import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/api_client.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';
import 'login_screen.dart';

enum _ApprovalStatus { pending, approved, rejected }

class PendingScreen extends StatefulWidget {
  final String email;
  const PendingScreen({super.key, required this.email});

  @override
  State<PendingScreen> createState() => _PendingScreenState();
}

class _PendingScreenState extends State<PendingScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;
  late AnimationController _dialogController;
  late Animation<double> _dialogScale;

  _ApprovalStatus _status = _ApprovalStatus.pending;
  String? _rejectionReason;
  bool _dialogShown = false;
  Timer? _pollingTimer;
  int _pollCount = 0;

  final _api = ApiClient();

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _dialogController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _dialogScale = CurvedAnimation(
      parent: _dialogController,
      curve: Curves.elasticOut,
    );

    _checkApproval();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _checkApproval();
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _pulseController.dispose();
    _dialogController.dispose();
    super.dispose();
  }

  Future<void> _checkApproval() async {
    _pollCount++;
    if (_pollCount > 720) {
      _pollingTimer?.cancel();
      return;
    }
    try {
      final res = await _api.post(
        '/auth/check-approval',
        {'email': widget.email},
        withAuth: false,
      );
      if (!mounted) return;
      if (!res.success || res.data == null) return;
      final data = res.data!['data'] as Map<String, dynamic>?;
      if (data == null) return;
      final statusStr = data['status'] as String?;
      if (statusStr == null) return;
      final newStatus = statusStr == 'approved'
          ? _ApprovalStatus.approved
          : statusStr == 'rejected'
              ? _ApprovalStatus.rejected
              : _ApprovalStatus.pending;
      if (newStatus != _status) {
        setState(() {
          _status = newStatus;
          if (newStatus == _ApprovalStatus.rejected) {
            _rejectionReason = data['rejection_reason'] as String?;
          }
        });
        if (newStatus != _ApprovalStatus.pending) {
          _pollingTimer?.cancel();
          _showResultDialog();
        }
      }
    } catch (_) {}
  }

  void _showResultDialog() {
    if (_dialogShown || !mounted) return;
    _dialogShown = true;
    _pulseController.stop();
    _dialogController.forward();
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (_) => ScaleTransition(
        scale: _dialogScale,
        child: _status == _ApprovalStatus.approved
            ? _ApprovedDialog(onLogin: _goToLogin)
            : _RejectedDialog(
                reason: _rejectionReason ?? 'Tidak ada keterangan.',
                onBack: _goToLogin,
              ),
      ),
    );
  }

  void _goToLogin() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
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
              AnimatedBuilder(
                animation: _pulseAnim,
                builder: (_, child) =>
                    Transform.scale(scale: _pulseAnim.value, child: child),
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
                      child: Text('⏳', style: TextStyle(fontSize: 48))),
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
                'Akun sedang direview Admin.\nHalaman ini akan otomatis update saat disetujui.',
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    color: AppColors.textGrey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.pendingOrange),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Memantau status secara otomatis...',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        color: AppColors.textGrey),
                  ),
                ],
              ),
              const SizedBox(height: 32),
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
                child: Column(
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
                      isActive: _status == _ApprovalStatus.pending,
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
                onPressed: _goToLogin,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Dialog Approved ──────────────────────────────────────────
class _ApprovedDialog extends StatelessWidget {
  final VoidCallback onLogin;
  const _ApprovedDialog({required this.onLogin});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                  color: Color(0xFFE8F5E9), shape: BoxShape.circle),
              child: const Center(
                  child: Text('🎉', style: TextStyle(fontSize: 40))),
            ),
            const SizedBox(height: 20),
            const Text(
              'Akun Disetujui!',
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.black),
            ),
            const SizedBox(height: 10),
            const Text(
              'Selamat! Admin telah menyetujui akun kamu.\nCek email untuk konfirmasi, lalu login sekarang.',
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  color: AppColors.textGrey,
                  height: 1.6),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Login Sekarang',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w600,
                        fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Dialog Rejected ──────────────────────────────────────────
class _RejectedDialog extends StatelessWidget {
  final String reason;
  final VoidCallback onBack;
  const _RejectedDialog({required this.reason, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                  color: Color(0xFFFFEBEE), shape: BoxShape.circle),
              child: const Center(
                  child: Text('😔', style: TextStyle(fontSize: 40))),
            ),
            const SizedBox(height: 20),
            const Text(
              'Pendaftaran Ditolak',
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.black),
            ),
            const SizedBox(height: 10),
            const Text(
              'Maaf, Admin tidak menyetujui pendaftaran kamu.',
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  color: AppColors.textGrey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                border: const Border(
                    left: BorderSide(color: Colors.orange, width: 4)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ALASAN',
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.orange,
                          letterSpacing: 1)),
                  const SizedBox(height: 4),
                  Text(reason,
                      style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          color: AppColors.black,
                          height: 1.5)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onBack,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Kembali ke Login',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w600,
                        fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Widget pembantu ──────────────────────────────────────────
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
          decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
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
                Text(subtitle!,
                    style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        color: AppColors.textGrey)),
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
