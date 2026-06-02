import 'package:flutter/foundation.dart';
import 'api_client.dart';
import '../models/models_api.dart';

// StudentService

class StudentService {
  final _api = ApiClient();

  Future<List<UserModel>> getStudents() async {
    final res = await _api.get('/students');
    if (!res.success || res.data == null) return [];
    final raw = res.data!['data'];
    final list = raw is List ? raw : (raw?['data'] as List? ?? []);
    return _parseStudentList(list);
  }

  Future<({List<UserModel> students, int statusCode})>
      getPendingStudents() async {
    final res = await _api.get('/students/pending');
    if (!res.success || res.data == null) {
      return (students: <UserModel>[], statusCode: res.statusCode);
    }
    final raw = res.data!['data'];
    final list = raw is List ? raw : (raw?['data'] as List? ?? []);
    return (students: _parseStudentList(list), statusCode: res.statusCode);
  }

  List<UserModel> _parseStudentList(List list) {
    return list.map((e) {
      final json = e as Map<String, dynamic>;

      if (json['user'] != null) {
        final userJson = json['user'] as Map<String, dynamic>;
        return UserModel.fromJson({
          ...userJson,
          'student': json,
        });
      }
      return UserModel.fromJson(json);
    }).toList();
  }

  Future<int?> approveStudent(int userId) async {
    final res = await _api.post('/students/$userId/approve', {});
    if (!res.success) return null;
    final data = res.data?['data'] as Map<String, dynamic>?;

    return data?['id'] as int?;
  }

  Future<bool> rejectStudent(int studentId, String reason) async {
    final res = await _api.post('/students/$studentId/reject', {
      'reason': reason,
    });
    return res.success;
  }

  Future<bool> suspendStudent(int studentId) async {
    final res = await _api.post('/students/$studentId/suspend', {});
    return res.success;
  }

  Future<bool> unsuspendStudent(int studentId) async {
    final res = await _api.post('/students/$studentId/unsuspend', {});
    return res.success;
  }

  Future<bool> deleteStudent(int studentId) async {
    final res = await _api.delete('/students/$studentId');
    return res.success;
  }

  Future<bool> updateStudent(int studentId, Map<String, dynamic> data) async {
    final res = await _api.put('/students/$studentId', data);
    return res.success;
  }

  // Siswa: get profil sendiri
  Future<UserModel?> getMyProfile() async {
    final res = await _api.get('/student/profile');
    if (!res.success || res.data == null) return null;
    final d = res.data!['data'];
    if (d == null) return null;
    return UserModel.fromJson(d as Map<String, dynamic>);
  }

  // Siswa: generate QR code check-in
  Future<Map<String, dynamic>?> generateQrCode({
    required double latitude,
    required double longitude,
  }) async {
    final res = await _api.post('/student/barcode', {
      'latitude': latitude,
      'longitude': longitude,
    });
    if (!res.success) {
      // Kembalikan map khusus berisi pesan error agar UI bisa tampilkan detail
      return {
        '__error':
            res.message.isNotEmpty ? res.message : 'Gagal generate QR Code'
      };
    }
    return res.data!['data'] as Map<String, dynamic>?;
  }

  /// Ambil status absensi siswa hari ini (sudah naik / belum / sudah turun)
  Future<Map<String, dynamic>?> getMyAttendanceToday(int studentId) async {
    final res = await _api.get('/student/attendance/today');
    if (!res.success || res.data == null) return null;
    final data = res.data!['data'];
    if (data == null) return null;
    return data as Map<String, dynamic>;
  }

  // Siswa: get info bus yang di-assign
  Future<Map<String, dynamic>?> getMyBus() async {
    final res = await _api.get('/student/bus');
    if (!res.success || res.data == null) return null;
    return res.data;
  }
}

// DriverService

class DriverService {
  final _api = ApiClient();

