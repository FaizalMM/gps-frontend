import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/models_api.dart';
import '../utils/app_theme.dart';
import 'dart:ui' as ui;
import 'dart:math' as math;

class BusMapWidget extends StatefulWidget {
  final List<BusModel> buses;
  final double height;
  final bool showAllBuses;
  final BusModel? focusBus;
  final LatLng? userLocation;
  final LatLng? driverLocation;
  final bool interactive;
  final MapController? mapController;

  final List<RouteModel> routes;

  /// Jika true, tampilkan semua rute. Jika false, hanya rute yang
  /// busnya match dengan [focusBus].
  final bool showRoutes;
  final bool showInfoCard;
  final List<dynamic> navigationPolyline;
  final Color? navPolylineColor; // null = pakai default biru navigasi
  final void Function(BusModel)? onBusTap;
  final List<Polyline> extraPolylines;
  final List<Marker> extraMarkers;
  final VoidCallback? onMapTap;
  final bool showBusCountBadge;

  const BusMapWidget({
    super.key,
    required this.buses,
    this.height = 220,
    this.showAllBuses = true,
    this.focusBus,
    this.userLocation,
    this.driverLocation,
    this.interactive = true,
    this.mapController,
    this.routes = const [],
    this.showRoutes = false,
    this.showInfoCard = true,
    this.navigationPolyline = const [],
    this.navPolylineColor,
    this.onBusTap,
    this.extraPolylines = const [],
    this.extraMarkers = const [],
    this.onMapTap,
    this.showBusCountBadge = true,
  });

  @override
  State<BusMapWidget> createState() => _BusMapWidgetState();
}

class _BusMapWidgetState extends State<BusMapWidget> {
  late MapController _mapController;
  int? _selectedHalteId;

  int? _selectedBusId;

  // Warna rute: orange (bus pertama) dan biru (bus kedua), bergantian
  static const List<Color> _routeColors = [
    Color(0xFFFF6B00), // orange
    Color(0xFF1565C0), // biru
    Color(0xFFFF6B00), // orange (rute ke-3 dst bergantian)
    Color(0xFF1565C0),
    Color(0xFFFF6B00),
  ];

  final Map<int, int> _busPolylineIndex = {};

  @override
  void initState() {
    super.initState();
    _mapController = widget.mapController ?? MapController();
    // Inisialisasi index polyline untuk semua bus yang sudah aktif saat widget pertama dibuat
    for (final bus in widget.buses) {
      if (!bus.gpsActive || bus.latitude == 0 || bus.longitude == 0) continue;
      _updateBusPolylineIndex(bus);
    }
  }

  bool _userInteracting = false;
  // Timer reset interaksi: 5 detik setelah user berhenti geser, auto-follow aktif kembali
  DateTime? _lastInteractionTime;
  static const _interactionCooldown = Duration(seconds: 5);

  bool get _isUserInteracting {
    if (!_userInteracting) return false;
    if (_lastInteractionTime == null) return false;
    // Jika sudah lebih dari 5 detik sejak interaksi terakhir, anggap selesai
    return DateTime.now().difference(_lastInteractionTime!) <
        _interactionCooldown;
  }

  @override
  void didUpdateWidget(BusMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Update indeks polyline untuk setiap bus yang posisinya berubah
    for (final bus in widget.buses) {
      if (!bus.gpsActive || bus.latitude == 0 || bus.longitude == 0) continue;
      final oldBus = oldWidget.buses.where((b) => b.id == bus.id).firstOrNull;
      final posChanged = oldBus == null ||
          oldBus.latitude != bus.latitude ||
          oldBus.longitude != bus.longitude;
      if (posChanged) {
        _updateBusPolylineIndex(bus);
      }
    }

    if (_isUserInteracting) return;

    if (widget.driverLocation != null &&
        widget.driverLocation != oldWidget.driverLocation) {
      _mapController.move(widget.driverLocation!, _mapController.camera.zoom);
      return;
    }
    if (!widget.showAllBuses && widget.focusBus != null) {
      final bus = widget.focusBus!;
      if (bus.gpsActive && bus.latitude != 0 && bus.longitude != 0) {
        _mapController.move(
            LatLng(bus.latitude, bus.longitude), _mapController.camera.zoom);
      }
    }
  }

