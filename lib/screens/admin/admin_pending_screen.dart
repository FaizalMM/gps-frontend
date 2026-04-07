import 'package:flutter/material.dart';
import '../../models/models_api.dart';
import '../../services/app_data_service.dart';
import '../../services/bus_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';

class AdminPendingScreen extends StatefulWidget {
  final AppDataService dataService;
  const AdminPendingScreen({super.key, required this.dataService});

  @override
  State<AdminPendingScreen> createState() => _AdminPendingScreenState();
}

class _AdminPendingScreenState extends State<AdminPendingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: 1);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Actions ──────────────────────────────────────────────
  void _approveUser(UserModel user) {
    final buses = widget.dataService.buses
        .where((b) => b.status == BusStatus.active)
        .toList();
    final haltes = widget.dataService.haltes;

    BusModel? selectedBus;
    HalteModel? selectedHalte;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) => Container(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
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
                  const SizedBox(height: 20),

                  // Header
                  Row(children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                          color: AppColors.primaryLight,
                          shape: BoxShape.circle),
                      child: Center(
                          child: Text(
                        user.namaLengkap.isNotEmpty
                            ? user.namaLengkap[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w700,
                            fontSize: 20,
                            color: AppColors.primary),
                      )),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text('Setujui ${user.namaLengkap}',
                              style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700)),
                          const Text('Tentukan bus dan halte penjemputan',
                              style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 12,
                                  color: AppColors.textGrey)),
                        ])),
                  ]),
                  const SizedBox(height: 24),

                  // Pilih Bus
                  const Text('Bus',
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.lightGrey)),
                    child: DropdownButtonHideUnderline(
                        child: DropdownButton<BusModel>(
                      isExpanded: true,
                      value: selectedBus,
                      hint: const Text('Pilih bus...',
                          style: TextStyle(
                              fontFamily: 'Poppins',
                              color: AppColors.textGrey)),
                      items: buses
                          .map((b) => DropdownMenuItem(
                                value: b,
                                child: Text(
                                    '${b.nama} — ${b.platNomor}${b.rute.isNotEmpty ? ' (${b.rute})' : ''}',
                                    style: const TextStyle(
                                        fontFamily: 'Poppins', fontSize: 13)),
                              ))
                          .toList(),
                      onChanged: (v) => setM(() => selectedBus = v),
                    )),
                  ),
                  const SizedBox(height: 16),

                  // Pilih Halte
                  const Text('Halte Penjemputan',
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.lightGrey)),
                    child: DropdownButtonHideUnderline(
                        child: DropdownButton<HalteModel>(
                      isExpanded: true,
                      value: selectedHalte,
                      hint: const Text('Pilih halte...',
                          style: TextStyle(
                              fontFamily: 'Poppins',
                              color: AppColors.textGrey)),
                      items: haltes
                          .map((h) => DropdownMenuItem(
                                value: h,
                                child: Text(h.namaHalte,
                                    style: const TextStyle(
                                        fontFamily: 'Poppins', fontSize: 13)),
                              ))
                          .toList(),
                      onChanged: (v) => setM(() => selectedHalte = v),
                    )),
                  ),
                  const SizedBox(height: 24),

                  // Tombol Setujui
                  PrimaryButton(
                    text: 'Setujui & Assign Bus',
                    icon: Icons.check_circle_rounded,
                    onPressed: () async {
                      if (selectedBus == null || selectedHalte == null) {
                        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                          content: Text('Pilih bus dan halte terlebih dahulu'),
                          behavior: SnackBarBehavior.floating,
                        ));
                        return;
                      }
                      Navigator.pop(ctx);

                      // 1. Approve siswa
                      await widget.dataService.updateUserStatus(
                        user.idStr,
                        AccountStatus.active,
                        studentDetailId: user.studentDetail?.id,
                      );

                      // 2. Assign ke bus
                      final studentId = user.studentDetail?.id ?? user.id;
                      final assigned = await BusService().assignStudentToBus(
                        selectedBus!.id,
                        studentId,
                        selectedHalte!.id,
                      );

                      if (!mounted) return;
                      setState(() {});
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(assigned
                            ? '${user.namaLengkap} disetujui & ditugaskan ke ${selectedBus!.nama}'
                            : '${user.namaLengkap} disetujui, tapi gagal assign bus — coba manual'),
                        backgroundColor:
                            assigned ? AppColors.primary : AppColors.orange,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ));
                    },
                  ),
                  const SizedBox(height: 8),

                  // Tombol Setujui tanpa bus (skip)
                  Center(
                      child: TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      widget.dataService
                          .updateUserStatus(
                        user.idStr,
                        AccountStatus.active,
                        studentDetailId: user.studentDetail?.id,
                      )
                          .then((_) {
                        if (!mounted) return;
                        setState(() {});
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(
                              '${user.namaLengkap} disetujui (belum ada bus)'),
                          backgroundColor: AppColors.primary,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ));
                      });
                    },
                    child: const Text('Setujui tanpa assign bus',
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13,
                            color: AppColors.textGrey)),
                  )),
                  const SizedBox(height: 8),
                ]),
          ),
        ),
      ),
    );
  }

  void _rejectUser(UserModel user) {
    widget.dataService
        .updateUserStatus(
      user.idStr,
      AccountStatus.rejected,
      studentDetailId: user.studentDetail?.id,
    )
        .then((_) {
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${user.namaLengkap} ditolak'),
        backgroundColor: AppColors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    });
  }

  void _deleteUser(UserModel user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Siswa',
            style:
                TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
        content: Text('Hapus ${user.namaLengkap}?',
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
                widget.dataService.deleteUser(user.idStr).then((_) {
                  if (mounted) setState(() {});
                });
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

  void _showCreateSiswaDialog() {
    final namaCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final noHpCtrl = TextEditingController();
    final alamatCtrl = TextEditingController();
    final passCtrl = TextEditingController();
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
                    const Text('Tambah Akun Siswa',
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
                        text: 'Buat Akun Siswa',
                        icon: Icons.person_add_rounded,
                        onPressed: () {
                          if (formKey.currentState!.validate()) {
                            if (widget.dataService
                                .emailExists(emailCtrl.text.trim())) {
                              ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                                  content: const Text('Email sudah terdaftar'),
                                  backgroundColor: AppColors.red,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(10))));
                              return;
                            }
                            widget.dataService.registerSiswa(
                                namaLengkap: namaCtrl.text.trim(),
                                email: emailCtrl.text.trim(),
                                noHp: noHpCtrl.text.trim(),
                                alamat: alamatCtrl.text.trim(),
                                password: passCtrl.text);
                            Navigator.pop(ctx);
                            setState(() {});
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content:
                                    const Text('Akun siswa berhasil dibuat'),
                                backgroundColor: AppColors.primary,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10))));
                          }
                        }),
                    const SizedBox(height: 8),
                  ])),
        ),
      ),
    );
  }

  void _showEditStudentDialog(UserModel student) {
    final namaCtrl = TextEditingController(text: student.namaLengkap);
    final noHpCtrl = TextEditingController(text: student.noHp);
    final alamatCtrl = TextEditingController(text: student.alamat);
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
                    const Text('Ubah Data Siswa',
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
                    AppTextField(label: 'Alamat', controller: alamatCtrl),
                    const SizedBox(height: 24),
                    PrimaryButton(
                        text: 'Simpan Perubahan',
                        icon: Icons.save_rounded,
                        onPressed: () {
                          if (formKey.currentState!.validate()) {
                            student.namaLengkap = namaCtrl.text.trim();
                            student.noHp = noHpCtrl.text.trim();
                            student.alamat = alamatCtrl.text.trim();
                            widget.dataService.updateUser(student);
                            Navigator.pop(ctx);
                            setState(() {});
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: const Text('Data siswa diperbarui'),
                                backgroundColor: AppColors.primary,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10))));
                          }
                        }),
                    const SizedBox(height: 8),
                  ])),
        ),
      ),
    );
  }

  void _showIdCard(UserModel student) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: EdgeInsets.zero,
        content: Container(
          width: 280,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(20)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Header kartu
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                  color: AppColors.primary,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(20))),
              child: Column(children: [
                Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle),
                    child: Center(
                        child: Text(student.namaLengkap[0].toUpperCase(),
                            style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)))),
                const SizedBox(height: 8),
                Text(student.namaLengkap,
                    style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
                Text('ID: #STU-${student.idStr.padLeft(8, '0')}',
                    style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        color: Colors.white70)),
              ]),
            ),
            // QR placeholder
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                        color: AppColors.surface2,
                        borderRadius: BorderRadius.circular(8)),
                    child: const Center(
                        child: Icon(Icons.qr_code_2_rounded,
                            size: 80, color: AppColors.textGrey))),
                const SizedBox(height: 12),
                Text(student.email,
                    style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        color: AppColors.textGrey),
                    textAlign: TextAlign.center),
                const SizedBox(height: 16),
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Tutup',
                        style: TextStyle(
                            fontFamily: 'Poppins', color: AppColors.primary))),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<UserModel>>(
      stream: widget.dataService.usersStream,
      builder: (context, snapshot) {
        final allUsers = snapshot.data ?? widget.dataService.users;
        final allStudents =
            allUsers.where((u) => u.role == UserRole.siswa).toList();
        final pendingStudents = allStudents
            .where((u) => u.status == AccountStatus.pending)
            .toList();
        final suspended = allStudents
            .where((u) => u.status == AccountStatus.rejected)
            .toList();
        final totalPending = pendingStudents.length;

        List<UserModel> _search(List<UserModel> list) {
          if (_searchQuery.isEmpty) return list;
          return list
              .where((u) => u.namaLengkap
                  .toLowerCase()
                  .contains(_searchQuery.toLowerCase()))
              .toList();
        }

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
            title: const Text('Persetujuan Siswa',
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: AppColors.black)),
            centerTitle: false,
            bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(color: AppColors.lightGrey, height: 0.5)),
          ),
          body: Column(children: [
            // Search
            Container(
              color: AppColors.white,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                    color: AppColors.surface2,
                    borderRadius: BorderRadius.circular(12)),
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: 'Cari siswa atau ID...',
                    hintStyle: TextStyle(
                        fontFamily: 'Poppins',
                        color: AppColors.textGrey,
                        fontSize: 13),
                    prefixIcon: Icon(Icons.search_rounded,
                        color: AppColors.textGrey, size: 18),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),

            // Tabs
            Container(
              color: AppColors.white,
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
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
                    const Text('Semua Siswa'),
                    const SizedBox(width: 6),
                    _TabBadge(
                        count: allStudents.length, color: AppColors.textGrey),
                  ])),
                  Tab(
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Text('Menunggu'),
                    if (totalPending > 0) ...[
                      const SizedBox(width: 6),
                      _TabBadge(count: totalPending, color: AppColors.orange)
                    ],
                  ])),
                  const Tab(text: 'Nonaktif'),
                ],
              ),
            ),

            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _StudentList(
                      students: _search(allStudents),
                      onApprove: _approveUser,
                      onReject: _rejectUser,
                      onDelete: _deleteUser,
                      onEdit: _showEditStudentDialog,
                      onIdCard: _showIdCard),
                  _StudentList(
                      students: _search(pendingStudents),
                      isPending: true,
                      onApprove: _approveUser,
                      onReject: _rejectUser,
                      onDelete: _deleteUser,
                      onEdit: _showEditStudentDialog,
                      onIdCard: _showIdCard),
                  _StudentList(
                      students: _search(suspended),
                      onApprove: _approveUser,
                      onReject: _rejectUser,
                      onDelete: _deleteUser,
                      onEdit: _showEditStudentDialog,
                      onIdCard: _showIdCard),
                ],
              ),
            ),
          ]),
        );
      },
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
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color)),
    );
  }
}

