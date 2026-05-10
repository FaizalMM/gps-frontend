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
import '../../widgets/skeleton_widgets.dart';
import '../auth/login_screen.dart';
import '../common/edit_profile_screen.dart';
import 'qr_code_screen.dart';

// ══════════════════════════════════════════════════════════════
// ROOT WIDGET
// ══════════════════════════════════════════════════════════════
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
      ),
    );
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
  int? _myBusId;
  String? _myBusName;
  String? _myDriverName;
  bool _loadingBusInfo = true;
  BusModel? _myBusLive;

  @override
  void initState() {
    super.initState();
    _pulseAnim =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat(reverse: true);
    _getLocation();
    _loadMyBusId();
    widget.dataService.startHomePolling(onUpdate: (bus) {
      if (!mounted) return;
      setState(() => _myBusLive = bus);
    });
  }

  @override
  void dispose() {
    widget.dataService.stopHomePolling();
    _pulseAnim.dispose();
    super.dispose();
  }

  Future<void> _loadMyBusId() async {
    try {
      final result = await BusService().getMyBusTrackingFull();
      if (!mounted) return;
      if (result.bus != null) {
        setState(() {
          _myBusId = result.bus!.id;
          _myBusName = result.bus!.nama;
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
    final myBus = _myBusLive;
    final gpsAktif = myBus != null && myBus.gpsActive;

    return ColoredBox(
      color: AppColors.background,
      child: SafeArea(
        child: SingleChildScrollView(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── Header ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text('${_greeting()}, $first 👋',
                            style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 13,
                                color: AppColors.textGrey)),
                        const SizedBox(height: 2),
                        const Text('Pantau busmu\nsekarang',
                            style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: AppColors.black,
                                height: 1.2)),
                      ])),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
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
                      const SizedBox(height: 8),
                      // GPS Status badge
                      _GpsBadge(aktif: gpsAktif),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // ── Bus status card ─────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _loadingBusInfo
                  ? const SkeletonBusCard()
                  : Builder(builder: (_) {
                      if (_myBusId == null) return _NoBusAssignedCard();
                      if (myBus == null || !myBus.gpsActive) {
                        return _BusOfflineCard(
                          busName: _myBusName,
                          driverName: _myDriverName,
                          onTrack: () => widget.onSwitchTab(1),
                        );
                      }
                      return _BusLiveCard(
                          bus: myBus,
                          eta: _eta(myBus),
                          pulseAnim: _pulseAnim,
                          onTrack: () => widget.onSwitchTab(1));
                    }),
            ),
            const SizedBox(height: 10),

            // ── Status banner (offline = waiting, online = siapkan QR) ─
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _loadingBusInfo
                  ? const SizedBox.shrink()
                  : _myBusId == null
                      ? const SizedBox.shrink()
                      : gpsAktif
                          ? _StatusBanner(
                              icon: Icons.qr_code_2_rounded,
                              iconColor: AppColors.primary,
                              bgColor: AppColors.primaryLight,
                              borderColor:
                                  AppColors.primary.withValues(alpha: 0.4),
                              title: 'Siapkan QR Code',
                              subtitle:
                                  'Bus sudah aktif. Tunjukkan QR Code ke driver saat naik untuk absensi.',
                            )
                          : const _WaitingBanner(),
            ),
            const SizedBox(height: 12),

            // ── Info bus & driver ───────────────────────────
            if (!_loadingBusInfo && _myBusName != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _BusDriverInfoCard(
                  busName: _myBusName!,
                  driverName: _myDriverName,
                ),
              ),
            const SizedBox(height: 12),

            // ── Quick actions (3 item — tanpa hubungi sekolah) ─
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                _QAction(
                    icon: Icons.qr_code_2_rounded,
                    label: 'ID & QR\nSaya',
                    color: AppColors.primary,
                    bg: AppColors.primaryLight,
                    onTap: () => widget.onSwitchTab(2)),
                const SizedBox(width: 10),
                _QAction(
                    icon: Icons.map_rounded,
                    label: 'Lacak\nBus',
                    color: AppColors.blue,
                    bg: const Color(0xFFE3F2FD),
                    onTap: () => widget.onSwitchTab(1)),
                const SizedBox(width: 10),
                _QAction(
                    icon: Icons.location_on_rounded,
                    label: 'Info\nHalte',
                    color: AppColors.purple,
                    bg: const Color(0xFFF3E5F5),
                    onTap: () => _showHalteSheet(context)),
              ]),
            ),
            const SizedBox(height: 20),

            // ── Bus Beroperasi ─────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
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
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    child: Center(
                        child: Text('Belum ada bus beroperasi',
                            style: TextStyle(
                                fontFamily: 'Poppins',
                                color: AppColors.textGrey))),
                  );
                return Column(
                  children: buses
                      .map((bus) => Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
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
      ),
    );
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
}

