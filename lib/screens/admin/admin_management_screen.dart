import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/models_api.dart';
import '../../services/domain_services.dart';
import '../../utils/app_theme.dart';

class AdminManagementScreen extends StatefulWidget {
  const AdminManagementScreen({super.key});

  @override
  State<AdminManagementScreen> createState() => _AdminManagementScreenState();
}

class _AdminManagementScreenState extends State<AdminManagementScreen> {
  final _service = AdminService();
  List<UserModel> _admins = [];
  bool _loading = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final result = await _service.getAdmins();
    if (mounted) {
      setState(() {
        _admins = result;
        _loading = false;
      });
    }
  }

  List<UserModel> get _filtered {
    if (_search.isEmpty) return _admins;
    final q = _search.toLowerCase();
    return _admins
        .where((a) =>
            a.namaLengkap.toLowerCase().contains(q) ||
            a.email.toLowerCase().contains(q))
        .toList();
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 13)),
      backgroundColor: error ? AppColors.red : AppColors.primary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  void _showAddSheet() => _showFormSheet(null);
  void _showEditSheet(UserModel admin) => _showFormSheet(admin);

  void _showFormSheet(UserModel? admin) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AdminFormSheet(
        admin: admin,
        service: _service,
        onSaved: () {
          Navigator.pop(context);
          _load();
        },
      ),
    );
  }

  void _confirmDelete(UserModel admin) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Admin',
            style:
                TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
        content: Text('Hapus akun "${admin.namaLengkap}" secara permanen?',
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 14)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child:
                  const Text('Batal', style: TextStyle(fontFamily: 'Poppins'))),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final ok = await _service.deleteAdmin(admin.id);
              if (ok) {
                _load();
                _snack('Admin berhasil dihapus');
              } else {
                _snack('Gagal menghapus admin', error: true);
              }
            },
            child: const Text('Hapus',
                style: TextStyle(fontFamily: 'Poppins', color: AppColors.red)),
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
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Manajemen Admin',
            style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 17,
                fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon:
                const Icon(Icons.person_add_rounded, color: AppColors.primary),
            onPressed: _showAddSheet,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: _SearchBox(
            onChanged: (v) => setState(() => _search = v),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary))
              : RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: _load,
                  child: _filtered.isEmpty
                      ? _EmptyState(hasSearch: _search.isNotEmpty)
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filtered.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, i) => _AdminCard(
                            admin: _filtered[i],
                            onEdit: () => _showEditSheet(_filtered[i]),
                            onDelete: () => _confirmDelete(_filtered[i]),
                          ),
                        ),
                ),
        ),
      ]),
    );
  }
}

class _AdminCard extends StatelessWidget {
  final UserModel admin;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AdminCard(
      {required this.admin, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.lightGrey),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          _Avatar(url: admin.photoUrl, name: admin.namaLengkap, size: 48),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(admin.namaLengkap,
                  style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(admin.email,
                  style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: AppColors.textGrey)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('ADMIN',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary)),
              ),
            ]),
          ),
          Column(children: [
            _IconBtn(
                icon: Icons.edit_rounded,
                color: AppColors.primary,
                onTap: onEdit),
            const SizedBox(height: 6),
            _IconBtn(
                icon: Icons.delete_rounded,
                color: AppColors.red,
                onTap: onDelete),
          ]),
        ]),
      ),
    );
  }
}

class _AdminFormSheet extends StatefulWidget {
  final UserModel? admin;
  final AdminService service;
  final VoidCallback onSaved;

  const _AdminFormSheet(
      {this.admin, required this.service, required this.onSaved});

  @override
  State<_AdminFormSheet> createState() => _AdminFormSheetState();
}

