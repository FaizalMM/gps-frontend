import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart' hide Path;
import '../../models/models_api.dart';
import '../../services/app_data_service.dart';
import '../../services/bus_service.dart';
import '../../services/domain_services.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/skeleton_widgets.dart';
import 'route_builder_screen.dart';

enum _BusFilter { all, active, maintenance, inactive, noDriver }

class AdminBusScreen extends StatefulWidget {
  final AppDataService dataService;
  const AdminBusScreen({super.key, required this.dataService});

  @override
  State<AdminBusScreen> createState() => _AdminBusScreenState();
}

class _AdminBusScreenState extends State<AdminBusScreen> {
  _BusFilter _filter = _BusFilter.all;
  String _searchQuery = '';

  // ── Dialog tambah bus
  void _showAddBusDialog() {
    final namaCtrl = TextEditingController();
    final platCtrl = TextEditingController();
    String? selectedDriverId;
    BusStatus selectedStatus = BusStatus.active;
    XFile? foto;
    final formKey = GlobalKey<FormState>();
    final drivers = widget.dataService.drivers;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) => _BusSheetWrap(
          title: 'Tambah Bus Baru',
          subtitle: 'Rute & halte dapat diatur setelah bus dibuat.',
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Foto Bus ──────────────────────────────────────
                Center(
                  child: GestureDetector(
                    onTap: () async {
                      final img = await ImagePicker().pickImage(
                          source: ImageSource.gallery, imageQuality: 75);
                      if (img != null) setM(() => foto = img);
                    },
                    child: _BusFotoPicker(foto: foto),
                  ),
                ),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6, bottom: 20),
                    child: Text(
                      foto != null
                          ? 'Ketuk untuk ganti foto'
                          : 'Ketuk untuk pilih foto bus (opsional)',
                      style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          color: AppColors.textGrey),
                    ),
                  ),
                ),
                AppTextField(
                  label: 'Kode Bus',
                  controller: namaCtrl,
                  validator: (v) => v!.isEmpty ? 'Kode bus wajib diisi' : null,
                ),
                const SizedBox(height: 12),
                AppTextField(
                  label: 'Plat Nomor',
                  controller: platCtrl,
                  validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
                ),
                const SizedBox(height: 12),
                const Text('Status',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textGrey)),
                const SizedBox(height: 6),
                _DropdownField<BusStatus>(
                  value: selectedStatus,
                  items: const [
                    DropdownMenuItem(
                        value: BusStatus.active,
                        child: Text('Aktif',
                            style: TextStyle(fontFamily: 'Poppins'))),
                    DropdownMenuItem(
                        value: BusStatus.maintenance,
                        child: Text('Perawatan',
                            style: TextStyle(fontFamily: 'Poppins'))),
                    DropdownMenuItem(
                        value: BusStatus.inactive,
                        child: Text('Nonaktif',
                            style: TextStyle(fontFamily: 'Poppins'))),
                  ],
                  onChanged: (v) => setM(() => selectedStatus = v!),
                ),
                if (drivers.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('Driver (opsional)',
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textGrey)),
                  const SizedBox(height: 6),
                  _DriverSearchField(
                    drivers: drivers,
                    selectedDriverId: selectedDriverId,
                    onChanged: (v) => setM(() => selectedDriverId = v),
                  ),
                ],
                const SizedBox(height: 24),
                PrimaryButton(
                  text: 'Tambah Bus',
                  icon: Icons.directions_bus_rounded,
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    final messenger = ScaffoldMessenger.of(context);
                    String statusStr = selectedStatus == BusStatus.maintenance
                        ? 'maintenance'
                        : selectedStatus == BusStatus.inactive
                            ? 'nonaktif'
                            : 'aktif';
                    final ok = await widget.dataService.createBus(
                      kodeBus: namaCtrl.text.trim(),
                      platNomor: platCtrl.text.trim(),
                      status: statusStr,
                    );
                    if (ok) {
                      await widget.dataService.loadAll();
                      final newBus = widget.dataService.buses
                          .where((b) => b.platNomor == platCtrl.text.trim())
                          .firstOrNull;
                      if (newBus != null) {
                        if (foto != null) {
                          await BusService()
                              .uploadBusPhoto(newBus.id, foto!.path);
                        }
                        if (selectedDriverId != null) {
                          final driver = drivers
                              .firstWhere((d) => d.idStr == selectedDriverId);
                          await BusService()
                              .assignDriverByUserId(newBus.id, driver);
                          await Future.delayed(
                              const Duration(milliseconds: 500));
                        }
                        await widget.dataService.loadAll();
                      }
                    }
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    if (!mounted) return;
                    setState(() {});
                    messenger.showSnackBar(SnackBar(
                      content: Text(
                          ok
                              ? 'Bus berhasil ditambahkan!'
                              : 'Gagal menambah bus',
                          style: const TextStyle(fontFamily: 'Poppins')),
                      backgroundColor: ok ? AppColors.primary : AppColors.red,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ));
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEditBusDialog(BusModel bus) {
    final namaCtrl = TextEditingController(text: bus.nama);
    final platCtrl = TextEditingController(text: bus.platNomor);
    String? selDriverId = bus.driverId.isEmpty ? null : bus.driverId;
    BusStatus selStatus = bus.status;
    XFile? foto;
    final formKey = GlobalKey<FormState>();
    final drivers = widget.dataService.drivers;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) => Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
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
                    const SizedBox(height: 18),
                    const Text('Edit Data Bus',
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 18,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 18),
                    // ── Foto Bus ──────────────────────────────────────
                    Center(
                      child: GestureDetector(
                        onTap: () async {
                          final img = await ImagePicker().pickImage(
                              source: ImageSource.gallery, imageQuality: 75);
                          if (img != null) setM(() => foto = img);
                        },
                        child: _BusFotoPicker(
                            foto: foto, existingUrl: bus.photoUrl),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Center(
                      child: Text(
                        foto != null
                            ? 'Foto baru terpilih'
                            : (bus.photoUrl != null && bus.photoUrl!.isNotEmpty)
                                ? 'Ketuk foto untuk mengganti'
                                : 'Ketuk untuk pilih foto bus (opsional)',
                        style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            color: AppColors.textGrey),
                      ),
                    ),
                    const SizedBox(height: 18),
                    AppTextField(
                      label: 'Kode Bus',
                      controller: namaCtrl,
                      validator: (v) =>
                          v!.isEmpty ? 'Kode bus wajib diisi' : null,
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      label: 'Plat Nomor',
                      controller: platCtrl,
                      validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
                    ),
                    const SizedBox(height: 12),
                    const Text('Status',
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textGrey)),
                    const SizedBox(height: 6),
                    _DropdownField<BusStatus>(
                      value: selStatus,
                      items: const [
                        DropdownMenuItem(
                            value: BusStatus.active,
                            child: Text('Aktif',
                                style: TextStyle(fontFamily: 'Poppins'))),
                        DropdownMenuItem(
                            value: BusStatus.maintenance,
                            child: Text('Perawatan',
                                style: TextStyle(fontFamily: 'Poppins'))),
                        DropdownMenuItem(
                            value: BusStatus.inactive,
                            child: Text('Nonaktif',
                                style: TextStyle(fontFamily: 'Poppins'))),
                      ],
                      onChanged: (v) => setM(() => selStatus = v!),
                    ),
                    const SizedBox(height: 12),
                    const Text('Driver',
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textGrey)),
                    const SizedBox(height: 6),
                    _DriverSearchField(
                      drivers: drivers,
                      selectedDriverId: selDriverId,
                      onChanged: (v) => setM(() => selDriverId = v),
                    ),

                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          if (!formKey.currentState!.validate()) return;
                          final messenger = ScaffoldMessenger.of(context);
                          String statusStr = selStatus == BusStatus.maintenance
                              ? 'maintenance'
                              : selStatus == BusStatus.inactive
                                  ? 'nonaktif'
                                  : 'aktif';
                          final ok = await widget.dataService.updateBus(
                            bus.idStr,
                            kodeBus: namaCtrl.text.trim(),
                            platNomor: platCtrl.text.trim(),
                            status: statusStr,
                          );
                          if (ok) {
                            try {
                              // Upload foto jika ada yang baru dipilih
                              if (foto != null) {
                                await BusService()
                                    .uploadBusPhoto(bus.id, foto!.path);
                              }
                              final driver = selDriverId != null
                                  ? drivers.cast<UserModel?>().firstWhere(
                                      (d) => d!.idStr == selDriverId,
                                      orElse: () => null)
                                  : null;
                              if (driver != null) {
                                await BusService()
                                    .assignDriverByUserId(bus.id, driver);
                              } else if (bus.driverId.isNotEmpty) {
                                await BusService().unassignDriver(bus.id);
                              }
                            } catch (_) {}
                            await Future.delayed(
                                const Duration(milliseconds: 500));
                            await widget.dataService.loadAll();
                          }
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);
                          if (!mounted) return;
                          setState(() {});
                          messenger.showSnackBar(SnackBar(
                            content: Text(
                                ok
                                    ? 'Bus berhasil diperbarui'
                                    : 'Gagal memperbarui',
                                style: const TextStyle(fontFamily: 'Poppins')),
                            backgroundColor:
                                ok ? AppColors.primary : AppColors.red,
                            behavior: SnackBarBehavior.floating,
                          ));
                        },
                        child: const Text('Simpan Perubahan',
                            style: TextStyle(
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.w700,
                                fontSize: 15)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _deleteBus(BusModel bus) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Bus?',
            style:
                TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
        content: Text(
            'Bus dengan kode "${bus.nama}" (${bus.platNomor}) beserta data rute dan siswa yang terhubung akan dihapus.',
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 13)),
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
                    borderRadius: BorderRadius.circular(8))),
            onPressed: () {
              Navigator.pop(ctx);
              widget.dataService
                  .deleteBus(bus.idStr)
                  .then((_) => setState(() {}));
            },
            child: const Text('Hapus',
                style: TextStyle(fontFamily: 'Poppins', color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
        title: const Text('Manajemen Bus',
            style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: AppColors.black)),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddBusDialog,
        backgroundColor: AppColors.primary,
        elevation: 4,
        child: const Icon(Icons.directions_bus_rounded, color: Colors.white),
      ),
      body: StreamBuilder<List<BusModel>>(
        stream: widget.dataService.busesStream,
        builder: (context, snapshot) {
          final allBuses = snapshot.data ?? widget.dataService.buses;
          final aktif =
              allBuses.where((b) => b.status == BusStatus.active).length;
          final maintenance =
              allBuses.where((b) => b.status == BusStatus.maintenance).length;

          List<BusModel> filtered = allBuses;
          if (_filter == _BusFilter.active) {
            filtered =
                allBuses.where((b) => b.status == BusStatus.active).toList();
          }
          if (_filter == _BusFilter.maintenance) {
            filtered = allBuses
                .where((b) => b.status == BusStatus.maintenance)
                .toList();
          }
          if (_filter == _BusFilter.inactive) {
            filtered =
                allBuses.where((b) => b.status == BusStatus.inactive).toList();
          }
          if (_filter == _BusFilter.noDriver) {
            filtered = allBuses.where((b) => b.driverName.isEmpty).toList();
          }
          if (_searchQuery.isNotEmpty) {
            filtered = filtered
                .where((b) =>
                    b.nama.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                    b.platNomor
                        .toLowerCase()
                        .contains(_searchQuery.toLowerCase()) ||
                    b.driverName
                        .toLowerCase()
                        .contains(_searchQuery.toLowerCase()))
                .toList();
          }

          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Container(
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white,
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
                    hintText: 'Cari kode bus, plat, atau driver...',
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  _Chip(
                      label: 'Semua (${allBuses.length})',
                      active: _filter == _BusFilter.all,
                      onTap: () => setState(() => _filter = _BusFilter.all)),
                  const SizedBox(width: 8),
                  _Chip(
                      label: 'Aktif ($aktif)',
                      active: _filter == _BusFilter.active,
                      dot: AppColors.primary,
                      onTap: () => setState(() => _filter = _BusFilter.active)),
                  const SizedBox(width: 8),
                  _Chip(
                      label: 'Perawatan ($maintenance)',
                      active: _filter == _BusFilter.maintenance,
                      dot: AppColors.orange,
                      onTap: () =>
                          setState(() => _filter = _BusFilter.maintenance)),
                  const SizedBox(width: 8),
                  _Chip(
                      label: 'Nonaktif',
                      active: _filter == _BusFilter.inactive,
                      dot: AppColors.textGrey,
                      onTap: () =>
                          setState(() => _filter = _BusFilter.inactive)),
                  const SizedBox(width: 8),
                  _Chip(
                      label:
                          'Tanpa Driver (${allBuses.where((b) => b.driverName.isEmpty).length})',
                      active: _filter == _BusFilter.noDriver,
                      dot: AppColors.orange,
                      onTap: () =>
                          setState(() => _filter = _BusFilter.noDriver)),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                          Icon(Icons.directions_bus_outlined,
                              size: 56,
                              color: AppColors.primary.withValues(alpha: 0.3)),
                          const SizedBox(height: 12),
                          const Text('Tidak ada bus ditemukan',
                              style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 14,
                                  color: AppColors.textGrey)),
                        ]))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final bus = filtered[i];
                        return _BusCard(
                          bus: bus,
                          onEdit: () => _showEditBusDialog(bus),
                          onDelete: () => _deleteBus(bus),
                          onAturRute: () async {
                            final nav = Navigator.of(context);
                            await widget.dataService.loadHaltes();
                            if (!mounted) return;
                            nav.push(MaterialPageRoute(
                                builder: (_) => BusRuteScreen(
                                    bus: bus,
                                    dataService: widget.dataService)));
                          },
                          onManageSiswa: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => BusSiswaScreen(
                                      bus: bus,
                                      dataService: widget.dataService))),
                        );
                      },
                    ),
            ),
          ]);
        },
      ),
    );
  }
}

