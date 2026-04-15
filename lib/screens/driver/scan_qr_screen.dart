import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import '../../models/models_api.dart';
import '../../services/domain_services.dart';
import '../../services/app_data_service.dart';
import '../../utils/app_theme.dart';

class ScanQrScreen extends StatefulWidget {
  final AppDataService dataService;
  const ScanQrScreen({super.key, required this.dataService});

  @override
  State<ScanQrScreen> createState() => _ScanQrScreenState();
}

class _ScanQrScreenState extends State<ScanQrScreen>
    with SingleTickerProviderStateMixin {
  final MobileScannerController _cam = MobileScannerController();
  bool _hasScanned = false;
  bool _torchOn = false;
  late AnimationController _scanAnim;
  late Animation<double> _scanLine;

  @override
  void initState() {
    super.initState();
    _scanAnim =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat();
    _scanLine = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _scanAnim, curve: Curves.linear));
  }

  @override
  void dispose() {
    _cam.stop();
    _cam.dispose();
    _scanAnim.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasScanned) return;
    for (final barcode in capture.barcodes) {
      final code = barcode.rawValue;
      if (code != null) {
        setState(() => _hasScanned = true);
        _verify(code);
        break;
      }
    }
  }

  Future<void> _verify(String qrData) async {
    try {
      final data = jsonDecode(qrData) as Map<String, dynamic>;
      if (data['student_id'] == null) {
        _showResult(ScanQrResult.error('QR Code tidak valid atau kadaluarsa'));
        return;
      }

      // Ambil posisi GPS driver
      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings:
              const LocationSettings(accuracy: LocationAccuracy.medium),
        );
      } catch (_) {}

      final lat = pos?.latitude ?? -7.6298;
      final lng = pos?.longitude ?? 111.5239;

      // Kirim ke backend
      final result = await DriverService()
          .scanStudentQr(data, latitude: lat, longitude: lng);

      _showResult(result);
    } catch (_) {
      _showResult(ScanQrResult.error('QR Code tidak dapat dibaca'));
    }
  }

  void _showResult(ScanQrResult result) {
    _cam.stop();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      isScrollControlled: true,
      builder: (ctx) => _ResultSheet(
        result: result,
        onNext: () {
          Navigator.pop(ctx);
          setState(() => _hasScanned = false);
          _cam.start();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      body: Stack(children: [
        MobileScanner(controller: _cam, onDetect: _onDetect, fit: BoxFit.cover),
        _ScanOverlay(),
        // Frame scan + garis animasi
        Center(
          child: SizedBox(
            width: 260,
            height: 260,
            child: Stack(children: [
              ..._corners(),
              AnimatedBuilder(
                animation: _scanLine,
                builder: (_, __) => Positioned(
                  top: 260 * _scanLine.value - 1,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 2,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [
                        Colors.transparent,
                        AppColors.primary,
                        AppColors.primary,
                        Colors.transparent
                      ]),
                      boxShadow: [
                        BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.6),
                            blurRadius: 6)
                      ],
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ),
        // Top bar
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.close_rounded,
                      color: Colors.white, size: 20),
                ),
              ),
              const Expanded(
                child: Center(
                    child: Text('Scan QR Code Siswa',
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white))),
              ),
              GestureDetector(
                onTap: () {
                  setState(() => _torchOn = !_torchOn);
                  _cam.toggleTorch();
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle),
                  child: Icon(
                      _torchOn
                          ? Icons.flash_on_rounded
                          : Icons.flash_off_rounded,
                      color: _torchOn ? AppColors.primary : Colors.white,
                      size: 20),
                ),
              ),
            ]),
          ),
        ),
        // Instruksi bawah
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.85),
                  Colors.transparent
                ],
              ),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('Arahkan ke QR Code siswa',
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white)),
              const SizedBox(height: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.4))),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.route_rounded, size: 14, color: AppColors.primary),
                  SizedBox(width: 6),
                  Text('Otomatis validasi rute',
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500)),
                ]),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  List<Widget> _corners() {
    const size = 24.0;
    const thick = 3.0;
    const color = AppColors.primary;
    return [
      const Positioned(
          top: 0,
          left: 0,
          child: _Corner(top: true, left: true, s: size, t: thick, c: color)),
      const Positioned(
          top: 0,
          right: 0,
          child: _Corner(top: true, left: false, s: size, t: thick, c: color)),
      const Positioned(
          bottom: 0,
          left: 0,
          child: _Corner(top: false, left: true, s: size, t: thick, c: color)),
      const Positioned(
          bottom: 0,
          right: 0,
          child: _Corner(top: false, left: false, s: size, t: thick, c: color)),
    ];
  }
}

