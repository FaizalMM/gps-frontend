import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart'; // ✅ TAMBAHAN: import url_launcher
import '../../models/models_api.dart';
import '../../services/app_data_service.dart';
import '../../services/domain_services.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';

// ── Buka WhatsApp

Future<void> _bukaWhatsApp(String noHp) async {
  String n = noHp.replaceAll(RegExp(r'[\s\-+]'), '');
  if (n.startsWith('0')) n = '62${n.substring(1)}';
  if (!n.startsWith('62')) n = '62$n';
  final uri = Uri.parse('https://wa.me/$n');
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } else {
    // Fallback: salin ke clipboard jika WhatsApp tidak terinstall
    await Clipboard.setData(ClipboardData(text: noHp));
  }
}

class AdminDriverScreen extends StatefulWidget {
  final AppDataService dataService;
  const AdminDriverScreen({super.key, required this.dataService});
  @override
  State<AdminDriverScreen> createState() => _AdminDriverScreenState();
}

class _AdminDriverScreenState extends State<AdminDriverScreen> {
  final _searchCtrl = TextEditingController();
  String _filterMode = 'semua'; // semua | online | offline
  String _sortBy = 'name';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  bool _isOnline(UserModel d) {
    final bus = widget.dataService.getDriverBus(d.idStr);
    return bus?.gpsActive == true;
  }

  // ── Filter & sort
  List<UserModel> _filtered(List<UserModel> all) {
    var list = all.where((u) => u.role == UserRole.driver).toList();

    if (_filterMode == 'online') {
      list = list.where(_isOnline).toList();
    } else if (_filterMode == 'offline') {
      list = list.where((d) => !_isOnline(d)).toList();
    }

    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list
          .where((d) =>
              d.namaLengkap.toLowerCase().contains(q) ||
              d.email.toLowerCase().contains(q))
          .toList();
    }

