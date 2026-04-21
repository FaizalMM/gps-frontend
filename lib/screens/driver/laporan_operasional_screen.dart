import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart'; // ← TAMBAH INI
import 'package:open_filex/open_filex.dart';
import '../../services/app_data_service.dart';
import '../../services/report_service.dart';
import '../../utils/app_theme.dart';

class LaporanOperasionalScreen extends StatefulWidget {
  final AppDataService dataService;
  final String driverId;

  /// bus_id driver aktif — wajib untuk fetch laporan dari API
  final int? busId;

  const LaporanOperasionalScreen({
    super.key,
    required this.dataService,
    required this.driverId,
    this.busId,
  });

  @override
  State<LaporanOperasionalScreen> createState() =>
      _LaporanOperasionalScreenState();
}

class _LaporanOperasionalScreenState extends State<LaporanOperasionalScreen> {
  DateTime _selectedDate = DateTime.now();
  final _reportService = ReportService();

  bool _isLoading = false;
  bool _hasError = false;
  String _errorMessage = '';
  DriverReportData? _reportData;

  bool _isExportingPdf = false;
  bool _isExportingExcel = false;

  final _catatanController = TextEditingController();

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('id_ID', null).then((_) {
      // ← TAMBAH INI (fallback safety)
      if (mounted) _fetchReport();
    });
  }

  @override
  void dispose() {
    _catatanController.dispose();
    super.dispose();
  }

  String get _tanggalParam => DateFormat('yyyy-MM-dd').format(_selectedDate);

  Future<void> _fetchReport() async {
    final busId = widget.busId;
    if (busId == null || busId == 0) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Bus belum ditugaskan ke akun ini.';
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    final data = await _reportService.fetchDriverReport(
      busId: busId,
      tanggal: _tanggalParam,
    );
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (data == null) {
        _hasError = true;
        _errorMessage = 'Gagal memuat laporan. Coba lagi.';
      } else {
        _reportData = data;
      }
    });
  }

  Future<void> _exportPdf() async {
    final busId = widget.busId;
    if (busId == null || busId == 0) return;
    setState(() => _isExportingPdf = true);
    final path = await _reportService.downloadDriverReportPdf(
      busId: busId,
      tanggal: _tanggalParam,
      catatanDriver: _catatanController.text.trim().isEmpty
          ? null
          : _catatanController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _isExportingPdf = false);
    if (path != null) {
      _showFileDialog(path, 'PDF');
    } else {
      _showErrorSnack('Gagal mengunduh PDF. Periksa koneksi internet.');
    }
  }

  Future<void> _exportExcel() async {
    final busId = widget.busId;
    if (busId == null || busId == 0) return;
    setState(() => _isExportingExcel = true);
    final path = await _reportService.downloadDriverReportExcel(
      busId: busId,
      tanggal: _tanggalParam,
      catatanDriver: _catatanController.text.trim().isEmpty
          ? null
          : _catatanController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _isExportingExcel = false);
    if (path != null) {
      _showFileDialog(path, 'Excel');
    } else {
      _showErrorSnack('Gagal mengunduh Excel. Periksa koneksi internet.');
    }
  }

  /// Dialog sukses yang jelas — tampilkan nama file, lokasi, dan tombol aksi
  void _showFileDialog(String path, String tipe) {
    final fileName = path.split('/').last;
    final isDownloads = path.contains('/Download');
    final isInternal =
        path.contains('/data/data') || path.contains('/data/user');
    final isPdf = fileName.toLowerCase().endsWith('.pdf');

    // Tentukan lokasi yang mudah dipahami
    String lokasiJudul;
    String lokasiPanduan;
    IconData lokasiIcon;
    Color lokasiColor;

    if (isDownloads) {
      lokasiJudul = 'Folder Download';
      lokasiPanduan = 'Buka aplikasi File Manager → folder "Download"';
      lokasiIcon = Icons.folder_rounded;
      lokasiColor = Colors.green;
    } else if (isInternal) {
      lokasiJudul = 'Penyimpanan internal app';
      lokasiPanduan =
          'File Manager → Internal → Android → data → com.mobitra.app → files';
      lokasiIcon = Icons.phone_android_rounded;
      lokasiColor = AppColors.orange;
    } else {
      lokasiJudul = 'Penyimpanan eksternal';
      lokasiPanduan = 'File Manager → Internal Storage → Android → data';
      lokasiIcon = Icons.sd_storage_rounded;
      lokasiColor = AppColors.blue;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon sukses
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                    color: AppColors.primaryLight, shape: BoxShape.circle),
                child: Icon(
                  isPdf
                      ? Icons.picture_as_pdf_rounded
                      : Icons.table_chart_rounded,
                  color: AppColors.primary,
                  size: 32,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                '$tipe Berhasil Tersimpan!',
                style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.black),
              ),
              const SizedBox(height: 6),

              // Nama file
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                    color: AppColors.surface2,
                    borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  Icon(
                    isPdf
                        ? Icons.picture_as_pdf_rounded
                        : Icons.grid_on_rounded,
                    size: 16,
                    color: isPdf ? Colors.red : Colors.green.shade700,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      fileName,
                      style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.black),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 12),

              // Lokasi file
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: lokasiColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: lokasiColor.withValues(alpha: 0.25)),
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(lokasiIcon, size: 16, color: lokasiColor),
                        const SizedBox(width: 6),
                        Text(
                          'Lokasi: $lokasiJudul',
                          style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: lokasiColor),
                        ),
                      ]),
                      const SizedBox(height: 4),
                      Text(
                        lokasiPanduan,
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            color: lokasiColor.withValues(alpha: 0.8),
                            height: 1.4),
                      ),
                    ]),
              ),
              const SizedBox(height: 16),

              // Tombol aksi
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.lightGrey),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Tutup',
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13,
                            color: AppColors.textGrey)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await OpenFilex.open(path);
                    },
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    label: Text('Buka $tipe',
                        style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ]),

              // Tips jika file tidak bisa dibuka
              const SizedBox(height: 10),
              Text(
                'Jika file tidak terbuka otomatis, cari manual\nmenggunakan panduan lokasi di atas.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 10,
                    color: AppColors.textGrey,
                    height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _reportData = null;
      });
      _fetchReport();
    }
  }

  Future<void> _showCatatanDialog(String exportType) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Catatan Driver (opsional)',
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w700,
                      fontSize: 16)),
              const SizedBox(height: 12),
              TextField(
                controller: _catatanController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Tambahkan catatan untuk laporan ini...',
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A1A2E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    if (exportType == 'PDF') {
                      _exportPdf();
                    } else {
                      _exportExcel();
                    }
                  },
                  child: Text('Ekspor $exportType',
                      style: const TextStyle(
                          fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showErrorSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.redAccent,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  void _showAllStudents() {
    final rows = _reportData?.rows ?? [];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        builder: (_, ctrl) => Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(children: [
            Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                child: Row(children: [
                  Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                          color: AppColors.lightGrey,
                          borderRadius: BorderRadius.circular(2))),
                  const Spacer(),
                  const Text('Semua Siswa Hari Ini',
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Text('${rows.length} siswa',
                      style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: AppColors.textGrey)),
                ])),
            Expanded(
              child: rows.isEmpty
                  ? const Center(
                      child: Text('Belum ada siswa hari ini',
                          style: TextStyle(
                              fontFamily: 'Poppins',
                              color: AppColors.textGrey)))
                  : ListView.builder(
                      controller: ctrl,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 30),
                      itemCount: rows.length,
                      itemBuilder: (_, i) {
                        final r = rows[i];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 8)
                              ]),
                          child: Row(children: [
                            _Avatar(initials: r.initials),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(r.namaPenumpang,
                                      style: const TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600)),
                                  Text('Halte: ${r.halteNaik}',
                                      style: const TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 11,
                                          color: AppColors.textGrey)),
                                ])),
                            _StatusBadge(checkout: r.checkout),
                          ]),
                        );
                      },
                    ),
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateStr =
        DateFormat('EEEE, d MMM yyyy', 'id_ID').format(_selectedDate);
    final rows = _reportData?.rows ?? [];
    final totalSiswa = _reportData?.totalAttendances ?? 0;

    String routeTime = '-';
    if (rows.isNotEmpty) {
      final naik = rows
          .where((r) => r.waktuNaik != null)
          .map((r) => DateTime.tryParse(r.waktuNaik!))
          .whereType<DateTime>()
          .toList()
        ..sort();
      final turun = rows
          .where((r) => r.waktuTurun != null)
          .map((r) => DateTime.tryParse(r.waktuTurun!))
          .whereType<DateTime>()
          .toList()
        ..sort();
      if (naik.isNotEmpty && turun.isNotEmpty) {
        final diff = turun.last.difference(naik.first);
        final h = diff.inHours;
        final m = diff.inMinutes % 60;
        routeTime = h > 0 ? '${h}h ${m}m' : '${m}m';
      }
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: _BottomExportBar(
        isExportingPdf: _isExportingPdf,
        isExportingExcel: _isExportingExcel,
        canExport: widget.busId != null && widget.busId != 0,
        onExportPdf: () => _showCatatanDialog('PDF'),
        onExportExcel: () => _showCatatanDialog('Excel'),
      ),
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: AppColors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Laporan Harian',
          style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: AppColors.black),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_rounded,
                color: AppColors.black, size: 22),
            onPressed: _pickDate,
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE0E0E0)),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _fetchReport,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(dateStr,
                  style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.black,
                      height: 1.1)),
              const SizedBox(height: 4),
              Text(
                widget.busId != null && widget.busId != 0
                    ? 'Bus ID: ${widget.busId}'
                    : 'Bus belum ditugaskan',
                style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    color: AppColors.textGrey),
              ),
              const SizedBox(height: 20),
              if (_isLoading)
                const _LoadingCard()
              else if (_hasError)
                _ErrorCard(message: _errorMessage, onRetry: _fetchReport)
              else ...[
                Row(children: [
                  Expanded(
                      child: _BigStatCard(
                          icon: Icons.people_rounded,
                          value: '$totalSiswa',
                          label: 'Total Siswa')),
                  const SizedBox(width: 14),
                  Expanded(
                      child: _BigStatCard(
                          icon: Icons.access_time_rounded,
                          value: routeTime,
                          label: 'Durasi Operasi')),
                ]),
                const SizedBox(height: 24),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 12,
                          offset: const Offset(0, 4))
                    ],
                  ),
                  child: Column(children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Log Siswa',
                                style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.black)),
                            if (rows.isNotEmpty)
                              GestureDetector(
                                onTap: _showAllStudents,
                                child: const Text('Lihat Semua',
                                    style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.primary)),
                              ),
                          ]),
                    ),
                    if (rows.isEmpty)
                      const Padding(
                        padding: EdgeInsets.fromLTRB(18, 0, 18, 20),
                        child: Text(
                          'Belum ada data absensi untuk tanggal ini.',
                          style: TextStyle(
                              fontFamily: 'Poppins',
                              color: AppColors.textGrey,
                              fontSize: 13),
                        ),
                      )
                    else
                      ...rows.take(4).toList().asMap().entries.map((e) {
                        return _StudentLogRow(
                          row: e.value,
                          showDivider: e.key < (rows.take(4).length - 1),
                        );
                      }),
                    const SizedBox(height: 8),
                  ]),
                ),
              ],
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Widgets ─────────────────────────────────────────────────

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();
  @override
  Widget build(BuildContext context) => Container(
        height: 140,
        decoration: BoxDecoration(
            color: AppColors.white, borderRadius: BorderRadius.circular(20)),
        child: const Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 12),
            Text('Memuat laporan...',
                style: TextStyle(
                    fontFamily: 'Poppins', color: AppColors.textGrey)),
          ]),
        ),
      );
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: AppColors.white, borderRadius: BorderRadius.circular(20)),
        child: Column(children: [
          const Icon(Icons.error_outline_rounded,
              color: Colors.redAccent, size: 40),
          const SizedBox(height: 10),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontFamily: 'Poppins', color: AppColors.textGrey)),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Coba Lagi',
                style: TextStyle(fontFamily: 'Poppins')),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
          )
        ]),
      );
}