// ── Result Sheet ────────────────────────────────────────────
class _ResultSheet extends StatelessWidget {
  final ScanQrResult result;
  final VoidCallback onNext;

  const _ResultSheet({required this.result, required this.onNext});

  @override
  Widget build(BuildContext context) {
    if (result.isSuccess) {
      return _SuccessSheet(attendance: result.attendance!, onNext: onNext);
    } else if (result.isRouteMismatch) {
      return _RouteMismatchSheet(mismatch: result.mismatch!, onNext: onNext);
    } else {
      return _ErrorSheet(message: result.message, onNext: onNext);
    }
  }
}

// ── Sheet: Sukses ────────────────────────────────────────────
class _SuccessSheet extends StatelessWidget {
  final AttendanceModel attendance;
  final VoidCallback onNext;
  const _SuccessSheet({required this.attendance, required this.onNext});

  @override
  Widget build(BuildContext context) {
    final initials = attendance.studentName.isNotEmpty
        ? attendance.studentName[0].toUpperCase()
        : '?';
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Center(
            child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.lightGrey,
                    borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 20),
        // Avatar + checkmark
        Stack(alignment: Alignment.bottomRight, children: [
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
                color: AppColors.primaryLight, shape: BoxShape.circle),
            child: Center(
                child: Text(initials,
                    style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary))),
          ),
          Container(
            width: 26,
            height: 26,
            decoration: const BoxDecoration(
                color: AppColors.primary, shape: BoxShape.circle),
            child:
                const Icon(Icons.check_rounded, color: Colors.white, size: 16),
          ),
        ]),
        const SizedBox(height: 14),
        Text(attendance.studentName,
            style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.black)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(20)),
          child: const Text('✅  RUTE SESUAI — TERVERIFIKASI',
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                  letterSpacing: 0.5)),
        ),
        const SizedBox(height: 16),
        // Info rute + halte
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            Expanded(
                child: _InfoCol(
              label: 'RUTE',
              value: attendance.namaRute.isNotEmpty
                  ? attendance.namaRute
                  : attendance.busCode,
              color: AppColors.primary,
            )),
            Container(width: 1, height: 36, color: AppColors.lightGrey),
            Expanded(
                child: _InfoCol(
              label: 'HALTE NAIK',
              value:
                  attendance.halteName.isNotEmpty ? attendance.halteName : '-',
            )),
            Container(width: 1, height: 36, color: AppColors.lightGrey),
            Expanded(
                child: _InfoCol(
              label: 'BUS',
              value: attendance.platNomor.isNotEmpty
                  ? attendance.platNomor
                  : attendance.busCode,
            )),
          ]),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: onNext,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Konfirmasi Naik Bus',
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: onNext,
          child: const Text('Scan Berikutnya',
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  color: AppColors.textGrey)),
        ),
      ]),
    );
  }
}

// ── Sheet: Rute Tidak Sesuai ─────────────────────────────────
class _RouteMismatchSheet extends StatelessWidget {
  final RouteMismatchInfo mismatch;
  final VoidCallback onNext;
  const _RouteMismatchSheet({required this.mismatch, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Center(
            child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.lightGrey,
                    borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 20),
        // Ikon X merah
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
              color: AppColors.orange.withValues(alpha: 0.12),
              shape: BoxShape.circle),
          child: const Icon(Icons.alt_route_rounded,
              size: 44, color: AppColors.orange),
        ),
        const SizedBox(height: 14),
        Text(mismatch.studentName,
            style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.black)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
              color: AppColors.orange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20)),
          child: const Text('⚠️  RUTE TIDAK SESUAI',
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.orange,
                  letterSpacing: 0.5)),
        ),
        const SizedBox(height: 8),
        Text('NIS: ${mismatch.studentNis}',
            style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                color: AppColors.textGrey)),
        const SizedBox(height: 16),

        // Perbandingan rute
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(14)),
          child: Column(children: [
            // Bus yang di-scan (salah)
            Row(children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                    color: AppColors.red.withValues(alpha: 0.1),
                    shape: BoxShape.circle),
                child: const Icon(Icons.close_rounded,
                    color: AppColors.red, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    const Text('BUS INI (tidak sesuai)',
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.red,
                            letterSpacing: 0.5)),
                    Text(
                      '${mismatch.scannedBusCode} — ${mismatch.scannedNamaRute}',
                      style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.black),
                    ),
                  ])),
            ]),
            const SizedBox(height: 12),
            const Divider(color: AppColors.lightGrey, height: 1),
            const SizedBox(height: 12),
            // Bus yang seharusnya (benar)
            Row(children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded,
                    color: AppColors.primary, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    const Text('BUS YANG SEHARUSNYA',
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                            letterSpacing: 0.5)),
                    Text(
                      mismatch.correctNamaRute != null
                          ? '${mismatch.correctBusCode} — ${mismatch.correctNamaRute}'
                          : 'Siswa belum di-assign ke bus manapun',
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: mismatch.correctNamaRute != null
                              ? AppColors.primary
                              : AppColors.textGrey),
                    ),
                  ])),
            ]),
          ]),
        ),
        const SizedBox(height: 12),

        // Pesan instruksi
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: AppColors.orange.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: AppColors.orange.withValues(alpha: 0.3))),
          child: const Row(children: [
            Icon(Icons.info_outline_rounded, color: AppColors.orange, size: 16),
            SizedBox(width: 8),
            Expanded(
                child: Text(
              'Siswa ini harus menunggu bus dengan rute yang sesuai. Tidak bisa naik bus ini.',
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  color: AppColors.orange,
                  height: 1.4),
            )),
          ]),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton(
            onPressed: onNext,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.orange, width: 1.5),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Scan Berikutnya',
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.orange)),
          ),
        ),
      ]),
    );
  }
}

