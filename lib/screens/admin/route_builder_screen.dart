import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:geolocator/geolocator.dart';
import '../../models/models_api.dart';
import '../../utils/app_theme.dart';
import '../../services/route_search_service.dart';
import '../../services/domain_services.dart';

class RouteBuilderResult {
  final List<LatLng> polylinePoints;
  final List<HalteModel> orderedHaltes;
  final String routeName;
  final double distanceMeters;
  final double durationSeconds;

  const RouteBuilderResult({
    required this.polylinePoints,
    required this.orderedHaltes,
    required this.routeName,
    required this.distanceMeters,
    required this.durationSeconds,
  });
}

class RouteBuilderScreen extends StatefulWidget {
  final List<HalteModel> availableHaltes;
  final String? initialName;
  final List<LatLng>? initialPoints;

  const RouteBuilderScreen({
    super.key,
    required this.availableHaltes,
    this.initialName,
    this.initialPoints,
  });

  @override
  State<RouteBuilderScreen> createState() => _RouteBuilderScreenState();
}

class _RouteBuilderScreenState extends State<RouteBuilderScreen>
    with TickerProviderStateMixin {
  final _mapCtrl = MapController();
  final _svc = RouteSearchService();
  final _halteSvc = HalteService();
  final _searchCtrl = TextEditingController();

  final List<HalteModel> _waypoints = [];
  late List<HalteModel> _allHaltes;

  List<LatLng> _routePolyline = [];
  bool _routing = false;
  double _distM = 0;
  double _durS = 0;

  bool _showHalteList = false;
  String _searchQuery = '';
  bool _savingHalte = false;

  static const _defaultCenter = LatLng(-7.6298, 111.5239);

  @override
  void initState() {
    super.initState();
    _allHaltes = List.from(widget.availableHaltes);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialPoints != null && widget.initialPoints!.length >= 2) {
        _fitBounds(widget.initialPoints!);
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _mapCtrl.dispose();
    super.dispose();
  }

  void _addWaypoint(HalteModel h) {
    if (_waypoints.any((w) => w.id == h.id)) return;
    setState(() {
      _waypoints.add(h);
      _routePolyline = [];
      _distM = 0;
      _durS = 0;
      _showHalteList = false;
    });
    _mapCtrl.move(LatLng(h.latitude, h.longitude), 14.5);
    if (_waypoints.length >= 2) _calcRoute();
  }

  void _removeWaypoint(int idx) {
    setState(() {
      _waypoints.removeAt(idx);
      _routePolyline = [];
      _distM = 0;
      _durS = 0;
    });
    if (_waypoints.length >= 2) _calcRoute();
  }

  void _reorderWaypoints(int oldIdx, int newIdx) {
    setState(() {
      if (newIdx > oldIdx) newIdx--;
      final h = _waypoints.removeAt(oldIdx);
      _waypoints.insert(newIdx, h);
      _routePolyline = [];
      _distM = 0;
      _durS = 0;
    });
    if (_waypoints.length >= 2) _calcRoute();
  }

  Future<void> _calcRoute() async {
    if (_waypoints.length < 2) return;
    setState(() => _routing = true);
    final pts = _waypoints.map((h) => LatLng(h.latitude, h.longitude)).toList();
    final result = await _svc.getRoute(pts);
    if (!mounted) return;
    setState(() {
      _routing = false;
      if (result != null) {
        _routePolyline = result.points;
        _distM = result.distanceMeters;
        _durS = result.durationSeconds;
      } else {
        _routePolyline = pts;
      }
    });
    if (_routePolyline.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) =>
          _fitBounds(_routePolyline, bottomPad: _showHalteList ? 400 : 320));
    }
  }

  void _fitBounds(List<LatLng> pts, {double bottomPad = 280}) {
    if (pts.isEmpty) return;
    if (pts.length == 1) {
      _mapCtrl.move(pts.first, 14);
      return;
    }
    _mapCtrl.fitCamera(CameraFit.bounds(
      bounds: LatLngBounds.fromPoints(pts),
      padding: EdgeInsets.fromLTRB(48, 110, 48, bottomPad),
    ));
  }

  Future<void> _buatHalteBaru() async {
    final namaCtrl = TextEditingController();
    final alamatCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final picked = _mapCtrl.camera.center;

    final result = await showModalBottomSheet<HalteModel?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
          child: Form(
            key: formKey,
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
                            borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 18),
                const Text('Buat Halte Baru',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                const Text(
                    'Koordinat diambil dari tengah peta. Geser peta ke lokasi halte sebelum membuka form ini.',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        color: AppColors.textGrey)),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.primary),
                  ),
                  child: Row(children: [
                    const Icon(Icons.my_location_rounded,
                        size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(
                      '${picked.latitude.toStringAsFixed(6)}, ${picked.longitude.toStringAsFixed(6)}',
                      style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary),
                    )),
                  ]),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: namaCtrl,
                  autofocus: true,
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Nama Halte *',
                    hintText: 'cth: Halte Pasar Besar',
                    labelStyle:
                        const TextStyle(fontFamily: 'Poppins', fontSize: 13),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 14),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Nama wajib diisi' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: alamatCtrl,
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Alamat (opsional)',
                    labelStyle:
                        const TextStyle(fontFamily: 'Poppins', fontSize: 13),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 14),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.add_location_alt_rounded, size: 18),
                    label: const Text('Simpan & Tambah ke Rute',
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      if (!formKey.currentState!.validate()) return;
                      Navigator.pop(
                          ctx,
                          HalteModel(
                            id: -DateTime.now().millisecondsSinceEpoch,
                            namaHalte: namaCtrl.text.trim(),
                            alamat: alamatCtrl.text.trim(),
                            latitude: picked.latitude,
                            longitude: picked.longitude,
                            createdAt: DateTime.now(),
                          ));
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (result == null || !mounted) return;
    setState(() => _savingHalte = true);
    final saved = await _halteSvc.createHalte(
      namaHalte: result.namaHalte,
      latitude: result.latitude,
      longitude: result.longitude,
      alamat: result.alamat,
    );
    if (!mounted) return;
    setState(() {
      _savingHalte = false;
      if (saved != null) _allHaltes.add(saved);
    });
    if (saved != null) {
      _addWaypoint(saved);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Halte "${saved.namaHalte}" dibuat & ditambahkan',
            style: const TextStyle(fontFamily: 'Poppins')),
        backgroundColor: AppColors.primary,
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Gagal menyimpan halte',
            style: TextStyle(fontFamily: 'Poppins')),
        backgroundColor: Colors.red,
      ));
    }
  }

  Future<void> _goToMyLocation() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied)
        perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition(
          locationSettings:
              const LocationSettings(accuracy: LocationAccuracy.high));
      _mapCtrl.move(LatLng(pos.latitude, pos.longitude), 15);
    } catch (_) {}
  }

  void _simpanRute() {
    if (_waypoints.length < 2) return;
    final pts = _routePolyline.isNotEmpty
        ? _routePolyline
        : _waypoints.map((h) => LatLng(h.latitude, h.longitude)).toList();
    final nama = widget.initialName?.isNotEmpty == true
        ? widget.initialName!
        : '${_waypoints.first.namaHalte} → ${_waypoints.last.namaHalte}';
    Navigator.pop(
        context,
        RouteBuilderResult(
          polylinePoints: pts,
          orderedHaltes: List.from(_waypoints),
          routeName: nama,
          distanceMeters: _distM,
          durationSeconds: _durS,
        ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        Positioned.fill(child: _buildPeta()),
        Positioned(
            top: 0, left: 0, right: 0, child: SafeArea(child: _buildHeader())),
        if (_routing)
          Positioned(
              top: 100,
              left: 0,
              right: 0,
              child: Center(child: _RoutingIndicator())),
        Positioned(
          right: 12,
          bottom:
              (_showHalteList ? 370 : (_waypoints.isEmpty ? 195 : 305)) + 16,
          child: Column(children: [
            _BtnBundar(
                icon: Icons.my_location_rounded,
                warna: AppColors.primary,
                onTap: _goToMyLocation),
            const SizedBox(height: 10),
            if (_waypoints.length >= 2)
              _BtnBundar(
                  icon: Icons.fit_screen_rounded,
                  onTap: () {
                    final pts = _routePolyline.isNotEmpty
                        ? _routePolyline
                        : _waypoints
                            .map((h) => LatLng(h.latitude, h.longitude))
                            .toList();
                    _fitBounds(pts, bottomPad: _showHalteList ? 400 : 320);
                  }),
          ]),
        ),
        Positioned(bottom: 0, left: 0, right: 0, child: _buildPanel()),
      ]),
    );
  }

  Widget _buildPeta() {
    return FlutterMap(
      mapController: _mapCtrl,
      options: const MapOptions(initialCenter: _defaultCenter, initialZoom: 13),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.mobitra.app',
          maxZoom: 19,
        ),
        if (_routePolyline.length >= 2)
          PolylineLayer(polylines: [
            Polyline(
                points: _routePolyline,
                color: Colors.black.withValues(alpha: 0.12),
                strokeWidth: 12),
            Polyline(
                points: _routePolyline,
                color: const Color(0xFF1A73E8),
                strokeWidth: 7),
            Polyline(
                points: _routePolyline,
                color: Colors.white.withValues(alpha: 0.35),
                strokeWidth: 2.5),
          ]),
        if (_showHalteList)
          MarkerLayer(
              markers: _allHaltes
                  .where((h) =>
                      !_waypoints.any((w) => w.id == h.id) && h.latitude != 0)
                  .map((h) => Marker(
                        point: LatLng(h.latitude, h.longitude),
                        width: 28,
                        height: 28,
                        child: GestureDetector(
                          onTap: () => _addWaypoint(h),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: AppColors.textGrey, width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 4)
                              ],
                            ),
                            child: const Icon(Icons.place_rounded,
                                size: 14, color: AppColors.textGrey),
                          ),
                        ),
                      ))
                  .toList()),
        MarkerLayer(
            markers: _waypoints.asMap().entries.map((e) {
          final idx = e.key;
          final h = e.value;
          final isFirst = idx == 0;
          final isLast = idx == _waypoints.length - 1 && idx > 0;
          final warna = isFirst
              ? Colors.green
              : isLast
                  ? const Color(0xFFE53935)
                  : const Color(0xFF1A73E8);
          return Marker(
            point: LatLng(h.latitude, h.longitude),
            width: 44,
            height: 58,
            alignment: Alignment.topCenter,
            child: GestureDetector(
              onTap: () => _tampilInfoWaypoint(h, idx),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: warna,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                          color: warna.withValues(alpha: 0.5),
                          blurRadius: 8,
                          offset: const Offset(0, 2))
                    ],
                  ),
                  child: Center(
                      child: Text('${idx + 1}',
                          style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              height: 1))),
                ),
                Container(width: 3, height: 10, color: warna),
                Container(
                    width: 6,
                    height: 6,
                    decoration:
                        BoxDecoration(color: warna, shape: BoxShape.circle)),
              ]),
            ),
          );
        }).toList()),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(children: [
        _BtnBundar(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () => Navigator.pop(context)),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
              const Icon(Icons.alt_route_rounded,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.initialName?.isNotEmpty == true
                      ? widget.initialName!
                      : _waypoints.length >= 2
                          ? '${_waypoints.first.namaHalte} → ${_waypoints.last.namaHalte}'
                          : _waypoints.length == 1
                              ? '${_waypoints.first.namaHalte} → ?'
                              : 'Pilih halte untuk membuat rute',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _waypoints.isEmpty
                          ? AppColors.textGrey
                          : AppColors.black),
                ),
              ),
              if (_distM > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    _distM >= 1000
                        ? '${(_distM / 1000).toStringAsFixed(1)} km'
                        : '${_distM.round()} m',
                    style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary),
                  ),
                ),
              ],
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _buildPanel() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [
          BoxShadow(
              color: Color(0x28000000), blurRadius: 24, offset: Offset(0, -6))
        ],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Center(
            child: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: AppColors.lightGrey,
                  borderRadius: BorderRadius.circular(2))),
        )),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            height: 44,
            decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              _TabBtn(
                  label: 'Urutan Halte',
                  icon: Icons.format_list_numbered_rounded,
                  active: !_showHalteList,
                  badge: _waypoints.isNotEmpty ? '${_waypoints.length}' : null,
                  onTap: () => setState(() => _showHalteList = false)),
              _TabBtn(
                  label: 'Pilih Halte',
                  icon: Icons.add_location_alt_rounded,
                  active: _showHalteList,
                  onTap: () => setState(() => _showHalteList = true)),
            ]),
          ),
        ),
        const SizedBox(height: 10),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _showHalteList ? _buildPanelPilihHalte() : _buildPanelUrutan(),
        ),
        const SizedBox(height: 10),
      ]),
    );
  }

  Widget _buildPanelUrutan() {
    return Column(
        key: const ValueKey('urutan'),
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_waypoints.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: AppColors.surface2,
                    borderRadius: BorderRadius.circular(14)),
                child: Column(children: [
                  Icon(Icons.route_rounded,
                      size: 36,
                      color: AppColors.primary.withValues(alpha: 0.4)),
                  const SizedBox(height: 8),
                  const Text('Belum ada halte dipilih',
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textGrey)),
                  const SizedBox(height: 4),
                  const Text(
                      'Tap "Pilih Halte" di atas untuk\nmenambahkan halte ke rute',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: AppColors.textGrey)),
                ]),
              ),
            )
          else ...[
            if (_waypoints.length >= 2)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Row(children: [
                  Icon(Icons.drag_indicator_rounded,
                      size: 13, color: AppColors.textGrey),
                  SizedBox(width: 4),
                  Text('Tahan & geser untuk ubah urutan',
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          color: AppColors.textGrey)),
                ]),
              ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 165),
              child: ReorderableListView.builder(
                shrinkWrap: true,
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _waypoints.length,
                onReorder: _reorderWaypoints,
                itemBuilder: (_, idx) {
                  final h = _waypoints[idx];
                  final isFirst = idx == 0;
                  final isLast = idx == _waypoints.length - 1 && idx > 0;
                  final warna = isFirst
                      ? Colors.green
                      : isLast
                          ? const Color(0xFFE53935)
                          : const Color(0xFF1A73E8);
                  return Material(
                    key: ValueKey('wp_${h.id}_$idx'),
                    color: Colors.transparent,
                    child: ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      leading: Container(
                        width: 32,
                        height: 32,
                        decoration:
                            BoxDecoration(color: warna, shape: BoxShape.circle),
                        child: Center(
                            child: Text('${idx + 1}',
                                style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white))),
                      ),
                      title: Text(h.namaHalte,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                      subtitle: h.alamat.isNotEmpty
                          ? Text(h.alamat,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 11,
                                  color: AppColors.textGrey))
                          : null,
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(
                            icon: const Icon(Icons.location_searching_rounded,
                                size: 17, color: AppColors.textGrey),
                            onPressed: () => _mapCtrl.move(
                                LatLng(h.latitude, h.longitude), 15),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero),
                        IconButton(
                            icon: const Icon(
                                Icons.remove_circle_outline_rounded,
                                size: 17,
                                color: Colors.red),
                            onPressed: () => _removeWaypoint(idx),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero),
                        ReorderableDragStartListener(
                            index: idx,
                            child: const Icon(Icons.drag_handle_rounded,
                                size: 22, color: AppColors.textGrey)),
                      ]),
                    ),
                  );
                },
              ),
            ),
            if (_waypoints.length == 1)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 6, 16, 0),
                child: _InfoBanner(
                    ikon: Icons.info_outline_rounded,
                    warna: AppColors.orange,
                    pesan:
                        'Tambah minimal 1 halte lagi agar jalur bisa dihitung.'),
              ),
          ],
          if (_distM > 0)
            Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: _InfoJarak(distM: _distM, durS: _durS)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.check_circle_rounded, size: 20),
                label: Text(
                  _waypoints.length < 2
                      ? 'Pilih minimal 2 halte'
                      : 'Gunakan Rute Ini  (${_waypoints.length} Halte)',
                  style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w700,
                      fontSize: 14),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _waypoints.length >= 2
                      ? AppColors.primary
                      : AppColors.lightGrey,
                  foregroundColor: _waypoints.length >= 2
                      ? Colors.white
                      : AppColors.textGrey,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _waypoints.length >= 2 ? _simpanRute : null,
              ),
            ),
          ),
        ]);
  }

  Widget _buildPanelPilihHalte() {
    final filtered = _allHaltes
        .where((h) =>
            h.namaHalte.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            h.alamat.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    return Column(
        key: const ValueKey('pilih'),
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(children: [
              Expanded(
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.surface2,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.lightGrey),
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _searchQuery = v),
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: 'Cari nama halte...',
                      hintStyle: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          color: AppColors.textGrey),
                      prefixIcon: Icon(Icons.search_rounded,
                          color: AppColors.textGrey, size: 18),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: 'Buat halte baru',
                child: GestureDetector(
                  onTap: _savingHalte ? null : _buatHalteBaru,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 6)
                      ],
                    ),
                    child: _savingHalte
                        ? const Center(
                            child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white)))
                        : const Icon(Icons.add_rounded,
                            color: Colors.white, size: 24),
                  ),
                ),
              ),
            ]),
          ),
          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                const Icon(Icons.location_off_outlined,
                    size: 40, color: AppColors.textGrey),
                const SizedBox(height: 8),
                Text(
                    _searchQuery.isEmpty
                        ? 'Belum ada halte terdaftar.\nTap + untuk buat halte baru.'
                        : 'Tidak ditemukan halte "$_searchQuery"',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        color: AppColors.textGrey)),
              ]),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: ListView.builder(
                shrinkWrap: true,
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: filtered.length,
                itemBuilder: (_, i) {
                  final h = filtered[i];
                  final sudahDipilih = _waypoints.any((w) => w.id == h.id);
                  final urutan = sudahDipilih
                      ? _waypoints.indexWhere((w) => w.id == h.id) + 1
                      : 0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: sudahDipilih
                            ? () => _mapCtrl.move(
                                LatLng(h.latitude, h.longitude), 15)
                            : () => _addWaypoint(h),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 10),
                          decoration: BoxDecoration(
                            color: sudahDipilih
                                ? AppColors.primaryLight
                                : AppColors.surface2,
                            borderRadius: BorderRadius.circular(12),
                            border: sudahDipilih
                                ? Border.all(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.4))
                                : null,
                          ),
                          child: Row(children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: sudahDipilih
                                    ? AppColors.primary
                                    : Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.08),
                                      blurRadius: 4)
                                ],
                              ),
                              child: Center(
                                  child: sudahDipilih
                                      ? Text('$urutan',
                                          style: const TextStyle(
                                              fontFamily: 'Poppins',
                                              fontSize: 13,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.white))
                                      : const Icon(Icons.add_rounded,
                                          size: 18, color: AppColors.textGrey)),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(h.namaHalte,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: sudahDipilih
                                              ? AppColors.primary
                                              : AppColors.black)),
                                  if (h.alamat.isNotEmpty)
                                    Text(h.alamat,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontFamily: 'Poppins',
                                            fontSize: 11,
                                            color: AppColors.textGrey)),
                                ])),
                            if (sudahDipilih)
                              const Padding(
                                  padding: EdgeInsets.only(left: 4),
                                  child: Icon(Icons.check_circle_rounded,
                                      size: 18, color: AppColors.primary))
                            else
                              IconButton(
                                icon: const Icon(
                                    Icons.location_searching_rounded,
                                    size: 16,
                                    color: AppColors.textGrey),
                                onPressed: () => _mapCtrl.move(
                                    LatLng(h.latitude, h.longitude), 15),
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                              ),
                          ]),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ]);
  }

  void _tampilInfoWaypoint(HalteModel h, int idx) {
    final isFirst = idx == 0;
    final isLast = idx == _waypoints.length - 1 && idx > 0;
    final warna = isFirst
        ? Colors.green
        : isLast
            ? const Color(0xFFE53935)
            : const Color(0xFF1A73E8);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
        decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: AppColors.lightGrey,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Row(children: [
            Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: warna, shape: BoxShape.circle),
                child: Center(
                    child: Text('${idx + 1}',
                        style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: Colors.white)))),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(h.namaHalte,
                      style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 16,
                          fontWeight: FontWeight.w700)),
                  if (h.alamat.isNotEmpty)
                    Text(h.alamat,
                        style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            color: AppColors.textGrey)),
                  Text(
                      '${h.latitude.toStringAsFixed(5)}, ${h.longitude.toStringAsFixed(5)}',
                      style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          color: AppColors.textGrey)),
                ])),
          ]),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.remove_circle_outline_rounded, size: 16),
              label: const Text('Hapus dari Rute',
                  style: TextStyle(fontFamily: 'Poppins')),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () {
                Navigator.pop(context);
                _removeWaypoint(idx);
              },
            ),
          ),
        ]),
      ),
    );
  }
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
        child: Icon(icon, color: warna ?? AppColors.black, size: 20),
      ),
    );
  }
}