class _BigStatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _BigStatCard(
      {required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 4))
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: AppColors.primary, size: 26)),
          const SizedBox(height: 14),
          Text(value,
              style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: AppColors.black,
                  height: 1.0)),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  color: AppColors.textGrey)),
        ]),
      );
}

class _StudentLogRow extends StatelessWidget {
  final AttendanceReportRow row;
  final bool showDivider;
  const _StudentLogRow({required this.row, required this.showDivider});

  @override
  Widget build(BuildContext context) => Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Row(children: [
            _Avatar(initials: row.initials),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(row.namaPenumpang,
                        style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.black)),
                    const SizedBox(height: 2),
                    Text('Halte: ${row.halteNaik}',
                        style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            color: AppColors.textGrey)),
                  ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(row.waktuNaikFormatted,
                  style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.black)),
              const SizedBox(height: 4),
              _StatusBadge(checkout: row.checkout),
            ]),
          ]),
        ),
        if (showDivider)
          const Divider(
              height: 1, indent: 18, endIndent: 18, color: Color(0xFFF0F0F0)),
      ]);
}

class _StatusBadge extends StatelessWidget {
  final bool checkout;
  const _StatusBadge({required this.checkout});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: checkout
              ? AppColors.primaryLight
              : AppColors.orange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          checkout ? 'CHECKOUT' : 'NAIK',
          style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: checkout ? AppColors.primary : AppColors.orange),
        ),
      );
}

