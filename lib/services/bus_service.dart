import 'api_client.dart';
import '../models/models_api.dart';
import 'package:flutter/foundation.dart';

class BusService {
  final _api = ApiClient();

  // ── Admin ─────────────────────────────────────────────────

  Future<List<BusModel>> getBuses() async {
    final res = await _api.get('/buses');
    if (!res.success || res.data == null) return [];
    final raw = res.data!['data'];
    // Response sekarang array langsung (bukan paginated)
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

  // Guard agar tidak double-call assignDriver
  final Set<String> _assigningKeys = {};

  Future<bool> assignDriver(int busId, int driverId) async {
    final key = '$busId-$driverId';
    if (_assigningKeys.contains(key)) return true; // sudah dalam proses
    _assigningKeys.add(key);

    try {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      debugPrint('[BusService] Assigning driver $driverId to bus $busId');
      final res = await _api.post('/buses/$busId/drivers', {
        'driver_id': driverId,
        'tanggal_mulai': today,
      });
      debugPrint(
          '[BusService] Assignment response: ${res.statusCode} - ${res.success}');
      if (res.data != null) {
        debugPrint('[BusService] Response data: ${res.data}');
      }
      // 201 = berhasil assign baru, 200 = sudah ada assignment aktif (reuse)
      return res.success;
    } finally {
      _assigningKeys.remove(key);
    }
  }

  /// Assign driver menggunakan users.id
  /// Otomatis resolve ke drivers.id via driverDetail atau fallback ke UserModel
  Future<bool> assignDriverByUserId(int busId, UserModel driver) async {
    debugPrint(
        '[assignDriverByUserId] Driver: ${driver.namaLengkap}, ID: ${driver.id}');
    debugPrint(
        '[assignDriverByUserId] Has driverDetail: ${driver.driverDetail != null}');

    // Prioritas: pakai driverDetail.id kalau ada
    if (driver.driverDetail != null) {
      debugPrint(
          '[assignDriverByUserId] Using driverDetail.id: ${driver.driverDetail!.id}');
      return assignDriver(busId, driver.driverDetail!.id);
    }

    // Fallback: fetch ulang user dari API untuk dapat driver profile
    debugPrint('[assignDriverByUserId] Fetching driver profile from API...');
    final res = await _api.get('/admin/users/${driver.id}');
    if (res.success && res.data != null) {
      final data = res.data!['data'] ?? res.data!;
      debugPrint('[assignDriverByUserId] API response: $data');
      final driverData = data['driver'];
      if (driverData != null) {
        final driverId = driverData['id'] as int?;
        debugPrint('[assignDriverByUserId] Resolved driver ID: $driverId');
        if (driverId != null) return assignDriver(busId, driverId);
      }
    }
    debugPrint('[assignDriverByUserId] Failed to resolve driver ID');
    return false;
  }

  /// Unassign driver dari bus (hapus assignment)
  Future<bool> unassignDriver(int busId) async {
    try {
      final res = await _api.delete('/buses/$busId/drivers');
      return res.success;
    } catch (e) {
      debugPrint('Error unassigning driver: $e');
      return false;
    }
  }

  Future<List<UserModel>> getBusStudents(int busId) async {
    final res = await _api.get('/buses/$busId/students');
    if (!res.success || res.data == null) return [];
    final raw = res.data!['data'];
    final list = raw is List ? raw : (raw?['data'] as List? ?? []);
    return list.map((e) {
      final json = e as Map<String, dynamic>;
      // Response dari getBusStudents: student object dengan relasi user
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

  // ── Driver ────────────────────────────────────────────────

  Future<List<BusModel>> getDriverBuses() async {
    final res = await _api.get('/driver/buses');
    if (!res.success || res.data == null) return [];
    final raw = res.data!['data'];
    final list = raw is List ? raw : [];
    return list
        .map((e) => BusModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Cek apakah token tersedia sebelum melakukan request
  Future<bool> hasValidToken() async {
    final token = await _api.getToken();
    return token != null && token.isNotEmpty;
  }

  /// Parsing response dashboard: backend kirim {'data': {'count': N, 'data': [...]}}
  /// Ekstrak list bus dari struktur nested tersebut.
  List<BusModel> _parseDashboardList(Map<String, dynamic> responseData) {
    // Struktur response: responseData = {'data': {'count': N, 'data': [...]}, ...}
    final outer = responseData['data'];
    List? list;
    if (outer is Map) {
      // {'data': {'count': N, 'data': [...]}} — struktur normal backend
      list = outer['data'] as List?;
    } else if (outer is List) {
      // Fallback jika backend kirim array langsung
      list = outer;
    }
    list ??= [];

    return list.map((e) {
      final json = e as Map<String, dynamic>;
      // Dashboard mengembalikan driver.name (bukan driver.user.name)
      // Normalisasi agar BusModel.fromJson bisa parsing dengan benar
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

  /// Versi getGpsDashboard yang juga mengembalikan status code HTTP
  /// sehingga polling bisa mendeteksi 401 dan berhenti sendiri.
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

  // ── GPS tracking (admin lihat semua bus) ──────────────────

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

  // ── Siswa: tracking bus yang di-assign ───────────────────

  /// Tracking bus untuk siswa — return BusModel dengan rute+halte lengkap
  /// plus my_halte (halte penjemputan siswa ini) sebagai field terpisah.
  Future<({BusModel? bus, Map<String, dynamic>? myHalte, String? driverName})>
      getMyBusTrackingFull() async {
    final res = await _api.get('/student/bus/tracking');
    if (!res.success || res.data == null) {
      return (bus: null, myHalte: null, driverName: null);
    }
    final d = res.data!['data'] as Map<String, dynamic>?;
    if (d == null) return (bus: null, myHalte: null, driverName: null);

    final pos = d['position'] as Map<String, dynamic>?;
    final gpsActive = (d['gps_active'] as bool? ?? false) && pos != null;

    final bus = BusModel.fromJson({
      'id': d['bus_id'],
      'kode_bus': d['bus_code'],
      'plat_nomor': d['bus_plate'],
      'status': 'aktif',
      'gps_active': gpsActive,
      // inject driver name jika ada
      'driver': d['driver_name'] != null
          ? {
              'user': {'name': d['driver_name']}
            }
          : null,
      // inject posisi langsung agar BusModel punya lat/lng/speed
      'current_position': gpsActive ? pos : null,
      'routes': d['routes'] ?? [],
      'created_at': DateTime.now().toIso8601String(),
    });

    // Terapkan posisi GPS ke field bus secara eksplisit
    if (gpsActive && pos != null) {
      bus.updateGps(
        latitude: (pos['latitude'] as num?)?.toDouble() ?? 0,
        longitude: (pos['longitude'] as num?)?.toDouble() ?? 0,
        speed: (pos['speed'] as num?)?.toDouble() ?? 0,
        gpsActive: true,
      );
    } else {
      // GPS off — reset posisi agar tidak tampilkan marker lama
      bus.updateGps(
        latitude: 0,
        longitude: 0,
        speed: 0,
        gpsActive: false,
      );
    }

    final myHalte = d['my_halte'] as Map<String, dynamic>?;
    final driverName = d['driver_name'] as String?;
    return (bus: bus, myHalte: myHalte, driverName: driverName);
  }

  /// Versi lama — tetap ada untuk kompatibilitas
  Future<BusModel?> getMyBusTracking() async {
    final result = await getMyBusTrackingFull();
    return result.bus;
  }
}
