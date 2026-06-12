import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../models/models_api.dart';
import '../../utils/app_theme.dart';

import '../../services/domain_services.dart';
import '../../services/gps_service.dart';

class QrCodeScreen extends StatefulWidget {
  final UserModel siswa;

  final VoidCallback? onBack;
  const QrCodeScreen({super.key, required this.siswa, this.onBack});
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

  Timer? _pollTimer;
  Timer? _autoRefreshTimer;
  bool _isScanned = false;
  bool _isOnTrip = false;
  bool _isPendingServer = false;
  String? _scannedAt;
  String? _scannedHalte;
  String? _scannedBus;

  @override
  void initState() {
    super.initState();
    _namaHalte = widget.siswa.studentDetail?.namaHalte.isNotEmpty == true
        ? widget.siswa.studentDetail!.namaHalte
        : null;
    if (widget.siswa.status == AccountStatus.active) {
      _initQr();
      _startAutoRefresh();
    }
  }

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!mounted || _isScanned) return;
      _checkAttendanceStatus();
    });
  }

  Future<void> _initQr() async {
    await _generateQr();
    await _checkAttendanceStatus();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkAttendanceStatus() async {
    if (_errorMsg != null) return;
    try {
      final result = await StudentService()
          .getMyAttendanceToday(int.parse(widget.siswa.idStr));
      if (!mounted) return;
      final list = result?['data'];
      if (list is List && list.isNotEmpty) {
        final latest = list.last as Map<String, dynamic>;
        final status = latest['status'] as String?;
        final waktuNaik = latest['waktu_naik'] as String?;
        final waktuTurun = latest['waktu_turun'] as String?;

        if (status == 'pending' && waktuNaik == null) {
          setState(() {
            _isPendingServer = true;
            _isScanned = false;
          });

          _startPolling();
          return;
        }

        if (waktuNaik != null) {
          final dt = DateTime.tryParse(waktuNaik)?.toLocal();
          final jamNaik = dt != null
              ? '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'
              : waktuNaik;
          setState(() {
            _isScanned = true;
            _isPendingServer = false;
            _isOnTrip = waktuTurun == null;
            _scannedAt = jamNaik;
            _scannedHalte = latest['halte_naik'] as String?;
            _scannedBus = latest['bus_code'] as String?;
          });
          _pollTimer?.cancel();
          return;
        }
      }
      _startPolling();
    } catch (_) {
      _startPolling();
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    if (!mounted || _isScanned) return;
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!mounted || _isScanned) {
        _pollTimer?.cancel();
        return;
      }
      _checkAttendanceStatus();
    });
  }

  bool _isGettingGps = false;
  String? _jarakInfo;

  Future<void> _generateQr() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _isGettingGps = true;
      _errorMsg = null;
      _jarakInfo = null;
    });

    final pos = await _gpsService.getCurrentPosition();
    if (!mounted) return;

    if (pos == null) {
      setState(() {
        _isLoading = false;
        _isGettingGps = false;
        _errorMsg = 'Tidak bisa mendapat lokasi GPS.\n'
            'Pastikan GPS diaktifkan dan izin lokasi sudah diberikan, lalu coba lagi.';
      });
      return;
    }

    setState(() => _isGettingGps = false);

    final result = await StudentService().generateQrCode(
      latitude: pos.latitude,
      longitude: pos.longitude,
    );
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (result == null) {
        _errorMsg = 'Tidak ada respons dari server. Periksa koneksi internet.';
      } else if (result.containsKey('__error')) {
        final errMsg = result['__error'] as String;

        if (errMsg.contains('halte') || errMsg.contains('dekat')) {
          _errorMsg = errMsg;

          final jarakMatch = RegExp(r'(\d+(?:\.\d+)?)m').allMatches(errMsg);
          if (jarakMatch.isNotEmpty) {
            final distances = jarakMatch.map((m) => m.group(0)!).toList();
            _jarakInfo = distances.join(' | ');
          }
        } else if (errMsg.contains('perjalanan')) {
          _errorMsg = 'Kamu masih tercatat dalam perjalanan.\n'
              'Minta driver untuk melakukan checkout terlebih dahulu.';
        } else if (errMsg.contains('bus aktif') ||
            errMsg.contains('ditugaskan')) {
          _errorMsg =
              'Kamu belum ditugaskan ke bus manapun.\nHubungi admin sekolah.';
        } else if (errMsg.contains('rute') || errMsg.contains('Rute')) {
          _errorMsg =
              'Rute bus belum diatur oleh admin.\nHubungi admin sekolah.';
        } else {
          _errorMsg = errMsg;
        }
      } else {
        _jarakInfo = null;
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
        _startPolling();
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
          onPressed: () {
            if (widget.onBack != null) {
              widget.onBack!();
            } else {
              Navigator.pop(context);
            }
          },
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
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          await _initQr();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          child: Column(children: [
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
            const SizedBox(height: 12),
            if (_isScanned) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _isOnTrip
                      ? const Color(0xFFE8F5E9)
                      : AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: _isOnTrip
                          ? Colors.green.withValues(alpha: 0.4)
                          : AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: _isOnTrip
                            ? Colors.green.withValues(alpha: 0.15)
                            : AppColors.primaryLight,
                        shape: BoxShape.circle),
                    child: Icon(
                      _isOnTrip
                          ? Icons.directions_bus_rounded
                          : Icons.check_circle_rounded,
                      color: _isOnTrip ? Colors.green : AppColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isOnTrip
                                ? 'Kamu sedang dalam perjalanan!'
                                : '✅ Perjalanan selesai hari ini',
                            style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _isOnTrip
                                    ? Colors.green.shade800
                                    : AppColors.primary),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            [
                              if (_scannedAt != null) 'Naik jam $_scannedAt',
                              if (_scannedHalte != null) 'di $_scannedHalte',
                              if (_scannedBus != null) '• Bus $_scannedBus',
                            ].join(' '),
                            style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 11,
                                color: _isOnTrip
                                    ? Colors.green.shade700
                                    : AppColors.primaryDark),
                          ),
                        ]),
                  ),
                ]),
              ),
              const SizedBox(height: 12),
            ] else if (_isPendingServer &&
                !_isLoading &&
                _errorMsg == null) ...[
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppColors.orange.withValues(alpha: 0.4)),
                ),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: AppColors.orange.withValues(alpha: 0.12),
                        shape: BoxShape.circle),
                    child: const Icon(Icons.qr_code_2_rounded,
                        color: AppColors.orange, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'QR siap — tunjukkan ke driver!',
                            style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.orange),
                          ),
                          SizedBox(height: 2),
                          Row(children: [
                            SizedBox(
                                width: 10,
                                height: 10,
                                child: CircularProgressIndicator(
                                    strokeWidth: 1.5, color: AppColors.orange)),
                            SizedBox(width: 6),
                            Text(
                              'Menunggu driver scan...',
                              style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 11,
                                  color: AppColors.orange),
                            ),
                          ]),
                        ]),
                  ),
                ]),
              ),
              const SizedBox(height: 12),
            ] else if (_qrData != null && !_isLoading) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                    color: AppColors.surface2,
                    borderRadius: BorderRadius.circular(12)),
                child: const Row(children: [
                  SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                          strokeWidth: 1.5, color: AppColors.textGrey)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Menunggu driver scan QR kamu...',
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: AppColors.textGrey),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 12),
            ],
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                  child: Column(children: [
                    if (isActive) ...[
                      if (_isLoading)
                        SizedBox(
                            height: 200,
                            width: 200,
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const CircularProgressIndicator(
                                      color: AppColors.primary),
                                  const SizedBox(height: 14),
                                  Text(
                                    _isGettingGps
                                        ? 'Mendapatkan lokasi GPS...'
                                        : 'Membuat QR Code...',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 12,
                                        color: AppColors.textGrey),
                                  ),
                                ],
                              ),
                            ))
                      else if (_errorMsg != null) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          width: double.infinity,
                          decoration: BoxDecoration(
                              color: _errorMsg!.contains('halte') ||
                                      _errorMsg!.contains('dekat') ||
                                      _errorMsg!.contains('Tunggu')
                                  ? AppColors.orange.withValues(alpha: 0.06)
                                  : AppColors.red.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: _errorMsg!.contains('halte') ||
                                          _errorMsg!.contains('dekat') ||
                                          _errorMsg!.contains('Tunggu')
                                      ? AppColors.orange.withValues(alpha: 0.3)
                                      : AppColors.red.withValues(alpha: 0.2))),
                          child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _errorMsg!.contains('GPS') ||
                                          _errorMsg!.contains('lokasi')
                                      ? Icons.location_off_rounded
                                      : _errorMsg!.contains('halte') ||
                                              _errorMsg!.contains('dekat') ||
                                              _errorMsg!.contains('Tunggu')
                                          ? Icons.place_rounded
                                          : _errorMsg!.contains('perjalanan')
                                              ? Icons.directions_bus_rounded
                                              : Icons.error_outline_rounded,
                                  size: 36,
                                  color: _errorMsg!.contains('halte') ||
                                          _errorMsg!.contains('dekat') ||
                                          _errorMsg!.contains('Tunggu')
                                      ? AppColors.orange
                                      : AppColors.red,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _errorMsg!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 11,
                                      color: _errorMsg!.contains('halte') ||
                                              _errorMsg!.contains('dekat') ||
                                              _errorMsg!.contains('Tunggu')
                                          ? AppColors.orange
                                          : AppColors.red,
                                      height: 1.5),
                                ),
                                if (_jarakInfo != null) ...[
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                        color: AppColors.orange
                                            .withValues(alpha: 0.1),
                                        borderRadius:
                                            BorderRadius.circular(20)),
                                    child: Text(
                                      '$_jarakInfo',
                                      style: const TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 10,
                                          color: AppColors.orange,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                                if (_errorMsg!.contains('halte') ||
                                    _errorMsg!.contains('Tunggu')) ...[
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Mendekat ke halte atau tunggu bus tiba',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 10,
                                        color: AppColors.textGrey),
                                  ),
                                ],
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
                        const Text(
                          'QR ini berlaku hingga 23:59 hari ini',
                          style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11,
                              color: AppColors.textGrey),
                        ),
                      ] else ...[
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
                      Container(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          color: AppColors.surface2,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: AppColors.lightGrey, width: 1.5),
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
                Container(
                    height: 1,
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    color: AppColors.lightGrey),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Column(children: [
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
                              _namaHalte != null
                                  ? _namaHalte! +
                                      (_jarakKeHalte != null
                                          ? ' (${_jarakKeHalte! < 1000 ? "${_jarakKeHalte!.round()} m" : "${(_jarakKeHalte! / 1000).toStringAsFixed(1)} km"})'
                                          : '')
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
                    if (hasQr && _expiresAt != null) ...[
                      const SizedBox(height: 8),
                      Row(children: [
                        const Icon(Icons.access_time_rounded,
                            size: 13, color: AppColors.textGrey),
                        const SizedBox(width: 6),
                        const Text(
                          'QR berlaku hari ini s/d 23:59',
                          style: TextStyle(
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
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8)
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
