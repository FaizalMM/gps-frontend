import 'package:flutter/foundation.dart';

// ============================================================
// models_api.dart — Model yang sesuai dengan respons Laravel BE
// Setiap model punya fromJson() untuk parsing API response
// ============================================================

/// Helper: parse double dari String ATAU num (Laravel kadang kirim keduanya)
double _parseDouble(dynamic v, double fallback) {
  if (v == null) return fallback;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? fallback;
  return fallback;
}

// ── Enum ─────────────────────────────────────────────────────

enum UserRole { admin, driver, siswa }

enum AccountStatus { pending, active, rejected }

enum BusStatus { active, maintenance, inactive }

enum ApprovalStatus { pending, approved, rejected }

// ── User (dari /auth/me, /auth/login) ────────────────────────

class UserModel {
  final int id;
  String namaLengkap;
  String email;
  final UserRole role;
  String noHp;
  String alamat;
  AccountStatus status;
  String? qrCode;
  String? photoUrl;
  final DateTime createdAt;

  // Data siswa (jika role siswa)
  StudentDetail? studentDetail;
  // Data driver (jika role driver)
  DriverDetail? driverDetail;

  UserModel({
    required this.id,
    required this.namaLengkap,
    required this.email,
    required this.role,
    this.noHp = '',
    this.alamat = '',
    this.status = AccountStatus.active,
    this.qrCode,
    this.photoUrl,
    required this.createdAt,
    this.studentDetail,
    this.driverDetail,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final roleStr = json['role'] as String? ?? 'siswa';
    UserRole role;
    switch (roleStr) {
      case 'admin':
        role = UserRole.admin;
        break;
      case 'driver':
        role = UserRole.driver;
        break;
      default:
        role = UserRole.siswa;
    }

    StudentDetail? studentDetail;
    DriverDetail? driverDetail;

    if (json['student'] != null) {
      studentDetail =
          StudentDetail.fromJson(json['student'] as Map<String, dynamic>);
    }
    if (json['driver'] != null) {
      driverDetail =
          DriverDetail.fromJson(json['driver'] as Map<String, dynamic>);
    }

    // Approval status dari student
    AccountStatus status = AccountStatus.active;
    // Cek is_suspended dulu
    final isSuspended =
        json['is_suspended'] == true || json['is_suspended'] == 1;
    if (isSuspended) {
      status = AccountStatus.rejected;
    } else if (studentDetail != null) {
      switch (studentDetail.approvalStatus) {
        case ApprovalStatus.pending:
          status = AccountStatus.pending;
          break;
        case ApprovalStatus.rejected:
          status = AccountStatus.rejected;
          break;
        default:
          status = AccountStatus.active;
      }
    }

    return UserModel(
      id: json['id'] as int,
      namaLengkap: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: role,
      noHp: studentDetail?.noHp ?? driverDetail?.noHp ?? '',
      alamat: studentDetail?.alamat ?? driverDetail?.alamat ?? '',
      status: status,
      photoUrl: json['photo_url'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      studentDetail: studentDetail,
      driverDetail: driverDetail,
    );
  }

  // Untuk backward compat dengan UI yang pakai String id
  String get idStr => id.toString();

  // Dulu pakai password field — sekarang tidak ada (token dari BE)
  bool get isActive => status == AccountStatus.active;
}

// ── Detail Siswa ──────────────────────────────────────────────

class StudentDetail {
  final int id;
  final int userId;
  String nis;
  String sekolah;
  String kelas;
  String alamat;
  String noHp;
  ApprovalStatus approvalStatus;
  // Info bus & rute — diisi saat admin load student atau dari /student/bus
  int busId;
  int halteId;
  String namaBus;
  String namaRute;
  String namaHalte;

  StudentDetail({
    required this.id,
    required this.userId,
    required this.nis,
    required this.sekolah,
    required this.kelas,
    required this.alamat,
    required this.noHp,
    required this.approvalStatus,
    this.busId = 0,
    this.halteId = 0,
    this.namaBus = '',
    this.namaRute = '',
    this.namaHalte = '',
  });

  factory StudentDetail.fromJson(Map<String, dynamic> json) {
    ApprovalStatus approvalStatus;
    switch (json['approval_status'] as String? ?? 'pending') {
      case 'approved':
        approvalStatus = ApprovalStatus.approved;
        break;
      case 'rejected':
        approvalStatus = ApprovalStatus.rejected;
        break;
      default:
        approvalStatus = ApprovalStatus.pending;
    }
    // Bus info bisa datang dari nested 'bus' object atau flat fields
    final busJson = json['bus'] as Map<String, dynamic>?;
    final routeJson = busJson != null
        ? (busJson['routes'] as List?)?.firstOrNull as Map<String, dynamic>?
        : null;
    final halteJson = json['halte'] as Map<String, dynamic>?;

    return StudentDetail(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      nis: json['nis'] as String? ?? '',
      sekolah: json['sekolah'] as String? ?? '',
      kelas: json['kelas'] as String? ?? '',
      alamat: json['alamat'] as String? ?? '',
      noHp: json['no_hp'] as String? ?? '',
      approvalStatus: approvalStatus,
      busId: busJson?['id'] as int? ?? json['bus_id'] as int? ?? 0,
      halteId: halteJson?['id'] as int? ?? json['halte_id'] as int? ?? 0,
      namaBus:
          busJson?['kode_bus'] as String? ?? json['kode_bus'] as String? ?? '',
      namaRute: routeJson?['nama_rute'] as String? ??
          json['nama_rute'] as String? ??
          '',
      namaHalte: halteJson?['nama_halte'] as String? ??
          json['nama_halte'] as String? ??
          '',
    );
  }
}

// ── Detail Driver ─────────────────────────────────────────────

class DriverDetail {
  final int id;
  final int userId;
  String nik;
  String noHp;
  String alamat;

  DriverDetail({
    required this.id,
    required this.userId,
    required this.nik,
    required this.noHp,
    required this.alamat,
  });

  factory DriverDetail.fromJson(Map<String, dynamic> json) {
    return DriverDetail(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      nik: json['nik'] as String? ?? '',
      noHp: json['no_hp'] as String? ?? '',
      alamat: json['alamat'] as String? ?? '',
    );
  }
}

// ── Bus (dari /buses, /driver/buses) ─────────────────────────

class BusModel {
  final int id;
  String nama; // kode_bus dari BE
  String platNomor; // plat_nomor dari BE
  String rute; // nama rute (string)
  List<RouteModel> routeList; // data rute lengkap dengan halte & polyline
  BusStatus status;
  String driverId;
  String driverName;
  bool gpsActive;

  double latitude;
  double longitude;
  double speed;
  double heading;
  double accuracy; // meter — akurasi GPS terakhir
  DateTime? lastUpdate;

  final DateTime createdAt;

  BusModel({
    required this.id,
    required this.nama,
    required this.platNomor,
    this.rute = '',
    this.routeList = const [],
    this.status = BusStatus.active,
    this.driverId = '',
    this.driverName = '',
    this.gpsActive = false,
    this.latitude = -7.6298,
    this.longitude = 111.5239,
    this.speed = 0,
    this.heading = 0,
    this.accuracy = 0,
    this.lastUpdate,
    required this.createdAt,
  });

  String get idStr => id.toString();
  bool get isActive => status == BusStatus.active;

  factory BusModel.fromJson(Map<String, dynamic> json) {
    BusStatus busStatus;
    switch (json['status'] as String? ?? 'aktif') {
      case 'aktif':
        busStatus = BusStatus.active;
        break;
      case 'maintenance':
        busStatus = BusStatus.maintenance;
        break;
      default:
        busStatus = BusStatus.inactive;
    }

    // GPS dari current_position jika ada
    // Gunakan 0.0 sebagai sentinel value — bukan Madiun — agar bisa deteksi
    // apakah koordinat nyata sudah diterima atau masih nilai awal/kosong.
    double lat = 0.0, lng = 0.0, spd = 0;
    bool gpsOn = false;
    if (json['current_position'] != null) {
      final pos = json['current_position'] as Map<String, dynamic>;
      final rawLat = _parseDouble(pos['latitude'], 0.0);
      final rawLng = _parseDouble(pos['longitude'], 0.0);
      spd = _parseDouble(pos['speed'], 0);
      // Simpan koordinat asli — jangan fallback ke Madiun di sini.
      // Koordinat 0,0 akan difilter di _getCenter() dan marker layer.
      lat = rawLat;
      lng = rawLng;
    }
    // Baca gps_status dari berbagai kemungkinan struktur response:
    // 1. Langsung 'gps_status' (dari /gps-tracks/dashboard & /buses)
    // 2. Nested 'assignment.gps_status' (dari /auth/me & /auth/login untuk driver)
    String? rawGpsStatus = json['gps_status'] as String?;
    rawGpsStatus ??=
        (json['assignment'] as Map<String, dynamic>?)?['gps_status'] as String?;

    if (rawGpsStatus != null) {
      final statusOn = rawGpsStatus == 'on';
      // Dari /auth/me (bus driver sendiri): aktif jika status ON saja
      // Dari /gps-tracks/dashboard (admin polling): aktif jika status ON saja
      //   → koordinat mungkin belum ada saat driver baru toggle ON
      //   → backend sudah filter current_position=null jika GPS off
      //   → jadi gpsActive cukup ikut gps_status saja
      // Satu-satunya pengecualian: data dari loadBuses (/buses) yang tidak
      //   punya gps_status → gpsOn tetap false (default)
      gpsOn = statusOn;
    }
    // Fallback ke koordinat Madiun hanya untuk tampilan default (bukan GPS live)
    if (lat == 0.0) lat = -7.6298;
    if (lng == 0.0) lng = 111.5239;

    // Rute dari relasi
    String rute = '';
    List<RouteModel> routeList = [];
    if (json['routes'] != null && (json['routes'] as List).isNotEmpty) {
      final routesRaw = json['routes'] as List;
      rute = routesRaw.map((r) => r['nama_rute'] ?? r['name'] ?? '').join(', ');
      // Parse full RouteModel jika ada data halte/polyline
      routeList = routesRaw.map((r) {
        final rMap = r as Map<String, dynamic>;
        // Pastikan bus_id ada untuk RouteModel
        if (!rMap.containsKey('bus_id') && json['id'] != null) {
          rMap['bus_id'] = json['id'];
        }
        return RouteModel.fromJson(rMap);
      }).toList();
    }

    // Driver dari relasi — BusService return 'drivers' array (include historical)
    String driverId = '', driverName = '';

    // Try 1: Check 'drivers' array dan cari yang ACTIVE (tanggal_selesai = null)
    if (json['drivers'] != null && (json['drivers'] as List).isNotEmpty) {
      try {
        // Filter untuk assignment aktif (tanggal_selesai = null)
        final activeDrivers = (json['drivers'] as List)
            .where((d) =>
                (d as Map<String, dynamic>)['pivot']?['tanggal_selesai'] ==
                null)
            .toList();

        final driver = activeDrivers.isNotEmpty
            ? activeDrivers.first
            : (json['drivers'] as List).first;
        final d = driver as Map<String, dynamic>;
        driverId = d['user_id']?.toString() ?? '';
        driverName = d['user']?['name'] as String? ?? '';
        if (driverId.isNotEmpty && driverName.isNotEmpty) {
          debugPrint(
              '[BusModel.fromJson] Bus ${json['id']}: Found active driver - $driverName (ID: $driverId) from drivers array');
        }
      } catch (e) {
        debugPrint('[BusModel.fromJson] Error parsing drivers array: $e');
      }
    }
    // Try 2: Check 'active_driver' array (alternative naming)
    if (driverId.isEmpty &&
        json['active_driver'] != null &&
        (json['active_driver'] as List).isNotEmpty) {
      try {
        final d = (json['active_driver'] as List).first as Map<String, dynamic>;
        driverId = d['user_id']?.toString() ?? '';
        driverName = d['user']?['name'] as String? ?? '';
        if (driverId.isNotEmpty && driverName.isNotEmpty) {
          debugPrint(
              '[BusModel.fromJson] Bus ${json['id']}: Found active driver - $driverName (ID: $driverId) from active_driver array');
        }
      } catch (e) {
        debugPrint('[BusModel.fromJson] Error parsing active_driver array: $e');
      }
    }
    // Try 3: Check 'driver' object (dari POST response saat assign)
    if (driverId.isEmpty && json['driver'] != null) {
      try {
        final d = json['driver'] as Map<String, dynamic>;
        driverId = d['user_id']?.toString() ?? d['id']?.toString() ?? '';
        driverName =
            d['user']?['name'] as String? ?? d['name'] as String? ?? '';
        if (driverId.isNotEmpty && driverName.isNotEmpty) {
          debugPrint(
              '[BusModel.fromJson] Bus ${json['id']}: Found driver - $driverName (ID: $driverId) from driver object');
        }
      } catch (e) {
        debugPrint('[BusModel.fromJson] Error parsing driver object: $e');
      }
    }
    // Try 4: Check nested 'data.driver' (untuk POST response)
    if (driverId.isEmpty && json['data'] != null && json['data'] is Map) {
      try {
        final dataMap = json['data'] as Map<String, dynamic>;
        if (dataMap['driver'] != null) {
          final d = dataMap['driver'] as Map<String, dynamic>;
          driverId = d['user_id']?.toString() ?? d['id']?.toString() ?? '';
          driverName =
              d['user']?['name'] as String? ?? d['name'] as String? ?? '';
        }
      } catch (e) {
        debugPrint('[BusModel.fromJson] Error parsing data.driver: $e');
      }
    }

    return BusModel(
      id: json['id'] as int,
      nama: json['kode_bus'] as String? ?? json['bus_code'] as String? ?? 'Bus',
      platNomor:
          json['plat_nomor'] as String? ?? json['bus_plate'] as String? ?? '-',
      rute: rute,
      routeList: routeList,
      status: busStatus,
      driverId: driverId,
      driverName: driverName,
      gpsActive: gpsOn,
      latitude: lat,
      longitude: lng,
      speed: spd,
      accuracy: json['current_position'] != null
          ? _parseDouble((json['current_position'] as Map)['accuracy'], 0)
          : 0,
      heading: json['current_position'] != null
          ? _parseDouble((json['current_position'] as Map)['heading'], 0)
          : 0,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  // Update GPS dari tracking data
  void updateGps({
    required double latitude,
    required double longitude,
    required double speed,
    double heading = 0,
    double accuracy = 0,
    bool gpsActive = true,
  }) {
    this.latitude = latitude;
    this.longitude = longitude;
    this.speed = speed;
    this.heading = heading;
    this.accuracy = accuracy;
    this.gpsActive = gpsActive;
    lastUpdate = DateTime.now();
  }
}

// ── Halte ─────────────────────────────────────────────────────

class HalteModel {
  final int id;
  String namaHalte;
  String alamat;
  double latitude;
  double longitude;
  final DateTime createdAt;

  HalteModel({
    required this.id,
    required this.namaHalte,
    this.alamat = '',
    required this.latitude,
    required this.longitude,
    required this.createdAt,
  });

  String get idStr => id.toString();
  String get nama => namaHalte;
  set nama(String v) => namaHalte = v;

  factory HalteModel.fromJson(Map<String, dynamic> json) {
    return HalteModel(
      id: json['id'] as int,
      namaHalte: json['nama_halte'] as String? ?? '',
      alamat: json['alamat'] as String? ?? '',
      latitude: _parseDouble(json['latitude'], -7.6298),
      longitude: _parseDouble(json['longitude'], 111.5239),
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'nama_halte': namaHalte,
        'alamat': alamat,
        'latitude': latitude,
        'longitude': longitude,
      };
}

// ── Laporan Perjalanan ────────────────────────────────────────

class LaporanPerjalanan {
  final int id;
  final int busId;
  final String busNama;
  final String driverId;
  final String driverName;
  final DateTime tanggal;
  final String waktuOperasional;
  final double jarakTempuh;
  final int siswaTerangkut;
  final List<String> halteYangDilewati;

  LaporanPerjalanan({
    required this.id,
    required this.busId,
    required this.busNama,
    required this.driverId,
    required this.driverName,
    required this.tanggal,
    required this.waktuOperasional,
    required this.jarakTempuh,
    required this.siswaTerangkut,
    required this.halteYangDilewati,
  });

  factory LaporanPerjalanan.fromJson(Map<String, dynamic> json) {
    return LaporanPerjalanan(
      id: json['id'] as int,
      busId: json['bus_id'] as int,
      busNama: json['bus']?['kode_bus'] as String? ?? '',
      driverId: json['driver_id']?.toString() ?? '',
      driverName: json['driver']?['user']?['name'] as String? ?? '',
      tanggal:
          DateTime.tryParse(json['tanggal'] as String? ?? '') ?? DateTime.now(),
      waktuOperasional:
          '${json['jam_mulai'] ?? '-'} - ${json['jam_selesai'] ?? '-'}',
      jarakTempuh:
          _parseDouble(json['km_akhir'], 0) - _parseDouble(json['km_awal'], 0),
      siswaTerangkut: json['total_penumpang'] as int? ?? 0,
      halteYangDilewati: [],
    );
  }
}

// ── Attendance (absensi siswa) ────────────────────────────────

class AttendanceModel {
  final int id;
  final String qrId;
  final int studentId;
  final String studentName;
  final String studentNis;
  final int busId;
  final String busCode;
  final String? busName;
  final String halteName;
  final DateTime? waktuNaik;
  final DateTime? waktuTurun;
  final String status;
  // Info rute dari response scan
  final String namaRute;
  final String platNomor;

  AttendanceModel({
    required this.id,
    required this.qrId,
    required this.studentId,
    required this.studentName,
    required this.studentNis,
    required this.busId,
    required this.busCode,
    this.busName,
    required this.halteName,
    this.waktuNaik,
    this.waktuTurun,
    required this.status,
    this.namaRute = '',
    this.platNomor = '',
  });

  factory AttendanceModel.fromJson(Map<String, dynamic> json) {
    final routeInfo = json['route_info'] as Map<String, dynamic>?;
    return AttendanceModel(
      id: json['attendance_id'] as int? ?? json['id'] as int? ?? 0,
      qrId: json['qr_id'] as String? ?? '',
      studentId: json['student_id'] as int? ?? 0,
      studentName: json['student_name'] as String? ?? '',
      studentNis: json['student_nis'] as String? ?? '',
      busId: json['bus_id'] as int? ?? 0,
      busCode: json['bus_code'] as String? ?? '',
      busName: json['bus_name'] as String? ?? json['nama_rute'] as String?,
      halteName: json['halte_naik'] as String? ?? '',
      waktuNaik: json['waktu_naik'] != null
          ? DateTime.tryParse(json['waktu_naik'] as String)
          : null,
      waktuTurun: json['waktu_turun'] != null
          ? DateTime.tryParse(json['waktu_turun'] as String)
          : null,
      status: json['status'] as String? ?? '',
      namaRute: routeInfo?['nama_rute'] as String? ?? '',
      platNomor: routeInfo?['plat_nomor'] as String? ?? '',
    );
  }
}

// ── Route Mismatch Info — dipakai oleh scan driver ────────────
class RouteMismatchInfo {
  final String studentName;
  final String studentNis;
  final String scannedBusCode;
  final String scannedNamaRute;
  final String? correctBusCode;
  final String? correctNamaRute;

  RouteMismatchInfo({
    required this.studentName,
    required this.studentNis,
    required this.scannedBusCode,
    required this.scannedNamaRute,
    this.correctBusCode,
    this.correctNamaRute,
  });

  factory RouteMismatchInfo.fromJson(Map<String, dynamic> json) {
    final scanned = json['scanned_bus'] as Map<String, dynamic>? ?? {};
    final correct = json['correct_bus'] as Map<String, dynamic>?;
    return RouteMismatchInfo(
      studentName: json['student_name'] as String? ?? '',
      studentNis: json['student_nis'] as String? ?? '',
      scannedBusCode: scanned['kode_bus'] as String? ?? '',
      scannedNamaRute: scanned['nama_rute'] as String? ?? '-',
      correctBusCode: correct?['kode_bus'] as String?,
      correctNamaRute: correct?['nama_rute'] as String?,
    );
  }
}

// ── GPS Track data ────────────────────────────────────────────

class GpsTrackData {
  final double latitude;
  final double longitude;
  final double speed;
  final DateTime recordedAt;

  GpsTrackData({
    required this.latitude,
    required this.longitude,
    required this.speed,
    required this.recordedAt,
  });

  factory GpsTrackData.fromJson(Map<String, dynamic> json) {
    return GpsTrackData(
      latitude: _parseDouble(json['latitude'], 0),
      longitude: _parseDouble(json['longitude'], 0),
      speed: _parseDouble(json['speed'], 0),
      recordedAt: DateTime.tryParse(json['recorded_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

// ── Route (rute bus) ──────────────────────────────────────────
class RouteModel {
  final int id;
  String namaRute;
  final int busId;
  String busNama;
  String busPlatNomor;
  List<RouteHalteModel> haltes;
  List<RoutePolylinePoint> polyline;

  RouteModel({
    required this.id,
    required this.namaRute,
    required this.busId,
    this.busNama = '',
    this.busPlatNomor = '',
    this.haltes = const [],
    this.polyline = const [],
  });

  String get idStr => id.toString();

  factory RouteModel.fromJson(Map<String, dynamic> json) {
    List<RouteHalteModel> halteList = [];
    if (json['haltes'] != null) {
      int idx = 0;
      halteList = (json['haltes'] as List).map((h) {
        final hMap = h as Map<String, dynamic>;
        // Format 1 (dari /auth/me & /auth/login):
        //   { id, nama_halte, latitude, longitude, urutan }
        // Format 2 (dari /routes/{id}/haltes):
        //   { id, route_id, halte_id, urutan, halte: { id, nama_halte, ... } }
        if (hMap.containsKey('halte_id') || hMap.containsKey('route_id')) {
          // Format 2 — sudah sesuai RouteHalteModel
          return RouteHalteModel.fromJson(hMap);
        } else {
          // Format 1 — halte flat, wrap ke RouteHalteModel
          idx++;
          final urutan = hMap['urutan'] as int? ?? idx;
          return RouteHalteModel(
            id: hMap['id'] as int? ?? idx,
            routeId: json['id'] as int? ?? 0,
            halteId: hMap['id'] as int? ?? idx,
            urutan: urutan,
            halte: HalteModel(
              id: hMap['id'] as int? ?? idx,
              namaHalte: hMap['nama_halte'] as String? ?? '',
              alamat: hMap['alamat'] as String? ?? '',
              latitude: (hMap['latitude'] as num?)?.toDouble() ?? 0.0,
              longitude: (hMap['longitude'] as num?)?.toDouble() ?? 0.0,
              createdAt:
                  DateTime.tryParse(hMap['created_at'] as String? ?? '') ??
                      DateTime.now(),
            ),
          );
        }
      }).toList()
        ..sort((a, b) => a.urutan.compareTo(b.urutan));
    }
    List<RoutePolylinePoint> polylineList = [];
    if (json['polyline'] != null) {
      polylineList = (json['polyline'] as List)
          .map((p) => RoutePolylinePoint.fromJson(p as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.urutan.compareTo(b.urutan));
    }
    return RouteModel(
      id: json['id'] as int? ?? 0,
      namaRute: json['nama_rute'] as String? ?? '',
      busId: json['bus_id'] as int? ?? 0,
      busNama: json['bus']?['kode_bus'] as String? ?? '',
      busPlatNomor: json['bus']?['plat_nomor'] as String? ?? '',
      haltes: halteList,
      polyline: polylineList,
    );
  }
}

// ── RoutePolylinePoint — satu titik jalur polyline ────────────
class RoutePolylinePoint {
  final int urutan;
  final double latitude;
  final double longitude;

  const RoutePolylinePoint({
    required this.urutan,
    required this.latitude,
    required this.longitude,
  });

  factory RoutePolylinePoint.fromJson(Map<String, dynamic> json) {
    return RoutePolylinePoint(
      urutan: (json['urutan'] as num?)?.toInt() ?? 0,
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'urutan': urutan,
        'latitude': latitude,
        'longitude': longitude,
      };
}

// ── RouteHalte (urutan halte dalam rute) ──────────────────────
class RouteHalteModel {
  final int id;
  final int routeId;
  final int halteId;
  int urutan;
  HalteModel? halte;

  RouteHalteModel({
    required this.id,
    required this.routeId,
    required this.halteId,
    required this.urutan,
    this.halte,
  });

  String get idStr => id.toString();

  factory RouteHalteModel.fromJson(Map<String, dynamic> json) {
    HalteModel? halteData;
    if (json['halte'] != null) {
      halteData = HalteModel.fromJson(json['halte'] as Map<String, dynamic>);
    }
    return RouteHalteModel(
      id: json['id'] as int,
      routeId: json['route_id'] as int? ?? 0,
      halteId: json['halte_id'] as int? ?? 0,
      urutan: json['urutan'] as int? ?? 0,
      halte: halteData,
    );
  }
}

// ── ScanQrResult — hasil scan QR oleh driver ─────────────────
enum ScanQrResultType { success, routeMismatch, error }

class ScanQrResult {
  final ScanQrResultType type;
  final AttendanceModel? attendance;
  final RouteMismatchInfo? mismatch;
  final String message;

  ScanQrResult._({
    required this.type,
    this.attendance,
    this.mismatch,
    this.message = '',
  });

  factory ScanQrResult.success(AttendanceModel a) =>
      ScanQrResult._(type: ScanQrResultType.success, attendance: a);

  factory ScanQrResult.routeMismatch(RouteMismatchInfo m) =>
      ScanQrResult._(type: ScanQrResultType.routeMismatch, mismatch: m);

  factory ScanQrResult.error(String msg) =>
      ScanQrResult._(type: ScanQrResultType.error, message: msg);

  bool get isSuccess => type == ScanQrResultType.success;
  bool get isRouteMismatch => type == ScanQrResultType.routeMismatch;
}
