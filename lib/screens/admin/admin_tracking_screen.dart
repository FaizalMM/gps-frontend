import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../models/models_api.dart';
import '../../services/app_data_service.dart';
import '../../services/domain_services.dart';
import '../../utils/app_theme.dart';
import '../../widgets/bus_map_widget.dart';

enum _ConnStatus { live, reconnecting, error }

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
  final _routeService = BusRouteService();

  BusModel? _focusedBus;
  bool _showDetail = false;
  bool _showBusList = false;
  RouteModel? _activeRoute;
  bool _loadingRoute = false;
  Map<int, bool> _prevGpsState = {};
  bool _initialFocusDone = false;
  StreamSubscription<List<BusModel>>? _busSub;
  _ConnStatus _connStatus = _ConnStatus.live;

  @override
  void initState() {
    super.initState();
    if (widget.initialFocus != null) {
      _focusedBus = widget.initialFocus;
      _initialFocusDone = true;
    }
    _prevGpsState = {
      for (final b in widget.dataService.buses) b.id: b.gpsActive
    };
    _busSub = widget.dataService.busesStream.listen(
      (buses) {
        if (!mounted) return;
        _checkGpsChanges(buses);
        if (_connStatus != _ConnStatus.live) {
          setState(() => _connStatus = _ConnStatus.live);
        }
      },
      onError: (_) {
        if (mounted) setState(() => _connStatus = _ConnStatus.error);
      },
    );
  }

  @override
  void dispose() {
    _busSub?.cancel();
    super.dispose();
  }

  void _checkGpsChanges(List<BusModel> current) {
    for (final bus in current) {
      final prevActive = _prevGpsState[bus.id];
      if (prevActive != null && prevActive != bus.gpsActive) {
        final name = bus.driverName.isNotEmpty ? bus.driverName : bus.nama;
        final msg =
            bus.gpsActive ? '$name mengaktifkan GPS' : '$name mematikan GPS';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            Icon(
              bus.gpsActive ? Icons.gps_fixed_rounded : Icons.gps_off_rounded,
              size: 16,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(msg,
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 13)),
            ),
          ]),
          backgroundColor:
              bus.gpsActive ? AppColors.primary : AppColors.textGrey,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    }
    _prevGpsState = {for (final b in current) b.id: b.gpsActive};
  }

  void _moveCameraTo(BusModel b, {double zoom = 16.0}) {
    _mapController.move(LatLng(b.latitude, b.longitude), zoom);
  }

  Future<void> _selectBus(BusModel b) async {
    setState(() {
      _focusedBus = b;
      _showBusList = false;
      _loadingRoute = true;
    });
    _moveCameraTo(b);
    final route = await _routeService.getBusRoute(b.id);
    if (mounted) {
      setState(() {
        _activeRoute = route;
        _loadingRoute = false;
      });
    }
  }

  Future<void> _tapBus(BusModel b) async {
    setState(() {
      _focusedBus = b;
      _showDetail = true;
      _showBusList = false;
      _loadingRoute = true;
    });
    _moveCameraTo(b);
    final route = await _routeService.getBusRoute(b.id);
    if (mounted) {
      setState(() {
        _activeRoute = route;
        _loadingRoute = false;
      });
    }
  }

  static const _halteColors = [
    Color(0xFF4CAF50),
    Color(0xFFF44336),
    Color(0xFF2196F3),
    Color(0xFFFF9800),
    Color(0xFF9C27B0),
    Color(0xFF00BCD4),
    Color(0xFF795548),
    Color(0xFF607D8B),
  ];

  List<Polyline> get _routePolylines {
    if (_activeRoute == null) return [];
    if (_activeRoute!.polyline.isNotEmpty) {
      return [
        Polyline(
          points: _activeRoute!.polyline
              .map((p) => LatLng(p.latitude, p.longitude))
              .toList(),
          color: AppColors.primary.withValues(alpha: 0.85),
          strokeWidth: 4.5,
        ),
      ];
    }
    final haltes = _activeRoute!.haltes.where((h) => h.halte != null).toList()
      ..sort((a, b) => a.urutan.compareTo(b.urutan));
    if (haltes.length < 2) return [];
    return [
      Polyline(
        points: haltes
            .map((h) => LatLng(h.halte!.latitude, h.halte!.longitude))
            .toList(),
        color: const Color(0xFF1B5E37).withValues(alpha: 0.65),
        strokeWidth: 3.5,
      ),
    ];
  }

  List<Marker> get _halteMarkers {
    if (_activeRoute == null) return [];
    final sorted = _activeRoute!.haltes.where((h) => h.halte != null).toList()
      ..sort((a, b) => a.urutan.compareTo(b.urutan));
    return sorted.asMap().entries.map((entry) {
      final idx = entry.key;
      final h = entry.value;
      final halte = h.halte!;
      final color = _halteColors[idx % _halteColors.length];
      return Marker(
        point: LatLng(halte.latitude, halte.longitude),
        width: 30,
        height: 30,
        child: Tooltip(
          message: 'Halte ${idx + 1}: ${halte.namaHalte}',
          child: Container(
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2), blurRadius: 4)
              ],
            ),
            child: Center(
              child: Text(
                '${idx + 1}',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      );
    }).toList();
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

          if (!_initialFocusDone && active.isNotEmpty) {
            _initialFocusDone = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _selectBus(active.first);
            });
          }

          if (_focusedBus != null &&
              !active.any((b) => b.id == _focusedBus!.id)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _focusedBus = active.isNotEmpty ? active.first : null;
                  _showDetail = false;
                  _activeRoute = null;
                });
              }
            });
          }

          if (_focusedBus != null) {
            final updated = active.where((b) => b.id == _focusedBus!.id);
            if (updated.isNotEmpty) _focusedBus = updated.first;
          }

          return GestureDetector(
            onTap: _showBusList
                ? () => setState(() => _showBusList = false)
                : null,
            child: Stack(children: [
              SizedBox.expand(
                child: Stack(children: [
                  BusMapWidget(
                    buses: active,
                    height: double.infinity,
                    showAllBuses: _focusedBus == null,
                    focusBus: _focusedBus,
                    interactive: true,
                    mapController: _mapController,
                    showInfoCard: false,
                    showBusCountBadge: false,
                    onBusTap: _tapBus,
                    extraPolylines: _routePolylines,
                    extraMarkers: _halteMarkers,
                    onMapTap: () => setState(() {
                      _activeRoute = null;
                      _showDetail = false;
                    }),
                  ),
                  if (active.isEmpty)
                    Positioned(
                      bottom: bottom + 24,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.12),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2))
                            ],
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: AppColors.textGrey,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 7),
                            const Text('Tidak ada bus aktif saat ini',
                                style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textGrey)),
                          ]),
                        ),
                      ),
                    ),
                  if (_loadingRoute)
                    Positioned(
                      top: top + 70,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 6)
                            ],
                          ),
                          child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                        color: AppColors.primary,
                                        strokeWidth: 2)),
                                SizedBox(width: 8),
                                Text('Memuat rute...',
                                    style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 11,
                                        color: AppColors.primary)),
                              ]),
                        ),
                      ),
                    ),
                  if (_activeRoute != null && !_loadingRoute)
                    Positioned(
                      top: top + 70,
                      left: 12,
                      child: _RouteInfoPill(
                        namaRute: _activeRoute!.namaRute.isNotEmpty
                            ? _activeRoute!.namaRute
                            : '${_activeRoute!.haltes.length} halte',
                        halteCount: _activeRoute!.haltes.length,
                        onDismiss: () => setState(() => _activeRoute = null),
                      ),
                    ),
                ]),
              ),
              Positioned(
                top: top + 10,
                left: 12,
                right: 12,
                child: Row(children: [
                  _CircleBtn(
                      icon: Icons.arrow_back_rounded,
                      onTap: () => Navigator.pop(context)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      height: 44,
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
                        _ConnStatusDot(status: _connStatus),
                      ]),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _CircleBtn(
                    icon: Icons.format_list_bulleted_rounded,
                    active: _showBusList,
                    onTap: () => setState(() => _showBusList = !_showBusList),
                    badge: active.isNotEmpty ? '${active.length}' : null,
                  ),
                ]),
              ),
              if (_showBusList && active.isNotEmpty)
                Positioned(
                  top: top + 62,
                  right: 12,
                  width: 230,
                  child: Material(
                    elevation: 8,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14)),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                          child: Row(children: [
                            const Text('Bus Beroperasi',
                                style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700)),
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
                        ...active.asMap().entries.map((entry) {
                          final b = entry.value;
                          final isSel = _focusedBus?.id == b.id;
                          const busColors = [
                            Color(0xFF1565C0),
                            Color(0xFFE53935),
                            Color(0xFF2E7D32),
                            Color(0xFFE65100),
                            Color(0xFF6A1B9A),
                            Color(0xFF00838F),
                          ];
                          final busColor = busColors[b.id % busColors.length];
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
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                      color: isSel
                                          ? busColor
                                          : busColor.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8)),
                                  child: Center(
                                      child: Text(label,
                                          style: TextStyle(
                                              fontFamily: 'Poppins',
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              color: isSel
                                                  ? Colors.white
                                                  : busColor))),
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
                                      ]),
                                ),
                                Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text('${b.speed.toStringAsFixed(0)} km/h',
                                          style: TextStyle(
                                              fontFamily: 'Poppins',
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: isSel
                                                  ? busColor
                                                  : AppColors.textGrey)),
                                      const SizedBox(height: 2),
                                      Icon(
                                          isSel
                                              ? Icons.location_on_rounded
                                              : Icons
                                                  .location_searching_rounded,
                                          size: 12,
                                          color: isSel
                                              ? busColor
                                              : AppColors.textGrey),
                                    ]),
                              ]),
                            ),
                          );
                        }),
                        const Padding(
                          padding: EdgeInsets.fromLTRB(14, 6, 14, 10),
                          child: Row(children: [
                            Icon(Icons.touch_app_rounded,
                                size: 11, color: AppColors.textGrey),
                            SizedBox(width: 4),
                            Text('Ketuk bus untuk fokus ke lokasinya',
                                style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 9,
                                    color: AppColors.textGrey)),
                          ]),
                        ),
                      ]),
                    ),
                  ),
                ),
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
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
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
                            route: _activeRoute,
                            onClose: () => setState(() => _showDetail = false),
                          ),
                        ),
                    ]),
                  ),
                ),
              ),
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
            ]),
          );
        },
      ),
    );
  }
}

