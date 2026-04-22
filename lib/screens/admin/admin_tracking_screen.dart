import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../models/models_api.dart';
import '../../services/app_data_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/bus_map_widget.dart';

class AdminTrackingScreen extends StatefulWidget {
  final AppDataService dataService;
  final BusModel? initialFocus;
  const AdminTrackingScreen({
    super.key,
    required this.dataService,
    this.initialFocus,
  });
  @override
  State<AdminTrackingScreen> createState() => _AdminTrackingScreenState();
}

class _AdminTrackingScreenState extends State<AdminTrackingScreen> {
  final MapController _mapController = MapController();
  BusModel? _focusedBus;
  bool _showDetail = false; // panel detail bawah
  bool _showBusList = false; // dropdown list bus kanan atas

  // Flag: user sedang menjelajahi map secara manual (geser/zoom)
  // Selagi true, auto-follow dari stream update dinonaktifkan
  bool _userIsExploring = false;
  DateTime? _lastExploreTime;
  static const _exploreCooldown = Duration(seconds: 5);
  // StreamSubscription untuk listen MapEvent dari MapController
  dynamic _mapEventSub;

  bool get _isExploring {
    if (!_userIsExploring) return false;
    if (_lastExploreTime == null) return false;
    return DateTime.now().difference(_lastExploreTime!) < _exploreCooldown;
  }

