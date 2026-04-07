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
import '../auth/login_screen.dart';
import '../common/edit_profile_screen.dart';
import 'admin_siswa_screen.dart';
import 'admin_driver_screen.dart';
import 'admin_pending_screen.dart';
import 'admin_bus_screen.dart';
import 'admin_halte_screen.dart';
import 'admin_analitik_screen.dart';
import 'admin_generate_qr_screen.dart';
import 'admin_tracking_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});
  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _currentIndex = 0;
  final AppDataService _dataService = AppDataService();
  late final List<Widget> _screens;

  @override
  @override
  void initState() {
    super.initState();
    _dataService.loadAll();
    _screens = [
      _HomeTab(dataService: _dataService),
      AdminAnalitikScreen(dataService: _dataService),
      _ProfileTab(dataService: _dataService),
    ];

    // [FIX] Mulai GPS polling HANYA setelah token dipastikan tersedia.
    // Jika token belum ada (misal app baru buka), polling ditunda 500ms
    // sampai login selesai — mencegah 401 berulang saat belum terautentikasi.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (!auth.isLoggedIn) return; // belum login, jangan mulai polling

      // Set handler agar polling otomatis berhenti + logout jika token expired
      _dataService.onUnauthorized = () {
        if (!mounted) return;
        auth.logout();
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      };

      _dataService.startGpsPolling();
    });
  }

  @override
  void dispose() {
    // Stop GPS polling saat admin keluar dari dashboard
    _dataService.stopGpsPolling();
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

// ════════════════════════════════════════════════════════════
// HOME TAB
// ════════════════════════════════════════════════════════════
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
    if (h < 11) return 'Selamat pagi 👋';
    if (h < 15) return 'Selamat siang 👋';
    if (h < 18) return 'Selamat sore 👋';
    return 'Selamat malam 👋';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────
            MobitraAppBar(
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

            // ── Stats ────────────────────────────────────────
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
                      return Row(children: [
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
                      ]);
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            // ── Live Tracking ────────────────────────────────
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

                if (active.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      height: 220,
                      decoration: BoxDecoration(
                        color: AppColors.surface2,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.directions_bus_outlined,
                                size: 36, color: AppColors.textGrey),
                            SizedBox(height: 8),
                            Text('Belum ada bus yang beroperasi',
                                style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textGrey)),
                            SizedBox(height: 4),
                            Text('GPS muncul saat driver mengaktifkan tracking',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 11,
                                    color: AppColors.textGrey)),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                // Peta + list bus terpisah (tidak overlay)
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Peta — non-interactive di dashboard, tap untuk buka fullscreen
                      GestureDetector(
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => AdminTrackingScreen(
                                    dataService: widget.dataService,
                                    initialFocus: _focusedBus))),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: BusMapWidget(
                            buses: active,
                            height: 185,
                            showAllBuses: true,
                            interactive: false,
                            mapController: _mapController,
                            focusBus: _focusedBus,
                            showInfoCard: false,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      // List bus di bawah peta — rapi, tidak overlay
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
            // ── Kelola ───────────────────────────────────────
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

            // Info: Rute diatur dari menu Bus
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

            // Persetujuan card
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
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                          color: AppColors.orange.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.pending_actions_rounded,
                          color: AppColors.orange, size: 22),
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
            const SizedBox(height: 16),

            // QR Generator quick access
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GestureDetector(
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => AdminGenerateQrScreen(
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
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                          color: AppColors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.qr_code_2_rounded,
                          color: AppColors.blue, size: 24),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Generator QR Code',
                                style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.black)),
                            Text('Generate & cetak kartu identitas siswa',
                                style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 12,
                                    color: AppColors.textGrey)),
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

// ════════════════════════════════════════════════════════════
// MONITOR TAB
// ════════════════════════════════════════════════════════════
class _MonitorTab extends StatelessWidget {
  final AppDataService dataService;
  const _MonitorTab({required this.dataService});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Row(children: [
            const Expanded(
                child: Text('Monitor GPS',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.black))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                        color: AppColors.primary, shape: BoxShape.circle)),
                const SizedBox(width: 5),
                const Text('Live',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary)),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: StreamBuilder<List<BusModel>>(
            stream: dataService.busesStream,
            builder: (_, s) {
              final buses = s.data ?? dataService.buses;
              final active = buses.where((b) => b.gpsActive).toList();
              if (active.isEmpty) {
                return Container(
                  height: 240,
                  decoration: BoxDecoration(
                    color: AppColors.surface2,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.location_off_outlined,
                            size: 36, color: AppColors.textGrey),
                        SizedBox(height: 8),
                        Text('Belum ada bus yang beroperasi',
                            style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textGrey)),
                        SizedBox(height: 4),
                        Text(
                            'GPS akan muncul saat driver mengaktifkan tracking',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 11,
                                color: AppColors.textGrey)),
                      ],
                    ),
                  ),
                );
              }
              return BusMapWidget(
                  buses: active,
                  height: 240,
                  showAllBuses: true,
                  interactive: true);
            },
          ),
        ),
        const SizedBox(height: 16),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text('Status Bus',
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.black)),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: StreamBuilder<List<BusModel>>(
            stream: dataService.busesStream,
            builder: (_, s) {
              final buses = s.data ?? dataService.buses;
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: buses.length,
                itemBuilder: (_, i) {
                  final b = buses[i];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2))
                      ],
                    ),
                    child: Row(children: [
                      Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                              color: b.gpsActive
                                  ? AppColors.primaryLight
                                  : AppColors.surface2,
                              borderRadius: BorderRadius.circular(10)),
                          child: Icon(Icons.directions_bus_rounded,
                              color: b.gpsActive
                                  ? AppColors.primary
                                  : AppColors.textGrey,
                              size: 22)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(b.nama,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.black)),
                            Text(
                                b.driverName.isEmpty
                                    ? 'Tidak ada driver'
                                    : b.driverName,
                                style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 12,
                                    color: AppColors.textGrey)),
                          ])),
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                  color: b.gpsActive
                                      ? AppColors.primaryLight
                                      : AppColors.surface2,
                                  borderRadius: BorderRadius.circular(6)),
                              child: Text(b.gpsActive ? 'GPS ON' : 'GPS OFF',
                                  style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: b.gpsActive
                                          ? AppColors.primary
                                          : AppColors.textGrey)),
                            ),
                            if (b.gpsActive) ...[
                              const SizedBox(height: 3),
                              Text('${b.speed.toStringAsFixed(0)} km/h',
                                  style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.black))
                            ],
                          ]),
                    ]),
                  );
                },
              );
            },
          ),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════