// ── Student list ────────────────────────────────────────────
class _StudentList extends StatelessWidget {
  final List<UserModel> students;
  final bool isPending;
  final Function(UserModel) onApprove;
  final Function(UserModel) onReject;
  final Function(UserModel) onDelete;
  final Function(UserModel) onEdit;
  final Function(UserModel) onIdCard;

  const _StudentList({
    required this.students,
    required this.onApprove,
    required this.onReject,
    required this.onDelete,
    required this.onEdit,
    required this.onIdCard,
    this.isPending = false,
  });

  @override
  Widget build(BuildContext context) {
    if (students.isEmpty) {
      return Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.people_outline,
            size: 56, color: AppColors.primary.withValues(alpha: 0.3)),
        const SizedBox(height: 12),
        const Text('Tidak ada data siswa',
            style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                color: AppColors.textGrey)),
      ]));
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
      itemCount: students.length + (isPending ? 1 : 0),
      itemBuilder: (_, i) {
        // Header "Tandai Semua" untuk tab pending
        if (isPending && i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(children: [
              const Expanded(
                  child: Text('Pendaftaran Baru',
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.black))),
              TextButton(
                onPressed: () {
                  for (final _ in students) {/* mark all read */}
                },
                child: const Text('Tandai Semua Dibaca',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        color: AppColors.primary)),
              ),
            ]),
          );
        }
        final student = students[isPending ? i - 1 : i];
        return _StudentCard(
            student: student,
            onApprove: () => onApprove(student),
            onReject: () => onReject(student),
            onDelete: () => onDelete(student),
            onEdit: () => onEdit(student),
            onIdCard: () => onIdCard(student));
      },
    );
  }
}

