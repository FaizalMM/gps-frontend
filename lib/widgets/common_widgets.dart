import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

// Mobitra App Bar
class MobitraAppBar extends StatelessWidget {
  final String? name;
  final VoidCallback? onNotification;
  final VoidCallback? onProfile;

  const MobitraAppBar({
    super.key,
    this.name,
    this.onNotification,
    this.onProfile,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Image.asset(
            'assets/images/logo.png',
            width: 40,
            height: 40,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 8),
          const Text(
            'Mobitra',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.black,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: onNotification ?? () {},
            icon: Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.notifications_outlined,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: onProfile ?? () {},
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.lightGrey,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.person_outline,
                color: AppColors.black,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Primary Button
class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool isOutline;
  final Color? color;

  const PrimaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isOutline = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: isOutline
          ? OutlinedButton(
              onPressed: isLoading ? null : onPressed,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: color ?? AppColors.primary, width: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _buildChild(color ?? AppColors.primary),
            )
          : ElevatedButton(
              onPressed: isLoading ? null : onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: color ?? AppColors.primary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _buildChild(AppColors.white),
            ),
    );
  }

  Widget _buildChild(Color textColor) {
    if (isLoading) {
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: textColor,
        ),
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, color: textColor, size: 20),
          const SizedBox(width: 8),
        ],
        Text(
          text,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ],
    );
  }
}

// Input Field
class AppTextField extends StatelessWidget {
  final String label;
  final TextEditingController? controller;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final Widget? suffixIcon;

  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.black,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          validator: validator,
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
          decoration: InputDecoration(
            suffixIcon: suffixIcon,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.lightGrey),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.lightGrey),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
            filled: true,
            fillColor: AppColors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }
}

// Map placeholder widget (since flutter_map requires additional setup)
class MapWidget extends StatelessWidget {
  final double height;
  final String busInfo;
  final String busSubInfo;

  const MapWidget({
    super.key,
    this.height = 200,
    required this.busInfo,
    required this.busSubInfo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFF2D3748),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Dark map background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF2D3748),
                  Color(0xFF1A202C),
                ],
              ),
            ),
          ),
          // Map grid lines
          CustomPaint(
            size: Size(double.infinity, height),
            painter: _MapGridPainter(),
          ),
          // Bus location indicator
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.9),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.4),
                        blurRadius: 20,
                        spreadRadius: 8,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.directions_bus,
                      color: Colors.white, size: 28),
                ),
              ],
            ),
          ),
          // Bus info card
          Positioned(
            bottom: 12,
            left: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.directions_bus,
                      color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          busInfo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.black,
                          ),
                        ),
                        Text(
                          busSubInfo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            color: AppColors.textGrey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1;

    // Grid lines (simulating map roads)
    for (double x = 0; x < size.width; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // Draw some diagonal "roads"
    final roadPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 3;
    canvas.drawLine(Offset(0, size.height * 0.3),
        Offset(size.width, size.height * 0.5), roadPaint);
    canvas.drawLine(Offset(0, size.height * 0.6),
        Offset(size.width, size.height * 0.4), roadPaint);
    canvas.drawLine(Offset(size.width * 0.3, 0),
        Offset(size.width * 0.4, size.height), roadPaint);
    canvas.drawLine(Offset(size.width * 0.7, 0),
        Offset(size.width * 0.6, size.height), roadPaint);

    // Location dots
    final dotPaint = Paint()
      ..color = Colors.blue.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width * 0.2, size.height * 0.3), 4, dotPaint);
    canvas.drawCircle(Offset(size.width * 0.7, size.height * 0.6), 4, dotPaint);
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.8), 4, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Status Badge
class StatusBadge extends StatelessWidget {
  final String text;
  final Color color;
  final Color bgColor;

  const StatusBadge({
    super.key,
    required this.text,
    required this.color,
    required this.bgColor,
  });

  factory StatusBadge.active() => const StatusBadge(
        text: 'Aktif',
        color: AppColors.primary,
        bgColor: AppColors.primaryLight,
      );

  factory StatusBadge.pending() => const StatusBadge(
        text: 'Pending',
        color: AppColors.pendingOrange,
        bgColor: Color(0xFFFEF3C7),
      );

  factory StatusBadge.inactive() => const StatusBadge(
        text: 'Nonaktif',
        color: AppColors.red,
        bgColor: Color(0xFFFEE2E2),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

// Bottom Nav Bar
class MobitraBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<BottomNavItem> items;

  const MobitraBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Container(
      height: 62 + bottomPad,
      decoration: BoxDecoration(
        color: AppColors.white,
        border: const Border(
            top: BorderSide(color: AppColors.lightGrey, width: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomPad),
        child: Row(
          children: List.generate(items.length, (index) {
            final item = items[index];
            final isSelected = index == currentIndex;
            return Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onTap(index),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                      padding: EdgeInsets.symmetric(
                          horizontal: isSelected ? 16 : 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary.withValues(alpha: 0.12)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        isSelected ? item.activeIcon : item.icon,
                        color:
                            isSelected ? AppColors.primary : AppColors.textGrey,
                        size: 22,
                      ),
                    ),
                    const SizedBox(height: 3),
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: isSelected ? 10.5 : 10,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w400,
                        color:
                            isSelected ? AppColors.primary : AppColors.textGrey,
                      ),
                      child: Text(item.label),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class BottomNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const BottomNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

// Shared BusPainter for use in other widgets
class _BusPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bodyPaint = Paint()
      ..color = const Color(0xFF7CBF2F)
      ..style = PaintingStyle.fill;
    final darkPaint = Paint()
      ..color = const Color(0xFF5A9A1A)
      ..style = PaintingStyle.fill;
    final windowPaint = Paint()
      ..color = const Color(0xFF87CEEB)
      ..style = PaintingStyle.fill;
    final redPaint = Paint()
      ..color = const Color(0xFFE53E3E)
      ..style = PaintingStyle.fill;

    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.05, size.height * 0.1, size.width * 0.9,
          size.height * 0.7),
      const Radius.circular(8),
    );
    canvas.drawRRect(bodyRect, bodyPaint);
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.05, size.height * 0.15, size.width * 0.9,
          size.height * 0.08),
      darkPaint,
    );

    final windowRect1 = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.1, size.height * 0.27, size.width * 0.35,
          size.height * 0.2),
      const Radius.circular(3),
    );
    canvas.drawRRect(windowRect1, windowPaint);

    final windowRect2 = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.55, size.height * 0.27, size.width * 0.35,
          size.height * 0.2),
      const Radius.circular(3),
    );
    canvas.drawRRect(windowRect2, windowPaint);

    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.05, size.height * 0.72, size.width * 0.9,
          size.height * 0.05),
      redPaint,
    );

    final wheelPaint = Paint()..color = const Color(0xFF2D2D2D);
    canvas.drawCircle(Offset(size.width * 0.25, size.height * 0.85),
        size.width * 0.12, wheelPaint);
    canvas.drawCircle(Offset(size.width * 0.75, size.height * 0.85),
        size.width * 0.12, wheelPaint);
    final rimPaint = Paint()..color = const Color(0xFFCCCCCC);
    canvas.drawCircle(Offset(size.width * 0.25, size.height * 0.85),
        size.width * 0.06, rimPaint);
    canvas.drawCircle(Offset(size.width * 0.75, size.height * 0.85),
        size.width * 0.06, rimPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