  @override
  void initState() {
    super.initState();
    // Panel detail tidak langsung muncul — hanya muncul saat marker di-tap
    if (widget.initialFocus != null) {
      _focusedBus = widget.initialFocus;
      _showDetail = false;
    }
    // Deteksi gesture user via mapEventStream (cara resmi flutter_map)
    // MapEventMoveStart = user mulai geser/zoom secara manual
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mapEventSub = _mapController.mapEventStream.listen((event) {
        if (event is MapEventMoveStart) {
          // Cek apakah gerak ini dari gesture user (bukan dari move() programmatic)
          if (event.source == MapEventSource.dragStart ||
              event.source == MapEventSource.multiFingerGestureStart ||
              event.source == MapEventSource.scrollWheel ||
              event.source == MapEventSource.doubleTap ||
              event.source == MapEventSource.doubleTapHold) {
            _userIsExploring = true;
            _lastExploreTime = DateTime.now();
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _mapEventSub?.cancel();
    super.dispose();
  }

  void _selectBus(BusModel b) {
    setState(() {
      _focusedBus = b;
      _showBusList = false; // tutup dropdown, tapi panel TIDAK dibuka otomatis
    });
    _mapController.move(LatLng(b.latitude, b.longitude), 16.0);
  }

  void _tapBus(BusModel b) {
    setState(() {
      _focusedBus = b;
      _showDetail = true; // panel detail dibuka HANYA saat tap marker
      _showBusList = false;
    });
    _mapController.move(LatLng(b.latitude, b.longitude), 16.0);
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final bottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      body: StreamBuilder<List<BusModel>>(
        stream: widget.dataService.busesStream,
        builder: (_, s) {
          final buses = s.data ?? widget.dataService.buses;
          final active = buses.where((b) => b.gpsActive).toList();

          // Auto-focus bus pertama (tanpa buka panel)
          if (_focusedBus == null && active.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _selectBus(active.first);
            });
          }
          // Reset jika bus focused sudah tidak aktif
          if (_focusedBus != null &&
              !active.any((b) => b.id == _focusedBus!.id)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted)
                setState(() {
                  _focusedBus = active.isNotEmpty ? active.first : null;
                  _showDetail = _focusedBus != null;
                });
            });
          }
          // Update data focused bus dari stream (posisi terbaru)
          // Tapi JANGAN pindahkan kamera jika user sedang menggeser map
          if (_focusedBus != null) {
            final updated = active.where((b) => b.id == _focusedBus!.id);
            if (updated.isNotEmpty) {
              _focusedBus = updated.first;
              // Auto-follow: hanya pindah kamera jika user tidak sedang eksplorasi
              if (!_isExploring && _focusedBus!.latitude != 0) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    _mapController.move(
                      LatLng(_focusedBus!.latitude, _focusedBus!.longitude),
                      _mapController.camera.zoom,
                    );
                  }
                });
              }
            }
          }

          return GestureDetector(
            // Tap di luar dropdown → tutup dropdown
            onTap: _showBusList
                ? () => setState(() => _showBusList = false)
                : null,
            child: Stack(
              children: [
                // ── PETA FULL SCREEN ───────────────────────
                active.isEmpty
                    ? Container(
                        color: AppColors.surface2,
                        child: const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.directions_bus_outlined,
                                  size: 52, color: AppColors.textGrey),
                              SizedBox(height: 12),
                              Text('Belum ada bus yang beroperasi',
                                  style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textGrey)),
                              SizedBox(height: 6),
                              Text(
                                  'GPS muncul saat driver\nmengaktifkan tracking',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 12,
                                      color: AppColors.textGrey)),
                            ],
                          ),
                        ),
                      )
                    : SizedBox.expand(
                        child: BusMapWidget(
                          buses: active,
                          height: double.infinity,
                          showAllBuses: _focusedBus == null,
                          focusBus: _focusedBus,
                          interactive: true,
                          mapController: _mapController,
                          showInfoCard: false,
                          onBusTap: _tapBus,
                        ),
                      ),

                // ── TOP BAR ─────────────────────────────────
                Positioned(
                  top: top + 10,
                  left: 12,
                  right: 12,
                  child: Row(children: [
                    // Kembali
                    _CircleBtn(
                      icon: Icons.arrow_back_rounded,
                      onTap: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 10),
                    // Judul
                    Expanded(
                      child: Container(
                        height: 42,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2))
                          ],
                        ),
                        child: Row(children: [
                          const Text('Live Tracking',
                              style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.black)),
                          const Spacer(),
                          if (active.isNotEmpty) ...[
                            Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle)),
                            const SizedBox(width: 5),
                            Text('${active.length} aktif',
                                style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary)),
                          ],
                        ]),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Tombol list bus
                    if (active.isNotEmpty)
                      _CircleBtn(
                        icon: Icons.format_list_bulleted_rounded,
                        active: _showBusList,
                        onTap: () =>
                            setState(() => _showBusList = !_showBusList),
                      ),
                  ]),
                ),

                // ── DROPDOWN LIST BUS (kanan atas) ───────────
                if (_showBusList && active.isNotEmpty)
                  Positioned(
                    top: top + 62,
                    right: 12,
                    width: 220,
                    child: Material(
                      elevation: 8,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Header dropdown
                            Padding(
                              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                              child: Row(children: [
                                const Text('Bus Beroperasi',
                                    style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.black)),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                      color: AppColors.primaryLight,
                                      borderRadius: BorderRadius.circular(8)),
                                  child: Text('${active.length}',
                                      style: const TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.primary)),
                                ),
                              ]),
                            ),
                            const Divider(height: 1),
                            // List bus — setiap bus punya warna berbeda
                            ...active.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final b = entry.value;
                              final isSel = _focusedBus?.id == b.id;
                              // Palet warna sesuai _BusMarker di bus_map_widget
                              const busColors = [
                                Color(0xFF1565C0),
                                Color(0xFFE53935),
                                Color(0xFF2E7D32),
                                Color(0xFFE65100),
                                Color(0xFF6A1B9A),
                                Color(0xFF00838F),
                                Color(0xFF558B2F),
                                Color(0xFFAD1457),
                              ];
                              final busColor =
                                  busColors[b.id % busColors.length];
                              final digits =
                                  b.nama.replaceAll(RegExp(r'[^0-9]'), '');
                              final label = digits.isNotEmpty
                                  ? (digits.length > 2
                                      ? digits.substring(0, 2)
                                      : digits)
                                  : (b.nama.isNotEmpty
                                      ? b.nama[0].toUpperCase()
                                      : '?');
                              return GestureDetector(
                                onTap: () => _selectBus(b),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isSel
                                        ? busColor.withValues(alpha: 0.08)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(
                                        b == active.last ? 14 : 0),
                                  ),
                                  child: Row(children: [
                                    Container(
                                      width: 30,
                                      height: 30,
                                      decoration: BoxDecoration(
                                          color: isSel
                                              ? busColor
                                              : busColor.withValues(
                                                  alpha: 0.12),
                                          borderRadius:
                                              BorderRadius.circular(8)),
                                      child: Center(
                                        child: Text(label,
                                            style: TextStyle(
                                                fontFamily: 'Poppins',
                                                fontSize: 11,
                                                fontWeight: FontWeight.w800,
                                                color: isSel
                                                    ? Colors.white
                                                    : busColor)),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(b.nama,
                                              style: TextStyle(
                                                  fontFamily: 'Poppins',
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: isSel
                                                      ? busColor
                                                      : AppColors.black)),
                                          if (b.driverName.isNotEmpty)
                                            Text(b.driverName,
                                                style: const TextStyle(
                                                    fontFamily: 'Poppins',
                                                    fontSize: 10,
                                                    color: AppColors.textGrey)),
                                        ],
                                      ),
                                    ),
                                    Text('${b.speed.toStringAsFixed(0)} km/h',
                                        style: TextStyle(
                                            fontFamily: 'Poppins',
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: isSel
                                                ? busColor
                                                : AppColors.textGrey)),
                                  ]),
                                ),
                              );
                            }),
                            const SizedBox(height: 4),
                          ],
                        ),
                      ),
                    ),
                  ),

                // ── BOTTOM PANEL detail bus ──────────────────
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: AnimatedSlide(
                    offset: _showDetail ? Offset.zero : const Offset(0, 1),
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                    child: Container(
                      padding: EdgeInsets.fromLTRB(16, 0, 16, bottom + 16),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(20)),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black12,
                              blurRadius: 20,
                              offset: Offset(0, -4))
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Handle
                          GestureDetector(
                            onTap: () => setState(() => _showDetail = false),
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 10),
                              width: 36,
                              height: 4,
                              decoration: BoxDecoration(
                                  color: AppColors.lightGrey,
                                  borderRadius: BorderRadius.circular(2)),
                            ),
                          ),
                          if (_focusedBus != null)
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: _BusDetailCard(
                                key: ValueKey(_focusedBus!.id),
                                bus: _focusedBus!,
                                onClose: () =>
                                    setState(() => _showDetail = false),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── FAB tampilkan detail jika tersembunyi ────
                if (!_showDetail && _focusedBus != null)
                  Positioned(
                    bottom: bottom + 16,
                    left: 12,
                    right: 12,
                    child: GestureDetector(
                      onTap: () => setState(() => _showDetail = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 4))
                          ],
                        ),
                        child: Row(children: [
                          const Icon(Icons.directions_bus_rounded,
                              color: Colors.white, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(_focusedBus!.nama,
                                style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white)),
                          ),
                          Text('${_focusedBus!.speed.toStringAsFixed(0)} km/h',
                              style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                          const SizedBox(width: 8),
                          const Icon(Icons.keyboard_arrow_up_rounded,
                              color: Colors.white, size: 20),
                        ]),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Detail card ───────────────────────────────────────────────
