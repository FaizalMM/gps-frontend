import 'package:flutter/material.dart';
import '../../models/models_api.dart';
import '../../services/api_client.dart';
import '../../services/app_data_service.dart';
import '../../utils/app_theme.dart';

// ── Helper format tanggal ────────────────────────────────────
String _fmtDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
String _todayStr() => _fmtDate(DateTime.now());

// ── Model lokal ──────────────────────────────────────────────
class _ActivitySummary {
  final int loginHari, loginGagal, akunSuspend;
  final List<Map<String, dynamic>> topUsers, byType;
  _ActivitySummary(
      {required this.loginHari,
      required this.loginGagal,
      required this.akunSuspend,
      required this.topUsers,
      required this.byType});
}

class _AttendanceSummary {
  final int total, checkout;
  _AttendanceSummary({required this.total, required this.checkout});
}

class _ReportSummary {
  final int totalLaporan, totalPenumpang;
  final List<Map<String, dynamic>> rows;
  _ReportSummary(
      {required this.totalLaporan,
      required this.totalPenumpang,
      required this.rows});
}

// ═══════════════════════════════════════════════════════════════
// MAIN SCREEN
// ═══════════════════════════════════════════════════════════════
class AdminAnalitikScreen extends StatefulWidget {
  final AppDataService dataService;
  const AdminAnalitikScreen({super.key, required this.dataService});
  @override
  State<AdminAnalitikScreen> createState() => _AdminAnalitikScreenState();
}

