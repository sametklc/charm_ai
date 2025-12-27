import 'package:flutter/material.dart';

/// App Color Palette
class AppColors {
  AppColors._();

  // Primary Colors - A sophisticated violet/purple
  static const Color primary = Color(0xFF7C3AED);
  static const Color primaryLight = Color(0xFFA78BFA);
  static const Color primaryDark = Color(0xFF5B21B6);

  // Secondary Colors - Warm coral accent
  static const Color secondary = Color(0xFFF472B6);
  static const Color secondaryLight = Color(0xFFFBCFE8);
  static const Color secondaryDark = Color(0xFFDB2777);

  // Neutral Colors
  static const Color background = Color(0xFFFAFAFA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF3F4F6);

  // Dark Theme Colors
  static const Color backgroundDark = Color(0xFF0F0F23);
  static const Color surfaceDark = Color(0xFF1A1A2E);
  static const Color surfaceVariantDark = Color(0xFF16213E);

  // Text Colors
  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9CA3AF);

  static const Color textPrimaryDark = Color(0xFFF9FAFB);
  static const Color textSecondaryDark = Color(0xFFD1D5DB);
  static const Color textTertiaryDark = Color(0xFF9CA3AF);

  // Semantic Colors
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Chat Colors
  static const Color userBubble = Color(0xFF7C3AED);
  static const Color aiBubble = Color(0xFFF3F4F6);
  static const Color aiBubbleDark = Color(0xFF1E293B);

  // Gradient Colors
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkGradient = LinearGradient(
    colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}



