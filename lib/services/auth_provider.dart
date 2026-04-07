import 'package:flutter/material.dart';
import '../models/models_api.dart';
import 'auth_service.dart';
export 'auth_service.dart' show RegisterResult;

class AuthProvider extends ChangeNotifier {
  final _authService = AuthService();

  // Expose authService agar DriverDashboard bisa ambil cachedDriverBus
  AuthService get authService => _authService;

  UserModel? _currentUser;
  String? _loginError;
  bool _isLoading = false;

  UserModel? get currentUser => _currentUser;
  String? get loginError => _loginError;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _currentUser != null;

  Future<LoginResult> login(String email, String password) async {
    _isLoading = true;
    _loginError = null;
    notifyListeners();

    if (email.isEmpty || password.isEmpty) {
      _loginError = 'Email dan password tidak boleh kosong';
      _isLoading = false;
      notifyListeners();
      return LoginResult.error;
    }

    final result = await _authService.login(email, password);
    _isLoading = false;

    switch (result.type) {
      case AuthResultType.success:
        _currentUser = result.user;
        notifyListeners();
        return LoginResult.success;
      case AuthResultType.pending:
        _loginError = result.message;
        notifyListeners();
        return LoginResult.pending;
      case AuthResultType.rejected:
        _loginError = result.message;
        notifyListeners();
        return LoginResult.rejected;
      case AuthResultType.error:
        _loginError = result.message;
        notifyListeners();
        return LoginResult.error;
    }
  }

  Future<RegisterResult> registerSiswa({
    required String namaLengkap,
    required String email,
    required String nis,
    required String sekolah,
    required String alamat,
    required String noHp,
    required String password,
  }) async {
    _isLoading = true;
    notifyListeners();
    final result = await _authService.registerSiswa(
      nama: namaLengkap,
      email: email,
      nis: nis,
      sekolah: sekolah,
      alamat: alamat,
      noHp: noHp,
      password: password,
      passwordConfirmation: password,
    );
    _isLoading = false;
    notifyListeners();
    return result;
  }

  Future<void> logout() async {
    await _authService.logout();
    _currentUser = null;
    notifyListeners();
  }

  Future<bool> tryAutoLogin() async {
    try {
      final loggedIn = await _authService.isLoggedIn();
      if (!loggedIn) return false;

      // Pakai getMeWithBus agar cachedDriverBus terisi saat auto-login
      final result = await _authService.getMeWithBus();
      if (result == null) {
        await _authService.logout();
        return false;
      }

      _currentUser = result;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint("Auto login error: $e");
      return false;
    }
  }
}

enum LoginResult { success, pending, rejected, error }