class _AdminAnalitikScreenState extends State<AdminAnalitikScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _api = ApiClient();

  bool _loading = true;
  _ActivitySummary? _activity;
  _AttendanceSummary? _attendance;
  _ReportSummary? _report;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await Future.wait([_fetchActivity(), _fetchAttendance(), _fetchReport()]);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _fetchActivity() async {
    final res = await _api.get('/activity/dashboard');
    if (!res.success || res.data == null) return;
    final d = res.data!;
    final summary = d['data']?['summary'] ?? d['summary'] ?? {};
    final topRaw =
        ((d['data']?['top_active_users'] ?? d['top_active_users']) as List? ??
            []);
    final byTypeRaw =
        ((d['data']?['activity_by_type'] ?? d['activity_by_type']) as List? ??
            []);
    if (!mounted) return;
    setState(() {
      _activity = _ActivitySummary(
        loginHari: (summary['recent_logins_24h'] as num?)?.toInt() ?? 0,
        loginGagal: (summary['failed_logins_24h'] as num?)?.toInt() ?? 0,
        akunSuspend: (summary['suspended_accounts'] as num?)?.toInt() ?? 0,
        topUsers: topRaw
            .take(5)
            .map<Map<String, dynamic>>((e) => {
                  'name': (e['user'] as Map?)?['name'] ?? 'Pengguna',
                  'role': (e['user'] as Map?)?['role'] ?? '-',
                  'count': (e['activity_count'] as num?)?.toInt() ?? 0,
                })
            .toList(),
        byType: byTypeRaw
            .take(6)
            .map<Map<String, dynamic>>((e) => {
                  'action': (e['action'] as String? ?? '-'),
                  'count': (e['count'] as num?)?.toInt() ?? 0,
                })
            .toList(),
      );
    });
  }

  Future<void> _fetchAttendance() async {
    final res = await _api.get('/attendance',
        params: {'tanggal': _todayStr(), 'per_page': '200'});
    if (!res.success || res.data == null) return;
    final raw = ((res.data!['data'] ?? res.data!['attendance']) as List? ?? [])
        .cast<Map<String, dynamic>>();
    if (!mounted) return;
    setState(() {
      _attendance = _AttendanceSummary(
        total: raw.length,
        checkout: raw.where((r) => r['checkout_time'] != null).length,
      );
    });
  }

  Future<void> _fetchReport() async {
    final res =
        await _api.get('/reports/admin', params: {'tanggal': _todayStr()});
    if (!res.success || res.data == null) return;
    final d = (res.data!['data'] ?? res.data!) as Map<String, dynamic>;
    final rows = ((d['reports'] as List?) ?? []).cast<Map<String, dynamic>>();
    final totalPenumpang = rows.fold<int>(
        0, (s, r) => s + ((r['total_penumpang'] as num?)?.toInt() ?? 0));
    if (!mounted) return;
    setState(() {
      _report = _ReportSummary(
        totalLaporan: (d['total_reports'] as num?)?.toInt() ?? rows.length,
        totalPenumpang: totalPenumpang,
        rows: rows,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final buses = widget.dataService.buses;
    final users = widget.dataService.users;
    final drivers = users.where((u) => u.role == UserRole.driver).toList();
    final siswa = users.where((u) => u.role == UserRole.siswa).toList();
    final admins = users
        .where((u) => u.role != UserRole.driver && u.role != UserRole.siswa)
        .toList();
    final activeBus = buses.where((b) => b.status == BusStatus.active).length;
    final activeGps = buses.where((b) => b.gpsActive).length;

    return SafeArea(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Header ──────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Row(children: [
            const Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('Analitik',
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.black)),
                  Text('Ringkasan Data Real-time',
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: AppColors.textGrey)),
                ])),
            GestureDetector(
              onTap: _loadData,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.lightGrey)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  _loading
                      ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                              strokeWidth: 1.5, color: AppColors.primary))
                      : const Icon(Icons.refresh_rounded,
                          size: 13, color: AppColors.textGrey),
                  const SizedBox(width: 5),
                  Text(_loading ? 'Memuat...' : 'Hari ini',
                      style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textGrey)),
                ]),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 16),

        // ── Tabs ────────────────────────────────────────────
        Container(
          color: AppColors.background,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TabBar(
            controller: _tabController,
            labelStyle: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                fontWeight: FontWeight.w600),
            unselectedLabelStyle:
                const TextStyle(fontFamily: 'Poppins', fontSize: 13),
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textGrey,
            indicator: const UnderlineTabIndicator(
                borderSide: BorderSide(color: AppColors.primary, width: 2.5)),
            tabs: const [
              Tab(text: 'Ringkasan'),
              Tab(text: 'Armada'),
              Tab(text: 'Pengguna'),
            ],
          ),
        ),
        Container(height: 0.5, color: AppColors.lightGrey),

        Expanded(
          child: _error != null
              ? _ErrorView(error: _error!, onRetry: _loadData)
              : TabBarView(controller: _tabController, children: [
                  _RingkasanTab(
                      buses: buses,
                      siswa: siswa,
                      drivers: drivers,
                      admins: admins,
                      activeBus: activeBus,
                      activeGps: activeGps,
                      activity: _activity,
                      attendance: _attendance,
                      report: _report,
                      loading: _loading),
                  _ArmadaTab(
                      buses: buses, report: _report, attendance: _attendance),
                  _PenggunaTab(
                      drivers: drivers,
                      siswa: siswa,
                      admins: admins,
                      dataService: widget.dataService,
                      activity: _activity),
                ]),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// TAB 1: RINGKASAN
// ═══════════════════════════════════════════════════════════════
class _RingkasanTab extends StatelessWidget {
  final List<BusModel> buses;
  final List<UserModel> siswa, drivers, admins;
  final int activeBus, activeGps;
  final _ActivitySummary? activity;
  final _AttendanceSummary? attendance;
  final _ReportSummary? report;
  final bool loading;

  const _RingkasanTab(
      {required this.buses,
      required this.siswa,
      required this.drivers,
      required this.admins,
      required this.activeBus,
      required this.activeGps,
      required this.activity,
      required this.attendance,
      required this.report,
      required this.loading});

  @override
  Widget build(BuildContext context) {
    final activeDrivers =
        drivers.where((d) => d.status == AccountStatus.active).length;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Stat cards utama (data real) ─────────────────────
        Row(children: [
          Expanded(
              child: _StatTile(
                  label: 'TOTAL BUS',
                  value: '${buses.length}',
                  sub: '$activeBus aktif · $activeGps GPS on',
                  icon: Icons.directions_bus_rounded,
                  color: AppColors.primary)),
          const SizedBox(width: 10),
          Expanded(
              child: _StatTile(
                  label: 'TOTAL SISWA',
                  value: '${siswa.length}',
                  sub: 'Terdaftar di sistem',
                  icon: Icons.school_rounded,
                  color: AppColors.purple)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
              child: _StatTile(
                  label: 'TOTAL DRIVER',
                  value: '${drivers.length}',
                  sub: '$activeDrivers aktif bertugas',
                  icon: Icons.badge_rounded,
                  color: AppColors.blue)),
          const SizedBox(width: 10),
          Expanded(
              child: _StatTile(
                  label: 'TOTAL ADMIN',
                  value: '${admins.length}',
                  sub: 'Pengelola sistem',
                  icon: Icons.admin_panel_settings_rounded,
                  color: AppColors.orange)),
        ]),
        const SizedBox(height: 20),

        // ── Absensi hari ini ──────────────────────────────────
        const _SectionHeader(title: 'Absensi Hari Ini'),
        const SizedBox(height: 10),
        loading
            ? const _LoadingCard()
            : attendance == null
                ? const _EmptyCard(msg: 'Data absensi belum tersedia')
                : _AbsensiCard(attendance: attendance!),
        const SizedBox(height: 20),

        // ── Laporan driver ────────────────────────────────────
        const _SectionHeader(title: 'Laporan Driver Hari Ini'),
        const SizedBox(height: 10),
        loading
            ? const _LoadingCard()
            : (report == null || report!.totalLaporan == 0)
                ? const _EmptyCard(msg: 'Belum ada laporan driver hari ini')
                : _LaporanCard(report: report!, buses: buses),
        const SizedBox(height: 20),

        // ── Aktivitas sistem ──────────────────────────────────
        const _SectionHeader(title: 'Aktivitas Sistem (24 Jam)'),
        const SizedBox(height: 10),
        loading
            ? const _LoadingCard()
            : activity == null
                ? const _EmptyCard(msg: 'Data aktivitas tidak tersedia')
                : _AktivitasCard(activity: activity!),
        const SizedBox(height: 20),

        // ── Top pengguna aktif ────────────────────────────────
        if (!loading && activity != null && activity!.topUsers.isNotEmpty) ...[
          const _SectionHeader(title: 'Pengguna Paling Aktif (7 Hari)'),
          const SizedBox(height: 10),
          ...activity!.topUsers.map((u) => _TopUserRow(data: u)),
        ],
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// TAB 2: ARMADA
// ═══════════════════════════════════════════════════════════════
class _ArmadaTab extends StatelessWidget {
  final List<BusModel> buses;
  final _ReportSummary? report;
  final _AttendanceSummary? attendance;
  const _ArmadaTab(
      {required this.buses, required this.report, required this.attendance});

  @override
  Widget build(BuildContext context) {
    final active = buses.where((b) => b.status == BusStatus.active).length;
    final gpsOn = buses.where((b) => b.gpsActive).length;
    final maintenance =
        buses.where((b) => b.status == BusStatus.maintenance).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      children: [
        Row(children: [
          Expanded(
              child: _StatTile(
                  label: 'BUS AKTIF',
                  value: '$active',
                  sub: '${buses.length} total armada',
                  icon: Icons.check_circle_rounded,
                  color: AppColors.primary)),
          const SizedBox(width: 10),
          Expanded(
              child: _StatTile(
                  label: 'GPS ON',
                  value: '$gpsOn',
                  sub: '${buses.length - gpsOn} GPS mati',
                  icon: Icons.location_on_rounded,
                  color: AppColors.blue)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
              child: _StatTile(
                  label: 'PERAWATAN',
                  value: '$maintenance',
                  sub: 'Bus dalam servis',
                  icon: Icons.build_rounded,
                  color: AppColors.orange)),
          const SizedBox(width: 10),
          Expanded(
              child: _StatTile(
                  label: 'PENUMPANG HARI INI',
                  value: attendance != null ? '${attendance!.total}' : '-',
                  sub: attendance != null
                      ? '${attendance!.checkout} sudah checkout'
                      : 'Memuat...',
                  icon: Icons.people_rounded,
                  color: AppColors.purple)),
        ]),
        const SizedBox(height: 20),

        // ── Laporan per bus ───────────────────────────────────
        if (report != null && report!.rows.isNotEmpty) ...[
          const _SectionHeader(title: 'Laporan Per Bus Hari Ini'),
          const SizedBox(height: 10),
          ...report!.rows.map((r) {
            final busData = r['bus'] as Map?;
            final nama = busData?['nama'] as String? ?? 'Bus';
            final plat = busData?['plat_nomor'] as String? ?? '-';
            final penumpang = (r['total_penumpang'] as num?)?.toInt() ?? 0;
            final catatan = r['catatan_driver'] as String? ?? '';
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
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
                    child: const Icon(Icons.directions_bus_rounded,
                        color: AppColors.primary, size: 20)),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(nama,
                          style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                      Text(plat,
                          style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11,
                              color: AppColors.textGrey)),
                      if (catatan.isNotEmpty)
                        Text(catatan,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 10,
                                color: AppColors.textGrey,
                                fontStyle: FontStyle.italic)),
                    ])),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('$penumpang',
                      style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary)),
                  const Text('penumpang',
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 9,
                          color: AppColors.textGrey)),
                ]),
              ]),
            );
          }),
          const SizedBox(height: 10),
        ],

        // ── Status semua armada ───────────────────────────────
        const _SectionHeader(title: 'Status Semua Armada'),
        const SizedBox(height: 10),
        ...buses.map((b) => _BusStatusRow(bus: b)),
        if (buses.isEmpty) const _EmptyState(msg: 'Belum ada data armada'),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// TAB 3: PENGGUNA