  void _updateBusPolylineIndex(BusModel bus) {
    for (final route in widget.routes) {
      if (route.busId != bus.id) continue;
      if (route.polyline.isEmpty) continue;

      int closestIdx = 0;
      double minDist = double.infinity;

      for (int i = 0; i < route.polyline.length; i++) {
        final p = route.polyline[i];
        final dist = _haversineDistance(
          bus.latitude,
          bus.longitude,
          p.latitude,
          p.longitude,
        );
        if (dist < minDist) {
          minDist = dist;
          closestIdx = i;
        }
      }

      final prev = _busPolylineIndex[bus.id] ?? 0;
      if (closestIdx > prev) {
        setState(() => _busPolylineIndex[bus.id] = closestIdx);
      }
    }
  }

  /// Jarak haversine antara dua koordinat (hasil dalam meter)
  double _haversineDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0;
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(lat1)) *
            math.cos(_toRad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  double _toRad(double deg) => deg * math.pi / 180;

  static const LatLng _defaultCenter = LatLng(-7.6298, 111.5239);

  LatLng _getCenter() {
    if (widget.driverLocation != null) return widget.driverLocation!;

    if (!widget.showAllBuses && widget.focusBus != null) {
      final bus = widget.focusBus!;
      // Hanya pakai koordinat bus bila valid (bukan 0,0 yang merupakan default)
      if (bus.latitude != 0 && bus.longitude != 0) {
        return LatLng(bus.latitude, bus.longitude);
      }
      return _defaultCenter;
    }

    // Filter hanya bus yang punya koordinat GPS valid (bukan 0,0)
    final validBuses =
        widget.buses.where((b) => b.latitude != 0 && b.longitude != 0).toList();

    if (validBuses.isEmpty) return _defaultCenter;

    // Rata-rata koordinat bus yang valid
    final lat =
        validBuses.fold(0.0, (sum, b) => sum + b.latitude) / validBuses.length;
    final lng =
        validBuses.fold(0.0, (sum, b) => sum + b.longitude) / validBuses.length;
    return LatLng(lat, lng);
  }

  /// Rute yang akan ditampilkan — filter berdasarkan [showAllBuses]
  List<RouteModel> get _visibleRoutes {
    if (!widget.showRoutes) return [];
    if (widget.showAllBuses || widget.focusBus == null) return widget.routes;
    return widget.routes.where((r) => r.busId == widget.focusBus!.id).toList();
  }

  @override
  Widget build(BuildContext context) {
    final activeBuses = widget.buses.where((b) => b.gpsActive).toList();
    final visibleRoutes = _visibleRoutes;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: widget.height,
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _getCenter(),
                // Zoom 13 untuk view keseluruhan kota, 15 untuk detail
                initialZoom: widget.showAllBuses ? 13.0 : 15.0,
                minZoom: 5,
                maxZoom: 19,
                interactionOptions: InteractionOptions(
                  flags: widget.interactive
                      ? InteractiveFlag.all
                      : InteractiveFlag.none,
                ),
                onTap: (_, __) {
                  setState(() {
                    _selectedHalteId = null;
                    _selectedBusId = null;
                  });
                  widget.onMapTap?.call();
                },

                onPositionChanged: (position, hasGesture) {
                  if (hasGesture) {
                    _userInteracting = true;
                    _lastInteractionTime = DateTime.now();
                  }
                },
              ),
              children: [
                TileLayer(
                  // Primary: OpenStreetMap
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  // Fallback: CartoDB (tampil bila OSM lambat/gagal)
                  fallbackUrl:
                      'https://a.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.mobitra.app',
                  maxZoom: 19,
                  maxNativeZoom: 19,
                  // Header wajib agar OSM tidak block request dari Flutter
                  additionalOptions: const {
                    'User-Agent':
                        'Mobitra/1.0 (school bus tracker; contact@mobitra.app)',
                  },
                ),

                if (visibleRoutes.isNotEmpty)
                  ...visibleRoutes.asMap().entries.expand((entry) {
                    final idx = entry.key;
                    final route = entry.value;
                    final color = _routeColors[idx % _routeColors.length];

                    if (route.polyline.isEmpty) return <Widget>[];

                    final allPoints = route.polyline
                        .map((p) => LatLng(p.latitude, p.longitude))
                        .toList();

                    // Cari bus yang sesuai dengan rute ini
                    final matchBus = widget.buses
                        .where((b) => b.gpsActive && b.id == route.busId)
                        .firstOrNull;

                    // Indeks titik terdekat bus di polyline
                    final splitIdx = matchBus != null
                        ? (_busPolylineIndex[matchBus.id] ?? 0)
                        : 0;

                    // Sisa rute: dari posisi bus ke depan
                    final aheadPoints = splitIdx < allPoints.length
                        ? allPoints.sublist(splitIdx)
                        : <LatLng>[];

                    final passedPoints = splitIdx > 0
                        ? allPoints.sublist(0, splitIdx + 1)
                        : <LatLng>[];

                    return [
                      // Bagian sudah dilalui — sangat pudar, tipis
                      if (passedPoints.length >= 2)
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: passedPoints,
                              color: color.withValues(alpha: 0.12),
                              strokeWidth: 3,
                            ),
                          ],
                        ),

                      // Sisa rute ke depan — shadow
                      if (aheadPoints.length >= 2)
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: aheadPoints,
                              color: color.withValues(alpha: 0.22),
                              strokeWidth: 10,
                            ),
                          ],
                        ),

                      // Sisa rute ke depan — garis utama penuh
                      if (aheadPoints.length >= 2)
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: aheadPoints,
                              color: color,
                              strokeWidth: 5,
                            ),
                            // Garis putih tipis di tengah (efek Google Maps)
                            Polyline(
                              points: aheadPoints,
                              color: Colors.white.withValues(alpha: 0.4),
                              strokeWidth: 1.8,
                            ),
                          ],
                        ),

                      // Fallback: belum ada bus aktif, tampilkan rute penuh normal
                      if (matchBus == null && allPoints.length >= 2)
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: allPoints,
                              color: color.withValues(alpha: 0.22),
                              strokeWidth: 10,
                            ),
                            Polyline(
                              points: allPoints,
                              color: color,
                              strokeWidth: 5,
                            ),
                            Polyline(
                              points: allPoints,
                              color: Colors.white.withValues(alpha: 0.4),
                              strokeWidth: 1.8,
                            ),
                          ],
                        ),
                    ];
                  }),

                if (visibleRoutes.isNotEmpty)
                  MarkerLayer(
                    markers: [
                      for (int ri = 0; ri < visibleRoutes.length; ri++)
                        for (final rh in visibleRoutes[ri].haltes)
                          if (rh.halte != null &&
                              rh.halte!.latitude != 0 &&
                              rh.halte!.longitude != 0)
                            Marker(
                              point: LatLng(
                                  rh.halte!.latitude, rh.halte!.longitude),
                              width: 36,
                              height: 44,
                              child: GestureDetector(
                                onTap: () => setState(
                                    () => _selectedHalteId = rh.halteId),
                                child: _HalteMarker(
                                  urutan: rh.urutan,
                                  color: _routeColors[ri % _routeColors.length],
                                  isSelected: _selectedHalteId == rh.halteId,
                                ),
                              ),
                            ),
                    ],
                  ),

                if (widget.navigationPolyline.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      // Shadow
                      Polyline(
                        points: List<LatLng>.from(widget.navigationPolyline),
                        color:
                            (widget.navPolylineColor ?? const Color(0xFF1A73E8))
                                .withValues(alpha: 0.25),
                        strokeWidth: 10,
                      ),
                      // Garis utama putus-putus
                      Polyline(
                        points: List<LatLng>.from(widget.navigationPolyline),
                        color:
                            widget.navPolylineColor ?? const Color(0xFF1A73E8),
                        strokeWidth: 4,
                        pattern: StrokePattern.dashed(segments: const [12, 6]),
                      ),
                    ],
                  ),

                if (widget.userLocation != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: widget.userLocation!,
                        width: 40,
                        height: 40,
                        child: _UserLocationMarker(),
                      ),
                    ],
                  ),

                // ── Marker driver
                if (widget.driverLocation != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: widget.driverLocation!,
                        width: 56,
                        height: 64,
                        child: const _DriverMarker(),
                      ),
                    ],
                  ),

                if (activeBuses.isNotEmpty)
                  MarkerLayer(
                    markers: activeBuses
                        .where((b) => b.latitude != 0 && b.longitude != 0)
                        .map((bus) {
                      final isFocus = widget.focusBus?.id == bus.id;
                      final isSelected = _selectedBusId == bus.id;
                      return Marker(
                        point: LatLng(bus.latitude, bus.longitude),
                        width: 44,
                        height: 44,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedBusId = isSelected ? null : bus.id;
                              _selectedHalteId = null;
                            });
                            // Panggil callback eksternal (misal buka panel detail)
                            if (!isSelected) widget.onBusTap?.call(bus);
                          },
                          child: _BusMarker(
                            bus: bus,
                            isFocused: isFocus,
                            isSelected: isSelected,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                if (widget.extraPolylines.isNotEmpty)
                  PolylineLayer(polylines: widget.extraPolylines),
                if (widget.extraMarkers.isNotEmpty)
                  MarkerLayer(markers: widget.extraMarkers),
              ],
            ),
            if (widget.showInfoCard) ...[
              if (_selectedBusId != null)
                Positioned(
                  bottom: 12,
                  left: 12,
                  right: 12,
                  child: _buildBusInfoPopup(
                    activeBuses.firstWhere(
                      (b) => b.id == _selectedBusId,
                      orElse: () => activeBuses.first,
                    ),
                  ),
                )
              else if (_selectedHalteId != null)
                Positioned(
                  bottom: 12,
                  left: 12,
                  right: 12,
                  child: _buildHalteInfoCard(visibleRoutes),
                )
              else if (activeBuses.isNotEmpty)
                Positioned(
                  bottom: 12,
                  left: 12,
                  right: 12,
                  child: _MapInfoCard(
                    bus: widget.focusBus ?? activeBuses.first,
                    totalActive: activeBuses.length,
                    showAll: widget.showAllBuses,
                    activeBuses: activeBuses,
                  ),
                )
              else if (widget.driverLocation != null && !widget.showAllBuses)
                Positioned(
                  bottom: 12,
                  left: 12,
                  right: 12,
                  child: _DriverGpsInfoCard(),
                ),
            ],
            if (widget.showAllBuses && widget.showBusCountBadge)
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 6)
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.directions_bus_rounded,
                          color: Colors.white, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        '${activeBuses.length} bus aktif',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (visibleRoutes.length > 1)
              Positioned(
                top: 12,
                left: widget.showAllBuses ? null : 12,
                right: widget.showAllBuses ? null : null,
                child: _RouteLegend(
                  routes: visibleRoutes,
                  colors: _routeColors,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Popup info bus yang muncul saat marker di-tap
  Widget _buildBusInfoPopup(BusModel bus) {
    final hasDriver = bus.driverName.isNotEmpty;
    final speed = bus.speed.toStringAsFixed(0);
    final lastUpdate =
        bus.lastUpdate != null ? _formatLastUpdate(bus.lastUpdate!) : '-';

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.13),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header
          Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(10),
              ),
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
                      color: AppColors.black,
                    )),
                Text(bus.platNomor,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      color: AppColors.textGrey,
                    )),
              ],
            )),
            // Badge LIVE
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                      color: AppColors.primary, shape: BoxShape.circle),
                ),
                const SizedBox(width: 4),
                const Text('LIVE',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    )),
              ]),
            ),
            const SizedBox(width: 6),
            // Tombol tutup
            GestureDetector(
              onTap: () => setState(() => _selectedBusId = null),
              child: const Icon(Icons.close_rounded,
                  color: AppColors.textGrey, size: 18),
            ),
          ]),

          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          const SizedBox(height: 12),

          _BusInfoRow(
            icon: Icons.person_rounded,
            label: 'Driver',
            value: hasDriver ? bus.driverName : 'Tidak ada driver',
          ),
          const SizedBox(height: 8),
          _BusInfoRow(
            icon: Icons.speed_rounded,
            label: 'Kecepatan',
            value: '$speed km/h',
          ),
          const SizedBox(height: 8),
          _BusInfoRow(
            icon: Icons.location_on_rounded,
            label: 'Koordinat',
            value:
                '${bus.latitude.toStringAsFixed(5)}, ${bus.longitude.toStringAsFixed(5)}',
          ),
          const SizedBox(height: 8),
          _BusInfoRow(
            icon: Icons.update_rounded,
            label: 'Update terakhir',
            value: lastUpdate,
          ),
        ],
      ),
    );
  }

  String _formatLastUpdate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds} detik lalu';
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    return '${diff.inDays} hari lalu';
  }

  Widget _buildHalteInfoCard(List<RouteModel> routes) {
    for (final route in routes) {
      for (final rh in route.haltes) {
        if (rh.halteId == _selectedHalteId) {
          return _HalteInfoCard(
            namaHalte: rh.halte?.namaHalte ?? 'Halte #${rh.halteId}',
            urutan: rh.urutan,
            namaRute: route.namaRute,
            alamat: rh.halte?.alamat ?? '',
            onClose: () => setState(() => _selectedHalteId = null),
          );
        }
      }
    }
    return const SizedBox.shrink();
  }
}

