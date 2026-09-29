import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Backgrounds
  static const background   = Color(0xFFF8FAFC);
  static const surface      = Color(0xFFFFFFFF);
  static const surface2     = Color(0xFFF1F5F9);
  static const surfaceCard  = Color(0xFFFFFFFF);

  // Brand
  static const primary      = Color(0xFF2563EB);
  static const primaryLight = Color(0xFFEFF6FF);
  static const primaryMid   = Color(0xFF3B82F6);

  // Semantic
  static const success      = Color(0xFF10B981);
  static const successLight = Color(0xFFECFDF5);
  static const warning      = Color(0xFFF59E0B);
  static const warningLight = Color(0xFFFFFBEB);
  static const danger       = Color(0xFFEF4444);
  static const dangerLight  = Color(0xFFFEF2F2);
  static const purple       = Color(0xFF7C3AED);
  static const purpleLight  = Color(0xFFF5F3FF);

  // Text
  static const text         = Color(0xFF0F172A);
  static const textSecond   = Color(0xFF334155);
  static const textMuted    = Color(0xFF64748B);
  static const textHint     = Color(0xFF94A3B8);

  // Borders & dividers
  static const border       = Color(0xFFE2E8F0);
  static const borderLight  = Color(0xFFF1F5F9);

  // Shadow
  static const shadow       = Color(0x0F000000);
  static const shadowMd     = Color(0x1A000000);
}

class AppTheme {
  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        surface: AppColors.surface,
        error: AppColors.danger,
        onPrimary: Colors.white,
        onSurface: AppColors.text,
      ),
      textTheme: GoogleFonts.interTextTheme(const TextTheme(
        displayLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.text),
        displayMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.text),
        titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.text),
        bodyLarge: TextStyle(fontSize: 16, color: AppColors.textSecond),
        bodyMedium: TextStyle(fontSize: 14, color: AppColors.textMuted),
        labelSmall: TextStyle(fontSize: 12, color: AppColors.textMuted),
      )),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
        titleTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.text,
        ),
        iconTheme: IconThemeData(color: AppColors.text),
        surfaceTintColor: Colors.transparent,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textHint,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontSize: 11),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
          textStyle: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.2),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 14),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1),
    );
  }
}

// Reusable card shadow
List<BoxShadow> get cardShadow => [
  const BoxShadow(color: AppColors.shadow, blurRadius: 8, offset: Offset(0, 2)),
  const BoxShadow(color: AppColors.shadow, blurRadius: 2, offset: Offset(0, 1)),
];

List<BoxShadow> get cardShadowMd => [
  const BoxShadow(color: AppColors.shadowMd, blurRadius: 16, offset: Offset(0, 4)),
  const BoxShadow(color: AppColors.shadow, blurRadius: 4, offset: Offset(0, 1)),
];