// ═══════════════════════════════════════════════════════════════
class _PenggunaTab extends StatelessWidget {
  final List<UserModel> drivers, siswa, admins;
  final AppDataService dataService;
  final _ActivitySummary? activity;

  const _PenggunaTab(
      {required this.drivers,
      required this.siswa,
      required this.admins,
      required this.dataService,
      required this.activity});

  @override
  Widget build(BuildContext context) {
    final activeDrivers =
        drivers.where((d) => d.status == AccountStatus.active).length;
    final pendingSiswa =
        siswa.where((s) => s.status == AccountStatus.pending).length;
    final activeSiswa =
        siswa.where((s) => s.status == AccountStatus.active).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      children: [
        // ── Stat pengguna ─────────────────────────────────────
        Row(children: [
          Expanded(
              child: _StatTile(
                  label: 'TOTAL SISWA',
                  value: '${siswa.length}',
                  sub: '$activeSiswa aktif · $pendingSiswa pending',
                  icon: Icons.school_rounded,
                  color: AppColors.purple)),
          const SizedBox(width: 10),
          Expanded(
              child: _StatTile(
                  label: 'TOTAL DRIVER',
                  value: '${drivers.length}',
                  sub: '$activeDrivers aktif bertugas',
                  icon: Icons.badge_rounded,
                  color: AppColors.blue)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
              child: _StatTile(
                  label: 'TOTAL ADMIN',
                  value: '${admins.length}',
                  sub: 'Pengelola sistem',
                  icon: Icons.admin_panel_settings_rounded,
                  color: AppColors.orange)),
          const SizedBox(width: 10),
          Expanded(
              child: _StatTile(
                  label: 'AKUN SUSPEND',
                  value: activity != null ? '${activity!.akunSuspend}' : '-',
                  sub: 'Diblokir admin',
                  icon: Icons.block_rounded,
                  color: AppColors.red)),
        ]),
        const SizedBox(height: 20),

        // ── Login info ────────────────────────────────────────
        if (activity != null) ...[
          const _SectionHeader(title: 'Aktivitas Login (24 Jam)'),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
                child: _MiniStatCard(
                    label: 'Login Berhasil',
                    value: '${activity!.loginHari}',
                    color: AppColors.primary,
                    icon: Icons.login_rounded)),
            const SizedBox(width: 10),
            Expanded(
                child: _MiniStatCard(
                    label: 'Login Gagal',
                    value: '${activity!.loginGagal}',
                    color: AppColors.red,
                    icon: Icons.error_outline_rounded)),
          ]),
          const SizedBox(height: 20),
          if (activity!.byType.isNotEmpty) ...[
            const _SectionHeader(title: 'Jenis Aktivitas (30 Hari)'),
            const SizedBox(height: 10),
            _AktivitasBarChart(data: activity!.byType),
            const SizedBox(height: 20),
          ],
        ],

        // ── Daftar driver ─────────────────────────────────────
        const _SectionHeader(title: 'Daftar Driver'),
        const SizedBox(height: 10),
        ...drivers.map((d) {
          final bus = dataService.getDriverBus(d.idStr);
          final isActive = d.status == AccountStatus.active;
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
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
                      color: isActive
                          ? AppColors.primaryLight
                          : AppColors.surface2,
                      shape: BoxShape.circle),
                  child: Center(
                      child: Text(
                          d.namaLengkap.isNotEmpty
                              ? d.namaLengkap[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: isActive
                                  ? AppColors.primary
                                  : AppColors.textGrey)))),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(d.namaLengkap,
                        style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.black)),
                    Text(
                        bus != null
                            ? 'Bus ${bus.nama} · ${bus.platNomor}'
                            : 'Belum ditugaskan',
                        style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            color: AppColors.textGrey)),
                  ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color:
                        isActive ? AppColors.primaryLight : AppColors.surface2,
                    borderRadius: BorderRadius.circular(6)),
                child: Text(isActive ? 'Aktif' : 'Nonaktif',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color:
                            isActive ? AppColors.primary : AppColors.textGrey)),
              ),
            ]),
          );
        }),
        if (drivers.isEmpty) const _EmptyState(msg: 'Belum ada data driver'),
        const SizedBox(height: 20),

        // ── Siswa pending ─────────────────────────────────────
        if (pendingSiswa > 0) ...[
          _SectionHeader(title: 'Menunggu Persetujuan ($pendingSiswa)'),
          const SizedBox(height: 10),
          ...siswa.where((s) => s.status == AccountStatus.pending).map((s) =>
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.pendingOrange.withValues(alpha: 0.4))),
                child: Row(children: [
                  const Icon(Icons.hourglass_top_rounded,
                      size: 18, color: AppColors.pendingOrange),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(s.namaLengkap,
                          style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13,
                              fontWeight: FontWeight.w500))),
                  const Text('Pending',
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          color: AppColors.pendingOrange,
                          fontWeight: FontWeight.w600)),
                ]),
              )),
        ],
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// CARD WIDGETS
// ═══════════════════════════════════════════════════════════════
class _AbsensiCard extends StatelessWidget {
  final _AttendanceSummary attendance;
  const _AbsensiCard({required this.attendance});

