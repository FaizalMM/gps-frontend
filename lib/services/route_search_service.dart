import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

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

class RouteSearchService {
  static const _nominatim = 'https://nominatim.openstreetmap.org';
  // driving-hgv = Heavy Goods Vehicle profile → prioritas jalan besar,
  // hindari gang sempit & jalan bertonase rendah. Cocok untuk rute bus.
  static const _osrmHgv =
      'https://router.project-osrm.org/route/v1/driving-hgv';
  static const _osrm = 'https://router.project-osrm.org';

  // Bias default ke area Madiun, Jawa Timur
  static const double _biasLat = -7.6298;
  static const double _biasLng = 111.5239;

  static const Map<String, String> _headers = {
    'User-Agent': 'MOBITRA-App/1.0',
    'Accept-Language': 'id,en',
  };

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

  Future<OsrmRouteResult?> getRoute(List<LatLng> waypoints) async {
    if (waypoints.length < 2) return null;

    // Strategi utama: gunakan segmentasi pairwise (lebih detail daripada global)
    try {
      // ignore: avoid_print
      print('Starting segmented routing for ${waypoints.length} waypoints');
    } catch (_) {}

    final segPoints = <LatLng>[];
    double totalDist = 0;
    double totalDur = 0;

    for (int i = 0; i < waypoints.length - 1; i++) {
      final a = waypoints[i];
      final b = waypoints[i + 1];
      try {
        // ignore: avoid_print
        print(
            'Routing segment $i: ${a.latitude.toStringAsFixed(4)},${a.longitude.toStringAsFixed(4)} → ${b.latitude.toStringAsFixed(4)},${b.longitude.toStringAsFixed(4)}');
      } catch (_) {}

      final seg = await _routePair(a, b);
      if (seg != null && seg.points.isNotEmpty) {
        // Avoid duplicate: skip first point if segPoints not empty
        if (segPoints.isNotEmpty) {
          segPoints.addAll(seg.points.sublist(1));
        } else {
          segPoints.addAll(seg.points);
        }
        totalDist += seg.distanceMeters;
        totalDur += seg.durationSeconds;
        try {
          // ignore: avoid_print
          print(
              '  Segment $i: ${seg.points.length} points, ${seg.distanceMeters.toStringAsFixed(0)}m');
        } catch (_) {}
      } else {
        try {
          // ignore: avoid_print
          print('  Segment $i: FAILED (returning null)');
        } catch (_) {}
      }
    }

    if (segPoints.isNotEmpty) {
      try {
        // ignore: avoid_print
        print(
            'Segmented routing complete: ${segPoints.length} total points, ${totalDist.toStringAsFixed(0)}m');
      } catch (_) {}
      return OsrmRouteResult(
        points: segPoints,
        distanceMeters: totalDist,
        durationSeconds: totalDur,
      );
    }

    try {
      // ignore: avoid_print
      print('Segmented routing failed, returning null');
    } catch (_) {}
    return null;
  }

  // Route between two consecutive points using HGV then driving fallback.
  // Hindari jalan kecil/buntu dengan menggunakan profile HGV & exclude residential.
  Future<OsrmRouteResult?> _routePair(LatLng a, LatLng b) async {
    try {
      // Gunakan hanya 2 titik (start & end) tanpa intermediate.
      // Intermediate waypoints kadang malah membuat rute ambil jalan buntu.
      final coords =
          '${a.longitude},${a.latitude};${b.longitude},${b.latitude}';

      try {
        // ignore: avoid_print
        print('    _routePair: $coords');
      } catch (_) {}

      // OSRM HGV profile: prioritas jalan besar, hindari gang sempit (cocok untuk bus)
      var uri = Uri.parse(
        '$_osrmHgv/$coords?overview=full&geometries=geojson&steps=false',
      );
      var res = await http.get(uri, headers: _headers).timeout(
            const Duration(seconds: 10),
          );

      // Jika HGV gagal, fallback ke driving biasa
      if (res.statusCode != 200) {
        try {
          // ignore: avoid_print
          print(
              '    _routePair: HGV failed (${res.statusCode}), trying driving...');
        } catch (_) {}

        uri = Uri.parse(
            '$_osrm/route/v1/driving/$coords?overview=full&geometries=geojson&steps=false');
        res = await http.get(uri, headers: _headers).timeout(
              const Duration(seconds: 10),
            );
        if (res.statusCode != 200) {
          try {
            // ignore: avoid_print
            print('    _routePair: driving also failed (${res.statusCode})');
          } catch (_) {}
          return null;
        }
      }

      final body = json.decode(res.body) as Map<String, dynamic>;
      if (body['code'] != 'Ok') {
        try {
          // ignore: avoid_print
          print('    _routePair: OSRM code ${body['code']}');
        } catch (_) {}
        return null;
      }

      final route = (body['routes'] as List).first as Map<String, dynamic>;
      final geom = route['geometry'] as Map<String, dynamic>;
      final coordList = (geom['coordinates'] as List).cast<List<dynamic>>();

      if (coordList.isEmpty) {
        try {
          // ignore: avoid_print
          print('    _routePair: empty coordList');
        } catch (_) {}
        return null;
      }

      final pts = coordList
          .map(
              (c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
          .toList();

      try {
        // ignore: avoid_print
        print('    _routePair result: ${pts.length} points');
      } catch (_) {}

      return OsrmRouteResult(
        points: pts,
        distanceMeters: (route['distance'] as num).toDouble(),
        durationSeconds: (route['duration'] as num).toDouble(),
      );
    } catch (e) {
      try {
        // ignore: avoid_print
        print('    _routePair exception: $e');
      } catch (_) {}
      return null;
    }
  }
}
