import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/models_api.dart';
import '../../services/auth_provider.dart';
import '../../services/app_data_service.dart';
import '../../services/domain_services.dart';
import '../../services/bus_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/bus_map_widget.dart';
import '../auth/login_screen.dart';
import '../common/edit_profile_screen.dart';
import 'qr_code_screen.dart';

class SiswaDashboard extends StatefulWidget {
  const SiswaDashboard({super.key});
  @override
  State<SiswaDashboard> createState() => _SiswaDashboardState();
}

class _SiswaDashboardState extends State<SiswaDashboard> {
  int _currentIndex = 0;
  final AppDataService _dataService = AppDataService();

  @override
  Widget build(BuildContext context) {
    final currentUser = context.read<AuthProvider>().currentUser!;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_currentIndex != 0) {
          setState(() => _currentIndex = 0);
        }
        // Kalau sudah di tab 0, tidak lakukan apa-apa (cegah layar hitam)
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: IndexedStack(
          index: _currentIndex,
          children: [
            _SiswaHomeTab(
                siswa: currentUser,
                dataService: _dataService,
                onSwitchTab: (i) => setState(() => _currentIndex = i)),
            _SiswaTrackingTab(dataService: _dataService),
            QrCodeScreen(
              siswa: currentUser,
              // onBack: kembali ke tab Beranda (index 0) tanpa Navigator.pop
              // sehingga tidak terjadi layar hitam saat ada di dalam IndexedStack
              onBack: () => setState(() => _currentIndex = 0),
            ),
            _SiswaProfileTab(siswa: currentUser),
          ],
        ),
        bottomNavigationBar: MobitraBottomNav(
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
          items: const [
            BottomNavItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                label: 'Beranda'),
            BottomNavItem(
                icon: Icons.map_outlined,
                activeIcon: Icons.map_rounded,
                label: 'Lacak'),
            BottomNavItem(
                icon: Icons.qr_code_outlined,
                activeIcon: Icons.qr_code_rounded,
                label: 'ID Saya'),
            BottomNavItem(
                icon: Icons.person_outline,
                activeIcon: Icons.person_rounded,
                label: 'Profil'),
          ],
        ),
      ), // Scaffold
    ); // PopScope
  }
}

// ══════════════════════════════════════════════════════════════
// HOME TAB
// ══════════════════════════════════════════════════════════════
class _SiswaHomeTab extends StatefulWidget {
  final UserModel siswa;
  final AppDataService dataService;
  final Function(int) onSwitchTab;
  const _SiswaHomeTab(
      {required this.siswa,
      required this.dataService,
      required this.onSwitchTab});
  @override
  State<_SiswaHomeTab> createState() => _SiswaHomeTabState();
}

