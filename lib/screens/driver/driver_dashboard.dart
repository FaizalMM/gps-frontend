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
import '../../services/api_client.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/bus_map_widget.dart';
import '../../widgets/skeleton_widgets.dart';
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
        bottomNavigationBar: _DriverBottomNav(
          currentIndex: _currentIndex,
          onDashboard: () => setState(() {
            _currentIndex = 0;
            _stackIndex = 0;
          }),
          onScan: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => ScanQrScreen(dataService: _dataService)),
          ),
          onProfile: () => setState(() {
            _currentIndex = 1;
            _stackIndex = 1;
          }),
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
    with TickerProviderStateMixin, WidgetsBindingObserver {
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

    WidgetsBinding.instance.addObserver(this);

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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _gpsActive) {
      if (!_gpsService.isTracking) {
        // GPS service mati saat layar off — restart tanpa ubah toggle UI
        _resumeTracking();
      }
    }
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
    WidgetsBinding.instance.removeObserver(this);
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
        if (!mounted) return;
        setState(() {
          _gpsLoading = false;
          _gpsError =
              'GPS tidak bisa diaktifkan.\nPastikan izin lokasi diberikan di Pengaturan.';
        });
      }
    } else {
      _gpsService.stopTracking();
      if (!mounted) return;
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
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: SkeletonInfoCard(),
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
                                    activeThumbColor: AppColors.primary),
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
                      const SkeletonBusCard(),
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
                    const Text('Menu',
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.black)),
                    const SizedBox(height: 12),

                    Row(children: [
                      Expanded(
                        child: _ActionCard(
                          icon: Icons.description_outlined,
                          label: 'Laporan Harian',
                          color: AppColors.blue,
                          onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => LaporanOperasionalScreen(
                                      dataService: widget.dataService,
                                      driverId: widget.driver.idStr,
                                      busId: widget.bus?.id))),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ActionCard(
                          icon: Icons.people_outline,
                          label: 'Daftar Siswa',
                          color: AppColors.purple,
                          onTap: () =>
                              _showSiswaSheet(context, widget.dataService),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ActionCard(
                          icon: Icons.alt_route_outlined,
                          label: 'Info Rute',
                          color: AppColors.pendingOrange,
                          onTap: () => _showRuteSheet(context, widget.bus),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 12),

                    _SelesaiBertugasButton(
                      bus: widget.bus,
                      attendanceCount: _attendanceToday.length,
                    ),
                    const SizedBox(height: 24),

                    // ── Penumpang Hari Ini
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
                            final dt = DateTime.tryParse(waktuNaik)?.toLocal();
                            if (dt != null) {
                              jam =
                                  '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                            }
                          }
                          String jamTurun = '';
                          if (waktuTurun != null) {
                            final dt = DateTime.tryParse(waktuTurun)?.toLocal();
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

class _SelesaiBertugasButton extends StatefulWidget {
  final dynamic bus;
  final int attendanceCount;
  const _SelesaiBertugasButton({
    required this.bus,
    required this.attendanceCount,
  });

  @override
  State<_SelesaiBertugasButton> createState() => _SelesaiBertugasButtonState();
}

class _SelesaiBertugasButtonState extends State<_SelesaiBertugasButton> {
  bool _isSubmitting = false;
  bool _sudahSubmit = false;
  final _catatanController = TextEditingController();

  @override
  void dispose() {
    _catatanController.dispose();
    super.dispose();
  }

  String _todayStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  void _showForm() {
    if (widget.bus == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Belum ada bus yang ditugaskan.'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.lightGrey,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Selesai Bertugas',
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.black)),
              const SizedBox(height: 4),
              Text(
                'Hari ini kamu mengangkut ${widget.attendanceCount} penumpang.',
                style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    color: AppColors.textGrey),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(children: [
                  const Icon(Icons.directions_bus_rounded,
                      color: AppColors.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${widget.bus?.nama ?? '-'} — ${widget.bus?.platNomor ?? '-'}',
                        style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.black),
                      ),
                      Text(_todayStr(),
                          style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11,
                              color: AppColors.textGrey)),
                    ],
                  )),
                  Text('${widget.attendanceCount} siswa',
                      style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary)),
                ]),
              ),
              const SizedBox(height: 16),
              const Text('Catatan (opsional)',
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.black)),
              const SizedBox(height: 8),
              TextField(
                controller: _catatanController,
                maxLines: 3,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 13),
                decoration: InputDecoration(
                  hintText:
                      'Contoh: Ban kempes di jalan, siswa X tidak naik, dll.',
                  hintStyle: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: AppColors.textGrey),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _submit(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: const Text('Kirim Laporan',
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit(BuildContext sheetCtx) async {
    setState(() => _isSubmitting = true);
    Navigator.pop(sheetCtx);

    try {
      final api = ApiClient();
      final today = _todayStr();

      final response = await api.post('/daily-reports', {
        'bus_id': widget.bus?.id,
        'tanggal': today,
        'total_penumpang': widget.attendanceCount,
        'catatan_driver': _catatanController.text.trim(),
      });

      if (!mounted) return;

      if (response.success) {
        setState(() {
          _isSubmitting = false;
          _sudahSubmit = true;
        });
        _catatanController.clear();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Laporan berhasil dikirim!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ));
      } else {
        setState(() => _isSubmitting = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(response.message),
            backgroundColor: Colors.red,
          ));
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: $e'),
        backgroundColor: Colors.red,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_sudahSubmit) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        ),
        child: const Row(children: [
          Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text('Laporan hari ini sudah dikirim',
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary)),
          ),
        ]),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isSubmitting ? null : _showForm,
        icon: _isSubmitting
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.check_circle_outline_rounded,
                size: 18, color: Colors.white),
        label: Text(
          _isSubmitting ? 'Mengirim laporan...' : 'Selesai Bertugas',
          style: const TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: Colors.white),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2E7D32),
          disabledBackgroundColor:
              const Color(0xFF2E7D32).withValues(alpha: 0.5),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionCard(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 8),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.black,
                  height: 1.3)),
        ]),
      ),
    );
  }
}

