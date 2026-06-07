import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../models/models_api.dart';
import '../../services/auth_provider.dart';
import '../../services/app_data_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/bus_map_widget.dart';
import '../../widgets/skeleton_widgets.dart';
import '../auth/login_screen.dart';
import '../common/edit_profile_screen.dart';
import '../common/change_password_screen.dart';
import 'admin_siswa_screen.dart';
import 'admin_driver_screen.dart';
import 'admin_pending_screen.dart';
import 'admin_bus_screen.dart';
import 'admin_halte_screen.dart';
import 'admin_analitik_screen.dart';
import 'admin_tracking_screen.dart';
import 'admin_management_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});
  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _currentIndex = 0;
  final AppDataService _dataService = AppDataService();
  late final List<Widget> _screens;
  StreamSubscription<List<BusModel>>? _gpsSub;
  Map<int, bool> _prevGpsState = {};

  @override
  void initState() {
    super.initState();
    _dataService.loadAll();
    _screens = [
      _HomeTab(dataService: _dataService),
      AdminAnalitikScreen(dataService: _dataService),
      _ProfileTab(dataService: _dataService),
    ];

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (!auth.isLoggedIn) return;

      _dataService.onUnauthorized = () {
        if (!mounted) return;
        auth.logout();
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      };

      _dataService.startGpsPolling();
      _dataService.startPendingPolling();

      _dataService.onNewPendingStudent = (jumlahBaru) {
        if (!mounted) return;
        _showNewPendingToast(jumlahBaru);
      };

      _prevGpsState = {for (final b in _dataService.buses) b.id: b.gpsActive};
      _gpsSub = _dataService.busesStream.listen((buses) {
        if (!mounted) return;
        for (final bus in buses) {
          final prev = _prevGpsState[bus.id];
          if (prev != null && prev != bus.gpsActive) {
            final name = bus.driverName.isNotEmpty ? bus.driverName : bus.nama;
            _showGpsToast(name, bus.nama, bus.gpsActive);
          }
        }
        _prevGpsState = {for (final b in buses) b.id: b.gpsActive};
      });
    });
  }

  void _showNewPendingToast(int jumlahBaru) {
    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (ctx) => _NewPendingToast(count: jumlahBaru),
    );
    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 4), () => entry.remove());
  }

  void _showGpsToast(String driverName, String busName, bool gpsActive) {
    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (ctx) => _GpsToast(
        driverName: driverName,
        busName: busName,
        gpsActive: gpsActive,
      ),
    );
    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 5), () => entry.remove());
  }

  @override
  void dispose() {
    _gpsSub?.cancel();
    _dataService.stopGpsPolling();
    _dataService.stopPendingPolling();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _screens[_currentIndex],
      bottomNavigationBar: MobitraBottomNav(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        items: const [
          BottomNavItem(
              icon: Icons.home_outlined,
              activeIcon: Icons.home_rounded,
              label: 'Beranda'),
          BottomNavItem(
              icon: Icons.bar_chart_outlined,
              activeIcon: Icons.bar_chart_rounded,
              label: 'Analitik'),
          BottomNavItem(
              icon: Icons.person_outline,
              activeIcon: Icons.person_rounded,
              label: 'Profil'),
        ],
      ),
    );
  }
}

