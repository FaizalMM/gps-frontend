// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import '../../models/models_api.dart';
import '../../services/domain_services.dart';
import '../../utils/app_theme.dart';

/// Screen untuk admin mengedit data siswa:
/// nama, email, NIS, sekolah, kelas, alamat, no_hp, dan reset password.
class EditSiswaScreen extends StatefulWidget {
  final UserModel siswa;

  const EditSiswaScreen({super.key, required this.siswa});

  @override
  State<EditSiswaScreen> createState() => _EditSiswaScreenState();
}

class _EditSiswaScreenState extends State<EditSiswaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _studentService = StudentService();

  // Controllers data user
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;

  // Controllers data student
  late final TextEditingController _nisCtrl;
  late final TextEditingController _sekolahCtrl;
  late final TextEditingController _kelasCtrl;
  late final TextEditingController _alamatCtrl;
  late final TextEditingController _noHpCtrl;

  // Controllers untuk reset password (opsional)
  final TextEditingController _passwordCtrl = TextEditingController();
  final TextEditingController _passwordConfirmCtrl = TextEditingController();

  bool _isLoading = false;
  bool _ubahPassword = false;
  bool _showPassword = false;
  bool _showPasswordConfirm = false;

  @override
  void initState() {
    super.initState();
    final s = widget.siswa;
    final sd = s.studentDetail;

    _nameCtrl = TextEditingController(text: s.namaLengkap);
    _emailCtrl = TextEditingController(text: s.email);
    _nisCtrl = TextEditingController(text: sd?.nis ?? '');
    _sekolahCtrl = TextEditingController(text: sd?.sekolah ?? '');
    _kelasCtrl = TextEditingController(text: sd?.kelas ?? '');
    _alamatCtrl = TextEditingController(text: sd?.alamat ?? s.alamat);
    _noHpCtrl = TextEditingController(text: sd?.noHp ?? s.noHp);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _nisCtrl.dispose();
    _sekolahCtrl.dispose();
    _kelasCtrl.dispose();
    _alamatCtrl.dispose();
    _noHpCtrl.dispose();
    _passwordCtrl.dispose();
    _passwordConfirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _simpan() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final userId = widget.siswa.id;

      final data = <String, dynamic>{
        'name': _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'nis': _nisCtrl.text.trim(),
        'sekolah': _sekolahCtrl.text.trim(),
        'kelas': _kelasCtrl.text.trim(),
        'alamat': _alamatCtrl.text.trim(),
        'no_hp': _noHpCtrl.text.trim(),
      };

      if (_ubahPassword && _passwordCtrl.text.isNotEmpty) {
        data['password'] = _passwordCtrl.text;
        data['password_confirmation'] = _passwordConfirmCtrl.text;
      }

      final ok = await _studentService.updateStudent(userId, data);

      if (!mounted) return;

      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Data ${_nameCtrl.text.trim()} berhasil diperbarui'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
        Navigator.pop(context, true); // true = ada perubahan, trigger reload
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Gagal memperbarui data. Coba lagi.'),
          backgroundColor: AppColors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: $e'),
        backgroundColor: AppColors.red,
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
        title: const Text('Edit Data Siswa',
            style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: AppColors.black)),
        centerTitle: true,
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.primary),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _simpan,
              child: const Text('Simpan',
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                      fontSize: 14)),
            ),
        ],
        bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(color: AppColors.lightGrey, height: 0.5)),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Avatar + nama siswa
            Center(
              child: Column(children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                      color: AppColors.primaryLight, shape: BoxShape.circle),
                  child: Center(
                    child: Text(
                      widget.siswa.namaLengkap.isNotEmpty
                          ? widget.siswa.namaLengkap[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w700,
                          fontSize: 28,
                          color: AppColors.primary),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(widget.siswa.namaLengkap,
                    style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.black)),
                const SizedBox(height: 2),
                Text(widget.siswa.email,
                    style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        color: AppColors.textGrey)),
              ]),
            ),
            const SizedBox(height: 24),

            // ── Seksi: Data Akun ──
            const _SectionHeader(
                icon: Icons.account_circle_outlined, label: 'Data Akun'),
            const SizedBox(height: 12),

            _FormField(
              controller: _nameCtrl,
              label: 'Nama Lengkap',
              icon: Icons.person_outline_rounded,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Nama wajib diisi' : null,
            ),
            const SizedBox(height: 12),

            _FormField(
              controller: _emailCtrl,
              label: 'Email',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Email wajib diisi';
                if (!v.contains('@')) return 'Format email tidak valid';
                return null;
              },
            ),
            const SizedBox(height: 20),

            // ── Seksi: Data Siswa ──
            const _SectionHeader(
                icon: Icons.school_outlined, label: 'Data Siswa'),
            const SizedBox(height: 12),

            _FormField(
              controller: _nisCtrl,
              label: 'NIS',
              icon: Icons.badge_outlined,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'NIS wajib diisi' : null,
            ),
            const SizedBox(height: 12),

            _FormField(
              controller: _sekolahCtrl,
              label: 'Sekolah',
              icon: Icons.business_outlined,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Nama sekolah wajib diisi'
                  : null,
            ),
            const SizedBox(height: 12),

            _FormField(
              controller: _kelasCtrl,
              label: 'Kelas',
              icon: Icons.class_outlined,
            ),
            const SizedBox(height: 12),

            _FormField(
              controller: _noHpCtrl,
              label: 'No. HP / WhatsApp',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),

            // Alamat — multiline
            TextFormField(
              controller: _alamatCtrl,
              maxLines: 3,
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 13),
              decoration: InputDecoration(
                labelText: 'Alamat Rumah',
                labelStyle: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    color: AppColors.textGrey),
                prefixIcon: const Icon(Icons.home_outlined,
                    size: 20, color: AppColors.textGrey),
                filled: true,
                fillColor: AppColors.white,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.lightGrey)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.lightGrey)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: AppColors.primary, width: 2)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              ),
            ),
            const SizedBox(height: 24),

            // ── Seksi: Reset Password ──
            Container(
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color:
                        _ubahPassword ? AppColors.orange : AppColors.lightGrey),
              ),
              child: Column(children: [
                // Toggle ubah password
                SwitchListTile.adaptive(
                  value: _ubahPassword,
                  onChanged: (v) {
                    setState(() {
                      _ubahPassword = v;
                      if (!v) {
                        _passwordCtrl.clear();
                        _passwordConfirmCtrl.clear();
                      }
                    });
                  },
                  title: const Text('Ubah Password',
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  subtitle: const Text('Kosongkan jika tidak ingin diubah',
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          color: AppColors.textGrey)),
                  activeColor: AppColors.orange,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                ),

                if (_ubahPassword) ...[
                  const Divider(height: 1, color: AppColors.lightGrey),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                    child: Column(children: [
                      // Password baru
                      TextFormField(
                        controller: _passwordCtrl,
                        obscureText: !_showPassword,
                        style: const TextStyle(
                            fontFamily: 'Poppins', fontSize: 13),
                        decoration: InputDecoration(
                          labelText: 'Password Baru',
                          labelStyle: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13,
                              color: AppColors.textGrey),
                          prefixIcon: const Icon(Icons.lock_outline_rounded,
                              size: 20, color: AppColors.textGrey),
                          suffixIcon: IconButton(
                            icon: Icon(
                                _showPassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                size: 18,
                                color: AppColors.textGrey),
                            onPressed: () =>
                                setState(() => _showPassword = !_showPassword),
                          ),
                          filled: true,
                          fillColor: AppColors.background,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  const BorderSide(color: AppColors.lightGrey)),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  const BorderSide(color: AppColors.lightGrey)),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                  color: AppColors.orange, width: 2)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 14),
                        ),
                        validator: _ubahPassword
                            ? (v) {
                                if (v == null || v.isEmpty) {
                                  return 'Password baru wajib diisi';
                                }
                                if (v.length < 8) {
                                  return 'Minimal 8 karakter';
                                }
                                return null;
                              }
                            : null,
                      ),
                      const SizedBox(height: 10),

                      // Konfirmasi password
                      TextFormField(
                        controller: _passwordConfirmCtrl,
                        obscureText: !_showPasswordConfirm,
                        style: const TextStyle(
                            fontFamily: 'Poppins', fontSize: 13),
                        decoration: InputDecoration(
                          labelText: 'Konfirmasi Password',
                          labelStyle: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13,
                              color: AppColors.textGrey),
                          prefixIcon: const Icon(Icons.lock_reset_rounded,
                              size: 20, color: AppColors.textGrey),
                          suffixIcon: IconButton(
                            icon: Icon(
                                _showPasswordConfirm
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                size: 18,
                                color: AppColors.textGrey),
                            onPressed: () => setState(() =>
                                _showPasswordConfirm = !_showPasswordConfirm),
                          ),
                          filled: true,
                          fillColor: AppColors.background,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  const BorderSide(color: AppColors.lightGrey)),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  const BorderSide(color: AppColors.lightGrey)),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                  color: AppColors.orange, width: 2)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 14),
                        ),
                        validator: _ubahPassword
                            ? (v) {
                                if (v == null || v.isEmpty) {
                                  return 'Konfirmasi password wajib diisi';
                                }
                                if (v != _passwordCtrl.text) {
                                  return 'Password tidak cocok';
                                }
                                return null;
                              }
                            : null,
                      ),
                      const SizedBox(height: 12),

                      // Info warning reset password
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: AppColors.orange.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color:
                                    AppColors.orange.withValues(alpha: 0.3))),
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
                      const SizedBox(height: 12),
                    ]),
                  ),
                ],
              ]),
            ),
            const SizedBox(height: 32),

            // Tombol simpan
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _simpan,
                icon: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_rounded, size: 18),
                label: Text(_isLoading ? 'Menyimpan...' : 'Simpan Perubahan',
                    style: const TextStyle(
                        fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
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
            const SizedBox(height: 16),

            // Tombol batal
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _isLoading ? null : () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textGrey,
                  side: const BorderSide(color: AppColors.lightGrey),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Batal',
                    style: TextStyle(
                        fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ── Widget Helper: Section Header ─────────────────────────────
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionHeader({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 16, color: AppColors.primary),
      const SizedBox(width: 8),
      Text(label,
          style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryDark)),
    ]);
  }
}

// ── Widget Helper: Form Field ──────────────────────────────────
class _FormField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;

  const _FormField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType = TextInputType.text,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(fontFamily: 'Poppins', fontSize: 13),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
            fontFamily: 'Poppins', fontSize: 13, color: AppColors.textGrey),
        prefixIcon: Icon(icon, size: 20, color: AppColors.textGrey),
        filled: true,
        fillColor: AppColors.white,
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
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.red, width: 2)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}