class _BusCard extends StatelessWidget {
  final BusModel bus;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onAturRute;
  final VoidCallback onManageSiswa;

  const _BusCard({
    required this.bus,
    required this.onEdit,
    required this.onDelete,
    required this.onAturRute,
    required this.onManageSiswa,
  });

  @override
  Widget build(BuildContext context) {
    final Color statusColor;
    final String statusLabel;
    if (bus.status == BusStatus.maintenance) {
      statusColor = AppColors.orange;
      statusLabel = 'Perawatan';
    } else if (bus.status == BusStatus.inactive) {
      statusColor = AppColors.textGrey;
      statusLabel = 'Nonaktif';
    } else {
      statusColor = AppColors.primary;
      statusLabel = 'Aktif';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── Foto / Icon Bus ─────────────────────────────────
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: bus.photoUrl != null && bus.photoUrl!.isNotEmpty
                  ? Image.network(
                      bus.photoUrl!,
                      width: 54,
                      height: 54,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.directions_bus_rounded,
                            color: statusColor, size: 30),
                      ),
                    )
                  : Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.directions_bus_rounded,
                          color: statusColor, size: 30),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Row(children: [
                    Expanded(
                        child: Text(bus.nama,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 15,
                                fontWeight: FontWeight.w700))),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                                color: statusColor, shape: BoxShape.circle)),
                        const SizedBox(width: 4),
                        Text(statusLabel,
                            style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: statusColor)),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 3),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                          color: AppColors.surface2,
                          borderRadius: BorderRadius.circular(4)),
                      child: const Text('Kode Bus',
                          style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textGrey)),
                    ),
                  ]),
                  const SizedBox(height: 3),
                  Text(bus.platNomor,
                      style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: AppColors.textGrey)),
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.person_rounded,
                        size: 12, color: AppColors.textGrey),
                    const SizedBox(width: 4),
                    Expanded(
                        child: Text(
                      bus.driverName.isEmpty
                          ? 'Belum ada driver'
                          : bus.driverName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        color: bus.driverName.isEmpty
                            ? AppColors.textGrey
                            : AppColors.black,
                        fontStyle: bus.driverName.isEmpty
                            ? FontStyle.italic
                            : FontStyle.normal,
                      ),
                    )),
                  ]),
                ])),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded,
                  color: AppColors.textGrey, size: 20),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              onSelected: (v) {
                if (v == 'edit') onEdit();
                if (v == 'hapus') onDelete();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                    value: 'edit',
                    child: Row(children: [
                      Icon(Icons.edit_rounded,
                          size: 16, color: AppColors.primary),
                      SizedBox(width: 8),
                      Text('Edit Data Bus',
                          style: TextStyle(fontFamily: 'Poppins')),
                    ])),
                const PopupMenuItem(
                    value: 'hapus',
                    child: Row(children: [
                      Icon(Icons.delete_outline_rounded,
                          size: 16, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Hapus Bus',
                          style: TextStyle(
                              fontFamily: 'Poppins', color: Colors.red)),
                    ])),
              ],
            ),
          ]),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.lightGrey),
          const SizedBox(height: 10),
          Row(children: [
            // Atur Rute (tombol utama)
            Expanded(
              flex: 3,
              child: GestureDetector(
                onTap: onAturRute,
                child: Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.alt_route_rounded,
                            size: 15, color: Colors.white),
                        SizedBox(width: 6),
                        Text('Rute & Halte',
                            style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                      ]),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: GestureDetector(
                onTap: onManageSiswa,
                child: Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_rounded,
                            size: 15, color: AppColors.primary),
                        SizedBox(width: 5),
                        Text('Siswa',
                            style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary)),
                      ]),
                ),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}

