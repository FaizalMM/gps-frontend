import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiConfig {
  // ─── GANTI SESUAI ENVIRONMENT ────────────────────────────────────────────
  //
  // Development (emulator Android):
  //   'http://10.0.2.2:8000/api'
  //
  // Development (device fisik, sesuaikan IP lokal):
  //   'http://192.168.1.100:8000/api'
  //
  // Staging / ngrok (ganti setiap kali ngrok restart):
  //   'https://xxxx-xxxx.ngrok-free.app/api'
  //
  // Production (domain tetap):
  //   'https://api.mobitra.id/api'
  //
  // ─────────────────────────────────────────────────────────────────────────
  static const String baseUrl =
      'https://unregal-keshia-contrapuntal.ngrok-free.dev/api'; // Ganti dengan Url server milikmu

  static const Duration timeout = Duration(seconds: 15);
}

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

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  final _storage = const FlutterSecureStorage();
  String? _token;

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

  Future<Map<String, String>> _headers({bool withAuth = true}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (withAuth) {
      final token = await _storage.read(key: 'api_token');
      _token = token;
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

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

  Future<ApiResponse<Map<String, dynamic>>> uploadMultipart(
    String endpoint,
    String filePath,
    String fieldName, {
    Map<String, String>? fields,
    String method = 'POST',
    bool withAuth = true,
  }) async {
    try {
      final token = withAuth ? await getToken() : null;
      final request = http.MultipartRequest(
        method,
        Uri.parse('${ApiConfig.baseUrl}$endpoint'),
      );
      if (token != null) request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';
      request.files.add(await http.MultipartFile.fromPath(fieldName, filePath));
      if (fields != null) request.fields.addAll(fields);
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