// ══════════════════════════════════════════════════════════════
// GPS STATUS BADGE
// ══════════════════════════════════════════════════════════════
class _GpsBadge extends StatelessWidget {
  final bool aktif;
  const _GpsBadge({required this.aktif});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: aktif
            ? AppColors.primaryLight
            : AppColors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: aktif
              ? AppColors.primary.withValues(alpha: 0.5)
              : AppColors.orange.withValues(alpha: 0.5),
        ),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: aktif ? AppColors.primary : AppColors.orange,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          aktif ? 'GPS LIVE' : 'GPS OFFLINE',
          style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: aktif ? AppColors.primary : AppColors.orange),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// BUS CARD — GPS OFFLINE STATE
// ══════════════════════════════════════════════════════════════
class _BusOfflineCard extends StatelessWidget {
  final String? busName;
  final String? driverName;
  final VoidCallback? onTrack;
  const _BusOfflineCard({this.busName, this.driverName, this.onTrack});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Bus header
        Row(children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(13)),
            child: const Icon(Icons.directions_bus_rounded,
                color: AppColors.textGrey, size: 24),
          ),
          const SizedBox(width: 12),
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
          // ETA placeholder
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(10)),
            child: Column(children: const [
              Text('ETA',
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textGrey)),
              SizedBox(height: 2),
              Text('— —',
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textGrey,
                      letterSpacing: 1)),
            ]),
          ),
        ]),

        if (driverName != null) ...[
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.lightGrey),
          const SizedBox(height: 12),
          Row(children: [
            // Avatar driver
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                  color: AppColors.primaryLight, shape: BoxShape.circle),
              child: Center(
                child: Text(
                  driverName!.isNotEmpty ? driverName![0].toUpperCase() : 'D',
                  style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(driverName!,
                      style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.black)),
                  const Text('Driver Ditugaskan',
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          color: AppColors.textGrey)),
                ])),
          ]),
        ],
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// WAITING BANNER — ditampilkan saat GPS belum aktif
// ══════════════════════════════════════════════════════════════
class _WaitingBanner extends StatelessWidget {
  const _WaitingBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Container(
          width: 52,
          height: 52,
          decoration:
              BoxDecoration(color: AppColors.white, shape: BoxShape.circle),
          child: const Icon(Icons.gps_off_rounded,
              size: 26, color: AppColors.orange),
        ),
        const SizedBox(height: 12),
        const Text('Menunggu Keberangkatan',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.black)),
        const SizedBox(height: 6),
        const Text(
            'Pelacakan dimulai setelah driver\nmengaktifkan GPS dan memulai perjalanan.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                color: AppColors.textGrey,
                height: 1.5)),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: const [
            Icon(Icons.info_outline_rounded,
                size: 14, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Kamu akan diberi tahu saat bus berangkat',
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500)),
          ]),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// STATUS BANNER — generic (dipakai untuk GPS aktif / siapkan QR)
