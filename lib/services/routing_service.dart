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

  /// Ambil polyline navigasi dari posisi driver ke halte target
  /// menggunakan OSRM routing engine
  Future<List<LatLng>> getNavigationRoute({
    required LatLng from,
    required LatLng to,
  }) async {
    try {
      final url =
          '$_osrmBase/${from.longitude},${from.latitude};${to.longitude},${to.latitude}'
          '?overview=full&geometries=geojson';

      final res =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));

      if (res.statusCode != 200) return _straightLine(from, to);

      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final routes = json['routes'] as List?;
      if (routes == null || routes.isEmpty) return _straightLine(from, to);

      final coords = (routes[0]['geometry']['coordinates'] as List)
          .map(
              (c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
          .toList();

      return coords;
    } catch (_) {
      // Fallback: garis lurus jika API tidak tersedia
      return _straightLine(from, to);
    }
  }

  /// Cari halte tujuan berikutnya berdasarkan posisi driver
  /// Returns index halte yang belum dilewati
  int getNextHalteIndex({
    required LatLng driverPos,
    required List<RouteHalteModel> haltes,
    required int currentIndex,
  }) {
    // Cek apakah driver sudah cukup dekat dengan halte saat ini
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