// BusRuteScreen — Atur rute bus + lihat peta jalur

class BusRuteScreen extends StatefulWidget {
  final BusModel bus;
  final AppDataService dataService;
  const BusRuteScreen(
      {super.key, required this.bus, required this.dataService});

  @override
  State<BusRuteScreen> createState() => _BusRuteScreenState();
}

class _BusRuteScreenState extends State<BusRuteScreen> {
  final _routeService = RouteService();
  RouteModel? _route;
  bool _loading = true;
  bool _petaExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadRoute();
  }

  Future<void> _loadRoute() async {
    setState(() => _loading = true);
    // getRouteByBus → GET /buses/{id}/route
    final route = await _routeService.getRouteByBus(widget.bus.id);
    if (!mounted) return;
    setState(() {
      _route = route;
      _loading = false;
    });
  }

  Future<void> _buatRute() async {
    final result = await _routeService.createRoute(
      busId: widget.bus.id,
      namaRute: 'Rute ${widget.bus.nama}',
    );
    if (!mounted) return;
    if (result != null) {
      setState(() => _route = result);
      _bukaEditor(result);
    } else {
      _snack('Gagal membuat rute', isError: true);
    }
  }

  Future<void> _bukaEditor(RouteModel route) async {
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
              )),
    );
    if (result == null || !mounted) return;
    final updated = await _routeService.syncRoute(
      routeId: route.id,
      polyline: result.polylinePoints
          .map((p) => {'latitude': p.latitude, 'longitude': p.longitude})
          .toList(),
      halteIds: result.orderedHaltes.isNotEmpty
          ? result.orderedHaltes.map((h) => h.id).toList()
          : null,
    );
    if (!mounted) return;
    if (updated != null) {
      final km = result.distanceMeters > 0
          ? ' · ${(result.distanceMeters / 1000).toStringAsFixed(1)} km'
          : '';
      _snack('Rute tersimpan · ${result.orderedHaltes.length} halte$km');
      _loadRoute();
    } else {
      _snack('Gagal menyimpan rute', isError: true);
    }
  }

  Future<void> _hapusRute() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Rute?',
            style:
                TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
        content: const Text('Semua halte dan jalur rute ini akan dihapus.',
            style: TextStyle(fontFamily: 'Poppins', fontSize: 13)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal',
                  style: TextStyle(
                      fontFamily: 'Poppins', color: AppColors.textGrey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8))),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus',
                style: TextStyle(fontFamily: 'Poppins', color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final ok = await _routeService.deleteRoute(_route!.id);
    if (!mounted) return;
    if (ok) {
      setState(() => _route = null);
      _snack('Rute dihapus');
    }
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Poppins')),
      backgroundColor: isError ? Colors.red : AppColors.primary,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.bus.nama,
              style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w700,
                  fontSize: 16)),
          Text(widget.bus.platNomor,
              style: const TextStyle(
                  fontFamily: 'Poppins', fontSize: 11, color: Colors.white70)),
        ]),
      ),
      body: _loading
          ? const SkeletonFullPage()
          : RefreshIndicator(
              onRefresh: _loadRoute,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Belum ada rute
                      if (_route == null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.lightGrey),
                          ),
                          child: Column(children: [
                            Icon(Icons.alt_route_rounded,
                                size: 52,
                                color:
                                    AppColors.primary.withValues(alpha: 0.35)),
                            const SizedBox(height: 14),
                            const Text('Belum ada rute',
                                style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 6),
                            const Text(
                              'Buat rute untuk menentukan halte yang dilalui bus ini. Jalur akan tergambar otomatis di peta.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 12,
                                  color: AppColors.textGrey),
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.add_road_rounded,
                                    size: 18),
                                label: const Text('Buat Rute Bus Ini',
                                    style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontWeight: FontWeight.w700)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: _buatRute,
                              ),
                            ),
                          ]),
                        ),
                      ]

                      // ── Sudah ada rute
                      else ...[
                        _PetaRute(
                          route: _route!,
                          expanded: _petaExpanded,
                          onToggle: () =>
                              setState(() => _petaExpanded = !_petaExpanded),
                          onAturJalur: () => _bukaEditor(_route!),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
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
                                Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 14, 16, 0),
                                  child: Row(children: [
                                    const Text('Urutan Halte',
                                        style: TextStyle(
                                            fontFamily: 'Poppins',
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700)),
                                    const Spacer(),
                                    if (_route!.haltes.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryLight,
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                            '${_route!.haltes.length} halte',
                                            style: const TextStyle(
                                                fontFamily: 'Poppins',
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.primary)),
                                      ),
                                  ]),
                                ),

                                if (_route!.haltes.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Row(children: [
                                      Icon(Icons.warning_amber_rounded,
                                          size: 16, color: AppColors.orange),
                                      SizedBox(width: 8),
                                      Expanded(
                                          child: Text(
                                              'Belum ada halte. Tap "Ubah Rute" untuk menambah.',
                                              style: TextStyle(
                                                  fontFamily: 'Poppins',
                                                  fontSize: 12,
                                                  color: AppColors.orange))),
                                    ]),
                                  )
                                else
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        16, 10, 16, 4),
                                    child: Column(
                                      children: _route!.haltes
                                          .asMap()
                                          .entries
                                          .map((e) {
                                        final rh = e.value;
                                        final isFirst = rh.urutan == 1;
                                        final isLast =
                                            rh.urutan == _route!.haltes.length;
                                        final dotColor = isFirst
                                            ? Colors.green
                                            : isLast
                                                ? const Color(0xFFE53935)
                                                : const Color(0xFF1A73E8);

                                        return IntrinsicHeight(
                                          child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.stretch,
                                              children: [
                                                SizedBox(
                                                    width: 32,
                                                    child: Column(children: [
                                                      if (!isFirst)
                                                        Expanded(
                                                            child: Center(
                                                                child: Container(
                                                                    width: 2,
                                                                    color: AppColors
                                                                        .lightGrey))),
                                                      Container(
                                                          width: 26,
                                                          height: 26,
                                                          decoration: BoxDecoration(
                                                              color: dotColor,
                                                              shape: BoxShape
                                                                  .circle),
                                                          child: Center(
                                                              child: Text(
                                                                  '${rh.urutan}',
                                                                  style: const TextStyle(
                                                                      fontFamily:
                                                                          'Poppins',
                                                                      fontSize:
                                                                          11,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w800,
                                                                      color: Colors
                                                                          .white)))),
                                                      if (!isLast)
                                                        Expanded(
                                                            child: Center(
                                                                child: Container(
                                                                    width: 2,
                                                                    color: AppColors
                                                                        .lightGrey))),
                                                    ])),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                    child: Padding(
                                                  padding: const EdgeInsets
                                                      .symmetric(vertical: 8),
                                                  child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                            rh.halte?.namaHalte ??
                                                                'Halte #${rh.halteId}',
                                                            style: const TextStyle(
                                                                fontFamily:
                                                                    'Poppins',
                                                                fontSize: 13,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600)),
                                                        if (rh.halte?.alamat
                                                                .isNotEmpty ==
                                                            true)
                                                          Text(
                                                              rh.halte?.alamat ??
                                                                  '',
                                                              maxLines: 1,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                              style: const TextStyle(
                                                                  fontFamily:
                                                                      'Poppins',
                                                                  fontSize: 11,
                                                                  color: AppColors
                                                                      .textGrey)),
                                                      ]),
                                                )),
                                              ]),
                                        );
                                      }).toList(),
                                    ),
                                  ),

                                const Divider(
                                    height: 1, color: AppColors.lightGrey),

                                // Tombol ubah dan hapus
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(children: [
                                    Expanded(
                                      flex: 3,
                                      child: ElevatedButton.icon(
                                        icon: const Icon(
                                            Icons.edit_road_rounded,
                                            size: 16),
                                        label: const Text('Ubah Rute',
                                            style: TextStyle(
                                                fontFamily: 'Poppins',
                                                fontWeight: FontWeight.w700)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primary,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10)),
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 10),
                                        ),
                                        onPressed: () => _bukaEditor(_route!),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    OutlinedButton.icon(
                                      icon: const Icon(
                                          Icons.delete_outline_rounded,
                                          size: 16),
                                      label: const Text('Hapus',
                                          style:
                                              TextStyle(fontFamily: 'Poppins')),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.red,
                                        side:
                                            const BorderSide(color: Colors.red),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10)),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 10, horizontal: 12),
                                      ),
                                      onPressed: _hapusRute,
                                    ),
                                  ]),
                                ),
                              ]),
                        ),
                      ],

                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Icon(Icons.lightbulb_outline_rounded,
                                    size: 15, color: AppColors.primary),
                                SizedBox(width: 6),
                                Text('Cara membuat rute',
                                    style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary)),
                              ]),
                              SizedBox(height: 8),
                              Text(
                                '1. Pastikan halte sudah terdaftar di menu Halte\n'
                                '2. Tap "Buat Rute Bus Ini" (atau "Ubah Rute" jika sudah ada)\n'
                                '3. Pilih halte-halte yang dilalui bus, atur urutannya\n'
                                '4. Jalur di peta otomatis tergambar mengikuti jalan nyata',
                                style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 11,
                                    color: AppColors.primary,
                                    height: 1.6),
                              ),
                            ]),
                      ),
                    ]),
              ),
            ),
    );
  }
}

