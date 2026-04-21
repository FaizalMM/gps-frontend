import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'halte_location_picker.dart';
import '../../models/models_api.dart';
import '../../services/app_data_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';

class AdminHalteScreen extends StatefulWidget {
  final AppDataService dataService;
  const AdminHalteScreen({super.key, required this.dataService});

  @override
  State<AdminHalteScreen> createState() => _AdminHalteScreenState();
}

class _AdminHalteScreenState extends State<AdminHalteScreen> {
  String _searchQuery = '';
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    await widget.dataService.loadHaltes();
    if (mounted) setState(() => _loading = false);
  }

  // ── Bug 2 Fix: Hapus field "Rute" yang tidak ada di BE
  void _showAddHalteDialog() {
    final namaCtrl = TextEditingController();
    final alamatCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    double? pickedLat;
    double? pickedLng;

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
                              borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 20),
                  const Text('Tambah Halte',
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 20,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  const Text(
                    'Setelah halte dibuat, tambahkan ke rute di menu Rute Bus.',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        color: AppColors.textGrey),
                  ),
                  const SizedBox(height: 20),
                  AppTextField(
                      label: 'Nama Halte',
                      controller: namaCtrl,
                      validator: (v) =>
                          v!.isEmpty ? 'Nama tidak boleh kosong' : null),
                  const SizedBox(height: 14),
                  // Bug 2 Fix: Tidak ada field "Rute" — halte tidak punya rute langsung
                  AppTextField(
                    label: 'Alamat (opsional)',
                    controller: alamatCtrl,
                  ),
                  const SizedBox(height: 14),
                  _LocationPickerField(
                    lat: pickedLat,
                    lng: pickedLng,
                    onPick: () async {
                      final result = await Navigator.push<PickedLocation>(
                        context,
                        MaterialPageRoute(
                            builder: (_) => HalteLocationPicker(
                                initialLat: pickedLat, initialLng: pickedLng)),
                      );
                      if (result != null)
                        setModal(() {
                          pickedLat = result.latitude;
                          pickedLng = result.longitude;
                          // Auto-isi alamat dari reverse geocode kalau field masih kosong
                          if (alamatCtrl.text.trim().isEmpty &&
                              result.namaAlamat != null) {
                            alamatCtrl.text = result.namaAlamat!;
                          }
                        });
                    },
                  ),
                  const SizedBox(height: 24),
                  PrimaryButton(
                    text: 'Tambah Halte',
                    icon: Icons.add_location_rounded,
                    onPressed: () {
                      if (formKey.currentState!.validate()) {
                        if (pickedLat == null || pickedLng == null) {
                          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                            content: const Text(
                                'Pilih lokasi halte di peta terlebih dahulu'),
                            backgroundColor: AppColors.pendingOrange,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ));
                          return;
                        }
                        widget.dataService
                            .createHalte(
                          namaHalte: namaCtrl.text.trim(),
                          latitude: pickedLat!,
                          longitude: pickedLng!,
                          alamat: alamatCtrl.text.trim(),
                        )
                            .then((ok) {
                          Navigator.pop(ctx);
                          if (!context.mounted) return;
                          if (ok) _refresh();
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(ok
                                ? 'Halte berhasil ditambahkan!'
                                : 'Gagal menambah halte'),
                            backgroundColor:
                                ok ? AppColors.primary : AppColors.red,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ));
                        });
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

  void _deleteHalte(HalteModel halte) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Halte',
            style:
                TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
        content: Text(
            'Hapus halte "${halte.namaHalte}"?'
            '\n\nHalte yang terhubung ke rute akan terputus.',
            style: const TextStyle(fontFamily: 'Poppins')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal',
                  style: TextStyle(
                      fontFamily: 'Poppins', color: AppColors.textGrey))),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.dataService
                  .deleteHalte(halte.idStr)
                  .then((_) => _refresh());
            },
            child: const Text('Hapus',
                style: TextStyle(
                    fontFamily: 'Poppins',
                    color: AppColors.red,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ── Bug 1 Fix: Edit halte sekarang memanggil API
  void _showEditHalteDialog(HalteModel halte) {
    final namaCtrl = TextEditingController(text: halte.namaHalte);
    final alamatCtrl = TextEditingController(text: halte.alamat);
    final formKey = GlobalKey<FormState>();
    double pickedLat = halte.latitude;
    double pickedLng = halte.longitude;

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
              borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
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
                              borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 20),
                  const Text('Ubah Data Halte',
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 20,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 20),
                  AppTextField(
                      label: 'Nama Halte',
                      controller: namaCtrl,
                      validator: (v) =>
                          v!.isEmpty ? 'Nama tidak boleh kosong' : null),
                  const SizedBox(height: 14),
                  // Bug 1 Fix: alamat field ada dan akan dikirim ke API
                  AppTextField(
                    label: 'Alamat (opsional)',
                    controller: alamatCtrl,
                  ),
                  const SizedBox(height: 14),
                  _LocationPickerField(
                    lat: pickedLat,
                    lng: pickedLng,
                    onPick: () async {
                      final result = await Navigator.push<PickedLocation>(
                        context,
                        MaterialPageRoute(
                            builder: (_) => HalteLocationPicker(
                                initialLat: pickedLat, initialLng: pickedLng)),
                      );
                      if (result != null)
                        setModal(() {
                          pickedLat = result.latitude;
                          pickedLng = result.longitude;
                          // Auto-isi alamat dari reverse geocode kalau field masih kosong
                          if (alamatCtrl.text.trim().isEmpty &&
                              result.namaAlamat != null) {
                            alamatCtrl.text = result.namaAlamat!;
                          }
                        });
                    },
                  ),
                  const SizedBox(height: 24),
                  PrimaryButton(
                    text: 'Simpan Perubahan',
                    icon: Icons.save_rounded,
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      Navigator.pop(ctx);
                      // Bug 1 Fix: panggil API, bukan hanya update lokal
                      final ok = await widget.dataService.updateHalte(
                        halte.idStr,
                        namaHalte: namaCtrl.text.trim(),
                        alamat: alamatCtrl.text.trim(),
                        latitude: pickedLat,
                        longitude: pickedLng,
                      );
                      if (!context.mounted) return;
                      if (ok) _refresh();
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(ok
                              ? 'Halte berhasil diperbarui'
                              : 'Gagal memperbarui halte'),
                          backgroundColor:
                              ok ? AppColors.primary : AppColors.red,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10))));
                    },
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final haltes = widget.dataService.haltes;

    // Bug 4 Fix: filter hanya berdasarkan nama/alamat — bukan rute fiktif
    List<HalteModel> filtered = haltes;
    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where((h) =>
              h.namaHalte.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              h.alamat.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Halte Bus',
            style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: AppColors.black)),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: TextButton.icon(
              onPressed: _showAddHalteDialog,
              icon:
                  const Icon(Icons.add_rounded, size: 16, color: Colors.white),
              label: const Text('Tambah',
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white)),
              style: TextButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Container(
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2))
                  ],
                ),
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: 'Cari nama atau alamat halte...',
                    hintStyle: TextStyle(
                        fontFamily: 'Poppins',
                        color: AppColors.textGrey,
                        fontSize: 13),
                    prefixIcon: Icon(Icons.search_rounded,
                        color: AppColors.textGrey, size: 20),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 13),
                  ),
                ),
              ),
            ),

            // Stats row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Row(children: [
                Expanded(
                  child: _StatChip(
                      label: 'TOTAL HALTE', value: '${haltes.length}'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatChip(
                      label: 'HASIL FILTER', value: '${filtered.length}'),
                ),
              ]),
            ),

            // Header list
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(children: [
                Icon(Icons.location_on_rounded,
                    color: AppColors.primary, size: 18),
                SizedBox(width: 6),
                Text('Daftar Halte',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.black)),
              ]),
            ),

            // Halte list
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.location_off_outlined,
                                  size: 64,
                                  color:
                                      AppColors.primary.withValues(alpha: 0.4)),
                              const SizedBox(height: 12),
                              Text(
                                _searchQuery.isEmpty
                                    ? 'Belum ada halte terdaftar'
                                    : 'Tidak ditemukan halte "$_searchQuery"',
                                style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 15,
                                    color: AppColors.textGrey),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                          itemCount: filtered.length,
                          itemBuilder: (_, i) {
                            final halte = filtered[i];
                            // Bug 5 Fix: tidak ada routeLabel fiktif
                            return _HalteCard(
                              halte: halte,
                              onDelete: () => _deleteHalte(halte),
                              onEdit: () => _showEditHalteDialog(halte),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;

  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textGrey,
                  letterSpacing: 0.5)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.black,
                  height: 1.1)),
        ],
      ),
    );
  }
}

