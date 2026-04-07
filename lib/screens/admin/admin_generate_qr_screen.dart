import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../models/models_api.dart';
import '../../services/app_data_service.dart';
import '../../utils/app_theme.dart';

class AdminGenerateQrScreen extends StatefulWidget {
  final AppDataService dataService;
  const AdminGenerateQrScreen({super.key, required this.dataService});

  @override
  State<AdminGenerateQrScreen> createState() => _AdminGenerateQrScreenState();
}

class _AdminGenerateQrScreenState extends State<AdminGenerateQrScreen> {
  String? _selectedFilter; // null = semua siswa
  String _labelSize = 'Sedang (4x4 cm)';
  final int _quantity = 0; // auto dari filter
  bool _isGenerating = false;
  bool _hasGenerated = false;
  UserModel? _previewSiswa;

  // Riwayat batch (simulasi)
  final List<_BatchRecord> _batches = [
    const _BatchRecord(
        label: 'Semua Siswa - Angkatan 2024', count: 120, date: '4 Okt 2023'),
    const _BatchRecord(
        label: 'Rute 15 - Pengganti', count: 5, date: '24 Okt 2023'),
  ];

  final _labelSizes = ['Kecil (3x3 cm)', 'Sedang (4x4 cm)', 'Besar (5x5 cm)'];

  List<UserModel> get _filteredSiswa {
    final all = widget.dataService.siswaList;
    if (_selectedFilter == null) return all;
    // Filter by rute (dari alamat, karena data rute disimpan di alamat pada mock)
    return all.where((s) => s.alamat.contains(_selectedFilter!)).toList();
  }

  List<String> get _availableRoutes {
    final buses = widget.dataService.buses;
    return [
      'Semua Siswa',
      ...buses.map((b) => b.rute).where((r) => r.isNotEmpty).toSet()
    ];
  }

  void _generateBatch() async {
    final siswa = _filteredSiswa;
    if (siswa.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Tidak ada siswa untuk filter ini'),
        backgroundColor: AppColors.orange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
      return;
    }

    setState(() => _isGenerating = true);
    await Future.delayed(const Duration(milliseconds: 1800)); // simulasi proses

    final batchLabel =
        _selectedFilter == null ? 'Semua Siswa' : _selectedFilter!;
    setState(() {
      _isGenerating = false;
      _hasGenerated = true;
      _batches.insert(
          0,
          _BatchRecord(
            label:
                '$batchLabel - ${DateTime.now().day} Mar ${DateTime.now().year}',
            count: siswa.length,
            date: '${DateTime.now().day} Mar ${DateTime.now().year}',
          ));
    });

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${siswa.length} QR Code berhasil dibuat!'),
      backgroundColor: AppColors.primary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  void _showPreview(UserModel siswa) {
    setState(() => _previewSiswa = siswa);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _QrPreviewSheet(siswa: siswa),
    );
  }