// PROFILE TAB
// ════════════════════════════════════════════════════════════
class _ProfileTab extends StatefulWidget {
  final AppDataService dataService;
  const _ProfileTab({required this.dataService});

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.currentUser;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          const SizedBox(height: 12),
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(22),
              image: user?.photoUrl != null
                  ? DecorationImage(
                      image: NetworkImage(user!.photoUrl!), fit: BoxFit.cover)
                  : null,
            ),
            child: user?.photoUrl == null
                ? Center(
                    child: Text(
                        user?.namaLengkap.substring(0, 1).toUpperCase() ?? 'A',
                        style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 34,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary)))
                : null,
          ),
          const SizedBox(height: 12),
          Text(user?.namaLengkap ?? 'Admin',
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
            child: const Text('Administrator',
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary)),
          ),
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
                      offset: const Offset(0, 3))
                ]),
            child: Column(children: [
              _InfoRow(
                  icon: Icons.email_outlined,
                  label: 'Email',
                  value: user?.email ?? '-'),
              const Divider(color: AppColors.lightGrey, height: 20),
              _InfoRow(
                  icon: Icons.phone_outlined,
                  label: 'No. HP',
                  value:
                      user?.noHp.isEmpty == true ? '-' : (user?.noHp ?? '-')),
              const Divider(color: AppColors.lightGrey, height: 20),
              _InfoRow(
                  icon: Icons.location_on_outlined,
                  label: 'Alamat',
                  value: user?.alamat.isEmpty == true
                      ? '-'
                      : (user?.alamat ?? '-')),
            ]),
          ),
          const SizedBox(height: 14),
          _ProfileMenu(
              icon: Icons.edit_outlined,
              label: 'Edit Profil',
              onTap: () {
                if (user != null) {
                  Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => EditProfileScreen(user: user)))
                      .then((_) {
                    if (mounted) setState(() {});
                  });
                }
              }),
          _ProfileMenu(
              icon: Icons.logout_rounded,
              label: 'Keluar',
              color: AppColors.red,
              onTap: () {
                auth.logout();
                Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (_) => false);
              }),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// SHARED WIDGETS
// ════════════════════════════════════════════════════════════

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
  // Nilai awal dari cache lokal sebelum stream pertama emit
  // Ini mencegah angka "0" saat data sudah ada tapi stream belum emit
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
      // Halte: pakai haltesStream, fallback ke initialCount saat belum emit
      countWidget = StreamBuilder<List<HalteModel>>(
        stream: stream as Stream<List<HalteModel>>,
        builder: (_, s) {
          final display = s.hasData
              ? halteCount!(s.data!)
              : (initialCount > 0 ? '$initialCount' : null);
          if (display == null) {
            return SizedBox(
              height: 14,
              width: 14,
              child: CircularProgressIndicator(
                  strokeWidth: 1.5, color: color.withValues(alpha: 0.5)),
            );
          }
          return Text(display, style: _countStyle);
        },
      );
    } else if (busStream && busCount != null) {
      // Bus: pakai busesStream, fallback ke initialCount saat belum emit
      countWidget = StreamBuilder<List<BusModel>>(
        stream: stream as Stream<List<BusModel>>,
        builder: (_, s) {
          final display = s.hasData
              ? busCount!(s.data!)
              : (initialCount > 0 ? '$initialCount' : null);
          if (display == null) {
            return SizedBox(
              height: 14,
              width: 14,
              child: CircularProgressIndicator(
                  strokeWidth: 1.5, color: color.withValues(alpha: 0.5)),
            );
          }
          return Text(display, style: _countStyle);
        },
      );
    } else {
      // Siswa / Driver: pakai usersStream, fallback ke initialCount
      countWidget = StreamBuilder<List<UserModel>>(
        stream: stream as Stream<List<UserModel>>,
        builder: (_, s) {
          final display = s.hasData
              ? count(s.data!)
              : (initialCount > 0 ? '$initialCount' : null);
          if (display == null) {
            return SizedBox(
              height: 14,
              width: 14,
              child: CircularProgressIndicator(
                  strokeWidth: 1.5, color: color.withValues(alpha: 0.5)),
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

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _InfoRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
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
  Widget build(BuildContext context) {
    return Container(
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
}
