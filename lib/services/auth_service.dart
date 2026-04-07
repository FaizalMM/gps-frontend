import 'api_client.dart';
import '../models/models_api.dart';

class AuthService {
  final _api = ApiClient();

  // Cache bus aktif driver — diisi saat login, dikosongkan saat logout.
  // Diakses oleh DriverDashboard agar tidak perlu request tambahan.
  BusModel? _cachedDriverBus;
  BusModel? get cachedDriverBus => _cachedDriverBus;

  Future<AuthResult> login(String email, String password) async {
    final res = await _api.post(
        '/auth/login',
        {
          'email': email,
          'password': password,
        },
        withAuth: false);

    if (!res.success) {
      if (res.statusCode == 403) {
        final msg = res.message;
        if (msg.contains('menunggu')) return AuthResult.pending(msg);
        if (msg.contains('ditolak')) return AuthResult.rejected(msg);
        return AuthResult.error(msg);
      }
      return AuthResult.error(res.message);
    }

    final data = res.data!['data'] as Map<String, dynamic>? ?? res.data!;
    final token = data['token'] as String?;
    final userJson = data['user'] as Map<String, dynamic>?;

    if (token == null || userJson == null) {
      return AuthResult.error('Response tidak valid dari server');
    }

    await _api.saveToken(token);

    // Parse user langsung dari response login — tidak perlu extra call /auth/me
    final user = UserModel.fromJson(userJson);

    // Jika driver, cache data bus aktif dari response login
    // sehingga DriverDashboard bisa langsung pakai tanpa request tambahan
    final busJson = data['bus'] as Map<String, dynamic>?;
    _cachedDriverBus = busJson != null ? BusModel.fromJson(busJson) : null;

    return AuthResult.success(user);
  }

  Future<RegisterResult> registerSiswa({
    required String nama,
    required String email,
    required String nis,
    required String sekolah,
    required String alamat,
    required String noHp,
    required String password,
    required String passwordConfirmation,
  }) async {
    final res = await _api.post(
        '/auth/register',
        {
          'name': nama,
          'email': email,
          'nis': nis,
          'sekolah': sekolah,
          'alamat': alamat,
          'no_hp': noHp,
          'password': password,
          'password_confirmation': passwordConfirmation,
        },
        withAuth: false);

    if (!res.success) {
      if (res.message.toLowerCase().contains('email')) {
        return RegisterResult.emailExists;
      }
      if (res.message.toLowerCase().contains('nis')) {
        return RegisterResult.nisExists;
      }
      return RegisterResult.error;
    }
    return RegisterResult.success;
  }

  Future<void> logout() async {
    await _api.post('/auth/logout', {});
    await _api.clearToken();
    _cachedDriverBus = null; // bersihkan cache saat logout
  }

  Future<UserModel?> getMe() async {
    final res = await _api.get('/auth/me');
    if (!res.success || res.data == null) return null;
    final data = res.data!['data'] ?? res.data;
    if (data is Map<String, dynamic>) {
      return UserModel.fromJson(data['user'] ?? data);
    }
    return null;
  }

  /// Versi getMe yang juga mengisi cachedDriverBus — dipakai saat auto-login
  /// agar driver yang buka kembali app setelah force-close tetap dapat data bus
  Future<UserModel?> getMeWithBus() async {
    final res = await _api.get('/auth/me');
    if (!res.success || res.data == null) return null;
    final data = res.data!['data'] ?? res.data;
    if (data is! Map<String, dynamic>) return null;

    final userJson = data['user'] as Map<String, dynamic>?;
    if (userJson == null) return null;

    final user = UserModel.fromJson(userJson);

    // Isi cache bus untuk driver
    final busJson = data['bus'] as Map<String, dynamic>?;
    _cachedDriverBus = busJson != null ? BusModel.fromJson(busJson) : null;

    return user;
  }

  Future<bool> isLoggedIn() => _api.hasToken();

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
    required String newPasswordConfirmation,
  }) async {
    final res = await _api.post('/auth/change-password', {
      'current_password': currentPassword,
      'new_password': newPassword,
      'new_password_confirmation': newPasswordConfirmation,
    });
    return res.success;
  }
}

// ── Result types ──────────────────────────────────────────────

class AuthResult {
  final AuthResultType type;
  final UserModel? user;
  final String message;

  AuthResult._(this.type, {this.user, this.message = ''});

  factory AuthResult.success(UserModel user) =>
      AuthResult._(AuthResultType.success, user: user);
  factory AuthResult.pending(String msg) =>
      AuthResult._(AuthResultType.pending, message: msg);
  factory AuthResult.rejected(String msg) =>
      AuthResult._(AuthResultType.rejected, message: msg);
  factory AuthResult.error(String msg) =>
      AuthResult._(AuthResultType.error, message: msg);

  bool get isSuccess => type == AuthResultType.success;
}

enum AuthResultType { success, pending, rejected, error }

enum RegisterResult { success, emailExists, nisExists, error }