class _SiswaHomeTabState extends State<_SiswaHomeTab>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseAnim;
  Position? _userLocation;
  // ID bus yang di-assign ke siswa ini — diambil dari studentDetail
  int? _myBusId;
  // Nama bus & driver yang di-assign ke siswa ini
  String? _myBusName;
  String? _myDriverName;
  bool _loadingBusInfo = true;

  @override
  void initState() {
    super.initState();
    _pulseAnim =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat(reverse: true);
    _getLocation();
    _loadMyBusId();
  }

  @override
  void dispose() {
    _pulseAnim.dispose();
    super.dispose();
  }

  /// Ambil bus_id milik siswa ini dari backend
  Future<void> _loadMyBusId() async {
    try {
      final result = await BusService().getMyBusTrackingFull();
      if (!mounted) return;
      if (result.bus != null) {
        setState(() {
          _myBusId = result.bus!.id;
          _myBusName = result.bus!.nama;
          // Prioritas: driverName dari field baru, fallback ke BusModel.driverName
          _myDriverName = (result.driverName?.isNotEmpty == true)
              ? result.driverName
              : (result.bus!.driverName.isNotEmpty
                  ? result.bus!.driverName
                  : null);
          _loadingBusInfo = false;
        });
      } else {
        if (mounted) setState(() => _loadingBusInfo = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loadingBusInfo = false);
    }
  }

  Future<void> _getLocation() async {
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied)
        await Geolocator.requestPermission();
      final pos = await Geolocator.getCurrentPosition();
      if (mounted) setState(() => _userLocation = pos);
    } catch (_) {}
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 11) return 'Selamat pagi';
    if (h < 15) return 'Selamat siang';
    if (h < 18) return 'Selamat sore';
    return 'Selamat malam';
  }

  String _eta(BusModel bus) {
    if (_userLocation == null) return '— mnt';
    const d = Distance();
    final dist = d.as(LengthUnit.Meter, LatLng(bus.latitude, bus.longitude),
        LatLng(_userLocation!.latitude, _userLocation!.longitude));
    final mins = (dist / (bus.speed.clamp(5, 60) / 3.6 * 60)).ceil();
    if (mins <= 1) return '< 1 mnt';
    if (mins > 60) return '> 1 jam';
    return '$mins mnt';
  }

  @override
  Widget build(BuildContext context) {
    final first = widget.siswa.namaLengkap.split(' ').first;
    return ColoredBox(
      color: AppColors.background,
      child: SafeArea(
        child: SingleChildScrollView(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── Header ────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(children: [
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('${_greeting()}, $first 👋',
                          style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13,
                              color: AppColors.textGrey)),
                      const Text('Pantau busmu\nsekarang',
                          style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.black,
                              height: 1.2)),
                    ])),
                // Notif bell
                GestureDetector(
                  onTap: () => _showNotifSheet(context),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(13),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 10,
                              offset: const Offset(0, 2))
                        ]),
                    child: const Icon(Icons.notifications_outlined,
                        size: 22, color: AppColors.black),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 20),

            // ── Bus status card — hanya bus milik siswa ini ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _loadingBusInfo
                  ? _LoadingBusCard()
                  : StreamBuilder<List<BusModel>>(
                      stream: widget.dataService.busesStream,
                      builder: (_, s) {
                        final buses = s.data ?? widget.dataService.buses;

                        BusModel? myBus;
                        if (_myBusId != null) {
                          try {
                            myBus = buses.firstWhere(
                                (b) => b.id == _myBusId && b.gpsActive);
                          } catch (_) {
                            try {
                              myBus = buses.firstWhere((b) => b.id == _myBusId);
                            } catch (_) {}
                          }
                        }

                        if (_myBusId == null) {
                          return _NoBusAssignedCard();
                        }
                        if (myBus == null || !myBus.gpsActive) {
                          return _BusNotActiveCard(
                            busName: _myBusName,
                            driverName: _myDriverName,
                            onTrack: () => widget.onSwitchTab(1),
                          );
                        }
                        return _BusCard(
                            bus: myBus,
                            eta: _eta(myBus),
                            pulseAnim: _pulseAnim,
                            onTrack: () => widget.onSwitchTab(1));
                      },
                    ),
            ),
            const SizedBox(height: 12),

            // ── Info Bus & Driver siswa ───────────────────────
            if (!_loadingBusInfo && _myBusName != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2))
                    ],
                  ),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(11)),
                      child: const Icon(Icons.directions_bus_rounded,
                          color: AppColors.primary, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Bus saya: $_myBusName',
                              style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.black),
                            ),
                            const SizedBox(height: 2),
                            Row(children: [
                              const Icon(Icons.person_rounded,
                                  size: 12, color: AppColors.textGrey),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  _myDriverName != null
                                      ? 'Driver: $_myDriverName'
                                      : 'Driver belum ditugaskan',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 12,
                                      color: AppColors.textGrey),
                                ),
                              ),
                            ]),
                          ]),
                    ),
                  ]),
                ),
              ),
            const SizedBox(height: 12),

            // ── Quick actions (2x2 grid — lebih besar, jelas) ─
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(children: [
                Row(children: [
                  _QAction(
                      icon: Icons.qr_code_2_rounded,
                      label: 'ID & QR\nSaya',
                      color: AppColors.primary,
                      bg: AppColors.primaryLight,
                      onTap: () => widget.onSwitchTab(2)),
                  const SizedBox(width: 12),
                  _QAction(
                      icon: Icons.map_rounded,
                      label: 'Lacak\nBus',
                      color: AppColors.blue,
                      bg: const Color(0xFFE3F2FD),
                      onTap: () => widget.onSwitchTab(1)),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  _QAction(
                      icon: Icons.location_on_rounded,
                      label: 'Info\nHalte',
                      color: AppColors.purple,
                      bg: const Color(0xFFF3E5F5),
                      onTap: () => _showHalteSheet(context)),
                  const SizedBox(width: 12),
                  _QAction(
                      icon: Icons.notifications_active_rounded,
                      label: 'Atur\nNotifikasi',
                      color: AppColors.orange,
                      bg: AppColors.orange.withValues(alpha: 0.1),
                      onTap: () => _showNotifSettingSheet(context)),
                ]),
              ]),
            ),
            const SizedBox(height: 24),

            // ── Info armada aktif ─────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                const Expanded(
                    child: Text('Bus Beroperasi',
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.black))),
                StreamBuilder<List<BusModel>>(
                  stream: widget.dataService.busesStream,
                  builder: (_, s) {
                    final n = (s.data ?? widget.dataService.buses)
                        .where((b) => b.gpsActive)
                        .length;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(20)),
                      child: Text('$n aktif',
                          style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary)),
                    );
                  },
                ),
              ]),
            ),
            const SizedBox(height: 10),

            StreamBuilder<List<BusModel>>(
              stream: widget.dataService.busesStream,
              builder: (_, s) {
                final buses = (s.data ?? widget.dataService.buses)
                    .where((b) => b.gpsActive)
                    .toList();
                if (buses.isEmpty)
                  return const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Center(
                        child: Text('Belum ada bus beroperasi',
                            style: TextStyle(
                                fontFamily: 'Poppins',
                                color: AppColors.textGrey))),
                  );
                return Column(
                  children: buses
                      .map((bus) => Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                            child: _BusListTile(
                                bus: bus,
                                eta: _eta(bus),
                                onTap: () => widget.onSwitchTab(1)),
                          ))
                      .toList(),
                );
              },
            ),
            const SizedBox(height: 30),
          ]),
        ),
      ), // SafeArea
    ); // ColoredBox
  }

  void _showNotifSheet(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      builder: (_) => const _SimpleSheet(
          title: 'Notifikasi',
          child: Column(children: [
            _NotifTile(
                icon: Icons.directions_bus_rounded,
                color: AppColors.primary,
                title: 'Bus memasuki rute',
                time: '5 mnt lalu'),
            _NotifTile(
                icon: Icons.location_on_rounded,
                color: AppColors.orange,
                title: 'Bus 2 halte lagi tiba',
                time: '12 mnt lalu'),
            _NotifTile(
                icon: Icons.check_circle_rounded,
                color: AppColors.blue,
                title: 'QR berhasil di-scan',
                time: 'Kemarin'),
          ])),
    );
  }

  void _showHalteSheet(BuildContext ctx) {
    // Bug 7 Fix: ambil halte dari rute bus siswa, bukan semua halte
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        maxChildSize: 0.85,
        minChildSize: 0.3,
        builder: (_, ctrl) => _HalteRouteSheet(
          dataService: widget.dataService,
          scrollCtrl: ctrl,
        ),
      ),
    );
  }

  void _showNotifSettingSheet(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      builder: (_) => const _SimpleSheet(
          title: 'Pengaturan Notifikasi',
          child: Column(children: [
            _ToggleTile(
                label: 'Bus hampir tiba (< 5 menit)', initialValue: true),
            _ToggleTile(label: 'Bus mulai beroperasi', initialValue: true),
            _ToggleTile(
                label: 'Bus tidak beroperasi hari ini', initialValue: false),
            _ToggleTile(label: 'QR berhasil di-scan', initialValue: true),
          ])),
    );
  }
}

