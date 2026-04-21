// app_data_service.dart — COMPATIBILITY SHIM
// [PERBAIKAN] Ditambahkan GPS polling setiap 3 detik agar admin
// melihat posisi bus terbaru secara otomatis tanpa refresh manual.

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/models_api.dart';
import 'domain_services.dart';
import 'bus_service.dart';

class AppDataService {
  static final AppDataService _instance = AppDataService._internal();
  factory AppDataService() => _instance;
  AppDataService._internal();

  final _studentService = StudentService();
  final _driverService = DriverService();
  final _busService = BusService();
  final _halteService = HalteService();

  // ── Stream controllers untuk reaktif UI ──────────────────
  final _studentsCtrl = StreamController<List<UserModel>>.broadcast();
  final _busesCtrl = StreamController<List<BusModel>>.broadcast();
  final _haltesCtrl = StreamController<List<HalteModel>>.broadcast();

  Stream<List<UserModel>> get usersStream => _studentsCtrl.stream;
  Stream<List<BusModel>> get busesStream => _busesCtrl.stream;
  Stream<List<HalteModel>> get haltesStream => _haltesCtrl.stream;

  // ── In-memory cache ───────────────────────────────────────
  List<UserModel> _users = [];
  List<BusModel> _buses = [];
  List<HalteModel> _haltes = [];

  List<UserModel> get users => _users;
  List<BusModel> get buses => _buses;
  List<HalteModel> get haltes => _haltes;

  List<UserModel> get siswaList =>
      _users.where((u) => u.role == UserRole.siswa).toList();
  List<UserModel> get drivers =>
      _users.where((u) => u.role == UserRole.driver).toList();
  List<UserModel> get pendingUsers =>
      _users.where((u) => u.status == AccountStatus.pending).toList();

  // ── GPS Polling (admin) — auto-refresh setiap 3 detik ────
  Timer? _gpsPollingTimer;
  bool _gpsPollingActive = false;

  /// Callback yang dipanggil saat server mengembalikan 401.
  /// Set ini dari AdminDashboard untuk handle logout otomatis.
  VoidCallback? onUnauthorized;

  // ── Pending Students Polling — auto-refresh setiap 15 detik ─
  Timer? _pendingPollingTimer;
  bool _pendingPollingActive = false;
  int _lastKnownPendingCount = -1; // -1 = belum diinisialisasi

  /// Callback dipanggil saat ada siswa pending BARU masuk.
  /// Set dari AdminPendingScreen / AdminDashboard untuk tampilkan notifikasi.
  void Function(int jumlahBaru)? onNewPendingStudent;