class _HomeTab extends StatefulWidget {
  final AppDataService dataService;
  const _HomeTab({required this.dataService});
  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  final MapController _mapController = MapController();
  BusModel? _focusedBus;

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 11) return 'Selamat pagi';
    if (h < 15) return 'Selamat siang';
    if (h < 18) return 'Selamat sore';
    return 'Selamat malam';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MobitraAppBar(
              pendingCount: widget.dataService.pendingUsers.length,
              onNotification: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          AdminPendingScreen(dataService: widget.dataService))),
              onProfile: () {},
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_greeting,
                      style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          color: AppColors.textGrey)),
                  const Text('Admin',
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.black,
                          height: 1.2)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: StreamBuilder<List<BusModel>>(
                stream: widget.dataService.busesStream,
                builder: (_, bs) {
                  final buses = bs.data ?? widget.dataService.buses;
                  return StreamBuilder<List<UserModel>>(
                    stream: widget.dataService.usersStream,
                    builder: (_, us) {
                      final users = us.data ?? widget.dataService.users;
                      final gpsActive = buses.where((b) => b.gpsActive).length;
                      final siswa =
                          users.where((u) => u.role == UserRole.siswa).length;
                      final pending = users
                          .where((u) => u.status == AccountStatus.pending)
                          .length;
                      final adminCount =
                          users.where((u) => u.role == UserRole.admin).length;
                      return Column(children: [
                        Row(children: [
                          Expanded(
                              child: _StatCard(
                                  value: '$gpsActive',
                                  label: 'Bus Beroperasi',
                                  sub: 'dari ${buses.length} bus',
                                  icon: Icons.directions_bus_rounded,
                                  color: AppColors.primary,
                                  filled: true)),
                          const SizedBox(width: 10),
                          Expanded(
                              child: _StatCard(
                                  value: '$siswa',
                                  label: 'Siswa',
                                  sub: 'Terdaftar',
                                  icon: Icons.school_rounded,
                                  color: AppColors.blue)),
                          const SizedBox(width: 10),
                          Expanded(
                              child: GestureDetector(
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => AdminPendingScreen(
                                        dataService: widget.dataService))),
                            child: _StatCard(
                                value: '$pending',
                                label: 'Persetujuan',
                                sub: 'Menunggu',
                                icon: Icons.pending_rounded,
                                color: AppColors.orange),
                          )),
                        ]),
                        if (adminCount > 0) ...[
                          const SizedBox(height: 10),
                          GestureDetector(
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const AdminManagementScreen())),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color:
                                    AppColors.primary.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.15)),
                              ),
                              child: Row(children: [
                                const Icon(Icons.admin_panel_settings_rounded,
                                    size: 16, color: AppColors.primary),
                                const SizedBox(width: 8),
                                Text('$adminCount Admin Terdaftar',
                                    style: const TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.primary)),
                                const Spacer(),
                                const Text('Kelola',
                                    style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 11,
                                        color: AppColors.primary)),
                                const SizedBox(width: 4),
                                const Icon(Icons.chevron_right_rounded,
                                    size: 14, color: AppColors.primary),
                              ]),
                            ),
                          ),
                        ],
                      ]);
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Live Tracking',
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.black)),
                  GestureDetector(
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => AdminTrackingScreen(
                                dataService: widget.dataService))),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.open_in_full_rounded,
                              size: 13, color: AppColors.primary),
                          SizedBox(width: 4),
                          Text('Buka Peta',
                              style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            StreamBuilder<List<BusModel>>(
              stream: widget.dataService.busesStream,
              builder: (_, s) {
                final buses = s.data ?? widget.dataService.buses;
                final active = buses.where((b) => b.gpsActive).toList();

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => AdminTrackingScreen(
                                    dataService: widget.dataService,
                                    initialFocus: _focusedBus))),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Stack(children: [
                            BusMapWidget(
                              buses: active,
                              height: 185,
                              showAllBuses: true,
                              interactive: false,
                              mapController: _mapController,
                              focusBus: _focusedBus,
                              showInfoCard: false,
                            ),
                            if (active.isEmpty)
                              Positioned(
                                bottom: 10,
                                left: 0,
                                right: 0,
                                child: Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.white.withValues(alpha: 0.92),
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                            color: Colors.black
                                                .withValues(alpha: 0.1),
                                            blurRadius: 6)
                                      ],
                                    ),
                                    child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 6,
                                            height: 6,
                                            decoration: const BoxDecoration(
                                              color: AppColors.textGrey,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          const Text(
                                              'Tidak ada bus aktif saat ini',
                                              style: TextStyle(
                                                  fontFamily: 'Poppins',
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w500,
                                                  color: AppColors.textGrey)),
                                        ]),
                                  ),
                                ),
                              ),
                          ]),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...active.map((b) {
                        final isFocused = _focusedBus?.id == b.id;
                        return GestureDetector(
                          onTap: () {
                            setState(() => _focusedBus = b);
                            _mapController.move(
                                LatLng(b.latitude, b.longitude), 16.0);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: isFocused
                                  ? AppColors.primaryLight
                                  : AppColors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isFocused
                                    ? AppColors.primary
                                    : Colors.transparent,
                              ),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2))
                              ],
                            ),
                            child: Row(children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: isFocused
                                      ? AppColors.primary
                                      : AppColors.primaryLight,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(Icons.directions_bus_rounded,
                                    size: 18,
                                    color: isFocused
                                        ? Colors.white
                                        : AppColors.primary),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(b.nama,
                                        style: TextStyle(
                                            fontFamily: 'Poppins',
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: isFocused
                                                ? AppColors.primary
                                                : AppColors.black)),
                                    if (b.driverName.isNotEmpty)
                                      Text(b.driverName,
                                          style: const TextStyle(
                                              fontFamily: 'Poppins',
                                              fontSize: 11,
                                              color: AppColors.textGrey)),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                        color: AppColors.primary,
                                        borderRadius: BorderRadius.circular(6)),
                                    child: const Text('LIVE',
                                        style: TextStyle(
                                            fontFamily: 'Poppins',
                                            fontSize: 9,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white)),
                                  ),
                                  const SizedBox(height: 3),
                                  Text('${b.speed.toStringAsFixed(0)} km/h',
                                      style: TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: isFocused
                                              ? AppColors.primary
                                              : AppColors.black)),
                                ],
                              ),
                            ]),
                          ),
                        );
                      }),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text('Kelola',
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.black)),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                Expanded(
                    child: _QuickCard(
                  icon: Icons.school_rounded,
                  label: 'Siswa',
                  color: AppColors.primary,
                  stream: widget.dataService.usersStream,
                  initialCount: widget.dataService.siswaList.length,
                  count: (u) => u
                      .where((x) => x.role == UserRole.siswa)
                      .length
                      .toString(),
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => AdminSiswaScreen(
                              dataService: widget.dataService))),
                )),
                const SizedBox(width: 12),
                Expanded(
                    child: _QuickCard(
                  icon: Icons.directions_bus_rounded,
                  label: 'Bus',
                  color: AppColors.blue,
                  stream: widget.dataService.busesStream,
                  busStream: true,
                  initialCount: widget.dataService.buses.length,
                  count: (_) => '',
                  busCount: (b) => b.length.toString(),
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              AdminBusScreen(dataService: widget.dataService))),
                )),
                const SizedBox(width: 12),
                Expanded(
                    child: _QuickCard(
                  icon: Icons.badge_rounded,
                  label: 'Driver',
                  color: AppColors.purple,
                  stream: widget.dataService.usersStream,
                  initialCount: widget.dataService.drivers.length,
                  count: (u) => u
                      .where((x) => x.role == UserRole.driver)
                      .length
                      .toString(),
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => AdminDriverScreen(
                              dataService: widget.dataService))),
                )),
                const SizedBox(width: 12),
                Expanded(
                    child: _QuickCard(
                  icon: Icons.location_on_rounded,
                  label: 'Halte',
                  color: AppColors.orange,
                  stream: widget.dataService.haltesStream,
                  halteStream: true,
                  halteCount: (h) => h.length.toString(),
                  initialCount: widget.dataService.haltes.length,
                  count: (_) => '',
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => AdminHalteScreen(
                              dataService: widget.dataService))),
                )),
              ]),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GestureDetector(
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AdminManagementScreen())),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.lightGrey),
                  ),
                  child: Row(children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.admin_panel_settings_rounded,
                          size: 20, color: AppColors.primary),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Manajemen Admin',
                                style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.black)),
                            Text('Kelola akun admin sistem',
                                style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 11,
                                    color: AppColors.textGrey)),
                          ]),
                    ),
                    const Icon(Icons.chevron_right_rounded,
                        size: 20, color: AppColors.textGrey),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(children: [
                  Icon(Icons.info_outline_rounded,
                      size: 16, color: AppColors.primary),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Untuk mengatur rute & halte bus, buka menu Bus → tap bus yang ingin diatur → "Atur Rute & Halte Bus".',
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          color: AppColors.primary),
                    ),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GestureDetector(
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => AdminPendingScreen(
                            dataService: widget.dataService))),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 3))
                    ],
                  ),
                  child: Row(children: [
                    StreamBuilder<List<UserModel>>(
                      stream: widget.dataService.usersStream,
                      builder: (_, s) {
                        final pending = (s.data ?? widget.dataService.users)
                            .where((u) => u.status == AccountStatus.pending)
                            .length;
                        return Stack(clipBehavior: Clip.none, children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                                color: AppColors.orange.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12)),
                            child: const Icon(Icons.pending_actions_rounded,
                                color: AppColors.orange, size: 22),
                          ),
                          if (pending > 0)
                            Positioned(
                              top: -4,
                              right: -4,
                              child: Container(
                                constraints: const BoxConstraints(
                                    minWidth: 18, minHeight: 18),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                decoration: const BoxDecoration(
                                    color: AppColors.red,
                                    shape: BoxShape.circle),
                                child: Center(
                                  child: Text(
                                    pending > 99 ? '99+' : '$pending',
                                    style: const TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white),
                                  ),
                                ),
                              ),
                            ),
                        ]);
                      },
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Persetujuan Akun',
                                style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.black)),
                            StreamBuilder<List<UserModel>>(
                              stream: widget.dataService.usersStream,
                              builder: (_, s) {
                                final n = (s.data ?? widget.dataService.users)
                                    .where((u) =>
                                        u.status == AccountStatus.pending)
                                    .length;
                                return Text(
                                  n > 0
                                      ? '$n siswa menunggu persetujuan'
                                      : 'Tidak ada permintaan baru',
                                  style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 12,
                                      color: n > 0
                                          ? AppColors.orange
                                          : AppColors.textGrey),
                                );
                              },
                            ),
                          ]),
                    ),
                    const Icon(Icons.chevron_right_rounded,
                        color: AppColors.textGrey, size: 20),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }
}