// ── Sheet: Error Umum ────────────────────────────────────────
class _ErrorSheet extends StatelessWidget {
  final String message;
  final VoidCallback onNext;
  const _ErrorSheet({required this.message, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Center(
            child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.lightGrey,
                    borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 20),
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
              color: AppColors.red.withValues(alpha: 0.1),
              shape: BoxShape.circle),
          child:
              const Icon(Icons.cancel_rounded, size: 48, color: AppColors.red),
        ),
        const SizedBox(height: 14),
        const Text('QR Code Tidak Valid',
            style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.red)),
        const SizedBox(height: 8),
        Text(
          message.isNotEmpty
              ? message
              : 'Siswa tidak terdaftar atau QR sudah kadaluarsa',
          style: const TextStyle(
              fontFamily: 'Poppins', fontSize: 13, color: AppColors.textGrey),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: AppColors.red.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12)),
          child: const Row(children: [
            Icon(Icons.error_outline_rounded, color: AppColors.red, size: 18),
            SizedBox(width: 10),
            Expanded(
                child: Text('Hubungi admin jika siswa seharusnya terdaftar',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        color: AppColors.red))),
          ]),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton(
            onPressed: onNext,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.red, width: 1.5),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Coba Lagi',
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.red)),
          ),
        ),
      ]),
    );
  }
}

// ── Info column ──────────────────────────────────────────────
class _InfoCol extends StatelessWidget {
  final String label, value;
  final Color color;
  const _InfoCol(
      {required this.label, required this.value, this.color = AppColors.black});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(children: [
        Text(label,
            style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: AppColors.textGrey,
                letterSpacing: 0.8)),
        const SizedBox(height: 3),
        Text(value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color)),
      ]),
    );
  }
}

// ── Corner widget ────────────────────────────────────────────
class _Corner extends StatelessWidget {
  final bool top, left;
  final double s, t;
  final Color c;
  const _Corner(
      {required this.top,
      required this.left,
      required this.s,
      required this.t,
      required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: s,
      height: s,
      decoration: BoxDecoration(
        border: Border(
          top: top ? BorderSide(color: c, width: t) : BorderSide.none,
          bottom: !top ? BorderSide(color: c, width: t) : BorderSide.none,
          left: left ? BorderSide(color: c, width: t) : BorderSide.none,
          right: !left ? BorderSide(color: c, width: t) : BorderSide.none,
        ),
      ),
    );
  }
}

// ── Scan overlay ─────────────────────────────────────────────
class _ScanOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _OverlayPainter(), size: Size.infinite);
  }
}

class _OverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.55);
    const w = 260.0;
    const h = 260.0;
    final cx = size.width / 2;
    final cy = size.height / 2;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, cy - h / 2), paint);
    canvas.drawRect(
        Rect.fromLTWH(0, cy + h / 2, size.width, size.height), paint);
    canvas.drawRect(Rect.fromLTWH(0, cy - h / 2, cx - w / 2, h), paint);
    canvas.drawRect(
        Rect.fromLTWH(cx + w / 2, cy - h / 2, size.width, h), paint);
  }

  @override
  bool shouldRepaint(_) => false;
}