class _HalteMarker extends StatelessWidget {
  final int urutan;
  final Color color;
  final bool isSelected;
  const _HalteMarker({
    required this.urutan,
    required this.color,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: isSelected ? 32 : 26,
          height: isSelected ? 32 : 26,
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: color, width: isSelected ? 3 : 2.5),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.4),
                blurRadius: isSelected ? 8 : 4,
              ),
            ],
          ),
          child: Center(
            child: Text(
              '$urutan',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: isSelected ? 11 : 10,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : color,
              ),
            ),
          ),
        ),
        // Ekor bawah
        CustomPaint(
          size: const Size(8, 5),
          painter: _MarkerTailPainter(color: color),
        ),
      ],
    );
  }
}

class _HalteInfoCard extends StatelessWidget {
  final String namaHalte;
  final int urutan;
  final String namaRute;
  final String alamat;
  final VoidCallback onClose;

  const _HalteInfoCard({
    required this.namaHalte,
    required this.urutan,
    required this.namaRute,
    required this.alamat,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 10)
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '$urutan',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  namaHalte,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.black,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  alamat.isNotEmpty ? alamat : namaRute,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 10,
                    color: AppColors.textGrey,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18),
            color: AppColors.textGrey,
            padding: EdgeInsets.zero,
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}

class _RouteLegend extends StatelessWidget {
  final List<RouteModel> routes;
  final List<Color> colors;
  const _RouteLegend({required this.routes, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 12),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.93),
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < routes.length && i < colors.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 16,
                    height: 3,
                    decoration: BoxDecoration(
                      color: colors[i],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    routes[i].namaRute.length > 16
                        ? '${routes[i].namaRute.substring(0, 14)}…'
                        : routes[i].namaRute,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                      color: AppColors.black,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _BusMarker extends StatelessWidget {
  final BusModel bus;
  final bool isFocused;
  final bool isSelected;

  static const List<Color> _busColors = [
    Color(0xFF1565C0), // biru tua
    Color(0xFFE53935), // merah
    Color(0xFF2E7D32), // hijau tua
    Color(0xFFE65100), // oranye tua
    Color(0xFF6A1B9A), // ungu
    Color(0xFF00838F), // teal
    Color(0xFF558B2F), // hijau olive
    Color(0xFFAD1457), // pink tua
  ];

  const _BusMarker({
    required this.bus,
    this.isFocused = false,
    this.isSelected = false,
  });

  Color get _color => _busColors[bus.id % _busColors.length];

  /// Label singkat untuk fallback: ambil angka dari nama bus, fallback huruf pertama
  String get _label {
    final digits = bus.nama.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isNotEmpty) {
      return digits.length > 2 ? digits.substring(0, 2) : digits;
    }
    return bus.nama.isNotEmpty ? bus.nama[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    final size = isSelected ? 52.0 : (isFocused ? 46.0 : 40.0);
    final border = (isFocused || isSelected) ? 3.0 : 2.5;
    final hasPhoto = bus.photoUrl != null && bus.photoUrl!.isNotEmpty;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: border),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: isSelected ? 0.75 : 0.50),
            blurRadius: isSelected ? 18 : 8,
            spreadRadius: isSelected ? 4 : 1,
          ),
        ],
      ),
      child: ClipOval(
        child: hasPhoto
            ? CachedNetworkImage(
                imageUrl: bus.photoUrl!,
                fit: BoxFit.cover,
                httpHeaders: const {
                  'ngrok-skip-browser-warning': 'true',
                  'User-Agent': 'Mobitra-App/1.0',
                },
                placeholder: (_, __) => _LabelFallback(
                  label: _label,
                  fontSize: isSelected ? 13.0 : (isFocused ? 12.0 : 10.0),
                ),
                errorWidget: (_, __, ___) => _LabelFallback(
                  label: _label,
                  fontSize: isSelected ? 13.0 : (isFocused ? 12.0 : 10.0),
                ),
              )
            : _LabelFallback(
                label: _label,
                fontSize: isSelected ? 13.0 : (isFocused ? 12.0 : 10.0),
              ),
      ),
    );
  }
}