class _ProfileTab extends StatefulWidget {
  final AppDataService dataService;
  const _ProfileTab({required this.dataService});

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  void _showLogoutDialog(AuthProvider auth) {
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
              auth.logout();
              Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (_) => false);
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
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.currentUser;
    final ds = widget.dataService;

    final initial = (user?.namaLengkap.isNotEmpty == true)
        ? user!.namaLengkap[0].toUpperCase()
        : 'A';

    final totalBus = ds.buses.length;
    final totalSiswa = ds.siswaList.length;
    final totalDriver = ds.drivers.length;
    final totalPending = ds.pendingUsers.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAdminHeader(user, initial),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _AProfLabel(label: 'Ringkasan Sistem'),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(
                          child: _AStatCard(
                        value: '$totalBus',
                        label: 'Bus',
                        icon: Icons.directions_bus_rounded,
                        color: AppColors.primary,
                      )),
                      const SizedBox(width: 10),
                      Expanded(
                          child: _AStatCard(
                        value: '$totalDriver',
                        label: 'Driver',
                        icon: Icons.badge_rounded,
                        color: AppColors.blue,
                      )),
                      const SizedBox(width: 10),
                      Expanded(
                          child: _AStatCard(
                        value: '$totalSiswa',
                        label: 'Siswa',
                        icon: Icons.school_rounded,
                        color: AppColors.purple,
                      )),
                      const SizedBox(width: 10),
                      Expanded(
                          child: _AStatCard(
                        value: '$totalPending',
                        label: 'Pending',
                        icon: Icons.pending_actions_rounded,
                        color: AppColors.pendingOrange,
                      )),
                    ]),
                    const SizedBox(height: 24),
                    const _AProfLabel(label: 'Data Pribadi'),
                    const SizedBox(height: 10),
                    _AProfCard(children: [
                      _AProfRow(
                        icon: Icons.email_outlined,
                        label: 'Email',
                        value:
                            user?.email.isNotEmpty == true ? user!.email : '-',
                      ),
                      const _AProfDivider(),
                      _AProfRow(
                        icon: Icons.phone_outlined,
                        label: 'No. HP',
                        value: user?.noHp.isNotEmpty == true ? user!.noHp : '-',
                      ),
                      const _AProfDivider(),
                      _AProfRow(
                        icon: Icons.location_on_outlined,
                        label: 'Alamat',
                        value: user?.alamat.isNotEmpty == true
                            ? user!.alamat
                            : '-',
                        maxLines: 2,
                      ),
                    ]),
                    const SizedBox(height: 24),
                    const _AProfLabel(label: 'Akun'),
                    const SizedBox(height: 10),
                    _AProfMenuCard(
                      icon: Icons.edit_outlined,
                      title: 'Edit Profil',
                      subtitle: 'Ubah nama, nomor HP, dan alamat',
                      onTap: () {
                        if (user != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => EditProfileScreen(user: user)),
                          ).then((_) {
                            if (mounted) setState(() {});
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    _AProfMenuCard(
                      icon: Icons.lock_reset_rounded,
                      title: 'Ganti Password',
                      subtitle: 'Ubah password akun admin',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ChangePasswordScreen()),
                      ),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _showLogoutDialog(auth),
                        icon: const Icon(Icons.logout_rounded,
                            color: AppColors.red, size: 18),
                        label: const Text('Keluar dari Akun',
                            style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.red)),
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

  Widget _buildAdminHeader(UserModel? user, String initial) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
      decoration: const BoxDecoration(
        color: Color(0xFF1A2B1A),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(children: [
        Container(
          width: 86,
          height: 86,
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.primary, width: 2.5),
            image: user?.photoUrl != null
                ? DecorationImage(
                    image: NetworkImage(user!.photoUrl!), fit: BoxFit.cover)
                : null,
          ),
          child: user?.photoUrl == null
              ? Center(
                  child: Text(initial,
                      style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 34,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary)),
                )
              : null,
        ),
        const SizedBox(height: 14),
        Text(user?.namaLengkap ?? 'Admin',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.primary, width: 1.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.shield_rounded, size: 12, color: AppColors.primary),
            SizedBox(width: 5),
            Text('Administrator',
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                    letterSpacing: 0.5)),
          ]),
        ),
        const SizedBox(height: 6),
        Text(
          user?.status == AccountStatus.active
              ? 'Akun Aktif'
              : 'Akun Non-aktif',
          style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.55)),
        ),
      ]),
    );
  }
}