// ══════════════════════════════════════════════════════════════
class _StatusBanner extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final Color borderColor;
  final String title;
  final String subtitle;

  const _StatusBanner({
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.borderColor,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: iconColor)),
          const SizedBox(height: 2),
          Text(subtitle,
              style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  color: AppColors.textGrey,
                  height: 1.4)),
        ])),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// BUS & DRIVER INFO CARD
// ══════════════════════════════════════════════════════════════
class _BusDriverInfoCard extends StatelessWidget {
  final String busName;
  final String? driverName;
  const _BusDriverInfoCard({required this.busName, this.driverName});

  @override
  Widget build(BuildContext context) {
    return Container(
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
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              'Bus saya: $busName',
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
                  driverName != null
                      ? 'Driver: $driverName'
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
    );
  }
}

// ══════════════════════════════════════════════════════════════
// BUS LIVE CARD — GPS aktif
// ══════════════════════════════════════════════════════════════
class _BusLiveCard extends StatelessWidget {
  final BusModel bus;
  final String eta;
  final AnimationController pulseAnim;
  final VoidCallback onTrack;
  const _BusLiveCard(
      {required this.bus,
      required this.eta,
      required this.pulseAnim,
      required this.onTrack});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
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
          const Text('LIVE TRACKING',
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
        if (bus.rute.isNotEmpty)
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
                        fontSize: 24,
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

// ══════════════════════════════════════════════════════════════
// QUICK ACTION (3-item row)
// ══════════════════════════════════════════════════════════════
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
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: color.withValues(alpha: 0.10),
                    blurRadius: 10,
                    offset: const Offset(0, 3))
              ]),
          child: Column(children: [
            Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                    color: bg, borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: color, size: 22)),
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
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// NO BUS ASSIGNED CARD
// ══════════════════════════════════════════════════════════════
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

// ══════════════════════════════════════════════════════════════
// BUS LIST TILE
// ══════════════════════════════════════════════════════════════
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

// ══════════════════════════════════════════════════════════════
// TRACKING TAB  (tidak berubah dari versi asli)
// ══════════════════════════════════════════════════════════════
class _SiswaTrackingTab extends StatefulWidget {
  final AppDataService dataService;
  const _SiswaTrackingTab({required this.dataService});
  @override
  State<_SiswaTrackingTab> createState() => _SiswaTrackingTabState();
}