  void _showAllPreview() {
    final list = _filteredSiswa;
    if (list.isEmpty) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (_, ctrl) => Container(
          decoration: const BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: AppColors.lightGrey,
                        borderRadius: BorderRadius.circular(2))),
                const Spacer(),
                Text('${list.length} QR Code',
                    style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
                const Spacer(),
                IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx)),
              ]),
            ),
            Expanded(
              child: GridView.builder(
                controller: ctrl,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 30),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.75),
                itemCount: list.length,
                itemBuilder: (_, i) => _QrCard(
                    siswa: list[i],
                    onTap: () {
                      Navigator.pop(ctx);
                      _showPreview(list[i]);
                    }),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = _filteredSiswa;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Generator QR Code',
            style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: AppColors.black)),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.print_rounded,
                color: AppColors.black, size: 22),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: const Text(
                    'Hubungkan ke printer via plugin printing untuk cetak kartu.'),
                backgroundColor: AppColors.orange,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ));
            },
          ),
        ],
        bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(color: AppColors.lightGrey, height: 0.5)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Bulk Generation card ────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 3))
              ],
            ),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Generate Massal',
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.black)),
              const SizedBox(height: 4),
              const Text(
                  'Buat QR code untuk semua siswa atau filter berdasarkan rute tertentu.',
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: AppColors.textGrey)),
              const SizedBox(height: 16),

              // Filter rute
              const Text('Pilih Siswa / Rute',
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.black)),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.lightGrey),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: _selectedFilter,
                    isExpanded: true,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded,
                        color: AppColors.textGrey),
                    style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        color: AppColors.black),
                    items: [
                      const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Semua Siswa',
                              style: TextStyle(fontFamily: 'Poppins'))),
                      ...widget.dataService.buses
                          .where((b) => b.rute.isNotEmpty)
                          .map((b) => DropdownMenuItem<String?>(
                              value: b.rute,
                              child: Text('Rute: ${b.rute}',
                                  style:
                                      const TextStyle(fontFamily: 'Poppins')))),
                    ],
                    onChanged: (v) => setState(() => _selectedFilter = v),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Ukuran label + jumlah
              Row(children: [
                Expanded(
                  flex: 3,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Ukuran Label',
                            style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.black)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 4),
                          decoration: BoxDecoration(
                              color: AppColors.surface2,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.lightGrey)),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _labelSize,
                              isExpanded: true,
                              icon: const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: AppColors.textGrey,
                                  size: 18),
                              style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 12,
                                  color: AppColors.black),
                              items: _labelSizes
                                  .map((s) => DropdownMenuItem(
                                      value: s,
                                      child: Text(s,
                                          style: const TextStyle(
                                              fontFamily: 'Poppins',
                                              fontSize: 12))))
                                  .toList(),
                              onChanged: (v) => setState(() => _labelSize = v!),
                            ),
                          ),
                        ),
                      ]),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Jumlah',
                            style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.black)),
                        const SizedBox(height: 8),
                        Container(
                          height: 50,
                          decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: AppColors.primary
                                      .withValues(alpha: 0.3))),
                          child: Center(
                              child: Text(
                            '${filteredList.length} siswa',
                            style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary),
                          )),
                        ),
                      ]),
                ),
              ]),
              const SizedBox(height: 18),

              // Tombol Generate
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isGenerating ? null : _generateBatch,
                  icon: _isGenerating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.qr_code_2_rounded, size: 20),
                  label: Text(
                    _isGenerating
                        ? 'Sedang membuat...'
                        : 'Generate ${filteredList.length} QR Code',
                    style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 20),

          // ── Pratinjau ───────────────────────────────────
          Row(children: [
            const Expanded(
                child: Text('Pratinjau',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.black))),
            if (filteredList.isNotEmpty)
              GestureDetector(
                onTap: _showAllPreview,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(20)),
                  child: const Text('Lihat Semua',
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary)),
                ),
              ),
          ]),
          const SizedBox(height: 10),

          // Preview card contoh
          if (filteredList.isNotEmpty)
            GestureDetector(
              onTap: () => _showPreview(filteredList.first),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      width: 1.5),
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 4))
                  ],
                ),
                child: Column(children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(20)),
                      child:
                          const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.visibility_rounded,
                            size: 12, color: AppColors.primary),
                        SizedBox(width: 4),
                        Text('KARTU CONTOH',
                            style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary)),
                      ]),
                    ),
                    const Spacer(),
                    Text('${filteredList.length} kartu total',
                        style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            color: AppColors.textGrey)),
                  ]),
                  const SizedBox(height: 16),
                  _QrCardContent(siswa: filteredList.first, compact: false),
                ]),
              ),
            )
          else
            Container(
              width: double.infinity,
              height: 120,
              decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(16)),
              child: const Center(
                  child: Text('Tidak ada siswa ditemukan',
                      style: TextStyle(
                          fontFamily: 'Poppins', color: AppColors.textGrey))),
            ),
          const SizedBox(height: 20),

          // ── Riwayat Batch ───────────────────────────────
          const Text('Riwayat Batch',
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.black)),
          const SizedBox(height: 10),

          ..._batches.map((b) => _BatchTile(
              batch: b,
              onDownload: () {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Mengunduh batch: ${b.label}'),
                  backgroundColor: AppColors.primary,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ));
              })),

          const SizedBox(height: 30),
        ]),
      ),
    );
  }
}