class _AStatCard extends StatelessWidget {
  final String value, label;
  final IconData icon;
  final Color color;
  const _AStatCard(
      {required this.value,
      required this.label,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: color.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(height: 6),
        Text(value,
            style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: color)),
        Text(label,
            style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 10,
                color: AppColors.textGrey)),
      ]),
    );
  }
}

class _AProfLabel extends StatelessWidget {
  final String label;
  const _AProfLabel({required this.label});
  @override
  Widget build(BuildContext context) => Text(label,
      style: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.black));
}

class _AProfCard extends StatelessWidget {
  final List<Widget> children;
  const _AProfCard({required this.children});
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

class _AProfRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final int maxLines;
  const _AProfRow(
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
                color: const Color(0xFF1A2B1A).withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(9)),
            child: Icon(icon, color: const Color(0xFF1A2B1A), size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
              ])),
        ]),
      );
}

class _AProfDivider extends StatelessWidget {
  const _AProfDivider();
  @override
  Widget build(BuildContext context) =>
      const Divider(color: AppColors.lightGrey, height: 1);
}

class _AProfMenuCard extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  const _AProfMenuCard(
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
                  color: const Color(0xFF1A2B1A).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: const Color(0xFF1A2B1A), size: 20),
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

class _StatCard extends StatelessWidget {
  final String value, label, sub;
  final Color color;
  final IconData icon;
  final bool filled;
  const _StatCard(
      {required this.value,
      required this.label,
      required this.sub,
      required this.icon,
      required this.color,
      this.filled = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: filled ? color : AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: color.withValues(alpha: filled ? 0.25 : 0.1),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: filled
                ? Colors.white.withValues(alpha: 0.2)
                : color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, color: filled ? Colors.white : color, size: 18),
        ),
        const SizedBox(height: 8),
        Text(value,
            style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: filled ? Colors.white : AppColors.black,
                height: 1.0)),
        Text(label,
            style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: filled ? Colors.white70 : AppColors.black)),
        Text(sub,
            style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 9,
                color: filled ? Colors.white54 : AppColors.textGrey)),
      ]),
    );
  }
}

