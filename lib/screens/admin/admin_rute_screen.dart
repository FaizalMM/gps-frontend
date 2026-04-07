import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import '../../models/models_api.dart';
import '../../services/app_data_service.dart';
import '../../services/domain_services.dart';
import '../../utils/app_theme.dart';
import '../../widgets/bus_map_widget.dart';
import '../../widgets/common_widgets.dart';
import 'route_builder_screen.dart';

class AdminRuteScreen extends StatefulWidget {
  final AppDataService dataService;
  const AdminRuteScreen({super.key, required this.dataService});

  @override
  State<AdminRuteScreen> createState() => _AdminRuteScreenState();
}

class _AdminRuteScreenState extends State<AdminRuteScreen>
    with SingleTickerProviderStateMixin {
  final _routeService = RouteService();
  late TabController _tabCtrl;

  List<RouteModel> _routes = [];
  bool _loading = true;
  RouteModel? _selectedRoute;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadRoutes();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRoutes() async {
    setState(() => _loading = true);
    print('[AdminRuteScreen] Loading routes...');
    final routes = await _routeService.getRoutes();
    print('[AdminRuteScreen] Loaded ${routes.length} routes');
    if (!mounted) return;
    setState(() {
      _routes = routes;
      _loading = false;
      if (_selectedRoute == null && routes.isNotEmpty) {
        _selectedRoute = routes.first;
      }
    });
  }

  // ─── Dialog tambah rute ──────────────────────────────────────
  void _showAddRouteDialog() {
    final namaCtrl = TextEditingController();
    int? selectedBusId;
    final formKey = GlobalKey<FormState>();

    // FIX 1: BusStatus.active (bukan .aktif)
    final buses = widget.dataService.buses
        .where((b) => b.status == BusStatus.active)
        .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Container(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.lightGrey,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Tambah Rute',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 20,
                        fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 20),
                  // FIX 2: AppTextField tidak punya parameter 'hint'
                  AppTextField(
                    label: 'Nama Rute (cth: Rute A - Terminal Caruban)',
                    controller: namaCtrl,
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Nama rute wajib diisi' : null,
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Bus',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<int>(
                    value: selectedBusId,
                    hint: const Text('Pilih Bus',
                        style: TextStyle(fontFamily: 'Poppins', fontSize: 13)),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 14),
                    ),
                    items: buses
                        .map((b) => DropdownMenuItem(
                              value: b.id,
                              child: Text(
                                '${b.nama} · ${b.platNomor}',
                                style: const TextStyle(
                                    fontFamily: 'Poppins', fontSize: 13),
                              ),
                            ))
                        .toList(),
                    onChanged: (v) => setModal(() => selectedBusId = v),
                    validator: (v) =>
                        v == null ? 'Pilih bus terlebih dahulu' : null,
                  ),
                  const SizedBox(height: 24),
                  // FIX 3: PrimaryButton, parameter 'text' (bukan 'label')
                  PrimaryButton(
                    text: 'Simpan',
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      Navigator.pop(ctx);
                      final result = await _routeService.createRoute(
                        busId: selectedBusId!,
                        namaRute: namaCtrl.text.trim(),
                      );
                      if (!mounted) return;
                      if (result != null) {
                        _showSnack('Rute berhasil ditambahkan', isError: false);
                        _loadRoutes();
                      } else {
                        _showSnack('Gagal menambahkan rute');
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Dialog hapus rute ───────────────────────────────────────
  void _confirmDelete(RouteModel route) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Hapus Rute?',
          style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Rute "${route.namaRute}" beserta semua halte dan jalurnya akan dihapus permanen.',
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal',
                style: TextStyle(
                    fontFamily: 'Poppins', color: AppColors.textGrey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await _routeService.deleteRoute(route.id);
              if (!mounted) return;
              if (ok) {
                _showSnack('Rute dihapus', isError: false);
                if (_selectedRoute?.id == route.id) {
                  setState(() => _selectedRoute = null);
                }
                _loadRoutes();
              } else {
                _showSnack('Gagal menghapus rute');
              }
            },
            child: const Text('Hapus',
                style: TextStyle(fontFamily: 'Poppins', color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _openPolylineEditor(RouteModel route) async {
    // Pastikan daftar halte selalu fresh sebelum buka editor
    await widget.dataService.loadHaltes();
    if (!mounted) return;

    final result = await Navigator.push<RouteBuilderResult>(
      context,
      MaterialPageRoute(
        builder: (_) => RouteBuilderScreen(
          availableHaltes: widget.dataService.haltes,
          initialName: route.namaRute,
          initialPoints: route.polyline.isNotEmpty
              ? route.polyline
                  .map((p) => LatLng(p.latitude, p.longitude))
                  .toList()
              : null,
        ),
      ),
    );

    if (result == null || !mounted) return;

    // Simpan ke backend (polyline + halte dalam 1 request)
    final polyPayload = result.polylinePoints
        .map((p) => {'latitude': p.latitude, 'longitude': p.longitude})
        .toList();

    final halteIds = result.orderedHaltes.map((h) => h.id).toList();

    final updated = await _routeService.syncRoute(
      routeId: route.id,
      polyline: polyPayload,
      halteIds: halteIds.isNotEmpty ? halteIds : null,
      namaRute: result.routeName != route.namaRute ? result.routeName : null,
    );

    if (!mounted) return;
    if (updated != null) {
      final dist = result.distanceMeters >= 1000
          ? '${(result.distanceMeters / 1000).toStringAsFixed(1)} km'
          : '${result.distanceMeters.round()} m';
      _showSnack(
        'Rute disimpan · ${result.polylinePoints.length} titik'
        '${result.distanceMeters > 0 ? " · $dist" : ""}',
        isError: false,
      );
      _loadRoutes();
    } else {
      _showSnack('Gagal menyimpan rute.');
    }
  }

  void _showSnack(String msg, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Poppins')),
      backgroundColor: isError ? Colors.red : AppColors.primary,
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text(
          'Rute Bus',
          style: TextStyle(
              fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 18),
        ),
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          labelStyle: const TextStyle(
              fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 13),
          tabs: const [
            Tab(text: 'Peta Rute'),
            Tab(text: 'Daftar Rute'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_road_rounded),
            tooltip: 'Tambah Rute',
            onPressed: _showAddRouteDialog,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabCtrl,
              children: [
                _buildMapTab(),
                _buildListTab(),
              ],
            ),
    );
  }

  // ─── Tab Peta ────────────────────────────────────────────────
  Widget _buildMapTab() {
    return Column(
      children: [
        if (_routes.isNotEmpty)
          Container(
            height: 44,
            color: Colors.white,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              itemCount: _routes.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final r = _routes[i];
                final selected = _selectedRoute?.id == r.id;
                return GestureDetector(
                  onTap: () => setState(() => _selectedRoute = r),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color:
                          selected ? AppColors.primary : AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Center(
                      child: Text(
                        r.namaRute,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: selected ? Colors.white : AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        Expanded(
          child: _routes.isEmpty
              ? _emptyState(
                  icon: Icons.map_outlined,
                  msg: 'Belum ada rute',
                  sub: 'Tambah rute baru melalui tombol + di atas',
                )
              : BusMapWidget(
                  buses: widget.dataService.buses,
                  height: double.infinity,
                  showAllBuses: _selectedRoute == null,
                  routes: _selectedRoute != null ? [_selectedRoute!] : _routes,
                  showRoutes: true,
                  interactive: true,
                ),
        ),
        if (_selectedRoute != null)
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedRoute!.namaRute,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '${_selectedRoute!.haltes.length} halte · '
                        '${_selectedRoute!.polyline.length} titik jalur',
                        style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            color: AppColors.textGrey),
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.edit_road_rounded, size: 16),
                  label: const Text(
                    'Edit Jalur',
                    style: TextStyle(
                        fontFamily: 'Poppins', fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _openPolylineEditor(_selectedRoute!),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ─── Tab Daftar ──────────────────────────────────────────────
  Widget _buildListTab() {
    if (_routes.isEmpty) {
      return _emptyState(
        icon: Icons.route_outlined,
        msg: 'Belum ada rute',
        sub: 'Tap tombol + di atas untuk menambah rute baru',
      );
    }
    return RefreshIndicator(
      onRefresh: _loadRoutes,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _routes.length,
        itemBuilder: (_, i) => _RouteCard(
          route: _routes[i],
          halteList: widget.dataService.haltes,
          routeService: _routeService,
          onEdit: () {
            setState(() => _selectedRoute = _routes[i]);
            _tabCtrl.animateTo(0);
          },
          onEditPolyline: () => _openPolylineEditor(_routes[i]),
          onDelete: () => _confirmDelete(_routes[i]),
          onRefresh: _loadRoutes,
        ),
      ),
    );
  }

  Widget _emptyState(
      {required IconData icon, required String msg, required String sub}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 56, color: AppColors.textGrey.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          Text(msg,
              style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                  color: AppColors.textGrey)),
          const SizedBox(height: 4),
          Text(sub,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  color: AppColors.textGrey)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Card satu rute
// ─────────────────────────────────────────────────────────────
class _RouteCard extends StatelessWidget {
  final RouteModel route;
  final List<HalteModel> halteList;
  final RouteService routeService;
  final VoidCallback onEdit;
  final VoidCallback onEditPolyline;
  final VoidCallback onDelete;
  final VoidCallback onRefresh;

  const _RouteCard({
    required this.route,
    required this.halteList,
    required this.routeService,
    required this.onEdit,
    required this.onEditPolyline,
    required this.onDelete,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.route_rounded,
                      color: AppColors.primary, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        route.namaRute,
                        style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w700,
                            fontSize: 14),
                      ),
                      Text(
                        '${route.busNama} · ${route.busPlatNomor}',
                        style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            color: AppColors.textGrey),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded,
                      color: AppColors.textGrey),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  onSelected: (v) {
                    if (v == 'lihat') onEdit();
                    if (v == 'jalur') onEditPolyline();
                    if (v == 'hapus') onDelete();
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                        value: 'lihat',
                        child: Row(children: [
                          Icon(Icons.map_outlined,
                              size: 18, color: AppColors.primary),
                          SizedBox(width: 8),
                          Text('Lihat di Peta',
                              style: TextStyle(fontFamily: 'Poppins')),
                        ])),
                    const PopupMenuItem(
                        value: 'jalur',
                        child: Row(children: [
                          Icon(Icons.edit_road_rounded,
                              size: 18, color: AppColors.primary),
                          SizedBox(width: 8),
                          Text('Edit Jalur',
                              style: TextStyle(fontFamily: 'Poppins')),
                        ])),
                    const PopupMenuItem(
                        value: 'hapus',
                        child: Row(children: [
                          Icon(Icons.delete_outline_rounded,
                              size: 18, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Hapus Rute',
                              style: TextStyle(
                                  fontFamily: 'Poppins', color: Colors.red)),
                        ])),
                  ],
                ),
              ],
            ),
            const Divider(height: 20),
            Row(
              children: [
                _stat(Icons.place_rounded, '${route.haltes.length} Halte'),
                const SizedBox(width: 16),
                _stat(Icons.timeline_rounded,
                    '${route.polyline.length} Titik Jalur'),
              ],
            ),
            // FIX 4: RouteHalteModel tidak punya .namaHalte/.latitude/.longitude langsung
            // → harus lewat .halte?.namaHalte
            if (route.haltes.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Urutan Halte:',
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textGrey),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: route.haltes
                    .map((rh) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${rh.urutan}. ${rh.halte?.namaHalte ?? 'Halte #${rh.halteId}'}',
                            style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 10,
                                color: AppColors.primary),
                          ),
                        ))
                    .toList(),
              ),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.add_location_alt_outlined, size: 16),
              label: const Text(
                'Tambah Halte ke Rute',
                style: TextStyle(
                    fontFamily: 'Poppins', fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                minimumSize: const Size(double.infinity, 36),
              ),
              onPressed: () => _showAddHalteDialog(
                  context, route, halteList, routeService, onRefresh),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textGrey),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11,
                color: AppColors.textGrey)),
      ],
    );
  }

  void _showAddHalteDialog(
    BuildContext context,
    RouteModel route,
    List<HalteModel> haltes,
    RouteService svc,
    VoidCallback onRefresh,
  ) {
    int? selectedHalteId;
    final urutanCtrl =
        TextEditingController(text: (route.haltes.length + 1).toString());
    final formKey = GlobalKey<FormState>();

    final existingIds = route.haltes.map((h) => h.halteId).toSet();
    final available = haltes.where((h) => !existingIds.contains(h.id)).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Container(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.lightGrey,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Tambah Halte ke "${route.namaRute}"',
                    style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 18,
                        fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 20),
                  if (available.isEmpty)
                    const Text(
                      'Semua halte sudah ditambahkan ke rute ini.',
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 13),
                    )
                  else ...[
                    DropdownButtonFormField<int>(
                      value: selectedHalteId,
                      hint: const Text('Pilih Halte',
                          style:
                              TextStyle(fontFamily: 'Poppins', fontSize: 13)),
                      decoration: InputDecoration(
                        labelText: 'Halte',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 14),
                      ),
                      items: available
                          .map((h) => DropdownMenuItem(
                                value: h.id,
                                child: Text(
                                  h.namaHalte,
                                  style: const TextStyle(
                                      fontFamily: 'Poppins', fontSize: 13),
                                ),
                              ))
                          .toList(),
                      onChanged: (v) => setModal(() => selectedHalteId = v),
                      validator: (v) =>
                          v == null ? 'Pilih halte terlebih dahulu' : null,
                    ),
                    const SizedBox(height: 14),
                    AppTextField(
                      label: 'Urutan',
                      controller: urutanCtrl,
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Urutan wajib diisi';
                        }
                        if (int.tryParse(v) == null) {
                          return 'Harus berupa angka';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    PrimaryButton(
                      text: 'Tambahkan',
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) return;
                        Navigator.pop(ctx);
                        final ok = await svc.addHalteToRoute(
                          routeId: route.id,
                          halteId: selectedHalteId!,
                          urutan: int.parse(urutanCtrl.text),
                        );
                        if (ok) onRefresh();
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Screen editor polyline — klik peta untuk tambah titik
// ─────────────────────────────────────────────────────────────
class _PolylineEditorScreen extends StatefulWidget {
  final RouteModel route;
  final RouteService routeService;

  const _PolylineEditorScreen({
    required this.route,
    required this.routeService,
  });

  @override
  State<_PolylineEditorScreen> createState() => _PolylineEditorScreenState();
}

class _PolylineEditorScreenState extends State<_PolylineEditorScreen> {
  final _mapController = MapController();
  late List<LatLng> _points;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _points = widget.route.polyline
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList();
  }

  LatLng get _center {
    if (_points.isNotEmpty) return _points.first;
    if (widget.route.haltes.isNotEmpty) {
      final h = widget.route.haltes.first;
      // FIX 4: latitude/longitude ada di .halte (HalteModel), bukan di RouteHalteModel
      final lat = h.halte?.latitude ?? -7.6298;
      final lng = h.halte?.longitude ?? 111.5239;
      return LatLng(lat, lng);
    }
    return const LatLng(-7.6298, 111.5239);
  }

  void _onMapTap(TapPosition _, LatLng point) {
    setState(() => _points.add(point));
  }

  void _removeLastPoint() {
    if (_points.isNotEmpty) setState(() => _points.removeLast());
  }

  void _clearAll() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Hapus semua titik?',
          style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(fontFamily: 'Poppins')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _points.clear());
            },
            child: const Text('Hapus',
                style: TextStyle(fontFamily: 'Poppins', color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (_points.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Minimal 2 titik untuk membuat jalur',
            style: TextStyle(fontFamily: 'Poppins')),
        backgroundColor: Colors.orange,
      ));
      return;
    }
    setState(() => _saving = true);
    final pointMaps = _points
        .map((p) => {'latitude': p.latitude, 'longitude': p.longitude})
        .toList();
    // savePolyline dihapus, pakai syncRoute (polyline saja, halte tidak diubah)
    final result = await widget.routeService.syncRoute(
      routeId: widget.route.id,
      polyline: pointMaps,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    final ok = result != null;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Jalur berhasil disimpan',
            style: TextStyle(fontFamily: 'Poppins')),
        backgroundColor: AppColors.primary,
      ));
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Gagal menyimpan jalur',
            style: TextStyle(fontFamily: 'Poppins')),
        backgroundColor: Colors.red,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
        title: Text(
          'Edit Jalur: ${widget.route.namaRute}',
          style: const TextStyle(
              fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 15),
        ),
        actions: [
          if (_points.isNotEmpty)
            TextButton.icon(
              icon: const Icon(Icons.delete_sweep_rounded,
                  color: Colors.redAccent, size: 18),
              label: const Text(
                'Hapus Semua',
                style: TextStyle(
                    fontFamily: 'Poppins',
                    color: Colors.redAccent,
                    fontSize: 12),
              ),
              onPressed: _clearAll,
            ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: 15.0,
              onTap: _onMapTap,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.mobitra.app',
                maxZoom: 19,
              ),
              if (_points.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _points,
                      color: AppColors.primary.withValues(alpha: 0.3),
                      strokeWidth: 10,
                    ),
                    Polyline(
                      points: _points,
                      color: AppColors.primary,
                      strokeWidth: 4,
                    ),
                    Polyline(
                      points: _points,
                      color: Colors.white.withValues(alpha: 0.4),
                      strokeWidth: 1.5,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: _points.asMap().entries.map((e) {
                  final isFirst = e.key == 0;
                  final isLast = e.key == _points.length - 1;
                  Color dotColor = AppColors.primary;
                  if (isFirst) dotColor = Colors.green;
                  if (isLast && _points.length > 1) dotColor = Colors.red;
                  return Marker(
                    point: e.value,
                    width: 16,
                    height: 16,
                    child: Container(
                      decoration: BoxDecoration(
                        color: dotColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  );
                }).toList(),
              ),
              // Marker halte referensi — FIX: akses koordinat via .halte!
              if (widget.route.haltes.isNotEmpty)
                MarkerLayer(
                  markers: widget.route.haltes
                      .where((h) => h.halte != null && h.halte!.latitude != 0)
                      .map((h) => Marker(
                            point: LatLng(
                              h.halte!.latitude,
                              h.halte!.longitude,
                            ),
                            width: 28,
                            height: 34,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: Colors.orange,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white, width: 2),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${h.urutan}',
                                      style: const TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Container(
                                  width: 4,
                                  height: 4,
                                  decoration: const BoxDecoration(
                                      color: Colors.orange,
                                      shape: BoxShape.circle),
                                ),
                              ],
                            ),
                          ))
                      .toList(),
                ),
            ],
          ),

          // Panel bawah
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 10)
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_points.length} titik jalur',
                        style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w600,
                            fontSize: 13),
                      ),
                      Row(
                        children: [
                          Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                  color: Colors.green, shape: BoxShape.circle)),
                          const SizedBox(width: 4),
                          const Text('Awal',
                              style: TextStyle(
                                  fontFamily: 'Poppins', fontSize: 10)),
                          const SizedBox(width: 10),
                          Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                  color: Colors.red, shape: BoxShape.circle)),
                          const SizedBox(width: 4),
                          const Text('Akhir',
                              style: TextStyle(
                                  fontFamily: 'Poppins', fontSize: 10)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Ketuk peta untuk menambah titik jalur. '
                    'Titik halte (oranye) ditampilkan sebagai referensi.',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        color: AppColors.textGrey),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.undo_rounded, size: 18),
                        label: const Text('Undo',
                            style:
                                TextStyle(fontFamily: 'Poppins', fontSize: 12)),
                        onPressed: _points.isEmpty ? null : _removeLastPoint,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: _saving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.save_rounded, size: 18),
                          label: Text(
                            _saving ? 'Menyimpan...' : 'Simpan Jalur',
                            style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.w600),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                            minimumSize: const Size(0, 44),
                          ),
                          onPressed: _saving ? null : _save,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Instruksi floating
          Positioned(
            top: 16,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.touch_app_rounded,
                        color: Colors.white, size: 16),
                    SizedBox(width: 6),
                    Text(
                      'Ketuk peta untuk tambah titik',
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