class _TabBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final String? badge;
  final VoidCallback onTap;
  const _TabBtn(
      {required this.label,
      required this.icon,
      required this.active,
      required this.onTap,
      this.badge});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.all(4),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon,
                size: 15, color: active ? Colors.white : AppColors.textGrey),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: active ? Colors.white : AppColors.textGrey)),
            if (badge != null) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: active
                      ? Colors.white.withValues(alpha: 0.3)
                      : AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(badge!,
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: active ? Colors.white : AppColors.primary)),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final IconData ikon;
  final Color warna;
  final String pesan;
  const _InfoBanner(
      {required this.ikon, required this.warna, required this.pesan});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: warna.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: warna.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Icon(ikon, size: 14, color: warna),
        const SizedBox(width: 8),
        Expanded(
            child: Text(pesan,
                style: TextStyle(
                    fontFamily: 'Poppins', fontSize: 11, color: warna))),
      ]),
    );
  }
}

class _InfoJarak extends StatelessWidget {
  final double distM;
  final double durS;
  const _InfoJarak({required this.distM, required this.durS});
  @override
  Widget build(BuildContext context) {
    final menit = (durS / 60).round();
    final durLabel =
        menit >= 60 ? '${menit ~/ 60}j ${menit % 60}m' : '${menit}m';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.straighten_rounded,
            color: AppColors.primary, size: 16),
        const SizedBox(width: 6),
        Text(
            distM >= 1000
                ? '${(distM / 1000).toStringAsFixed(1)} km'
                : '${distM.round()} m',
            style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.primary)),
        const SizedBox(width: 20),
        const Icon(Icons.access_time_filled_rounded,
            color: AppColors.primary, size: 16),
        const SizedBox(width: 6),
        Text(durLabel,
            style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.primary)),
        const SizedBox(width: 4),
        const Text(' (estimasi)',
            style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 10,
                color: AppColors.textGrey)),
      ]),
    );
  }
}

class _RoutingIndicator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(22)),
      child: const Row(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
            width: 16,
            height: 16,
            child:
                CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
        SizedBox(width: 10),
        Text('Menghitung jalur...',
            style: TextStyle(
                fontFamily: 'Poppins', fontSize: 12, color: Colors.white)),
      ]),
    );
  }
}