  @override
  Widget build(BuildContext context) {
    final pct = attendance.total > 0
        ? (attendance.checkout / attendance.total * 100).round()
        : 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: _MiniStatCard(
                  label: 'Naik Bus',
                  value: '${attendance.total}',
                  color: AppColors.blue,
                  icon: Icons.directions_bus_rounded)),
          const SizedBox(width: 10),
          Expanded(
              child: _MiniStatCard(
                  label: 'Sudah Turun',
                  value: '${attendance.checkout}',
                  color: AppColors.primary,
                  icon: Icons.check_circle_outline_rounded)),
        ]),
        const SizedBox(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Rate Checkout',
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  color: AppColors.textGrey)),
          Text('$pct%',
              style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary)),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: attendance.total > 0
                ? attendance.checkout / attendance.total
                : 0,
            backgroundColor: AppColors.lightGrey,
            color: AppColors.primary,
            minHeight: 8,
          ),
        ),
      ]),
    );
  }
}

class _LaporanCard extends StatelessWidget {
  final _ReportSummary report;
  final List<BusModel> buses;
  const _LaporanCard({required this.report, required this.buses});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: _MiniStatCard(
                  label: 'Laporan Masuk',
                  value: '${report.totalLaporan}',
                  color: AppColors.primary,
                  icon: Icons.assignment_turned_in_rounded)),
          const SizedBox(width: 10),
          Expanded(
              child: _MiniStatCard(
                  label: 'Total Penumpang',
                  value: '${report.totalPenumpang}',
                  color: AppColors.purple,
                  icon: Icons.people_rounded)),
        ]),
        if (buses.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
              '${report.totalLaporan} dari ${buses.length} bus melaporkan hari ini',
              style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  color: AppColors.textGrey)),
        ],
      ]),
    );
  }
}

