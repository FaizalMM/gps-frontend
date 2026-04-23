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
import '../../services/bus_service.dart';
import '../../services/domain_services.dart';
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
  BusModel? _driverBus;

  // [FIX 1] Lacak apakah sedang refresh bus dari API — untuk tampilkan loading
  bool _isRefreshingBus = false;

  @override
  void initState() {
    super.initState();
    _driverBus = Provider.of<AuthProvider>(context, listen: false)
        .authService
        .cachedDriverBus;

    if (_driverBus == null) {
      _refreshBusFromApi();
    }
  }

  // [FIX 2] Gunakan refreshDriverBus() dari AuthProvider agar notifyListeners()
  // ikut dipanggil dan semua widget listener terupdate secara konsisten
  Future<void> _refreshBusFromApi() async {
    if (!mounted) return;
    setState(() => _isRefreshingBus = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.refreshDriverBus(); // notifyListeners() ada di dalam
    final refreshedBus = authProvider.authService.cachedDriverBus;

    if (mounted) {
      setState(() {
        _isRefreshingBus = false;
        if (refreshedBus != null) _driverBus = refreshedBus;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.read<AuthProvider>().currentUser!;
    final BusModel? bus = _driverBus;

    // [FIX 3] isLoadingBus sekarang dinamis — bukan selalu false
    final bool isLoadingBus = _isRefreshingBus && bus == null;

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

// ── _DriverHomeTab ────────────────────────────────────────────

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
  List<LatLng> _navPolyline = [];
  int _targetHalteIndex = 0;
  HalteModel? _targetHalte;
  LatLng? _driverLatLng;
  StreamSubscription<Position>? _positionSub;

  // Absensi hari ini — diperbarui setiap 15 detik saat GPS aktif
  List<Map<String, dynamic>> _attendanceToday = [];
  Timer? _attendancePollTimer;
  bool _isLoadingAttendance = false; // guard: cegah request dobel

  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _gpsActive = widget.bus?.gpsActive ?? false;

    _positionSub = _gpsService.positionStream.listen((position) {
      if (!mounted || position.latitude == 0) return;
      final pos = LatLng(position.latitude, position.longitude);
      setState(() => _driverLatLng = pos);

      final bus = widget.bus;
      if (_gpsActive && bus != null && bus.routeList.isNotEmpty) {
        final haltes = bus.routeList.first.haltes;
        _updateNavigation(pos, haltes);
      }
    });

    if (_gpsActive) {
      if (_gpsService.isTracking) {
        if (_gpsService.lastPosition != null) {
          final p = _gpsService.lastPosition!;
          _driverLatLng = LatLng(p.latitude, p.longitude);
        }
      } else {
        _resumeTracking();
      }
    }

    _pulseController =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
        CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));

    // Load absensi awal + mulai polling
    _loadAttendanceToday();
    _attendancePollTimer = Timer.periodic(
        const Duration(seconds: 15), (_) => _loadAttendanceToday());
  }

  Future<void> _loadAttendanceToday() async {
    final bus = widget.bus;
    if (bus == null || !mounted || _isLoadingAttendance) return;
    _isLoadingAttendance = true;
    try {
      final list = await DriverService().getBusAttendanceToday(bus.id);
      if (mounted) setState(() => _attendanceToday = list);
    } catch (_) {
    } finally {
      _isLoadingAttendance = false;
    }
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _attendancePollTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _resumeTracking() async {
    final started = await _gpsService.startTracking();
    if (!mounted) return;
    if (started) {
      final pos = await _gpsService.getCurrentPosition();
      if (mounted && pos != null) {
        final latLng = LatLng(pos.latitude, pos.longitude);
        setState(() => _driverLatLng = latLng);
        await _gpsService.sendCurrentPosition(pos);
        await _initNavigation(latLng);
      }
    } else {
      setState(() => _gpsActive = false);
      await _gpsService.stopTracking();
    }
  }

  Future<void> _initNavigation(LatLng driverPos) async {
    final bus = widget.bus;
    if (bus == null || bus.routeList.isEmpty) return;
    final route = bus.routeList.first;
    if (route.haltes.isEmpty) return;
    _targetHalteIndex = 0;
    await _updateNavigation(driverPos, route.haltes);
  }

  // Flag cegah request navigasi paralel yang bisa tumpang tindih
  bool _navRequestInProgress = false;

  Future<void> _updateNavigation(
      LatLng driverPos, List<RouteHalteModel> haltes) async {
    if (haltes.isEmpty || _navRequestInProgress) return;

    final nextIdx = _routingService.getNextHalteIndex(
      driverPos: driverPos,
      haltes: haltes,
      currentIndex: _targetHalteIndex,
    );

    // Halte berganti — hapus cache rute lama agar rute baru di-fetch
    if (nextIdx != _targetHalteIndex) {
      final oldHalte = _targetHalteIndex < haltes.length
          ? haltes[_targetHalteIndex].halte
          : null;
      if (oldHalte != null) {
        _routingService
            .clearCacheForHalte(LatLng(oldHalte.latitude, oldHalte.longitude));
      }
      if (mounted) setState(() => _targetHalteIndex = nextIdx);
    }

    // Semua halte sudah dilewati — rute selesai, jangan kosongkan polyline
    if (_targetHalteIndex >= haltes.length) {
      if (mounted) setState(() => _targetHalte = null);
      return;
    }

    final halte = haltes[_targetHalteIndex].halte;
    if (halte == null) return;

    final target = LatLng(halte.latitude, halte.longitude);

    _navRequestInProgress = true;
    final polyline = await _routingService.getNavigationRoute(
      from: driverPos,
      to: target,
    );
    _navRequestInProgress = false;

    if (mounted) {
      setState(() {
        // Hanya update jika polyline valid — jaga rute lama tetap tampil jika gagal
        if (polyline.isNotEmpty) _navPolyline = polyline;
        _targetHalte = halte;
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
      final started = await _gpsService.startTracking();
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
        if (pos != null) await _initNavigation(pos);
      } else {
        setState(() {
          _gpsLoading = false;
          _gpsError =
              'GPS tidak bisa diaktifkan.\nPastikan izin lokasi diberikan di Pengaturan.';
        });
      }
    } else {
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
    final bus = widget.bus;

    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        maxChildSize: 0.85,
        minChildSize: 0.3,
        builder: (_, ctrl) => _SiswaListSheet(
          bus: bus,
          scrollCtrl: ctrl,
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
                                if (_gpsActive && _targetHalte != null)
                                  _NextHalteBanner(
                                    halte: _targetHalte!,
                                    halteIndex: _targetHalteIndex,
                                    driverPos: _driverLatLng,
                                    routingService: _routingService,
                                  ),
                                const SizedBox(height: 12),
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
                    const SizedBox(height: 24),

                    // ── Penumpang Hari Ini ─────────────────────────
                    Row(children: [
                      const Expanded(
                          child: Text('Penumpang Hari Ini',
                              style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.black))),
                      GestureDetector(
                        onTap: _loadAttendanceToday,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(20)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Text(
                              '${_attendanceToday.length} siswa',
                              style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.refresh_rounded,
                                size: 13, color: AppColors.primary),
                          ]),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 10),

                    if (_attendanceToday.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 8)
                            ]),
                        child: const Column(children: [
                          Icon(Icons.people_outline_rounded,
                              size: 36, color: AppColors.lightGrey),
                          SizedBox(height: 8),
                          Text('Belum ada siswa naik hari ini',
                              style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 13,
                                  color: AppColors.textGrey)),
                        ]),
                      )
                    else
                      Column(
                        children: _attendanceToday.map((a) {
                          final name = a['student_name'] as String? ?? '-';
                          final halte = a['halte_naik'] as String? ?? '-';
                          final sudahTurun = a['waktu_turun'] != null;
                          final qrId = a['qr_id'] as String? ?? '';
                          final waktuNaik = a['waktu_naik'] as String?;
                          final waktuTurun = a['waktu_turun'] as String?;
                          String jam = '';
                          if (waktuNaik != null) {
                            final dt = DateTime.tryParse(waktuNaik);
                            if (dt != null) {
                              jam =
                                  '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                            }
                          }
                          String jamTurun = '';
                          if (waktuTurun != null) {
                            final dt = DateTime.tryParse(waktuTurun);
                            if (dt != null) {
                              jamTurun =
                                  '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                            }
                          }
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                                color: AppColors.white,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.04),
                                      blurRadius: 8)
                                ]),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                        color: sudahTurun
                                            ? AppColors.primaryLight
                                            : AppColors.orange
                                                .withValues(alpha: 0.12),
                                        shape: BoxShape.circle),
                                    child: Center(
                                        child: Text(
                                      name.isNotEmpty
                                          ? name[0].toUpperCase()
                                          : '?',
                                      style: TextStyle(
                                          fontFamily: 'Poppins',
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15,
                                          color: sudahTurun
                                              ? AppColors.primary
                                              : AppColors.orange),
                                    )),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                        Text(name,
                                            style: const TextStyle(
                                                fontFamily: 'Poppins',
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.black)),
                                        Text(
                                          [
                                            if (jam.isNotEmpty) 'Naik $jam',
                                            if (halte != '-') '\u2022 $halte',
                                            if (jamTurun.isNotEmpty)
                                              '\u2022 Turun $jamTurun',
                                          ].join(' '),
                                          style: const TextStyle(
                                              fontFamily: 'Poppins',
                                              fontSize: 11,
                                              color: AppColors.textGrey),
                                        ),
                                      ])),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                        color: sudahTurun
                                            ? AppColors.primaryLight
                                            : AppColors.orange
                                                .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8)),
                                    child: Text(
                                      sudahTurun ? 'Sudah Turun' : 'Di Bus',
                                      style: TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: sudahTurun
                                              ? AppColors.primary
                                              : AppColors.orange),
                                    ),
                                  ),
                                ]),
                                // Tombol checkout — hanya muncul jika siswa masih di bus
                                if (!sudahTurun && qrId.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 36,
                                    child: _CheckoutButton(
                                      qrId: qrId,
                                      studentName: name,
                                      onDone: _loadAttendanceToday,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
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

// ── _DQA ─────────────────────────────────────────────────────

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

// [FIX 4] _DriverQuickAction DIHAPUS — tidak dipakai, sudah digantikan _DQA

// ── Banner halte berikutnya ───────────────────────────────────

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

// ── Profile Tab ───────────────────────────────────────────────

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

// ══════════════════════════════════════════════════════════════
// _SiswaListSheet — list siswa yang terdaftar di bus driver ini
// Data diambil dari API /buses/{id}/students bukan dari stream global
// ══════════════════════════════════════════════════════════════
class _SiswaListSheet extends StatefulWidget {
  final BusModel? bus;
  final ScrollController scrollCtrl;
  const _SiswaListSheet({required this.bus, required this.scrollCtrl});
  @override
  State<_SiswaListSheet> createState() => _SiswaListSheetState();
}

class _SiswaListSheetState extends State<_SiswaListSheet> {
  List<UserModel> _siswa = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final bus = widget.bus;
    if (bus == null) {
      setState(() {
        _error = 'Bus belum ditugaskan ke akun driver ini.';
        _loading = false;
      });
      return;
    }
    try {
      final list = await BusService().getBusStudents(bus.id);
      if (!mounted) return;
      setState(() {
        _siswa = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal memuat daftar siswa.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final busName = widget.bus?.nama ?? '-';
    return Container(
      decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(children: [
        // Handle + header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
          child: Column(children: [
            Center(
              child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.lightGrey,
                      borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 14),
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.people_rounded,
                    color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Siswa di Bus Saya',
                          style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.black)),
                      Text(busName,
                          style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              color: AppColors.textGrey)),
                    ]),
              ),
              if (!_loading)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    '${_siswa.length} siswa',
                    style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary),
                  ),
                ),
            ]),
          ]),
        ),
        const Divider(height: 1, color: AppColors.lightGrey),

        // Content
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary))
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
                  : _siswa.isEmpty
                      ? Center(
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.person_off_outlined,
                                size: 52,
                                color:
                                    AppColors.primary.withValues(alpha: 0.3)),
                            const SizedBox(height: 12),
                            const Text('Belum ada siswa terdaftar',
                                style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textGrey)),
                            const SizedBox(height: 6),
                            const Text('Hubungi admin untuk menambahkan siswa',
                                style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 12,
                                    color: AppColors.textGrey)),
                          ]),
                        )
                      : ListView.builder(
                          controller: widget.scrollCtrl,
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
                          itemCount: _siswa.length,
                          itemBuilder: (_, i) {
                            final s = _siswa[i];
                            final initial = s.namaLengkap.isNotEmpty
                                ? s.namaLengkap[0].toUpperCase()
                                : '?';
                            // Ambil info halte dari studentDetail jika tersedia
                            final halteId =
                                s.studentDetail?.halteId?.toString();
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                  color: AppColors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                        color: Colors.black
                                            .withValues(alpha: 0.04),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2))
                                  ]),
                              child: Row(children: [
                                // Avatar inisial
                                Container(
                                    width: 44,
                                    height: 44,
                                    decoration: const BoxDecoration(
                                        color: AppColors.primaryLight,
                                        shape: BoxShape.circle),
                                    child: Center(
                                        child: Text(initial,
                                            style: const TextStyle(
                                                fontFamily: 'Poppins',
                                                fontWeight: FontWeight.w800,
                                                color: AppColors.primary,
                                                fontSize: 18)))),
                                const SizedBox(width: 12),
                                // Info siswa
                                Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Text(s.namaLengkap,
                                          style: const TextStyle(
                                              fontFamily: 'Poppins',
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.black)),
                                      const SizedBox(height: 2),
                                      if (s.alamat.isNotEmpty)
                                        Row(children: [
                                          const Icon(Icons.location_on_rounded,
                                              size: 11,
                                              color: AppColors.textGrey),
                                          const SizedBox(width: 3),
                                          Expanded(
                                              child: Text(s.alamat,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                      fontFamily: 'Poppins',
                                                      fontSize: 11,
                                                      color:
                                                          AppColors.textGrey))),
                                        ]),
                                    ])),
                                // Status badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: s.status == AccountStatus.active
                                        ? AppColors.primaryLight
                                        : AppColors.surface2,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    s.status == AccountStatus.active
                                        ? 'Aktif'
                                        : 'Non-aktif',
                                    style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: s.status == AccountStatus.active
                                            ? AppColors.primary
                                            : AppColors.textGrey),
                                  ),
                                ),
                              ]),
                            );
                          }),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// _CheckoutButton — tombol turunkan siswa dari list penumpang hari ini
