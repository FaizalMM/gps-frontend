import 'package:flutter/material.dart';

class AppColors {
  // ── Brand ──────────────────────────────────────────────
  static const Color primary = Color(0xFF7CBF2F); // hijau lime asli Mobitra
  static const Color primaryDark =
      Color(0xFF5A9A1A); // lebih gelap untuk gradient/hover
  static const Color primaryLight =
      Color(0xFFEAF5D0); // hijau muda lembut (bukan terlalu kuning)

  // ── Surface / Background ───────────────────────────────
  static const Color background =
      Color(0xFFF5F6FA); // abu netral bersih (bukan kekuningan)
  static const Color white = Color(0xFFFFFFFF);
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color surface2 = Color(0xFFF0F2F5); // input, chip bg

  // ── Text ───────────────────────────────────────────────
  static const Color black = Color(0xFF1A1A1A);
  static const Color textDark = Color(0xFF2D2D2D);
  static const Color textGrey = Color(0xFF888888);
  static const Color textLight = Color(0xFFAEAEB2);

  // ── Border / Divider ───────────────────────────────────
  static const Color lightGrey = Color(0xFFEEEEEE);
  static const Color divider = Color(0xFFF2F2F7);

  // ── Status ─────────────────────────────────────────────
  static const Color red = Color(0xFFE53E3E);
  static const Color orange = Color(0xFFFF8C00);
  static const Color pendingOrange = Color(0xFFF5A623);
  static const Color blue = Color(0xFF2196F3);
  static const Color purple = Color(0xFF9C27B0);

  // ── Nav ────────────────────────────────────────────────
  static const Color navBg = Color(0xFF2D2D2D);
}

class AppTextStyles {
  static const String fontFamily = 'Poppins';

  static const TextStyle heading1 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 28,
    fontWeight: FontWeight.w800,
    color: AppColors.black,
    height: 1.2,
  );
  static const TextStyle heading2 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AppColors.black,
  );
  static const TextStyle heading3 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: AppColors.black,
  );
  static const TextStyle subtitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textGrey,
  );
  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.black,
  );
  static const TextStyle bodyMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.black,
  );
  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textGrey,
  );
  static const TextStyle button = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.white,
  );
  static const TextStyle primaryAccent = TextStyle(
    fontFamily: fontFamily,
    fontSize: 28,
    fontWeight: FontWeight.w800,
    color: AppColors.primary,
    height: 1.2,
  );
}

ThemeData appTheme() {
  return ThemeData(
    fontFamily: 'Poppins',
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      surface: AppColors.background,
    ),
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      elevation: 0,
      iconTheme: IconThemeData(color: AppColors.black),
      titleTextStyle: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.black,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        elevation: 0,
        textStyle: AppTextStyles.button,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.white,
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    useMaterial3: true,
  );
}