class _LabelFallback extends StatelessWidget {
  final String label;
  final double fontSize;
  const _LabelFallback({required this.label, required this.fontSize});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          fontFamily: 'Poppins',
          height: 1.0,
        ),
      ),
    );
  }
}

// ── Row info dalam popup bus
class _BusInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _BusInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 16, color: AppColors.primary),
      const SizedBox(width: 10),
      SizedBox(
        width: 110,
        child: Text(label,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              color: AppColors.textGrey,
            )),
      ),
      Expanded(
        child: Text(value,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.black,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
      ),
    ]);
  }
}

class _UserLocationMarker extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.blue,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
              color: Colors.blue.withValues(alpha: 0.4),
              blurRadius: 8,
              spreadRadius: 2)
        ],
      ),
      child: const Icon(Icons.person_pin_circle_rounded,
          color: Colors.white, size: 20),
    );
  }
}

class _MapInfoCard extends StatelessWidget {
  final BusModel bus;
  final int totalActive;
  final bool showAll;
  final List<BusModel> activeBuses;

  const _MapInfoCard({
    required this.bus,
    required this.totalActive,
    required this.showAll,
    this.activeBuses = const [],
  });

  Widget _liveBadge() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
                color: AppColors.primary, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          const Text('LIVE',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              )),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    // ── Mode showAll: tampilkan ringkasan semua bus aktif ──
    if (showAll && activeBuses.isNotEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.12), blurRadius: 10)
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(children: [
              const Icon(Icons.directions_bus_rounded,
                  color: AppColors.primary, size: 16),
              const SizedBox(width: 6),
              Text('$totalActive Bus Beroperasi',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.black,
                  )),
              const Spacer(),
              _liveBadge(),
            ]),
            const SizedBox(height: 8),
            // Daftar maks 3 bus
            ...activeBuses.take(3).map((b) => Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Row(children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(6)),
                      child: const Icon(Icons.directions_bus_rounded,
                          color: AppColors.primary, size: 14),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(b.nama,
                              style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.black)),
                          Text(
                            b.driverName.isNotEmpty
                                ? b.driverName
                                : 'Tidak ada driver',
                            style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 10,
                                color: AppColors.textGrey),
                          ),
                        ])),
                    Text('${b.speed.toStringAsFixed(0)} km/h',
                        style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary)),
                  ]),
                )),
            if (activeBuses.length > 3)
              Text('+ ${activeBuses.length - 3} bus lainnya',
                  style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 10,
                      color: AppColors.textGrey)),
          ],
        ),
      );
    }

    // ── Mode single bus
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 10)
        ],
      ),
      child: Row(children: [
        const Icon(Icons.directions_bus_rounded,
            color: AppColors.primary, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${bus.nama} · ${bus.speed.toStringAsFixed(0)} km/h',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.black,
                  ),
                ),
                Text(
                  bus.driverName.isNotEmpty
                      ? 'Driver: ${bus.driverName}'
                      : 'Tidak ada driver',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 10,
                    color: AppColors.textGrey,
                  ),
                ),
              ]),
        ),
        _liveBadge(),
      ]),
    );
  }
}