class _QuickCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final Stream stream;
  final String Function(List<UserModel>) count;
  final String Function(List<BusModel>)? busCount;
  final String Function(List<HalteModel>)? halteCount;
  final bool busStream;
  final bool halteStream;
  final int initialCount;

  const _QuickCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    required this.stream,
    required this.count,
    this.busCount,
    this.halteCount,
    this.busStream = false,
    this.halteStream = false,
    this.initialCount = 0,
  });

  TextStyle get _countStyle => const TextStyle(
      fontFamily: 'Poppins', fontSize: 11, color: AppColors.textGrey);

  @override
  Widget build(BuildContext context) {
    Widget countWidget;

    if (halteStream && halteCount != null) {
      countWidget = StreamBuilder<List<HalteModel>>(
        stream: stream as Stream<List<HalteModel>>,
        builder: (_, s) {
          final display = s.hasData
              ? halteCount!(s.data!)
              : (initialCount > 0 ? '$initialCount' : null);
          if (display == null) {
            return ShimmerEffect(
              child: Container(
                width: 50,
                height: 14,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            );
          }
          return Text(display, style: _countStyle);
        },
      );
    } else if (busStream && busCount != null) {
      countWidget = StreamBuilder<List<BusModel>>(
        stream: stream as Stream<List<BusModel>>,
        builder: (_, s) {
          final display = s.hasData
              ? busCount!(s.data!)
              : (initialCount > 0 ? '$initialCount' : null);
          if (display == null) {
            return ShimmerEffect(
              child: Container(
                width: 50,
                height: 14,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            );
          }
          return Text(display, style: _countStyle);
        },
      );
    } else {
      countWidget = StreamBuilder<List<UserModel>>(
        stream: stream as Stream<List<UserModel>>,
        builder: (_, s) {
          final display = s.hasData
              ? count(s.data!)
              : (initialCount > 0 ? '$initialCount' : null);
          if (display == null) {
            return ShimmerEffect(
              child: Container(
                width: 50,
                height: 14,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            );
          }
          return Text(display, style: _countStyle);
        },
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 2),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: color.withValues(alpha: 0.12),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 7),
          Text(label,
              style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.black)),
          const SizedBox(height: 2),
          countWidget,
        ]),
      ),
    );
  }
}