// ── Tracking Tab ─────────────────────────────────────────────
class _SiswaTrackingTab extends StatefulWidget {
  final AppDataService dataService;
  const _SiswaTrackingTab({required this.dataService});
  @override
  State<_SiswaTrackingTab> createState() => _SiswaTrackingTabState();
}

class _SiswaTrackingTabState extends State<_SiswaTrackingTab>
    with SingleTickerProviderStateMixin {
  // ── Data bus & attendance ────────────────────────────────
  BusModel? _myBus;
  Map<String, dynamic>? _myHalte;
  String? _driverName;
  bool _loadingBus = true;

  // Status absensi hari ini
  // null = belum load, 'pending' = QR belum discan, 'checked_in' = sudah naik,
  // 'checked_out'/'not_checked_out' = sudah turun
  String? _attendanceStatus;
  String? _waktuNaik;
  String? _waktuTurun;
  String? _halteNaik;
  bool _loadingAttendance = true;

  // ── Timer & service ──────────────────────────────────────
  Timer? _busRefreshTimer;
  Timer? _attendanceTimer;
  final AppDataService _busDataService = AppDataService();
  final MapController _mapController = MapController();

  // ── Animasi pulse ────────────────────────────────────────
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 1))
          ..repeat(reverse: true);
    _pulseAnim = Tween(begin: 0.5, end: 1.0).animate(_pulseCtrl);

    // Mulai GPS polling agar posisi bus update realtime (tiap 3 detik)
    _busDataService.startGpsPolling();

    _loadAll();

    // Auto-refresh bus tiap 5 detik
    _busRefreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) _refreshBusPosition();
    });

    // Auto-refresh attendance tiap 8 detik (deteksi perubahan status)
    _attendanceTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted) _loadAttendance(silent: true);
    });
  }

  @override
  void dispose() {
    _busRefreshTimer?.cancel();
    _attendanceTimer?.cancel();
    _busDataService.stopGpsPolling();
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── Load semua data ──────────────────────────────────────

  Future<void> _loadAll() async {
    await Future.wait([
      _loadBus(),
      _loadAttendance(),
    ]);
  }

  Future<void> _loadBus({bool silent = false}) async {
    if (!silent && mounted) setState(() => _loadingBus = true);
    try {
      final result = await BusService().getMyBusTrackingFull();
      if (!mounted) return;
      setState(() {
        _myBus = result.bus;
        _myHalte = result.myHalte;
        _driverName = result.driverName;
        _loadingBus = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingBus = false);
    }
  }

  // Refresh posisi bus dari GPS polling stream (lebih ringan dari full reload)
  Future<void> _refreshBusPosition() async {
    if (_myBus == null) return;
    try {
      final result = await BusService().getMyBusTrackingFull();
      if (!mounted) return;
      final updatedBus = result.bus;
      if (updatedBus == null) return;
      setState(() {
        _myBus = updatedBus;
        if (result.driverName != null) _driverName = result.driverName;
        // Pindahkan kamera hanya jika bus aktif GPS
        if (updatedBus.gpsActive && updatedBus.latitude != 0) {
          _mapController.move(
            LatLng(updatedBus.latitude, updatedBus.longitude),
            _mapController.camera.zoom,
          );
        }
      });
    } catch (_) {}
  }

  Future<void> _loadAttendance({bool silent = false}) async {
    if (!silent && mounted) setState(() => _loadingAttendance = true);
    try {
      final res = await StudentService().getMyAttendanceToday(0);
      if (!mounted) return;
      final list = res?['data'];
      if (list is List && list.isNotEmpty) {
        final latest = list.last as Map<String, dynamic>;
        final status = latest['status'] as String? ?? 'pending';
        final wn = latest['waktu_naik'] as String?;
        final wt = latest['waktu_turun'] as String?;
        setState(() {
          _attendanceStatus = status;
          _waktuNaik = wn != null ? _fmtTime(wn) : null;
          _waktuTurun = wt != null ? _fmtTime(wt) : null;
          _halteNaik = latest['halte_naik'] as String?;
          _loadingAttendance = false;
        });
      } else {
        setState(() {
          _attendanceStatus = null;
          _waktuNaik = null;
          _waktuTurun = null;
          _halteNaik = null;
          _loadingAttendance = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingAttendance = false);
    }
  }

  // ── Helper ───────────────────────────────────────────────

  String _fmtTime(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }

  String _etaKeHalte() {
    if (_myBus == null || !_myBus!.gpsActive || _myBus!.latitude == 0) {
      return 'Bus belum aktif';
    }
    final halte = _myHalte;
    if (halte == null) return '—';
    final hLat = (halte['latitude'] as num?)?.toDouble() ?? 0;
    final hLng = (halte['longitude'] as num?)?.toDouble() ?? 0;
    if (hLat == 0 && hLng == 0) return '—';
    const d = Distance();
    final dist = d.as(LengthUnit.Meter,
        LatLng(_myBus!.latitude, _myBus!.longitude), LatLng(hLat, hLng));
    if (dist < 50) return 'Hampir tiba!';
    final speed = _myBus!.speed.clamp(5.0, 60.0);
    final mins = (dist / (speed / 3.6 * 60)).ceil();
    if (mins <= 1) return '< 1 menit';
    if (mins > 60) return '> 1 jam';
    return '$mins menit lagi';
  }

  bool get _isOnBus => _attendanceStatus == 'checked_in';

  bool get _isDone =>
      _attendanceStatus == 'checked_out' ||
      _attendanceStatus == 'not_checked_out';

  // ── Build ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final buses = _myBus != null ? [_myBus!] : <BusModel>[];

    return ColoredBox(
      color: AppColors.background,
      child: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Header ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(children: [
              const Expanded(
                  child: Text('Lacak Bus',
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.black))),
              // Status badge realtime
              AnimatedBuilder(
                animation: _pulseAnim,
                builder: (_, __) => Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _myBus != null && _myBus!.gpsActive
                        ? AppColors.primary
                            .withValues(alpha: 0.1 + 0.1 * _pulseAnim.value)
                        : AppColors.surface2,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: _myBus != null && _myBus!.gpsActive
                            ? AppColors.primary.withValues(alpha: 0.4)
                            : AppColors.lightGrey),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: _myBus != null && _myBus!.gpsActive
                            ? AppColors.primary
                            : AppColors.textGrey,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _myBus != null && _myBus!.gpsActive ? 'Live' : 'Offline',
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _myBus != null && _myBus!.gpsActive
                              ? AppColors.primary
                              : AppColors.textGrey),
                    ),
                  ]),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _loadAll(),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.refresh_rounded,
                      size: 18, color: AppColors.primary),
                ),
              ),
            ]),
          ),

          // ── Status absensi (banner atas peta) ───────────
          if (!_loadingAttendance) _buildAttendanceBanner(),

          // ── Peta ────────────────────────────────────────
          Expanded(
            child: _loadingBus
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary))
                : _myBus == null
                    ? _buildNoBusView()
                    : (!_myBus!.gpsActive || _myBus!.latitude == 0)
                        ? _buildGpsOffView()
                        : Stack(children: [
                            BusMapWidget(
                              buses: buses,
                              height: double.infinity,
                              showAllBuses: true,
                              interactive: true,
                              showRoutes: true,
                              routes: _myBus?.routeList ?? [],
                              mapController: _mapController,
                              userLocation: null,
                            ),
                            // Overlay saat siswa sudah di dalam bus
                            if (_isOnBus)
                              Positioned(
                                top: 12,
                                left: 12,
                                right: 12,
                                child: _OnBusOverlay(
                                  busName: _myBus!.nama,
                                  speed: _myBus!.speed,
                                  waktuNaik: _waktuNaik,
                                  halteNaik: _halteNaik,
                                ),
                              ),
                            // Alert bus hampir tiba (sebelum naik)
                            if (!_isOnBus && !_isDone && _myHalte != null)
                              _buildArrivalAlert(),
                          ]),
          ),

          // ── Info card bawah ──────────────────────────────
          if (!_loadingBus && _myBus != null) _buildBottomCard(),
        ]),
      ),
    );
  }

  // ── Banner status absensi ────────────────────────────────

  Widget _buildAttendanceBanner() {
    if (_attendanceStatus == null) {
      // Belum ada absensi hari ini — belum naik
      return _StatusBanner(
        color: AppColors.surface2,
        borderColor: AppColors.lightGrey,
        icon: Icons.qr_code_2_rounded,
        iconColor: AppColors.textGrey,
        title: 'Belum naik bus hari ini',
        subtitle: 'Tunjukkan QR Code saat bus tiba di haltemu',
        badge: null,
      );
    }
    if (_attendanceStatus == 'pending') {
      return _StatusBanner(
        color: const Color(0xFFFFF8E1),
        borderColor: AppColors.orange.withValues(alpha: 0.4),
        icon: Icons.qr_code_2_rounded,
        iconColor: AppColors.orange,
        title: 'QR sudah siap, menunggu scan driver',
        subtitle: 'Tunjukkan QR Code kamu ke driver',
        badge: null,
      );
    }
    if (_isOnBus) {
      return _StatusBanner(
        color: const Color(0xFFE8F5E9),
        borderColor: Colors.green.withValues(alpha: 0.4),
        icon: Icons.directions_bus_rounded,
        iconColor: Colors.green,
        title: 'Kamu sedang dalam perjalanan 🚌',
        subtitle: _waktuNaik != null
            ? 'Naik jam $_waktuNaik${_halteNaik != null ? " di $_halteNaik" : ""}'
            : 'Sudah check-in',
        badge: 'ON TRIP',
        badgeColor: Colors.green,
      );
    }
    if (_isDone) {
      return _StatusBanner(
        color: AppColors.primaryLight,
        borderColor: AppColors.primary.withValues(alpha: 0.3),
        icon: Icons.check_circle_rounded,
        iconColor: AppColors.primary,
        title: 'Perjalanan hari ini selesai ✅',
        subtitle: _waktuNaik != null && _waktuTurun != null
            ? 'Naik $_waktuNaik — Turun $_waktuTurun'
            : 'Sudah checkout',
        badge: 'SELESAI',
        badgeColor: AppColors.primary,
      );
    }
    return const SizedBox.shrink();
  }

  // ── Overlay saat di dalam bus (di atas peta) ─────────────

  // ── Alert bus hampir tiba ────────────────────────────────

  Widget _buildArrivalAlert() {
    if (_myBus == null || _myHalte == null) return const SizedBox.shrink();
    final hLat = (_myHalte!['latitude'] as num?)?.toDouble() ?? 0;
    final hLng = (_myHalte!['longitude'] as num?)?.toDouble() ?? 0;
    if (hLat == 0 && hLng == 0) return const SizedBox.shrink();
    const d = Distance();
    final dist = d.as(LengthUnit.Meter,
        LatLng(_myBus!.latitude, _myBus!.longitude), LatLng(hLat, hLng));
    if (dist > 300) return const SizedBox.shrink();
    final isVeryClose = dist < 80;
    return Positioned(
      bottom: 12,
      left: 12,
      right: 12,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isVeryClose
              ? Colors.green.withValues(alpha: 0.95)
              : AppColors.orange.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: (isVeryClose ? Colors.green : AppColors.orange)
                    .withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 4))
          ],
        ),
        child: Row(children: [
          Text(isVeryClose ? '🚌' : '⚠️', style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(
                  isVeryClose
                      ? 'Bus sudah tiba di haltemu!'
                      : 'Bus hampir tiba! (${dist.round()}m)',
                  style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white),
                ),
                Text(
                  isVeryClose
                      ? 'Siapkan QR Code — buka tab ID Saya'
                      : 'Segera ke halte dan siapkan QR Code',
                  style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      color: Colors.white70),
                ),
              ])),
        ]),
      ),
    );
  }

  // ── Bottom info card ─────────────────────────────────────

  Widget _buildBottomCard() {
    final bus = _myBus!;
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, -4))
        ],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Bus info row
        Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _isOnBus
                  ? Colors.green.withValues(alpha: 0.12)
                  : AppColors.primaryLight,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.directions_bus_rounded,
                color: _isOnBus ? Colors.green : AppColors.primary, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(bus.nama,
                    style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.black)),
                Text(
                  [
                    bus.platNomor,
                    if (_driverName != null) '• Driver: $_driverName',
                  ].join('  '),
                  style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      color: AppColors.textGrey),
                ),
              ])),
          // Speed badge
          if (bus.gpsActive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${bus.speed.toStringAsFixed(0)} km/h',
                style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary),
              ),
            ),
        ]),

        const SizedBox(height: 10),
        const Divider(height: 1, color: AppColors.lightGrey),
        const SizedBox(height: 10),

        // Kondisi berbeda: sebelum naik vs saat naik vs selesai
        if (_isOnBus) ...[
          // ── Sudah naik: tampilkan info perjalanan ──────
          Row(children: [
            Expanded(
                child: _InfoTile(
              icon: Icons.login_rounded,
              label: 'Jam Naik',
              value: _waktuNaik ?? '—',
              color: Colors.green,
            )),
            const SizedBox(width: 8),
            Expanded(
                child: _InfoTile(
              icon: Icons.location_on_rounded,
              label: 'Halte Naik',
              value: _halteNaik ?? '—',
              color: Colors.green,
            )),
            const SizedBox(width: 8),
            Expanded(
                child: _InfoTile(
              icon: Icons.speed_rounded,
              label: 'Kecepatan',
              value:
                  bus.gpsActive ? '${bus.speed.toStringAsFixed(0)} km/h' : '—',
              color: AppColors.primary,
            )),
          ]),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3))),
            child: const Row(children: [
              Icon(Icons.info_outline_rounded, color: Colors.green, size: 14),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Kamu sedang di bus. Driver akan checkout saat kamu turun.',
                  style: TextStyle(
                      fontFamily: 'Poppins', fontSize: 11, color: Colors.green),
                ),
              ),
            ]),
          ),
        ] else if (_isDone) ...[
          // ── Sudah selesai: ringkasan perjalanan ────────
          Row(children: [
            Expanded(
                child: _InfoTile(
              icon: Icons.login_rounded,
              label: 'Jam Naik',
              value: _waktuNaik ?? '—',
              color: AppColors.primary,
            )),
            const SizedBox(width: 8),
            Expanded(
                child: _InfoTile(
              icon: Icons.logout_rounded,
              label: 'Jam Turun',
              value: _waktuTurun ?? '—',
              color: AppColors.primary,
            )),
            const SizedBox(width: 8),
            Expanded(
                child: _InfoTile(
              icon: Icons.location_on_rounded,
              label: 'Halte Naik',
              value: _halteNaik ?? '—',
              color: AppColors.primary,
            )),
          ]),
        ] else ...[
          // ── Belum naik: tampilkan ETA ke halte ────────
          Row(children: [
            Expanded(
                child: _InfoTile(
              icon: Icons.timer_rounded,
              label: 'Tiba di Haltemu',
              value: bus.gpsActive ? _etaKeHalte() : 'Bus belum aktif',
              color: bus.gpsActive ? AppColors.primary : AppColors.textGrey,
            )),
            const SizedBox(width: 8),
            Expanded(
                child: _InfoTile(
              icon: Icons.place_rounded,
              label: 'Halte Naik',
              value: _myHalte?['nama_halte'] as String? ?? 'Belum diatur',
              color: AppColors.orange,
            )),
          ]),
        ],
      ]),
    );
  }

  Widget _buildNoBusView() => Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.directions_bus_outlined,
            size: 64, color: AppColors.primary.withValues(alpha: 0.3)),
        const SizedBox(height: 12),
        const Text('Bus belum ditugaskan',
            style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textGrey)),
        const SizedBox(height: 6),
        const Text('Hubungi admin sekolah',
            style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                color: AppColors.textGrey)),
        const SizedBox(height: 20),
        GestureDetector(
          onTap: () => _loadAll(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(20)),
            child: const Text('Refresh',
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary)),
          ),
        ),
      ]));

  Widget _buildGpsOffView() => Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration:
              BoxDecoration(color: AppColors.surface2, shape: BoxShape.circle),
          child: Icon(Icons.gps_off_rounded,
              size: 48, color: AppColors.textGrey.withValues(alpha: 0.5)),
        ),
        const SizedBox(height: 16),
        Text('GPS ${_myBus!.nama} Tidak Aktif',
            style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.black)),
        const SizedBox(height: 6),
        const Text(
          'Driver belum mengaktifkan GPS.\nPosisi bus tidak dapat ditampilkan.',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              color: AppColors.textGrey,
              height: 1.5),
        ),
        const SizedBox(height: 20),
        GestureDetector(
          onTap: () => _loadAll(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(20)),
            child: const Text('Refresh',
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary)),
          ),
        ),
      ]));
}

