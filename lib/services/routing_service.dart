import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../models/models_api.dart';

class RoutingService {
  static final RoutingService _instance = RoutingService._internal();
  factory RoutingService() => _instance;
  RoutingService._internal();

  // OSRM public routing API — gratis, tidak butuh API key
  static const String _osrmBase =
      'http://router.project-osrm.org/route/v1/driving';

  // Jarak (meter) untuk dianggap "sudah melewati" halte
  static const double _haltePassThreshold = 80.0;

  final _distance = const Distance();

  // Cache polyline terakhir per halte tujuan
  final Map<String, List<LatLng>> _polylineCache = {};
  // Throttle: timestamp request terakhir per halte tujuan
  final Map<String, DateTime> _lastRequestTime = {};
  // Minimum jeda antar request OSRM ke halte yang sama (detik)
  static const int _requestThrottleSeconds = 5;

  /// Ambil polyline navigasi dari posisi driver ke halte target.
  /// - Hasil di-cache per halte tujuan agar rute tidak hilang saat request gagal
  /// - Throttle request agar tidak spam OSRM setiap detik GPS update
  /// - Jika OSRM gagal/timeout: kembalikan cache terakhir (rute tetap tampil)
  Future<List<LatLng>> getNavigationRoute({
    required LatLng from,
    required LatLng to,
  }) async {
    final cacheKey =
        '${to.latitude.toStringAsFixed(5)},${to.longitude.toStringAsFixed(5)}';
    final now = DateTime.now();
    final lastRequest = _lastRequestTime[cacheKey];

    // Throttle: jika baru request ke halte ini < 5 detik lalu, pakai cache
    if (lastRequest != null &&
        now.difference(lastRequest).inSeconds < _requestThrottleSeconds) {
      final cached = _polylineCache[cacheKey];
      if (cached != null && cached.isNotEmpty) return cached;
    }

    try {
      final url =
          '$_osrmBase/${from.longitude},${from.latitude};${to.longitude},${to.latitude}'
          '?overview=full&geometries=geojson';

      final res =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));

      _lastRequestTime[cacheKey] = now;

      if (res.statusCode != 200) {
        // Request gagal → kembalikan cache agar rute tidak hilang
        final cached = _polylineCache[cacheKey];
        if (cached != null && cached.isNotEmpty) return cached;
        return _straightLine(from, to);
      }

      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final routes = json['routes'] as List?;
      if (routes == null || routes.isEmpty) {
        final cached = _polylineCache[cacheKey];
        if (cached != null && cached.isNotEmpty) return cached;
        return _straightLine(from, to);
      }

      final coords = (routes[0]['geometry']['coordinates'] as List)
          .map(
              (c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
          .toList();

      // Simpan ke cache
      _polylineCache[cacheKey] = coords;
      return coords;
    } catch (_) {
      // Network error / timeout → kembalikan cache terakhir jika ada
      final cached = _polylineCache[cacheKey];
      if (cached != null && cached.isNotEmpty) return cached;
      return _straightLine(from, to);
    }
  }

  /// Hapus cache saat driver pindah ke halte berikutnya
  void clearCacheForHalte(LatLng haltePos) {
    final key =
        '${haltePos.latitude.toStringAsFixed(5)},${haltePos.longitude.toStringAsFixed(5)}';
    _polylineCache.remove(key);
    _lastRequestTime.remove(key);
  }

  /// Cari halte tujuan berikutnya berdasarkan posisi driver.
  /// Returns index halte yang belum dilewati.
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
          // Sudah melewati halte ini → lanjut ke berikutnya
          return currentIndex + 1 < haltes.length
              ? currentIndex + 1
              : currentIndex;
        }
      }
    }
    return currentIndex;
  }

  /// Hitung jarak driver ke halte target (meter)
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

  /// Fallback: garis lurus dari A ke B
  List<LatLng> _straightLine(LatLng from, LatLng to) => [from, to];
}