class _NewPendingToast extends StatefulWidget {
  final int count;
  const _NewPendingToast({required this.count});

  @override
  State<_NewPendingToast> createState() => _NewPendingToastState();
}

class _NewPendingToastState extends State<_NewPendingToast>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _slide;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    )..forward();
    _slide = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.count == 1
        ? '1 siswa baru mendaftar, menunggu persetujuan'
        : '${widget.count} siswa baru mendaftar, menunggu persetujuan';

    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(children: [
                Stack(clipBehavior: Clip.none, children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.orange.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person_add_rounded,
                        color: AppColors.orange, size: 20),
                  ),
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: const BoxDecoration(
                          color: AppColors.orange, shape: BoxShape.circle),
                      child: Center(
                        child: Text(
                          '${widget.count}',
                          style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ]),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Pendaftaran Baru!',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        label,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _GpsToast extends StatefulWidget {
  final String driverName;
  final String busName;
  final bool gpsActive;

  const _GpsToast({
    required this.driverName,
    required this.busName,
    required this.gpsActive,
  });

  @override
  State<_GpsToast> createState() => _GpsToastState();
}

class _GpsToastState extends State<_GpsToast>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _slide;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    )..forward();
    _slide = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color =
        widget.gpsActive ? AppColors.primary : const Color(0xFF616161);
    final icon =
        widget.gpsActive ? Icons.gps_fixed_rounded : Icons.gps_off_rounded;
    final title = widget.gpsActive ? 'GPS DIAKTIFKAN' : 'GPS DIMATIKAN';
    final msg = widget.gpsActive
        ? '${widget.driverName} mengaktifkan GPS (${widget.busName})'
        : '${widget.driverName} mematikan GPS (${widget.busName})';

    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(children: [
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 0.5)),
                        Text(msg,
                            style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 12,
                                color: Colors.white)),
                      ]),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
