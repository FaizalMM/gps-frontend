import 'dart:convert';
import 'dart:math';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import '../../models/models_api.dart';
import '../../services/app_data_service.dart';
import '../../services/bus_service.dart';
import '../../services/domain_services.dart';
import '../../utils/app_theme.dart';

class AdminSiswaScreen extends StatefulWidget {
  final AppDataService dataService;
  const AdminSiswaScreen({super.key, required this.dataService});
  @override
  State<AdminSiswaScreen> createState() => _AdminSiswaScreenState();
}

class _AdminSiswaScreenState extends State<AdminSiswaScreen> {
  String _search = '';
  String _filter = 'Semua'; // Semua / Aktif / Nonaktif

  Future<Map<String, double>?> _geocodeAlamat(String alamat) async {
    try {
      final query =
          Uri.encodeComponent('$alamat, Madiun, Jawa Timur, Indonesia');
      final url = Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=1');
      final res = await http
          .get(url, headers: {'User-Agent': 'Mobitra-SchoolBus-App/1.0'});
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as List;
      if (data.isEmpty) return null;
      return {
        'lat': double.parse(data[0]['lat'] as String),
        'lng': double.parse(data[0]['lon'] as String),
      };
    } catch (_) {
      return null;
    }
  }

  double _hitungJarak(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371000.0;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLng = (lng2 - lng1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) *
            cos(lat2 * pi / 180) *
            sin(dLng / 2) *
            sin(dLng / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  String _formatJarak(double meter) {
    if (meter < 1000) return '${meter.round()} m';
    return '${(meter / 1000).toStringAsFixed(1)} km';
  }

  void _deleteUser(UserModel u) {
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: const Text('Hapus Siswa',
                  style: TextStyle(
                      fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
              content: Text('Hapus akun ${u.namaLengkap}?',
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 13)),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Batal',
                        style: TextStyle(
                            fontFamily: 'Poppins', color: AppColors.textGrey))),
                TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      widget.dataService.deleteUser(u.idStr).then((_) {
                        if (mounted) setState(() {});
                      });
                    },
                    child: const Text('Hapus',
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            color: AppColors.red,
                            fontWeight: FontWeight.w700))),
              ],
            ));
  }

  void _toggleStatus(UserModel u) async {
    // Gunakan student.id (bukan user.id) karena endpoint /students/{id} merujuk ke tabel students
    final studentId = u.studentDetail?.id;
    if (studentId == null || studentId == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Data siswa tidak ditemukan',
            style: TextStyle(fontFamily: 'Poppins')),
        backgroundColor: AppColors.red,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    final isActive = u.status == AccountStatus.active;
    bool ok;
    if (isActive) {
      ok = await StudentService().suspendStudent(studentId);
    } else {
      ok = await StudentService().unsuspendStudent(studentId);
    }
    if (!mounted) return;
    if (ok) {
      await widget.dataService.loadStudents();
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isActive
            ? '${u.namaLengkap} dinonaktifkan'
            : '${u.namaLengkap} diaktifkan kembali'),
        backgroundColor: isActive ? AppColors.orange : AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'Gagal ${isActive ? 'menonaktifkan' : 'mengaktifkan'} ${u.namaLengkap}'),
        backgroundColor: AppColors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    }
  }

  // ── Edit data siswa oleh admin
  void _showEditSiswaSheet(UserModel user) {
    final studentId = user.studentDetail?.id ?? 0;
    if (studentId == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Data siswa tidak lengkap',
            style: TextStyle(fontFamily: 'Poppins')),
        backgroundColor: AppColors.red,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    final namaCtrl = TextEditingController(text: user.namaLengkap);
    final emailCtrl = TextEditingController(text: user.email);
    final nisCtrl = TextEditingController(text: user.studentDetail?.nis ?? '');
    final sekolahCtrl =
        TextEditingController(text: user.studentDetail?.sekolah ?? '');
    final kelasCtrl =
        TextEditingController(text: user.studentDetail?.kelas ?? '');
    final noHpCtrl = TextEditingController(
        text: user.studentDetail?.noHp.isNotEmpty == true
            ? user.studentDetail!.noHp
            : user.noHp);
    final alamatCtrl = TextEditingController(
        text: user.studentDetail?.alamat.isNotEmpty == true
            ? user.studentDetail!.alamat
            : user.alamat);
    final passwordCtrl = TextEditingController();
    final passwordConfirmCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;
    bool obscurePassword = true;
    bool obscureConfirm = true;
    bool ubahPassword = false;
    XFile? foto;

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
              color: AppColors.background,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
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
                    const SizedBox(height: 20),
                    // Header
                    Row(children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                            color: AppColors.primaryLight,
                            shape: BoxShape.circle),
                        child: Center(
                            child: Text(
                          user.namaLengkap.isNotEmpty
                              ? user.namaLengkap[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w700,
                              fontSize: 20,
                              color: AppColors.primary),
                        )),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            const Text('Edit Data Siswa',
                                style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700)),
                            Text(user.email,
                                style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 12,
                                    color: AppColors.textGrey)),
                          ])),
                    ]),
                    const SizedBox(height: 16),
                    Center(
                      child: GestureDetector(
                        onTap: () async {
                          final img = await ImagePicker().pickImage(
                              source: ImageSource.gallery, imageQuality: 75);
                          if (img != null) setM(() => foto = img);
                        },
                        child: Stack(children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primaryLight,
                              border: Border.all(
                                  color:
                                      AppColors.primary.withValues(alpha: 0.25),
                                  width: 2),
                            ),
                            child: ClipOval(
                              child: foto != null
                                  ? Image.file(File(foto!.path),
                                      fit: BoxFit.cover)
                                  : (user.photoUrl != null &&
                                          user.photoUrl!.isNotEmpty)
                                      ? Image.network(user.photoUrl!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              const Icon(Icons.person_rounded,
                                                  size: 36,
                                                  color: AppColors.primary))
                                      : const Icon(Icons.person_rounded,
                                          size: 36, color: AppColors.primary),
                            ),
                          ),
                          Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: 26,
                                height: 26,
                                decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.primary),
                                child: const Icon(Icons.camera_alt_rounded,
                                    size: 13, color: Colors.white),
                              )),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Center(
                      child: Text(
                        foto != null
                            ? 'Foto baru terpilih — ketuk untuk ganti'
                            : (user.photoUrl != null
                                ? 'Ketuk foto untuk mengganti'
                                : 'Ketuk untuk pilih foto (opsional)'),
                        style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            color: AppColors.textGrey),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Nama
                    _EditField(
                        label: 'Nama Lengkap',
                        controller: namaCtrl,
                        validator: (v) => v!.trim().isEmpty
                            ? 'Nama tidak boleh kosong'
                            : null),
                    const SizedBox(height: 14),
                    // Email
                    _EditField(
                        label: 'Email',
                        controller: emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v!.trim().isEmpty) {
                            return 'Email tidak boleh kosong';
                          }
                          if (!v.contains('@')) {
                            return 'Format email tidak valid';
                          }
                          return null;
                        }),
                    const SizedBox(height: 14),
                    // NIS
                    _EditField(
                        label: 'NIS',
                        controller: nisCtrl,
                        keyboardType: TextInputType.number),
                    const SizedBox(height: 14),
                    // Sekolah
                    _EditField(label: 'Sekolah', controller: sekolahCtrl),
                    const SizedBox(height: 14),
                    // Kelas
                    _EditField(label: 'Kelas', controller: kelasCtrl),
                    const SizedBox(height: 14),
                    // No HP
                    _EditField(
                        label: 'No. HP / WhatsApp',
                        controller: noHpCtrl,
                        keyboardType: TextInputType.phone),
                    const SizedBox(height: 14),
                    // Alamat
                    _EditField(
                        label: 'Alamat Rumah',
                        controller: alamatCtrl,
                        maxLines: 2),
                    const SizedBox(height: 20),

                    // ── Ganti Password — Toggle Enable/Disable ──
                    const Divider(height: 1, color: AppColors.lightGrey),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: ubahPassword
                                ? AppColors.orange
                                : AppColors.lightGrey),
                      ),
                      child: Column(children: [
                        // ── Baris header + tombol toggle ──
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          child: Row(children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: ubahPassword
                                    ? AppColors.orange.withValues(alpha: 0.12)
                                    : AppColors.lightGrey
                                        .withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.lock_outline_rounded,
                                size: 18,
                                color: ubahPassword
                                    ? AppColors.orange
                                    : AppColors.textGrey,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Ubah Password',
                                        style: TextStyle(
                                            fontFamily: 'Poppins',
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600)),
                                    Text(
                                      ubahPassword
                                          ? 'Isi password baru di bawah'
                                          : 'Ketuk tombol untuk mengubah',
                                      style: const TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 11,
                                          color: AppColors.textGrey),
                                    ),
                                  ]),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                setM(() {
                                  ubahPassword = !ubahPassword;
                                  if (!ubahPassword) {
                                    passwordCtrl.clear();
                                    passwordConfirmCtrl.clear();
                                  }
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 7),
                                decoration: BoxDecoration(
                                  color: ubahPassword
                                      ? AppColors.orange
                                      : AppColors.primaryLight,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        ubahPassword
                                            ? Icons.lock_open_rounded
                                            : Icons.edit_rounded,
                                        size: 13,
                                        color: ubahPassword
                                            ? Colors.white
                                            : AppColors.primary,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        ubahPassword ? 'Batal' : 'Ubah',
                                        style: TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: ubahPassword
                                              ? Colors.white
                                              : AppColors.primary,
                                        ),
                                      ),
                                    ]),
                              ),
                            ),
                          ]),
                        ),

                        // ── Field password — hanya tampil saat ubahPassword = true ──
                        if (ubahPassword) ...[
                          const Divider(height: 1, color: AppColors.lightGrey),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                            child: Column(children: [
                              // Password baru
                              TextFormField(
                                controller: passwordCtrl,
                                obscureText: obscurePassword,
                                style: const TextStyle(
                                    fontFamily: 'Poppins', fontSize: 13),
                                validator: (v) {
                                  if (!ubahPassword) return null;
                                  if (v == null || v.isEmpty) {
                                    return 'Password baru wajib diisi';
                                  }
                                  if (v.length < 8) {
                                    return 'Password minimal 8 karakter';
                                  }
                                  return null;
                                },
                                decoration: InputDecoration(
                                  labelText: 'Password Baru',
                                  labelStyle: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 12,
                                      color: AppColors.textGrey),
                                  filled: true,
                                  fillColor: AppColors.background,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 12),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                        obscurePassword
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                        color: AppColors.textGrey,
                                        size: 20),
                                    onPressed: () => setM(() =>
                                        obscurePassword = !obscurePassword),
                                  ),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                          color: AppColors.lightGrey)),
                                  enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                          color: AppColors.lightGrey)),
                                  focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                          color: AppColors.orange, width: 1.5)),
                                  errorBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                          color: AppColors.red)),
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Konfirmasi password
                              TextFormField(
                                controller: passwordConfirmCtrl,
                                obscureText: obscureConfirm,
                                style: const TextStyle(
                                    fontFamily: 'Poppins', fontSize: 13),
                                validator: (v) {
                                  if (!ubahPassword) return null;
                                  if (v == null || v.isEmpty) {
                                    return 'Konfirmasi password wajib diisi';
                                  }
                                  if (v != passwordCtrl.text) {
                                    return 'Password tidak cocok';
                                  }
                                  return null;
                                },
                                decoration: InputDecoration(
                                  labelText: 'Konfirmasi Password Baru',
                                  labelStyle: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 12,
                                      color: AppColors.textGrey),
                                  filled: true,
                                  fillColor: AppColors.background,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 12),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                        obscureConfirm
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                        color: AppColors.textGrey,
                                        size: 20),
                                    onPressed: () => setM(
                                        () => obscureConfirm = !obscureConfirm),
                                  ),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                          color: AppColors.lightGrey)),
                                  enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                          color: AppColors.lightGrey)),
                                  focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                          color: AppColors.orange, width: 1.5)),
                                  errorBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                          color: AppColors.red)),
                                ),
                              ),
                              const SizedBox(height: 10),
                              // Info warning
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                    color: AppColors.orange
                                        .withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: AppColors.orange
                                            .withValues(alpha: 0.3))),
                                child: const Row(children: [
                                  Icon(Icons.info_outline_rounded,
                                      size: 14, color: AppColors.orange),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Siswa akan perlu login ulang menggunakan password baru.',
                                      style: TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 11,
                                          color: AppColors.orange),
                                    ),
                                  ),
                                ]),
                              ),
                            ]),
                          ),
                        ],
                      ]),
                    ),
                    const SizedBox(height: 28),

                    // Tombol Simpan
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: isSaving
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;
                                setM(() => isSaving = true);
                                final data = <String, dynamic>{
                                  'name': namaCtrl.text.trim(),
                                  'email': emailCtrl.text.trim(),
                                  'nis': nisCtrl.text.trim(),
                                  'sekolah': sekolahCtrl.text.trim(),
                                  'kelas': kelasCtrl.text.trim(),
                                  'no_hp': noHpCtrl.text.trim(),
                                  'alamat': alamatCtrl.text.trim(),
                                };
                                // Sertakan password hanya jika diisi
                                if (ubahPassword &&
                                    passwordCtrl.text.isNotEmpty) {
                                  data['password'] = passwordCtrl.text;
                                  data['password_confirmation'] =
                                      passwordConfirmCtrl.text;
                                }
                                final ok = await StudentService().updateStudent(
                                    studentId, data,
                                    photoPath: foto?.path);
                                if (!mounted) return;
                                setM(() => isSaving = false);
                                if (ok) {
                                  await widget.dataService.loadStudents();

                                  if (!mounted) return;

                                  Navigator.pop(context);

                                  setState(() {});

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text(
                                        'Data siswa berhasil diperbarui',
                                        style: TextStyle(fontFamily: 'Poppins'),
                                      ),
                                      backgroundColor: AppColors.primary,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(SnackBar(
                                    content: const Text(
                                        'Gagal memperbarui data. Coba lagi.',
                                        style:
                                            TextStyle(fontFamily: 'Poppins')),
                                    backgroundColor: AppColors.red,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                  ));
                                }
                              },
                        child: isSaving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.5, color: Colors.white))
                            : const Text('Simpan Perubahan',
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

  // ── Assign / Re-assign bus untuk siswa yang sudah approved
  void _showAssignBusSheet(UserModel user) {
    final buses = widget.dataService.buses
        .where((b) => b.status == BusStatus.active)
        .toList();
    final allHaltes = widget.dataService.haltes;

    final currentBusId = user.studentDetail?.busId ?? 0;
    final currentHalteId = user.studentDetail?.halteId ?? 0;

    BusModel? selectedBus = currentBusId > 0
        ? buses.where((b) => b.id == currentBusId).firstOrNull
        : null;
    HalteModel? selectedHalte = currentHalteId > 0
        ? allHaltes.where((h) => h.id == currentHalteId).firstOrNull
        : null;

    bool isGeocoding = false;
    Map<String, double>? siswaCoords;
    Map<int, double> jarakKeHalte = {};

    List<HalteModel> haltesForBus(BusModel? bus) {
      if (bus == null) return [];
      if (bus.routeList.isEmpty) return allHaltes;
      final halteIds =
          bus.routeList.expand((r) => r.haltes).map((h) => h.halteId).toSet();
      final filtered = allHaltes.where((h) => halteIds.contains(h.id)).toList();
      return filtered.isEmpty ? allHaltes : filtered;
    }

    List<HalteModel> sortedHaltes(List<HalteModel> haltes) {
      if (jarakKeHalte.isEmpty) return haltes;
      final sorted = List<HalteModel>.from(haltes);
      sorted.sort((a, b) {
        final da = jarakKeHalte[a.id] ?? double.maxFinite;
        final db = jarakKeHalte[b.id] ?? double.maxFinite;
        return da.compareTo(db);
      });
      return sorted;
    }

    bool sheetOpen = true;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) {
          final haltesShown = sortedHaltes(haltesForBus(selectedBus));
          final alamat = user.studentDetail?.alamat.isNotEmpty == true
              ? user.studentDetail!.alamat
              : user.alamat;

          // Auto-geocode saat sheet buka
          if (!isGeocoding && siswaCoords == null && alamat.isNotEmpty) {
            isGeocoding = true;
            _geocodeAlamat(alamat).then((coords) {
              if (!sheetOpen) return;
              if (coords == null) {
                setM(() => isGeocoding = false);
                return;
              }
              final jarak = <int, double>{};
              for (final h in allHaltes) {
                jarak[h.id] = _hitungJarak(
                    coords['lat']!, coords['lng']!, h.latitude, h.longitude);
              }
              setM(() {
                siswaCoords = coords;
                jarakKeHalte = jarak;
                isGeocoding = false;
                if (selectedBus != null && selectedHalte == null) {
                  final hBus = haltesForBus(selectedBus);
                  if (hBus.isNotEmpty) selectedHalte = sortedHaltes(hBus).first;
                }
              });
            });
          }

          final isReassign = currentBusId > 0;

          return Container(
            padding:
                EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            decoration: const BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
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
                    const SizedBox(height: 20),

                    Row(children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                            color: AppColors.primaryLight,
                            shape: BoxShape.circle),
                        child: Center(
                            child: Text(
                          user.namaLengkap.isNotEmpty
                              ? user.namaLengkap[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w700,
                              fontSize: 20,
                              color: AppColors.primary),
                        )),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(
                              isReassign
                                  ? 'Ganti Bus: ${user.namaLengkap}'
                                  : 'Assign Bus: ${user.namaLengkap}',
                              style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700),
                            ),
                            if (isReassign)
                              Text(
                                'Bus saat ini: ${user.studentDetail?.namaBus ?? "-"}',
                                style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 12,
                                    color: AppColors.textGrey),
                              ),
                          ])),
                    ]),
                    const SizedBox(height: 12),

                    // Kotak alamat + status geocoding
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.home_rounded,
                                size: 14, color: AppColors.primary),
                            const SizedBox(width: 6),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  const Text('Alamat Rumah',
                                      style: TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.primary)),
                                  const SizedBox(height: 2),
                                  Text(
                                    alamat.isNotEmpty ? alamat : '-',
                                    style: const TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 12,
                                        color: AppColors.primaryDark),
                                  ),
                                  const SizedBox(height: 4),
                                  if (isGeocoding)
                                    const Row(children: [
                                      SizedBox(
                                          width: 10,
                                          height: 10,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 1.5,
                                              color: AppColors.primary)),
                                      SizedBox(width: 6),
                                      Text('Mencari lokasi...',
                                          style: TextStyle(
                                              fontFamily: 'Poppins',
                                              fontSize: 10,
                                              color: AppColors.primary)),
                                    ])
                                  else if (siswaCoords != null)
                                    const Row(children: [
                                      Icon(Icons.check_circle_rounded,
                                          size: 11, color: AppColors.primary),
                                      SizedBox(width: 4),
                                      Text(
                                          'Lokasi ditemukan — halte terdekat otomatis diurutkan',
                                          style: TextStyle(
                                              fontFamily: 'Poppins',
                                              fontSize: 10,
                                              color: AppColors.primary)),
                                    ]),
                                ])),
                          ]),
                    ),
                    const SizedBox(height: 20),

                    const Text('Pilih Bus / Rute',
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),

                    if (buses.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                            color: AppColors.surface2,
                            borderRadius: BorderRadius.circular(10)),
                        child: const Row(children: [
                          Icon(Icons.info_outline_rounded,
                              color: AppColors.textGrey, size: 16),
                          SizedBox(width: 8),
                          Text('Belum ada bus aktif. Tambah bus dulu.',
                              style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 12,
                                  color: AppColors.textGrey)),
                        ]),
                      )
                    else
                      ...buses.map((b) {
                        final isSelected = selectedBus?.id == b.id;
                        final namaRute = b.routeList.isNotEmpty
                            ? b.routeList.first.namaRute
                            : b.rute;
                        String saranHalte = '';
                        if (siswaCoords != null) {
                          final hBus = haltesForBus(b);
                          if (hBus.isNotEmpty) {
                            final sorted = sortedHaltes(hBus);
                            final jarak = jarakKeHalte[sorted.first.id];
                            if (jarak != null) {
                              saranHalte =
                                  'Halte terdekat: ${sorted.first.namaHalte} (${_formatJarak(jarak)})';
                            }
                          }
                        }
                        return GestureDetector(
                          onTap: () => setM(() {
                            selectedBus = b;
                            selectedHalte = null;
                            if (siswaCoords != null) {
                              final hBus = haltesForBus(b);
                              if (hBus.isNotEmpty) {
                                selectedHalte = sortedHaltes(hBus).first;
                              }
                            }
                          }),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primaryLight
                                  : AppColors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.lightGrey,
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppColors.primary
                                          : AppColors.surface2,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(Icons.directions_bus_rounded,
                                        size: 18,
                                        color: isSelected
                                            ? Colors.white
                                            : AppColors.textGrey),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                        Text(b.nama,
                                            style: TextStyle(
                                                fontFamily: 'Poppins',
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: isSelected
                                                    ? AppColors.primary
                                                    : AppColors.black)),
                                        if (namaRute.isNotEmpty)
                                          Text(namaRute,
                                              style: TextStyle(
                                                  fontFamily: 'Poppins',
                                                  fontSize: 11,
                                                  color: isSelected
                                                      ? AppColors.primaryDark
                                                      : AppColors.textGrey)),
                                        Text(b.platNomor,
                                            style: const TextStyle(
                                                fontFamily: 'Poppins',
                                                fontSize: 11,
                                                color: AppColors.textGrey)),
                                        if (saranHalte.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? AppColors.primary
                                                      .withValues(alpha: 0.15)
                                                  : AppColors.orange
                                                      .withValues(alpha: 0.1),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                      Icons.location_on_rounded,
                                                      size: 10,
                                                      color: isSelected
                                                          ? AppColors.primary
                                                          : AppColors.orange),
                                                  const SizedBox(width: 3),
                                                  Flexible(
                                                      child: Text(saranHalte,
                                                          style: TextStyle(
                                                              fontFamily:
                                                                  'Poppins',
                                                              fontSize: 10,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                              color: isSelected
                                                                  ? AppColors
                                                                      .primary
                                                                  : AppColors
                                                                      .orange))),
                                                ]),
                                          ),
                                        ],
                                      ])),
                                  if (isSelected)
                                    const Padding(
                                      padding: EdgeInsets.only(top: 8),
                                      child: Icon(Icons.check_circle_rounded,
                                          color: AppColors.primary, size: 20),
                                    ),
                                ]),
                          ),
                        );
                      }),
                    const SizedBox(height: 16),

                    if (selectedBus != null) ...[
                      Row(children: [
                        const Expanded(
                            child: Text('Halte Penjemputan',
                                style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600))),
                        Text('${haltesShown.length} halte',
                            style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 11,
                                color: AppColors.primary)),
                      ]),
                      const SizedBox(height: 4),
                      Text(
                        siswaCoords != null
                            ? 'Diurutkan dari yang terdekat dengan rumah siswa'
                            : 'Pilih halte yang paling dekat dengan rumah siswa',
                        style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            color: AppColors.textGrey),
                      ),
                      const SizedBox(height: 10),
                      ...haltesShown.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final h = entry.value;
                        final isSelected = selectedHalte?.id == h.id;
                        final jarak = jarakKeHalte[h.id];
                        final isSuggest = idx == 0 && siswaCoords != null;
                        return GestureDetector(
                          onTap: () => setM(() => selectedHalte = h),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primaryLight
                                  : AppColors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primary
                                    : isSuggest
                                        ? AppColors.primary
                                            .withValues(alpha: 0.4)
                                        : AppColors.lightGrey,
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Row(children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.primary
                                      : isSuggest
                                          ? AppColors.primaryLight
                                          : AppColors.surface2,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.location_on_rounded,
                                    size: 16,
                                    color: isSelected
                                        ? Colors.white
                                        : isSuggest
                                            ? AppColors.primary
                                            : AppColors.textGrey),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    Row(children: [
                                      Expanded(
                                          child: Text(h.namaHalte,
                                              style: TextStyle(
                                                  fontFamily: 'Poppins',
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w500,
                                                  color: isSelected
                                                      ? AppColors.primary
                                                      : AppColors.black))),
                                      if (isSuggest && !isSelected)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                              color: AppColors.primaryLight,
                                              borderRadius:
                                                  BorderRadius.circular(6)),
                                          child: const Text('Terdekat',
                                              style: TextStyle(
                                                  fontFamily: 'Poppins',
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.primary)),
                                        ),
                                    ]),
                                    if (jarak != null)
                                      Text(
                                        '${_formatJarak(jarak)} dari rumah siswa',
                                        style: TextStyle(
                                            fontFamily: 'Poppins',
                                            fontSize: 11,
                                            color: isSelected
                                                ? AppColors.primaryDark
                                                : AppColors.textGrey),
                                      ),
                                  ])),
                              if (isSelected)
                                const Icon(Icons.check_circle_rounded,
                                    color: AppColors.primary, size: 20),
                            ]),
                          ),
                        );
                      }),
                      const SizedBox(height: 16),
                    ],

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: selectedBus == null || selectedHalte == null
                            ? null
                            : () async {
                                sheetOpen = false;
                                final studentId = user.studentDetail?.id ?? 0;
                                final messenger = ScaffoldMessenger.of(context);
                                final nav = Navigator.of(ctx);
                                if (studentId <= 0) {
                                  nav.pop();
                                  messenger.showSnackBar(const SnackBar(
                                    content: Text(
                                        'ID siswa tidak ditemukan. Refresh dan coba lagi.'),
                                    backgroundColor: AppColors.red,
                                    behavior: SnackBarBehavior.floating,
                                  ));
                                  return;
                                }
                                final ok =
                                    await BusService().assignStudentToBus(
                                  selectedBus!.id,
                                  studentId,
                                  selectedHalte!.id,
                                );
                                await widget.dataService.loadStudents();
                                if (!mounted) return;
                                nav.pop();
                                setState(() {});
                                messenger.showSnackBar(SnackBar(
                                  content: Text(ok
                                      ? '${user.namaLengkap} berhasil ditugaskan ke ${selectedBus!.nama}'
                                      : 'Gagal assign bus. Coba lagi.'),
                                  backgroundColor:
                                      ok ? AppColors.primary : AppColors.red,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                ));
                              },
                        icon:
                            const Icon(Icons.directions_bus_rounded, size: 18),
                        label: Text(
                            isReassign ? 'Simpan Perubahan Bus' : 'Assign Bus',
                            style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: AppColors.lightGrey,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ]),
            ),
          );
        },
      ),
    ).whenComplete(() => sheetOpen = false);
  }

  void _showAssignHalteSheet(UserModel user) {
    final allHaltes = widget.dataService.haltes;
    final buses = widget.dataService.buses
        .where((b) => b.status == BusStatus.active)
        .toList();

    final currentBusId = user.studentDetail?.busId ?? 0;
    final currentHalteId = user.studentDetail?.halteId ?? 0;

    final currentBus = currentBusId > 0
        ? buses.where((b) => b.id == currentBusId).firstOrNull
        : null;

    List<HalteModel> haltesForBus(BusModel? bus) {
      if (bus == null || bus.routeList.isEmpty) return allHaltes;
      final halteIds =
          bus.routeList.expand((r) => r.haltes).map((h) => h.halteId).toSet();
      final filtered = allHaltes.where((h) => halteIds.contains(h.id)).toList();
      return filtered.isEmpty ? allHaltes : filtered;
    }

    HalteModel? selectedHalte = currentHalteId > 0
        ? allHaltes.where((h) => h.id == currentHalteId).firstOrNull
        : null;

    final haltes = haltesForBus(currentBus);

    if (currentBus == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Siswa harus ditugaskan ke bus terlebih dahulu',
            style: TextStyle(fontFamily: 'Poppins')),
        backgroundColor: AppColors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) {
          return Padding(
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
                          borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(children: [
                    const Icon(Icons.place_rounded,
                        color: Color(0xFF1565C0), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tetapkan Halte untuk ${user.namaLengkap}',
                        style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 16,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  Text(
                    'Bus: ${currentBus.nama} · ${currentBus.platNomor}',
                    style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        color: AppColors.textGrey),
                  ),
                  const SizedBox(height: 16),
                  const Text('Pilih Halte',
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textGrey)),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 280),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: haltes.length,
                      itemBuilder: (_, i) {
                        final h = haltes[i];
                        final selected = selectedHalte?.id == h.id;
                        return GestureDetector(
                          onTap: () => setM(() => selectedHalte = h),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: selected
                                  ? const Color(0xFFE3F2FD)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: selected
                                    ? const Color(0xFF1565C0)
                                    : AppColors.lightGrey,
                                width: selected ? 1.5 : 1,
                              ),
                            ),
                            child: Row(children: [
                              Icon(Icons.location_on_rounded,
                                  size: 16,
                                  color: selected
                                      ? const Color(0xFF1565C0)
                                      : AppColors.textGrey),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(h.namaHalte,
                                          style: TextStyle(
                                              fontFamily: 'Poppins',
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: selected
                                                  ? const Color(0xFF1565C0)
                                                  : AppColors.black)),
                                      if (h.alamat.isNotEmpty)
                                        Text(h.alamat,
                                            style: const TextStyle(
                                                fontFamily: 'Poppins',
                                                fontSize: 11,
                                                color: AppColors.textGrey)),
                                    ]),
                              ),
                              if (selected)
                                const Icon(Icons.check_circle_rounded,
                                    color: Color(0xFF1565C0), size: 18),
                            ]),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check_rounded,
                          size: 18, color: Colors.white),
                      label: const Text('Simpan Halte',
                          style: TextStyle(
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w600,
                              color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1565C0),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: selectedHalte == null
                          ? null
                          : () async {
                              final messenger = ScaffoldMessenger.of(context);
                              final nav = Navigator.of(ctx);
                              final ok = await StudentService()
                                  .updateStudent(user.id, {
                                'bus_id': currentBus.id,
                                'halte_id': selectedHalte!.id,
                              });
                              if (ok) {
                                await widget.dataService.loadAll();
                                user.studentDetail?.halteId = selectedHalte!.id;
                                user.studentDetail?.namaHalte =
                                    selectedHalte!.namaHalte;
                              }
                              if (!mounted) return;
                              nav.pop();
                              setState(() {});
                              messenger.showSnackBar(SnackBar(
                                content: Text(
                                    ok
                                        ? 'Halte berhasil ditetapkan'
                                        : 'Gagal menetapkan halte',
                                    style:
                                        const TextStyle(fontFamily: 'Poppins')),
                                backgroundColor:
                                    ok ? AppColors.primary : AppColors.red,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ));
                            },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Manajemen Siswa',
            style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: AppColors.black)),
        centerTitle: true,
        bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(color: AppColors.lightGrey, height: 0.5)),
      ),
      body: Column(children: [
        Container(
          color: AppColors.white,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: AppColors.blue.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(10)),
            child: const Row(children: [
              Icon(Icons.info_outline_rounded, color: AppColors.blue, size: 16),
              SizedBox(width: 8),
              Expanded(
                  child: Text(
                'Siswa mendaftar sendiri. Setujui akun di tab Persetujuan.',
                style: TextStyle(
                    fontFamily: 'Poppins', fontSize: 11, color: AppColors.blue),
              )),
            ]),
          ),
        ),
        const SizedBox(height: 2),
        Container(
          color: AppColors.white,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Container(
            height: 44,
            decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(12)),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 13),
              decoration: const InputDecoration(
                hintText: 'Cari nama atau email...',
                hintStyle: TextStyle(
                    fontFamily: 'Poppins',
                    color: AppColors.textGrey,
                    fontSize: 13),
                prefixIcon: Icon(Icons.search_rounded,
                    color: AppColors.textGrey, size: 18),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
          child: Row(
              children:
                  ['Semua', 'Aktif', 'Belum ada Bus', 'Nonaktif'].map((label) {
            final sel = _filter == label;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => setState(() => _filter = label),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: sel
                        ? (label == 'Belum ada Bus'
                            ? AppColors.orange
                            : AppColors.primary)
                        : AppColors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: sel
                            ? (label == 'Belum ada Bus'
                                ? AppColors.orange
                                : AppColors.primary)
                            : AppColors.lightGrey),
                  ),
                  child: Text(label,
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                          color: sel ? Colors.white : AppColors.textGrey)),
                ),
              ),
            );
          }).toList()),
        ),
        Expanded(
          child: StreamBuilder<List<UserModel>>(
            stream: widget.dataService.usersStream,
            builder: (_, snap) {
              var list = (snap.data ?? widget.dataService.users)
                  .where((u) => u.role == UserRole.siswa)
                  .where((u) =>
                      u.namaLengkap
                          .toLowerCase()
                          .contains(_search.toLowerCase()) ||
                      u.email.toLowerCase().contains(_search.toLowerCase()))
                  .where((u) {
                if (_filter == 'Aktif') return u.status == AccountStatus.active;
                if (_filter == 'Nonaktif') {
                  return u.status != AccountStatus.active &&
                      u.status != AccountStatus.pending;
                }
                if (_filter == 'Belum ada Bus') {
                  // Siswa aktif tapi belum punya bus assignment
                  return u.status == AccountStatus.active &&
                      (u.studentDetail?.busId ?? 0) == 0;
                }
                return true;
              }).toList();

              if (list.isEmpty) {
                return Center(
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                      Icon(
                          _filter == 'Belum ada Bus'
                              ? Icons.directions_bus_outlined
                              : Icons.school_outlined,
                          size: 56,
                          color: AppColors.primary.withValues(alpha: 0.3)),
                      const SizedBox(height: 12),
                      Text(
                          _filter == 'Belum ada Bus'
                              ? 'Semua siswa sudah punya bus'
                              : 'Tidak ada siswa ditemukan',
                          style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 15,
                              color: AppColors.textGrey)),
                    ]));
              } else {
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
                  itemCount: list.length,
                  itemBuilder: (_, i) => _SiswaCard(
                      siswa: list[i],
                      onDelete: () => _deleteUser(list[i]),
                      onToggle: () => _toggleStatus(list[i]),
                      onAssignBus: () => _showAssignBusSheet(list[i]),
                      onAssignHalte: () => _showAssignHalteSheet(list[i]),
                      onEdit: () => _showEditSiswaSheet(list[i])),
                );
              }
            },
          ),
        ),
      ]),
    );
  }
}