class _BusDetailCard extends StatelessWidget {
  final BusModel bus;
  final VoidCallback onClose;
  const _BusDetailCard({super.key, required this.bus, required this.onClose});

  String _timeAgo(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inSeconds < 60) return '${d.inSeconds} detik lalu';
    if (d.inMinutes < 60) return '${d.inMinutes} menit lalu';
    return '${d.inHours} jam lalu';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.directions_bus_rounded,
                color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(bus.nama,
                    style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.black)),
                Text(bus.platNomor,
                    style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        color: AppColors.textGrey)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(6)),
            child: const Text('LIVE',
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onClose,
            child: const Icon(Icons.close_rounded,
                size: 20, color: AppColors.textGrey),
          ),
        ]),
        const SizedBox(height: 12),
        // Info rows
        _Row(
            icon: Icons.person_rounded,
            label: 'Driver',
            value: bus.driverName.isEmpty ? '-' : bus.driverName),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(
            child: _Row(
                icon: Icons.speed_rounded,
                label: 'Kecepatan',
                value: '${bus.speed.toStringAsFixed(0)} km/h'),
          ),
          if (bus.accuracy > 0)
            Expanded(
              child: _Row(
                  icon: Icons.my_location_rounded,
                  label: 'Akurasi',
                  value: '±${bus.accuracy.toStringAsFixed(0)}m',
                  valueColor: bus.accuracy <= 15
                      ? Colors.green
                      : bus.accuracy <= 30
                          ? Colors.orange
                          : Colors.red),
            ),
        ]),
        const SizedBox(height: 6),
        _Row(
            icon: Icons.location_on_rounded,
            label: 'Koordinat',
            value:
                '${bus.latitude.toStringAsFixed(5)}, ${bus.longitude.toStringAsFixed(5)}'),
        const SizedBox(height: 6),
        _Row(
            icon: Icons.update_rounded,
            label: 'Update',
            value: bus.lastUpdate != null ? _timeAgo(bus.lastUpdate!) : '-'),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  const _Row(
      {required this.icon,
      required this.label,
      required this.value,
      this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 14, color: AppColors.textGrey),
      const SizedBox(width: 6),
      Text('$label  ',
          style: const TextStyle(
              fontFamily: 'Poppins', fontSize: 12, color: AppColors.textGrey)),
      Flexible(
        child: Text(value,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: valueColor ?? AppColors.black)),
      ),
    ]);
  }
}

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool active;
  const _CircleBtn(
      {required this.icon, required this.onTap, this.active = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: active ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Icon(icon,
            color: active ? Colors.white : AppColors.black, size: 20),
      ),
    );
  }
}
