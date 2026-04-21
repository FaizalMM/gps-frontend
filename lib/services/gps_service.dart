import 'dart:async';
import 'dart:io';
import 'package:geolocator/geolocator.dart';
import 'api_client.dart';
import 'domain_services.dart';

class GpsService {
  static final GpsService _instance = GpsService._internal();
  factory GpsService() => _instance;
  GpsService._internal();

  final _driverService = DriverService();
  StreamSubscription<Position>? _positionStream;
  Timer? _heartbeatTimer;
  bool _isTracking = false;
  bool get isTracking => _isTracking;

  Position? _lastPosition;
  Position? get lastPosition => _lastPosition;

  // Ambang akurasi — data GPS lebih buruk dari ini diabaikan
  static const double _maxAccuracyMeters = 50.0;

  final _positionController = StreamController<Position>.broadcast();
  Stream<Position> get positionStream => _positionController.stream;

  Future<bool> requestPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission != LocationPermission.denied &&
        permission != LocationPermission.deniedForever;
  }

  bool _isValidPosition(Position p) {
    // Filter posisi tidak valid:
    // - Koordinat 0,0 (default GPS belum lock)
    // - Akurasi > 50m (sinyal lemah)
    // - Speed negatif (geolocator return -1 jika tidak tersedia)
    if (p.latitude == 0 && p.longitude == 0) return false;
    if (p.accuracy > _maxAccuracyMeters) return false;
    return true;
  }

  Future<void> _sendPosition(Position position) async {
    await _driverService.sendGpsLocation(
      latitude: position.latitude,
      longitude: position.longitude,
      speed: position.speed < 0 ? 0 : position.speed * 3.6, // m/s → km/h
      accuracy: position.accuracy,
      heading: position.heading >= 0 ? position.heading : null,
      deviceTimestamp: position.timestamp.millisecondsSinceEpoch,
    );
  }

  /// Mulai tracking GPS dengan pengaturan platform optimal
  Future<bool> startTracking() async {
    if (_isTracking) return true;
    if (!await requestPermission()) return false;
    _isTracking = true;

    await _driverService.toggleGps('on');

    // Platform-specific settings untuk akurasi maksimal
    final LocationSettings locationSettings;
    if (Platform.isAndroid) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // update setiap 5m (lebih sering dari 10m)
        intervalDuration: const Duration(seconds: 3), // minimal setiap 3 detik
        forceLocationManager:
            false, // pakai Google Fused Location (lebih akurat)
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Mobitra GPS',
          notificationText: 'Sedang memantau lokasi bus',
          enableWakeLock: true, // jaga agar tracking tidak mati saat layar off
        ),
      );
    } else if (Platform.isIOS) {
      locationSettings = AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
        activityType:
            ActivityType.automotiveNavigation, // optimasi untuk kendaraan
        pauseLocationUpdatesAutomatically: false, // jangan pause saat diam
        allowBackgroundLocationUpdates: true,
        showBackgroundLocationIndicator: true,
      );
    } else {
      locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      );
    }

    _positionStream = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((position) async {
      // Filter posisi tidak valid sebelum dikirim
      if (!_isValidPosition(position)) return;

      _lastPosition = position;
      _positionController.add(position);
      await _sendPosition(position);
    });

    // Heartbeat setiap 90 detik — kirim posisi terakhir agar last_gps_update fresh
    // Threshold stale di backend adalah 10 menit, jadi 90 detik memberikan
    // margin aman yang cukup bahkan saat koneksi lambat atau bus sedang diam
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 90), (_) async {
      if (!_isTracking) return;
      final pos = _lastPosition ?? await getCurrentPosition();
      if (pos != null && _isValidPosition(pos)) {
        await _sendPosition(pos);
      }
    });

    return true;
  }

  Future<void> stopTracking() async {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    await _positionStream?.cancel();
    _positionStream = null;
    _isTracking = false;

    try {
      final token = await ApiClient().getToken();
      if (token != null) {
        await _driverService.toggleGps('off');
      }
    } catch (_) {}

    // Emit posisi kosong agar UI tahu tracking sudah stop
    _positionController.add(Position(
      latitude: 0,
      longitude: 0,
      timestamp: DateTime.now(),
      accuracy: 0,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    ));
  }

  /// Kirim posisi saat ini (sekali) — saat GPS baru diaktifkan
  Future<bool> sendCurrentPosition(Position position) async {
    if (!_isValidPosition(position)) return false;
    await _sendPosition(position);
    return true;
  }

  /// Ambil posisi sekali (untuk QR scan, init, dll)
  /// Strategi berlapis agar tidak mudah gagal:
  /// 1. Coba high accuracy (15 detik)
  /// 2. Kalau gagal/tidak akurat, fallback ke medium accuracy (10 detik)
  /// 3. Kalau masih gagal, pakai lastPosition dari tracking aktif (kalau ada)
  Future<Position?> getCurrentPosition() async {
    if (!await requestPermission()) return null;

    // Coba high accuracy dulu
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 15),
        ),
      );
      if (pos.latitude != 0 && pos.longitude != 0) return pos;
    } catch (_) {}

    // Fallback: medium accuracy dengan timeout lebih longgar
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 10),
        ),
      );
      if (pos.latitude != 0 && pos.longitude != 0) return pos;
    } catch (_) {}

    // Fallback terakhir: pakai posisi terakhir dari tracking aktif
    // (berguna saat GPS driver sedang hangat dan siswa mau scan QR)
    if (_lastPosition != null &&
        _lastPosition!.latitude != 0 &&
        _lastPosition!.longitude != 0) {
      return _lastPosition;
    }

    return null;
  }

  void dispose() {
    _heartbeatTimer?.cancel();
    _positionStream?.cancel();
    _positionController.close();
  }
}