// ── Widget peta preview jalur rute
class _PetaRute extends StatefulWidget {
  final RouteModel route;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onAturJalur;

  const _PetaRute({
    required this.route,
    required this.expanded,
    required this.onToggle,
    required this.onAturJalur,
  });

  @override
  State<_PetaRute> createState() => _PetaRuteState();
}

class _PetaRuteState extends State<_PetaRute> {
  final _mapCtrl = MapController();

  @override
  void dispose() {
    _mapCtrl.dispose();
    super.dispose();
  }

  void _fitBounds(List<LatLng> pts) {
    if (pts.length < 2) {
      _mapCtrl.move(pts.first, 14);
      return;
    }
    _mapCtrl.fitCamera(CameraFit.bounds(
      bounds: LatLngBounds.fromPoints(pts),
      padding: const EdgeInsets.all(40),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final route = widget.route;
    final expanded = widget.expanded;
    final hasPolyline = route.polyline.isNotEmpty;
    final hasHaltes = route.haltes.isNotEmpty;
    final polylinePts = hasPolyline
        ? route.polyline.map((p) => LatLng(p.latitude, p.longitude)).toList()
        : <LatLng>[];
    final allPts = hasPolyline
        ? polylinePts
        : hasHaltes
            ? route.haltes
                .where((rh) => rh.halte != null && rh.halte!.latitude != 0)
                .map((rh) => LatLng(rh.halte!.latitude, rh.halte!.longitude))
                .toList()
            : <LatLng>[];
    final LatLng center = allPts.isNotEmpty
        ? allPts[allPts.length ~/ 2]
        : const LatLng(-7.6298, 111.5239);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(children: [
            const Icon(Icons.map_rounded, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(route.namaRute,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
            ),
            if (!hasPolyline)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('Belum ada jalur',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 10,
                        color: AppColors.orange,
                        fontWeight: FontWeight.w600)),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('${route.polyline.length} titik',
                    style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 10,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600)),
              ),
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(
                  expanded
                      ? Icons.fullscreen_exit_rounded
                      : Icons.fullscreen_rounded,
                  size: 20,
                  color: AppColors.textGrey),
              onPressed: () {
                widget.onToggle();
                // Re-fit setelah animasi selesai
                Future.delayed(const Duration(milliseconds: 350), () {
                  if (mounted && allPts.length >= 2) _fitBounds(allPts);
                });
              },
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
            ),
          ]),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOut,
          height: expanded ? 320 : 180,
          child: ClipRRect(
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(14)),
            child: !hasPolyline && !hasHaltes
                ? Container(
                    color: AppColors.surface2,
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.map_outlined,
                              size: 40,
                              color: AppColors.textGrey.withValues(alpha: 0.4)),
                          const SizedBox(height: 8),
                          const Text('Jalur belum diatur',
                              style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 13,
                                  color: AppColors.textGrey)),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                            ),
                            onPressed: widget.onAturJalur,
                            child: const Text('Atur Jalur',
                                style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontWeight: FontWeight.w600)),
                          ),
                        ]),
                  )
                : FlutterMap(
                    mapController: _mapCtrl,
                    options: MapOptions(
                      initialCenter: center,
                      initialZoom: 14,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                      ),
                      onMapReady: () {
                        if (allPts.length >= 2) {
                          Future.delayed(const Duration(milliseconds: 100), () {
                            if (mounted) _fitBounds(allPts);
                          });
                        }
                      },
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
                      if (hasPolyline)
                        PolylineLayer(polylines: [
                          Polyline(
                              points: polylinePts,
                              color: const Color(0xFF1A73E8)
                                  .withValues(alpha: 0.2),
                              strokeWidth: 12),
                          Polyline(
                              points: polylinePts,
                              color: const Color(0xFF1A73E8),
                              strokeWidth: 5),
                        ]),
                      if (hasHaltes)
                        MarkerLayer(
                            markers: route.haltes
                                .where((rh) =>
                                    rh.halte != null && rh.halte!.latitude != 0)
                                .map((rh) {
                          final isFirst = rh.urutan == 1;
                          final isLast = rh.urutan == route.haltes.length;
                          final warna = isFirst
                              ? Colors.green
                              : isLast
                                  ? const Color(0xFFE53935)
                                  : const Color(0xFF1A73E8);
                          return Marker(
                            point:
                                LatLng(rh.halte!.latitude, rh.halte!.longitude),
                            width: 32,
                            height: 38,
                            alignment: Alignment.topCenter,
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: warna,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: Colors.white, width: 2),
                                    ),
                                    child: Center(
                                        child: Text('${rh.urutan}',
                                            style: const TextStyle(
                                                fontFamily: 'Poppins',
                                                fontSize: 10,
                                                fontWeight: FontWeight.w800,
                                                color: Colors.white))),
                                  ),
                                  Container(width: 2, height: 6, color: warna),
                                ]),
                          );
                        }).toList()),
                    ],
                  ),
          ),
        ),
      ]),
    );
  }
}