// Avatar siswa: tampilkan foto jika ada, fallback ke inisial
class _SiswaAvatar extends StatelessWidget {
  final UserModel siswa;
  const _SiswaAvatar({required this.siswa});

  @override
  Widget build(BuildContext context) {
    final hasPhoto = siswa.photoUrl != null && siswa.photoUrl!.isNotEmpty;
    final initials =
        siswa.namaLengkap.isNotEmpty ? siswa.namaLengkap[0].toUpperCase() : '?';

    Widget fallback = Container(
      color: AppColors.primaryLight,
      child: Center(
        child: Text(initials,
            style: const TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
                fontSize: 18)),
      ),
    );

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primaryLight,
        border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.2), width: 1.5),
      ),
      child: ClipOval(
        child: hasPhoto
            ? CachedNetworkImage(
                imageUrl: siswa.photoUrl!,
                fit: BoxFit.cover,
                httpHeaders: const {
                  'ngrok-skip-browser-warning': 'true',
                  'User-Agent': 'Mobitra-App/1.0',
                },
                placeholder: (_, __) => fallback,
                errorWidget: (_, __, ___) => fallback,
              )
            : fallback,
      ),
    );
  }
}

class _SiswaCard extends StatelessWidget {
  final UserModel siswa;
  final VoidCallback onDelete, onToggle, onAssignBus, onAssignHalte, onEdit;
  const _SiswaCard(
      {required this.siswa,
      required this.onDelete,
      required this.onToggle,
      required this.onAssignBus,
      required this.onAssignHalte,
      required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final isActive = siswa.status == AccountStatus.active;
    final isPending = siswa.status == AccountStatus.pending;
    final statusColor = isActive
        ? AppColors.primary
        : isPending
            ? AppColors.orange
            : AppColors.red;
    final statusLabel = isActive
        ? 'Aktif'
        : isPending
            ? 'Pending'
            : 'Nonaktif';
    final statusBg = isActive
        ? AppColors.primaryLight
        : isPending
            ? AppColors.orange.withValues(alpha: 0.1)
            : AppColors.red.withValues(alpha: 0.1);

    // Cek apakah siswa sudah punya bus
    final hasBus = (siswa.studentDetail?.busId ?? 0) > 0;
    final namaBus = siswa.studentDetail?.namaBus ?? '';
    final namaHalte = siswa.studentDetail?.namaHalte ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: !isActive && !isPending
              ? Border.all(
                  color: AppColors.red.withValues(alpha: 0.3), width: 1.5)
              : !hasBus && isActive
                  ? Border.all(
                      color: AppColors.orange.withValues(alpha: 0.4),
                      width: 1.5)
                  : null,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _SiswaAvatar(siswa: siswa),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(siswa.namaLengkap,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.black)),
                const SizedBox(height: 2),
                Text(siswa.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        color: AppColors.textGrey)),
                const SizedBox(height: 5),
                Row(children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(6)),
                    child: Text(statusLabel,
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: statusColor)),
                  ),
                  const SizedBox(width: 6),
                  if (isActive)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                          color: hasBus
                              ? AppColors.primary.withValues(alpha: 0.08)
                              : AppColors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(
                            hasBus
                                ? Icons.directions_bus_rounded
                                : Icons.directions_bus_outlined,
                            size: 10,
                            color:
                                hasBus ? AppColors.primary : AppColors.orange),
                        const SizedBox(width: 3),
                        Text(
                            hasBus
                                ? (namaBus.isNotEmpty ? namaBus : 'Ada Bus')
                                : 'Belum Ada Bus',
                            style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: hasBus
                                    ? AppColors.primary
                                    : AppColors.orange)),
                      ]),
                    ),
                  if (isActive && hasBus && namaHalte.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1565C0).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.place_rounded,
                            size: 10, color: Color(0xFF1565C0)),
                        const SizedBox(width: 3),
                        Text(namaHalte,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1565C0))),
                      ]),
                    ),
                  ],
                ]),
              ])),
          const SizedBox(width: 8),
          Column(mainAxisSize: MainAxisSize.min, children: [
            // Tombol edit data siswa
            _ActionBtn(
              icon: Icons.edit_rounded,
              color: AppColors.primary,
              bg: AppColors.primaryLight,
              onTap: onEdit,
              tooltip: 'Edit Data',
            ),
            const SizedBox(height: 6),
            // Tombol assign/ganti bus — tampil untuk siswa aktif
            if (isActive) ...[
              _ActionBtn(
                icon:
                    hasBus ? Icons.sync_rounded : Icons.directions_bus_rounded,
                color: hasBus ? AppColors.primary : AppColors.orange,
                bg: hasBus
                    ? AppColors.primaryLight
                    : AppColors.orange.withValues(alpha: 0.1),
                onTap: onAssignBus,
                tooltip: hasBus ? 'Ganti Bus' : 'Assign Bus',
              ),
              const SizedBox(height: 6),
              _ActionBtn(
                icon: Icons.place_rounded,
                color: const Color(0xFF1565C0),
                bg: const Color(0xFFE3F2FD),
                onTap: onAssignHalte,
                tooltip: 'Tetapkan Halte',
              ),
              const SizedBox(height: 6),
              _ActionBtn(
                icon:
                    isActive ? Icons.block_rounded : Icons.check_circle_rounded,
                color: isActive ? AppColors.red : AppColors.primary,
                bg: isActive
                    ? AppColors.red.withValues(alpha: 0.1)
                    : AppColors.primaryLight,
                onTap: onToggle,
                tooltip: isActive ? 'Nonaktifkan' : 'Aktifkan',
              ),
            ] else if (!isPending) ...[
              _ActionBtn(
                icon: Icons.check_circle_rounded,
                color: AppColors.primary,
                bg: AppColors.primaryLight,
                onTap: onToggle,
                tooltip: 'Aktifkan',
              ),
            ],
            const SizedBox(height: 6),
            _ActionBtn(
                icon: Icons.delete_rounded,
                color: AppColors.red,
                bg: AppColors.red.withValues(alpha: 0.08),
                onTap: onDelete,
                tooltip: 'Hapus'),
          ]),
        ]),

        // Info halte jika sudah ada bus
        if (hasBus && namaHalte.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              const Icon(Icons.location_on_rounded,
                  size: 12, color: AppColors.primary),
              const SizedBox(width: 5),
              Text('Halte: $namaHalte',
                  style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      color: AppColors.primaryDark)),
            ]),
          ),
        ],

        // Warning jika aktif tapi belum ada bus
        if (isActive && !hasBus) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
                color: AppColors.orange.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: AppColors.orange.withValues(alpha: 0.3))),
            child: const Row(children: [
              Icon(Icons.warning_amber_rounded,
                  size: 12, color: AppColors.orange),
              SizedBox(width: 5),
              Expanded(
                child: Text('Belum ditugaskan ke bus — tap tombol assign,',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        color: AppColors.orange)),
              ),
            ]),
          ),
        ],
      ]),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color, bg;
  final VoidCallback onTap;
  final String tooltip;
  const _ActionBtn(
      {required this.icon,
      required this.color,
      required this.bg,
      required this.onTap,
      required this.tooltip});
  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: bg, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 18)),
        ),
      );
}

// ── Widget input field untuk edit form siswa
class _EditField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final int maxLines;
  final String? Function(String?)? validator;

  const _EditField({
    required this.label,
    required this.controller,
    this.keyboardType,
    this.maxLines = 1,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      style: const TextStyle(fontFamily: 'Poppins', fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
            fontFamily: 'Poppins', fontSize: 12, color: AppColors.textGrey),
        filled: true,
        fillColor: AppColors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.lightGrey),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.lightGrey),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.red),
        ),
      ),
    );
  }
}
