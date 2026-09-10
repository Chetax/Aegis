// lib/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Backgrounds — layered darks give depth without going pure black
  static const Color bgDeep = Color(0xFF0A0E1A);
  static const Color bgSurface = Color(0xFF141824);
  static const Color bgRaised = Color(0xFF1C2333);
  static const Color border = Color(0xFF2A3244);

  // Accent — cyan reads as "security" without aggressive neon
  static const Color accent = Color(0xFF22D3EE);
  static const Color accentDim = Color(0xFF0891B2);

  // Text
  static const Color textPrimary = Color(0xFFF5F7FA);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);

  // Risk levels
  static const Color riskHigh = Color(0xFFEF4444);
  static const Color riskMedium = Color(0xFFF59E0B);
  static const Color riskLow = Color(0xFF10B981);

  static Color riskColor(String level) {
    switch (level.toLowerCase()) {
      case 'high':
        return riskHigh;
      case 'medium':
        return riskMedium;
      case 'low':
        return riskLow;
      default:
        return textSecondary;
    }
  }
}

class AppTheme {
  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.bgDeep,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.accent,
        secondary: AppColors.accent,
        surface: AppColors.bgSurface,
        onSurface: AppColors.textPrimary,
        onPrimary: AppColors.bgDeep,
      ),
      textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.bgSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.accent, width: 2),
        ),
        contentPadding: const EdgeInsets.all(20),
        hintStyle: GoogleFonts.inter(
          color: AppColors.textMuted,
          fontSize: 16,
        ),
      ),
    );
  }
}