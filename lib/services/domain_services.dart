import 'package:flutter/foundation.dart';
import 'api_client.dart';
import '../models/models_api.dart';

class StudentService {
  final _api = ApiClient();

  Future<List<UserModel>> getStudents() async {
    final List<UserModel> all = [];
    int page = 1;
    while (true) {
      final res = await _api.get('/students?page=$page&per_page=1000');
      if (!res.success || res.data == null) break;
      final raw = res.data!['data'];
      final list = raw is List ? raw : (raw?['data'] as List? ?? []);
      final parsed = _parseStudentList(list);
      all.addAll(parsed);

      final pagination = res.data!['pagination'] as Map<String, dynamic>?;
      final lastPage = pagination?['last_page'] as int? ?? 1;
      if (page >= lastPage) break;
      page++;
    }
    return all;
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

  Future<UserModel?> getMyProfile() async {
    final res = await _api.get('/student/profile');
    if (!res.success || res.data == null) return null;
    final d = res.data!['data'];
    if (d == null) return null;
    return UserModel.fromJson(d as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>?> generateQrCode({
    required double latitude,
    required double longitude,
  }) async {
    final res = await _api.post('/student/barcode', {
      'latitude': latitude,
      'longitude': longitude,
    });
    if (!res.success) {
      return {
        '__error':
            res.message.isNotEmpty ? res.message : 'Gagal generate QR Code'
      };
    }
    return res.data!['data'] as Map<String, dynamic>?;
  }

  Future<Map<String, dynamic>?> getMyAttendanceToday(int studentId) async {
    final res = await _api.get('/student/attendance/today');
    if (!res.success || res.data == null) return null;
    final data = res.data!['data'];
    if (data == null) return null;
    return data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>?> getMyBus() async {
    final res = await _api.get('/student/bus');
    if (!res.success || res.data == null) return null;
    return res.data;
  }
}

class DriverService {
  final _api = ApiClient();

  Future<List<UserModel>> getDrivers() async {
    final List<UserModel> all = [];
    int page = 1;
    while (true) {
      final res = await _api.get('/drivers?page=$page&per_page=1000');
      if (!res.success || res.data == null) break;
      final raw = res.data!['data'];
      final list = raw is List ? raw : (raw?['data'] as List? ?? []);
      final parsed = list.map((e) {
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
      all.addAll(parsed);

      final pagination = res.data!['pagination'] as Map<String, dynamic>?;
      final lastPage = pagination?['last_page'] as int? ?? 1;
      if (page >= lastPage) break;
      page++;
    }
    return all;
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

  Future<UserModel?> getMyProfile() async {
    final res = await _api.get('/driver/profile');
    if (!res.success || res.data == null) return null;
    final d = res.data!['data'];
    if (d == null) return null;
    return UserModel.fromJson(d as Map<String, dynamic>);
  }

  Future<bool> toggleGps(String status) async {
    final res = await _api.patch('/driver/gps', {'gps_status': status});
    return res.success;
  }

  Future<bool> sendGpsLocation({
    required double latitude,
    required double longitude,
    required double speed,
    double? accuracy,
    double? heading,
    int? deviceTimestamp,
    String? deviceId,
  }) async {
    final body = <String, dynamic>{
      'latitude': latitude,
      'longitude': longitude,
      'speed': speed < 0 ? 0 : speed,
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

    final body = res.data;
    if (res.statusCode == 403 &&
        body != null &&
        body['error_type'] == 'route_mismatch') {
      return ScanQrResult.routeMismatch(RouteMismatchInfo.fromJson(body));
    }

    return ScanQrResult.error(res.message);
  }

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

  Future<Map<String, dynamic>?> getDailyReport(int busId) async {
    final res = await _api.get('/driver/buses/$busId/report');
    if (!res.success || res.data == null) return null;
    return res.data;
  }
}

class HalteService {
  final _api = ApiClient();

  Future<List<HalteModel>> getHaltes() async {
    final res = await _api.get('/haltes', params: {'all': 'true'});
    if (!res.success || res.data == null) return [];
    final raw = res.data!['data'];
    final list = raw is List ? raw : (raw?['data'] as List? ?? []);
    return list
        .map((e) => HalteModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<HalteModel>> searchHaltes(String query) async {
    final res = await _api.get('/haltes', params: {'q': query, 'all': 'true'});
    if (!res.success || res.data == null) return [];
    final raw = res.data!['data'];
    final list = raw is List ? raw : (raw?['data'] as List? ?? []);
    return list
        .map((e) => HalteModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

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

  Future<RouteModel?> getRoute(int routeId) async {
    final res = await _api.get('/routes/$routeId');
    if (!res.success || res.data == null) return null;
    final d = res.data!['data'] ?? res.data;
    if (d == null) return null;
    return RouteModel.fromJson(d as Map<String, dynamic>);
  }

  Future<RouteModel?> getRouteByBus(int busId) async {
    final res = await _api.get('/buses/$busId/route');
    if (!res.success || res.data == null) return null;
    final d = res.data!['data'];
    if (d == null) return null;
    return RouteModel.fromJson(d as Map<String, dynamic>);
  }

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

  Future<bool> updateRoute(int routeId, {String? namaRute, int? busId}) async {
    final body = <String, dynamic>{};
    if (namaRute != null) body['nama_rute'] = namaRute;
    if (busId != null) body['bus_id'] = busId;
    final res = await _api.put('/routes/$routeId', body);
    return res.success;
  }

  Future<bool> deleteRoute(int routeId) async {
    final res = await _api.delete('/routes/$routeId');
    return res.success;
  }

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

  Future<bool> updateRouteHalte(int routeHalteId, int urutan) async {
    final res =
        await _api.put('/route-haltes/$routeHalteId', {'urutan': urutan});
    return res.success;
  }

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
