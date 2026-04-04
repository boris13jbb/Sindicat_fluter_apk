import 'package:flutter/foundation.dart';
import '../core/models/user.dart';
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
      _user = await _authService.getCurrentUser();
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
}