class BusSiswaScreen extends StatefulWidget {
  final BusModel bus;
  final AppDataService dataService;
  const BusSiswaScreen(
      {super.key, required this.bus, required this.dataService});

  @override
  State<BusSiswaScreen> createState() => _BusSiswaScreenState();
}

class _BusSiswaScreenState extends State<BusSiswaScreen> {
  List<UserModel> _siswa = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await BusService().getBusStudents(widget.bus.id);
    if (mounted) {
      setState(() {
        _siswa = list;
        _loading = false;
      });
    }
  }

  void _showAssignDialog() {
    final allSiswa = widget.dataService.siswaList
        .where((s) => s.status == AccountStatus.active)
        .toList();
    final inBusIds = _siswa.map((s) => s.id).toSet();
    final available = allSiswa.where((s) => !inBusIds.contains(s.id)).toList();
    final haltes = widget.dataService.haltes;

    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Semua siswa aktif sudah di-assign ke bus',
            style: TextStyle(fontFamily: 'Poppins')),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    UserModel? selSiswa;
    HalteModel? selHalte;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) => Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
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
                  const SizedBox(height: 16),
                  Text('Tambah Siswa ke ${widget.bus.nama}',
                      style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 17,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  const Text('Pilih siswa dan halte tempat dijemput',
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: AppColors.textGrey)),
                  const SizedBox(height: 16),
                  const Text('Siswa',
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textGrey)),
                  const SizedBox(height: 6),
                  _DropdownField<UserModel?>(
                    value: selSiswa,
                    hint: 'Pilih siswa...',
                    items: available
                        .map((s) => DropdownMenuItem(
                            value: s,
                            child: Text(s.namaLengkap,
                                style: const TextStyle(fontFamily: 'Poppins'))))
                        .toList(),
                    onChanged: (v) => setM(() => selSiswa = v),
                  ),
                  if (haltes.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text('Halte Penjemputan',
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textGrey)),
                    const SizedBox(height: 6),
                    _DropdownField<HalteModel?>(
                      value: selHalte,
                      hint: 'Pilih halte...',
                      items: haltes
                          .map((h) => DropdownMenuItem(
                              value: h,
                              child: Text(h.namaHalte,
                                  style:
                                      const TextStyle(fontFamily: 'Poppins'))))
                          .toList(),
                      onChanged: (v) => setM(() => selHalte = v),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        if (selSiswa == null) {
                          ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                              content: Text('Pilih siswa terlebih dahulu',
                                  style: TextStyle(fontFamily: 'Poppins')),
                              behavior: SnackBarBehavior.floating));
                          return;
                        }
                        final messenger = ScaffoldMessenger.of(context);
                        final nav = Navigator.of(ctx);
                        final studentId =
                            selSiswa!.studentDetail?.id ?? selSiswa!.id;
                        final halteId = selHalte?.id ??
                            (haltes.isNotEmpty ? haltes.first.id : 0);
                        final ok = await BusService().assignStudentToBus(
                            widget.bus.id, studentId, halteId);
                        if (!mounted) return;
                        nav.pop();
                        messenger.showSnackBar(SnackBar(
                          content: Text(
                              ok
                                  ? '${selSiswa!.namaLengkap} berhasil ditambahkan'
                                  : 'Gagal — siswa mungkin sudah di bus lain',
                              style: const TextStyle(fontFamily: 'Poppins')),
                          backgroundColor:
                              ok ? AppColors.primary : AppColors.red,
                          behavior: SnackBarBehavior.floating,
                        ));
                        if (ok) _load();
                      },
                      child: const Text('Tambahkan ke Bus',
                          style: TextStyle(
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w700,
                              fontSize: 15)),
                    ),
                  ),
                ]),
          ),
        ),
      ),
    );
  }

  void _showSiswaDetail(UserModel s) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _SiswaDetailSheet(
          siswa: s,
          onRemove: () {
            Navigator.pop(context);
            _removeSiswa(s);
          }),
    );
  }

  Future<void> _removeSiswa(UserModel s) async {
    final studentId = s.studentDetail?.id ?? s.id;
    final ok =
        await BusService().removeStudentFromBus(widget.bus.id, studentId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
          ok ? '${s.namaLengkap} dihapus dari bus' : 'Gagal menghapus',
          style: const TextStyle(fontFamily: 'Poppins')),
      backgroundColor: ok ? AppColors.primary : AppColors.red,
      behavior: SnackBarBehavior.floating,
    ));
    if (ok) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Siswa — ${widget.bus.nama}',
              style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 15,
                  fontWeight: FontWeight.w700)),
          Text(widget.bus.platNomor,
              style: const TextStyle(
                  fontFamily: 'Poppins', fontSize: 11, color: Colors.white70)),
        ]),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: TextButton.icon(
              onPressed: _showAssignDialog,
              icon: const Icon(Icons.person_add_rounded,
                  size: 15, color: Colors.white),
              label: const Text('Tambah',
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white)),
              style: TextButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const SkeletonFullPage()
          : RefreshIndicator(
              onRefresh: _load,
              child: _siswa.isEmpty
                  ? const Center(
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                          Icon(Icons.people_outline_rounded,
                              size: 56, color: AppColors.textGrey),
                          SizedBox(height: 12),
                          Text('Belum ada siswa di bus ini',
                              style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 14,
                                  color: AppColors.textGrey)),
                          SizedBox(height: 6),
                          Text('Tap "+ Tambah" untuk assign siswa',
                              style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 12,
                                  color: AppColors.textGrey)),
                        ]))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _siswa.length,
                      itemBuilder: (_, i) {
                        final s = _siswa[i];
                        final hasPhoto =
                            s.photoUrl != null && s.photoUrl!.isNotEmpty;
                        return GestureDetector(
                          onTap: () => _showSiswaDetail(s),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2))
                              ],
                            ),
                            child: Row(children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                    color: AppColors.primaryLight,
                                    shape: BoxShape.circle,
                                    image: hasPhoto
                                        ? DecorationImage(
                                            image: NetworkImage(s.photoUrl!),
                                            fit: BoxFit.cover)
                                        : null),
                                child: hasPhoto
                                    ? null
                                    : Center(
                                        child: Text(
                                            s.namaLengkap.isNotEmpty
                                                ? s.namaLengkap[0].toUpperCase()
                                                : '?',
                                            style: const TextStyle(
                                                fontFamily: 'Poppins',
                                                fontSize: 18,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.primary))),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    Text(s.namaLengkap,
                                        style: const TextStyle(
                                            fontFamily: 'Poppins',
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 2),
                                    Text('NIS: ${s.studentDetail?.nis ?? '-'}',
                                        style: const TextStyle(
                                            fontFamily: 'Poppins',
                                            fontSize: 11,
                                            color: AppColors.textGrey)),
                                    if ((s.studentDetail?.sekolah ?? '')
                                            .isNotEmpty ||
                                        (s.studentDetail?.kelas ?? '')
                                            .isNotEmpty)
                                      Text(
                                        [
                                          if ((s.studentDetail?.kelas ?? '')
                                              .isNotEmpty)
                                            s.studentDetail!.kelas,
                                          if ((s.studentDetail?.sekolah ?? '')
                                              .isNotEmpty)
                                            s.studentDetail!.sekolah,
                                        ].join(' • '),
                                        style: const TextStyle(
                                            fontFamily: 'Poppins',
                                            fontSize: 11,
                                            color: AppColors.textGrey),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ])),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.info_outline_rounded,
                                      size: 16, color: AppColors.textGrey),
                                  const SizedBox(height: 4),
                                  GestureDetector(
                                    onTap: () => _removeSiswa(s),
                                    child: const Icon(
                                        Icons.person_remove_rounded,
                                        color: AppColors.red,
                                        size: 18),
                                  ),
                                ],
                              ),
                            ]),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool active;
  final Color? dot;
  final VoidCallback onTap;
  const _Chip(
      {required this.label,
      required this.active,
      required this.onTap,
      this.dot});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color:
              active ? AppColors.primary.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border:
              active ? Border.all(color: AppColors.primary, width: 1.5) : null,
          boxShadow: [
            if (!active)
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2))
          ],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (dot != null) ...[
            Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
            const SizedBox(width: 5),
          ],
          Text(label,
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: active ? AppColors.primary : AppColors.black)),
        ]),
      ),
    );
  }
}