class _AktivitasCard extends StatelessWidget {
  final _ActivitySummary activity;
  const _AktivitasCard({required this.activity});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ]),
      child: Row(children: [
        Expanded(
            child: _MiniStatCard(
                label: 'Login Berhasil',
                value: '${activity.loginHari}',
                color: AppColors.primary,
                icon: Icons.login_rounded)),
        const SizedBox(width: 10),
        Expanded(
            child: _MiniStatCard(
                label: 'Login Gagal',
                value: '${activity.loginGagal}',
                color: AppColors.red,
                icon: Icons.error_outline_rounded)),
        const SizedBox(width: 10),
        Expanded(
            child: _MiniStatCard(
                label: 'Akun Suspend',
                value: '${activity.akunSuspend}',
                color: AppColors.orange,
                icon: Icons.block_rounded)),
      ]),
    );
  }
}

class _AktivitasBarChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  const _AktivitasBarChart({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();
    final maxCount =
        data.map((e) => e['count'] as int).reduce((a, b) => a > b ? a : b);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ]),
      child: Column(
        children: data.map((e) {
          final action = (e['action'] as String).replaceAll('_', ' ');
          final count = e['count'] as int;
          final ratio = maxCount > 0 ? count / maxCount : 0.0;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              SizedBox(
                  width: 90,
                  child: Text(action,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 10,
                          color: AppColors.textGrey))),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 10,
                    backgroundColor: AppColors.lightGrey,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                  width: 30,
                  child: Text('$count',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.black))),
            ]),
          );
        }).toList(),
      ),
    );
  }
}

