import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../core/models/user.dart' as app;
import '../core/models/member.dart';
import '../core/models/user_role.dart';
import '../core/security/account_status.dart';
import 'member_lookup_service.dart';

class AuthService {
  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _manualAuth = auth,
      _manualFirestore = firestore;

  final FirebaseAuth? _manualAuth;
  final FirebaseFirestore? _manualFirestore;

  // Getters seguros que no rompen la app si Firebase no está inicializado
  FirebaseAuth get _auth {
    try {
      return _manualAuth ?? FirebaseAuth.instance;
    } catch (e) {
      throw Exception(
        'Firebase Auth no inicializado. Revisa la configuración Web.',
      );
    }
  }

  FirebaseFirestore get _firestore {
    try {
      return _manualFirestore ?? FirebaseFirestore.instance;
    } catch (e) {
      throw Exception(
        'Firestore no inicializado. Revisa la configuración Web.',
      );
    }
  }

  static const String _usersCollection = 'users';
  app.AppUser? _currentUser;
  app.AppUser? get currentUser => _currentUser;

  Stream<app.AppUser?> get authStateChanges {
    try {
      return _auth.authStateChanges().asyncMap((u) async {
        if (u == null) {
          _currentUser = null;
          return null;
        }
        try {
          final user = await _getUserFromFirestore(
            u.uid,
            signOutIfInactive: true,
          );
          _currentUser = user;
          return user;
        } on AccountInactiveException {
          _currentUser = null;
          return null;
        }
      });
    } catch (e) {
      return Stream.value(null);
    }
  }