class _SiswaTrackingTabState extends State<_SiswaTrackingTab>
    with SingleTickerProviderStateMixin {
  BusModel? _myBus;
  Map<String, dynamic>? _myHalte;
  String? _driverName;
  bool _loadingBus = true;

  String? _attendanceStatus;
  String? _waktuNaik;
  String? _waktuTurun;
  String? _halteNaik;
  bool _loadingAttendance = true;

  Timer? _attendanceTimer;
  final AppDataService _busDataService = AppDataService();
  final MapController _mapController = MapController();
  String _selectedFilter = 'Semua'; // 'Semua' | 'Online' | 'Offline'

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 1))
          ..repeat(reverse: true);
    _pulseAnim = Tween(begin: 0.5, end: 1.0).animate(_pulseCtrl);

    _busDataService.startStudentPolling(
      onUpdate: (result) {
        if (!mounted) return;
        setState(() {
          _myBus = result.bus;
          _myHalte = result.myHalte;
          _driverName = result.driverName;
        });
      },
    );

    _loadAll();

    _attendanceTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted) _loadAttendance(silent: true);
    });
  }

  @override
  void dispose() {
    _attendanceTimer?.cancel();
    _busDataService.stopStudentPolling();
    _pulseCtrl.dispose();
    super.dispose();
  }

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

  @override
  Widget build(BuildContext context) {
    final buses = _myBus != null ? [_myBus!] : <BusModel>[];

    return ColoredBox(
      color: AppColors.background,
      child: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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

          if (_loadingAttendance)
            const SkeletonAttendanceBanner()
          else
            _buildAttendanceBanner(),

          // ── Filter chips ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(children: [
              for (final f in ['Semua', 'Online', 'Offline']) ...[
                GestureDetector(
                  onTap: () => setState(() => _selectedFilter = f),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                    decoration: BoxDecoration(
                      color: _selectedFilter == f
                          ? (f == 'Online'
                              ? AppColors.primary
                              : f == 'Offline'
                                  ? AppColors.orange
                                  : AppColors.black)
                          : AppColors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _selectedFilter == f
                            ? Colors.transparent
                            : AppColors.lightGrey,
                      ),
                      boxShadow: _selectedFilter == f
                          ? [
                              BoxShadow(
                                  color: (f == 'Online'
                                          ? AppColors.primary
                                          : f == 'Offline'
                                              ? AppColors.orange
                                              : AppColors.black)
                                      .withValues(alpha: 0.25),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3))
                            ]
                          : [],
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (f != 'Semua') ...[
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: _selectedFilter == f
                                ? Colors.white
                                : (f == 'Online'
                                    ? AppColors.primary
                                    : AppColors.orange),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                      ],
                      Text(
                        f,
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _selectedFilter == f
                                ? Colors.white
                                : AppColors.textGrey),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ]),
          ),

          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: _loadingBus
                      ? const SkeletonMapArea(height: 400)
                      : _buildFilteredView(),
                ),
                if (!_loadingBus &&
                    _myBus != null &&
                    _myBus!.gpsActive &&
                    _myBus!.latitude != 0 &&
                    _selectedFilter != 'Offline')
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _buildBottomCard(),
                  ),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildAttendanceBanner() {
    if (_attendanceStatus == null) {
      return const _TrackingStatusBanner(
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
      return _TrackingStatusBanner(
        color: const Color(0xFFFFF8E1),
        borderColor: AppColors.orange.withValues(alpha: 0.4),
        icon: Icons.qr_code_2_rounded,
        iconColor: AppColors.orange,
        title: 'QR siap — tunjukkan ke driver saat naik!',
        subtitle: 'QR sudah aktif, menunggu driver scan',
        badge: 'MENUNGGU SCAN',
        badgeColor: AppColors.orange,
      );
    }
    if (_isOnBus) {
      return _TrackingStatusBanner(
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
      return _TrackingStatusBanner(
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
        if (_isOnBus) ...[
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

  Widget _buildFilteredView() {
    // Filter Offline: tampilkan list semua bus yang GPS-nya tidak aktif
    if (_selectedFilter == 'Offline') {
      return StreamBuilder<List<BusModel>>(
        stream: widget.dataService.busesStream,
        builder: (_, snap) {
          final all = snap.data ?? widget.dataService.buses;
          final offlineBuses = all.where((b) => !b.gpsActive).toList();
          if (offlineBuses.isEmpty) {
            return _buildEmptyFilterView(
              icon: Icons.gps_off_rounded,
              color: AppColors.orange,
              message: 'Semua bus sedang online',
              sub: 'Tidak ada bus yang offline saat ini',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
            itemCount: offlineBuses.length,
            itemBuilder: (_, i) {
              final bus = offlineBuses[i];
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
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                        color: AppColors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.directions_bus_rounded,
                        color: AppColors.orange, size: 22),
                  ),
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
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: AppColors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8)),
                    child: const Text('Offline',
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.orange)),
                  ),
                ]),
              );
            },
          );
        },
      );
    }

    // Filter Online: tampilkan peta jika bus online, atau pesan kosong
    if (_selectedFilter == 'Online') {
      if (_myBus == null) return _buildNoBusView();
      if (!_myBus!.gpsActive || _myBus!.latitude == 0) {
        return _buildEmptyFilterView(
          icon: Icons.gps_off_rounded,
          color: AppColors.primary,
          message: 'Belum ada driver yang online',
          sub:
              'Driver belum mengaktifkan GPS.\nKamu akan diberi tahu saat bus mulai bergerak.',
        );
      }
      return _buildMapView();
    }

    // Filter Semua (default)
    if (_myBus == null) return _buildNoBusView();
    if (!_myBus!.gpsActive || _myBus!.latitude == 0) return _buildGpsOffView();
    return _buildMapView();
  }

  Widget _buildMapView() {
    final buses = [_myBus!];
    return Stack(children: [
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
      if (!_isOnBus && !_isDone && _myHalte != null) _buildArrivalAlert(),
    ]);
  }

  Widget _buildEmptyFilterView({
    required IconData icon,
    required Color color,
    required String message,
    required String sub,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08), shape: BoxShape.circle),
            child: Icon(icon, size: 48, color: color.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 16),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.black)),
          const SizedBox(height: 8),
          Text(sub,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  color: AppColors.textGrey,
                  height: 1.5)),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () => _loadAll(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withValues(alpha: 0.3))),
              child: Text('Refresh',
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: color)),
            ),
          ),
        ]),
      ),
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
          decoration: const BoxDecoration(
              color: AppColors.surface2, shape: BoxShape.circle),
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

