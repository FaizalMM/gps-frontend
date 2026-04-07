import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';
import 'pending_screen.dart';

class RegisterSiswaScreen extends StatefulWidget {
  const RegisterSiswaScreen({super.key});
  @override
  State<RegisterSiswaScreen> createState() => _RegisterSiswaScreenState();
}

class _RegisterSiswaScreenState extends State<RegisterSiswaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _namaController = TextEditingController();
  final _emailController = TextEditingController();
  final _nisController = TextEditingController();
  final _sekolahController = TextEditingController();
  final _noHpController = TextEditingController();
  final _alamatController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _namaController.dispose();
    _emailController.dispose();
    _nisController.dispose();
    _sekolahController.dispose();
    _noHpController.dispose();
    _alamatController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final result = await auth.registerSiswa(
      namaLengkap: _namaController.text.trim(),
      email: _emailController.text.trim(),
      nis: _nisController.text.trim(),
      sekolah: _sekolahController.text.trim(),
      noHp: _noHpController.text.trim(),
      alamat: _alamatController.text.trim(),
      password: _passwordController.text,
    );
    if (!mounted) return;
    if (result == RegisterResult.success) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const PendingScreen()),
      );
    } else {
      final msg = result == RegisterResult.emailExists
          ? 'Email sudah terdaftar'
          : result == RegisterResult.nisExists
              ? 'NIS sudah terdaftar'
              : 'Pendaftaran gagal, coba lagi';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    }
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
              size: 20, color: AppColors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Daftar Akun Siswa',
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
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Info banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: const Row(children: [
                Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                SizedBox(width: 10),
                Expanded(
                    child: Text(
                  'Akun memerlukan persetujuan Admin sebelum dapat digunakan.',
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: AppColors.primaryDark),
                )),
              ]),
            ),
            const SizedBox(height: 24),

            AppTextField(
                label: 'Nama Lengkap',
                controller: _namaController,
                validator: (v) =>
                    v!.isEmpty ? 'Nama tidak boleh kosong' : null),
            const SizedBox(height: 16),
            AppTextField(
                label: 'Email',
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v!.isEmpty) return 'Email tidak boleh kosong';
                  if (!v.contains('@')) return 'Format email tidak valid';
                  return null;
                }),
            const SizedBox(height: 16),
            AppTextField(
                label: 'NIS (Nomor Induk Siswa)',
                controller: _nisController,
                keyboardType: TextInputType.number,
                validator: (v) => v!.isEmpty ? 'NIS tidak boleh kosong' : null),
            const SizedBox(height: 16),
            AppTextField(
                label: 'Nama Sekolah',
                controller: _sekolahController,
                validator: (v) =>
                    v!.isEmpty ? 'Sekolah tidak boleh kosong' : null),
            const SizedBox(height: 16),
            AppTextField(
                label: 'No HP',
                controller: _noHpController,
                keyboardType: TextInputType.phone,
                validator: (v) =>
                    v!.isEmpty ? 'No. HP tidak boleh kosong' : null),
            const SizedBox(height: 16),
            AppTextField(
                label: 'Alamat',
                controller: _alamatController,
                validator: (v) =>
                    v!.isEmpty ? 'Alamat tidak boleh kosong' : null),
            const SizedBox(height: 16),
            AppTextField(
              label: 'Password (min. 8 karakter)',
              controller: _passwordController,
              obscureText: _obscurePassword,
              validator: (v) {
                if (v!.isEmpty) return 'Password tidak boleh kosong';
                if (v.length < 8) return 'Password minimal 8 karakter';
                return null;
              },
              suffixIcon: IconButton(
                icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: AppColors.textGrey),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            const SizedBox(height: 32),
            Consumer<AuthProvider>(
              builder: (_, auth, __) => PrimaryButton(
                text: 'Kirim Pendaftaran',
                icon: Icons.send_rounded,
                isLoading: auth.isLoading,
                onPressed: _register,
              ),
            ),
            const SizedBox(height: 20),
          ]),
        ),
      ),
    );
  }
}
