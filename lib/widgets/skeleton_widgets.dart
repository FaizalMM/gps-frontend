import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

// ══════════════════════════════════════════════════════════════
// SHIMMER CORE ENGINE
// Pure Flutter shimmer — tidak perlu package tambahan.
// Menggunakan LinearGradient yang dianimasikan dengan AnimationController.
// ══════════════════════════════════════════════════════════════

class ShimmerEffect extends StatefulWidget {
  final Widget child;
  final Color baseColor;
  final Color highlightColor;
  final Duration duration;

  const ShimmerEffect({
    super.key,
    required this.child,
    this.baseColor = const Color(0xFFE8E8E8),
    this.highlightColor = const Color(0xFFF5F5F5),
    this.duration = const Duration(milliseconds: 1400),
  });

  @override
  State<ShimmerEffect> createState() => _ShimmerEffectState();
}

class _ShimmerEffectState extends State<ShimmerEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration)
      ..repeat();
    _anim = Tween<double>(begin: -2.0, end: 2.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                widget.baseColor,
                widget.highlightColor,
                widget.highlightColor,
                widget.baseColor,
              ],
              stops: const [0.0, 0.35, 0.65, 1.0],
              transform: _SlidingGradientTransform(_anim.value),
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  final double slidePercent;
  const _SlidingGradientTransform(this.slidePercent);

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * slidePercent, 0, 0);
  }
}

