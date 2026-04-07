import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Konfigurasi Base URL — ganti sesuai server Laravel kamu
class ApiConfig {
  // Ganti dengan IP/domain server Laravel saat deploy
  // Contoh local: 'http://192.168.1.x:8000/api'
  // Contoh production: 'https://api.mobitra.id/api'
  // static const String baseUrl =
  //     'http://10.0.2.2:8000/api'; // Android emulator → localhost

  // Base URL server Laravel melalui ngrok  
  static const String baseUrl =
      'https://unregal-keshia-contrapuntal.ngrok-free.dev/api';

  static const Duration timeout = Duration(seconds: 15);
}

/// Response wrapper
class ApiResponse<T> {
  final bool success;
  final T? data;
  final String message;
  final int statusCode;

  ApiResponse({
    required this.success,
    this.data,
    required this.message,
    required this.statusCode,
  });
}

/// Core API client — semua request HTTP lewat sini
class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  final _storage = const FlutterSecureStorage();
  String? _token;

  // ── Token management ─────────────────────────────────────

  Future<void> saveToken(String token) async {
    _token = token;
    await _storage.write(key: 'api_token', value: token);
  }

  Future<String?> getToken() async {
    _token ??= await _storage.read(key: 'api_token');
    return _token;
  }

  Future<void> clearToken() async {
    _token = null;
    await _storage.delete(key: 'api_token');
  }

  Future<bool> hasToken() async {
    final t = await getToken();
    return t != null && t.isNotEmpty;
  }

  // ── Headers ───────────────────────────────────────────────

  Future<Map<String, String>> _headers({bool withAuth = true}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (withAuth) {
      // [FIX] Selalu baca ulang dari storage — jangan andalkan cache _token
      // yang bisa null saat polling berjalan sebelum login selesai
      final token = await _storage.read(key: 'api_token');
      _token = token;
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  // ── HTTP Methods ──────────────────────────────────────────

  Future<ApiResponse<Map<String, dynamic>>> get(
    String endpoint, {
    Map<String, String>? params,
    bool withAuth = true,
  }) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint')
          .replace(queryParameters: params);
      final response = await http
          .get(uri, headers: await _headers(withAuth: withAuth))
          .timeout(ApiConfig.timeout);
      return _parse(response);
    } on SocketException {
      return ApiResponse(
          success: false, message: 'Tidak ada koneksi internet', statusCode: 0);
    } catch (e) {
      return ApiResponse(
          success: false,
          message: 'Gagal terhubung ke server: $e',
          statusCode: 0);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> post(
    String endpoint,
    Map<String, dynamic> body, {
    bool withAuth = true,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}$endpoint'),
            headers: await _headers(withAuth: withAuth),
            body: jsonEncode(body),
          )
          .timeout(ApiConfig.timeout);
      return _parse(response);
    } on SocketException {
      return ApiResponse(
          success: false, message: 'Tidak ada koneksi internet', statusCode: 0);
    } catch (e) {
      return ApiResponse(
          success: false,
          message: 'Gagal terhubung ke server: $e',
          statusCode: 0);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> put(
    String endpoint,
    Map<String, dynamic> body, {
    bool withAuth = true,
  }) async {
    try {
      final response = await http
          .put(
            Uri.parse('${ApiConfig.baseUrl}$endpoint'),
            headers: await _headers(withAuth: withAuth),
            body: jsonEncode(body),
          )
          .timeout(ApiConfig.timeout);
      return _parse(response);
    } on SocketException {
      return ApiResponse(
          success: false, message: 'Tidak ada koneksi internet', statusCode: 0);
    } catch (e) {
      return ApiResponse(
          success: false,
          message: 'Gagal terhubung ke server: $e',
          statusCode: 0);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> patch(
    String endpoint,
    Map<String, dynamic> body, {
    bool withAuth = true,
  }) async {
    try {
      final response = await http
          .patch(
            Uri.parse('${ApiConfig.baseUrl}$endpoint'),
            headers: await _headers(withAuth: withAuth),
            body: jsonEncode(body),
          )
          .timeout(ApiConfig.timeout);
      return _parse(response);
    } on SocketException {
      return ApiResponse(
          success: false, message: 'Tidak ada koneksi internet', statusCode: 0);
    } catch (e) {
      return ApiResponse(
          success: false,
          message: 'Gagal terhubung ke server: $e',
          statusCode: 0);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> delete(
    String endpoint, {
    bool withAuth = true,
  }) async {
    try {
      final response = await http
          .delete(
            Uri.parse('${ApiConfig.baseUrl}$endpoint'),
            headers: await _headers(withAuth: withAuth),
          )
          .timeout(ApiConfig.timeout);
      return _parse(response);
    } on SocketException {
      return ApiResponse(
          success: false, message: 'Tidak ada koneksi internet', statusCode: 0);
    } catch (e) {
      return ApiResponse(
          success: false,
          message: 'Gagal terhubung ke server: $e',
          statusCode: 0);
    }
  }

  // Upload file (multipart)
  Future<ApiResponse<Map<String, dynamic>>> uploadFile(
    String endpoint,
    String filePath,
    String fieldName, {
    bool withAuth = true,
  }) async {
    try {
      final token = withAuth ? await getToken() : null;
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.baseUrl}$endpoint'),
      );
      if (token != null) request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';
      request.files.add(await http.MultipartFile.fromPath(fieldName, filePath));
      final streamed = await request.send().timeout(ApiConfig.timeout);
      final response = await http.Response.fromStream(streamed);
      return _parse(response);
    } on SocketException {
      return ApiResponse(
          success: false, message: 'Tidak ada koneksi internet', statusCode: 0);
    } catch (e) {
      return ApiResponse(
          success: false, message: 'Gagal upload: $e', statusCode: 0);
    }
  }

  // ── Response parser ───────────────────────────────────────

  ApiResponse<Map<String, dynamic>> _parse(http.Response response) {
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final success = response.statusCode >= 200 && response.statusCode < 300;
      final message = body['message'] as String? ??
          (success ? 'Berhasil' : 'Terjadi kesalahan');

      if (kDebugMode) {
        debugPrint('[API] ${response.statusCode} ${response.request?.url}');
        if (!success) debugPrint('[API] Error: $message');
      }

      return ApiResponse(
        success: success,
        data: body,
        message: message,
        statusCode: response.statusCode,
      );
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Gagal parse response: $e',
        statusCode: response.statusCode,
      );
    }
  }
}
