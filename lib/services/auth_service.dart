import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/models/user.dart' as app;
import '../core/models/user_role.dart';

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
        final user = await _getUserFromFirestore(u.uid);
        _currentUser = user;
        return user;
      });
    } catch (e) {
      return Stream.value(null);
    }
  }

  Future<app.AppUser?> getCurrentUser() async {
    try {
      final fb = _auth.currentUser;
      if (fb == null) return null;
      _currentUser = await _getUserFromFirestore(fb.uid);
      return _currentUser;
    } catch (e) {
      return null;
    }
  }

  Future<app.AppUser?> _getUserFromFirestore(String uid) async {
    try {
      final doc = await _firestore.collection(_usersCollection).doc(uid).get();
      if (doc.exists && doc.data() != null) {
        final user = app.AppUser.fromMap(doc.data()!, doc.id);
        return _ensureUserMemberLink(user);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<QueryDocumentSnapshot<Map<String, dynamic>>?>
  _getMemberByEmployeeNumber(String employeeNumber) async {
    final value = employeeNumber.trim();
    if (value.isEmpty) return null;

    final byWorkerCode = await _firestore
        .collection('members')
        .where('workerCode', isEqualTo: value)
        .limit(1)
        .get();
    if (byWorkerCode.docs.isNotEmpty) return byWorkerCode.docs.first;

    final byMemberNumber = await _firestore
        .collection('members')
        .where('memberNumber', isEqualTo: value)
        .limit(1)
        .get();
    if (byMemberNumber.docs.isNotEmpty) return byMemberNumber.docs.first;

    return null;
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
      final member = await _getMemberByEmployeeNumber(employeeNumber);
      if (member == null || !_memberIsActive(member.data())) {
        return user;
      }

      await _firestore.collection(_usersCollection).doc(user.id).update({
        'memberId': member.id,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
      return user.copyWith(memberId: member.id);
    } catch (_) {
      return user;
    }
  }

  bool _memberIsActive(Map<String, dynamic> data) {
    final status = (data['status'] as String? ?? 'active').toLowerCase();
    return status == 'active' || status == 'activo';
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

      final user = await _getUserFromFirestore(uid);
      if (user == null) {
        await _auth.signOut();
        _currentUser = null;
        throw Exception(
          'Tu cuenta no tiene perfil asignado. Contacta al administrador.',
        );
      }
      _currentUser = user;
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

      final QueryDocumentSnapshot<Map<String, dynamic>>? member;
      try {
        member = await _getMemberByEmployeeNumber(trimmedEmployeeNumber);
      } catch (_) {
        await _rollbackCreatedFirebaseUser(fbUser);
        throw Exception(
          'No se pudo validar el número de trabajador en el padrón.',
        );
      }

      if (member == null) {
        await _rollbackCreatedFirebaseUser(fbUser);
        throw Exception(
          'Número de trabajador no registrado en el padrón de socios.',
        );
      }
      if (!_memberIsActive(member.data())) {
        await _rollbackCreatedFirebaseUser(fbUser);
        throw Exception('El socio asociado no se encuentra activo.');
      }

      final user = app.AppUser(
        id: fbUser.uid,
        email: fbUser.email ?? email,
        displayName: displayName ?? fbUser.displayName,
        role: UserRole.fromString(role),
        employeeNumber: trimmedEmployeeNumber,
        memberId: member.id,
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

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw Exception(_firebaseErrorMessage(e.code));
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
}
