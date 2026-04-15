import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../models/models_api.dart';
import '../../utils/app_theme.dart';

import '../../services/domain_services.dart';
import '../../services/gps_service.dart';

class QrCodeScreen extends StatefulWidget {
  final UserModel siswa;
  const QrCodeScreen({super.key, required this.siswa});
  @override
  State<QrCodeScreen> createState() => _QrCodeScreenState();
}

class _QrCodeScreenState extends State<QrCodeScreen> {
  final _gpsService = GpsService();
  String? _qrData;
  bool _isLoading = false;
  String? _errorMsg;
  String? _expiresAt;
  String? _busCode;
  String? _namaHalte;
  double? _jarakKeHalte;

  @override
  void initState() {
    super.initState();
    if (widget.siswa.status == AccountStatus.active) {
      _generateQr();
    }
  }

  Future<void> _generateQr() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });
    final pos = await _gpsService.getCurrentPosition();
    if (!mounted) return;
    if (pos == null) {
      setState(() {
        _isLoading = false;
        _errorMsg = 'Tidak bisa mendapat lokasi GPS. Pastikan GPS aktif.';
      });
      return;
    }
    final result = await StudentService().generateQrCode(
      latitude: pos.latitude,
      longitude: pos.longitude,
    );
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (result != null) {
        // Encode ke JSON string agar bisa di-decode driver saat scan
        if (result['qr_data'] != null) {
          final qrMap = result['qr_data'];
          _qrData = qrMap is String ? qrMap : jsonEncode(qrMap);
        } else {
          _qrData = result['qr_code_url'] as String?;
        }
        _expiresAt = result['expires_at'] as String?;
        _busCode = result['bus_code'] as String?;
        final halteInfo = result['halte_info'] as Map<String, dynamic>?;
        _namaHalte = halteInfo?['nama_halte'] as String?;
        _jarakKeHalte = (result['distance_to_halte'] as num?)?.toDouble();
      } else {
        _errorMsg =
            'Gagal generate QR Code. Pastikan kamu berada di dekat halte (<100m).';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final siswa = widget.siswa;
    final bool isActive = siswa.status == AccountStatus.active;
    final bool isPending = siswa.status == AccountStatus.pending;
    final qrData = _qrData ?? '';
    final hasQr = _qrData != null && _qrData!.isNotEmpty;
    final initials =
        siswa.namaLengkap.isNotEmpty ? siswa.namaLengkap[0].toUpperCase() : '?';
    final studentId = '#STU-${siswa.idStr.padLeft(8, '0').toUpperCase()}';

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF0F2F8),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Digital ID',
            style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: AppColors.black)),
        centerTitle: true,
        actions: [
          if (isActive)
            IconButton(
              icon: const Icon(Icons.more_horiz_rounded,
                  color: AppColors.black, size: 22),
              onPressed: () => _showMenu(context),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        child: Column(children: [
          // ── Status bar ────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.primaryLight
                  : isPending
                      ? AppColors.orange.withValues(alpha: 0.1)
                      : AppColors.red.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: isActive
                      ? AppColors.primary.withValues(alpha: 0.3)
                      : isPending
                          ? AppColors.orange.withValues(alpha: 0.3)
                          : AppColors.red.withValues(alpha: 0.2)),
            ),
            child: Row(children: [
              Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppColors.primary
                        : isPending
                            ? AppColors.orange
                            : AppColors.red,
                    shape: BoxShape.circle,
                  )),
              const SizedBox(width: 8),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(
                      isActive
                          ? 'Status Scan Aktif'
                          : isPending
                              ? 'Menunggu Persetujuan Admin'
                              : 'Akun Tidak Aktif',
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isActive
                              ? AppColors.primary
                              : isPending
                                  ? AppColors.orange
                                  : AppColors.red),
                    ),
                    Text(
                      isActive
                          ? 'Siap untuk di-scan driver'
                          : isPending
                              ? 'QR aktif setelah admin menyetujui akun kamu'
                              : 'Hubungi admin untuk mengaktifkan akun',
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          color: isActive
                              ? AppColors.primaryDark
                              : isPending
                                  ? AppColors.orange.withValues(alpha: 0.8)
                                  : AppColors.red.withValues(alpha: 0.7)),
                    ),
                  ])),
              Icon(
                isActive
                    ? Icons.check_circle_rounded
                    : isPending
                        ? Icons.access_time_rounded
                        : Icons.cancel_rounded,
                color: isActive
                    ? AppColors.primary
                    : isPending
                        ? AppColors.orange
                        : AppColors.red,
                size: 18,
              ),
            ]),
          ),
          const SizedBox(height: 16),

          // ── Kartu ID ──────────────────────────────────
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
                    blurRadius: 24,
                    offset: const Offset(0, 8))
              ],
            ),
            child: Column(children: [
              // Header gradient
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isActive
                        ? [AppColors.primary, AppColors.primaryDark]
                        : [const Color(0xFF9E9E9E), const Color(0xFF757575)],
                  ),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.5),
                          width: 2.5),
                    ),
                    child: Center(
                        child: Text(initials,
                            style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 34,
                                fontWeight: FontWeight.w800,
                                color: Colors.white))),
                  ),
                  const SizedBox(height: 12),
                  Text(siswa.namaLengkap,
                      style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.white)),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20)),
                    child: Text(studentId,
                        style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white)),
                  ),
                ]),
              ),

              // QR area
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Column(children: [
                  if (isActive) ...[
                    // QR aktif atau loading
                    if (_isLoading)
                      const SizedBox(
                          height: 180,
                          width: 180,
                          child: Center(
                              child: CircularProgressIndicator(
                                  color: AppColors.primary)))
                    else if (_errorMsg != null) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                            color: AppColors.red.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: AppColors.red.withValues(alpha: 0.2))),
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.location_off_rounded,
                                  size: 40, color: AppColors.red),
                              const SizedBox(height: 8),
                              Text(_errorMsg!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 10,
                                      color: AppColors.red,
                                      height: 1.4)),
                            ]),
                      ),
                      const SizedBox(height: 10),
                      TextButton.icon(
                        onPressed: _generateQr,
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('Coba Lagi',
                            style: TextStyle(
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.w600)),
                        style: TextButton.styleFrom(
                            foregroundColor: AppColors.primary),
                      ),
                    ] else if (hasQr) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: AppColors.lightGrey, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 2))
                          ],
                        ),
                        child: QrImageView(
                          data: qrData,
                          version: QrVersions.auto,
                          size: 180,
                          eyeStyle: const QrEyeStyle(
                              eyeShape: QrEyeShape.square,
                              color: AppColors.black),
                          dataModuleStyle: const QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.square,
                              color: AppColors.black),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text('PINDAI UNTUK VERIFIKASI',
                          style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textGrey,
                              letterSpacing: 1.2)),
                      const SizedBox(height: 6),
                      TextButton.icon(
                        onPressed: _generateQr,
                        icon: const Icon(Icons.refresh_rounded, size: 14),
                        label: const Text('Perbarui QR',
                            style:
                                TextStyle(fontFamily: 'Poppins', fontSize: 12)),
                        style: TextButton.styleFrom(
                            foregroundColor: AppColors.textGrey),
                      ),
                    ] else ...[
                      // Belum ada QR (belum generate)
                      Container(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                            color: AppColors.surface2,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: AppColors.lightGrey, width: 1.5)),
                        child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.qr_code_2_rounded,
                                  size: 60, color: AppColors.lightGrey),
                              SizedBox(height: 10),
                              Text('Butuh Lokasi GPS',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 12,
                                      color: AppColors.textGrey,
                                      height: 1.4)),
                            ]),
                      ),
                    ],
                  ] else ...[
                    // QR belum aktif — placeholder
                    Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        color: AppColors.surface2,
                        borderRadius: BorderRadius.circular(16),
                        border:
                            Border.all(color: AppColors.lightGrey, width: 1.5),
                      ),
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isPending
                                  ? Icons.hourglass_top_rounded
                                  : Icons.qr_code_2_rounded,
                              size: 60,
                              color: AppColors.lightGrey,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              isPending
                                  ? 'Menunggu\nPersetujuan'
                                  : 'QR Tidak\nAktif',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 12,
                                  color: AppColors.textGrey,
                                  height: 1.4),
                            ),
                          ]),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isPending
                          ? 'QR akan otomatis aktif saat admin\nmenyetujui pendaftaranmu'
                          : 'Hubungi admin untuk mengaktifkan akun',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          color: AppColors.textGrey,
                          height: 1.5),
                    ),
                  ],
                ]),
              ),

              // Divider + info QR aktual (halte, bus, expired)
              Container(
                  height: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  color: AppColors.lightGrey),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(children: [
                  // Row halte
                  Row(children: [
                    Icon(Icons.location_on_rounded,
                        color:
                            isActive ? AppColors.primary : AppColors.textGrey,
                        size: 15),
                    const SizedBox(width: 6),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          const Text('HALTE NAIK',
                              style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textGrey,
                                  letterSpacing: 0.8)),
                          Text(
                            hasQr && _namaHalte != null
                                ? _namaHalte! +
                                    (_jarakKeHalte != null
                                        ? ' (${_jarakKeHalte! < 1000 ? "${_jarakKeHalte!.round()} m" : "${(_jarakKeHalte! / 1000).toStringAsFixed(1)} km"})'
                                        : '')
                                : siswa.alamat.isNotEmpty
                                    ? siswa.alamat
                                    : 'Belum diatur',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isActive
                                    ? AppColors.black
                                    : AppColors.textGrey),
                          ),
                        ])),
                    if (hasQr && _busCode != null) ...[
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.directions_bus_rounded,
                              size: 12, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Text(_busCode!,
                              style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary)),
                        ]),
                      ),
                    ],
                  ]),
                  // Row expired
                  if (hasQr && _expiresAt != null) ...[
                    const SizedBox(height: 8),
                    Row(children: [
                      const Icon(Icons.access_time_rounded,
                          size: 13, color: AppColors.textGrey),
                      const SizedBox(width: 6),
                      Text(
                        'QR berlaku hari ini s/d 23:59',
                        style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            color: AppColors.textGrey),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('Expired tiap hari',
                            style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.pendingOrange)),
                      ),
                    ]),
                  ],
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 16),

          // ── Info card ─────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)
              ],
            ),
            child: Row(children: [
              Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.info_outline_rounded,
                      color: AppColors.primary, size: 18)),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(
                isActive
                    ? 'Tunjukkan QR ini kepada driver saat naik bus. QR otomatis memvalidasi rute kamu.'
                    : 'QR Code kamu akan otomatis aktif begitu admin menyetujui pendaftaranmu. Tidak perlu langkah tambahan.',
                style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    color: AppColors.textGrey,
                    height: 1.4),
              )),
            ]),
          ),
        ]),
      ),
    );
  }

  void _showMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(
              child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.lightGrey,
                      borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          ListTile(
            dense: true,
            leading: const Icon(Icons.download_rounded,
                color: AppColors.black, size: 20),
            title: const Text('Simpan ke Galeri',
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w500)),
            onTap: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: const Text(
                    'Butuh izin galeri. Tambahkan plugin image_gallery_saver untuk fitur ini.'),
                backgroundColor: AppColors.orange,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ));
            },
          ),
          ListTile(
            dense: true,
            leading: const Icon(Icons.share_rounded,
                color: AppColors.black, size: 20),
            title: const Text('Bagikan',
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w500)),
            onTap: () => Navigator.pop(ctx),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}
