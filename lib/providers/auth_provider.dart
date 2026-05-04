import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/app_scaffold_messenger.dart';
import '../core/models/user.dart';
import '../core/models/user_avatar_prefs.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider({AuthService? authService})
    : _authService = authService ?? AuthService();

  final AuthService _authService;

  AppUser? _user;
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  AppUser? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;
  bool get isSignedIn => _user != null;

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();
    try {
      _authService.authStateChanges.listen((AppUser? u) {
        _user = u;
        _isLoading = false;
        notifyListeners();
      });
      _user = await _authService.getCurrentUser();
    } catch (e) {
      debugPrint('Auth provider init error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signIn(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
    try {
      await _authService.signIn(email, password);
      _user = _authService.currentUser ?? await _authService.getCurrentUser();
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signUpWithEmployeeNumber({
    required String email,
    required String password,
    required String employeeNumber,
    String? displayName,
    String role = 'VOTER',
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _authService.signUpWithEmployeeNumber(
        email: email,
        password: password,
        employeeNumber: employeeNumber,
        displayName: displayName,
        role: role,
      );
      _user = await _authService.getCurrentUser();
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();
    try {
      await _authService.signOut();
      _user = null;
    } catch (_) {
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
    try {
      await _authService.sendPasswordResetEmail(email);
      _successMessage =
          'Se ha enviado un correo para restablecer tu contraseña';
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  /// Persiste nombre y teléfono de contacto en Firestore y refresca el usuario local.
  /// No usa [_isLoading] global para no bloquear el shell de inicio durante el guardado.
  Future<void> saveProfileBasics({
    required String displayName,
    required String phoneNumber,
  }) async {
    final u = _user;
    if (u == null) return;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
    try {
      await _authService.updateSelfUserProfile(
        uid: u.id,
        displayName: displayName,
        phoneNumber: phoneNumber,
      );
      _user = await _authService.getCurrentUser();
      _successMessage = 'Perfil actualizado';
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
    } finally {
      notifyListeners();
    }
  }

  static String _storageOrRulesDeniedHint() {
    return 'Acceso denegado al guardar el avatar (403). Revisa: (1) reglas de '
        'Storage desplegadas para user_avatars/{tu_uid}/…; (2) si en Firebase '
        'App Check tiene refuerzo en Storage, registra el token de depuración '
        '(logcat al arrancar la app en debug) o desactiva el refuerzo temporalmente.';
  }

  static String _avatarErrorMessage(Object e) {
    if (e is FirebaseException) {
      switch (e.code) {
        case 'permission-denied':
          return 'No se pudo guardar el avatar: el servidor rechazó la operación. '
              'Despliega las reglas de Firestore y Storage (firebase deploy) o '
              'contacta al administrador.';
        case 'unauthorized':
          return _storageOrRulesDeniedHint();
        case 'unauthenticated':
          return 'Sesión caducada. Vuelve a iniciar sesión e inténtalo de nuevo.';
        case 'network-request-failed':
        case 'unavailable':
          return 'Sin conexión o servicio no disponible. Revisa la red e inténtalo de nuevo.';
        default:
          final m = e.message;
          if (m != null && m.isNotEmpty) {
            final lower = m.toLowerCase();
            if (lower.contains('not authorized') ||
                lower.contains('permission denied')) {
              return _storageOrRulesDeniedHint();
            }
            return 'No se pudo guardar el avatar: $m';
          }
          return 'No se pudo guardar el avatar (código: ${e.code}).';
      }
    }
    final s = e.toString();
    return s.replaceFirst('Exception: ', '').replaceFirst('Error: ', '');
  }

  void _showAvatarErrorSnackBar(String message) {
    final messenger = appScaffoldMessengerKey.currentState;
    if (messenger == null) {
      debugPrint('[AuthProvider] Error de avatar (sin ScaffoldMessenger): $message');
      return;
    }
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade900,
        duration: const Duration(seconds: 6),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Avatar ilustrado por defecto (masculino / femenino / neutro); borra foto personalizada.
  Future<void> saveDefaultAvatar(String avatarMode) async {
    final u = _user;
    if (u == null) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final String gender;
      switch (avatarMode) {
        case UserAvatarMode.defaultMale:
          gender = UserAvatarMode.genderMale;
          break;
        case UserAvatarMode.defaultFemale:
          gender = UserAvatarMode.genderFemale;
          break;
        default:
          gender = UserAvatarMode.genderNeutral;
      }
      await _authService.updateUserAvatarPreferences(
        uid: u.id,
        gender: gender,
        avatarMode: avatarMode,
        removeAvatarUrl: true,
      );
      _user = await _authService.getCurrentUser();
    } catch (e) {
      _errorMessage = _avatarErrorMessage(e);
      _showAvatarErrorSnackBar(_errorMessage!);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Elige imagen desde galería, sube a Storage y marca perfil como `custom`.
  Future<void> pickAndUploadCustomAvatar() async {
    final u = _user;
    if (u == null) return;
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 88,
    );
    if (file == null) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final url = await _authService.uploadUserAvatarXFile(file);
      await _authService.updateUserAvatarPreferences(
        uid: u.id,
        avatarUrl: url,
        avatarMode: UserAvatarMode.custom,
      );
      _user = await _authService.getCurrentUser();
    } catch (e) {
      _errorMessage = _avatarErrorMessage(e);
      _showAvatarErrorSnackBar(_errorMessage!);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
