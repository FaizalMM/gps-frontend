import 'package:flutter/material.dart';
import '../../models/models_api.dart';
import '../../services/app_data_service.dart';
import '../../services/domain_services.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';

class AdminDriverScreen extends StatefulWidget {
  final AppDataService dataService;
  const AdminDriverScreen({super.key, required this.dataService});

  @override
  State<AdminDriverScreen> createState() => _AdminDriverScreenState();
}

class _AdminDriverScreenState extends State<AdminDriverScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  String _sortBy = 'name';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Dialogs ──────────────────────────────────────────────
  void _showCreateDriverDialog() {
    final namaCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final noHpCtrl = TextEditingController();
    final alamatCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final nikCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
              key: formKey,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                        child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                                color: AppColors.lightGrey,
                                borderRadius: BorderRadius.circular(2)))),
                    const SizedBox(height: 20),
                    const Text('Tambah Akun Driver',
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 20,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 20),
                    AppTextField(
                        label: 'Nama Lengkap',
                        controller: namaCtrl,
                        validator: (v) =>
                            v!.isEmpty ? 'Nama tidak boleh kosong' : null),
                    const SizedBox(height: 14),
                    AppTextField(
                        label: 'Email',
                        controller: emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v!.isEmpty) return 'Email wajib diisi';
                          if (!v.contains('@'))
                            return 'Format email tidak valid';
                          return null;
                        }),
                    const SizedBox(height: 14),
                    AppTextField(
                        label: 'No. HP',
                        controller: noHpCtrl,
                        keyboardType: TextInputType.phone),
                    const SizedBox(height: 14),
                    AppTextField(
                        label: 'NIK (KTP)',
                        controller: nikCtrl,
                        validator: (v) =>
                            v!.isEmpty ? 'NIK wajib diisi' : null),
                    const SizedBox(height: 14),
                    AppTextField(label: 'Alamat', controller: alamatCtrl),
                    const SizedBox(height: 14),
                    AppTextField(
                        label: 'Password',
                        controller: passCtrl,
                        obscureText: true,
                        validator: (v) {
                          if (v!.isEmpty) return 'Password wajib diisi';
                          if (v.length < 6) return 'Min 6 karakter';
                          return null;
                        }),
                    const SizedBox(height: 24),
                    PrimaryButton(
                        text: 'Buat Akun Driver',
                        icon: Icons.person_add_rounded,
                        onPressed: () {
                          if (formKey.currentState!.validate()) {
                            DriverService()
                                .createDriver(
                              nama: namaCtrl.text.trim(),
                              email: emailCtrl.text.trim(),
                              password: passCtrl.text,
                              nik: nikCtrl.text.trim(),
                              noHp: noHpCtrl.text.trim(),
                              alamat: alamatCtrl.text.trim(),
                            )
                                .then((ok) async {
                              if (ok) await widget.dataService.loadDrivers();
                              Navigator.pop(ctx);
                              if (!context.mounted) return;
                              setState(() {});
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(SnackBar(
                                content: Text(ok
                                    ? 'Akun driver berhasil dibuat'
                                    : 'Gagal membuat akun driver'),
                                backgroundColor:
                                    ok ? AppColors.primary : AppColors.red,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ));
                            });
                          }
                        }),
                    const SizedBox(height: 8),
                  ])),
        ),
      ),
    );
  }

  void _showEditDriverDialog(UserModel driver) {
    final namaCtrl = TextEditingController(text: driver.namaLengkap);
    final noHpCtrl = TextEditingController(text: driver.noHp);
    final alamatCtrl = TextEditingController(text: driver.alamat);
    final nikCtrl = TextEditingController(text: driver.driverDetail?.nik ?? '');
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
              key: formKey,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                        child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                                color: AppColors.lightGrey,
                                borderRadius: BorderRadius.circular(2)))),
                    const SizedBox(height: 20),
                    const Text('Ubah Data Driver',
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 20,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 20),
                    AppTextField(
                        label: 'Nama Lengkap',
                        controller: namaCtrl,
                        validator: (v) =>
                            v!.isEmpty ? 'Nama tidak boleh kosong' : null),
                    const SizedBox(height: 14),
                    AppTextField(
                        label: 'No. HP',
                        controller: noHpCtrl,
                        keyboardType: TextInputType.phone),
                    const SizedBox(height: 14),
                    AppTextField(
                        label: 'NIK (KTP)',
                        controller: nikCtrl,
                        validator: (v) =>
                            v!.isEmpty ? 'NIK wajib diisi' : null),
                    const SizedBox(height: 14),
                    AppTextField(label: 'Alamat', controller: alamatCtrl),
                    const SizedBox(height: 24),
                    PrimaryButton(
                        text: 'Simpan Perubahan',
                        icon: Icons.save_rounded,
                        onPressed: () {
                          if (formKey.currentState!.validate()) {
                            final data = <String, dynamic>{
                              'name': namaCtrl.text.trim(),
                              'no_hp': noHpCtrl.text.trim(),
                              'alamat': alamatCtrl.text.trim(),
                            };
                            if (nikCtrl.text.trim().isNotEmpty) {
                              data['nik'] = nikCtrl.text.trim();
                            }
                            DriverService()
                                .updateDriver(driver.id, data)
                                .then((ok) async {
                              if (ok) await widget.dataService.loadDrivers();
                              Navigator.pop(ctx);
                              if (!context.mounted) return;
                              setState(() {});
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(SnackBar(
                                content: Text(ok
                                    ? 'Data driver diperbarui'
                                    : 'Gagal memperbarui driver'),
                                backgroundColor:
                                    ok ? AppColors.primary : AppColors.red,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ));
                            });
                          }
                        }),
                    const SizedBox(height: 8),
                  ])),
        ),
      ),
    );
  }

  void _showSortDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                  child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: AppColors.lightGrey,
                          borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              const Text('Urutkan',
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 18,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              _buildSortOption(ctx, 'Nama (A-Z)', 'name'),
              _buildSortOption(ctx, 'Status Aktif dulu', 'status'),
              const SizedBox(height: 8),
            ]),
      ),
    );
  }

  Widget _buildSortOption(BuildContext ctx, String label, String value) {
    final active = _sortBy == value;
    return GestureDetector(
      onTap: () {
        setState(() => _sortBy = value);
        Navigator.pop(ctx);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: active ? AppColors.primaryLight : AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: active ? AppColors.primary : AppColors.lightGrey,
              width: active ? 1.5 : 1),
        ),
        child: Row(children: [
          Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: active ? AppColors.primary : AppColors.black))),
          if (active)
            const Icon(Icons.check_rounded, color: AppColors.primary, size: 18),
        ]),
      ),
    );
  }

  void _deleteDriver(UserModel driver) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Driver',
            style:
                TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
        content: Text('Hapus ${driver.namaLengkap}?',
            style: const TextStyle(fontFamily: 'Poppins')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal',
                  style: TextStyle(
                      fontFamily: 'Poppins', color: AppColors.textGrey))),
          TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                widget.dataService
                    .deleteUser(driver.idStr)
                    .then((_) => setState(() {}));
              },
              child: const Text('Hapus',
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      color: AppColors.red,
                      fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  void _callDriver(UserModel driver) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
          'Menghubungi ${driver.namaLengkap}... (${driver.noHp.isEmpty ? "No. HP belum diisi" : driver.noHp})'),
      backgroundColor: AppColors.primary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // ── Build ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
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
        title: const Text('Driver',
            style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: AppColors.black)),
        centerTitle: false,
        actions: [
          IconButton(
              icon: const Icon(Icons.search_rounded,
                  color: AppColors.black, size: 22),
              onPressed: () => setState(
                  () => _searchQuery = _searchQuery.isEmpty ? ' ' : '')),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: TextButton.icon(
              onPressed: _showCreateDriverDialog,
              icon:
                  const Icon(Icons.add_rounded, size: 16, color: Colors.white),
              label: const Text('Tambah',
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white)),
              style: TextButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(color: AppColors.lightGrey, height: 0.5)),
      ),
      body: StreamBuilder<List<UserModel>>(
        stream: widget.dataService.usersStream,
        builder: (context, snapshot) {
          final allUsers = snapshot.data ?? widget.dataService.users;
          final driverList =
              allUsers.where((u) => u.role == UserRole.driver).toList();
          final active = driverList
              .where((d) => d.status == AccountStatus.active)
              .toList();
          final offline = driverList
              .where((d) => d.status != AccountStatus.active)
              .toList();

          List<UserModel> _applySearch(List<UserModel> list) {
            if (_searchQuery.trim().isEmpty) return list;
            return list
                .where((d) =>
                    d.namaLengkap
                        .toLowerCase()
                        .contains(_searchQuery.toLowerCase()) ||
                    d.email.toLowerCase().contains(_searchQuery.toLowerCase()))
                .toList();
          }

          List<UserModel> _applySort(List<UserModel> list) {
            final copy = List<UserModel>.from(list);
            if (_sortBy == 'name')
              copy.sort((a, b) => a.namaLengkap.compareTo(b.namaLengkap));
            return copy;
          }

          final activeFiltered = _applySort(_applySearch(active));
          final offlineFiltered = _applySort(_applySearch(offline));

          return Column(children: [
            // Search bar (animatable)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: _searchQuery.isNotEmpty ? 56 : 0,
              color: AppColors.white,
              child: _searchQuery.isNotEmpty
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: TextField(
                        autofocus: true,
                        onChanged: (v) => setState(() => _searchQuery = v),
                        style: const TextStyle(
                            fontFamily: 'Poppins', fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Cari nama atau email driver...',
                          hintStyle: const TextStyle(
                              fontFamily: 'Poppins',
                              color: AppColors.textGrey,
                              fontSize: 13),
                          prefixIcon: const Icon(Icons.search_rounded,
                              color: AppColors.textGrey, size: 20),
                          suffixIcon: IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18),
                              onPressed: () =>
                                  setState(() => _searchQuery = '')),
                          filled: true,
                          fillColor: AppColors.surface2,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none),
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    )
                  : null,
            ),

            // Tab bar
            Container(
              color: AppColors.white,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
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
                    borderSide:
                        BorderSide(color: AppColors.primary, width: 2.5)),
                tabs: [
                  Tab(
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Text('Aktif'),
                    const SizedBox(width: 6),
                    _TabBadge(count: active.length, color: AppColors.primary),
                  ])),
                  Tab(
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Text('Nonaktif'),
                    const SizedBox(width: 6),
                    _TabBadge(count: offline.length, color: AppColors.textGrey),
                  ])),
                ],
              ),
            ),

            // Sort info bar
            Container(
              color: AppColors.background,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
              child: Row(children: [
                Expanded(
                    child: Text('${driverList.length} driver terdaftar',
                        style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            color: AppColors.textGrey))),
                GestureDetector(
                  onTap: _showSortDialog,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.swap_vert_rounded,
                        size: 14, color: AppColors.textGrey),
                    const SizedBox(width: 3),
                    Text(_sortBy == 'name' ? 'Nama (A-Z)' : 'Status',
                        style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            color: AppColors.textGrey)),
                  ]),
                ),
              ]),
            ),

            // Tab views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _DriverList(
                      drivers: activeFiltered,
                      dataService: widget.dataService,
                      isActive: true,
                      onEdit: _showEditDriverDialog,
                      onDelete: _deleteDriver,
                      onCall: _callDriver),
                  _DriverList(
                      drivers: offlineFiltered,
                      dataService: widget.dataService,
                      isActive: false,
                      onEdit: _showEditDriverDialog,
                      onDelete: _deleteDriver,
                      onCall: _callDriver),
                ],
              ),
            ),
          ]);
        },
      ),
    );
  }
}