    if (_sortBy == 'name') {
      list.sort((a, b) => a.namaLengkap.compareTo(b.namaLengkap));
    } else {
      list.sort((a, b) => (_isOnline(b) ? 1 : 0) - (_isOnline(a) ? 1 : 0));
    }
    return list;
  }

  // ── Snackbar
  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Poppins')),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // ── Hubungi driver via WA
  void _hubungi(UserModel driver) {
    if (driver.noHp.isEmpty) {
      _snack('No. HP ${driver.namaLengkap} belum diisi', AppColors.red);
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SheetWrap(
        title: 'Hubungi ${driver.namaLengkap}',
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(driver.noHp,
              style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 18,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon:
                  const Icon(Icons.chat_rounded, color: Colors.white, size: 18),
              label: const Text('Buka WhatsApp',
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                      color: Colors.white)),
              onPressed: () async {
                Navigator.pop(ctx);
                await _bukaWhatsApp(
                    driver.noHp); //  Sekarang membuka WA langsung
                if (mounted)
                  _snack('Membuka WhatsApp...', const Color(0xFF25D366));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.copy_rounded,
                  size: 16, color: AppColors.primary),
              label: const Text('Salin Nomor',
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500)),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: driver.noHp));
                Navigator.pop(ctx);
                _snack('Nomor disalin: ${driver.noHp}', AppColors.primary);
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Dialog Tambah
  void _showAdd() {
    final namaC = TextEditingController();
    final emailC = TextEditingController();
    final hpC = TextEditingController();
    final alamatC = TextEditingController();
    final passC = TextEditingController();
    final nikC = TextEditingController();
    final key = GlobalKey<FormState>();
    XFile? foto;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => _SheetWrap(
          title: 'Tambah Akun Driver',
          child: Form(
            key: key,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: GestureDetector(
                    onTap: () async {
                      final img = await ImagePicker().pickImage(
                          source: ImageSource.gallery, imageQuality: 75);
                      if (img != null) set(() => foto = img);
                    },
                    child: _FotoPicker(foto: foto),
                  ),
                ),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6, bottom: 20),
                    child: Text(
                      foto != null
                          ? 'Ketuk untuk ganti foto'
                          : 'Ketuk untuk pilih foto profil',
                      style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          color: AppColors.textGrey),
                    ),
                  ),
                ),
                AppTextField(
                    label: 'Nama Lengkap',
                    controller: namaC,
                    validator: (v) => v!.isEmpty ? 'Wajib diisi' : null),
                const SizedBox(height: 12),
                AppTextField(
                    label: 'Email',
                    controller: emailC,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v!.isEmpty) return 'Wajib diisi';
                      if (!v.contains('@')) return 'Format tidak valid';
                      return null;
                    }),
                const SizedBox(height: 12),
                AppTextField(
                    label: 'No. HP (WhatsApp)',
                    controller: hpC,
                    keyboardType: TextInputType.phone),
                const SizedBox(height: 12),
                AppTextField(
                    label: 'NIK (KTP)',
                    controller: nikC,
                    validator: (v) => v!.isEmpty ? 'Wajib diisi' : null),
                const SizedBox(height: 12),
                AppTextField(label: 'Alamat', controller: alamatC),
                const SizedBox(height: 12),
                AppTextField(
                    label: 'Password',
                    controller: passC,
                    obscureText: true,
                    validator: (v) {
                      if (v!.isEmpty) return 'Wajib diisi';
                      if (v.length < 6) return 'Min 6 karakter';
                      return null;
                    }),
                const SizedBox(height: 24),
                PrimaryButton(
                  text: 'Buat Akun Driver',
                  icon: Icons.person_add_rounded,
                  onPressed: () {
                    if (key.currentState!.validate()) {
                      DriverService()
                          .createDriver(
                        nama: namaC.text.trim(),
                        email: emailC.text.trim(),
                        password: passC.text,
                        nik: nikC.text.trim(),
                        noHp: hpC.text.trim(),
                        alamat: alamatC.text.trim(),
                      )
                          .then((ok) async {
                        if (ok) await widget.dataService.loadDrivers();
                        Navigator.pop(ctx);
                        if (!mounted) return;
                        setState(() {});
                        _snack(
                          ok
                              ? 'Akun driver berhasil dibuat'
                              : 'Gagal membuat akun',
                          ok ? AppColors.primary : AppColors.red,
                        );
                      });
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Dialog Edit
  void _showEdit(UserModel driver) {
    final namaC = TextEditingController(text: driver.namaLengkap);
    final hpC = TextEditingController(text: driver.noHp);
    final alamatC = TextEditingController(text: driver.alamat);
    final nikC = TextEditingController(text: driver.driverDetail?.nik ?? '');
    final key = GlobalKey<FormState>();
    XFile? foto;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => _SheetWrap(
          title: 'Ubah Data Driver',
          child: Form(
            key: key,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: GestureDetector(
                    onTap: () async {
                      final img = await ImagePicker().pickImage(
                          source: ImageSource.gallery, imageQuality: 75);
                      if (img != null) set(() => foto = img);
                    },
                    child:
                        _FotoPicker(foto: foto, existingUrl: driver.photoUrl),
                  ),
                ),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6, bottom: 20),
                    child: Text(
                      foto != null
                          ? 'Foto baru terpilih'
                          : 'Ketuk foto untuk mengganti',
                      style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          color: AppColors.textGrey),
                    ),
                  ),
                ),
                AppTextField(
                    label: 'Nama Lengkap',
                    controller: namaC,
                    validator: (v) => v!.isEmpty ? 'Wajib diisi' : null),
                const SizedBox(height: 12),
                AppTextField(
                    label: 'No. HP (WhatsApp)',
                    controller: hpC,
                    keyboardType: TextInputType.phone),
                const SizedBox(height: 12),
                AppTextField(
                    label: 'NIK (KTP)',
                    controller: nikC,
                    validator: (v) => v!.isEmpty ? 'Wajib diisi' : null),
                const SizedBox(height: 12),
                AppTextField(label: 'Alamat', controller: alamatC),
                const SizedBox(height: 24),
                PrimaryButton(
                  text: 'Simpan Perubahan',
                  icon: Icons.save_rounded,
                  onPressed: () {
                    if (key.currentState!.validate()) {
                      final data = <String, dynamic>{
                        'name': namaC.text.trim(),
                        'no_hp': hpC.text.trim(),
                        'alamat': alamatC.text.trim(),
                        if (nikC.text.trim().isNotEmpty)
                          'nik': nikC.text.trim(),
                      };
                      DriverService()
                          .updateDriver(driver.id, data)
                          .then((ok) async {
                        if (ok) await widget.dataService.loadDrivers();
                        Navigator.pop(ctx);
                        if (!mounted) return;
                        setState(() {});
                        _snack(
                          ok ? 'Data driver diperbarui' : 'Gagal memperbarui',
                          ok ? AppColors.primary : AppColors.red,
                        );
                      });
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _hapus(UserModel driver) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Driver',
            style:
                TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
        content: Text(
            'Hapus akun ${driver.namaLengkap}? Tindakan ini tidak dapat dibatalkan.',
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal',
                style: TextStyle(
                    fontFamily: 'Poppins', color: AppColors.textGrey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.dataService
                  .deleteUser(driver.idStr)
                  .then((_) => setState(() {}));
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

  // ── Sort sheet
  void _showSort() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SheetWrap(
        title: 'Urutkan',
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _SortOpt('Nama (A-Z)', 'name', _sortBy, (v) {
            setState(() => _sortBy = v);
            Navigator.pop(ctx);
          }),
          const SizedBox(height: 8),
          _SortOpt('Online dahulu', 'status', _sortBy, (v) {
            setState(() => _sortBy = v);
            Navigator.pop(ctx);
          }),
        ]),
      ),
    );
  }

  // ── BUILD
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Kelola Driver',
            style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: AppColors.black)),
        centerTitle: true,
      ),
      body: StreamBuilder<List<UserModel>>(
        stream: widget.dataService.usersStream,
        builder: (context, snap) {
          final all = snap.data ?? widget.dataService.users;
          final drivers = all.where((u) => u.role == UserRole.driver).toList();
          final onlineCount = drivers.where(_isOnline).length;
          final offlineCount = drivers.length - onlineCount;
          final list = _filtered(all);

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 90),
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: list.isEmpty ? 2 : list.length + 1,
                  itemBuilder: (_, i) {
                    if (i == 0) {
                      return Container(
                        color: Colors.white,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Search bar
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                              child: Container(
                                height: 44,
                                decoration: BoxDecoration(
                                  color: AppColors.surface2,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: TextField(
                                  controller: _searchCtrl,
                                  onChanged: (_) => setState(() {}),
                                  style: const TextStyle(
                                      fontFamily: 'Poppins', fontSize: 13),
                                  decoration: InputDecoration(
                                    hintText: 'Cari nama atau ID bus...',
                                    hintStyle: const TextStyle(
                                        fontFamily: 'Poppins',
                                        color: AppColors.textGrey,
                                        fontSize: 12),
                                    prefixIcon: const Icon(Icons.search_rounded,
                                        color: AppColors.textGrey, size: 20),
                                    suffixIcon: _searchCtrl.text.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(
                                                Icons.close_rounded,
                                                size: 18,
                                                color: AppColors.textGrey),
                                            onPressed: () {
                                              _searchCtrl.clear();
                                              setState(() {});
                                            })
                                        : null,
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    isDense: true,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            // Filter chips
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: Row(children: [
                                _Chip(
                                  label: 'Semua',
                                  count: drivers.length,
                                  active: _filterMode == 'semua',
                                  onTap: () =>
                                      setState(() => _filterMode = 'semua'),
                                ),
                                const SizedBox(width: 8),
                                _Chip(
                                  label: 'Online',
                                  count: onlineCount,
                                  active: _filterMode == 'online',
                                  onTap: () =>
                                      setState(() => _filterMode = 'online'),
                                ),
                                const SizedBox(width: 8),
                                _Chip(
                                  label: 'Offline',
                                  count: offlineCount,
                                  active: _filterMode == 'offline',
                                  onTap: () =>
                                      setState(() => _filterMode = 'offline'),
                                ),
                              ]),
                            ),
                            const SizedBox(height: 10),
                            const Divider(
                                height: 0.5,
                                thickness: 0.5,
                                color: AppColors.lightGrey),
                            // Sort bar
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                              child: Row(children: [
                                Expanded(
                                  child: Text('${list.length} driver ditemukan',
                                      style: const TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 12,
                                          color: AppColors.textGrey)),
                                ),
                                GestureDetector(
                                  onTap: _showSort,
                                  child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.swap_vert_rounded,
                                            size: 14,
                                            color: AppColors.textGrey),
                                        const SizedBox(width: 3),
                                        Text(
                                          _sortBy == 'name'
                                              ? 'Nama (A-Z)'
                                              : 'Online dahulu',
                                          style: const TextStyle(
                                              fontFamily: 'Poppins',
                                              fontSize: 12,
                                              color: AppColors.textGrey),
                                        ),
                                      ]),
                                ),
                              ]),
                            ),
                          ],
                        ),
                      );
                    }

                    // Item 1 saat kosong: pesan kontekstual
                    if (list.isEmpty && i == 1) {
                      final isOnlineFilter = _filterMode == 'online';
                      return SizedBox(
                        height: 300,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isOnlineFilter
                                    ? Icons.wifi_off_rounded
                                    : Icons.person_search_rounded,
                                size: 56,
                                color: AppColors.primary.withValues(alpha: 0.2),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                isOnlineFilter
                                    ? 'Belum ada driver yang online'
                                    : 'Tidak ada driver ditemukan',
                                style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textGrey),
                              ),
                              if (isOnlineFilter) ...[
                                const SizedBox(height: 6),
                                const Text(
                                  'Driver online saat GPS aktif di aplikasi driver',
                                  style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 11,
                                      color: AppColors.textLight),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }

                    // Item 1..n: kartu driver
                    final driverIndex = i - 1;
                    if (driverIndex < 0 || driverIndex >= list.length)
                      return const SizedBox.shrink();
                    final d = list[driverIndex];
                    final bus = widget.dataService.getDriverBus(d.idStr);
                    return Padding(
                      padding: EdgeInsets.fromLTRB(12, i == 1 ? 8 : 0, 12, 8),
                      child: _DriverCard(
                        driver: d,
                        bus: bus,
                        isOnline: _isOnline(d),
                        onEdit: () => _showEdit(d),
                        onDelete: () => _hapus(d),
                        onCall: () => _hubungi(d),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAdd,
        backgroundColor: AppColors.primary,
        elevation: 4,
        child: const Icon(Icons.person_add_rounded, color: Colors.white),
      ),
    );
  }
}