  Future<app.AppUser?> getCurrentUser() async {
    try {
      final fb = _auth.currentUser;
      if (fb == null) return null;
      _currentUser = await _getUserFromFirestore(
        fb.uid,
        signOutIfInactive: true,
      );
      return _currentUser;
    } on AccountInactiveException {
      _currentUser = null;
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Escucha el documento `users/{uid}` y refleja cambios de rol/estado en la app.
  Stream<app.AppUser?> watchUserProfile(String uid) {
    return _firestore
        .collection(_usersCollection)
        .doc(uid)
        .snapshots()
        .asyncMap((doc) async {
          if (!doc.exists || doc.data() == null) {
            await _auth.signOut();
            _currentUser = null;
            return null;
          }

          final linked = await _ensureUserMemberLink(
            app.AppUser.fromMap(doc.data()!, doc.id),
          );

          if (!linked.isActive) {
            await _auth.signOut();
            _currentUser = null;
            throw AccountInactiveException();
          }

          _currentUser = linked;
          return linked;
        });
  }

  Future<app.AppUser?> _getUserFromFirestore(
    String uid, {
    bool signOutIfInactive = false,
  }) async {
    try {
      final doc = await _firestore.collection(_usersCollection).doc(uid).get();
      if (doc.exists && doc.data() != null) {
        final user = app.AppUser.fromMap(doc.data()!, doc.id);
        final linked = await _ensureUserMemberLink(user);
        if (!linked.isActive) {
          if (signOutIfInactive) {
            await _auth.signOut();
            _currentUser = null;
          }
          throw AccountInactiveException();
        }
        return linked;
      }
      return null;
    } on AccountInactiveException {
      rethrow;
    } catch (_) {
      return null;
    }
  }

  Future<MemberLookupResult?> _getMemberByEmployeeNumber(
    String employeeNumber,
  ) async {
    try {
      return await MemberLookupService(
        auth: _auth,
      ).lookupByEmployeeNumber(employeeNumber);
    } on MemberLookupException {
      rethrow;
    } catch (_) {
      return null;
    }
  }

  Future<app.AppUser> _ensureUserMemberLink(app.AppUser user) async {
    if (user.memberId != null && user.memberId!.trim().isNotEmpty) {
      return user;
    }

    final employeeNumber = user.employeeNumber?.trim();
    if (employeeNumber == null || employeeNumber.isEmpty) {
      return user;
    }

    try {
      final lookup = await _getMemberByEmployeeNumber(employeeNumber);
      if (lookup == null) {
        return user;
      }

      await _firestore.collection(_usersCollection).doc(user.id).update({
        'memberId': lookup.memberId,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
      return user.copyWith(memberId: lookup.memberId);
    } catch (_) {
      return user;
    }
  }

  Future<void> _rollbackCreatedFirebaseUser(User user) async {
    try {
      await user.delete();
    } catch (_) {
      await _auth.signOut();
    }
    _currentUser = null;
  }

  Future<void> signIn(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final uid = credential.user?.uid;
      if (uid == null) {
        throw Exception('No se pudo identificar el usuario autenticado');
      }

      final user = await _getUserFromFirestore(uid, signOutIfInactive: true);
      if (user == null) {
        await _auth.signOut();
        _currentUser = null;
        throw Exception(
          'Tu cuenta no tiene perfil asignado. Contacta al administrador.',
        );
      }
      _currentUser = user;
    } on AccountInactiveException catch (e) {
      throw Exception(e.message);
    } on FirebaseAuthException catch (e) {
      throw Exception(_firebaseErrorMessage(e.code));
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Error de conexión con el servidor');
    }
  }

  Future<void> signUpWithEmployeeNumber({
    required String email,
    required String password,
    String? employeeNumber,
    String? displayName,
    String role = 'VOTER',
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final fbUser = cred.user;
      if (fbUser == null) throw Exception('Error al crear usuario');

      final trimmedEmployeeNumber = employeeNumber?.trim();
      if (trimmedEmployeeNumber == null || trimmedEmployeeNumber.isEmpty) {
        await _rollbackCreatedFirebaseUser(fbUser);
        throw Exception('El número de trabajador es obligatorio');
      }

      MemberLookupResult lookup;
      try {
        final result = await _getMemberByEmployeeNumber(trimmedEmployeeNumber);
        if (result == null) {
          await _rollbackCreatedFirebaseUser(fbUser);
          throw Exception(
            'Número de trabajador no registrado en el padrón de socios.',
          );
        }
        if (result.member.status != MemberStatus.active) {
          await _rollbackCreatedFirebaseUser(fbUser);
          throw Exception('El socio asociado no se encuentra activo.');
        }
        lookup = result;
      } on MemberLookupException catch (e) {
        await _rollbackCreatedFirebaseUser(fbUser);
        throw Exception(e.message);
      } catch (e) {
        if (e is Exception && e.toString().contains('padrón')) rethrow;
        await _rollbackCreatedFirebaseUser(fbUser);
        throw Exception(
          'No se pudo validar el número de trabajador en el padrón.',
        );
      }

      final user = app.AppUser(
        id: fbUser.uid,
        email: fbUser.email ?? email,
        displayName: displayName ?? fbUser.displayName,
        role: UserRole.fromString(role),
        employeeNumber: trimmedEmployeeNumber,
        memberId: lookup.memberId,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );
      try {
        await _firestore
            .collection(_usersCollection)
            .doc(user.id)
            .set(user.toMap());
      } catch (_) {
        await _rollbackCreatedFirebaseUser(fbUser);
        throw Exception('No se pudo completar el registro de usuario.');
      }
      _currentUser = user;
    } on FirebaseAuthException catch (e) {
      throw Exception(_firebaseErrorMessage(e.code));
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
      _currentUser = null;
    } catch (_) {}
  }

  static const String _passwordResetEndpoint =
      'https://sistema-integrado-sindicato.web.app/api/request-password-reset';

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      final response = await http
          .post(
            Uri.parse(_passwordResetEndpoint),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email.trim()}),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode >= 200 && response.statusCode < 300) return;

      String message =
          'No se pudo enviar el correo de recuperación. Inténtalo nuevamente.';
      try {
        final payload = jsonDecode(response.body) as Map<String, dynamic>;
        message = payload['message'] as String? ?? message;
      } catch (_) {}
      throw Exception(message);
    } on TimeoutException {
      throw Exception(
        'El servidor tardó demasiado en responder. Inténtalo nuevamente.',
      );
    }
  }

  String _firebaseErrorMessage(String code) {
    switch (code) {
      case 'invalid-email':
        return 'Email no válido';
      case 'user-not-found':
        return 'Usuario no encontrado';
      case 'wrong-password':
        return 'Contraseña incorrecta';
      default:
        return 'Error de autenticación: $code';
    }
  }

  /// Sube una imagen de perfil a `user_avatars/{uid}/profile.jpg` y devuelve la URL pública.
  Future<String> uploadUserAvatarXFile(XFile file) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw Exception('Sesión no iniciada');
    }
    final ref = FirebaseStorage.instance.ref('user_avatars/$uid/profile.jpg');
    final mime = file.mimeType ?? 'image/jpeg';
    final meta = SettableMetadata(contentType: mime);
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) throw Exception('Imagen vacía');
    await ref.putData(bytes, meta);
    return ref.getDownloadURL();
  }

  /// Actualiza preferencias de avatar/género del propio usuario (Firestore).
  Future<void> updateUserAvatarPreferences({
    required String uid,
    String? gender,
    String? avatarMode,
    String? avatarUrl,
    bool removeAvatarUrl = false,
    bool removeGender = false,
  }) async {
    final fb = _auth.currentUser;
    if (fb == null || fb.uid != uid) {
      throw Exception('Sesión no válida');
    }
    final updates = <String, dynamic>{
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    };
    if (removeGender) {
      updates['gender'] = FieldValue.delete();
    } else if (gender != null) {
      updates['gender'] = gender;
    }
    if (avatarMode != null) {
      updates['avatarMode'] = avatarMode;
    }
    if (removeAvatarUrl) {
      updates['avatarUrl'] = FieldValue.delete();
    } else if (avatarUrl != null) {
      updates['avatarUrl'] = avatarUrl;
    }
    try {
      await _firestore.collection(_usersCollection).doc(uid).update(updates);
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        debugPrint(
          '[AuthService] Firestore permission-denied al actualizar perfil. '
          'Despliega reglas: firebase deploy --only firestore:rules '
          '(campos gender, avatarUrl, avatarMode deben estar permitidos).',
        );
      }
      rethrow;
    }
    if (_currentUser?.id == uid) {
      _currentUser = await _getUserFromFirestore(uid);
    }
  }

  /// Actualiza nombre y teléfono de contacto del propio usuario (`users/{uid}`).
  Future<void> updateSelfUserProfile({
    required String uid,
    required String displayName,
    required String phoneNumber,
  }) async {
    final fb = _auth.currentUser;
    if (fb == null || fb.uid != uid) {
      throw Exception('Sesión no válida');
    }
    final trimmedName = displayName.trim();
    if (trimmedName.isEmpty) {
      throw Exception('El nombre no puede estar vacío');
    }
    final updates = <String, dynamic>{
      'displayName': trimmedName,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    };
    final ph = phoneNumber.trim();
    if (ph.isEmpty) {
      updates['phoneNumber'] = FieldValue.delete();
    } else {
      updates['phoneNumber'] = ph;
    }
    try {
      await _firestore.collection(_usersCollection).doc(uid).update(updates);
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        debugPrint(
          '[AuthService] permission-denied al actualizar perfil (displayName/phoneNumber). '
          'Despliega reglas Firestore.',
        );
      }
      rethrow;
    }
    if (_currentUser?.id == uid) {
      _currentUser = await _getUserFromFirestore(uid);
    }
  }
}