// ── QR Preview Bottom Sheet ─────────────────────────────────
class _QrPreviewSheet extends StatelessWidget {
  final UserModel siswa;
  const _QrPreviewSheet({required this.siswa});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Center(
            child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.lightGrey,
                    borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 20),
        const Text('Pratinjau Kartu',
            style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4))
              ]),
          padding: const EdgeInsets.all(20),
          child: _QrCardContent(siswa: siswa, compact: false),
        ),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(
              child: OutlinedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded, size: 16),
            label: const Text('Tutup', style: TextStyle(fontFamily: 'Poppins')),
            style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textGrey,
                side: const BorderSide(color: AppColors.lightGrey),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 13)),
          )),
          const SizedBox(width: 12),
          Expanded(
              child: ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: const Text(
                    'Tambahkan plugin path_provider untuk ekspor PDF.'),
                backgroundColor: AppColors.orange,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ));
            },
            icon: const Icon(Icons.download_rounded, size: 16),
            label: const Text('Unduh',
                style: TextStyle(
                    fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 13)),
          )),
        ]),
        const SizedBox(height: 8),
      ]),
    );
  }
}

// ── QR Card content ─────────────────────────────────────────
class _QrCardContent extends StatelessWidget {
  final UserModel siswa;
  final bool compact;
  const _QrCardContent({required this.siswa, required this.compact});

  @override
  Widget build(BuildContext context) {
    final qrData =
        '{"id":"${siswa.id}","nama":"${siswa.namaLengkap}","role":"siswa"}';
    return Column(children: [
      // Header card identitas
      Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(
              color: AppColors.primaryLight, shape: BoxShape.circle),
          child: Center(
              child: Text(siswa.namaLengkap[0].toUpperCase(),
                  style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color: AppColors.primary))),
        ),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(siswa.namaLengkap,
              style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.black)),
          Text('ID: #STU-${siswa.idStr.padLeft(8, '0').toUpperCase()}',
              style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w500)),
          Text(siswa.email,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 10,
                  color: AppColors.textGrey)),
        ])),
      ]),
      const SizedBox(height: 16),
      const Divider(color: AppColors.lightGrey),
      const SizedBox(height: 12),
      // QR Code
      Center(
        child: QrImageView(
          data: qrData,
          version: QrVersions.auto,
          size: compact ? 100 : 160,
          eyeStyle: const QrEyeStyle(
              eyeShape: QrEyeShape.square, color: AppColors.black),
          dataModuleStyle: const QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: AppColors.black),
        ),
      ),
      const SizedBox(height: 10),
      const Text('PINDAI UNTUK VERIFIKASI',
          style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: AppColors.textGrey,
              letterSpacing: 1.0)),
      if (!compact) ...[
        const SizedBox(height: 8),
        const Divider(color: AppColors.lightGrey),
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('MOBITRA',
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary)),
          Text('EXP: ${DateTime.now().year + 1}',
              style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 10,
                  color: AppColors.textGrey)),
        ]),
      ],
    ]);
  }
}

// ── QR Card (grid) ──────────────────────────────────────────
class _QrCard extends StatelessWidget {
  final UserModel siswa;
  final VoidCallback onTap;
  const _QrCard({required this.siswa, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2))
            ]),
        child: _QrCardContent(siswa: siswa, compact: true),
      ),
    );
  }
}

// ── Batch record ────────────────────────────────────────────
class _BatchRecord {
  final String label, date;
  final int count;
  const _BatchRecord(
      {required this.label, required this.count, required this.date});
}

class _BatchTile extends StatelessWidget {
  final _BatchRecord batch;
  final VoidCallback onDownload;
  const _BatchTile({required this.batch, required this.onDownload});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ]),
      child: Row(children: [
        Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.qr_code_2_rounded,
                color: AppColors.primary, size: 22)),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(batch.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.black)),
          Text('${batch.count} QR Code • ${batch.date}',
              style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  color: AppColors.textGrey)),
        ])),
        IconButton(
          onPressed: onDownload,
          icon: const Icon(Icons.download_rounded,
              color: AppColors.primary, size: 22),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ]),
    );
  }
}