class _DriverBottomNav extends StatelessWidget {
  final int currentIndex;
  final VoidCallback onDashboard;
  final VoidCallback onScan;
  final VoidCallback onProfile;

  const _DriverBottomNav({
    required this.currentIndex,
    required this.onDashboard,
    required this.onScan,
    required this.onProfile,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Container(
      height: 64 + bottomPad,
      decoration: BoxDecoration(
        color: AppColors.white,
        border: const Border(
            top: BorderSide(color: AppColors.lightGrey, width: 0.5)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, -3)),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomPad),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            // Baris kiri & kanan
            Row(children: [
              Expanded(
                  child: _NavItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                label: 'Dashboard',
                isActive: currentIndex == 0,
                onTap: onDashboard,
              )),
              // Spacer tengah untuk tombol QR
              const Expanded(child: SizedBox()),
              Expanded(
                  child: _NavItem(
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                label: 'Profil',
                isActive: currentIndex == 1,
                onTap: onProfile,
              )),
            ]),
            // Tombol QR menonjol di tengah
            Positioned(
              top: -22,
              child: GestureDetector(
                onTap: onScan,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.45),
                              blurRadius: 14,
                              offset: const Offset(0, 5)),
                        ],
                      ),
                      child: const Icon(Icons.qr_code_scanner_rounded,
                          color: Colors.white, size: 26),
                    ),
                    const SizedBox(height: 4),
                    const Text('Scan QR',
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon, activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  const _NavItem(
      {required this.icon,
      required this.activeIcon,
      required this.label,
      required this.isActive,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding:
              EdgeInsets.symmetric(horizontal: isActive ? 14 : 10, vertical: 5),
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.primary.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(isActive ? activeIcon : icon,
              color: isActive ? AppColors.primary : AppColors.textGrey,
              size: 22),
        ),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                color: isActive ? AppColors.primary : AppColors.textGrey)),
      ]),
    );
  }
}

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

// ── Profile Tab

class _DriverProfileTab extends StatefulWidget {
  final UserModel driver;
  final BusModel? bus;
  const _DriverProfileTab({required this.driver, this.bus});

  @override
  State<_DriverProfileTab> createState() => _DriverProfileTabState();
}