// Dipanggil dari driver dashboard, bukan dari scan sheet
// ══════════════════════════════════════════════════════════════
class _CheckoutButton extends StatefulWidget {
  final String qrId;
  final String studentName;
  final VoidCallback onDone; // refresh list setelah checkout berhasil

  const _CheckoutButton({
    required this.qrId,
    required this.studentName,
    required this.onDone,
  });

  @override
  State<_CheckoutButton> createState() => _CheckoutButtonState();
}

class _CheckoutButtonState extends State<_CheckoutButton> {
  bool _loading = false;

  Future<void> _doCheckout() async {
    // Konfirmasi dulu
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Konfirmasi Turun',
            style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                fontWeight: FontWeight.w700)),
        content: Text(
          'Tandai ${widget.studentName} sudah turun dari bus?',
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal',
                style: TextStyle(
                    fontFamily: 'Poppins', color: AppColors.textGrey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Ya, Sudah Turun',
                style: TextStyle(
                    fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _loading = true);

    // Ambil posisi GPS driver saat ini
    Position? pos;
    try {
      pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
              timeLimit: Duration(seconds: 8)));
    } catch (_) {}

    final ok = await DriverService().checkoutStudent(
      qrId: widget.qrId,
      latitude: pos?.latitude ?? -7.6298,
      longitude: pos?.longitude ?? 111.5239,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text('${widget.studentName} berhasil turun',
              style: const TextStyle(
                  fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
        ]),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ));
      widget.onDone(); // refresh list penumpang
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Gagal checkout. Coba lagi.',
            style: TextStyle(fontFamily: 'Poppins')),
        backgroundColor: AppColors.red,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: _loading ? null : _doCheckout,
      icon: _loading
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.orange))
          : const Icon(Icons.logout_rounded, size: 14, color: AppColors.orange),
      label: Text(
        _loading ? 'Memproses...' : 'Turunkan Siswa',
        style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.orange),
      ),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: AppColors.orange, width: 1.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      ),
    );
  }
}