// ── _BusFotoPicker ────────────────────────────────────────────────────────────
class _BusFotoPicker extends StatelessWidget {
  final XFile? foto;
  final String? existingUrl;
  const _BusFotoPicker({this.foto, this.existingUrl});

  @override
  Widget build(BuildContext context) {
    Widget inner;
    if (foto != null) {
      inner = ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.file(File(foto!.path), fit: BoxFit.cover),
      );
    } else if (existingUrl != null && existingUrl!.isNotEmpty) {
      inner = ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.network(
          existingUrl!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(Icons.directions_bus_rounded,
              size: 42, color: AppColors.primary),
        ),
      );
    } else {
      inner = const Icon(Icons.directions_bus_rounded,
          size: 42, color: AppColors.primary);
    }

    return Stack(children: [
      Container(
        width: 90,
        height: 90,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: AppColors.primaryLight,
          border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.25), width: 2),
        ),
        child: inner,
      ),
      Positioned(
        bottom: 0,
        right: 0,
        child: Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
              shape: BoxShape.circle, color: AppColors.primary),
          child: const Icon(Icons.camera_alt_rounded,
              size: 15, color: Colors.white),
        ),
      ),
    ]);
  }
}

// ── Sheet Wrapper (konsisten dengan driver screen) ─────────────
class _BusSheetWrap extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  const _BusSheetWrap(
      {required this.title, this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
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
                    borderRadius: BorderRadius.circular(2)),
              )),
              const SizedBox(height: 20),
              Text(title,
                  style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 20,
                      fontWeight: FontWeight.w700)),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!,
                    style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        color: AppColors.textGrey)),
              ],
              const SizedBox(height: 20),
              child,
            ],
          ),
        ),
      );
}