class _DriverProfileTabState extends State<_DriverProfileTab> {
  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Keluar',
            style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                fontWeight: FontWeight.w700)),
        content: const Text('Kamu yakin ingin keluar dari akun ini?',
            style: TextStyle(fontFamily: 'Poppins', fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal',
                style: TextStyle(
                    fontFamily: 'Poppins', color: AppColors.textGrey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AuthProvider>().logout();
              Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (r) => false);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.red,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Keluar',
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final driver = widget.driver;
    // local variable agar Dart bisa promote nullable → non-nullable
    final bus = widget.bus;
    final initial = driver.namaLengkap.isNotEmpty
        ? driver.namaLengkap[0].toUpperCase()
        : '?';
    final driverDetail = driver.driverDetail;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(driver, bus, initial),
              if (bus != null) _buildStatsBar(bus),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _ProfSectionLabel(label: 'Data Pribadi'),
                    const SizedBox(height: 10),
                    _ProfInfoCard(children: [
                      _ProfInfoRow(
                        icon: Icons.badge_outlined,
                        label: 'NIK',
                        value: (driverDetail != null &&
                                driverDetail.nik.isNotEmpty)
                            ? driverDetail.nik
                            : '-',
                      ),
                      const _ProfDivider(),
                      _ProfInfoRow(
                        icon: Icons.email_outlined,
                        label: 'Email',
                        value: driver.email.isNotEmpty ? driver.email : '-',
                      ),
                      const _ProfDivider(),
                      _ProfInfoRow(
                        icon: Icons.phone_outlined,
                        label: 'No. HP',
                        value: driver.noHp.isNotEmpty ? driver.noHp : '-',
                      ),
                      const _ProfDivider(),
                      _ProfInfoRow(
                        icon: Icons.location_on_outlined,
                        label: 'Alamat',
                        value: driver.alamat.isNotEmpty ? driver.alamat : '-',
                        maxLines: 2,
                      ),
                    ]),
                    const SizedBox(height: 20),
                    const _ProfSectionLabel(label: 'Bus Ditugaskan'),
                    const SizedBox(height: 10),
                    if (bus != null)
                      _ProfInfoCard(children: [
                        _ProfInfoRow(
                          icon: Icons.directions_bus_outlined,
                          label: 'Nama Bus',
                          value: bus.nama,
                        ),
                        const _ProfDivider(),
                        _ProfInfoRow(
                          icon: Icons.pin_outlined,
                          label: 'Plat Nomor',
                          value: bus.platNomor,
                        ),
                        const _ProfDivider(),
                        _ProfInfoRow(
                          icon: Icons.route_outlined,
                          label: 'Rute',
                          value:
                              bus.rute.isNotEmpty ? bus.rute : 'Belum ada rute',
                        ),
                        const _ProfDivider(),
                        _ProfInfoRowStatus(isActive: bus.isActive),
                      ])
                    else
                      const _ProfInfoCard(children: [
                        _ProfInfoRow(
                          icon: Icons.directions_bus_outlined,
                          label: 'Bus',
                          value: 'Belum ada bus yang ditugaskan',
                        ),
                      ]),
                    const SizedBox(height: 20),
                    const _ProfSectionLabel(label: 'Manajemen'),
                    const SizedBox(height: 10),
                    _ProfMenuCard(
                      icon: Icons.edit_outlined,
                      title: 'Edit Data Pribadi',
                      subtitle: 'Ubah nama, nomor HP, dan alamat',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => EditProfileScreen(user: driver)),
                        ).then((_) {
                          if (mounted) setState(() {});
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    _ProfMenuCard(
                      icon: Icons.assessment_outlined,
                      title: 'Laporan Operasional',
                      subtitle: 'Riwayat perjalanan & laporan harian',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => LaporanOperasionalScreen(
                              dataService: AppDataService(),
                              driverId: driver.idStr,
                              busId: bus?.id,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _showLogoutDialog,
                        icon: const Icon(Icons.logout_rounded,
                            color: AppColors.red, size: 18),
                        label: const Text(
                          'Keluar dari Akun',
                          style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.red),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                              color: AppColors.red, width: 1.2),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(UserModel driver, BusModel? bus, String initial) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(children: [
        Stack(children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3)),
            child: ClipOval(
              child: driver.photoUrl != null
                  ? Image.network(driver.photoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _AvatarInitial(
                          initial: initial, size: 90, textSize: 36))
                  : _AvatarInitial(initial: initial, size: 90, textSize: 36),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        Text(driver.namaLengkap,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20)),
          child: Text(
            // gunakan local var bus agar aman dari non-promo error
            bus != null ? 'Driver \u2022 ${bus.nama}' : 'Driver',
            style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.white),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.4), width: 0.8)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.verified_outlined, size: 13, color: Colors.white),
            const SizedBox(width: 4),
            Text(
              driver.status == AccountStatus.active
                  ? 'Akun Aktif'
                  : 'Akun Non-aktif',
              style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.white),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _buildStatsBar(BusModel bus) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      transform: Matrix4.translationValues(0, -20, 0),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4))
          ]),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(children: [
        Expanded(
            child: _StatItem(
                value: bus.isActive ? 'Aktif' : 'Non-aktif',
                label: 'Status Bus',
                color: bus.isActive ? AppColors.primary : AppColors.textGrey,
                icon: Icons.directions_bus_rounded)),
        Container(width: 1, height: 44, color: AppColors.lightGrey),
        Expanded(
            child: _StatItem(
                value: bus.platNomor.isNotEmpty ? bus.platNomor : '-',
                label: 'Plat Nomor',
                color: AppColors.blue,
                icon: Icons.pin_rounded)),
        Container(width: 1, height: 44, color: AppColors.lightGrey),
        Expanded(
            child: _StatItem(
                value: bus.gpsActive ? 'ON' : 'OFF',
                label: 'GPS',
                color: bus.gpsActive ? AppColors.primary : AppColors.textGrey,
                icon: Icons.gps_fixed_rounded)),
      ]),
    );
  }
}

