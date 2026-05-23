import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/auth_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../admin/admin_dashboard.dart';
import '../driver/driver_dashboard.dart';
import '../siswa/siswa_dashboard.dart';
import '../../models/models_api.dart';
import 'register_siswa_screen.dart';
import 'pending_screen.dart';
import 'splash_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeIn);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final result = await authProvider.login(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (!mounted) return;

    if (result == LoginResult.success) {
      final user = authProvider.currentUser!;
      Widget nextScreen;
      switch (user.role) {
        case UserRole.admin:
          nextScreen = const AdminDashboard();
          break;
        case UserRole.driver:
          nextScreen = const DriverDashboard();
          break;
        case UserRole.siswa:
          nextScreen = const SiswaDashboard();
          break;
      }

      // tidak tampil lagi saat resume dari background
      SplashScreen.hasNavigated = true;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => nextScreen),
        (_) => false,
      );
    } else if (result == LoginResult.pending) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PendingScreen(email: _emailController.text.trim()),
        ),
      );
    } else if (result == LoginResult.rejected) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.loginError ?? 'Akun ditolak oleh admin'),
          backgroundColor: AppColors.red,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.loginError ?? 'Login gagal'),
          backgroundColor: AppColors.red,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  // ── Kontak admin via WhatsApp
  Future<void> _bukaWhatsApp(String noHp) async {
    final nomor = noHp.replaceAll(RegExp(r'[^0-9]'), '');
    final intl = nomor.startsWith('0') ? '62${nomor.substring(1)}' : nomor;
    final pesan = Uri.encodeComponent(
        'Halo Admin, saya lupa password akun MoBus saya. Mohon bantuannya. 🙏');
    final url = Uri.parse('https://wa.me/$intl?text=$pesan');
    if (await canLaunchUrl(url)) await launchUrl(url);
  }

  // ── Kontak admin via Email
  Future<void> _bukaEmail(String email) async {
    final url = Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: {
        'subject': 'Reset Password Akun MoBus',
        'body':
            'Halo Admin,\n\nSaya lupa password untuk akun MoBus saya.\nEmail akun saya: ${_emailController.text.trim()}\n\nMohon bantuannya.\n\nTerima kasih.',
      },
    );
    if (await canLaunchUrl(url)) await launchUrl(url);
  }

  void _showForgotDialog(BuildContext context) {
    // Info kontak admin — ganti dengan data admin sekolah
    const String adminWhatsApp = '081234567890';
    const String adminEmail = 'admin@diskominfo.kotamadiun.com';
    const String adminNama = 'Admin Dinas Kominfo Kota Madiun';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.lightGrey,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),

            // Ikon + judul
            Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.lock_reset_rounded,
                    color: AppColors.orange, size: 22),
              ),
              const SizedBox(width: 14),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Lupa Password?',
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 18,
                          fontWeight: FontWeight.w700)),
                  Text('Hubungi admin untuk reset password',
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: AppColors.textGrey)),
                ],
              ),
            ]),
            const SizedBox(height: 20),

            // Info box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: const Row(children: [
                Icon(Icons.info_outline_rounded,
                    size: 16, color: AppColors.primary),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Password hanya bisa direset oleh admin. Hubungi admin sekolah melalui salah satu kontak di bawah.',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        color: AppColors.primary),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 20),

            // Label kontak
            const Text('Kontak Admin',
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryDark)),
            const SizedBox(height: 12),

            // Tombol WhatsApp
            _KontakBtn(
              icon: Icons.chat_rounded,
              warna: const Color(0xFF25D366),
              warnaBg: const Color(0xFF25D366).withValues(alpha: 0.1),
              judul: 'Chat WhatsApp',
              subjudul: adminWhatsApp,
              onTap: () async {
                Navigator.pop(ctx);
                await _bukaWhatsApp(adminWhatsApp);
              },
            ),
            const SizedBox(height: 10),

            // Tombol Email
            _KontakBtn(
              icon: Icons.email_rounded,
              warna: AppColors.primary,
              warnaBg: AppColors.primaryLight,
              judul: 'Kirim Email',
              subjudul: adminEmail,
              onTap: () async {
                Navigator.pop(ctx);
                await _bukaEmail(adminEmail);
              },
            ),
            const SizedBox(height: 10),

            // Salin nomor WA
            _KontakBtn(
              icon: Icons.copy_rounded,
              warna: AppColors.textGrey,
              warnaBg: AppColors.lightGrey.withValues(alpha: 0.6),
              judul: 'Salin Nomor Admin',
              subjudul: '$adminNama · $adminWhatsApp',
              onTap: () async {
                await Clipboard.setData(
                    const ClipboardData(text: adminWhatsApp));
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: const Text('Nomor $adminNama disalin',
                      style: TextStyle(fontFamily: 'Poppins')),
                  backgroundColor: AppColors.primary,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ));
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    // Logo
                    Image.asset(
                      'assets/images/Logo1.png',
                      width: 100,
                      height: 100,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 36),

                    // Welcome text
                    Align(
                      alignment: Alignment.centerLeft,
                      child: RichText(
                        text: const TextSpan(
                          children: [
                            TextSpan(
                              text: 'Selamat\nDatang ',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                                color: AppColors.black,
                                height: 1.2,
                              ),
                            ),
                            TextSpan(
                              text: 'Kembali',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Masuk ke akun Anda untuk melanjutkan',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          color: AppColors.textGrey,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Email field
                    AppTextField(
                      label: 'Email/Username',
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) =>
                          v!.isEmpty ? 'Email tidak boleh kosong' : null,
                    ),
                    const SizedBox(height: 16),

                    // Password field
                    AppTextField(
                      label: 'Password',
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      validator: (v) =>
                          v!.isEmpty ? 'Password tidak boleh kosong' : null,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: AppColors.textGrey,
                        ),
                        onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Forgot password
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => _showForgotDialog(context),
                        child: const Text(
                          'Lupa Password?',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Login Button
                    Consumer<AuthProvider>(
                      builder: (_, auth, __) => PrimaryButton(
                        text: 'Masuk',
                        icon: Icons.login_rounded,
                        isLoading: auth.isLoading,
                        onPressed: _login,
                      ),
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'atau',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        color: AppColors.textGrey,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Register as Siswa
                    PrimaryButton(
                      text: 'Daftar sebagai Siswa',
                      icon: Icons.person_add_outlined,
                      isOutline: true,
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const RegisterSiswaScreen()),
                        );
                      },
                    ),
                    const SizedBox(height: 20),

                    // Driver info
                    const Text(
                      'Login Driver? Hubungi pengelola sistem',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        color: AppColors.textGrey,
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
}

// ── Widget tombol kontak admin ─────────────────────────────────
class _KontakBtn extends StatelessWidget {
  final IconData icon;
  final Color warna;
  final Color warnaBg;
  final String judul;
  final String subjudul;
  final VoidCallback onTap;

  const _KontakBtn({
    required this.icon,
    required this.warna,
    required this.warnaBg,
    required this.judul,
    required this.subjudul,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.lightGrey),
        ),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: warnaBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: warna, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(judul,
                    style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                Text(subjudul,
                    style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        color: AppColors.textGrey)),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios_rounded, size: 14, color: warna),
        ]),
      ),
    );
  }
}