// ══════════════════════════════════════════════════════════════
// TRACKING STATUS BANNER (untuk tab Lacak)
// ══════════════════════════════════════════════════════════════
class _TrackingStatusBanner extends StatelessWidget {
  final Color color;
  final Color borderColor;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String? badge;
  final Color? badgeColor;

  const _TrackingStatusBanner({
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

// ══════════════════════════════════════════════════════════════
// ON BUS OVERLAY
// ══════════════════════════════════════════════════════════════
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

// ══════════════════════════════════════════════════════════════
// INFO TILE
// ══════════════════════════════════════════════════════════════
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

// ══════════════════════════════════════════════════════════════
// PROFILE TAB  (tidak berubah dari versi asli)
// ══════════════════════════════════════════════════════════════
class _SiswaProfileTab extends StatefulWidget {
  final UserModel siswa;
  const _SiswaProfileTab({required this.siswa});

  @override
  State<_SiswaProfileTab> createState() => _SiswaProfileTabState();
}

class _SiswaProfileTabState extends State<_SiswaProfileTab> {
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
    final siswa = widget.siswa;
    final detail = siswa.studentDetail;
    final initial =
        siswa.namaLengkap.isNotEmpty ? siswa.namaLengkap[0].toUpperCase() : '?';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(siswa, detail, initial),
              if (detail != null && detail.nis.isNotEmpty)
                _buildNisBadge(detail),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SProfQrCard(
                      siswa: siswa,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => QrCodeScreen(siswa: siswa)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const _SProfLabel(label: 'Data Pribadi'),
                    const SizedBox(height: 10),
                    _SProfCard(children: [
                      _SProfRow(
                        icon: Icons.email_outlined,
                        label: 'Email',
                        value: siswa.email.isNotEmpty ? siswa.email : '-',
                      ),
                      const _SProfDivider(),
                      _SProfRow(
                        icon: Icons.phone_outlined,
                        label: 'No. HP',
                        value: siswa.noHp.isNotEmpty ? siswa.noHp : '-',
                      ),
                      const _SProfDivider(),
                      _SProfRow(
                        icon: Icons.location_on_outlined,
                        label: 'Alamat',
                        value: siswa.alamat.isNotEmpty ? siswa.alamat : '-',
                        maxLines: 2,
                      ),
                    ]),
                    const SizedBox(height: 20),
                    const _SProfLabel(label: 'Info Sekolah'),
                    const SizedBox(height: 10),
                    _SProfCard(children: [
                      _SProfRow(
                        icon: Icons.school_outlined,
                        label: 'Sekolah',
                        value: (detail != null && detail.sekolah.isNotEmpty)
                            ? detail.sekolah
                            : '-',
                      ),
                      if (detail != null && detail.nis.isNotEmpty) ...[
                        const _SProfDivider(),
                        _SProfRow(
                          icon: Icons.badge_outlined,
                          label: 'NIS',
                          value: detail.nis,
                        ),
                      ],
                    ]),
                    const SizedBox(height: 20),
                    const _SProfLabel(label: 'Bus & Rute'),
                    const SizedBox(height: 10),
                    _SProfCard(children: [
                      _SProfRow(
                        icon: Icons.directions_bus_outlined,
                        label: 'Bus',
                        value: (detail != null && detail.namaBus.isNotEmpty)
                            ? detail.namaBus
                            : 'Belum ada bus',
                      ),
                      const _SProfDivider(),
                      _SProfRow(
                        icon: Icons.route_outlined,
                        label: 'Rute',
                        value: (detail != null && detail.namaRute.isNotEmpty)
                            ? detail.namaRute
                            : '-',
                      ),
                      const _SProfDivider(),
                      _SProfRow(
                        icon: Icons.place_outlined,
                        label: 'Halte Naik',
                        value: (detail != null && detail.namaHalte.isNotEmpty)
                            ? detail.namaHalte
                            : '-',
                      ),
                      const _SProfDivider(),
                      _SProfRowStatus(
                          status:
                              detail?.approvalStatus ?? ApprovalStatus.pending),
                    ]),
                    const SizedBox(height: 20),
                    const _SProfLabel(label: 'Pengaturan'),
                    const SizedBox(height: 10),
                    _SProfMenuCard(
                      icon: Icons.edit_outlined,
                      title: 'Edit Data Pribadi',
                      subtitle: 'Ubah nama, nomor HP, dan alamat',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => EditProfileScreen(user: siswa)),
                      ).then((_) {
                        if (mounted) setState(() {});
                      }),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _showLogoutDialog,
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

  Widget _buildHeader(UserModel siswa, StudentDetail? detail, String initial) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3)),
          child: ClipOval(
            child: siswa.photoUrl != null
                ? Image.network(siswa.photoUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        _SProfAvatar(initial: initial))
                : _SProfAvatar(initial: initial),
          ),
        ),
        const SizedBox(height: 12),
        Text(siswa.namaLengkap,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20)),
          child: const Text('Siswa',
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.white)),
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
              siswa.status == AccountStatus.active
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

  Widget _buildNisBadge(StudentDetail detail) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      transform: Matrix4.translationValues(0, -18, 0),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.07),
                blurRadius: 12,
                offset: const Offset(0, 4))
          ]),
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(children: [
        Expanded(
            child: _SProfStatItem(
          icon: Icons.badge_outlined,
          value: detail.nis.isNotEmpty ? detail.nis : '-',
          label: 'NIS',
          color: AppColors.primary,
        )),
        Container(width: 1, height: 40, color: AppColors.lightGrey),
        Expanded(
            child: _SProfStatItem(
          icon: Icons.directions_bus_outlined,
          value: detail.namaBus.isNotEmpty ? detail.namaBus : '-',
          label: 'Bus',
          color: AppColors.blue,
        )),
        Container(width: 1, height: 40, color: AppColors.lightGrey),
        Expanded(
            child: _SProfStatItem(
          icon: Icons.place_outlined,
          value: detail.namaHalte.isNotEmpty ? detail.namaHalte : '-',
          label: 'Halte',
          color: AppColors.pendingOrange,
        )),
      ]),
    );
  }
}

