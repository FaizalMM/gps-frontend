import 'package:flutter/material.dart';
import '../../models/models_api.dart';
import '../../services/app_data_service.dart';
import '../../utils/app_theme.dart';

class AdminAnalitikScreen extends StatefulWidget {
  final AppDataService dataService;
  const AdminAnalitikScreen({super.key, required this.dataService});

  @override
  State<AdminAnalitikScreen> createState() => _AdminAnalitikScreenState();
}

class _AdminAnalitikScreenState extends State<AdminAnalitikScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showPeriodPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(
              child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.lightGrey,
                      borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          const Text('Pilih Periode',
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ...[
            '7 Hari Terakhir',
            '30 Hari Terakhir',
            '3 Bulan Terakhir',
            'Tahun Ini'
          ].map((p) => ListTile(
                onTap: () => Navigator.pop(context),
                title: Text(p,
                    style:
                        const TextStyle(fontFamily: 'Poppins', fontSize: 14)),
                trailing: p == '30 Hari Terakhir'
                    ? const Icon(Icons.check_rounded,
                        color: AppColors.primary, size: 18)
                    : null,
                dense: true,
              )),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final buses = widget.dataService.buses;
    final users = widget.dataService.users;
    final drivers = users.where((u) => u.role == UserRole.driver).toList();
    final siswa = users.where((u) => u.role == UserRole.siswa).toList();
    final active = buses.where((b) => b.status == BusStatus.active).length;
    final onGps = buses.where((b) => b.gpsActive).length;

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
                  Text('Ringkasan Performa Armada',
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: AppColors.textGrey)),
                ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.lightGrey)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.calendar_today_rounded,
                    size: 13, color: AppColors.textGrey),
                SizedBox(width: 5),
                Text('30 Hari Terakhir',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textGrey)),
              ]),
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
              Tab(text: 'Rute'),
              Tab(text: 'Driver')
            ],
          ),
        ),
        Container(height: 0.5, color: AppColors.lightGrey),

        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // ── Tab 1: Ringkasan ───────────────────────
              _RingkasanTab(
                  buses: buses,
                  siswa: siswa,
                  drivers: drivers,
                  active: active,
                  onGps: onGps),
              // ── Tab 2: Rute ────────────────────────────
              _RuteTab(buses: buses),
              // ── Tab 3: Driver ──────────────────────────
              _DriverTab(drivers: drivers, dataService: widget.dataService),
            ],
          ),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// TAB RINGKASAN
// ═══════════════════════════════════════════════════════════
class _RingkasanTab extends StatelessWidget {
  final List<BusModel> buses;
  final List<UserModel> siswa;
  final List<UserModel> drivers;
  final int active, onGps;

  const _RingkasanTab(
      {required this.buses,
      required this.siswa,
      required this.drivers,
      required this.active,
      required this.onGps});

  void _showPeriodPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(
              child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.lightGrey,
                      borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          const Text('Pilih Periode',
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ...[
            '7 Hari Terakhir',
            '30 Hari Terakhir',
            '3 Bulan Terakhir',
            'Tahun Ini'
          ].map((p) => ListTile(
                onTap: () => Navigator.pop(context),
                title: Text(p,
                    style:
                        const TextStyle(fontFamily: 'Poppins', fontSize: 14)),
                trailing: p == '30 Hari Terakhir'
                    ? const Icon(Icons.check_rounded,
                        color: AppColors.primary, size: 18)
                    : null,
                dense: true,
              )),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // 4 stat cards
        Row(children: [
          Expanded(
              child: _StatTile(
                  label: 'TOTAL RUTE',
                  value: '${buses.length}',
                  sub: '+2% minggu ini',
                  icon: Icons.route_rounded,
                  color: AppColors.primary)),
          const SizedBox(width: 10),
          const Expanded(
              child: _StatTile(
                  label: 'RATA KONSUMSI',
                  value: '12.5L',
                  sub: '-5% lebih hemat',
                  icon: Icons.local_gas_station_rounded,
                  color: AppColors.orange)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
              child: _StatTile(
                  label: 'KEHADIRAN',
                  value: '${siswa.length}',
                  sub: 'Siswa terdaftar',
                  icon: Icons.people_rounded,
                  color: AppColors.blue)),
          const SizedBox(width: 10),
          const Expanded(
              child: _StatTile(
                  label: 'TEPAT WAKTU',
                  value: '88%',
                  sub: '+4% bulan ini',
                  icon: Icons.timer_rounded,
                  color: AppColors.primary)),
        ]),
        const SizedBox(height: 20),

        // Efisiensi Rute chart
        const _SectionHeader(title: 'Efisiensi Rute', action: '•••'),
        const SizedBox(height: 12),
        const _BarChart(
          labels: ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab'],
          values: [0.6, 0.45, 0.8, 0.9, 0.85, 0.5],
          color: AppColors.primary,
        ),
        const SizedBox(height: 20),

        // Tren Bahan Bakar
        Row(children: [
          const Expanded(
              child: _SectionHeader(title: 'Tren Bahan Bakar', action: '')),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(20)),
            child: const Text('30 HARI TERAKHIR',
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary)),
          ),
        ]),
        const SizedBox(height: 12),
        const _LineChart(
          labels: ['1', '5', '10', '15', '20', '25', '30'],
          values: [0.7, 0.65, 0.8, 0.75, 0.6, 0.85, 0.7],
          color: AppColors.blue,
        ),
        const SizedBox(height: 20),

        // Status armada
        const _SectionHeader(title: 'Status Armada', action: ''),
        const SizedBox(height: 10),
        _FleetStatus(buses: buses),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// TAB RUTE