// ── Helper: kotak skeleton ─────────────────────────────────────
class _SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;
  final Color color;

  const _SkeletonBox({
    required this.width,
    required this.height,
    this.radius = 8,
    this.color = const Color(0xFFE0E0E0),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

// ── Helper: lingkaran skeleton ────────────────────────────────
class _SkeletonCircle extends StatelessWidget {
  final double size;
  final Color color;

  const _SkeletonCircle({
    required this.size,
    this.color = const Color(0xFFE0E0E0),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// SKELETON: BUS CARD (Siswa Dashboard — Home Tab)
// Menggantikan _LoadingBusCard
// ══════════════════════════════════════════════════════════════

class SkeletonBusCard extends StatelessWidget {
  const SkeletonBusCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerEffect(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: icon + teks
            const Row(
              children: [
                _SkeletonBox(width: 48, height: 48, radius: 14),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SkeletonBox(width: 140, height: 14, radius: 6),
                      SizedBox(height: 8),
                      _SkeletonBox(width: 100, height: 11, radius: 5),
                    ],
                  ),
                ),
                _SkeletonBox(width: 60, height: 28, radius: 8),
              ],
            ),
            const SizedBox(height: 16),
            // Info row: speed / ETA / status
            Row(
              children: [
                Expanded(child: _buildInfoChip()),
                const SizedBox(width: 10),
                Expanded(child: _buildInfoChip()),
                const SizedBox(width: 10),
                Expanded(child: _buildInfoChip()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(
        children: [
          _SkeletonBox(width: 30, height: 10, radius: 4),
          SizedBox(height: 6),
          _SkeletonBox(width: 45, height: 13, radius: 5),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// SKELETON: LIST ITEM (Admin: Siswa / Driver / Bus / Halte)
// ══════════════════════════════════════════════════════════════

class SkeletonListItem extends StatelessWidget {
  final bool showAvatar;
  final bool showTrailing;

  const SkeletonListItem({
    super.key,
    this.showAvatar = true,
    this.showTrailing = true,
  });

  @override
  Widget build(BuildContext context) {
    return ShimmerEffect(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Row(
          children: [
            if (showAvatar) ...[
              const _SkeletonCircle(size: 46),
              const SizedBox(width: 14),
            ],
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SkeletonBox(
                    width: double.infinity,
                    height: 13,
                    radius: 6,
                  ),
                  SizedBox(height: 8),
                  _SkeletonBox(width: 160, height: 11, radius: 5),
                  SizedBox(height: 6),
                  _SkeletonBox(width: 100, height: 10, radius: 4),
                ],
              ),
            ),
            if (showTrailing) ...[
              const SizedBox(width: 12),
              const _SkeletonBox(width: 60, height: 26, radius: 7),
            ],
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// SKELETON: LIST (beberapa item sekaligus)
// ══════════════════════════════════════════════════════════════

class SkeletonList extends StatelessWidget {
  final int itemCount;
  final bool showAvatar;

  const SkeletonList({
    super.key,
    this.itemCount = 5,
    this.showAvatar = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        itemCount,
        (i) => SkeletonListItem(showAvatar: showAvatar),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// SKELETON: STAT CARD (Admin Dashboard — stat cards)
// ══════════════════════════════════════════════════════════════

class SkeletonStatCard extends StatelessWidget {
  const SkeletonStatCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerEffect(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
            ),
          ],
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _SkeletonBox(width: 80, height: 11, radius: 5),
                _SkeletonBox(width: 36, height: 36, radius: 10),
              ],
            ),
            SizedBox(height: 12),
            _SkeletonBox(width: 60, height: 26, radius: 6),
            SizedBox(height: 6),
            _SkeletonBox(width: 90, height: 10, radius: 4),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// SKELETON: GRID STAT CARDS (2x2)
// ══════════════════════════════════════════════════════════════

class SkeletonStatGrid extends StatelessWidget {
  final int count;

  const SkeletonStatGrid({super.key, this.count = 4});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: List.generate(count, (_) => const SkeletonStatCard()),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// SKELETON: MAP AREA
// ══════════════════════════════════════════════════════════════

class SkeletonMapArea extends StatelessWidget {
  final double height;

  const SkeletonMapArea({super.key, this.height = 220});

  @override
  Widget build(BuildContext context) {
    return ShimmerEffect(
      baseColor: const Color(0xFFD8D8D8),
      highlightColor: const Color(0xFFEAEAEA),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFFD8D8D8),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(
          children: [
            // "Jalan" palsu
            Positioned(
              top: height * 0.4,
              left: 0,
              right: 0,
              child: Container(
                height: 6,
                color: const Color(0xFFC8C8C8),
              ),
            ),
            Positioned(
              top: 0,
              bottom: 0,
              left: 80,
              child: Container(
                width: 6,
                color: const Color(0xFFC8C8C8),
              ),
            ),
            // Dot lokasi bus
            Center(
              child: Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Color(0xFFC8C8C8),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            // Info card bawah
            Positioned(
              bottom: 12,
              left: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFCCCCCC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    _SkeletonCircle(size: 28, color: Color(0xFFBBBBBB)),
                    SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SkeletonBox(
                          width: 120,
                          height: 12,
                          radius: 5,
                          color: Color(0xFFBBBBBB),
                        ),
                        SizedBox(height: 5),
                        _SkeletonBox(
                          width: 80,
                          height: 10,
                          radius: 4,
                          color: Color(0xFFBBBBBB),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// SKELETON: INFO CARD (Bus info / driver info horizontal)
// ══════════════════════════════════════════════════════════════

class SkeletonInfoCard extends StatelessWidget {
  const SkeletonInfoCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerEffect(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
            ),
          ],
        ),
        child: const Row(
          children: [
            _SkeletonBox(width: 42, height: 42, radius: 12),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SkeletonBox(width: 100, height: 12, radius: 5),
                  SizedBox(height: 6),
                  _SkeletonBox(width: 160, height: 11, radius: 5),
                ],
              ),
            ),
            _SkeletonBox(width: 70, height: 28, radius: 8),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// SKELETON: PROFILE SECTION (header profil)
// ══════════════════════════════════════════════════════════════

class SkeletonProfileHeader extends StatelessWidget {
  const SkeletonProfileHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerEffect(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
            ),
          ],
        ),
        child: const Row(
          children: [
            _SkeletonCircle(size: 64),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SkeletonBox(width: 140, height: 15, radius: 6),
                  SizedBox(height: 8),
                  _SkeletonBox(width: 100, height: 11, radius: 5),
                  SizedBox(height: 6),
                  _SkeletonBox(width: 70, height: 22, radius: 6),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// SKELETON: ATTENDANCE BANNER (banner status absensi)
// ══════════════════════════════════════════════════════════════

class SkeletonAttendanceBanner extends StatelessWidget {
  const SkeletonAttendanceBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerEffect(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFE8E8E8),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Row(
          children: [
            _SkeletonBox(width: 36, height: 36, radius: 10),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SkeletonBox(width: 160, height: 12, radius: 5),
                  SizedBox(height: 6),
                  _SkeletonBox(width: 220, height: 10, radius: 4),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// SKELETON: DASHBOARD HOME (gabungan untuk home admin/driver/siswa)
// ══════════════════════════════════════════════════════════════

class SkeletonDashboardHome extends StatelessWidget {
  final bool showStatGrid;
  final bool showMapArea;
  final int listItemCount;

  const SkeletonDashboardHome({
    super.key,
    this.showStatGrid = true,
    this.showMapArea = false,
    this.listItemCount = 3,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting row
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: ShimmerEffect(
              child: Row(
                children: [
                  _SkeletonCircle(size: 44),
                  SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SkeletonBox(width: 100, height: 12, radius: 5),
                      SizedBox(height: 6),
                      _SkeletonBox(width: 160, height: 16, radius: 6),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Bus card / info card
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: SkeletonBusCard(),
          ),
          const SizedBox(height: 16),

          if (showMapArea) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: SkeletonMapArea(),
            ),
            const SizedBox(height: 16),
          ],

          if (showStatGrid) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: ShimmerEffect(
                child: _SkeletonBox(width: 120, height: 14, radius: 6),
              ),
            ),
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: SkeletonStatGrid(),
            ),
            const SizedBox(height: 16),
          ],

          // List items
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: ShimmerEffect(
              child: _SkeletonBox(width: 120, height: 14, radius: 6),
            ),
          ),
          const SizedBox(height: 12),
          SkeletonList(itemCount: listItemCount),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// SKELETON: DETAIL ROW (untuk detail item: Bus Detail, Route, dll)
// ══════════════════════════════════════════════════════════════

class SkeletonDetailRow extends StatelessWidget {
  const SkeletonDetailRow({super.key});

  @override
  Widget build(BuildContext context) {
    return const ShimmerEffect(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 10, horizontal: 20),
        child: Row(
          children: [
            _SkeletonBox(width: 80, height: 11, radius: 4),
            Spacer(),
            _SkeletonBox(width: 120, height: 11, radius: 4),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// SKELETON: BUS BOTTOM CARD (tracking tab — info card bawah)
// ══════════════════════════════════════════════════════════════

class SkeletonBottomCard extends StatelessWidget {
  const SkeletonBottomCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerEffect(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Row(
              children: [
                _SkeletonBox(width: 52, height: 52, radius: 14),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SkeletonBox(
                          width: double.infinity, height: 13, radius: 6),
                      SizedBox(height: 8),
                      _SkeletonBox(width: 130, height: 11, radius: 5),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8E8E8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0E0E0),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// SKELETON: CHART / ANALYTICS
// ══════════════════════════════════════════════════════════════

class SkeletonChart extends StatelessWidget {
  final double height;

  const SkeletonChart({super.key, this.height = 180});

  @override
  Widget build(BuildContext context) {
    return ShimmerEffect(
      child: Container(
        height: height,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SkeletonBox(width: 120, height: 13, radius: 6),
            const SizedBox(height: 4),
            const _SkeletonBox(width: 80, height: 10, radius: 4),
            const Spacer(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildBar(0.4),
                const SizedBox(width: 8),
                _buildBar(0.7),
                const SizedBox(width: 8),
                _buildBar(0.55),
                const SizedBox(width: 8),
                _buildBar(0.9),
                const SizedBox(width: 8),
                _buildBar(0.6),
                const SizedBox(width: 8),
                _buildBar(0.75),
                const SizedBox(width: 8),
                _buildBar(0.5),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBar(double fraction) {
    return Expanded(
      child: Container(
        height: (height - 80) * fraction,
        decoration: BoxDecoration(
          color: const Color(0xFFE0E0E0),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// SKELETON: SPLASH / FULL SCREEN LOADER
// Dipakai saat halaman pertama kali load sebelum ada data apapun
// ══════════════════════════════════════════════════════════════

class SkeletonFullPage extends StatelessWidget {
  const SkeletonFullPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      physics: NeverScrollableScrollPhysics(),
      child: Column(
        children: [
          SizedBox(height: 16),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: ShimmerEffect(
              child: Row(
                children: [
                  _SkeletonBox(width: 40, height: 40, radius: 10),
                  SizedBox(width: 10),
                  _SkeletonBox(width: 80, height: 14, radius: 6),
                  Spacer(),
                  _SkeletonBox(width: 40, height: 40, radius: 10),
                  SizedBox(width: 8),
                  _SkeletonBox(width: 40, height: 40, radius: 10),
                ],
              ),
            ),
          ),
          SizedBox(height: 8),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: SkeletonBusCard(),
          ),
          SizedBox(height: 14),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: SkeletonInfoCard(),
          ),
          SizedBox(height: 20),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: ShimmerEffect(
              child:
                  _SkeletonBox(width: double.infinity, height: 14, radius: 6),
            ),
          ),
          SizedBox(height: 12),
          SkeletonList(itemCount: 4),
        ],
      ),
    );
  }
}