  /// Mulai polling pending students. Panggil dari AdminDashboard setelah login.
  void startPendingPolling() {
    if (_pendingPollingActive) return;
    _pendingPollingActive = true;
    _pollPendingStudents();
    _pendingPollingTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_pendingPollingActive) _pollPendingStudents();
    });
  }

  /// Stop polling pending. Panggil saat logout.
  void stopPendingPolling() {
    _pendingPollingActive = false;
    _pendingPollingTimer?.cancel();
    _pendingPollingTimer = null;
    _lastKnownPendingCount = -1;
    onNewPendingStudent = null;
  }

  Future<void> _pollPendingStudents() async {
    try {
      final result = await _studentService.getPendingStudents();

      // [FIX] Hentikan polling jika server menolak token (401 Unauthorized)
      // Ini mencegah log 401 berulang-ulang saat belum/tidak terautentikasi
      if (result.statusCode == 401) {
        stopPendingPolling();
        onUnauthorized?.call();
        return;
      }

      if (!_pendingPollingActive) return;
      final pendingList = result.students;
      final newCount = pendingList.length;

      // Pertama kali polling — hanya set baseline, jangan notifikasi
      if (_lastKnownPendingCount == -1) {
        _lastKnownPendingCount = newCount;
        // Tetap update cache agar UI langsung tampil data terbaru
        _mergePendingIntoCache(pendingList);
        return;
      }

      // Ada siswa baru masuk sejak polling terakhir
      if (newCount > _lastKnownPendingCount) {
        final jumlahBaru = newCount - _lastKnownPendingCount;
        _lastKnownPendingCount = newCount;
        _mergePendingIntoCache(pendingList);
        onNewPendingStudent?.call(jumlahBaru);
      } else if (newCount != _lastKnownPendingCount) {
        // Jumlah berkurang (ada yang di-approve/reject) — update saja
        _lastKnownPendingCount = newCount;
        _mergePendingIntoCache(pendingList);
      }
    } catch (_) {}
  }

  /// Merge data pending terbaru dari server ke cache _users tanpa menghapus
  /// data driver/student lain yang sudah ada.
  void _mergePendingIntoCache(List<UserModel> pendingList) {
    final pendingIds = pendingList.map((u) => u.id).toSet();

    // Hapus entry pending lama dari cache, ganti dengan yang baru
    _users = [
      ..._users.where((u) =>
          u.role != UserRole.siswa ||
          u.status != AccountStatus.pending ||
          pendingIds.contains(u.id)),
    ];

    // Tambahkan pending baru yang belum ada di cache
    final existingIds = _users.map((u) => u.id).toSet();
    for (final p in pendingList) {
      if (!existingIds.contains(p.id)) {
        _users.add(p);
      }
    }

    _studentsCtrl.add(_users);
  }

  /// Mulai polling GPS. Pastikan token sudah tersimpan sebelum memanggil ini.
  void startGpsPolling() {
    if (_gpsPollingActive) return;
    _gpsPollingActive = true;
    _pollGps();
    _gpsPollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_gpsPollingActive) _pollGps();
    });
  }

  /// Stop polling. Panggil di dispose AdminDashboard atau saat logout.
  void stopGpsPolling() {
    _gpsPollingActive = false;
    _gpsPollingTimer?.cancel();
    _gpsPollingTimer = null;
    onUnauthorized = null;
  }

  Future<void> _pollGps() async {
    try {
      // Cek token dulu sebelum request — jika tidak ada, hentikan polling
      final hasToken = await _busService.hasValidToken();
      if (!hasToken) {
        stopGpsPolling();
        onUnauthorized?.call();
        return;
      }

      final result = await _busService.getGpsDashboardWithStatus();

      // Hentikan polling jika server menolak token (401 Unauthorized)
      if (result.statusCode == 401) {
        stopGpsPolling();
        onUnauthorized?.call();
        return;
      }

      final gpsBuses = result.buses;
      if (!_gpsPollingActive) return;

      bool changed = false;

      // Semua bus dari dashboard (termasuk yang GPS-nya off)
      // dipakai untuk update status di _buses cache
      for (final gpsBus in gpsBuses) {
        final idx = _buses.indexWhere((b) => b.id == gpsBus.id);
        if (idx >= 0) {
          final e = _buses[idx];

          // gpsActive dari polling adalah sumber kebenaran utama.
          // Selalu update jika status berubah — termasuk dari on→off
          final activeChanged = e.gpsActive != gpsBus.gpsActive;
          final latChanged = e.latitude != gpsBus.latitude;
          final lngChanged = e.longitude != gpsBus.longitude;
          final spdChanged = e.speed != gpsBus.speed;
          final nameChanged =
              gpsBus.driverName.isNotEmpty && e.driverName != gpsBus.driverName;

          if (activeChanged || latChanged || lngChanged || spdChanged) {
            // Jangan update posisi ke 0,0 — artinya belum ada GPS hari ini
            // Biarkan posisi terakhir yang valid tetap ditampilkan
            // hingga koordinat nyata masuk
            final hasRealCoords = gpsBus.latitude != 0 && gpsBus.longitude != 0;
            e.updateGps(
              latitude: hasRealCoords ? gpsBus.latitude : e.latitude,
              longitude: hasRealCoords ? gpsBus.longitude : e.longitude,
              speed: gpsBus.gpsActive ? gpsBus.speed : 0,
              gpsActive: gpsBus.gpsActive,
            );
            changed = true;
          }
          if (nameChanged) {
            e.driverName = gpsBus.driverName;
            changed = true;
          }
        } else {
          // Bus ada di dashboard tapi belum di cache — tambahkan
          _buses.add(gpsBus);
          changed = true;
        }
      }

      // Bus yang ada di cache tapi tidak ada di dashboard response:
      // set gpsActive = false (mungkin bus baru ditambah/dihapus)
      final dashboardIds = gpsBuses.map((b) => b.id).toSet();
      for (final bus in _buses) {
        if (!dashboardIds.contains(bus.id) && bus.gpsActive) {
          bus.updateGps(
            latitude: bus.latitude,
            longitude: bus.longitude,
            speed: 0,
            gpsActive: false,
          );
          changed = true;
        }
      }

      // Selalu emit ke stream agar UI driver baru aktif langsung kelihatan
      // meski changed = false (menghindari delay saat pertama kali GPS on)
      _busesCtrl.add(_buses);
    } catch (_) {}
  }

  // ── Load data dari API ────────────────────────────────────

  Future<void> loadAll() async {
    await Future.wait([
      loadStudents(),
      loadDrivers(),
      loadBuses(),
      loadHaltes(),
    ]);
  }

  // [FIX] loadStudents: getStudents() mengembalikan List<UserModel> langsung,
  // sedangkan getPendingStudents() mengembalikan record {students, statusCode}.
  // Jangan panggil .students pada List — itu akan crash.
  Future<void> loadStudents() async {
    final approved = await _studentService.getStudents();
    final pendingResult = await _studentService.getPendingStudents();
    final pending = pendingResult.students;

    final all = [...approved, ...pending];
    final seen = <int>{};
    _users = [
      ..._users.where((u) => u.role == UserRole.driver),
      ...all.where((u) => seen.add(u.id)),
    ];
    _studentsCtrl.add(_users);
  }

  Future<void> loadDrivers() async {
    final list = await _driverService.getDrivers();
    _users = [...list, ..._users.where((u) => u.role != UserRole.driver)];
    _studentsCtrl.add(_users);
  }

  Future<void> loadBuses() async {
    _buses = await _busService.getBuses();
    _busesCtrl.add(_buses);
  }

  Future<void> loadHaltes() async {
    _haltes = await _halteService.getHaltes();
    _haltesCtrl.add(_haltes);
  }

  // ── Student actions ───────────────────────────────────────

  Future<void> updateUserStatus(String userId, AccountStatus status,
      {int? studentDetailId}) async {
    final id = int.tryParse(userId);
    if (id == null) return;
    bool ok;
    if (status == AccountStatus.active) {
      final studentDbId = await _studentService.approveStudent(id);
      ok = studentDbId != null;
    } else {
      ok = await _studentService.rejectStudent(id, 'Ditolak oleh admin');
    }
    if (ok) await loadStudents();
  }

  /// Approve siswa dan return students.id — dipakai admin untuk assign bus
  /// langsung setelah approve tanpa perlu call terpisah.
  Future<int?> approveAndGetStudentId(String userId,
      {int? studentDetailId}) async {
    final id = int.tryParse(userId);
    if (id == null) return studentDetailId;
    // Jika studentDetailId sudah ada (dari cache), tidak perlu hit API lagi
    if (studentDetailId != null && studentDetailId > 0) {
      // Tetap approve via API
      await _studentService.approveStudent(id);
      await loadStudents();
      return studentDetailId;
    }
    final studentDbId = await _studentService.approveStudent(id);
    if (studentDbId != null) await loadStudents();
    return studentDbId;
  }

  Future<void> deleteUser(String userId) async {
    final id = int.tryParse(userId);
    if (id == null) return;
    await _studentService.deleteStudent(id);
    await loadStudents();
  }

  // ── Bus actions ───────────────────────────────────────────

  Future<bool> createBus({
    required String kodeBus,
    required String platNomor,
    String status = 'aktif',
    String? namaRute,
  }) async {
    final ok = await _busService.createBus(
        kodeBus: kodeBus,
        platNomor: platNomor,
        status: status,
        namaRute: namaRute);
    if (ok) await loadBuses();
    return ok;
  }

  Future<bool> updateBus(String busId,
      {String? kodeBus,
      String? platNomor,
      String? status,
      String? namaRute}) async {
    final id = int.tryParse(busId);
    if (id == null) return false;
    return _busService.updateBus(id,
        kodeBus: kodeBus,
        platNomor: platNomor,
        status: status,
        namaRute: namaRute);
  }

  Future<bool> deleteBus(String busId) async {
    final id = int.tryParse(busId);
    if (id == null) return false;
    final ok = await _busService.deleteBus(id);
    if (ok) await loadBuses();
    return ok;
  }

  // ── Halte actions ─────────────────────────────────────────

  Future<bool> createHalte({
    required String namaHalte,
    required double latitude,
    required double longitude,
    String alamat = '',
  }) async {
    final saved = await _halteService.createHalte(
        namaHalte: namaHalte,
        latitude: latitude,
        longitude: longitude,
        alamat: alamat);
    if (saved != null) await loadHaltes();
    return saved != null;
  }

  Future<bool> updateHalte(String halteId,
      {String? namaHalte,
      double? latitude,
      double? longitude,
      String? alamat}) async {
    final id = int.tryParse(halteId);
    if (id == null) return false;
    final ok = await _halteService.updateHalte(id,
        namaHalte: namaHalte,
        latitude: latitude,
        longitude: longitude,
        alamat: alamat);
    if (ok) await loadHaltes();
    return ok;
  }

  Future<bool> deleteHalte(String halteId) async {
    final id = int.tryParse(halteId);
    if (id == null) return false;
    final ok = await _halteService.deleteHalte(id);
    if (ok) await loadHaltes();
    return ok;
  }

  // ── GPS (driver) ──────────────────────────────────────────

  Future<List<BusModel>> getGpsDashboard() => _busService.getGpsDashboard();

  void updateBusLocation({
    required String busId,
    required double latitude,
    required double longitude,
    required double speed,
  }) {
    final bus = _buses.firstWhere(
      (b) => b.idStr == busId,
      orElse: () => _buses.isEmpty
          ? BusModel(id: 0, nama: '', platNomor: '', createdAt: DateTime.now())
          : _buses.first,
    );
    bus.updateGps(latitude: latitude, longitude: longitude, speed: speed);
    _busesCtrl.add(_buses);
  }

  // ── Helpers ───────────────────────────────────────────────

  bool emailExists(String email) =>
      _users.any((u) => u.email.toLowerCase() == email.toLowerCase());

  UserModel? login(String email, String password) => null;
  void logout() {}

  BusModel? getDriverBus(String driverId) {
    try {
      return _buses.firstWhere((b) => b.driverId == driverId);
    } catch (_) {
      return _buses.isNotEmpty ? _buses.first : null;
    }
  }

  void registerSiswa(
      {required String namaLengkap,
      required String email,
      required String noHp,
      required String alamat,
      required String password}) {}

  void updateUser(UserModel user) {}
  void addHalte(HalteModel h) => _haltes.add(h);
  void updateHalteLocal(HalteModel h) {
    final idx = _haltes.indexWhere((x) => x.id == h.id);
    if (idx >= 0) _haltes[idx] = h;
  }

  void deleteHalteLocal(String halteId) =>
      _haltes.removeWhere((h) => h.idStr == halteId);
  LaporanPerjalanan? getLaporanByDriver(String driverId) => null;
}
