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
        return app.AppUser.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw Exception(_firebaseErrorMessage(e.code));
    } catch (e) {
      throw Exception('Error de conexión con el servidor');
    }
  }

  Future<void> signUpWithEmployeeNumber({
    required String email,
    required String password,
    String? employeeNumber,
    String? displayName,
    String role = 'USER',
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final fbUser = cred.user;
      if (fbUser == null) throw Exception('Error al crear usuario');

      final user = app.AppUser(
        id: fbUser.uid,
        email: fbUser.email ?? email,
        displayName: displayName ?? fbUser.displayName,
        role: UserRole.fromString(role),
        employeeNumber: employeeNumber?.trim().isEmpty ?? true ? null : employeeNumber,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );
      await _firestore
          .collection(_usersCollection)
          .doc(user.id)
          .set(user.toMap());
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