// ── _StatusBanner — banner status absensi di atas peta ───────

class _StatusBanner extends StatelessWidget {
  final Color color;
  final Color borderColor;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String? badge;
  final Color? badgeColor;

  const _StatusBanner({
    required this.color,
    required this.borderColor,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.badge,
    this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 10),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: iconColor)),
          Text(subtitle,
              style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  color: AppColors.textGrey)),
        ])),
        if (badge != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
                color: badgeColor ?? AppColors.primary,
                borderRadius: BorderRadius.circular(6)),
            child: Text(badge!,
                style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
          ),
      ]),
    );
  }
}

// ── _OnBusOverlay — overlay di atas peta saat siswa di bus ───

class _OnBusOverlay extends StatelessWidget {
  final String busName;
  final double speed;
  final String? waktuNaik;
  final String? halteNaik;

  const _OnBusOverlay({
    required this.busName,
    required this.speed,
    this.waktuNaik,
    this.halteNaik,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.93),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.green.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 3))
        ],
      ),
      child: Row(children: [
        const Icon(Icons.directions_bus_rounded, color: Colors.white, size: 20),
        const SizedBox(width: 10),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Kamu di $busName',
              style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
          if (waktuNaik != null)
            Text(
              'Naik $waktuNaik${halteNaik != null ? " di $halteNaik" : ""}',
              style: const TextStyle(
                  fontFamily: 'Poppins', fontSize: 10, color: Colors.white70),
            ),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${speed.toStringAsFixed(0)} km/h',
            style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white),
          ),
        ),
      ]),
    );
  }
}