  Future<List<UserModel>> getDrivers() async {
    final res = await _api.get('/drivers');
    if (!res.success || res.data == null) return [];
    final raw = res.data!['data'];
    final list = raw is List ? raw : (raw?['data'] as List? ?? []);
    return list.map((e) {
      final json = e as Map<String, dynamic>;
      if (json['user'] != null) {
        final userJson =
            Map<String, dynamic>.from(json['user'] as Map<String, dynamic>);
        final driverJson = Map<String, dynamic>.from(json);
        return UserModel.fromJson({
          ...userJson,
          'role': 'driver',
          'driver': driverJson,
        });
      }
      return UserModel.fromJson({...json, 'role': 'driver'});
    }).toList();
  }

  Future<bool> createDriver({
    required String nama,
    required String email,
    required String password,
    required String nik,
    required String noHp,
    required String alamat,
  }) async {
    final res = await _api.post('/drivers', {
      'name': nama,
      'email': email,
      'password': password,
      'password_confirmation': password,
      'nik': nik,
      'no_hp': noHp,
      'alamat': alamat,
    });
    return res.success;
  }

  Future<bool> updateDriver(int id, Map<String, dynamic> data) async {
    final res = await _api.put('/drivers/$id', data);
    return res.success;
  }

  Future<bool> deleteDriver(int id) async {
    final res = await _api.delete('/drivers/$id');
    return res.success;
  }

  // Driver: profil sendiri
  Future<UserModel?> getMyProfile() async {
    final res = await _api.get('/driver/profile');
    if (!res.success || res.data == null) return null;
    final d = res.data!['data'];
    if (d == null) return null;
    return UserModel.fromJson(d as Map<String, dynamic>);
  }

  // Driver: toggle GPS on/off
  Future<bool> toggleGps(String status) async {
    final res = await _api.patch('/driver/gps', {'gps_status': status});
    return res.success;
  }

  // Driver: kirim koordinat GPS dengan data akurasi lengkap
  Future<bool> sendGpsLocation({
    required double latitude,
    required double longitude,
    required double speed,
    double? accuracy,
    double? heading,
    int? deviceTimestamp, // epoch ms dari device
    String? deviceId,
  }) async {
    final body = <String, dynamic>{
      'latitude': latitude,
      'longitude': longitude,
      'speed': speed < 0 ? 0 : speed, // filter speed negatif
      'device_timestamp':
          deviceTimestamp ?? DateTime.now().millisecondsSinceEpoch,
    };
    if (accuracy != null && accuracy >= 0) body['accuracy'] = accuracy;
    if (heading != null && heading >= 0) body['heading'] = heading;
    if (deviceId != null) body['device_id'] = deviceId;
    final res = await _api.post('/driver/gps', body);
    return res.success;
  }

  Future<ScanQrResult> scanStudentQr(
    Map<String, dynamic> qrData, {
    required double latitude,
    required double longitude,
  }) async {
    final res = await _api.post('/driver/attendance/scan', {
      'qr_id': qrData['id'],
      'student_id': qrData['student_id'],
      'bus_id': qrData['bus_id'],
      'halte_id': qrData['halte_id'],
      'tanggal': qrData['tanggal'],
      'latitude': latitude,
      'longitude': longitude,
    });

    if (res.success) {
      final d = res.data?['data'];
      if (d == null) return ScanQrResult.error('Response tidak valid');
      return ScanQrResult.success(
          AttendanceModel.fromJson(d as Map<String, dynamic>));
    }

    // Cek apakah error karena rute tidak sesuai (403 + error_type)
    final body = res.data;
    if (res.statusCode == 403 &&
        body != null &&
        body['error_type'] == 'route_mismatch') {
      return ScanQrResult.routeMismatch(RouteMismatchInfo.fromJson(body));
    }

    return ScanQrResult.error(res.message);
  }

  // Driver: checkout siswa
  Future<bool> checkoutStudent({
    required String qrId,
    required double latitude,
    required double longitude,
  }) async {
    final res = await _api.put('/driver/attendance/checkout', {
      'qr_id': qrId,
      'latitude': latitude,
      'longitude': longitude,
    });
    return res.success;
  }

  Future<List<Map<String, dynamic>>> getBusAttendanceToday(int busId) async {
    final res = await _api.get('/driver/buses/$busId/attendance/today');
    if (!res.success || res.data == null) return [];

    final wrapper = res.data!['data'];
    final raw = wrapper is Map ? wrapper['data'] : wrapper;
    if (raw is! List) return [];
    return List<Map<String, dynamic>>.from(raw);
  }

