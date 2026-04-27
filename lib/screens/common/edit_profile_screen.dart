import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../models/models_api.dart';
import '../../services/api_client.dart';
import '../../services/auth_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';

class EditProfileScreen extends StatefulWidget {
  final UserModel user;
  const EditProfileScreen({super.key, required this.user});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _namaCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _noHpCtrl;
  late TextEditingController _alamatCtrl;
  bool _isLoading = false;
  File? _pickedImage;

  @override
  void initState() {
    super.initState();
    _namaCtrl = TextEditingController(text: widget.user.namaLengkap);
    _emailCtrl = TextEditingController(text: widget.user.email);
    _noHpCtrl = TextEditingController(text: widget.user.noHp);
    _alamatCtrl = TextEditingController(text: widget.user.alamat);
  }

  @override
  void dispose() {
    _namaCtrl.dispose();
    _emailCtrl.dispose();
    _noHpCtrl.dispose();
    _alamatCtrl.dispose();
    super.dispose();
  }

  void _showPickerOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(
              child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.lightGrey,
                      borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          const Text('Foto Profil',
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),
          _PickerOption(
            icon: Icons.camera_alt_rounded,
            label: 'Kamera',
            sub: 'Ambil foto baru',
            onTap: () {
              Navigator.pop(context);
              _pickImage(ImageSource.camera);
            },
          ),
          const SizedBox(height: 12),
          _PickerOption(
            icon: Icons.photo_library_rounded,
            label: 'Galeri',
            sub: 'Pilih dari file foto',
            onTap: () {
              Navigator.pop(context);
              _pickImage(ImageSource.gallery);
            },
          ),
          if (_pickedImage != null) ...[
            const SizedBox(height: 12),
            _PickerOption(
              icon: Icons.delete_rounded,
              label: 'Hapus Foto',
              sub: 'Kembali ke inisial nama',
              color: AppColors.red,
              onTap: () {
                Navigator.pop(context);
                setState(() => _pickedImage = null);
              },
            ),
          ],
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (picked != null && mounted) {
        setState(() => _pickedImage = File(picked.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Gagal memilih foto: $e'),
          backgroundColor: AppColors.red,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    // Upload foto kalau ada yang baru dipilih
    if (_pickedImage != null) {
      final res = await ApiClient().uploadFile(
        '/auth/profile/photo',
        _pickedImage!.path,
        'photo',
      );
      if (res.success) {
        final url = res.data?['data']?['photo_url'] as String?;
        if (url != null) widget.user.photoUrl = url;
      }
    }

    // PERBAIKAN: kirim semua field termasuk no_hp dan alamat ke backend.
    // Sebelumnya hanya name & email yang dikirim → no_hp dan alamat hanya
    // diupdate di memori lokal dan hilang saat login ulang karena tidak tersimpan ke DB.
    await ApiClient().put('/auth/profile', {
      'name': _namaCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'no_hp': _noHpCtrl.text.trim(),
      'alamat': _alamatCtrl.text.trim(),
    });

    widget.user.namaLengkap = _namaCtrl.text.trim();
    widget.user.email = _emailCtrl.text.trim();
    widget.user.noHp = _noHpCtrl.text.trim();
    widget.user.alamat = _alamatCtrl.text.trim();

    if (mounted) {
      // Refresh currentUser di AuthProvider agar foto muncul di semua screen
      await context.read<AuthProvider>().tryAutoLogin();
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Profil berhasil diperbarui'),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    String roleLabel = 'User';
    if (widget.user.role == UserRole.admin) roleLabel = 'Administrator';
    if (widget.user.role == UserRole.driver) roleLabel = 'Driver';
    if (widget.user.role == UserRole.siswa) roleLabel = 'Siswa';
    final initials = widget.user.namaLengkap.isNotEmpty
        ? widget.user.namaLengkap[0].toUpperCase()
        : '?';

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
        title: const Text('Edit Data Pribadi',
            style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: AppColors.black)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(children: [
            // Avatar
            GestureDetector(
              onTap: _showPickerOptions,
              child: Stack(children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primaryLight,
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        width: 3),
                    image: _pickedImage != null
                        ? DecorationImage(
                            image: FileImage(_pickedImage!), fit: BoxFit.cover)
                        : widget.user.photoUrl != null
                            ? DecorationImage(
                                image: NetworkImage(widget.user.photoUrl!),
                                fit: BoxFit.cover)
                            : null,
                  ),
                  child: (_pickedImage == null && widget.user.photoUrl == null)
                      ? Center(
                          child: Text(initials,
                              style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 40,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary)))
                      : null,
                ),
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: const BoxDecoration(
                        color: AppColors.primary, shape: BoxShape.circle),
                    child: const Icon(Icons.camera_alt_rounded,
                        color: Colors.white, size: 16),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 8),
            const Text('Tap untuk ubah foto',
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    color: AppColors.textGrey)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(8)),
              child: Text(roleLabel,
                  style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary)),
            ),
            const SizedBox(height: 32),

            AppTextField(
                label: 'Nama Lengkap',
                controller: _namaCtrl,
                validator: (v) =>
                    v!.isEmpty ? 'Nama tidak boleh kosong' : null),
            const SizedBox(height: 16),
            AppTextField(
                label: 'Email',
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                validator: (v) => v!.isEmpty
                    ? 'Email tidak boleh kosong'
                    : !v.contains('@')
                        ? 'Format email tidak valid'
                        : null),
            const SizedBox(height: 16),
            AppTextField(
                label: 'No HP',
                controller: _noHpCtrl,
                keyboardType: TextInputType.phone,
                validator: (v) =>
                    v!.isEmpty ? 'No HP tidak boleh kosong' : null),
            const SizedBox(height: 16),
            AppTextField(
                label: 'Alamat',
                controller: _alamatCtrl,
                validator: (v) =>
                    v!.isEmpty ? 'Alamat tidak boleh kosong' : null),
            const SizedBox(height: 32),
            PrimaryButton(
                text: 'Simpan Perubahan',
                icon: Icons.check_circle_rounded,
                isLoading: _isLoading,
                onPressed: _saveChanges),
          ]),
        ),
      ),
    );
  }
}

class _PickerOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sub;
  final VoidCallback onTap;
  final Color? color;
  const _PickerOption(
      {required this.icon,
      required this.label,
      required this.sub,
      required this.onTap,
      this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.withValues(alpha: 0.15)),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: c.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(icon, color: c, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(label,
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: c)),
                Text(sub,
                    style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        color: AppColors.textGrey)),
              ])),
          Icon(Icons.arrow_forward_ios_rounded,
              size: 14, color: c.withValues(alpha: 0.5)),
        ]),
      ),
    );
  }
}