// ── Tab badge ───────────────────────────────────────────────
class _TabBadge extends StatelessWidget {
  final int count;
  final Color color;
  const _TabBadge({required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10)),
      child: Text('$count',
          style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color)),
    );
  }
}

// ── Driver list ─────────────────────────────────────────────
class _DriverList extends StatelessWidget {
  final List<UserModel> drivers;
  final AppDataService dataService;
  final bool isActive;
  final Function(UserModel) onEdit;
  final Function(UserModel) onDelete;
  final Function(UserModel) onCall;

  const _DriverList(
      {required this.drivers,
      required this.dataService,
      required this.isActive,
      required this.onEdit,
      required this.onDelete,
      required this.onCall});

  @override
  Widget build(BuildContext context) {
    if (drivers.isEmpty) {
      return Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.person_off_outlined,
            size: 56, color: AppColors.primary.withValues(alpha: 0.3)),
        const SizedBox(height: 12),
        Text(isActive ? 'Tidak ada driver aktif' : 'Tidak ada driver nonaktif',
            style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                color: AppColors.textGrey)),
      ]));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      itemCount: drivers.length,
      itemBuilder: (_, i) {
        final driver = drivers[i];
        final bus = dataService.getDriverBus(driver.idStr);
        return _DriverCard(
            driver: driver,
            bus: bus,
            onEdit: () => onEdit(driver),
            onDelete: () => onDelete(driver),
            onCall: () => onCall(driver));
      },
    );
  }
}

