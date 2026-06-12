import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:provider/provider.dart';
import '../../models/models_api.dart';
import '../../services/routing_service.dart';
import '../../services/auth_provider.dart';
import '../../utils/app_theme.dart';

class NavigationScreen extends StatefulWidget {
  final BusModel bus;
  final LatLng initialDriverPos;
  final List<LatLng> initialPolyline;
  final int initialHalteIndex;
  final HalteModel? initialTargetHalte;
  final Stream<({LatLng pos, double heading, double speed})> positionStream;

  const NavigationScreen({
    super.key,
    required this.bus,
    required this.initialDriverPos,
    required this.initialPolyline,
    required this.initialHalteIndex,
    required this.initialTargetHalte,
    required this.positionStream,
  });

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen>
    with TickerProviderStateMixin {
  late final MapController _mapController;
  late final RoutingService _routingService;

  LatLng _driverPos = const LatLng(-7.6298, 111.5239);
  double _heading = 0.0;
  double _speed = 0.0;

  List<LatLng> _polyline = [];
  int _targetHalteIndex = 0;
  HalteModel? _targetHalte;

  StreamSubscription<({LatLng pos, double heading, double speed})>? _posSub;

  bool _headingUp = true;
  bool _userInteracting = false;
  DateTime? _lastInteractionTime;

  late final AnimationController _compassAnim;
  late Animation<double> _compassRotation;
  double _prevHeading = 0;

  bool _navRequestInProgress = false;
  Timer? _busRefreshTimer;

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    _mapController = MapController();
    _routingService = RoutingService();

    _driverPos = widget.initialDriverPos;
    _polyline = List.from(widget.initialPolyline);
    _targetHalteIndex = widget.initialHalteIndex;
    _targetHalte = widget.initialTargetHalte;

    _compassAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _compassRotation = Tween<double>(begin: 0, end: 0).animate(_compassAnim);

    _posSub = widget.positionStream.listen(_onPosition);

    _busRefreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) _refreshBusData();
    });
  }

  Future<void> _refreshBusData() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.refreshDriverBus();
      final updatedBus = authProvider.authService.cachedDriverBus;
      if (!mounted || updatedBus == null) return;

      if (updatedBus.routeList.isNotEmpty) {
        final haltes = updatedBus.routeList.first.haltes;
        if (_targetHalteIndex < haltes.length) {
          final newTargetHalte = haltes[_targetHalteIndex].halte;
          if (newTargetHalte?.id != _targetHalte?.id) {
            setState(() => _targetHalte = newTargetHalte);
          }
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));
    _posSub?.cancel();
    _busRefreshTimer?.cancel();
    _compassAnim.dispose();
    super.dispose();
  }

  void _onPosition(({LatLng pos, double heading, double speed}) data) {
    if (!mounted) return;

    final headingChanged = (data.heading - _prevHeading).abs() > 2;

    setState(() {
      _driverPos = data.pos;
      _speed = data.speed;
      if (headingChanged) _heading = data.heading;
    });

    if (headingChanged) {
      _compassRotation = Tween<double>(
        begin: _prevHeading,
        end: data.heading,
      ).animate(CurvedAnimation(parent: _compassAnim, curve: Curves.easeOut));
      _compassAnim.forward(from: 0);
      _prevHeading = data.heading;
    }

    if (!_isUserInteracting) {
      _mapController.move(_driverPos, _mapController.camera.zoom);
      if (_headingUp) {
        _mapController.rotate(-_heading);
      }
    }

    _updateNavigation();
  }

  bool get _isUserInteracting {
    if (!_userInteracting) return false;
    if (_lastInteractionTime == null) return false;
    return DateTime.now().difference(_lastInteractionTime!) <
        const Duration(seconds: 4);
  }

  Future<void> _updateNavigation() async {
    final haltes = _halteList;
    if (haltes.isEmpty || _navRequestInProgress) return;

    final nextIdx = _routingService.getNextHalteIndex(
      driverPos: _driverPos,
      haltes: haltes,
      currentIndex: _targetHalteIndex,
    );

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

    if (_targetHalteIndex >= haltes.length) {
      if (mounted) setState(() => _targetHalte = null);
      return;
    }

    final halte = haltes[_targetHalteIndex].halte;
    if (halte == null) return;

    final target = LatLng(halte.latitude, halte.longitude);
    _navRequestInProgress = true;
    try {
      final poly = await _routingService.getNavigationRoute(
          from: _driverPos, to: target);
      if (mounted) {
        setState(() {
          if (poly.isNotEmpty) _polyline = poly;
          _targetHalte = halte;
        });
      }
    } finally {
      _navRequestInProgress = false;
    }
  }

  List<RouteHalteModel> get _halteList =>
      widget.bus.routeList.isNotEmpty ? widget.bus.routeList.first.haltes : [];

  double get _distToHalte {
    if (_targetHalte == null) return 0;
    return _routingService.distanceToHalte(
        driverPos: _driverPos, halte: _targetHalte!);
  }

  String get _distLabel {
    final d = _distToHalte;
    if (d <= 0) return '';
    return d < 1000
        ? '${d.toStringAsFixed(0)} m'
        : '${(d / 1000).toStringAsFixed(1)} km';
  }

  String get _etaLabel {
    final d = _distToHalte;
    if (d <= 0 || _speed <= 0) return '';
    final minutes = ((d / 1000) / _speed * 60).round();
    if (minutes < 1) return '< 1 mnt';
    return '$minutes mnt';
  }

  void _toggleHeadingUp() {
    setState(() => _headingUp = !_headingUp);
    if (!_headingUp) {
      _mapController.rotate(0);
    } else {
      _mapController.rotate(-_heading);
    }
  }

  void _recenter() {
    setState(() => _userInteracting = false);
    _mapController.move(_driverPos, 17.0);
    if (_headingUp) _mapController.rotate(-_heading);
  }

  @override
  Widget build(BuildContext context) {
    final haltes = _halteList;
    final totalHaltes = haltes.length;
    final passed = _targetHalteIndex;
    final safeTop = MediaQuery.of(context).padding.top;
    final safeBottom = MediaQuery.of(context).padding.bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _driverPos,
                initialZoom: 17.0,
                minZoom: 10,
                maxZoom: 19,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all,
                ),
                onPositionChanged: (_, hasGesture) {
                  if (hasGesture) {
                    _userInteracting = true;
                    _lastInteractionTime = DateTime.now();
                  }
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  fallbackUrl:
                      'https://a.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.mobitra.app',
                  maxZoom: 19,
                  additionalOptions: const {
                    'User-Agent':
                        'Mobitra/1.0 (school bus tracker; contact@mobitra.app)',
                  },
                ),
                if (widget.bus.routeList.isNotEmpty &&
                    widget.bus.routeList.first.polyline.isNotEmpty)
                  PolylineLayer(polylines: [
                    Polyline(
                      points: widget.bus.routeList.first.polyline
                          .map((p) => LatLng(p.latitude, p.longitude))
                          .toList(),
                      color: Colors.grey.withValues(alpha: 0.35),
                      strokeWidth: 5,
                    ),
                  ]),
                if (_polyline.isNotEmpty) ...[
                  PolylineLayer(polylines: [
                    Polyline(
                      points: _polyline,
                      color: const Color(0xFF0D47A1).withValues(alpha: 0.4),
                      strokeWidth: 12,
                    ),
                  ]),
                  PolylineLayer(polylines: [
                    Polyline(
                      points: _polyline,
                      color: const Color(0xFF1A73E8),
                      strokeWidth: 8,
                    ),
                  ]),
                ],
                MarkerLayer(
                  markers: [
                    ...haltes.asMap().entries.map((e) {
                      final idx = e.key;
                      final halte = e.value.halte;
                      if (halte == null) return null;
                      final isPassed = idx < passed;
                      final isCurrent = idx == _targetHalteIndex;
                      return Marker(
                        point: LatLng(halte.latitude, halte.longitude),
                        width: isCurrent ? 40 : 28,
                        height: isCurrent ? 40 : 28,
                        child: Container(
                          decoration: BoxDecoration(
                            color: isPassed
                                ? Colors.grey.shade400
                                : isCurrent
                                    ? const Color(0xFFFF6B00)
                                    : AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: Colors.white, width: isCurrent ? 3 : 2),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 6)
                            ],
                          ),
                          child: Center(
                            child: Text(
                              '${idx + 1}',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: isCurrent ? 14 : 10,
                                  fontWeight: FontWeight.w800,
                                  fontFamily: 'Poppins'),
                            ),
                          ),
                        ),
                      );
                    }).whereType<Marker>(),
                  ],
                ),
                MarkerLayer(markers: [
                  Marker(
                    point: _driverPos,
                    width: 48,
                    height: 48,
                    child: AnimatedBuilder(
                      animation: _compassAnim,
                      builder: (_, __) => Transform.rotate(
                        angle: _compassRotation.value * math.pi / 180,
                        child: CustomPaint(
                          size: const Size(48, 48),
                          painter: _BusArrowPainter(),
                        ),
                      ),
                    ),
                  ),
                ]),
              ],
            ),
            Positioned(
              top: safeTop + 8,
              left: 12,
              right: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_targetHalte != null)
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B5E20),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 4))
                        ],
                      ),
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      child: Row(children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.arrow_upward_rounded,
                              color: Colors.white, size: 28),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ke arah ${_targetHalte!.namaHalte}',
                                style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    height: 1.2),
                              ),
                              if (_distLabel.isNotEmpty)
                                Text(
                                  _etaLabel.isNotEmpty
                                      ? '$_distLabel • $_etaLabel'
                                      : _distLabel,
                                  style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 12,
                                      color:
                                          Colors.white.withValues(alpha: 0.8)),
                                ),
                            ],
                          ),
                        ),
                      ]),
                    ),
                  if (_targetHalteIndex + 1 < haltes.length) ...[
                    const SizedBox(height: 6),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B5E20).withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      child: Row(children: [
                        const Icon(Icons.subdirectory_arrow_right_rounded,
                            color: Colors.white70, size: 18),
                        const SizedBox(width: 8),
                        const Text('Kemudian  ',
                            style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 13,
                                color: Colors.white70)),
                        Expanded(
                          child: Text(
                            haltes[_targetHalteIndex + 1].halte?.namaHalte ??
                                '',
                            style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ]),
                    ),
                  ],
                ],
              ),
            ),
            Positioned(
              right: 12,
              top: safeTop + 150,
              child: Column(children: [
                _MapButton(
                  onTap: _toggleHeadingUp,
                  child: AnimatedBuilder(
                    animation: _compassAnim,
                    builder: (_, __) => Transform.rotate(
                      angle: _headingUp
                          ? _compassRotation.value * math.pi / 180
                          : 0,
                      child: Icon(
                        Icons.navigation_rounded,
                        color: _headingUp ? Colors.red : AppColors.textGrey,
                        size: 24,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _MapButton(
                  onTap: _recenter,
                  child: const Icon(Icons.my_location_rounded,
                      color: AppColors.primary, size: 24),
                ),
              ]),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black26,
                        blurRadius: 16,
                        offset: Offset(0, -4))
                  ],
                ),
                padding: EdgeInsets.fromLTRB(20, 16, 20, safeBottom + 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                              color: AppColors.lightGrey,
                              borderRadius: BorderRadius.circular(2))),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _InfoChip(
                          icon: Icons.speed_rounded,
                          value: _speed.toStringAsFixed(0),
                          unit: 'km/h',
                          color: AppColors.primary,
                        ),
                        _InfoChip(
                          icon: Icons.place_rounded,
                          value: '$passed/$totalHaltes',
                          unit: 'halte',
                          color: const Color(0xFFFF6B00),
                        ),
                        _InfoChip(
                          icon: Icons.route_rounded,
                          value: _distLabel.isEmpty ? '-' : _distLabel,
                          unit: 'ke halte',
                          color: AppColors.blue,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (totalHaltes > 0) ...[
                      Row(children: [
                        Text('$passed halte terlewati',
                            style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 11,
                                color: AppColors.textGrey)),
                        const Spacer(),
                        Text('$totalHaltes total',
                            style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 11,
                                color: AppColors.textGrey)),
                      ]),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: passed / totalHaltes,
                          minHeight: 6,
                          backgroundColor: AppColors.lightGrey,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                              AppColors.primary),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded,
                            size: 18, color: AppColors.red),
                        label: const Text('Keluar Navigasi',
                            style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.red)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                              color: AppColors.red, width: 1.2),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
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

