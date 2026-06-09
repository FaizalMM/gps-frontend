import 'api_client.dart';
import '../models/models_api.dart';
import 'package:flutter/foundation.dart';

class BusService {
  final _api = ApiClient();

  Future<List<BusModel>> getBuses() async {
    final res = await _api.get('/buses');
    if (!res.success || res.data == null) return [];
    final raw = res.data!['data'];
    final list = raw is List ? raw : (raw?['data'] as List? ?? []);
    return list
        .map((e) => BusModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<BusModel?> getBus(int id) async {
    final res = await _api.get('/buses/$id');
    if (!res.success || res.data == null) return null;
    final data = res.data!['data'];
    if (data == null) return null;
    return BusModel.fromJson(data as Map<String, dynamic>);
  }

  Future<bool> createBus({
    required String kodeBus,
    required String platNomor,
    String status = 'aktif',
    String? namaRute,
  }) async {
    final body = {
      'kode_bus': kodeBus,
      'plat_nomor': platNomor,
      'status': status,
    };
    if (namaRute != null && namaRute.isNotEmpty) body['nama_rute'] = namaRute;
    final res = await _api.post('/buses', body);
    return res.success;
  }

  Future<bool> updateBus(
    int id, {
    String? kodeBus,
    String? platNomor,
    String? status,
    String? namaRute,
  }) async {
    final body = <String, dynamic>{};
    if (kodeBus != null) body['kode_bus'] = kodeBus;
    if (platNomor != null) body['plat_nomor'] = platNomor;
    if (status != null) body['status'] = status;
    if (namaRute != null) body['nama_rute'] = namaRute;
    final res = await _api.put('/buses/$id', body);
    return res.success;
  }

  Future<bool> deleteBus(int id) async {
    final res = await _api.delete('/buses/$id');
    return res.success;
  }

  Future<String?> uploadBusPhoto(int busId, String filePath) async {
    final res = await _api.uploadMultipart(
      '/buses/$busId/photo',
      filePath,
      'photo',
      method: 'POST',
    );
    if (res.success && res.data != null) {
      final data = res.data!['data'] ?? res.data!;
      return data['photo_url'] as String?;
    }
    return null;
  }

  final Set<String> _assigningKeys = {};

  Future<bool> assignDriver(int busId, int driverId,
      {String? tanggalMulai, String? tanggalSelesai}) async {
    final key = '$busId-$driverId';
    if (_assigningKeys.contains(key)) return true;
    _assigningKeys.add(key);

    try {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final body = <String, dynamic>{
        'driver_id': driverId,
        'tanggal_mulai': tanggalMulai ?? today,
      };
      if (tanggalSelesai != null) body['tanggal_selesai'] = tanggalSelesai;

      final res = await _api.post('/buses/$busId/drivers', body);
      return res.success;
    } finally {
      _assigningKeys.remove(key);
    }
  }

  Future<bool> assignDriverByUserId(int busId, UserModel driver,
      {String? tanggalMulai, String? tanggalSelesai}) async {
    if (driver.driverDetail != null) {
      return assignDriver(busId, driver.driverDetail!.id,
          tanggalMulai: tanggalMulai, tanggalSelesai: tanggalSelesai);
    }

    final res = await _api.get('/admin/users/${driver.id}');
    if (res.success && res.data != null) {
      final data = res.data!['data'] ?? res.data!;
      final driverData = data['driver'];
      if (driverData != null) {
        final driverId = driverData['id'] as int?;
        if (driverId != null) {
          return assignDriver(busId, driverId,
              tanggalMulai: tanggalMulai, tanggalSelesai: tanggalSelesai);
        }
      }
    }
    return false;
  }

  Future<bool> unassignDriver(int busId) async {
    try {
      final res = await _api.delete('/buses/$busId/drivers');
      return res.success;
    } catch (e) {
      debugPrint('Error unassigning driver: $e');
      return false;
    }
  }

  Future<bool> updateBusDriverAssignment(
    int pivotId, {
    String? tanggalMulai,
    String? tanggalSelesai,
  }) async {
    final body = <String, dynamic>{};
    if (tanggalMulai != null) body['tanggal_mulai'] = tanggalMulai;
    body['tanggal_selesai'] = tanggalSelesai;
    final res = await _api.put('/bus-driver/$pivotId', body);
    return res.success;
  }

  Future<Map<String, dynamic>?> getBusActiveDriver(int busId) async {
    try {
      final res = await _api.get('/buses/$busId/driver');
      if (!res.success || res.data == null) return null;
      final data = res.data!['data'] ?? res.data!;
      if (data is Map<String, dynamic>) return data;
      return null;
    } catch (e) {
      debugPrint('Error getBusActiveDriver: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getAvailableDrivers() async {
    try {
      final res = await _api.get('/drivers', params: {'per_page': '100'});
      if (!res.success || res.data == null) return [];
      final raw = res.data!['data'];
      final list =
          raw is Map ? (raw['data'] as List? ?? []) : (raw as List? ?? []);
      final today = DateTime.now().toIso8601String().substring(0, 10);
      return list.whereType<Map<String, dynamic>>().where((d) {
        final buses = d['buses'] as List? ?? [];
        final hasActiveBus = buses.any((b) {
          final end = (b as Map<String, dynamic>)['pivot']?['tanggal_selesai']
              as String?;
          return end == null || end.compareTo(today) >= 0;
        });
        return !hasActiveBus;
      }).toList();
    } catch (e) {
      debugPrint('Error getAvailableDrivers: $e');
      return [];
    }
  }

  Future<void> deactivateDriverOnOtherBuses(
      int targetBusId, int driverId) async {
    try {
      final res = await _api.get('/buses', params: {'per_page': '1000'});
      if (!res.success || res.data == null) return;
      final raw = res.data!['data'];
      final list = raw is List
          ? raw
          : (raw is Map ? (raw['data'] as List? ?? []) : <dynamic>[]);
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final futures = <Future>[];
      for (final b in list) {
        final busJson = b as Map<String, dynamic>;
        final busId = busJson['id'] as int? ?? 0;
        if (busId == targetBusId) continue;
        final drivers = busJson['drivers'] as List? ?? [];
        for (final d in drivers) {
          final dMap = d as Map<String, dynamic>;
          final did = dMap['id'] as int? ?? dMap['user_id'] as int? ?? 0;
          final pivotId = dMap['pivot']?['id'] as int?;
          final end = dMap['pivot']?['tanggal_selesai'] as String?;
          final active = end == null || end.compareTo(today) >= 0;
          if (pivotId != null && active && did == driverId) {
            futures
                .add(updateBusDriverAssignment(pivotId, tanggalSelesai: today));
          }
        }
      }
      await Future.wait(futures);
    } catch (e) {
      debugPrint('Error deactivateDriverOnOtherBuses: $e');
    }
  }

  Future<List<UserModel>> getDriverBusStudents(int busId) async {
    final res = await _api.get('/driver/buses/$busId/students');
    if (!res.success || res.data == null) return [];

    debugPrint('[BusService] raw data: ${res.data}');

    final wrapper = res.data!['data'];
    debugPrint('[BusService] wrapper type: ${wrapper.runtimeType}');

    final raw = wrapper is List
        ? wrapper
        : wrapper is Map
            ? (wrapper['data'] ?? wrapper['items'] ?? [])
            : [];
    debugPrint('[BusService] raw count: ${(raw as List).length}');
    final List<UserModel> result = [];
    for (final e in raw) {
      try {
        final student = e as Map<String, dynamic>;
        final user = student['user'] as Map<String, dynamic>?;

        final userId = user?['id'] ?? student['user_id'];

        if (userId == null) {
          debugPrint(
              '[BusService] SKIP student id=${student['id']}: userId null, user=$user');
          continue;
        }

        final merged = {
          'id': userId,
          'name': user?['name'] ?? student['name'] ?? 'Siswa',
          'email': user?['email'] ?? student['email'] ?? '',
          'role': user?['role'] ?? 'siswa',
          'photo': user?['photo'] ?? student['photo'],
          'photo_url': user?['photo_url'] ?? student['photo_url'],
          'created_at': user?['created_at'] ??
              student['created_at'] ??
              DateTime.now().toIso8601String(),
          'student': {
            'id': student['id'] ?? 0,
            'user_id': userId,
            'nis': student['nis'] ?? '',
            'sekolah': student['sekolah'] ?? '',
            'kelas': student['kelas'] ?? '',
            'alamat': student['alamat'] ?? '',
            'no_hp': student['no_hp'] ?? '',
            'halte_id': student['pivot']?['halte_id'] ?? student['halte_id'],
            'approval_status': student['approval_status'] ?? 'approved',
          },
        };
        result.add(UserModel.fromJson(merged));
        debugPrint(
            '[BusService] OK parsed student userId=$userId name=${merged['name']}');
      } catch (ex) {
        debugPrint('[BusService] ERROR parsing student item: $ex — data: $e');
        continue;
      }
    }
    debugPrint('[BusService] total parsed: ${result.length}');
    return result;
  }

  Future<List<UserModel>> getBusStudents(int busId) async {
    final res = await _api.get('/buses/$busId/students');
    if (!res.success || res.data == null) return [];
    final raw = res.data!['data'];
    final list = raw is List ? raw : (raw?['data'] as List? ?? []);
    return list.map((e) {
      final json = e as Map<String, dynamic>;
      if (json['user'] != null) {
        final userJson =
            Map<String, dynamic>.from(json['user'] as Map<String, dynamic>);
        return UserModel.fromJson({
          ...userJson,
          'role': 'siswa',
          'student': json,
        });
      }
      return UserModel.fromJson(json);
    }).toList();
  }

  Future<bool> assignStudentToBus(int busId, int studentId, int halteId) async {
    final res = await _api.post('/buses/$busId/students', {
      'student_id': studentId,
      'halte_id': halteId,
    });
    return res.success;
  }

  Future<bool> removeStudentFromBus(int busId, int studentId) async {
    final res = await _api.delete('/buses/$busId/students/$studentId');
    return res.success;
  }

  Future<List<BusModel>> getDriverBuses() async {
    final res = await _api.get('/driver/buses');
    if (!res.success || res.data == null) return [];
    final raw = res.data!['data'];
    final list = raw is List ? raw : [];
    return list
        .map((e) => BusModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<bool> hasValidToken() async {
    final token = await _api.getToken();
    return token != null && token.isNotEmpty;
  }

  List<BusModel> _parseDashboardList(Map<String, dynamic> responseData) {
    final outer = responseData['data'];
    List? list;
    if (outer is Map) {
      list = outer['data'] as List?;
    } else if (outer is List) {
      list = outer;
    }
    list ??= [];

    return list.map((e) {
      final json = e as Map<String, dynamic>;
      final driverRaw = json['driver'] as Map<String, dynamic>?;
      final driverNormalized = driverRaw != null
          ? {
              'id': driverRaw['id'],
              'user_id': driverRaw['id'],
              'user': {'id': driverRaw['id'], 'name': driverRaw['name']},
              'no_hp': driverRaw['phone'],
            }
          : null;
      return BusModel.fromJson({
        'id': json['bus_id'],
        'kode_bus': json['bus_code'],
        'plat_nomor': json['bus_plate'],
        'status': 'aktif',
        'gps_status': json['gps_status'],
        'current_position': json['current_position'],
        'driver': driverNormalized,
        'created_at': DateTime.now().toIso8601String(),
      });
    }).toList();
  }

  Future<({List<BusModel> buses, int statusCode})>
      getGpsDashboardWithStatus() async {
    final res = await _api.get('/gps-tracks/dashboard');
    if (res.statusCode == 401) {
      return (buses: <BusModel>[], statusCode: 401);
    }
    if (!res.success || res.data == null) {
      return (buses: <BusModel>[], statusCode: res.statusCode);
    }
    return (buses: _parseDashboardList(res.data!), statusCode: res.statusCode);
  }

  Future<List<BusModel>> getGpsDashboard() async {
    final res = await _api.get('/gps-tracks/dashboard');
    if (!res.success || res.data == null) return [];
    return _parseDashboardList(res.data!);
  }

  Future<BusModel?> getBusTracking(int busId) async {
    final res = await _api.get('/buses/$busId/gps/latest');
    if (!res.success || res.data == null) return null;
    final d = res.data!['data'] ?? res.data;
    if (d == null) return null;
    final json = d as Map<String, dynamic>;
    return BusModel.fromJson({
      'id': json['bus_id'],
      'kode_bus': json['bus_code'],
      'plat_nomor': json['bus_plate'],
      'status': 'aktif',
      'current_position': {
        'latitude': json['latitude'],
        'longitude': json['longitude'],
        'speed': json['speed'],
        'recorded_at': json['recorded_at'],
      },
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<({BusModel? bus, Map<String, dynamic>? myHalte, String? driverName})>
      getMyBusTrackingFull() async {
    final res = await _api.get('/student/bus/tracking');
    if (res.success && res.data != null) {
      final d = res.data!['data'] as Map<String, dynamic>?;
      if (d != null) {
        final pos = d['position'] as Map<String, dynamic>?;

        final gpsActive = d['gps_active'] as bool? ?? false;

        final bus = BusModel.fromJson({
          'id': d['bus_id'],
          'kode_bus': d['bus_code'],
          'plat_nomor': d['bus_plate'],
          'status': 'aktif',
          'gps_active': gpsActive,
          'driver': d['driver_name'] != null
              ? {
                  'user': {'name': d['driver_name']}
                }
              : null,
          'current_position': pos,
          'routes': d['routes'] ?? [],
          'created_at': DateTime.now().toIso8601String(),
        });

        if (gpsActive && pos != null) {
          bus.updateGps(
            latitude: (pos['latitude'] as num?)?.toDouble() ?? 0,
            longitude: (pos['longitude'] as num?)?.toDouble() ?? 0,
            speed: (pos['speed'] as num?)?.toDouble() ?? 0,
            gpsActive: true,
          );
        } else if (gpsActive) {
          bus.updateGps(latitude: 0, longitude: 0, speed: 0, gpsActive: true);
        } else {
          bus.updateGps(latitude: 0, longitude: 0, speed: 0, gpsActive: false);
        }

        final myHalte = d['my_halte'] as Map<String, dynamic>?;
        final driverName = d['driver_name'] as String?;
        return (bus: bus, myHalte: myHalte, driverName: driverName);
      }
    }

    final fallback = await _api.get('/student/bus');
    if (!fallback.success || fallback.data == null) {
      return (bus: null, myHalte: null, driverName: null);
    }
    final fd = fallback.data!['data'] as Map<String, dynamic>?;
    if (fd == null) return (bus: null, myHalte: null, driverName: null);

    final bus = BusModel.fromJson({
      'id': fd['id'] ?? fd['bus_id'],
      'kode_bus': fd['kode_bus'],
      'plat_nomor': fd['plat_nomor'],
      'status': fd['status'] ?? 'aktif',
      'gps_status': fd['gps_status'] ?? 'off',
      'driver': fd['driver_name'] != null
          ? {
              'user': {'name': fd['driver_name']}
            }
          : null,
      'routes': fd['routes'] ?? [],
      'created_at': DateTime.now().toIso8601String(),
    });
    bus.updateGps(latitude: 0, longitude: 0, speed: 0, gpsActive: false);

    final driverName = fd['driver_name'] as String?;
    return (bus: bus, myHalte: null, driverName: driverName);
  }

  Future<BusModel?> getMyBusTracking() async {
    final result = await getMyBusTrackingFull();
    return result.bus;
  }
}