// ── Profile sub-widgets ──────────────────────────────────────
class _SProfAvatar extends StatelessWidget {
  final String initial;
  const _SProfAvatar({required this.initial});
  @override
  Widget build(BuildContext context) => Container(
        color: AppColors.primaryLight,
        child: Center(
          child: Text(initial,
              style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary)),
        ),
      );
}

class _SProfStatItem extends StatelessWidget {
  final IconData icon;
  final String value, label;
  final Color color;
  const _SProfStatItem(
      {required this.icon,
      required this.value,
      required this.label,
      required this.color});
  @override
  Widget build(BuildContext context) => Column(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(value,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color)),
        Text(label,
            style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 10,
                color: AppColors.textGrey)),
      ]);
}

class _SProfLabel extends StatelessWidget {
  final String label;
  const _SProfLabel({required this.label});
  @override
  Widget build(BuildContext context) => Text(label,
      style: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.black));
}

class _SProfCard extends StatelessWidget {
  final List<Widget> children;
  const _SProfCard({required this.children});
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

class _SProfRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final int maxLines;
  const _SProfRow(
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

class _SProfRowStatus extends StatelessWidget {
  final ApprovalStatus status;
  const _SProfRowStatus({required this.status});
  @override
  Widget build(BuildContext context) {
    final isApproved = status == ApprovalStatus.approved;
    final isPending = status == ApprovalStatus.pending;
    final color = isApproved
        ? AppColors.primary
        : isPending
            ? AppColors.pendingOrange
            : AppColors.red;
    final bg = isApproved
        ? AppColors.primaryLight
        : isPending
            ? AppColors.orange.withValues(alpha: 0.1)
            : AppColors.red.withValues(alpha: 0.08);
    final label = isApproved
        ? 'Disetujui'
        : isPending
            ? 'Menunggu Persetujuan'
            : 'Ditolak';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(9)),
          child: const Icon(Icons.verified_user_outlined,
              color: AppColors.primary, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Status Pendaftaran',
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textGrey,
                    letterSpacing: 0.3)),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                  color: bg, borderRadius: BorderRadius.circular(8)),
              child: Text(label,
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color)),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _SProfDivider extends StatelessWidget {
  const _SProfDivider();
  @override
  Widget build(BuildContext context) =>
      const Divider(color: AppColors.lightGrey, height: 1);
}

