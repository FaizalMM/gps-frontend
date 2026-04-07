import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:geolocator/geolocator.dart';
import '../../utils/app_theme.dart';
import '../../services/route_search_service.dart';

class PickedLocation {
  final double latitude;
  final double longitude;
  final String? namaAlamat; // nama jalan/tempat dari reverse geocode
  const PickedLocation(this.latitude, this.longitude, {this.namaAlamat});
}

/// Full-screen map picker untuk menentukan koordinat halte secara akurat.
/// Fitur:
/// 1. Cari alamat/tempat (Nominatim)
/// 2. Tap peta untuk pilih titik
/// 3. Tombol GPS → langsung ke posisi saat ini
/// 4. Reverse geocode → tampilkan nama jalan setelah pilih titik
/// 5. Zoom tinggi default (18) agar presisi
/// 6. Crosshair di tengah peta (alternatif tap)
class HalteLocationPicker extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;
  const HalteLocationPicker({super.key, this.initialLat, this.initialLng});

  @override
  State<HalteLocationPicker> createState() => _HalteLocationPickerState();
}

class _HalteLocationPickerState extends State<HalteLocationPicker> {
  final _mapCtrl = MapController();
  final _svc = RouteSearchService();
  final _searchCtrl = TextEditingController();

  LatLng? _picked;
  String? _namaAlamat; // dari reverse geocode
  bool _loadingGps = false;
  bool _loadingAddr = false;
  bool _showSearch = false;
  List<LocationSearchResult> _searchResults = [];
  bool _searching = false;
  Timer? _debounce;

  static const _defaultCenter = LatLng(-7.6298, 111.5239); // Madiun

