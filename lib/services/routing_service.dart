import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../models/models_api.dart';

/// Profile routing yang tersedia
/// - [busHgv]  : OSRM driving-hgv  — jalan besar, hindari gang sempit (direkomendasikan untuk bus)
/// - [driving] : OSRM driving       — fallback standar
enum RoutingProfile { busHgv, driving }

class RoutingService {
  static final RoutingService _instance = RoutingService._internal();
  factory RoutingService() => _instance;
  RoutingService._internal();

  // ── OSRM public server ───────────────────────────────────────────────────
  // Profile 'driving-hgv' = Heavy Goods Vehicle → menggunakan jalan besar,
  // menghindari gang sempit, jembatan rendah, dan jalan dengan tonase rendah.
  // Cocok untuk rute bus sekolah.
  static const String _osrmHgv =
      'https://router.project-osrm.org/route/v1/driving-hgv';
  static const String _osrmDriving =
      'https://router.project-osrm.org/route/v1/driving';

  // Profile aktif — ganti ke RoutingProfile.driving jika ingin routing biasa
  static const RoutingProfile activeProfile = RoutingProfile.busHgv;

  static const double _haltePassThreshold = 80.0;

  final _distance = const Distance();

  // Cache polyline per (profile + from_grid + to)
  // from di-grid ke 3 desimal (~111m) agar cache tetap hit saat driver
  // bergerak sedikit, tapi minta ulang jika sudah bergerak >~100m.
  final Map<String, List<LatLng>> _polylineCache = {};
  final Map<String, DateTime> _lastRequestTime = {};

  // Throttle per cache-key: minimal 3 detik antar request dengan key yang sama
  static const int _requestThrottleSeconds = 3;

  // Jarak minimum pergerakan dari sebelum minta ulang rute (meter)
  static const double _rerouteThresholdMeters = 50.0;

  LatLng? _lastFromPos;

  String get _baseUrl =>
      activeProfile == RoutingProfile.busHgv ? _osrmHgv : _osrmDriving;

  Future<List<LatLng>> getNavigationRoute({
    required LatLng from,
    required LatLng to,
  }) async {
    const profileKey = activeProfile == RoutingProfile.busHgv ? 'hgv' : 'drv';

    // Grid dari: presisi 3 desimal ≈ 111m per unit → cache hit jika belum jauh bergerak
    final fromGrid =
        '${from.latitude.toStringAsFixed(3)},${from.longitude.toStringAsFixed(3)}';
    final cacheKey =
        '$profileKey:$fromGrid->${to.latitude.toStringAsFixed(5)},${to.longitude.toStringAsFixed(5)}';

    final now = DateTime.now();
    final lastRequest = _lastRequestTime[cacheKey];

    // Kembalikan cache jika masih fresh DAN driver belum bergerak melebihi threshold
    if (lastRequest != null &&
        now.difference(lastRequest).inSeconds < _requestThrottleSeconds) {
      final cached = _polylineCache[cacheKey];
      if (cached != null && cached.isNotEmpty) {
        // Cek apakah driver sudah bergerak cukup jauh untuk paksa reroute
        if (_lastFromPos == null ||
            _distance.as(LengthUnit.Meter, _lastFromPos!, from) <
                _rerouteThresholdMeters) {
          return cached;
        }
      }
    }

    _lastFromPos = from;

    try {
      final url =
          '$_baseUrl/${from.longitude},${from.latitude};${to.longitude},${to.latitude}'
          '?overview=full&geometries=geojson';

      final res =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));

      _lastRequestTime[cacheKey] = now;

      if (res.statusCode != 200) {
        // HGV gagal → coba fallback ke driving biasa
        if (activeProfile == RoutingProfile.busHgv) {
          return await _fallbackDriving(from, to, cacheKey);
        }
        final cached = _polylineCache[cacheKey];
        if (cached != null && cached.isNotEmpty) return cached;
        return _straightLine(from, to);
      }

      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final routes = json['routes'] as List?;
      if (routes == null || routes.isEmpty) {
        if (activeProfile == RoutingProfile.busHgv) {
          return await _fallbackDriving(from, to, cacheKey);
        }
        final cached = _polylineCache[cacheKey];
        if (cached != null && cached.isNotEmpty) return cached;
        return _straightLine(from, to);
      }

      final coords = (routes[0]['geometry']['coordinates'] as List)
          .map(
              (c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
          .toList();

      _polylineCache[cacheKey] = coords;
      return coords;
    } catch (_) {
      if (activeProfile == RoutingProfile.busHgv) {
        return await _fallbackDriving(from, to, cacheKey);
      }
      final cached = _polylineCache[cacheKey];
      if (cached != null && cached.isNotEmpty) return cached;
      return _straightLine(from, to);
    }
  }

  /// Fallback ke profile driving standar jika HGV gagal
  Future<List<LatLng>> _fallbackDriving(
      LatLng from, LatLng to, String cacheKey) async {
    try {
      final url =
          '$_osrmDriving/${from.longitude},${from.latitude};${to.longitude},${to.latitude}'
          '?overview=full&geometries=geojson';
      final res =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        final routes = json['routes'] as List?;
        if (routes != null && routes.isNotEmpty) {
          final coords = (routes[0]['geometry']['coordinates'] as List)
              .map((c) =>
                  LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
              .toList();
          _polylineCache[cacheKey] = coords;
          return coords;
        }
      }
    } catch (_) {}
    final cached = _polylineCache[cacheKey];
    if (cached != null && cached.isNotEmpty) return cached;
    return _straightLine(from, to);
  }

  void clearCacheForHalte(LatLng haltePos) {
    // Hapus semua cache key yang memiliki destination halte ini
    final toSuffix =
        '${haltePos.latitude.toStringAsFixed(5)},${haltePos.longitude.toStringAsFixed(5)}';
    _polylineCache.removeWhere((key, _) => key.contains('->$toSuffix'));
    _lastRequestTime.removeWhere((key, _) => key.contains('->$toSuffix'));
    _lastFromPos = null;
  }

  int getNextHalteIndex({
    required LatLng driverPos,
    required List<RouteHalteModel> haltes,
    required int currentIndex,
  }) {
    if (currentIndex < haltes.length) {
      final halte = haltes[currentIndex].halte;
      if (halte != null) {
        final target = LatLng(halte.latitude, halte.longitude);
        final dist = _distance.as(LengthUnit.Meter, driverPos, target);
        if (dist <= _haltePassThreshold) {
          return currentIndex + 1 < haltes.length
              ? currentIndex + 1
              : currentIndex;
        }
      }
    }
    return currentIndex;
  }

  double distanceToHalte({
    required LatLng driverPos,
    required HalteModel halte,
  }) {
    return _distance.as(
      LengthUnit.Meter,
      driverPos,
      LatLng(halte.latitude, halte.longitude),
    );
  }

  List<LatLng> _straightLine(LatLng from, LatLng to) => [from, to];
}
