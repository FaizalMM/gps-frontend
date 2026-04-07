import 'package:flutter/material.dart';
import '../../models/models_api.dart';
import '../../services/app_data_service.dart';
import '../../services/domain_services.dart';
import '../../utils/app_theme.dart';

class AdminSiswaScreen extends StatefulWidget {
  final AppDataService dataService;
  const AdminSiswaScreen({super.key, required this.dataService});
  @override
  State<AdminSiswaScreen> createState() => _AdminSiswaScreenState();
}

class _AdminSiswaScreenState extends State<AdminSiswaScreen> {
  String _search = '';
  String _filter = 'Semua'; // Semua / Aktif / Nonaktif

  void _deleteUser(UserModel u) {
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: const Text('Hapus Siswa',
                  style: TextStyle(
                      fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
              content: Text('Hapus akun ${u.namaLengkap}?',
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 13)),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Batal',
                        style: TextStyle(
                            fontFamily: 'Poppins', color: AppColors.textGrey))),
                TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      widget.dataService.deleteUser(u.idStr).then((_) {
                        if (mounted) setState(() {});
                      });
                    },
                    child: const Text('Hapus',
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            color: AppColors.red,
                            fontWeight: FontWeight.w700))),
              ],
            ));
  }

  void _toggleStatus(UserModel u) async {
    final id = int.tryParse(u.idStr);
    if (id == null) return;
    final isActive = u.status == AccountStatus.active;
    bool ok;
    if (isActive) {
      ok = await StudentService().suspendStudent(id);
    } else {
      ok = await StudentService().unsuspendStudent(id);
    }
    if (!mounted) return;
    if (ok) {
      await widget.dataService.loadStudents();
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isActive
            ? '${u.namaLengkap} dinonaktifkan'
            : '${u.namaLengkap} diaktifkan kembali'),
        backgroundColor: isActive ? AppColors.orange : AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Manajemen Siswa',
            style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: AppColors.black)),
        centerTitle: true,
      ),
      body: Column(children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Container(
            height: 46,
            decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8)
                ]),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 13),
              decoration: const InputDecoration(
                hintText: 'Cari nama atau email...',
                hintStyle: TextStyle(
                    fontFamily: 'Poppins',
                    color: AppColors.textGrey,
                    fontSize: 13),
                prefixIcon: Icon(Icons.search_rounded,
                    color: AppColors.textGrey, size: 20),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 13),
              ),
            ),
          ),
        ),

        // Info banner - read only
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: AppColors.blue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.blue.withValues(alpha: 0.2)),
            ),
            child: const Row(children: [
              Icon(Icons.info_outline_rounded, color: AppColors.blue, size: 16),
              SizedBox(width: 8),
              Expanded(
                  child: Text(
                'Siswa mendaftar sendiri. Setujui akun di tab Persetujuan.',
                style: TextStyle(
                    fontFamily: 'Poppins', fontSize: 11, color: AppColors.blue),
              )),
            ]),
          ),
        ),
        const SizedBox(height: 2),

        // Filter chips
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Row(
              children: ['Semua', 'Aktif', 'Nonaktif'].map((label) {
            final sel = _filter == label;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => setState(() => _filter = label),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: sel ? AppColors.primary : AppColors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: sel ? AppColors.primary : AppColors.lightGrey),
                  ),
                  child: Text(label,
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                          color: sel ? Colors.white : AppColors.textGrey)),
                ),
              ),
            );
          }).toList()),
        ),

        Expanded(
          child: StreamBuilder<List<UserModel>>(
            stream: widget.dataService.usersStream,
            builder: (_, snap) {
              var list = (snap.data ?? widget.dataService.users)
                  .where((u) => u.role == UserRole.siswa)
                  .where((u) =>
                      u.namaLengkap
                          .toLowerCase()
                          .contains(_search.toLowerCase()) ||
                      u.email.toLowerCase().contains(_search.toLowerCase()))
                  .where((u) {
                if (_filter == 'Aktif') return u.status == AccountStatus.active;
                if (_filter == 'Nonaktif')
                  return u.status != AccountStatus.active;
                return true;
              }).toList();

              if (list.isEmpty)
                return Center(
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                      Icon(Icons.school_outlined,
                          size: 56,
                          color: AppColors.primary.withValues(alpha: 0.3)),
                      const SizedBox(height: 12),
                      const Text('Tidak ada siswa ditemukan',
                          style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 15,
                              color: AppColors.textGrey)),
                    ]));

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
                itemCount: list.length,
                itemBuilder: (_, i) => _SiswaCard(
                    siswa: list[i],
                    onDelete: () => _deleteUser(list[i]),
                    onToggle: () => _toggleStatus(list[i])),
              );
            },
          ),
        ),
      ]),
    );
  }
}

class _SiswaCard extends StatelessWidget {
  final UserModel siswa;
  final VoidCallback onDelete, onToggle;
  const _SiswaCard(
      {required this.siswa, required this.onDelete, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final isActive = siswa.status == AccountStatus.active;
    final isPending = siswa.status == AccountStatus.pending;
    final statusColor = isActive
        ? AppColors.primary
        : isPending
            ? AppColors.orange
            : AppColors.textGrey;
    final statusLabel = isActive
        ? 'Aktif'
        : isPending
            ? 'Pending'
            : 'Nonaktif';
    final statusBg = isActive
        ? AppColors.primaryLight
        : isPending
            ? AppColors.orange.withValues(alpha: 0.1)
            : AppColors.lightGrey;

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
        CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.primaryLight,
            child: Text(siswa.namaLengkap[0].toUpperCase(),
                style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                    fontSize: 18))),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(siswa.namaLengkap,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.black)),
          const SizedBox(height: 2),
          Text(siswa.email,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  color: AppColors.textGrey)),
          const SizedBox(height: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
                color: statusBg, borderRadius: BorderRadius.circular(6)),
            child: Text(statusLabel,
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: statusColor)),
          ),
        ])),
        const SizedBox(width: 8),
        // Tombol aksi sesuai status
        Column(mainAxisSize: MainAxisSize.min, children: [
          if (!isPending) ...[
            _ActionBtn(
              icon: isActive ? Icons.person_off_rounded : Icons.person_rounded,
              color: isActive ? AppColors.orange : AppColors.primary,
              bg: isActive
                  ? AppColors.orange.withValues(alpha: 0.1)
                  : AppColors.primaryLight,
              onTap: onToggle,
            ),
            const SizedBox(height: 6),
          ],
          _ActionBtn(
              icon: Icons.delete_rounded,
              color: AppColors.red,
              bg: AppColors.red.withValues(alpha: 0.08),
              onTap: onDelete),
        ]),
      ]),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color, bg;
  final VoidCallback onTap;
  const _ActionBtn(
      {required this.icon,
      required this.color,
      required this.bg,
      required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: bg, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18)),
      );
}