// ═══════════════════════════════════════════════════════════
class _RuteTab extends StatelessWidget {
  final List<BusModel> buses;
  const _RuteTab({required this.buses});

  void _showPeriodPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(
              child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.lightGrey,
                      borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          const Text('Pilih Periode',
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ...[
            '7 Hari Terakhir',
            '30 Hari Terakhir',
            '3 Bulan Terakhir',
            'Tahun Ini'
          ].map((p) => ListTile(
                onTap: () => Navigator.pop(context),
                title: Text(p,
                    style:
                        const TextStyle(fontFamily: 'Poppins', fontSize: 14)),
                trailing: p == '30 Hari Terakhir'
                    ? const Icon(Icons.check_rounded,
                        color: AppColors.primary, size: 18)
                    : null,
                dense: true,
              )),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final routes =
        buses.map((b) => b.rute).where((r) => r.isNotEmpty).toSet().toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      children: [
        // Summary
        Row(children: [
          Expanded(
              child: _StatTile(
                  label: 'TOTAL RUTE',
                  value: '${routes.length}',
                  sub: 'Rute aktif',
                  icon: Icons.map_rounded,
                  color: AppColors.primary)),
          const SizedBox(width: 10),
          Expanded(
              child: _StatTile(
                  label: 'TOTAL BUS',
                  value: '${buses.length}',
                  sub: 'Unit armada',
                  icon: Icons.directions_bus_rounded,
                  color: AppColors.blue)),
        ]),
        const SizedBox(height: 20),
        const _SectionHeader(title: 'Daftar Rute', action: ''),
        const SizedBox(height: 10),
        ...routes.asMap().entries.map((e) {
          final routeBuses = buses.where((b) => b.rute == e.value).toList();
          return _RouteCard(
            index: e.key + 1,
            name: e.value,
            busCount: routeBuses.length,
            active:
                routeBuses.where((b) => b.status == BusStatus.active).length,
          );
        }),
        if (routes.isEmpty)
          const Center(
              child: Padding(
            padding: EdgeInsets.all(40),
            child: Text('Belum ada data rute',
                style: TextStyle(
                    fontFamily: 'Poppins', color: AppColors.textGrey)),
          )),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
// TAB DRIVER
// ═══════════════════════════════════════════════════════════
class _DriverTab extends StatelessWidget {
  final List<UserModel> drivers;
  final AppDataService dataService;
  const _DriverTab({required this.drivers, required this.dataService});

  void _showPeriodPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(
              child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.lightGrey,
                      borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          const Text('Pilih Periode',
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ...[
            '7 Hari Terakhir',
            '30 Hari Terakhir',
            '3 Bulan Terakhir',
            'Tahun Ini'
          ].map((p) => ListTile(
                onTap: () => Navigator.pop(context),
                title: Text(p,
                    style:
                        const TextStyle(fontFamily: 'Poppins', fontSize: 14)),
                trailing: p == '30 Hari Terakhir'
                    ? const Icon(Icons.check_rounded,
                        color: AppColors.primary, size: 18)
                    : null,
                dense: true,
              )),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final active =
        drivers.where((d) => d.status == AccountStatus.active).length;
    final inactive = drivers.length - active;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      children: [
        Row(children: [
          Expanded(
              child: _StatTile(
                  label: 'TOTAL DRIVER',
                  value: '${drivers.length}',
                  sub: 'Terdaftar',
                  icon: Icons.badge_rounded,
                  color: AppColors.purple)),
          const SizedBox(width: 10),
          Expanded(
              child: _StatTile(
                  label: 'DRIVER AKTIF',
                  value: '$active',
                  sub: '$inactive sedang nonaktif',
                  icon: Icons.check_circle_rounded,
                  color: AppColors.primary)),
        ]),
        const SizedBox(height: 20),
        const _SectionHeader(title: 'Performa Driver', action: ''),
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
                      child: Text(d.namaLengkap[0].toUpperCase(),
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
                            ? 'Bus ${bus.nama} • ${bus.rute}'
                            : 'Belum ditugaskan',
                        style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            color: AppColors.textGrey)),
                  ])),
              // Progress bar performa (simulasi)
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(isActive ? '92%' : '—',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color:
                            isActive ? AppColors.primary : AppColors.textGrey)),
                const Text('performa',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 9,
                        color: AppColors.textGrey)),
              ]),
            ]),
          );
        }),
        if (drivers.isEmpty)
          const Center(
              child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Text('Belum ada data driver',
                      style: TextStyle(
                          fontFamily: 'Poppins', color: AppColors.textGrey)))),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
