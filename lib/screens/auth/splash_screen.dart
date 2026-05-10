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

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _busController;
  late AnimationController _fadeController;
  late Animation<double> _busAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _busController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _busAnimation = CurvedAnimation(
      parent: _busController,
      curve: Curves.elasticOut,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));

    _busController.forward();
    Future.delayed(const Duration(milliseconds: 400), () {
      _fadeController.forward();
    });

    Future.delayed(const Duration(milliseconds: 2000), () async {
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
      Navigator.of(context)
          .pushReplacement(MaterialPageRoute(builder: (_) => next));
    });
  }

  @override
  void dispose() {
    _busController.dispose();
    _fadeController.dispose();
    super.dispose();
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
                'assets/images/logo.png',
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

class _BusIcon extends StatelessWidget {
  final double size;
  const _BusIcon({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _BusPainter(),
      ),
    );
  }
}

class _BusPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bodyPaint = Paint()
      ..color = const Color(0xFF7CBF2F)
      ..style = PaintingStyle.fill;
    final darkPaint = Paint()
      ..color = const Color(0xFF5A9A1A)
      ..style = PaintingStyle.fill;
    final windowPaint = Paint()
      ..color = const Color(0xFF87CEEB)
      ..style = PaintingStyle.fill;
    final greyPaint = Paint()
      ..color = const Color(0xFF888888)
      ..style = PaintingStyle.fill;
    final redPaint = Paint()
      ..color = const Color(0xFFE53E3E)
      ..style = PaintingStyle.fill;

    // Bus body
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.05, size.height * 0.1, size.width * 0.9,
          size.height * 0.7),
      const Radius.circular(12),
    );
    canvas.drawRRect(bodyRect, bodyPaint);

    // Top dark stripe
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.05, size.height * 0.15, size.width * 0.9,
          size.height * 0.08),
      darkPaint,
    );

    // Windows
    final windowRect1 = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.1, size.height * 0.25, size.width * 0.35,
          size.height * 0.2),
      const Radius.circular(4),
    );
    canvas.drawRRect(windowRect1, windowPaint);

    final windowRect2 = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.55, size.height * 0.25, size.width * 0.35,
          size.height * 0.2),
      const Radius.circular(4),
    );
    canvas.drawRRect(windowRect2, windowPaint);

    // Front bumper red stripe
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.05, size.height * 0.72, size.width * 0.9,
          size.height * 0.05),
      redPaint,
    );

    // Wheels
    final wheelPaint = Paint()..color = const Color(0xFF2D2D2D);
    canvas.drawCircle(Offset(size.width * 0.25, size.height * 0.85),
        size.width * 0.12, wheelPaint);
    canvas.drawCircle(Offset(size.width * 0.75, size.height * 0.85),
        size.width * 0.12, wheelPaint);

    // Wheel rims
    final rimPaint = Paint()..color = const Color(0xFFCCCCCC);
    canvas.drawCircle(Offset(size.width * 0.25, size.height * 0.85),
        size.width * 0.06, rimPaint);
    canvas.drawCircle(Offset(size.width * 0.75, size.height * 0.85),
        size.width * 0.06, rimPaint);

    // Antenna
    final antennaPaint = Paint()
      ..color = const Color(0xFF444444)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(size.width * 0.5, size.height * 0.1),
      Offset(size.width * 0.5, size.height * 0.01),
      antennaPaint,
    );
    canvas.drawCircle(
        Offset(size.width * 0.5, size.height * 0.01), 3, greyPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