class _DropdownField<T> extends StatelessWidget {
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String? hint;
  const _DropdownField(
      {required this.value,
      required this.items,
      required this.onChanged,
      this.hint});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.lightGrey),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          isExpanded: true,
          value: value,
          hint: hint != null
              ? Text(hint!,
                  style: const TextStyle(
                      fontFamily: 'Poppins', color: AppColors.textGrey))
              : null,
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _SiswaDetailSheet extends StatelessWidget {
  final UserModel siswa;
  final VoidCallback onRemove;

  const _SiswaDetailSheet({required this.siswa, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final d = siswa.studentDetail;
    final hasPhoto = siswa.photoUrl != null && siswa.photoUrl!.isNotEmpty;
    final bottom = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 0, 20, bottom + 20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: 12),
          width: 36,
          height: 4,
          decoration: BoxDecoration(
              color: AppColors.lightGrey,
              borderRadius: BorderRadius.circular(2)),
        ),
        Row(children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              shape: BoxShape.circle,
              image: hasPhoto
                  ? DecorationImage(
                      image: NetworkImage(siswa.photoUrl!), fit: BoxFit.cover)
                  : null,
            ),
            child: hasPhoto
                ? null
                : Center(
                    child: Text(
                        siswa.namaLengkap.isNotEmpty
                            ? siswa.namaLengkap[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(siswa.namaLengkap,
                  style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
              Text(siswa.email,
                  style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: AppColors.textGrey)),
            ]),
          ),
        ]),
        const SizedBox(height: 16),
        const Divider(height: 1, color: AppColors.lightGrey),
        const SizedBox(height: 14),
        _DetailRow(
            icon: Icons.badge_rounded, label: 'NIS', value: d?.nis ?? '-'),
        const SizedBox(height: 8),
        _DetailRow(
            icon: Icons.class_rounded, label: 'Kelas', value: d?.kelas ?? '-'),
        const SizedBox(height: 8),
        _DetailRow(
            icon: Icons.school_rounded,
            label: 'Sekolah',
            value: d?.sekolah ?? '-'),
        const SizedBox(height: 8),
        _DetailRow(
            icon: Icons.phone_rounded,
            label: 'No. HP',
            value: siswa.noHp.isNotEmpty ? siswa.noHp : '-'),
        const SizedBox(height: 8),
        _DetailRow(
            icon: Icons.location_on_rounded,
            label: 'Alamat',
            value: siswa.alamat.isNotEmpty ? siswa.alamat : '-'),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onRemove,
            icon: const Icon(Icons.person_remove_rounded, size: 16),
            label: const Text('Hapus dari Bus',
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.red,
              side: const BorderSide(color: AppColors.red),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ]),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 16, color: AppColors.textGrey),
      const SizedBox(width: 10),
      SizedBox(
          width: 70,
          child: Text(label,
              style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  color: AppColors.textGrey))),
      Expanded(
          child: Text(value,
              style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis)),
    ]);
  }
}

