import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/models_api.dart';
import '../../services/auth_provider.dart';
import '../../services/app_data_service.dart';
import '../../services/gps_service.dart';
import '../../services/routing_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/bus_map_widget.dart';
import '../auth/login_screen.dart';
import '../common/edit_profile_screen.dart';
import 'scan_qr_screen.dart';
import 'laporan_operasional_screen.dart';

class DriverDashboard extends StatefulWidget {
  const DriverDashboard({super.key});
  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard> {
  int _currentIndex = 0;
  int _stackIndex = 0;
  final AppDataService _dataService = AppDataService();
  // Bus aktif driver — diambil dari cache login, tanpa request tambahan
  BusModel? _driverBus;

  @override
  void initState() {
    super.initState();
    // Ambil bus dari cache yang sudah diisi saat login — 0ms, no network call
    _driverBus = Provider.of<AuthProvider>(context, listen: false)
        .authService
        .cachedDriverBus;
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.read<AuthProvider>().currentUser!;
    final BusModel? bus = _driverBus;
    const bool isLoadingBus = false;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_currentIndex != 0) {
          setState(() {
            _currentIndex = 0;
            _stackIndex = 0;
          });
        }
        // Kalau sudah di tab 0, cegah pop keluar (hindari layar hitam)
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: IndexedStack(
          index: _stackIndex,
          children: [
            _DriverHomeTab(
                driver: currentUser,
                bus: bus,
                dataService: _dataService,
                isLoadingBus: isLoadingBus),
            _DriverProfileTab(driver: currentUser, bus: bus),
          ],
        ),
        bottomNavigationBar: MobitraBottomNav(
          currentIndex: _currentIndex,
          onTap: (i) {
            if (i == 1) {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => ScanQrScreen(dataService: _dataService)),
              );
              return;
            }
            // i == 2 → buka Laporan via push (lazy, bukan IndexedStack)
            if (i == 2) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LaporanOperasionalScreen(
                    dataService: _dataService,
                    driverId: currentUser.idStr,
                    busId: bus?.id,
                  ),
                ),
              );
              return;
            }
            final stackIndex = i == 3 ? 1 : 0;
            setState(() {
              _currentIndex = i;
              _stackIndex = stackIndex;
            });
          },
          items: const [
            BottomNavItem(
                icon: Icons.directions_bus_outlined,
                activeIcon: Icons.directions_bus_rounded,
                label: 'Dashboard'),
            BottomNavItem(
                icon: Icons.qr_code_2_outlined,
                activeIcon: Icons.qr_code_2_rounded,
                label: 'Scan'),
            BottomNavItem(
                icon: Icons.description_outlined,
                activeIcon: Icons.description_rounded,
                label: 'Reports'),
            BottomNavItem(
                icon: Icons.person_outline,
                activeIcon: Icons.person_rounded,
                label: 'Profil'),
          ],
        ),
      ),
    );
  }
}

class _DriverHomeTab extends StatefulWidget {
  final UserModel driver;
  final BusModel? bus;
  final AppDataService dataService;
  final bool isLoadingBus;
  const _DriverHomeTab({
    required this.driver,
    required this.bus,
    required this.dataService,
    this.isLoadingBus = false,
  });
  @override
  State<_DriverHomeTab> createState() => _DriverHomeTabState();
}