// ── _InfoTile — tile info kecil di bottom card ────────────────

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _InfoTile(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(height: 4),
        Text(value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color)),
        Text(label,
            style: const TextStyle(
                fontFamily: 'Poppins', fontSize: 9, color: AppColors.textGrey)),
      ]),
    );
  }
}

class _SiswaProfileTab extends StatefulWidget {
  final UserModel siswa;
  const _SiswaProfileTab({required this.siswa});

  @override
  State<_SiswaProfileTab> createState() => _SiswaProfileTabState();
}

class _SiswaProfileTabState extends State<_SiswaProfileTab> {
  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.background,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            const SizedBox(height: 12),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(20),
                image: widget.siswa.photoUrl != null
                    ? DecorationImage(
                        image: NetworkImage(widget.siswa.photoUrl!),
                        fit: BoxFit.cover)
                    : null,
              ),
              child: widget.siswa.photoUrl == null
                  ? Center(
                      child: Text(widget.siswa.namaLengkap[0].toUpperCase(),
                          style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary)))
                  : null,
            ),
            const SizedBox(height: 12),
            Text(widget.siswa.namaLengkap,
                style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.black)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(20)),
              child: const Text('Siswa',
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary)),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10)
                  ]),
              child: Column(children: [
                _InfoRow(
                    icon: Icons.email_outlined,
                    label: 'Email',
                    value: widget.siswa.email),
                const Divider(color: AppColors.lightGrey, height: 20),
                _InfoRow(
                    icon: Icons.phone_outlined,
                    label: 'No. HP',
                    value: widget.siswa.noHp.isEmpty ? '-' : widget.siswa.noHp),
                const Divider(color: AppColors.lightGrey, height: 20),
                _InfoRow(
                    icon: Icons.location_on_outlined,
                    label: 'Alamat',
                    value: widget.siswa.alamat.isEmpty
                        ? '-'
                        : widget.siswa.alamat),
              ]),
            ),
            const SizedBox(height: 14),
            _ProfileMenu(
                icon: Icons.edit_outlined,
                label: 'Edit Profil',
                onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    EditProfileScreen(user: widget.siswa)))
                        .then((_) {
                      if (mounted) setState(() {});
                    })),
            _ProfileMenu(
                icon: Icons.logout_rounded,
                label: 'Keluar',
                color: AppColors.red,
                onTap: () {
                  context.read<AuthProvider>().logout();
                  Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (_) => false);
                }),
            const SizedBox(height: 20),
          ]),
        ),
      ), // SafeArea
    ); // ColoredBox
  }
}

