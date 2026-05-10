import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/app_theme.dart';
import '../../services/auth_provider.dart';
import '../../models/models_api.dart';
import 'login_screen.dart';
import '../admin/admin_dashboard.dart';
import '../driver/driver_dashboard.dart';
import '../siswa/siswa_dashboard.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  // [FIX SPLASH LOGIN] Flag static di public class agar bisa diakses
  // dari LoginScreen saat user login manual — set true setelah login sukses
  // sehingga SplashScreen tidak tampil lagi saat Android resume activity.
  static bool hasNavigated = false;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _busController;
  late Animation<double> _busAnimation;

  // [FIX SPLASH] Pakai flag dari SplashScreen (public) agar bisa di-set
  // dari LoginScreen juga — mencegah splash muncul saat resume/login.

  @override
  void initState() {
    super.initState();
    _busController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _busAnimation = CurvedAnimation(
      parent: _busController,
      curve: Curves.elasticOut,
    );

    // [FIX SPLASH] Jika sudah pernah navigasi (resume dari background,
    // atau user sudah login manual), langsung navigasi tanpa animasi splash.
    if (SplashScreen.hasNavigated) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _navigate());
      return;
    }

    _busController.forward();

    Future.delayed(const Duration(milliseconds: 2000), () async {
      await _navigate();
    });
  }

  @override
  void dispose() {
    _busController.dispose();
    super.dispose();
  }

  // [FIX BUG 3] Pisahkan logika navigasi ke method sendiri
  Future<void> _navigate() async {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    final autoLogin = await auth.tryAutoLogin();
    if (!mounted) return;
    Widget next;
    if (autoLogin && auth.currentUser != null) {
      switch (auth.currentUser!.role) {
        case UserRole.admin:
          next = const AdminDashboard();
          break;
        case UserRole.driver:
          next = const DriverDashboard();
          break;
        default:
          next = const SiswaDashboard();
      }
    } else {
      next = const LoginScreen();
    }
    // Tandai sudah navigasi agar resume berikutnya tidak tampil splash
    SplashScreen.hasNavigated = true;
    Navigator.of(context)
        .pushReplacement(MaterialPageRoute(builder: (_) => next));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _busAnimation,
              child: Image.asset(
                'assets/images/Logo1.png',
                width: 200,
                height: 200,
                fit: BoxFit.contain,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