class _DriverSearchField extends StatefulWidget {
  final List<UserModel> drivers;
  final String? selectedDriverId;
  final ValueChanged<String?> onChanged;

  const _DriverSearchField({
    required this.drivers,
    required this.selectedDriverId,
    required this.onChanged,
  });

  @override
  State<_DriverSearchField> createState() => _DriverSearchFieldState();
}

class _DriverSearchFieldState extends State<_DriverSearchField> {
  final _ctrl = TextEditingController();
  bool _open = false;
  List<UserModel> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.drivers;
    final sel = widget.drivers
        .where((d) => d.idStr == widget.selectedDriverId)
        .firstOrNull;
    if (sel != null) _ctrl.text = sel.namaLengkap;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _filter(String q) {
    setState(() {
      _filtered = q.isEmpty
          ? widget.drivers
          : widget.drivers
              .where((d) =>
                  d.namaLengkap.toLowerCase().contains(q.toLowerCase()) ||
                  d.email.toLowerCase().contains(q.toLowerCase()))
              .toList();
    });
  }

  void _select(UserModel? driver) {
    setState(() {
      _open = false;
      _ctrl.text = driver?.namaLengkap ?? '';
    });
    widget.onChanged(driver?.idStr);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() {
            _open = !_open;
            if (_open) _filtered = widget.drivers;
          }),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: _open ? AppColors.primary : AppColors.lightGrey,
                  width: _open ? 1.5 : 1),
            ),
            child: Row(children: [
              const Icon(Icons.person_rounded,
                  size: 16, color: AppColors.textGrey),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _ctrl.text.isEmpty ? '— Tanpa Driver —' : _ctrl.text,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    color: _ctrl.text.isEmpty
                        ? AppColors.textGrey
                        : AppColors.black,
                  ),
                ),
              ),
              Icon(
                  _open
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: AppColors.textGrey,
                  size: 18),
            ]),
          ),
        ),
        if (_open) ...[
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.lightGrey),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2))
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: TextField(
                    controller: _ctrl,
                    onChanged: _filter,
                    autofocus: true,
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Cari nama atau email driver...',
                      hintStyle: const TextStyle(
                          fontFamily: 'Poppins',
                          color: AppColors.textGrey,
                          fontSize: 12),
                      prefixIcon: const Icon(Icons.search_rounded,
                          color: AppColors.textGrey, size: 18),
                      isDense: true,
                      filled: true,
                      fillColor: AppColors.surface2,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                  ),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(bottom: 8),
                    children: [
                      ListTile(
                        dense: true,
                        leading: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                              color: AppColors.surface2,
                              borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.person_off_rounded,
                              size: 16, color: AppColors.textGrey),
                        ),
                        title: const Text('— Tanpa Driver —',
                            style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 13,
                                color: AppColors.textGrey)),
                        onTap: () => _select(null),
                      ),
                      ..._filtered.map((d) => ListTile(
                            dense: true,
                            leading: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                  color: AppColors.primaryLight,
                                  borderRadius: BorderRadius.circular(8)),
                              child: Center(
                                child: Text(
                                  d.namaLengkap.isNotEmpty
                                      ? d.namaLengkap[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: AppColors.primary),
                                ),
                              ),
                            ),
                            title: Text(d.namaLengkap,
                                style: const TextStyle(
                                    fontFamily: 'Poppins', fontSize: 13)),
                            subtitle: Text(d.email,
                                style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 11,
                                    color: AppColors.textGrey)),
                            selected: d.idStr == widget.selectedDriverId,
                            selectedTileColor: AppColors.primaryLight,
                            onTap: () => _select(d),
                          )),
                      if (_filtered.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(
                              child: Text('Driver tidak ditemukan',
                                  style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 13,
                                      color: AppColors.textGrey))),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