class _TopUserRow extends StatelessWidget {
  final Map<String, dynamic> data;
  const _TopUserRow({required this.data});

  Color _roleColor(String role) {
    switch (role) {
      case 'driver':
        return AppColors.blue;
      case 'siswa':
        return AppColors.purple;
      default:
        return AppColors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = data['name'] as String? ?? '-';
    final role = data['role'] as String? ?? '-';
    final count = data['count'] as int? ?? 0;
    final clr = _roleColor(role);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ]),
      child: Row(children: [
        Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
                color: clr.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Center(
                child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: clr)))),
        const SizedBox(width: 10),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name,
              style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.black)),
          Text(role,
              style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 10,
                  color: AppColors.textGrey)),
        ])),
        Text('$count aksi',
            style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.primary)),
      ]),
    );
  }
}

class _BusStatusRow extends StatelessWidget {
  final BusModel bus;
  const _BusStatusRow({required this.bus});

  @override
  Widget build(BuildContext context) {
    final isActive = bus.status == BusStatus.active;
    final isMaint = bus.status == BusStatus.maintenance;
    final statusColor = isActive
        ? AppColors.primary
        : isMaint
            ? AppColors.orange
            : AppColors.textGrey;
    final statusText = isActive
        ? 'Aktif'
        : isMaint
            ? 'Perawatan'
            : 'Nonaktif';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ]),
      child: Row(children: [
        Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(9)),
            child: Icon(Icons.directions_bus_rounded,
                color: statusColor, size: 18)),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(bus.nama,
              style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.black)),
          Text(bus.platNomor,
              style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  color: AppColors.textGrey)),
        ])),
        Icon(bus.gpsActive ? Icons.gps_fixed_rounded : Icons.gps_off_rounded,
            size: 14,
            color: bus.gpsActive ? AppColors.blue : AppColors.lightGrey),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6)),
          child: Text(statusText,
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: statusColor)),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// SHARED SMALL WIDGETS
// ═══════════════════════════════════════════════════════════════
class _StatTile extends StatelessWidget {
  final String label, value, sub;
  final IconData icon;
  final Color color;
  const _StatTile(
      {required this.label,
      required this.value,
      required this.sub,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Expanded(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textGrey,
                      letterSpacing: 0.4))),
        ]),
        const SizedBox(height: 6),
        Text(value,
            style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppColors.black,
                height: 1.0)),
        const SizedBox(height: 2),
        Text(sub,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 10,
                color: AppColors.textGrey)),
      ]),
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  final String label, value;
  final Color color;
  final IconData icon;
  const _MiniStatCard(
      {required this.label,
      required this.value,
      required this.color,
      required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(height: 6),
        Text(value,
            style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: color)),
        Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 10,
                color: AppColors.textGrey)),
      ]),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(title,
        style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.black));
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
          color: AppColors.white, borderRadius: BorderRadius.circular(14)),
      child: const Center(
          child: CircularProgressIndicator(
              strokeWidth: 2, color: AppColors.primary)),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final String msg;
  const _EmptyCard({required this.msg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: AppColors.surface2, borderRadius: BorderRadius.circular(14)),
      child: Center(
          child: Text(msg,
              style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  color: AppColors.textGrey))),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String msg;
  const _EmptyState({required this.msg});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 30),
      child: Center(
          child: Text(msg,
              style: const TextStyle(
                  fontFamily: 'Poppins', color: AppColors.textGrey))),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.cloud_off_rounded,
              size: 48, color: AppColors.textLight),
          const SizedBox(height: 12),
          const Text('Gagal memuat data',
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                  color: AppColors.black)),
          const SizedBox(height: 4),
          Text(error,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  color: AppColors.textGrey)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Coba Lagi',
                style: TextStyle(fontFamily: 'Poppins')),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20))),
          ),
        ]),
      ),
    );
  }
}
