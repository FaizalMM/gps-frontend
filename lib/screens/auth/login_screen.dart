import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../admin/admin_dashboard.dart';
import '../driver/driver_dashboard.dart';
import '../siswa/siswa_dashboard.dart';
import '../../models/models_api.dart';
import 'register_siswa_screen.dart';
import 'pending_screen.dart';

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
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => nextScreen),
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

  void _showForgotDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Lupa Password?',
            style:
                TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
        content: const Text(
          'Hubungi admin sekolah untuk mereset password akun kamu.',
          style: TextStyle(
              fontFamily: 'Poppins', fontSize: 13, color: Color(0xFF888888)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Mengerti',
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF7CBF2F))),
          ),
        ],
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
                      'assets/images/logo.png',
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

class _BusPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bodyPaint = Paint()..color = const Color(0xFF7CBF2F);
    final darkPaint = Paint()..color = const Color(0xFF5A9A1A);
    final windowPaint = Paint()..color = const Color(0xFF87CEEB);
    final redPaint = Paint()..color = const Color(0xFFE53E3E);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.05, size.height * 0.1, size.width * 0.9,
            size.height * 0.7),
        const Radius.circular(8),
      ),
      bodyPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.05, size.height * 0.15, size.width * 0.9,
          size.height * 0.08),
      darkPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.1, size.height * 0.27, size.width * 0.35,
            size.height * 0.2),
        const Radius.circular(3),
      ),
      windowPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.55, size.height * 0.27, size.width * 0.35,
            size.height * 0.2),
        const Radius.circular(3),
      ),
      windowPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.05, size.height * 0.72, size.width * 0.9,
          size.height * 0.05),
      redPaint,
    );
    final wheelPaint = Paint()..color = const Color(0xFF2D2D2D);
    canvas.drawCircle(Offset(size.width * 0.25, size.height * 0.85),
        size.width * 0.12, wheelPaint);
    canvas.drawCircle(Offset(size.width * 0.75, size.height * 0.85),
        size.width * 0.12, wheelPaint);
    final rimPaint = Paint()..color = const Color(0xFFCCCCCC);
    canvas.drawCircle(Offset(size.width * 0.25, size.height * 0.85),
        size.width * 0.06, rimPaint);
    canvas.drawCircle(Offset(size.width * 0.75, size.height * 0.85),
        size.width * 0.06, rimPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