// Bug 5 Fix: Hapus routeLabel dan routeColor — tidak ada relasi halte→rute di level ini
class _HalteCard extends StatelessWidget {
  final HalteModel halte;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _HalteCard({
    required this.halte,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Map preview
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: SizedBox(
              height: 120,
              child: AbsorbPointer(
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: LatLng(halte.latitude, halte.longitude),
                    initialZoom: 16.0,
                    interactionOptions:
                        const InteractionOptions(flags: InteractiveFlag.none),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      fallbackUrl:
                          'https://a.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.mobitra.app',
                      maxZoom: 19,
                      maxNativeZoom: 19,
                      additionalOptions: const {
                        'User-Agent':
                            'Mobitra/1.0 (school bus tracker; contact@mobitra.app)',
                      },
                    ),
                    MarkerLayer(markers: [
                      Marker(
                        point: LatLng(halte.latitude, halte.longitude),
                        width: 36,
                        height: 42,
                        alignment: Alignment.topCenter,
                        child: const Icon(Icons.location_pin,
                            color: AppColors.primary, size: 36),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          ),

          // Info
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        halte.namaHalte,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.black,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'ID #${halte.idStr.padLeft(4, '0')}',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    const Icon(Icons.location_on_rounded,
                        size: 13, color: AppColors.textGrey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        halte.alamat.isNotEmpty ? halte.alamat : '—',
                        style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            color: AppColors.textGrey),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.gps_fixed_rounded,
                      size: 12, color: AppColors.textGrey),
                  const SizedBox(width: 4),
                  Text(
                    '${halte.latitude.toStringAsFixed(5)}, '
                    '${halte.longitude.toStringAsFixed(5)}',
                    style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        color: AppColors.textGrey),
                  ),
                ]),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: onEdit,
                        child: Container(
                          height: 38,
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.lightGrey),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.edit_rounded,
                                  size: 15, color: AppColors.textGrey),
                              SizedBox(width: 6),
                              Text('Ubah',
                                  style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.black)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: onDelete,
                        child: Container(
                          height: 38,
                          decoration: BoxDecoration(
                            color: AppColors.red.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: AppColors.red.withValues(alpha: 0.2)),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.delete_rounded,
                                  size: 15, color: AppColors.red),
                              SizedBox(width: 6),
                              Text('Hapus',
                                  style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.red)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Location picker field ─────────────────────────────────────────────
class _LocationPickerField extends StatelessWidget {
  final double? lat;
  final double? lng;
  final VoidCallback onPick;

  const _LocationPickerField({required this.onPick, this.lat, this.lng});

  @override
  Widget build(BuildContext context) {
    final bool hasPicked = lat != null && lng != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Lokasi di Peta',
            style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textGrey)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onPick,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasPicked ? AppColors.primary : AppColors.lightGrey,
                width: hasPicked ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2))
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: hasPicked ? AppColors.primary : AppColors.lightGrey,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    hasPicked
                        ? Icons.location_on_rounded
                        : Icons.add_location_alt_rounded,
                    color: hasPicked ? Colors.white : AppColors.textGrey,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasPicked ? 'Lokasi sudah dipilih' : 'Belum ada lokasi',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color:
                              hasPicked ? AppColors.black : AppColors.textGrey,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasPicked
                            ? '${lat!.toStringAsFixed(5)}, ${lng!.toStringAsFixed(5)}'
                            : 'Tap untuk buka peta & pilih titik',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          color: hasPicked
                              ? AppColors.primary
                              : AppColors.textGrey,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: hasPicked
                        ? AppColors.primaryLight
                        : AppColors.lightGrey,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    hasPicked ? 'Ubah' : 'Pilih',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: hasPicked ? AppColors.primary : AppColors.textGrey,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
