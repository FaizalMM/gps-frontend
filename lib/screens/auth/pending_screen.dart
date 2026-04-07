import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';
import 'login_screen.dart';

class PendingScreen extends StatefulWidget {
  const PendingScreen({super.key});

  @override
  State<PendingScreen> createState() => _PendingScreenState();
}

class _PendingScreenState extends State<PendingScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Hourglass animation
              AnimatedBuilder(
                animation: _pulseAnim,
                builder: (_, child) => Transform.scale(
                  scale: _pulseAnim.value,
                  child: child,
                ),
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.pendingOrange.withValues(alpha: 0.3),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      '⏳',
                      style: TextStyle(fontSize: 48),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              const Text(
                'Menunggu Persetujuan',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.black,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Akun sedang direview Admin. Tunggu 1×24 jam.',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  color: AppColors.textGrey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),

              // Status steps
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Column(
                  children: [
                    _StatusStep(
                      icon: Icons.check_circle_rounded,
                      label: 'Registrasi Terkirim',
                      isCompleted: true,
                      isActive: false,
                    ),
                    _StepConnector(isCompleted: true),
                    _StatusStep(
                      icon: Icons.hourglass_top_rounded,
                      label: 'Menunggu Persetujuan Admin',
                      subtitle: 'Sedang diproses...',
                      isCompleted: false,
                      isActive: true,
                    ),
                    _StepConnector(isCompleted: false),
                    _StatusStep(
                      icon: Icons.verified_rounded,
                      label: 'Akun Diaktifkan',
                      isCompleted: false,
                      isActive: false,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              PrimaryButton(
                text: 'Kembali ke Login',
                icon: Icons.arrow_back_rounded,
                isOutline: true,
                onPressed: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusStep extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final bool isCompleted;
  final bool isActive;

  const _StatusStep({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.isCompleted,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    Color iconColor;
    Color bgColor;

    if (isCompleted) {
      iconColor = AppColors.primary;
      bgColor = AppColors.primaryLight;
    } else if (isActive) {
      iconColor = AppColors.pendingOrange;
      bgColor = const Color(0xFFFEF3C7);
    } else {
      iconColor = AppColors.lightGrey;
      bgColor = AppColors.lightGrey;
    }

    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isCompleted || isActive
                      ? AppColors.black
                      : AppColors.textGrey,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    color: AppColors.textGrey,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StepConnector extends StatelessWidget {
  final bool isCompleted;

  const _StepConnector({required this.isCompleted});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 19, top: 4, bottom: 4),
      child: Container(
        width: 2,
        height: 28,
        color: isCompleted ? AppColors.primary : AppColors.lightGrey,
      ),
    );
  }
}