class _MapButton extends StatelessWidget {
  final VoidCallback onTap;
  final Widget child;
  const _MapButton({required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8)
          ],
        ),
        child: Center(child: child),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String unit;
  final Color color;
  const _InfoChip(
      {required this.icon,
      required this.value,
      required this.unit,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: color)),
        Text(unit,
            style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 10,
                color: AppColors.textGrey)),
      ]),
    );
  }
}

class _BusArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    canvas.drawPath(
      Path()
        ..moveTo(cx, cy - 18)
        ..lineTo(cx - 11, cy + 14)
        ..lineTo(cx, cy + 7)
        ..lineTo(cx + 11, cy + 14)
        ..close(),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    canvas.drawPath(
      Path()
        ..moveTo(cx, cy - 20)
        ..lineTo(cx - 13, cy + 16)
        ..lineTo(cx, cy + 8)
        ..lineTo(cx + 13, cy + 16)
        ..close(),
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );

    canvas.drawPath(
      Path()
        ..moveTo(cx, cy - 18)
        ..lineTo(cx - 11, cy + 14)
        ..lineTo(cx, cy + 7)
        ..lineTo(cx + 11, cy + 14)
        ..close(),
      Paint()
        ..color = const Color(0xFF1A73E8)
        ..style = PaintingStyle.fill,
    );

    canvas.drawCircle(Offset(cx, cy + 2), 4, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