// ══════════════════════════════════════════════════════════════
// SHARED WIDGETS
// ══════════════════════════════════════════════════════════════

class _BusCard extends StatelessWidget {
  final BusModel bus;
  final String eta;
  final AnimationController pulseAnim;
  final VoidCallback onTrack;
  const _BusCard(
      {required this.bus,
      required this.eta,
      required this.pulseAnim,
      required this.onTrack});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primary, AppColors.primaryDark]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          AnimatedBuilder(
            animation: pulseAnim,
            builder: (_, __) => Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color:
                    Colors.white.withValues(alpha: 0.5 + 0.5 * pulseAnim.value),
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 6),
          const Text('LIVE',
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.white70,
                  letterSpacing: 1)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20)),
            child: Text('${bus.speed.toStringAsFixed(0)} km/h',
                style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white)),
          ),
        ]),
        const SizedBox(height: 12),
        Text(bus.nama,
            style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.white)),
        Text(bus.rute,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontFamily: 'Poppins', fontSize: 12, color: Colors.white70)),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Text('ESTIMASI TIBA',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: Colors.white60,
                        letterSpacing: 0.8)),
                Text(eta,
                    style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
              ])),
          GestureDetector(
            onTap: onTrack,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: const Row(children: [
                Icon(Icons.map_rounded, color: AppColors.primary, size: 16),
                SizedBox(width: 6),
                Text('Lacak',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary)),
              ]),
            ),
          ),
        ]),
      ]),
    );
  }
}