  @override
  void initState() {
    super.initState();
    if (widget.initialLat != null && widget.initialLng != null) {
      _picked = LatLng(widget.initialLat!, widget.initialLng!);
      // Ambil nama alamat dari koordinat awal
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _reverseGeocode(_picked!);
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _mapCtrl.dispose();
    super.dispose();
  }

  LatLng get _center => _picked ?? _defaultCenter;

  // ── Pilih titik dari tap peta ────────────────────────────
  Future<void> _onTap(TapPosition _, LatLng point) async {
    setState(() {
      _picked = point;
      _namaAlamat = null;
      _showSearch = false;
    });
    await _reverseGeocode(point);
  }

  // ── Pakai tengah peta sebagai titik (tombol crosshair) ───
  Future<void> _useCenterPoint() async {
    final center = _mapCtrl.camera.center;
    setState(() {
      _picked = center;
      _namaAlamat = null;
    });
    await _reverseGeocode(center);
  }

  // ── Reverse geocode: koordinat → nama jalan ──────────────
  Future<void> _reverseGeocode(LatLng point) async {
    setState(() => _loadingAddr = true);
    final nama = await _svc.reverseGeocode(point.latitude, point.longitude);
    if (!mounted) return;
    setState(() {
      _namaAlamat = nama;
      _loadingAddr = false;
    });
  }

  // ── GPS: pergi ke posisi saat ini ────────────────────────
  Future<void> _goToMyLocation() async {
    setState(() => _loadingGps = true);
    try {
      bool enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        _snack('Aktifkan layanan GPS di perangkat');
        return;
      }

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        _snack('Izin lokasi diperlukan');
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
          locationSettings:
              const LocationSettings(accuracy: LocationAccuracy.high));
      final loc = LatLng(pos.latitude, pos.longitude);

      setState(() {
        _picked = loc;
        _namaAlamat = null;
      });
      _mapCtrl.move(loc, 19.0); // zoom sangat tinggi untuk presisi
      await _reverseGeocode(loc);
    } catch (_) {
      _snack('Gagal mendapatkan lokasi GPS');
    } finally {
      if (mounted) setState(() => _loadingGps = false);
    }
  }

  // ── Cari alamat (debounce 600ms) ─────────────────────────
  void _onSearchChanged(String q) {
    _debounce?.cancel();
    if (q.trim().length < 3) {
      setState(() => _searchResults = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 600), () async {
      setState(() => _searching = true);
      final results = await _svc.searchLocation(q);
      if (!mounted) return;
      setState(() {
        _searchResults = results;
        _searching = false;
      });
    });
  }

  // ── Pilih hasil pencarian ─────────────────────────────────
  Future<void> _selectSearchResult(LocationSearchResult r) async {
    final loc = LatLng(r.latitude, r.longitude);
    setState(() {
      _picked = loc;
      _namaAlamat = r.shortName;
      _showSearch = false;
      _searchResults = [];
      _searchCtrl.clear();
    });
    _mapCtrl.move(loc, 19.0);
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Poppins')),
      backgroundColor: AppColors.textGrey,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        // ── PETA ─────────────────────────────────────────────
        FlutterMap(
          mapController: _mapCtrl,
          options: MapOptions(
            initialCenter: _center,
            initialZoom: _picked != null ? 19.0 : 15.0,
            onTap: _onTap,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.mobitra.app',
              maxZoom: 19,
            ),
            if (_picked != null)
              MarkerLayer(markers: [
                Marker(
                  point: _picked!,
                  width: 48,
                  height: 58,
                  alignment: Alignment.topCenter,
                  child: _PinMarker(),
                ),
              ]),
          ],
        ),

        // ── CROSSHAIR tengah peta ─────────────────────────────
        const Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(height: 0),
            Icon(Icons.add, size: 24, color: Colors.black54),
          ]),
        ),

        // ── HEADER: tombol kembali + search bar ───────────────
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Column(children: [
                Row(children: [
                  // Tombol kembali
                  _BtnBundar(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onTap: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 10),
                  // Search bar
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _showSearch = true),
                      child: Container(
                        height: 46,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 10,
                                offset: const Offset(0, 3))
                          ],
                        ),
                        child: Row(children: [
                          Icon(Icons.search_rounded,
                              size: 18,
                              color: _showSearch
                                  ? AppColors.primary
                                  : AppColors.textGrey),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _showSearch
                                ? TextField(
                                    controller: _searchCtrl,
                                    autofocus: true,
                                    onChanged: _onSearchChanged,
                                    style: const TextStyle(
                                        fontFamily: 'Poppins', fontSize: 13),
                                    decoration: const InputDecoration(
                                      hintText: 'Cari nama jalan, tempat...',
                                      hintStyle: TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 13,
                                          color: AppColors.textGrey),
                                      border: InputBorder.none,
                                      isDense: true,
                                    ),
                                  )
                                : Text(
                                    'Cari nama jalan atau tempat...',
                                    style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 13,
                                        color: AppColors.textGrey
                                            .withValues(alpha: 0.7)),
                                  ),
                          ),
                          if (_showSearch && _searchCtrl.text.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                _searchCtrl.clear();
                                setState(() => _searchResults = []);
                              },
                              child: const Icon(Icons.close_rounded,
                                  size: 16, color: AppColors.textGrey),
                            ),
                          if (_searching)
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppColors.primary),
                            ),
                        ]),
                      ),
                    ),
                  ),
                ]),

                // Hasil pencarian
                if (_showSearch && _searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 10,
                            offset: const Offset(0, 4))
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: _searchResults
                          .take(5)
                          .map((r) => InkWell(
                                onTap: () => _selectSearchResult(r),
                                borderRadius: BorderRadius.circular(14),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 12),
                                  child: Row(children: [
                                    const Icon(Icons.place_rounded,
                                        size: 16, color: AppColors.primary),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(r.shortName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                  fontFamily: 'Poppins',
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600)),
                                          Text(r.displayName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                  fontFamily: 'Poppins',
                                                  fontSize: 11,
                                                  color: AppColors.textGrey)),
                                        ],
                                      ),
                                    ),
                                  ]),
                                ),
                              ))
                          .toList(),
                    ),
                  ),

                // Tutup search kalau tap di luar
                if (_showSearch && _searchResults.isEmpty && !_searching)
                  const SizedBox.shrink(),
              ]),
            ),
          ),
        ),

        // ── Tombol crosshair (pakai tengah peta) ─────────────
        Positioned(
          right: 16,
          bottom: _picked != null ? 220 : 100,
          child: Column(children: [
            // GPS
            _BtnBundar(
              icon: _loadingGps
                  ? Icons.hourglass_empty_rounded
                  : Icons.my_location_rounded,
              warna: AppColors.primary,
              onTap: _loadingGps ? null : _goToMyLocation,
            ),
            const SizedBox(height: 10),
            // Pakai tengah peta
            Tooltip(
              message: 'Pakai titik tengah peta',
              child: _BtnBundar(
                icon: Icons.gps_fixed_rounded,
                onTap: _useCenterPoint,
              ),
            ),
          ]),
        ),

        // ── Panel bawah: info koordinat + konfirmasi ──────────
        if (_picked != null && !_showSearch)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(22)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 16,
                      offset: const Offset(0, -4))
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                            color: AppColors.lightGrey,
                            borderRadius: BorderRadius.circular(2))),
                  ),
                  const SizedBox(height: 14),

                  // Nama alamat dari reverse geocode
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on_rounded,
                          color: AppColors.primary, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _loadingAddr
                            ? const Text('Mencari nama lokasi...',
                                style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 13,
                                    color: AppColors.textGrey,
                                    fontStyle: FontStyle.italic))
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _namaAlamat ?? 'Lokasi dipilih',
                                    style: const TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.black),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${_picked!.latitude.toStringAsFixed(7)}, '
                                    '${_picked!.longitude.toStringAsFixed(7)}',
                                    style: const TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 11,
                                        color: AppColors.textGrey,
                                        fontFeatures: [
                                          FontFeature.tabularFigures()
                                        ]),
                                  ),
                                ],
                              ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Hint presisi
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surface2,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(children: [
                      Icon(Icons.info_outline_rounded,
                          size: 13, color: AppColors.textGrey),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Tap peta untuk sesuaikan titik. Zoom lebih dekat = lebih presisi.',
                          style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11,
                              color: AppColors.textGrey),
                        ),
                      ),
                    ]),
                  ),

                  const SizedBox(height: 14),

                  // Tombol konfirmasi
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(
                          context,
                          PickedLocation(
                            _picked!.latitude,
                            _picked!.longitude,
                            namaAlamat: _namaAlamat,
                          )),
                      icon: const Icon(Icons.check_circle_rounded, size: 20),
                      label: const Text('Gunakan Lokasi Ini',
                          style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // ── Instruksi awal kalau belum pilih titik ────────────
        if (_picked == null && !_showSearch)
          Positioned(
            bottom: 24,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(children: [
                    Icon(Icons.touch_app_rounded,
                        color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text('Tap peta untuk pilih lokasi halte',
                          style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13,
                              color: Colors.white,
                              fontWeight: FontWeight.w600)),
                    ),
                  ]),
                  SizedBox(height: 6),
                  Row(children: [
                    Icon(Icons.search_rounded, color: Colors.white70, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text('Atau cari nama jalan/tempat di atas',
                          style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11,
                              color: Colors.white70)),
                    ),
                  ]),
                  SizedBox(height: 6),
                  Row(children: [
                    Icon(Icons.my_location_rounded,
                        color: Colors.white70, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text('Tombol biru = lokasi GPS kamu sekarang',
                          style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11,
                              color: Colors.white70)),
                    ),
                  ]),
                ],
              ),
            ),
          ),

        // ── Tutup search saat tap di luar ─────────────────────
        if (_showSearch)
          Positioned.fill(
            child: GestureDetector(
              onTap: () => setState(() {
                _showSearch = false;
                _searchResults = [];
              }),
              behavior: HitTestBehavior.translucent,
              child: const SizedBox.expand(),
            ),
          ),
      ]),
    );
  }
}

// ── Widget helpers ────────────────────────────────────────────

class _PinMarker extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.5),
                  blurRadius: 12,
                  offset: const Offset(0, 4))
            ],
          ),
          child: const Icon(Icons.location_on_rounded,
              color: Colors.white, size: 22),
        ),
        CustomPaint(size: const Size(14, 10), painter: _PinTail()),
      ],
    );
  }
}

class _PinTail extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(size.width / 2, size.height)
        ..lineTo(size.width, 0)
        ..close(),
      Paint()..color = AppColors.primary,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}

class _BtnBundar extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color? warna;
  const _BtnBundar({required this.icon, this.onTap, this.warna});

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
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 10,
                offset: const Offset(0, 3))
          ],
        ),
        child: Icon(icon,
            color: onTap != null
                ? (warna ?? AppColors.black)
                : AppColors.lightGrey,
            size: 20),
      ),
    );
  }
}