class _DriverHomeTabState extends State<_DriverHomeTab>
    with TickerProviderStateMixin {
  final GpsService _gpsService = GpsService();
  final RoutingService _routingService = RoutingService();
  bool _gpsActive = false;
  bool _gpsLoading = false;
  String _gpsError = '';
  // Navigasi: polyline dari posisi driver ke halte berikutnya
  List<LatLng> _navPolyline = [];
  int _targetHalteIndex = 0; // index halte yang sedang dituju
  HalteModel? _targetHalte; // halte tujuan saat ini
  LatLng? _driverLatLng;
  StreamSubscription<Position>? _positionSub;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _gpsActive = widget.bus?.gpsActive ?? false;

    // Subscribe ke stream posisi GPS — update marker + navigasi real-time
    _positionSub = _gpsService.positionStream.listen((position) {
      if (!mounted || position.latitude == 0) return;
      final pos = LatLng(position.latitude, position.longitude);
      setState(() => _driverLatLng = pos);

      // Update navigasi ke halte berikutnya setiap update posisi
      final bus = widget.bus;
      if (_gpsActive && bus != null && bus.routeList.isNotEmpty) {
        final haltes = bus.routeList.first.haltes;
        _updateNavigation(pos, haltes);
      }
    });

    // Jika GPS sudah aktif dari DB (saat app restart setelah force-close):
    // resume tracking tanpa toggle manual
    if (_gpsActive) {
      if (_gpsService.isTracking) {
        // GpsService masih tracking (navigasi antar halaman) — ambil posisi terakhir
        if (_gpsService.lastPosition != null) {
          final p = _gpsService.lastPosition!;
          _driverLatLng = LatLng(p.latitude, p.longitude);
        }
      } else {
        // App baru dibuka / force-close — restart tracking otomatis
        _resumeTracking();
      }
    }

    _pulseController =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
        CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    // JANGAN panggil stopTracking() di sini — GPS harus tetap jalan
    // saat navigasi ke halaman lain (scan, laporan, profil).
    // stopTracking() hanya dipanggil saat user sengaja matikan toggle GPS
    // atau saat logout.
    _pulseController.dispose();
    super.dispose();
  }

  /// Resume tracking GPS saat app dibuka kembali setelah force-close
  /// dan DB masih mencatat gps_status = 'on'
  Future<void> _resumeTracking() async {
    final started = await _gpsService.startTracking();
    if (!mounted) return;
    if (started) {
      final pos = await _gpsService.getCurrentPosition();
      if (mounted && pos != null) {
        final latLng = LatLng(pos.latitude, pos.longitude);
        setState(() => _driverLatLng = latLng);
        await _gpsService.sendCurrentPosition(pos);
        // Resume navigasi dari posisi saat ini
        await _initNavigation(latLng);
      }
    } else {
      // Gagal restart (izin dicabut, GPS hp dimatikan, dll)
      // Reset state dan update DB ke off
      setState(() => _gpsActive = false);
      await _gpsService.stopTracking();
    }
  }

  /// Inisiasi navigasi ke halte pertama saat GPS diaktifkan
  Future<void> _initNavigation(LatLng driverPos) async {
    final bus = widget.bus;
    if (bus == null || bus.routeList.isEmpty) return;
    final route = bus.routeList.first;
    if (route.haltes.isEmpty) return;

    _targetHalteIndex = 0;
    await _updateNavigation(driverPos, route.haltes);
  }

  /// Update polyline navigasi ke halte berikutnya
  Future<void> _updateNavigation(
      LatLng driverPos, List<RouteHalteModel> haltes) async {
    if (haltes.isEmpty) return;

    // Cek apakah sudah melewati halte saat ini
    final nextIdx = _routingService.getNextHalteIndex(
      driverPos: driverPos,
      haltes: haltes,
      currentIndex: _targetHalteIndex,
    );

    if (nextIdx != _targetHalteIndex && mounted) {
      setState(() => _targetHalteIndex = nextIdx);
    }

    // Sudah melewati semua halte
    if (_targetHalteIndex >= haltes.length) {
      if (mounted)
        setState(() {
          _navPolyline = [];
          _targetHalte = null;
        });
      return;
    }

    final halte = haltes[_targetHalteIndex].halte;
    if (halte == null) return;

    final target = LatLng(halte.latitude, halte.longitude);
    final polyline = await _routingService.getNavigationRoute(
      from: driverPos,
      to: target,
    );

    if (mounted) {
      setState(() {
        _navPolyline = polyline;
        _targetHalte = halte;
      });
    }
  }

  /// Ambil posisi perangkat saat ini secara async saat GPS sudah aktif
  /// tapi posisi belum tersedia (misal setelah restart atau buka ulang layar)
  Future<void> _fetchInitialPosition() async {
    final pos = await _gpsService.getCurrentPosition();
    if (mounted && pos != null) {
      setState(() {
        _driverLatLng = LatLng(pos.latitude, pos.longitude);
      });
    }
  }

  String _getGreeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Selamat pagi,';
    if (h < 17) return 'Selamat siang,';
    return 'Selamat malam,';
  }

  Future<void> _toggleGps(bool value) async {
    if (widget.bus == null) return;

    setState(() {
      _gpsLoading = true;
      _gpsError = '';
    });

    if (value) {
      // Aktifkan GPS → minta permission → mulai tracking lokasi HP
      final started =
          await _gpsService.startTracking(); // API call ada di GpsService
      if (started) {
        final currentPos = await _gpsService.getCurrentPosition();
        if (!mounted) return;
        final pos = currentPos != null
            ? LatLng(currentPos.latitude, currentPos.longitude)
            : _gpsService.lastPosition != null
                ? LatLng(_gpsService.lastPosition!.latitude,
                    _gpsService.lastPosition!.longitude)
                : null;
        setState(() {
          _gpsActive = true;
          _gpsLoading = false;
          if (pos != null) _driverLatLng = pos;
        });
        // Inisiasi navigasi dari posisi awal driver ke halte pertama
        if (pos != null) await _initNavigation(pos);
      } else {
        setState(() {
          _gpsLoading = false;
          _gpsError =
              'GPS tidak bisa diaktifkan.\nPastikan izin lokasi diberikan di Pengaturan.';
        });
      }
    } else {
      // Matikan GPS → stop tracking
      _gpsService.stopTracking();
      setState(() {
        _gpsActive = false;
        _gpsLoading = false;
        _navPolyline = [];
        _targetHalte = null;
        _targetHalteIndex = 0;
      });
    }
  }

  void _showSiswaSheet(BuildContext ctx, AppDataService ds) {
    final siswa =
        ds.siswaList.where((u) => u.status == AccountStatus.active).toList();
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        maxChildSize: 0.85,
        minChildSize: 0.3,
        builder: (_, ctrl) => Container(
          decoration: const BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(children: [
            Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                child: Row(children: [
                  Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                          color: AppColors.lightGrey,
                          borderRadius: BorderRadius.circular(2))),
                  const Spacer(),
                  const Text('Siswa di Rute Ini',
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Text('${siswa.length} siswa',
                      style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: AppColors.textGrey)),
                ])),
            Expanded(
              child: siswa.isEmpty
                  ? const Center(
                      child: Text('Belum ada siswa terdaftar',
                          style: TextStyle(
                              fontFamily: 'Poppins',
                              color: AppColors.textGrey)))
                  : ListView.builder(
                      controller: ctrl,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 30),
                      itemCount: siswa.length,
                      itemBuilder: (_, i) {
                        final s = siswa[i];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 8)
                              ]),
                          child: Row(children: [
                            Container(
                                width: 40,
                                height: 40,
                                decoration: const BoxDecoration(
                                    color: AppColors.primaryLight,
                                    shape: BoxShape.circle),
                                child: Center(
                                    child: Text(s.namaLengkap[0].toUpperCase(),
                                        style: const TextStyle(
                                            fontFamily: 'Poppins',
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.primary,
                                            fontSize: 16)))),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(s.namaLengkap,
                                      style: const TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600)),
                                  Text(s.alamat.isEmpty ? '-' : s.alamat,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 11,
                                          color: AppColors.textGrey)),
                                ])),
                            const Icon(Icons.qr_code_rounded,
                                size: 18, color: AppColors.textGrey),
                          ]),
                        );
                      }),
            ),
          ]),
        ),
      ),
    );
  }

  void _showRuteSheet(BuildContext ctx, BusModel? bus) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                  child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                          color: AppColors.lightGrey,
                          borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              const Text('Info Rute',
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              if (widget.isLoadingBus && bus == null)
                // [FIX] Tampilkan loading saat data bus sedang dimuat dari API
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Row(children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.primary),
                    ),
                    SizedBox(width: 10),
                    Text('Memuat data bus...',
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13,
                            color: AppColors.textGrey)),
                  ]),
                )
              else if (bus == null)
                const Text('Belum ada bus yang ditugaskan ke akun ini',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        color: AppColors.textGrey))
              else ...[
                _RuteItem(
                    icon: Icons.directions_bus_rounded,
                    label: 'Bus',
                    value: '${bus.nama} (${bus.platNomor})'),
                _RuteItem(
                    icon: Icons.route_rounded,
                    label: 'Rute',
                    value: bus.rute.isEmpty ? 'Belum ada rute' : bus.rute),
                _RuteItem(
                    icon: Icons.people_rounded,
                    label: 'Status',
                    value: bus.isActive ? 'Aktif Beroperasi' : 'Tidak Aktif'),
                // List halte berurutan
                if (bus.routeList.isEmpty && bus.rute.isEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface2,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(children: [
                      Icon(Icons.info_outline_rounded,
                          size: 16, color: AppColors.textGrey),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                            'Admin belum membuat rute untuk bus ini. '
                            'Hubungi admin untuk menambahkan rute dan halte.',
                            style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 11,
                                color: AppColors.textGrey)),
                      ),
                    ]),
                  ),
                ] else if (bus.routeList.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const Text('Daftar Halte',
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  ...bus.routeList.expand((route) {
                    return [
                      if (bus.routeList.length > 1)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(route.namaRute,
                              style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary)),
                        ),
                      ...route.haltes.map((rh) {
                        final halte = rh.halte;
                        if (halte == null) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Column(
                                children: [
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: rh.urutan == 1
                                          ? AppColors.primary
                                          : rh.urutan == route.haltes.length
                                              ? AppColors.orange
                                              : AppColors.primaryLight,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text('${rh.urutan}',
                                          style: TextStyle(
                                              fontFamily: 'Poppins',
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: rh.urutan == 1 ||
                                                      rh.urutan ==
                                                          route.haltes.length
                                                  ? Colors.white
                                                  : AppColors.primary)),
                                    ),
                                  ),
                                  if (rh.urutan < route.haltes.length)
                                    Container(
                                        width: 2,
                                        height: 16,
                                        color: AppColors.lightGrey),
                                ],
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(halte.namaHalte,
                                      style: const TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 13,
                                          color: AppColors.black)),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ];
                  }),
                ],
              ],
              const SizedBox(height: 10),
            ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final firstName = widget.driver.namaLengkap.split(' ').first;
    final bus = widget.bus;

    return ColoredBox(
      color: AppColors.background,
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const MobitraAppBar(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${_getGreeting()} Pak $firstName',
                        style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            color: AppColors.textGrey)),
                    RichText(
                      text: TextSpan(children: [
                        const TextSpan(
                            text: 'Siap\n',
                            style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                                color: AppColors.black,
                                height: 1.2)),
                        TextSpan(
                            text: _gpsActive ? 'Beroperasi! ✅' : 'Beroperasi?',
                            style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary)),
                      ]),
                    ),
                    const SizedBox(height: 24),

                    if (bus != null) ...[
                      // Card info bus
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4))
                            ]),
                        child: Row(
                          children: [
                            Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                    color: AppColors.primaryLight,
                                    borderRadius: BorderRadius.circular(12)),
                                child: const Icon(Icons.directions_bus_rounded,
                                    color: AppColors.primary, size: 28)),
                            const SizedBox(width: 14),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(bus.nama,
                                      style: const TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700)),
                                  Text(bus.platNomor,
                                      style: const TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 12,
                                          color: AppColors.textGrey)),
                                  Text(bus.rute,
                                      style: const TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 11,
                                          color: AppColors.textGrey)),
                                ])),
                            bus.isActive
                                ? StatusBadge.active()
                                : StatusBadge.inactive(),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Card GPS toggle
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4))
                            ]),
                        child: Row(
                          children: [
                            AnimatedBuilder(
                              animation: _gpsActive
                                  ? _pulseAnim
                                  : const AlwaysStoppedAnimation(1.0),
                              builder: (_, child) => Transform.scale(
                                  scale: _gpsActive ? _pulseAnim.value : 1.0,
                                  child: child),
                              child: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                    color: _gpsActive
                                        ? AppColors.primaryLight
                                        : AppColors.lightGrey,
                                    borderRadius: BorderRadius.circular(12)),
                                child: Icon(Icons.gps_fixed_rounded,
                                    color: _gpsActive
                                        ? AppColors.primary
                                        : AppColors.textGrey,
                                    size: 26),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  const Text('GPS Tracking',
                                      style: TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700)),
                                  Text(_gpsActive ? '• AKTIF' : '• NONAKTIF',
                                      style: TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: _gpsActive
                                              ? AppColors.primary
                                              : AppColors.textGrey)),
                                ])),
                            _gpsLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.primary))
                                : Switch(
                                    value: _gpsActive,
                                    onChanged: bus.isActive ? _toggleGps : null,
                                    activeColor: AppColors.primary),
                          ],
                        ),
                      ),

                      // Error GPS
                      if (_gpsError.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                              color: const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(12)),
                          child: Row(children: [
                            const Icon(Icons.error_outline,
                                color: AppColors.red, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(_gpsError,
                                    style: const TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 12,
                                        color: AppColors.red))),
                          ]),
                        ),
                      ],
                      const SizedBox(height: 20),

                      // Peta + info live hanya kalau GPS aktif
                      if (_gpsActive) ...[
                        const Text('Posisi Saat Ini',
                            style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 16,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 10),
                        StreamBuilder<List<BusModel>>(
                          stream: widget.dataService.busesStream,
                          builder: (context, snapshot) {
                            final buses =
                                snapshot.data ?? widget.dataService.buses;
                            final updatedBus = buses.firstWhere(
                                (b) => b.id == bus.id,
                                orElse: () => bus);
                            return Column(
                              children: [
                                // Peta OpenStreetMap
                                BusMapWidget(
                                  buses: [updatedBus],
                                  height: 260,
                                  showAllBuses: false,
                                  focusBus: updatedBus,
                                  interactive: true,
                                  driverLocation: _driverLatLng,
                                  routes: updatedBus.routeList,
                                  showRoutes: updatedBus.routeList.isNotEmpty,
                                  navigationPolyline: _navPolyline,
                                ),
                                // Info halte tujuan berikutnya
                                if (_gpsActive && _targetHalte != null)
                                  _NextHalteBanner(
                                    halte: _targetHalte!,
                                    halteIndex: _targetHalteIndex,
                                    driverPos: _driverLatLng,
                                    routingService: _routingService,
                                  ),
                                const SizedBox(height: 12),
                                // Speed & heading info
                                Row(children: [
                                  Expanded(
                                      child: _InfoTile(
                                          icon: Icons.speed_rounded,
                                          label: 'Kecepatan',
                                          value:
                                              '${updatedBus.speed.toStringAsFixed(0)} km/h',
                                          color: AppColors.primary)),
                                  const SizedBox(width: 12),
                                  Expanded(
                                      child: _InfoTile(
                                          icon: Icons.explore_rounded,
                                          label: 'Arah',
                                          value: _headingToText(
                                              updatedBus.heading),
                                          color: AppColors.orange)),
                                ]),
                              ],
                            );
                          },
                        ),
                      ] else ...[
                        // Pesan jika GPS belum aktif
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: AppColors.pendingOrange
                                      .withValues(alpha: 0.3))),
                          child: const Row(children: [
                            Icon(Icons.info_outline,
                                color: AppColors.pendingOrange),
                            SizedBox(width: 12),
                            Expanded(
                                child: Text(
                                    'Aktifkan GPS Tracking agar siswa dapat melacak posisi bus secara realtime.',
                                    style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 13,
                                        color: AppColors.orange))),
                          ]),
                        ),
                      ],
                    ] else if (widget.isLoadingBus) ...[
                      // [FIX] Loading saat data bus masih diambil dari API
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(16)),
                        child: const Column(children: [
                          CircularProgressIndicator(color: AppColors.primary),
                          SizedBox(height: 16),
                          Text('Memuat informasi bus...',
                              style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 13,
                                  color: AppColors.textGrey)),
                        ]),
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(16)),
                        child: Column(children: [
                          Icon(Icons.directions_bus_outlined,
                              size: 64,
                              color: AppColors.primary.withValues(alpha: 0.5)),
                          const SizedBox(height: 12),
                          const Text('Belum ada bus yang ditugaskan',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 16,
                                  color: AppColors.textGrey)),
                          const SizedBox(height: 4),
                          const Text(
                              'Hubungi admin untuk mendapatkan tugas bus',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 12,
                                  color: AppColors.textGrey)),
                        ]),
                      ),
                    ],

                    // ── Quick Actions Driver ────────────────────────────
                    const SizedBox(height: 24),
                    const Text('Aksi Cepat',
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.black)),
                    const SizedBox(height: 12),
                    Column(children: [
                      Row(children: [
                        Expanded(
                            child: _DQA(
                                icon: Icons.qr_code_scanner_rounded,
                                label: 'Scan QR Siswa',
                                color: AppColors.primary,
                                bg: AppColors.primaryLight,
                                onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                        builder: (_) => ScanQrScreen(
                                            dataService:
                                                widget.dataService))))),
                        const SizedBox(width: 12),
                        Expanded(
                            child: _DQA(
                                icon: Icons.description_rounded,
                                label: 'Laporan Harian',
                                color: AppColors.blue,
                                bg: const Color(0xFFE3F2FD),
                                onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            LaporanOperasionalScreen(
                                                dataService: widget.dataService,
                                                driverId: widget.driver.idStr,
                                                busId: widget.bus?.id))))),
                      ]),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                            child: _DQA(
                                icon: Icons.people_rounded,
                                label: 'Daftar Siswa',
                                color: AppColors.purple,
                                bg: const Color(0xFFF3E5F5),
                                onTap: () => _showSiswaSheet(
                                    context, widget.dataService))),
                        const SizedBox(width: 12),
                        Expanded(
                            child: _DQA(
                                icon: Icons.route_rounded,
                                label: 'Info Rute Bus',
                                color: AppColors.pendingOrange,
                                bg: AppColors.orange.withValues(alpha: 0.1),
                                onTap: () =>
                                    _showRuteSheet(context, widget.bus))),
                      ]),
                    ]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ), // SafeArea
    ); // ColoredBox
  }

  String _headingToText(double heading) {
    if (heading < 22.5 || heading >= 337.5) return 'Utara ↑';
    if (heading < 67.5) return 'Timur Laut ↗';
    if (heading < 112.5) return 'Timur →';
    if (heading < 157.5) return 'Tenggara ↘';
    if (heading < 202.5) return 'Selatan ↓';
    if (heading < 247.5) return 'Barat Daya ↙';
    if (heading < 292.5) return 'Barat ←';
    return 'Barat Laut ↖';
  }
}