class _AvatarInitial extends StatelessWidget {
  final String initial;
  final double size, textSize;
  const _AvatarInitial(
      {required this.initial, required this.size, required this.textSize});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        color: AppColors.primaryLight,
        child: Center(
          child: Text(initial,
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: textSize,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary)),
        ),
      );
}

class _StatItem extends StatelessWidget {
  final String value, label;
  final Color color;
  final IconData icon;
  const _StatItem(
      {required this.value,
      required this.label,
      required this.color,
      required this.icon});
  @override
  Widget build(BuildContext context) => Column(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color)),
        Text(label,
            style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 10,
                color: AppColors.textGrey)),
      ]);
}

class _ProfSectionLabel extends StatelessWidget {
  final String label;
  const _ProfSectionLabel({required this.label});
  @override
  Widget build(BuildContext context) => Text(label,
      style: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.black));
}

class _ProfInfoCard extends StatelessWidget {
  final List<Widget> children;
  const _ProfInfoCard({required this.children});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4))
            ]),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(children: children),
      );
}

class _ProfInfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final int maxLines;
  const _ProfInfoRow(
      {required this.icon,
      required this.label,
      required this.value,
      this.maxLines = 1});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(9)),
            child: Icon(icon, color: AppColors.primary, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textGrey,
                      letterSpacing: 0.3)),
              const SizedBox(height: 1),
              Text(value,
                  maxLines: maxLines,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.black)),
            ]),
          ),
        ]),
      );
}

class _ProfInfoRowStatus extends StatelessWidget {
  final bool isActive;
  const _ProfInfoRowStatus({required this.isActive});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(9)),
            child: const Icon(Icons.circle_outlined,
                color: AppColors.primary, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Status Bus',
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textGrey,
                      letterSpacing: 0.3)),
              const SizedBox(height: 2),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                    color:
                        isActive ? AppColors.primaryLight : AppColors.surface2,
                    borderRadius: BorderRadius.circular(8)),
                child: Text(
                  isActive ? 'Aktif Beroperasi' : 'Tidak Aktif',
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isActive ? AppColors.primary : AppColors.textGrey),
                ),
              ),
            ]),
          ),
        ]),
      );
}

class _ProfDivider extends StatelessWidget {
  const _ProfDivider();
  @override
  Widget build(BuildContext context) =>
      const Divider(color: AppColors.lightGrey, height: 1);
}

class _ProfMenuCard extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  const _ProfMenuCard(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2))
              ]),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title,
                      style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.black)),
                  Text(subtitle,
                      style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          color: AppColors.textGrey)),
                ])),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textGrey, size: 20),
          ]),
        ),
      );
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
      if (!mounted) return;
      setState(() {
        _error = 'Bus belum ditugaskan ke akun driver ini.';
        _loading = false;
      });
      return;
    }
    try {
      final list = await BusService().getDriverBusStudents(bus.id);
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
                      const Text('Daftar Siswa',
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
        Expanded(
          child: _loading
              ? const SkeletonFullPage()
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