class _SProfQrCard extends StatelessWidget {
  final UserModel siswa;
  final VoidCallback onTap;
  const _SProfQrCard({required this.siswa, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isActive = siswa.status == AccountStatus.active;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ],
        ),
        child: Row(children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: isActive ? AppColors.primary : AppColors.surface2,
              borderRadius:
                  const BorderRadius.horizontal(left: Radius.circular(16)),
            ),
            child: Icon(
              Icons.qr_code_2_rounded,
              size: 40,
              color: isActive ? Colors.white : AppColors.textGrey,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Buka QR Code',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.black)),
                const SizedBox(height: 2),
                Text(
                  isActive
                      ? 'Tunjukkan ke driver saat naik bus'
                      : 'Akun belum aktif',
                  style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      color: AppColors.textGrey),
                ),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color:
                        isActive ? AppColors.primaryLight : AppColors.surface2,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isActive ? 'Aktif · Berlaku hari ini' : 'Tidak aktif',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color:
                            isActive ? AppColors.primary : AppColors.textGrey),
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(right: 14),
            child: Icon(Icons.chevron_right_rounded,
                color: AppColors.textGrey, size: 20),
          ),
        ]),
      ),
    );
  }
}

class _SProfMenuCard extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  const _SProfMenuCard(
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

// ══════════════════════════════════════════════════════════════
// SHARED BOTTOM SHEET WIDGETS
// ══════════════════════════════════════════════════════════════
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

// ══════════════════════════════════════════════════════════════
// HALTE ROUTE SHEET
// ══════════════════════════════════════════════════════════════
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

      final routeSvc = RouteService();
      final route = await routeSvc.getRouteByBus(busId);

      if (route == null) {
        setState(() {
          _error = 'Rute bus belum diatur oleh admin.';
          _loading = false;
        });
        return;
      }

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
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(children: [
            Center(
                child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: AppColors.lightGrey,
                        borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 10),
            const Text('Halte di Rute Bus Saya',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
            if (_namaRute.isNotEmpty)
              Text(_namaRute,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      color: AppColors.textGrey)),
          ]),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _loading
              ? const SkeletonList(itemCount: 5)
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