class _LoadingBusCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)
          ]),
      child: const Row(children: [
        SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
                strokeWidth: 2.5, color: AppColors.primary)),
        SizedBox(width: 14),
        Text('Memuat informasi bus...',
            style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                color: AppColors.textGrey)),
      ]),
    );
  }
}

class _NoBusAssignedCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.orange.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10)
        ],
      ),
      child: Row(children: [
        Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
                color: AppColors.orange.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.info_outline_rounded,
                color: AppColors.orange, size: 24)),
        const SizedBox(width: 14),
        const Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Belum Ditugaskan ke Bus',
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.black)),
          SizedBox(height: 2),
          Text('Hubungi admin agar kamu didaftarkan ke bus',
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  color: AppColors.textGrey)),
        ])),
      ]),
    );
  }
}

class _BusNotActiveCard extends StatelessWidget {
  final String? busName;
  final String? driverName;
  final VoidCallback? onTrack;
  const _BusNotActiveCard({this.busName, this.driverName, this.onTrack});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.directions_bus_rounded,
                  color: AppColors.textGrey, size: 24)),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(
                  busName ?? 'Bus Saya',
                  style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.black),
                ),
                const SizedBox(height: 2),
                Row(children: [
                  Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                          color: AppColors.textGrey, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  const Text('GPS belum aktif',
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: AppColors.textGrey)),
                ]),
              ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(8)),
            child: const Text('OFFLINE',
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textGrey)),
          ),
        ]),
        if (driverName != null) ...[
          const SizedBox(height: 10),
          const Divider(height: 1, color: AppColors.lightGrey),
          const SizedBox(height: 10),
          Row(children: [
            const Icon(Icons.person_rounded,
                size: 14, color: AppColors.textGrey),
            const SizedBox(width: 6),
            Text('Driver: $driverName',
                style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    color: AppColors.textGrey)),
            const Spacer(),
            if (onTrack != null)
              GestureDetector(
                onTap: onTrack,
                child: const Text('Cek Peta',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary)),
              ),
          ]),
        ],
      ]),
    );
  }
}

class _NoBusCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)
          ]),
      child: Row(children: [
        Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.directions_bus_rounded,
                color: AppColors.textGrey, size: 24)),
        const SizedBox(width: 14),
        const Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Bus Belum Beroperasi',
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.black)),
          Text('Bus akan muncul saat mulai beroperasi',
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  color: AppColors.textGrey)),
        ])),
      ]),
    );
  }
}

class _QAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color, bg;
  final VoidCallback onTap;
  const _QAction(
      {required this.icon,
      required this.label,
      required this.color,
      required this.bg,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: color.withValues(alpha: 0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 3))
              ]),
          child: Row(children: [
            Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                    color: bg, borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: color, size: 22)),
            const SizedBox(width: 12),
            Expanded(
                child: Text(label,
                    style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.black,
                        height: 1.3))),
            Icon(Icons.chevron_right_rounded,
                color: color.withValues(alpha: 0.5), size: 18),
          ]),
        ),
      ),
    );
  }
}

class _BusListTile extends StatelessWidget {
  final BusModel bus;
  final String eta;
  final VoidCallback onTap;
  const _BusListTile(
      {required this.bus, required this.eta, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2))
            ]),
        child: Row(children: [
          Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.directions_bus_rounded,
                  color: AppColors.primary, size: 22)),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(bus.nama,
                    style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.black)),
                Text(bus.rute,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        color: AppColors.textGrey)),
              ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(eta,
                style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary)),
            const Text('estimasi',
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 9,
                    color: AppColors.textGrey)),
          ]),
        ]),
      ),
    );
  }
}

class _BusChip extends StatelessWidget {
  final BusModel bus;
  const _BusChip({required this.bus});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.directions_bus_rounded,
              color: AppColors.primary, size: 16),
          const SizedBox(width: 6),
          Expanded(
              child: Text(bus.nama,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary))),
        ]),
        const SizedBox(height: 4),
        Text(bus.rute,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 10,
                color: AppColors.primaryDark)),
        const SizedBox(height: 6),
        Text('${bus.speed.toStringAsFixed(0)} km/h',
            style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.black)),
      ]),
    );
  }
}

class _SimpleSheet extends StatelessWidget {
  final String title;
  final Widget child;
  const _SimpleSheet({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Center(
            child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.lightGrey,
                    borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 16),
        Text(title,
            style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        child,
        const SizedBox(height: 8),
      ]),
    );
  }
}