// ── Driver card — gaya referensi screenshot ─────────────────
class _DriverCard extends StatelessWidget {
  final UserModel driver;
  final dynamic bus; // BusModel?
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onCall;

  const _DriverCard(
      {required this.driver,
      this.bus,
      required this.onEdit,
      required this.onDelete,
      required this.onCall});

  @override
  Widget build(BuildContext context) {
    final isActive = driver.status == AccountStatus.active;
    final initials = driver.namaLengkap.isNotEmpty
        ? driver.namaLengkap[0].toUpperCase()
        : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ]),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        // FIX: Tap kartu -> detail sheet, bukan langsung edit
        onTap: () => _showDetailSheet(context),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            // Avatar
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: isActive ? AppColors.primaryLight : AppColors.surface2,
                shape: BoxShape.circle,
              ),
              child: Center(
                  child: Text(initials,
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                          color: isActive
                              ? AppColors.primary
                              : AppColors.textGrey))),
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(driver.namaLengkap,
                      style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.black)),
                  const SizedBox(height: 2),
                  Row(children: [
                    if (bus != null) ...[
                      Text('Bus ${bus.nama}',
                          style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              color: AppColors.textGrey)),
                      const Text(' • ',
                          style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              color: AppColors.textGrey)),
                    ],
                    Expanded(
                        child: Text(
                      bus != null ? 'Rute ${bus.rute}' : 'Belum ada bus',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: AppColors.textGrey),
                    )),
                  ]),
                  const SizedBox(height: 3),
                  Text('ID: #DRV-${driver.idStr.padLeft(4, '0')}',
                      style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          color: AppColors.textLight)),
                ])),

            // Badge + chevron
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isActive ? AppColors.primaryLight : AppColors.surface2,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(isActive ? 'AKTIF' : 'NONAKTIF',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color:
                            isActive ? AppColors.primary : AppColors.textGrey)),
              ),
              const SizedBox(height: 6),
              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: AppColors.textLight),
            ]),
          ]),
        ),
      ),
    );
  }

  // FIX: Detail sheet — lihat info driver dulu, tombol edit/hapus di dalam sheet
  void _showDetailSheet(BuildContext context) {
    final isActive = driver.status == AccountStatus.active;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: AppColors.lightGrey,
                  borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          Row(children: [
            Container(width: 52, height: 52,
              decoration: BoxDecoration(
                  color: isActive ? AppColors.primaryLight : AppColors.surface2,
                  shape: BoxShape.circle),
              child: Center(child: Text(
                driver.namaLengkap.isNotEmpty ? driver.namaLengkap[0].toUpperCase() : '?',
                style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700,
                    fontSize: 22, color: isActive ? AppColors.primary : AppColors.textGrey),
              )),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(driver.namaLengkap, style: const TextStyle(fontFamily: 'Poppins',
                  fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.black)),
              Text(driver.email, style: const TextStyle(fontFamily: 'Poppins',
                  fontSize: 12, color: AppColors.textGrey)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: isActive ? AppColors.primaryLight : AppColors.surface2,
                  borderRadius: BorderRadius.circular(8)),
              child: Text(isActive ? 'Aktif' : 'Nonaktif',
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600,
                      color: isActive ? AppColors.primary : AppColors.textGrey)),
            ),
          ]),
          const SizedBox(height: 20),
          const Divider(color: AppColors.lightGrey),
          const SizedBox(height: 12),
          _DetailRow(icon: Icons.badge_rounded, label: 'NIK',
              value: driver.driverDetail?.nik ?? '-'),
          const SizedBox(height: 10),
          _DetailRow(icon: Icons.phone_rounded, label: 'No. HP',
              value: driver.noHp.isNotEmpty ? driver.noHp : 'Belum diisi'),
          const SizedBox(height: 10),
          _DetailRow(icon: Icons.location_on_rounded, label: 'Alamat',
              value: driver.alamat.isNotEmpty ? driver.alamat : 'Belum diisi'),
          const SizedBox(height: 10),
          _DetailRow(icon: Icons.directions_bus_rounded, label: 'Bus',
              value: bus != null ? '${bus.nama} · ${bus.platNomor}' : 'Belum ditugaskan'),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: OutlinedButton.icon(
              icon: const Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.red),
              label: const Text('Hapus', style: TextStyle(fontFamily: 'Poppins',
                  fontSize: 13, color: AppColors.red)),
              onPressed: () { Navigator.pop(ctx); onDelete(); },
              style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.red),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12)),
            )),
            const SizedBox(width: 10),
            Expanded(child: ElevatedButton.icon(
              icon: const Icon(Icons.edit_rounded, size: 16, color: Colors.white),
              label: const Text('Edit Data', style: TextStyle(fontFamily: 'Poppins',
                  fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
              onPressed: () { Navigator.pop(ctx); onEdit(); },
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary, elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12)),
            )),
          ]),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon; final String label; final String value;
  const _DetailRow({required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
    Icon(icon, size: 16, color: AppColors.textGrey),
    const SizedBox(width: 10),
    SizedBox(width: 60, child: Text(label, style: const TextStyle(fontFamily: 'Poppins',
        fontSize: 12, color: AppColors.textGrey))),
    Expanded(child: Text(value, style: const TextStyle(fontFamily: 'Poppins',
        fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.black))),
  ]);
}