// ── Driver Quick Action tile (2x2 grid style) ───────────────
class _DQA extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color, bg;
  final VoidCallback onTap;
  const _DQA(
      {required this.icon,
      required this.label,
      required this.color,
      required this.bg,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: color.withValues(alpha: 0.10),
                blurRadius: 10,
                offset: const Offset(0, 3))
          ],
        ),
        child: Row(children: [
          Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: bg, borderRadius: BorderRadius.circular(11)),
              child: Icon(icon, color: color, size: 20)),
          const SizedBox(width: 10),
          Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.black,
                      height: 1.3))),
        ]),
      ),
    );
  }
}

class _DriverQuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;

  const _DriverQuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.bgColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 3))
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                  color: bgColor, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.black,
                  height: 1.3),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Banner info halte berikutnya ─────────────────────────────
class _NextHalteBanner extends StatelessWidget {
  final HalteModel halte;
  final int halteIndex;
  final LatLng? driverPos;
  final RoutingService routingService;

  const _NextHalteBanner({
    required this.halte,
    required this.halteIndex,
    required this.driverPos,
    required this.routingService,
  });

  @override
  Widget build(BuildContext context) {
    double? distM;
    if (driverPos != null) {
      distM =
          routingService.distanceToHalte(driverPos: driverPos!, halte: halte);
    }

    String distText = '';
    if (distM != null) {
      distText = distM < 1000
          ? '${distM.toStringAsFixed(0)} m lagi'
          : '${(distM / 1000).toStringAsFixed(1)} km lagi';
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: const Color(0xFFFF6B00).withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFFFF6B00),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text('${halteIndex + 1}',
                style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Halte Berikutnya',
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 10,
                      color: Color(0xFFFF6B00))),
              Text(halte.namaHalte,
                  style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.black)),
            ],
          ),
        ),
        if (distText.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B00),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(distText,
                style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
          ),
      ]),
    );
  }
}

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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 3))
          ]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(value,
            style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: color)),
        Text(label,
            style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11,
                color: AppColors.textGrey)),
      ]),
    );
  }
}