class _AdminFormSheetState extends State<_AdminFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  final _passCtrl = TextEditingController();
  final _passConfirmCtrl = TextEditingController();
  bool _changePass = false;
  bool _loading = false;
  bool _obscurePass = true;
  bool _obscureConfirm = true;
  File? _photo;
  bool _deletePhoto = false;

  bool get _isEdit => widget.admin != null;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.admin?.namaLengkap ?? '');
    _emailCtrl = TextEditingController(text: widget.admin?.email ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _passConfirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final img = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (img != null && mounted) {
      setState(() {
        _photo = File(img.path);
        _deletePhoto = false;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    bool ok;
    if (_isEdit) {
      final r = await widget.service.updateAdmin(
        widget.admin!.id,
        name: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        password:
            _changePass && _passCtrl.text.isNotEmpty ? _passCtrl.text : null,
        passwordConfirmation: _changePass ? _passConfirmCtrl.text : null,
        photoPath: _photo?.path,
      );
      ok = r.success;
      if (!ok && mounted) {
        _snack(r.error ?? 'Gagal menyimpan', error: true);
      }
    } else {
      ok = await widget.service.createAdmin(
        name: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
        passwordConfirmation: _passConfirmCtrl.text,
        photoPath: _photo?.path,
      );
      if (!ok && mounted) _snack('Gagal membuat admin', error: true);
    }

    if (mounted) setState(() => _loading = false);
    if (ok) widget.onSaved();
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 13)),
      backgroundColor: error ? AppColors.red : AppColors.primary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 0, 20, bottom + 24),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: AppColors.lightGrey,
                  borderRadius: BorderRadius.circular(2)),
            ),
            Text(_isEdit ? 'Edit Admin' : 'Tambah Admin',
                style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: _pickPhoto,
              child: Stack(alignment: Alignment.bottomRight, children: [
                _Avatar(
                  url: _deletePhoto
                      ? null
                      : (_photo != null ? null : widget.admin?.photoUrl),
                  file: _photo,
                  name: _nameCtrl.text.isNotEmpty ? _nameCtrl.text : 'A',
                  size: 72,
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                      color: AppColors.primary, shape: BoxShape.circle),
                  child: const Icon(Icons.camera_alt_rounded,
                      size: 14, color: Colors.white),
                ),
              ]),
            ),
            const SizedBox(height: 20),
            _Field(
                controller: _nameCtrl,
                label: 'Nama Lengkap',
                icon: Icons.person_rounded,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Nama wajib diisi'
                    : null),
            const SizedBox(height: 12),
            _Field(
                controller: _emailCtrl,
                label: 'Email',
                icon: Icons.email_rounded,
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Email wajib diisi';
                  if (!v.contains('@')) return 'Format email tidak valid';
                  return null;
                }),
            const SizedBox(height: 12),
            if (!_isEdit) ...[
              _Field(
                  controller: _passCtrl,
                  label: 'Password',
                  icon: Icons.lock_rounded,
                  obscure: _obscurePass,
                  suffixIcon: IconButton(
                    icon: Icon(
                        _obscurePass
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        size: 20),
                    onPressed: () =>
                        setState(() => _obscurePass = !_obscurePass),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Password wajib diisi';
                    if (v.length < 8) return 'Minimal 8 karakter';
                    return null;
                  }),
              const SizedBox(height: 12),
              _Field(
                  controller: _passConfirmCtrl,
                  label: 'Konfirmasi Password',
                  icon: Icons.lock_outline_rounded,
                  obscure: _obscureConfirm,
                  suffixIcon: IconButton(
                    icon: Icon(
                        _obscureConfirm
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        size: 20),
                    onPressed: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                  validator: (v) {
                    if (v != _passCtrl.text) return 'Password tidak cocok';
                    return null;
                  }),
            ] else ...[
              GestureDetector(
                onTap: () => setState(() => _changePass = !_changePass),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: _changePass
                        ? AppColors.primaryLight
                        : AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: _changePass
                            ? AppColors.primary
                            : AppColors.lightGrey),
                  ),
                  child: Row(children: [
                    Icon(Icons.lock_reset_rounded,
                        size: 18,
                        color: _changePass
                            ? AppColors.primary
                            : AppColors.textGrey),
                    const SizedBox(width: 10),
                    Text('Ganti Password',
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            color: _changePass
                                ? AppColors.primary
                                : AppColors.textDark)),
                    const Spacer(),
                    Icon(
                        _changePass
                            ? Icons.check_box_rounded
                            : Icons.check_box_outline_blank_rounded,
                        size: 20,
                        color: _changePass
                            ? AppColors.primary
                            : AppColors.textGrey),
                  ]),
                ),
              ),
              if (_changePass) ...[
                const SizedBox(height: 12),
                _Field(
                    controller: _passCtrl,
                    label: 'Password Baru',
                    icon: Icons.lock_rounded,
                    obscure: _obscurePass,
                    suffixIcon: IconButton(
                      icon: Icon(
                          _obscurePass
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          size: 20),
                      onPressed: () =>
                          setState(() => _obscurePass = !_obscurePass),
                    ),
                    validator: (v) {
                      if (!_changePass) return null;
                      if (v == null || v.isEmpty) {
                        return 'Password baru wajib diisi';
                      }
                      if (v.length < 8) return 'Minimal 8 karakter';
                      return null;
                    }),
                const SizedBox(height: 12),
                _Field(
                    controller: _passConfirmCtrl,
                    label: 'Konfirmasi Password',
                    icon: Icons.lock_outline_rounded,
                    obscure: _obscureConfirm,
                    suffixIcon: IconButton(
                      icon: Icon(
                          _obscureConfirm
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          size: 20),
                      onPressed: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                    validator: (v) {
                      if (!_changePass) return null;
                      if (v != _passCtrl.text) return 'Password tidak cocok';
                      return null;
                    }),
              ],
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _loading ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Text(_isEdit ? 'Simpan Perubahan' : 'Tambah Admin',
                        style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscure;
  final TextInputType? keyboardType;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;

  const _Field({
    required this.controller,
    required this.label,
    required this.icon,
    this.obscure = false,
    this.keyboardType,
    this.suffixIcon,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
            fontFamily: 'Poppins', fontSize: 14, color: AppColors.textGrey),
        prefixIcon: Icon(icon, size: 20, color: AppColors.textGrey),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.lightGrey)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.lightGrey)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 2)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.red)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String? url;
  final File? file;
  final String name;
  final double size;

  const _Avatar({this.url, this.file, required this.name, required this.size});

  @override
  Widget build(BuildContext context) {
    ImageProvider? provider;
    if (file != null) {
      provider = FileImage(file!);
    } else if (url != null && url!.isNotEmpty) provider = NetworkImage(url!);

    final initials =
        name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'A';

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        shape: BoxShape.circle,
        image: provider != null
            ? DecorationImage(image: provider, fit: BoxFit.cover)
            : null,
      ),
      child: provider == null
          ? Center(
              child: Text(initials,
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: size * 0.35,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary)))
          : null,
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _IconBtn(
      {required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}

class _SearchBox extends StatelessWidget {
  final ValueChanged<String> onChanged;
  const _SearchBox({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.lightGrey),
      ),
      child: Row(children: [
        const SizedBox(width: 12),
        const Icon(Icons.search_rounded, size: 18, color: AppColors.textGrey),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            onChanged: onChanged,
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 13),
            decoration: const InputDecoration(
              hintText: 'Cari nama atau email...',
              hintStyle: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  color: AppColors.textGrey),
              border: InputBorder.none,
              isDense: true,
            ),
          ),
        ),
      ]),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasSearch;
  const _EmptyState({required this.hasSearch});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.admin_panel_settings_rounded,
            size: 52, color: AppColors.textGrey),
        const SizedBox(height: 12),
        Text(hasSearch ? 'Admin tidak ditemukan' : 'Belum ada admin',
            style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppColors.textGrey)),
      ]),
    );
  }
}
