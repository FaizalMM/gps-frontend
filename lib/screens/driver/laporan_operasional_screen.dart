import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/app_data_service.dart';
import '../../utils/app_theme.dart';

class LaporanOperasionalScreen extends StatefulWidget {
  final AppDataService dataService;
  final String driverId;

  const LaporanOperasionalScreen({
    super.key,
    required this.dataService,
    required this.driverId,
  });

  @override
  State<LaporanOperasionalScreen> createState() =>
      _LaporanOperasionalScreenState();
}

class _LaporanOperasionalScreenState extends State<LaporanOperasionalScreen> {
  DateTime _selectedDate = DateTime.now();

  // Dummy student log data (frontend only)
  final List<_StudentLogEntry> _studentLog = [
    const _StudentLogEntry(
      name: 'Sarah Johnson',
      initials: 'SJ',
      avatarColor: null, // will show image placeholder
      stopNumber: '03',
      stopAddress: 'Main St.',
      pickupTime: '07:45 AM',
      isVerified: true,
    ),
    const _StudentLogEntry(
      name: 'Michael Jones',
      initials: 'MJ',
      avatarColor: Color(0xFFBBDEFB),
      stopNumber: '04',
      stopAddress: 'Oak Ave.',
      pickupTime: '07:52 AM',
      isVerified: true,
    ),
    const _StudentLogEntry(
      name: 'David Wilson',
      initials: 'DW',
      avatarColor: null,
      stopNumber: '05',
      stopAddress: 'Pine Ln.',
      pickupTime: '08:05 AM',
      isVerified: true,
    ),
    const _StudentLogEntry(
      name: 'Emma Lewis',
      initials: 'EL',
      avatarColor: Color(0xFFFFF9C4),
      stopNumber: '06',
      stopAddress: 'Hilltop Rd.',
      pickupTime: '08:12 AM',
      isVerified: true,
    ),
  ];

  void _showAllStudents(BuildContext context) {
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
                  Text('${_studentLog.length} siswa',
                      style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: AppColors.textGrey)),
                ])),
            Expanded(
              child: ListView.builder(
                controller: ctrl,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 30),
                itemCount: _studentLog.length,
                itemBuilder: (_, i) {
                  final s = _studentLog[i];
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
                      Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                              color: AppColors.primaryLight,
                              shape: BoxShape.circle),
                          child: Center(
                              child: Text(s.initials,
                                  style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                      fontSize: 15)))),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(s.name,
                                style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                            Text(s.route,
                                style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 11,
                                    color: AppColors.textGrey)),
                          ])),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: s.status == 'Naik'
                              ? AppColors.primaryLight
                              : AppColors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(s.status,
                            style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: s.status == 'Naik'
                                    ? AppColors.primary
                                    : AppColors.orange)),
                      ),
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

  void _pickDate() async {
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
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final laporan = widget.dataService.getLaporanByDriver(widget.driverId);
    final todayLaporan = laporan;

    final totalStudents = todayLaporan?.siswaTerangkut ?? _studentLog.length;
    final routeTime = todayLaporan?.waktuOperasional ?? '1h 15m';
    final dateStr =
        DateFormat('EEEE, MMM d').format(_selectedDate); // e.g. Monday, Oct 24

    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: _BottomExportBar(
        onExportPdf: () => _showExportSnack('PDF'),
        onExportExcel: () => _showExportSnack('Excel'),
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
            color: AppColors.black,
          ),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date header
            Text(
              dateStr,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppColors.black,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'School Year 2023-2024 • Route #42A',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                color: AppColors.textGrey,
              ),
            ),
            const SizedBox(height: 20),

            // Stat cards
            Row(
              children: [
                Expanded(
                  child: _BigStatCard(
                    icon: Icons.people_rounded,
                    iconBgColor: AppColors.primaryLight,
                    iconColor: AppColors.primary,
                    value: '$totalStudents',
                    label: 'Total Students',
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _BigStatCard(
                    icon: Icons.access_time_rounded,
                    iconBgColor: AppColors.primaryLight,
                    iconColor: AppColors.primary,
                    value: routeTime.contains('-') ? '1h 15m' : routeTime,
                    label: 'Route Time',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Student Log card
            Container(
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Log Siswa',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.black,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _showAllStudents(context),
                          child: const Text(
                            'Lihat Semua',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Student entries
                  ..._studentLog.asMap().entries.map((entry) {
                    final i = entry.key;
                    final s = entry.value;
                    return _StudentLogRow(
                      entry: s,
                      showDivider: i < _studentLog.length - 1,
                    );
                  }),

                  const SizedBox(height: 8),
                ],
              ),
            ),

            const SizedBox(height: 100), // space for bottom bar
          ],
        ),
      ),
    );
  }

  void _showExportSnack(String type) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Mengekspor laporan ke $type...'),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

// ─── Data model for student log entry ────────────────────────────────────────

class _StudentLogEntry {
  final String name;
  final String initials;
  final Color? avatarColor;
  final String stopNumber;
  final String stopAddress;
  final String pickupTime;
  final bool isVerified;
  final String route;
  final String status;

  const _StudentLogEntry({
    required this.name,
    required this.initials,
    this.avatarColor,
    required this.stopNumber,
    required this.stopAddress,
    required this.pickupTime,
    required this.isVerified,
    this.route = 'Route #42A',
    this.status = 'Naik',
  });
}

// ─── Widgets ─────────────────────────────────────────────────────────────────

class _BigStatCard extends StatelessWidget {
  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final String value;
  final String label;

  const _BigStatCard({
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 26),
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: AppColors.black,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              color: AppColors.textGrey,
            ),
          ),
        ],
      ),
    );
  }
}

class _StudentLogRow extends StatelessWidget {
  final _StudentLogEntry entry;
  final bool showDivider;

  const _StudentLogRow({
    required this.entry,
    required this.showDivider,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Row(
            children: [
              // Avatar
              _Avatar(
                initials: entry.initials,
                bgColor: entry.avatarColor,
              ),
              const SizedBox(width: 14),

              // Name & stop
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.name,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.black,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Stop #${entry.stopNumber} • ${entry.stopAddress}',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        color: AppColors.textGrey,
                      ),
                    ),
                  ],
                ),
              ),

              // Time & verified badge
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    entry.pickupTime,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (entry.isVerified)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 16,
                          height: 16,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 11,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'TERVERIFIKASI',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
        if (showDivider)
          const Divider(
            height: 1,
            indent: 18,
            endIndent: 18,
            color: Color(0xFFF0F0F0),
          ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  final String initials;
  final Color? bgColor;

  const _Avatar({required this.initials, this.bgColor});

  @override
  Widget build(BuildContext context) {
    if (bgColor != null) {
      return CircleAvatar(
        radius: 24,
        backgroundColor: bgColor,
        child: Text(
          initials,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: AppColors.black,
          ),
        ),
      );
    }
    // Grey placeholder avatar
    return const CircleAvatar(
      radius: 24,
      backgroundColor: AppColors.lightGrey,
      child: Icon(Icons.person_rounded, color: AppColors.textGrey, size: 26),
    );
  }
}

class _BottomExportBar extends StatelessWidget {
  final VoidCallback onExportPdf;
  final VoidCallback onExportExcel;

  const _BottomExportBar({
    required this.onExportPdf,
    required this.onExportExcel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 14, 20, 14 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ExportButton(
              label: 'Ekspor PDF',
              icon: Icons.picture_as_pdf_rounded,
              onTap: onExportPdf,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _ExportButton(
              label: 'Ekspor Excel',
              icon: Icons.table_chart_rounded,
              onTap: onExportExcel,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExportButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _ExportButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