class _NotifTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title, time;
  const _NotifTile(
      {required this.icon,
      required this.color,
      required this.title,
      required this.time});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18)),
        const SizedBox(width: 12),
        Expanded(
            child: Text(title,
                style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w500))),
        Text(time,
            style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11,
                color: AppColors.textGrey)),
      ]),
    );
  }
}

class _ToggleTile extends StatefulWidget {
  final String label;
  final bool initialValue;
  const _ToggleTile({required this.label, required this.initialValue});
  @override
  State<_ToggleTile> createState() => _ToggleTileState();
}

class _ToggleTileState extends State<_ToggleTile> {
  late bool _val;
  @override
  void initState() {
    super.initState();
    _val = widget.initialValue;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: SwitchListTile(
        value: _val,
        onChanged: (v) => setState(() => _val = v),
        title: Text(widget.label,
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 13)),
        activeColor: AppColors.primary,
        dense: true,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _InfoRow(
      {required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, color: AppColors.primary, size: 18),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  color: AppColors.textGrey)),
          Text(value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.black)),
        ])),
      ]);
}

class _ProfileMenu extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ProfileMenu(
      {required this.icon,
      required this.label,
      required this.onTap,
      this.color = AppColors.black});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)
            ]),
        child: ListTile(
          onTap: onTap,
          leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 18)),
          title: Text(label,
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: color)),
          trailing: Icon(Icons.chevron_right_rounded,
              color: color.withValues(alpha: 0.4), size: 20),
        ),
      );
}

// ── Bug 7 Fix: Sheet halte berdasarkan rute bus siswa ─────────
class _HalteRouteSheet extends StatefulWidget {
  final AppDataService dataService;
  final ScrollController scrollCtrl;
  const _HalteRouteSheet({required this.dataService, required this.scrollCtrl});

  @override
  State<_HalteRouteSheet> createState() => _HalteRouteSheetState();
}

class _HalteRouteSheetState extends State<_HalteRouteSheet> {
  List<RouteHalteModel> _haltes = [];
  String _namaRute = '';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHaltesRute();
  }

  Future<void> _loadHaltesRute() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Ambil bus siswa untuk dapat bus_id → cari route → ambil haltes
      final studentSvc = StudentService();
      final myBusData = await studentSvc.getMyBus();

      if (myBusData == null) {
        setState(() {
          _error = 'Kamu belum terdaftar di bus manapun.';
          _loading = false;
        });
        return;
      }

      final busId = myBusData['data']?['bus_id'] as int? ??
          myBusData['data']?['id'] as int?;

      if (busId == null) {
        setState(() {
          _error = 'Data bus tidak ditemukan.';
          _loading = false;
        });
        return;
      }

      // Ambil rute bus → halte dalam rute
      final routeSvc = RouteService();
      final route = await routeSvc.getRouteByBus(busId);

      if (route == null) {
        setState(() {
          _error = 'Rute bus belum diatur oleh admin.';
          _loading = false;
        });
        return;
      }

      // Gunakan haltes yang sudah ter-embed di RouteModel
      setState(() {
        _namaRute = route.namaRute;
        _haltes = route.haltes;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Gagal memuat data halte.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(children: [
        // Handle
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(children: [
            Center(
                child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: AppColors.lightGrey,
                        borderRadius: BorderRadius.circular(2)))),
            const Spacer(),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              const Text('Halte di Rute Bus Saya',
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
              if (_namaRute.isNotEmpty)
                Text(_namaRute,
                    style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        color: AppColors.textGrey)),
            ]),
            const Spacer(),
          ]),
        ),
        const SizedBox(height: 8),
        // Content
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.info_outline_rounded,
                              size: 48, color: AppColors.textGrey),
                          const SizedBox(height: 12),
                          Text(_error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 13,
                                  color: AppColors.textGrey)),
                        ]),
                      ),
                    )
                  : _haltes.isEmpty
                      ? const Center(
                          child: Text('Belum ada halte di rute ini.',
                              style: TextStyle(
                                  fontFamily: 'Poppins',
                                  color: AppColors.textGrey)))
                      : ListView.builder(
                          controller: widget.scrollCtrl,
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
                          itemCount: _haltes.length,
                          itemBuilder: (_, i) {
                            final rh = _haltes[i];
                            final h = rh.halte;
                            final isFirst = i == 0;
                            final isLast = i == _haltes.length - 1;
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Timeline
                                Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 32,
                                        height: 32,
                                        margin: const EdgeInsets.only(top: 10),
                                        decoration: BoxDecoration(
                                          color: isFirst
                                              ? Colors.green
                                              : (isLast
                                                  ? AppColors.primary
                                                  : AppColors.primaryLight),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                            child: Text('${rh.urutan}',
                                                style: TextStyle(
                                                    fontFamily: 'Poppins',
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                    color: (isFirst || isLast)
                                                        ? Colors.white
                                                        : AppColors.primary))),
                                      ),
                                      if (!isLast)
                                        Container(
                                            width: 2,
                                            height: 36,
                                            color: AppColors.primaryLight),
                                    ]),
                                const SizedBox(width: 12),
                                // Card
                                Expanded(
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 4),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                        color: AppColors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                              color: Colors.black
                                                  .withValues(alpha: 0.04),
                                              blurRadius: 6)
                                        ]),
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                              h?.namaHalte ??
                                                  'Halte #${rh.halteId}',
                                              style: const TextStyle(
                                                  fontFamily: 'Poppins',
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600)),
                                          if (h != null && h.alamat.isNotEmpty)
                                            Text(h.alamat,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                    fontFamily: 'Poppins',
                                                    fontSize: 11,
                                                    color: AppColors.textGrey)),
                                        ]),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
        ),
      ]),
    );
  }
}