class _RouteInfoPill extends StatelessWidget {
  final String namaRute;
  final int halteCount;
  final VoidCallback onDismiss;

  const _RouteInfoPill(
      {required this.namaRute,
      required this.halteCount,
      required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 6)
        ],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
                color: AppColors.primary, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(namaRute,
            style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.black)),
        const SizedBox(width: 4),
        Text('• $halteCount halte',
            style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 10,
                color: AppColors.textGrey)),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: onDismiss,
          child: const Icon(Icons.close_rounded,
              size: 14, color: AppColors.textGrey),
        ),
      ]),
    );
  }
}

class _BusDetailCard extends StatelessWidget {
  final BusModel bus;
  final RouteModel? route;
  final VoidCallback onClose;
  const _BusDetailCard(
      {super.key, required this.bus, this.route, required this.onClose});

  String _timeAgo(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inSeconds < 60) return '${d.inSeconds} detik lalu';
    if (d.inMinutes < 60) return '${d.inMinutes} menit lalu';
    return '${d.inHours} jam lalu';
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(bus.nama,
                style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
            Text(bus.platNomor,
                style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    color: AppColors.textGrey)),
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
              color: AppColors.primary, borderRadius: BorderRadius.circular(6)),
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
                size: 20, color: AppColors.textGrey)),
      ]),
      const SizedBox(height: 12),
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
                value: '${bus.speed.toStringAsFixed(0)} km/h')),
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
                          : Colors.red)),
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
      if (route != null) ...[
        const SizedBox(height: 6),
        _Row(
            icon: Icons.route_rounded,
            label: 'Rute',
            value: route!.namaRute.isNotEmpty
                ? route!.namaRute
                : '${route!.haltes.length} halte'),
      ],
    ]);
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
  final String? badge;
  const _CircleBtn(
      {required this.icon,
      required this.onTap,
      this.active = false,
      this.badge});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(clipBehavior: Clip.none, children: [
        Container(
          width: 44,
          height: 44,
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
        if (badge != null)
          Positioned(
            top: -4,
            right: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: Text(badge!,
                  style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ),
          ),
      ]),
    );
  }
}

class _ConnStatusDot extends StatelessWidget {
  final _ConnStatus status;
  const _ConnStatusDot({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      _ConnStatus.live => AppColors.primary,
      _ConnStatus.reconnecting => AppColors.orange,
      _ConnStatus.error => AppColors.red,
    };
    final label = switch (status) {
      _ConnStatus.live => 'Live',
      _ConnStatus.reconnecting => 'Reconnecting',
      _ConnStatus.error => 'Error',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color)),
      ]),
    );
  }
}