// SHARED WIDGETS
// ═══════════════════════════════════════════════════════════

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

  void _showPeriodPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(
              child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.lightGrey,
                      borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          const Text('Pilih Periode',
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ...[
            '7 Hari Terakhir',
            '30 Hari Terakhir',
            '3 Bulan Terakhir',
            'Tahun Ini'
          ].map((p) => ListTile(
                onTap: () => Navigator.pop(context),
                title: Text(p,
                    style:
                        const TextStyle(fontFamily: 'Poppins', fontSize: 14)),
                trailing: p == '30 Hari Terakhir'
                    ? const Icon(Icons.check_rounded,
                        color: AppColors.primary, size: 18)
                    : null,
                dense: true,
              )),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

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
          Text(label,
              style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textGrey,
                  letterSpacing: 0.4)),
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
        Row(children: [
          Icon(
              sub.contains('+')
                  ? Icons.arrow_upward_rounded
                  : sub.contains('-')
                      ? Icons.arrow_downward_rounded
                      : Icons.info_outline_rounded,
              size: 10,
              color: sub.contains('+')
                  ? AppColors.primary
                  : sub.contains('-')
                      ? AppColors.orange
                      : AppColors.textGrey),
          const SizedBox(width: 2),
          Expanded(
              child: Text(sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 10,
                      color: sub.contains('+')
                          ? AppColors.primary
                          : sub.contains('-')
                              ? AppColors.orange
                              : AppColors.textGrey))),
        ]),
      ]),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title, action;
  const _SectionHeader({required this.title, required this.action});

  void _showPeriodPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(
              child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.lightGrey,
                      borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          const Text('Pilih Periode',
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ...[
            '7 Hari Terakhir',
            '30 Hari Terakhir',
            '3 Bulan Terakhir',
            'Tahun Ini'
          ].map((p) => ListTile(
                onTap: () => Navigator.pop(context),
                title: Text(p,
                    style:
                        const TextStyle(fontFamily: 'Poppins', fontSize: 14)),
                trailing: p == '30 Hari Terakhir'
                    ? const Icon(Icons.check_rounded,
                        color: AppColors.primary, size: 18)
                    : null,
                dense: true,
              )),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
          child: Text(title,
              style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.black))),
      if (action.isNotEmpty)
        Text(action,
            style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 18,
                color: AppColors.textGrey)),
    ]);
  }
}

// ── Bar chart sederhana ─────────────────────────────────────
class _BarChart extends StatelessWidget {
  final List<String> labels;
  final List<double> values; // 0.0 – 1.0
  final Color color;
  const _BarChart(
      {required this.labels, required this.values, required this.color});

  void _showPeriodPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(
              child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.lightGrey,
                      borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          const Text('Pilih Periode',
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ...[
            '7 Hari Terakhir',
            '30 Hari Terakhir',
            '3 Bulan Terakhir',
            'Tahun Ini'
          ].map((p) => ListTile(
                onTap: () => Navigator.pop(context),
                title: Text(p,
                    style:
                        const TextStyle(fontFamily: 'Poppins', fontSize: 14)),
                trailing: p == '30 Hari Terakhir'
                    ? const Icon(Icons.check_rounded,
                        color: AppColors.primary, size: 18)
                    : null,
                dense: true,
              )),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 130,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ]),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 14, 10, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(labels.length, (i) {
            final isTall = values[i] > 0.7;
            return Expanded(
              child:
                  Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: FractionallySizedBox(
                        heightFactor: values[i],
                        child: Container(
                          decoration: BoxDecoration(
                            color:
                                isTall ? color : color.withValues(alpha: 0.4),
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(5)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Text(labels[i],
                    style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 10,
                        color: AppColors.textGrey)),
              ]),
            );
          }),
        ),
      ),
    );
  }
}