class _DriverProfileTab extends StatefulWidget {
  final UserModel driver;
  final BusModel? bus;
  const _DriverProfileTab({required this.driver, this.bus});

  @override
  State<_DriverProfileTab> createState() => _DriverProfileTabState();
}

class _DriverProfileTabState extends State<_DriverProfileTab> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 40),
              CircleAvatar(
                radius: 50,
                backgroundColor: AppColors.primaryLight,
                backgroundImage: widget.driver.photoUrl != null
                    ? NetworkImage(widget.driver.photoUrl!)
                    : null,
                child: widget.driver.photoUrl == null
                    ? Text(
                        widget.driver.namaLengkap.substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 40,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary))
                    : null,
              ),
              const SizedBox(height: 16),
              Text(widget.driver.namaLengkap,
                  style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 22,
                      fontWeight: FontWeight.w700)),
              Text(widget.driver.email,
                  style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      color: AppColors.textGrey)),
              const SizedBox(height: 8),
              Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(8)),
                  child: const Text('Driver',
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary))),
              const SizedBox(height: 24),
              _ProfileButton(
                  icon: Icons.edit_rounded,
                  label: 'Edit Data Pribadi',
                  onTap: () {
                    Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    EditProfileScreen(user: widget.driver)))
                        .then((_) {
                      if (mounted) setState(() {});
                    });
                  }),
              const SizedBox(height: 12),
              _ProfileButton(
                  icon: Icons.assessment_rounded,
                  label: 'Laporan Operasional',
                  onTap: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => LaporanOperasionalScreen(
                                dataService: AppDataService(),
                                driverId: widget.driver.idStr,
                                busId: widget.bus?.id)));
                  }),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4))
                    ]),
                child: Column(children: [
                  _ProfileRow(
                      icon: Icons.phone,
                      label: 'No. HP',
                      value: widget.driver.noHp),
                  const Divider(color: AppColors.lightGrey, height: 20),
                  _ProfileRow(
                      icon: Icons.location_on,
                      label: 'Alamat',
                      value: widget.driver.alamat),
                ]),
              ),
              const Spacer(),
              PrimaryButton(
                  text: 'Keluar',
                  icon: Icons.logout_rounded,
                  color: AppColors.red,
                  onPressed: () {
                    context.read<AuthProvider>().logout();
                    Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                        (r) => false);
                  }),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _ProfileRow(
      {required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: AppColors.primary, size: 18)),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  color: AppColors.textGrey)),
          Text(value.isEmpty ? '-' : value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ]),
      ),
    ]);
  }
}

class _ProfileButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ProfileButton(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)
        ],
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: AppColors.primary, size: 18),
        ),
        title: Text(label,
            style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.black)),
        trailing: const Icon(Icons.chevron_right_rounded,
            color: AppColors.textGrey, size: 20),
      ),
    );
  }
}

class _RuteItem extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _RuteItem(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: AppColors.primary, size: 18)),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textGrey,
                  letterSpacing: 0.5)),
          Text(value,
              style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.black)),
        ])),
      ]),
    );
  }
}