// ── Student card — gaya referensi screenshot ────────────────
class _StudentCard extends StatelessWidget {
  final UserModel student;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback onIdCard;

  const _StudentCard(
      {required this.student,
      required this.onApprove,
      required this.onReject,
      required this.onDelete,
      required this.onEdit,
      required this.onIdCard});

  @override
  Widget build(BuildContext context) {
    final isPending = student.status == AccountStatus.pending;
    final isActive = student.status == AccountStatus.active;
    final initials = student.namaLengkap.isNotEmpty
        ? student.namaLengkap[0].toUpperCase()
        : '?';

    Color badgeColor = isActive
        ? AppColors.primary
        : isPending
            ? AppColors.orange
            : AppColors.textGrey;
    Color badgeBg = isActive
        ? AppColors.primaryLight
        : isPending
            ? AppColors.orange.withValues(alpha: 0.12)
            : AppColors.surface2;
    String badgeText = isActive
        ? 'AKTIF'
        : isPending
            ? 'MENUNGGU'
            : 'NONAKTIF';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Row atas: avatar + info + badge
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                  color: isPending
                      ? AppColors.orange.withValues(alpha: 0.12)
                      : AppColors.primaryLight,
                  shape: BoxShape.circle),
              child: Center(
                  child: Text(initials,
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                          color: isPending
                              ? AppColors.orange
                              : AppColors.primary))),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(student.namaLengkap,
                      style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.black)),
                  Text('ID: #STU-${student.idStr.padLeft(8, '0')}',
                      style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 3),
                  if (student.noHp.isNotEmpty || student.alamat.isNotEmpty)
                    Row(children: [
                      const Icon(Icons.route_rounded,
                          size: 12, color: AppColors.textGrey),
                      const SizedBox(width: 3),
                      Expanded(
                          child: Text(
                              student.alamat.isNotEmpty ? student.alamat : '-',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 11,
                                  color: AppColors.textGrey))),
                    ]),
                ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: badgeBg, borderRadius: BorderRadius.circular(6)),
              child: Text(badgeText,
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: badgeColor)),
            ),
          ]),

          if (isPending) ...[
            const SizedBox(height: 12),
            // Baris Rute & Wali
            Row(children: [
              Expanded(
                  child: _InfoChip(
                      label: 'BUS / RUTE',
                      value: student.alamat.isNotEmpty
                          ? student.alamat
                          : 'Belum diisi')),
              const SizedBox(width: 8),
              Expanded(child: _InfoChip(label: 'EMAIL', value: student.email)),
            ]),
            const SizedBox(height: 10),
            // Action buttons — persis seperti referensi
            Row(children: [
              Expanded(
                child: GestureDetector(
                  onTap: onApprove,
                  child: Container(
                    height: 38,
                    decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(10)),
                    child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_rounded,
                              color: Colors.white, size: 16),
                          SizedBox(width: 6),
                          Text('Setujui',
                              style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white)),
                        ]),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // ID Card button
              GestureDetector(
                onTap: onIdCard,
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                      color: AppColors.surface2,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.lightGrey)),
                  child: const Row(children: [
                    Icon(Icons.badge_rounded,
                        size: 15, color: AppColors.textGrey),
                    SizedBox(width: 5),
                    Text('ID Card',
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.black)),
                  ]),
                ),
              ),
              const SizedBox(width: 8),
              // More menu
              GestureDetector(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.transparent,
                    builder: (ctx) => Container(
                      padding: const EdgeInsets.all(20),
                      decoration: const BoxDecoration(
                          color: AppColors.background,
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(20))),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Center(
                            child: Container(
                                width: 36,
                                height: 4,
                                decoration: BoxDecoration(
                                    color: AppColors.lightGrey,
                                    borderRadius: BorderRadius.circular(2)))),
                        const SizedBox(height: 16),
                        _MoreOption(
                            icon: Icons.edit_rounded,
                            label: 'Ubah Data',
                            onTap: () {
                              Navigator.pop(ctx);
                              onEdit();
                            }),
                        _MoreOption(
                            icon: Icons.close_rounded,
                            label: 'Tolak Pendaftaran',
                            color: AppColors.orange,
                            onTap: () {
                              Navigator.pop(ctx);
                              onReject();
                            }),
                        _MoreOption(
                            icon: Icons.delete_rounded,
                            label: 'Hapus Siswa',
                            color: AppColors.red,
                            onTap: () {
                              Navigator.pop(ctx);
                              onDelete();
                            }),
                      ]),
                    ),
                  );
                },
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                      color: AppColors.surface2,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.lightGrey)),
                  child: const Icon(Icons.more_vert_rounded,
                      size: 16, color: AppColors.textGrey),
                ),
              ),
            ]),
          ] else ...[
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              _ActionBtn(
                  icon: Icons.badge_rounded, label: 'ID Card', onTap: onIdCard),
              const SizedBox(width: 8),
              _ActionBtn(
                  icon: Icons.edit_rounded, label: 'Ubah', onTap: onEdit),
              const SizedBox(width: 8),
              _ActionBtn(
                  icon: Icons.delete_rounded,
                  label: 'Hapus',
                  onTap: onDelete,
                  color: AppColors.red,
                  bgColor: AppColors.red.withValues(alpha: 0.08)),
            ]),
          ],
        ]),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label, value;
  const _InfoChip({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          color: AppColors.surface2, borderRadius: BorderRadius.circular(8)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: AppColors.textGrey,
                letterSpacing: 0.5)),
        Text(value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.black)),
      ]),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  final Color bgColor;
  const _ActionBtn(
      {required this.icon,
      required this.label,
      required this.onTap,
      this.color = AppColors.textGrey,
      this.bgColor = AppColors.surface2});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.lightGrey)),
        child: Row(children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: color)),
        ]),
      ),
    );
  }
}

class _MoreOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  const _MoreOption(
      {required this.icon,
      required this.label,
      required this.onTap,
      this.color = AppColors.black});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      dense: true,
      leading: Icon(icon, color: color, size: 20),
      title: Text(label,
          style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: color)),
    );
  }
}