  // Driver: laporan harian
  Future<Map<String, dynamic>?> getDailyReport(int busId) async {
    final res = await _api.get('/driver/buses/$busId/report');
    if (!res.success || res.data == null) return null;
    return res.data;
  }
}

// HalteService
class HalteService {
  final _api = ApiClient();

  /// Ambil semua halte (tanpa paginasi)
  Future<List<HalteModel>> getHaltes() async {
    final res = await _api.get('/haltes', params: {'all': 'true'});
    if (!res.success || res.data == null) return [];
    final raw = res.data!['data'];
    final list = raw is List ? raw : (raw?['data'] as List? ?? []);
    return list
        .map((e) => HalteModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Cari halte berdasarkan nama/alamat
  Future<List<HalteModel>> searchHaltes(String query) async {
    final res = await _api.get('/haltes', params: {'q': query, 'all': 'true'});
    if (!res.success || res.data == null) return [];
    final raw = res.data!['data'];
    final list = raw is List ? raw : (raw?['data'] as List? ?? []);
    return list
        .map((e) => HalteModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Buat halte baru dan kembalikan HalteModel-nya
  /// Return HalteModel dengan ID asli dari BE, atau null jika gagal
  Future<HalteModel?> createHalte({
    required String namaHalte,
    required double latitude,
    required double longitude,
    String alamat = '',
  }) async {
    final res = await _api.post('/haltes', {
      'nama_halte': namaHalte,
      'latitude': latitude,
      'longitude': longitude,
      'alamat': alamat,
    });
    if (!res.success || res.data == null) return null;
    final d = res.data!['data'];
    if (d == null) return null;
    return HalteModel.fromJson(d as Map<String, dynamic>);
  }

  Future<bool> updateHalte(
    int id, {
    String? namaHalte,
    double? latitude,
    double? longitude,
    String? alamat,
  }) async {
    final body = <String, dynamic>{};
    if (namaHalte != null) body['nama_halte'] = namaHalte;
    if (latitude != null) body['latitude'] = latitude;
    if (longitude != null) body['longitude'] = longitude;
    if (alamat != null) body['alamat'] = alamat;
    final res = await _api.put('/haltes/$id', body);
    return res.success;
  }

  Future<bool> deleteHalte(int id) async {
    final res = await _api.delete('/haltes/$id');
    return res.success;
  }
}

// AttendanceService

class AttendanceService {
  final _api = ApiClient();

  Future<List<AttendanceModel>> getAttendanceToday({int? busId}) async {
    final params = <String, String>{
      'date': DateTime.now().toIso8601String().substring(0, 10),
    };
    if (busId != null) params['bus_id'] = busId.toString();

    final res = await _api.get('/attendance', params: params);
    if (!res.success || res.data == null) return [];
    final raw = res.data!['data'];
    final list = raw is List ? raw : (raw?['data'] as List? ?? []);
    return list
        .map((e) => AttendanceModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

class RouteService {
  final _api = ApiClient();

  /// Ambil semua rute untuk listing (tanpa polyline — ringan)
  /// Untuk polyline lengkap gunakan getRoute(id) atau getRouteByBus(busId)
  Future<List<RouteModel>> getRoutes() async {
    final res = await _api.get('/routes');
    if (!res.success || res.data == null) return [];
    final raw = res.data!['data'];
    final list = raw is List ? raw : (raw?['data'] as List? ?? []);
    try {
      return list
          .map((e) => RouteModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[RouteService] Error parsing routes: \$e');
      return [];
    }
  }

  /// Ambil satu rute lengkap (dengan halte & polyline)
  Future<RouteModel?> getRoute(int routeId) async {
    final res = await _api.get('/routes/$routeId');
    if (!res.success || res.data == null) return null;
    final d = res.data!['data'] ?? res.data;
    if (d == null) return null;
    return RouteModel.fromJson(d as Map<String, dynamic>);
  }

  /// Ambil rute untuk sebuah bus (digunakan siswa & driver)
  Future<RouteModel?> getRouteByBus(int busId) async {
    final res = await _api.get('/buses/$busId/route');
    if (!res.success || res.data == null) return null;
    final d = res.data!['data'];
    if (d == null) return null;
    return RouteModel.fromJson(d as Map<String, dynamic>);
  }

  /// Buat rute baru beserta urutan halte (admin)
  /// [orderedHalteIds] = list id halte berurutan dari awal ke akhir
  Future<RouteModel?> createRoute({
    required int busId,
    required String namaRute,
    List<int>? orderedHalteIds,
  }) async {
    final body = <String, dynamic>{
      'bus_id': busId,
      'nama_rute': namaRute,
    };
    if (orderedHalteIds != null && orderedHalteIds.isNotEmpty) {
      body['haltes'] = orderedHalteIds
          .asMap()
          .entries
          .map((e) => {
                'halte_id': e.value,
                'urutan': e.key + 1,
              })
          .toList();
    }
    final res = await _api.post('/routes', body);
    if (!res.success || res.data == null) return null;
    final d = res.data!['data'] ?? res.data;
    if (d == null) return null;
    return RouteModel.fromJson(d as Map<String, dynamic>);
  }

  /// Update nama rute
  Future<bool> updateRoute(int routeId, {String? namaRute, int? busId}) async {
    final body = <String, dynamic>{};
    if (namaRute != null) body['nama_rute'] = namaRute;
    if (busId != null) body['bus_id'] = busId;
    final res = await _api.put('/routes/$routeId', body);
    return res.success;
  }

  /// Hapus rute
  Future<bool> deleteRoute(int routeId) async {
    final res = await _api.delete('/routes/$routeId');
    return res.success;
  }

  /// Ambil halte dalam rute tertentu
  Future<List<RouteHalteModel>> getHaltesByRoute(int routeId) async {
    final res = await _api.get('/routes/$routeId/haltes');
    if (!res.success || res.data == null) return [];
    final raw = res.data!['data'];
    final list = raw is List ? raw : (raw?['data'] as List? ?? []);
    return (list
        .map((e) => RouteHalteModel.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.urutan.compareTo(b.urutan)));
  }

  /// Tambah halte ke rute
  Future<bool> addHalteToRoute({
    required int routeId,
    required int halteId,
    required int urutan,
  }) async {
    final res = await _api.post('/routes/$routeId/haltes', {
      'halte_id': halteId,
      'urutan': urutan,
    });
    return res.success;
  }

  /// Update urutan halte dalam rute
  Future<bool> updateRouteHalte(int routeHalteId, int urutan) async {
    final res =
        await _api.put('/route-haltes/$routeHalteId', {'urutan': urutan});
    return res.success;
  }

  /// Hapus halte dari rute
  Future<bool> removeHalteFromRoute(int routeHalteId) async {
    final res = await _api.delete('/route-haltes/$routeHalteId');
    return res.success;
  }

  Future<RouteModel?> syncRoute({
    required int routeId,
    required List<Map<String, double>> polyline,
    List<int>? halteIds,
    String? namaRute,
  }) async {
    final body = <String, dynamic>{'polyline': polyline};
    if (namaRute != null && namaRute.isNotEmpty) body['nama_rute'] = namaRute;
    if (halteIds != null && halteIds.isNotEmpty) {
      body['haltes'] = halteIds
          .asMap()
          .entries
          .map((e) => {'halte_id': e.value, 'urutan': e.key + 1})
          .toList();
    }
    final res = await _api.post('/routes/$routeId/sync', body);
    if (!res.success || res.data == null) return null;
    final d = res.data!['data'] ?? res.data;
    if (d == null) return null;
    return RouteModel.fromJson(d as Map<String, dynamic>);
  }
}

class AdminService {
  final _api = ApiClient();

  Future<List<UserModel>> getAdmins() async {
    final allAdmins = <UserModel>[];
    int page = 1;
    int lastPage = 1;

    do {
      final res = await _api.get('/admins', params: {'page': '$page'});
      if (!res.success || res.data == null) break;

      final raw = res.data!['data'];
      final list = raw is List ? raw : [];
      for (final e in list) {
        final json = e as Map<String, dynamic>;
        allAdmins.add(UserModel.fromJson({...json, 'role': 'admin'}));
      }

      final pagination = res.data!['pagination'] as Map?;
      if (pagination != null) {
        lastPage = (pagination['last_page'] as num?)?.toInt() ?? 1;
      }
      page++;
    } while (page <= lastPage);

    return allAdmins;
  }

  Future<UserModel?> getAdmin(int id) async {
    final res = await _api.get('/admins/$id');
    if (!res.success || res.data == null) return null;
    final d = res.data!['data'];
    if (d == null) return null;
    return UserModel.fromJson(
        {...(d as Map<String, dynamic>), 'role': 'admin'});
  }

  Future<bool> createAdmin({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
    String? photoPath,
  }) async {
    if (photoPath != null) {
      final res = await _api.uploadMultipart(
        '/admins',
        photoPath,
        'photo',
        fields: {
          'name': name,
          'email': email,
          'password': password,
          'password_confirmation': passwordConfirmation,
        },
      );
      return res.success;
    }
    final res = await _api.post('/admins', {
      'name': name,
      'email': email,
      'password': password,
      'password_confirmation': passwordConfirmation,
    });
    return res.success;
  }

  Future<({bool success, String? error})> updateAdmin(
    int id, {
    String? name,
    String? email,
    String? password,
    String? passwordConfirmation,
    String? photoPath,
  }) async {
    final fields = <String, String>{};
    if (name != null) fields['name'] = name;
    if (email != null) fields['email'] = email;
    if (password != null) {
      fields['password'] = password;
      fields['password_confirmation'] = passwordConfirmation ?? '';
    }

    if (photoPath != null) {
      final res = await _api.uploadMultipart(
        '/admins/$id',
        photoPath,
        'photo',
        fields: {...fields, '_method': 'PUT'},
      );
      return (success: res.success, error: res.success ? null : res.message);
    }

    if (fields.isEmpty) return (success: false, error: 'Tidak ada data');

    final body = <String, dynamic>{};
    fields.forEach((k, v) => body[k] = v);
    final res = await _api.put('/admins/$id', body);
    return (success: res.success, error: res.success ? null : res.message);
  }

  Future<bool> deleteAdmin(int id) async {
    final res = await _api.delete('/admins/$id');
    return res.success;
  }
}

class DriverSuspendService {
  Future<({bool success, String? error})> suspendDriver(int driverId) async {
    return (
      success: false,
      error:
          'Fitur suspend driver belum tersedia di server. Hubungi pengembang backend untuk menambahkan endpoint /drivers/{id}/suspend.'
    );
  }

  Future<({bool success, String? error})> unsuspendDriver(int driverId) async {
    return (
      success: false,
      error:
          'Fitur aktifkan driver belum tersedia di server. Hubungi pengembang backend untuk menambahkan endpoint /drivers/{id}/unsuspend.'
    );
  }
}

class RejectionHistoryService {
  final _api = ApiClient();

  Future<List<Map<String, dynamic>>> getStudentRejectionHistories(
      int studentId) async {
    final res = await _api.get('/students/$studentId/rejection-histories');
    if (!res.success || res.data == null) return [];
    final raw = res.data!['data'];
    final list = raw is List ? raw : (raw?['data'] as List? ?? []);
    return list.cast<Map<String, dynamic>>();
  }

  Future<bool> deleteRejectionHistory(int historyId) async {
    final res = await _api.delete('/student-rejection-histories/$historyId');
    return res.success;
  }
}

class BusRouteService {
  final _api = ApiClient();

  Future<RouteModel?> getBusRoute(int busId) async {
    final res = await _api.get('/buses/$busId/route');
    if (!res.success || res.data == null) return null;
    final d = res.data!['data'];
    if (d == null) return null;
    return RouteModel.fromJson(d as Map<String, dynamic>);
  }
}

class ChangePasswordService {
  final _api = ApiClient();

  Future<({bool success, String? error})> changePassword({
    required String currentPassword,
    required String newPassword,
    required String newPasswordConfirmation,
  }) async {
    final res = await _api.post('/auth/change-password', {
      'current_password': currentPassword,
      'new_password': newPassword,
      'new_password_confirmation': newPasswordConfirmation,
    });
    return (success: res.success, error: res.success ? null : res.message);
  }
}
