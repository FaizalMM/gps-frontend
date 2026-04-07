import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

// ─────────────────────────────────────────────────────────────
// Model hasil pencarian lokasi (Nominatim)
// ─────────────────────────────────────────────────────────────
class LocationSearchResult {
  final String displayName;
  final String shortName;
  final double latitude;
  final double longitude;

  const LocationSearchResult({
    required this.displayName,
    required this.shortName,
    required this.latitude,
    required this.longitude,
  });

  LatLng get latLng => LatLng(latitude, longitude);
}

// ─────────────────────────────────────────────────────────────
// Model hasil routing (OSRM)
// ─────────────────────────────────────────────────────────────
class OsrmRouteResult {
  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;

  const OsrmRouteResult({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  String get distanceLabel {
    if (distanceMeters >= 1000) {
      return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
    }
    return '${distanceMeters.round()} m';
  }

  String get durationLabel {
    final m = (durationSeconds / 60).round();
    if (m >= 60) return '${m ~/ 60}j ${m % 60}m';
    return '${m}m';
  }
}

// ─────────────────────────────────────────────────────────────
// RouteSearchService
// Geocoding: Nominatim (openstreetmap) — gratis, tanpa API key
// Routing:   OSRM public server       — gratis, tanpa API key
// ─────────────────────────────────────────────────────────────
class RouteSearchService {
  static const _nominatim = 'https://nominatim.openstreetmap.org';
  static const _osrm = 'https://router.project-osrm.org';

  // Bias default ke area Madiun, Jawa Timur
  static const double _biasLat = -7.6298;
  static const double _biasLng = 111.5239;

  static const Map<String, String> _headers = {
    'User-Agent': 'MOBITRA-App/1.0',
    'Accept-Language': 'id,en',
  };

  // ── Cari lokasi berdasarkan query teks ─────────────────────
  Future<List<LocationSearchResult>> searchLocation(String query) async {
    if (query.trim().isEmpty) return [];
    try {
      final uri = Uri.parse('$_nominatim/search').replace(
        queryParameters: {
          'q': '$query, Jawa Timur, Indonesia',
          'format': 'json',
          'limit': '6',
          'addressdetails': '1',
          'countrycodes': 'id',
          'lat': '$_biasLat',
          'lon': '$_biasLng',
        },
      );
      final res = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return [];

      final List<dynamic> data = json.decode(res.body);
      return data.map((item) {
        final addr = item['address'] as Map<String, dynamic>? ?? {};
        final parts = <String>[];
        for (final key in [
          'road',
          'suburb',
          'village',
          'city_district',
          'city',
          'county'
        ]) {
          if (addr[key] != null) parts.add(addr[key] as String);
          if (parts.length >= 2) break;
        }
        final short = parts.isNotEmpty
            ? parts.join(', ')
            : (item['display_name'] as String).split(',').first.trim();
        return LocationSearchResult(
          displayName: item['display_name'] as String,
          shortName: short,
          latitude: double.parse(item['lat'] as String),
          longitude: double.parse(item['lon'] as String),
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  // ── Reverse geocode: koordinat → nama tempat ───────────────
  Future<String?> reverseGeocode(double lat, double lng) async {
    try {
      final uri = Uri.parse('$_nominatim/reverse').replace(
        queryParameters: {
          'lat': lat.toString(),
          'lon': lng.toString(),
          'format': 'json',
          'zoom': '16',
          'addressdetails': '1',
        },
      );
      final res = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return null;
      final data = json.decode(res.body) as Map<String, dynamic>;
      final addr = data['address'] as Map<String, dynamic>? ?? {};
      final parts = <String>[];
      for (final key in ['road', 'suburb', 'city_district', 'city']) {
        if (addr[key] != null) parts.add(addr[key] as String);
        if (parts.length >= 2) break;
      }
      return parts.isNotEmpty
          ? parts.join(', ')
          : (data['display_name'] as String?)?.split(',').first.trim();
    } catch (_) {
      return null;
    }
  }

  // ── Routing via OSRM (jalur mengikuti jalan) ───────────────
  // [waypoints] = titik awal, halte-halte, titik akhir
  Future<OsrmRouteResult?> getRoute(List<LatLng> waypoints) async {
    if (waypoints.length < 2) return null;
    try {
      final coords =
          waypoints.map((p) => '${p.longitude},${p.latitude}').join(';');
      final uri = Uri.parse(
        '$_osrm/route/v1/driving/$coords'
        '?overview=full&geometries=geojson&steps=false',
      );
      final res = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return null;

      final body = json.decode(res.body) as Map<String, dynamic>;
      if (body['code'] != 'Ok') return null;

      final route = (body['routes'] as List).first as Map<String, dynamic>;
      final geom = route['geometry'] as Map<String, dynamic>;
      final coordList = (geom['coordinates'] as List).cast<List<dynamic>>();

      return OsrmRouteResult(
        points: coordList
            .map((c) => LatLng(
                  (c[1] as num).toDouble(),
                  (c[0] as num).toDouble(),
                ))
            .toList(),
        distanceMeters: (route['distance'] as num).toDouble(),
        durationSeconds: (route['duration'] as num).toDouble(),
      );
    } catch (_) {
      return null;
    }
  }
}