class _Avatar extends StatelessWidget {
  final String initials;
  const _Avatar({required this.initials});

  @override
  Widget build(BuildContext context) => CircleAvatar(
        radius: 24,
        backgroundColor: AppColors.primaryLight,
        child: Text(initials,
            style: const TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
                fontSize: 14)),
      );
}

class _BottomExportBar extends StatelessWidget {
  final bool isExportingPdf;
  final bool isExportingExcel;
  final bool canExport;
  final VoidCallback onExportPdf;
  final VoidCallback onExportExcel;

  const _BottomExportBar({
    required this.isExportingPdf,
    required this.isExportingExcel,
    required this.canExport,
    required this.onExportPdf,
    required this.onExportExcel,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.fromLTRB(
            20, 14, 20, 14 + MediaQuery.of(context).padding.bottom),
        decoration: const BoxDecoration(
          color: AppColors.white,
          border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
        ),
        child: Row(children: [
          Expanded(
              child: _ExportButton(
                  label: 'Ekspor PDF',
                  icon: Icons.picture_as_pdf_rounded,
                  isLoading: isExportingPdf,
                  enabled: canExport && !isExportingPdf && !isExportingExcel,
                  onTap: onExportPdf)),
          const SizedBox(width: 12),
          Expanded(
              child: _ExportButton(
                  label: 'Ekspor Excel',
                  icon: Icons.table_chart_rounded,
                  isLoading: isExportingExcel,
                  enabled: canExport && !isExportingPdf && !isExportingExcel,
                  onTap: onExportExcel)),
        ]),
      );
}

class _ExportButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isLoading;
  final bool enabled;
  final VoidCallback onTap;

  const _ExportButton({
    required this.label,
    required this.icon,
    required this.isLoading,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            color: enabled
                ? const Color(0xFF1A1A2E)
                : const Color(0xFF1A1A2E).withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(14),
          ),
          child: isLoading
              ? const Center(
                  child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: AppColors.primary, strokeWidth: 2.5)))
              : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(icon, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(label,
                      style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ]),
        ),
      );
}