// DRIVER CARD

class _DriverCard extends StatelessWidget {
  final UserModel driver;
  final dynamic bus;
  final bool isOnline;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onCall;

  const _DriverCard({
    required this.driver,
    this.bus,
    required this.isOnline,
    required this.onEdit,
    required this.onDelete,
    required this.onCall,
  });

  @override
  Widget build(BuildContext context) {
    final hasPhoto = driver.photoUrl != null && driver.photoUrl!.isNotEmpty;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showDetail(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(13, 13, 13, 11),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── BARIS ATAS
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _Avatar(driver: driver, isOnline: isOnline, size: 48),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Nama
                        Text(driver.namaLengkap,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.black)),
                        const SizedBox(height: 2),
                        // Bus
                        Row(children: [
                          Icon(Icons.directions_bus_rounded,
                              size: 11,
                              color: bus != null
                                  ? AppColors.primary
                                  : AppColors.textLight),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              bus != null
                                  ? '${bus.nama} – ${bus.rute}'
                                  : 'Belum ditugaskan',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 11,
                                  color: bus != null
                                      ? AppColors.primary
                                      : AppColors.textLight,
                                  fontWeight: bus != null
                                      ? FontWeight.w500
                                      : FontWeight.w400),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 2),
                        // Foto indicator
                        Row(children: [
                          Icon(
                            hasPhoto
                                ? Icons.camera_alt_rounded
                                : Icons.camera_alt_outlined,
                            size: 10.5,
                            color:
                                hasPhoto ? AppColors.textGrey : AppColors.red,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            hasPhoto ? 'Foto diunggah' : 'Belum ada foto',
                            style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 10.5,
                                color: hasPhoto
                                    ? AppColors.textGrey
                                    : AppColors.red),
                          ),
                        ]),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Badge Online/Offline berdasarkan GPS
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isOnline
                          ? AppColors.primaryLight
                          : AppColors.surface2,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isOnline ? 'Online' : 'Offline',
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: isOnline
                              ? AppColors.primary
                              : AppColors.textGrey),
                    ),
                  ),
                ],
              ),

              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Divider(
                    height: 0.5, thickness: 0.5, color: AppColors.lightGrey),
              ),

              // ── BARIS BAWAH: No HP + aksi ─────────────────
              Row(children: [
                const Icon(Icons.phone_rounded,
                    size: 12, color: AppColors.textLight),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    driver.noHp.isNotEmpty ? driver.noHp : 'No. HP belum diisi',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        color: driver.noHp.isNotEmpty
                            ? AppColors.textGrey
                            : AppColors.textLight),
                  ),
                ),
                _IkonBtn(
                    icon: Icons.chat_rounded,
                    bg: const Color(0xFFE8F5ED),
                    color: const Color(0xFF1B5E37),
                    onTap: onCall,
                    tip: 'WhatsApp'),
                const SizedBox(width: 6),
                _IkonBtn(
                    icon: Icons.edit_rounded,
                    bg: AppColors.surface2,
                    color: AppColors.textGrey,
                    onTap: onEdit,
                    tip: 'Edit'),
                const SizedBox(width: 6),
                _IkonBtn(
                    icon: Icons.delete_outline_rounded,
                    bg: const Color(0xFFFFF0F0),
                    color: AppColors.red,
                    onTap: onDelete,
                    tip: 'Hapus'),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    final hasPhoto = driver.photoUrl != null && driver.photoUrl!.isNotEmpty;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _SheetWrap(
        title: '',
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            _Avatar(driver: driver, isOnline: isOnline, size: 56),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(driver.namaLengkap,
                        style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 16,
                            fontWeight: FontWeight.w700)),
                    Text(driver.email,
                        style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            color: AppColors.textGrey)),
                  ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isOnline ? AppColors.primaryLight : AppColors.surface2,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(isOnline ? 'Online' : 'Offline',
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color:
                          isOnline ? AppColors.primary : AppColors.textGrey)),
            ),
          ]),
          const SizedBox(height: 16),
          const Divider(color: AppColors.lightGrey),
          const SizedBox(height: 12),
          _InfoRow(
              icon: Icons.badge_rounded,
              label: 'NIK',
              value: driver.driverDetail?.nik ?? '-'),
          const SizedBox(height: 10),
          _InfoRow(
              icon: Icons.phone_rounded,
              label: 'No. HP',
              value: driver.noHp.isNotEmpty ? driver.noHp : 'Belum diisi'),
          const SizedBox(height: 10),
          _InfoRow(
              icon: Icons.location_on_rounded,
              label: 'Alamat',
              value: driver.alamat.isNotEmpty ? driver.alamat : 'Belum diisi'),
          const SizedBox(height: 10),
          _InfoRow(
              icon: Icons.directions_bus_rounded,
              label: 'Bus',
              value: bus != null
                  ? '${bus.nama} · ${bus.platNomor}'
                  : 'Belum ditugaskan'),
          const SizedBox(height: 10),
          _InfoRow(
            icon:
                hasPhoto ? Icons.camera_alt_rounded : Icons.camera_alt_outlined,
            label: 'Foto',
            value: hasPhoto ? 'Sudah diunggah' : 'Belum ada foto',
            valueColor: hasPhoto ? AppColors.primary : AppColors.red,
          ),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.delete_outline_rounded,
                    size: 16, color: AppColors.red),
                label: const Text('Hapus',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        color: AppColors.red)),
                onPressed: () {
                  Navigator.pop(ctx);
                  onDelete();
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.red),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.edit_rounded,
                    size: 16, color: Colors.white),
                label: const Text('Edit Data',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white)),
                onPressed: () {
                  Navigator.pop(ctx);
                  onEdit();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}