class _DriverGpsInfoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 10)
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.gps_fixed_rounded,
              color: AppColors.primary, size: 20),
          const SizedBox(width: 8),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'GPS Aktif · Mengirim lokasi',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.black,
                  ),
                ),
                Text(
                  'Posisi Anda sedang dipantau',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 10,
                    color: AppColors.textGrey,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                      color: AppColors.primary, shape: BoxShape.circle),
                ),
                const SizedBox(width: 4),
                const Text(
                  'LIVE',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverMarker extends StatefulWidget {
  const _DriverMarker();

  @override
  State<_DriverMarker> createState() => _DriverMarkerState();
}

class _DriverMarkerState extends State<_DriverMarker>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;
  late Animation<double> _opacityAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat();
    _scaleAnim = Tween<double>(begin: 1.0, end: 2.4)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _opacityAnim = Tween<double>(begin: 0.6, end: 0.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 64,
      child: Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
          AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) => Transform.scale(
              scale: _scaleAnim.value,
              child: Opacity(
                opacity: _opacityAnim.value,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.55),
                        blurRadius: 10,
                        spreadRadius: 2)
                  ],
                ),
                child: const Icon(Icons.person_pin_rounded,
                    color: Colors.white, size: 22),
              ),
              const CustomPaint(
                size: Size(12, 7),
                painter: _MarkerTailPainter(color: AppColors.primary),
              ),
            ],
          ),
          Positioned(
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'DRIVER',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MarkerTailPainter extends CustomPainter {
  final Color color;
  const _MarkerTailPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final ui.Path path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_) => false;
}