// ── Line chart sederhana ─────────────────────────────────────
class _LineChart extends StatelessWidget {
  final List<String> labels;
  final List<double> values;
  final Color color;
  const _LineChart(
      {required this.labels, required this.values, required this.color});

  void _showPeriodPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(
              child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.lightGrey,
                      borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          const Text('Pilih Periode',
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ...[
            '7 Hari Terakhir',
            '30 Hari Terakhir',
            '3 Bulan Terakhir',
            'Tahun Ini'
          ].map((p) => ListTile(
                onTap: () => Navigator.pop(context),
                title: Text(p,
                    style:
                        const TextStyle(fontFamily: 'Poppins', fontSize: 14)),
                trailing: p == '30 Hari Terakhir'
                    ? const Icon(Icons.check_rounded,
                        color: AppColors.primary, size: 18)
                    : null,
                dense: true,
              )),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 110,
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 8),
      decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ]),
      child: CustomPaint(
        painter: _LinePainter(values: values, color: color),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: labels
              .map((l) => Text(l,
                  style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 9,
                      color: AppColors.textGrey)))
              .toList(),
        ),
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  final List<double> values;
  final Color color;
  const _LinePainter({required this.values, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final chartH = size.height - 16;
    final stepX = size.width / (values.length - 1);
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final fill = Paint()
      ..color = color.withValues(alpha: 0.1)
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();

    for (int i = 0; i < values.length; i++) {
      final x = i * stepX;
      final y = chartH * (1 - values[i]);
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, chartH);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }
    fillPath.lineTo((values.length - 1) * stepX, chartH);
    fillPath.close();

    canvas.drawPath(fillPath, fill);
    canvas.drawPath(path, paint);

    // Dots
    final dot = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    for (int i = 0; i < values.length; i++) {
      canvas.drawCircle(Offset(i * stepX, chartH * (1 - values[i])), 3, dot);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── Fleet status ────────────────────────────────────────────
class _FleetStatus extends StatelessWidget {
  final List<BusModel> buses;
  const _FleetStatus({required this.buses});

  void _showPeriodPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(
              child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.lightGrey,
                      borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          const Text('Pilih Periode',
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ...[
            '7 Hari Terakhir',
            '30 Hari Terakhir',
            '3 Bulan Terakhir',
            'Tahun Ini'
          ].map((p) => ListTile(
                onTap: () => Navigator.pop(context),
                title: Text(p,
                    style:
                        const TextStyle(fontFamily: 'Poppins', fontSize: 14)),
                trailing: p == '30 Hari Terakhir'
                    ? const Icon(Icons.check_rounded,
                        color: AppColors.primary, size: 18)
                    : null,
                dense: true,
              )),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: buses.map((b) {
        final isActive = b.status == BusStatus.active;
        final isMaint = b.status == BusStatus.maintenance;
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
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(b.nama,
                      style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.black)),
                  Text(b.platNomor,
                      style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          color: AppColors.textGrey)),
                ])),
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
      }).toList(),
    );
  }
}

// ── Route card ──────────────────────────────────────────────
class _RouteCard extends StatelessWidget {
  final int index, busCount, active;
  final String name;
  const _RouteCard(
      {required this.index,
      required this.name,
      required this.busCount,
      required this.active});

  void _showPeriodPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(
              child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.lightGrey,
                      borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          const Text('Pilih Periode',
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ...[
            '7 Hari Terakhir',
            '30 Hari Terakhir',
            '3 Bulan Terakhir',
            'Tahun Ini'
          ].map((p) => ListTile(
                onTap: () => Navigator.pop(context),
                title: Text(p,
                    style:
                        const TextStyle(fontFamily: 'Poppins', fontSize: 14)),
                trailing: p == '30 Hari Terakhir'
                    ? const Icon(Icons.check_rounded,
                        color: AppColors.primary, size: 18)
                    : null,
                dense: true,
              )),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(9)),
            child: Center(
                child: Text('$index',
                    style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary)))),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.black)),
          Text('$busCount bus • $active aktif',
              style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  color: AppColors.textGrey)),
        ])),
        const Icon(Icons.chevron_right_rounded,
            size: 18, color: AppColors.textLight),
      ]),
    );
  }
}