// WIDGET HELPERS

class _Avatar extends StatelessWidget {
  final UserModel driver;
  final bool isOnline;
  final double size;
  const _Avatar(
      {required this.driver, required this.isOnline, required this.size});

  @override
  Widget build(BuildContext context) {
    final hasPhoto = driver.photoUrl != null && driver.photoUrl!.isNotEmpty;
    final initials = driver.namaLengkap.isNotEmpty
        ? driver.namaLengkap[0].toUpperCase()
        : '?';

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primaryLight,
            border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.2), width: 1.5),
          ),
          child: ClipOval(
            child: hasPhoto
                ? Image.network(driver.photoUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _inisial(initials))
                : _inisial(initials),
          ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            width: size * 0.27,
            height: size * 0.27,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color:
                  isOnline ? const Color(0xFF22C55E) : const Color(0xFF9CA3AF),
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _inisial(String i) => Container(
        color: AppColors.primaryLight,
        child: Center(
          child: Text(i,
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w700,
                  fontSize: size * 0.38,
                  color: AppColors.primary)),
        ),
      );
}

class _FotoPicker extends StatelessWidget {
  final XFile? foto;
  final String? existingUrl;
  const _FotoPicker({this.foto, this.existingUrl});

  @override
  Widget build(BuildContext context) {
    Widget inner;
    if (foto != null) {
      inner = ClipOval(child: Image.file(File(foto!.path), fit: BoxFit.cover));
    } else if (existingUrl != null && existingUrl!.isNotEmpty) {
      inner = ClipOval(
          child: Image.network(existingUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(Icons.person_rounded,
                  size: 38, color: AppColors.primary)));
    } else {
      inner =
          const Icon(Icons.person_rounded, size: 38, color: AppColors.primary);
    }
    return Stack(children: [
      Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
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
          width: 26,
          height: 26,
          decoration: const BoxDecoration(
              shape: BoxShape.circle, color: AppColors.primary),
          child: const Icon(Icons.camera_alt_rounded,
              size: 13, color: Colors.white),
        ),
      ),
    ]);
  }
}

class _SheetWrap extends StatelessWidget {
  final String title;
  final Widget child;
  const _SheetWrap({required this.title, required this.child});

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
              if (title.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(title,
                    style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 20,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 20),
              ] else
                const SizedBox(height: 20),
              child,
            ],
          ),
        ),
      );
}

class _IkonBtn extends StatelessWidget {
  final IconData icon;
  final Color bg, color;
  final VoidCallback onTap;
  final String tip;
  const _IkonBtn(
      {required this.icon,
      required this.bg,
      required this.color,
      required this.onTap,
      required this.tip});

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tip,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
                color: bg, borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 15, color: color),
          ),
        ),
      );
}

class _Chip extends StatelessWidget {
  final String label;
  final int count;
  final bool active;
  final bool disabled;
  final VoidCallback? onTap;
  const _Chip(
      {required this.label,
      required this.count,
      required this.active,
      this.disabled = false,
      this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: disabled ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: active
                ? AppColors.primary
                : disabled
                    ? const Color(0xFFF2F4F2)
                    : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: active
                  ? AppColors.primary
                  : disabled
                      ? const Color(0xFFDDE6E0)
                      : AppColors.lightGrey,
              width: active ? 1.5 : 1,
            ),
          ),
          child: Text(
            count > 0 ? '$label ($count)' : label,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: active
                  ? Colors.white
                  : disabled
                      ? AppColors.textLight
                      : AppColors.textGrey,
            ),
          ),
        ),
      );
}

class _SortOpt extends StatelessWidget {
  final String label, value, current;
  final ValueChanged<String> onTap;
  const _SortOpt(this.label, this.value, this.current, this.onTap);

  @override
  Widget build(BuildContext context) {
    final active = current == value;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: active ? AppColors.primaryLight : AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: active ? AppColors.primary : AppColors.lightGrey,
              width: active ? 1.5 : 1),
        ),
        child: Row(children: [
          Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: active ? AppColors.primary : AppColors.black))),
          if (active)
            const Icon(Icons.check_rounded, color: AppColors.primary, size: 18),
        ]),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color? valueColor;
  const _InfoRow(
      {required this.icon,
      required this.label,
      required this.value,
      this.valueColor});

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: AppColors.textGrey),
          const SizedBox(width: 10),
          SizedBox(
              width: 58,
              child: Text(label,
                  style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: AppColors.textGrey))),
          Expanded(
              child: Text(value,
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: valueColor ?? AppColors.black))),
        ],
      );
}
