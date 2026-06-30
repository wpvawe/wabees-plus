import 'package:flutter/material.dart';

/// 🎨 MASTER COLOR SYSTEM - SINGLE SOURCE OF TRUTH
/// NO HARDCODED COLORS ANYWHERE IN THE APP
class AppColors {
  AppColors._();

  // ============ BRAND COLORS ============
  static const Color primary = Color(0xFF25D366);     // WhatsApp Green
  static const Color primaryLight = Color(0xFF4FE3A7);
  static const Color primaryDark = Color(0xFF075E54);

  // ============ SEMANTIC COLORS ============
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF34B7F1);
  static const Color premium = Color(0xFF9C27B0);

  // ============ NEUTRAL COLORS - LIGHT ============
  static const Color lightBg = Color(0xFFFFFFFF);
  static const Color lightSurface = Color(0xFFF8FAFC);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF475569);
  static const Color lightTextHint = Color(0xFF94A3B8);

  // ============ NEUTRAL COLORS - DARK ============
  static const Color darkBg = Color(0xFF0F172A);
  static const Color darkSurface = Color(0xFF1E293B);
  static const Color darkBorder = Color(0xFF334155);
  static const Color darkTextPrimary = Color(0xFFF1F5F9);
  static const Color darkTextSecondary = Color(0xFFCBD5E1);
  static const Color darkTextHint = Color(0xFF64748B);

  // ============ LIGHT COLOR SCHEME ============
  static ColorScheme get lightScheme => const ColorScheme(
    brightness: Brightness.light,
    primary: primary,
    onPrimary: Colors.white,
    primaryContainer: Color(0xFFDCF8C6),
    onPrimaryContainer: primaryDark,
    secondary: info,
    onSecondary: Colors.white,
    error: error,
    onError: Colors.white,
    surface: lightSurface,
    onSurface: lightTextPrimary,
    surfaceContainerHighest: Color(0xFFF1F5F9),
    onSurfaceVariant: lightTextSecondary,
    outline: lightBorder,
    outlineVariant: Color(0xFFCBD5E1),
    shadow: Colors.black12,
    scrim: Colors.black54,
    inverseSurface: darkSurface,
    onInverseSurface: darkTextPrimary,
    inversePrimary: primaryLight,
    tertiary: success,
    onTertiary: Colors.white,
    tertiaryContainer: Color(0xFFD1FAE5),
    onTertiaryContainer: Color(0xFF065F46),
  );

  // ============ DARK COLOR SCHEME ============
  static ColorScheme get darkScheme => const ColorScheme(
    brightness: Brightness.dark,
    primary: primaryLight,
    onPrimary: Colors.black,
    primaryContainer: Color(0xFF1A3A32),
    onPrimaryContainer: primaryLight,
    secondary: info,
    onSecondary: Colors.black,
    error: error,
    onError: Colors.black,
    surface: darkSurface,
    onSurface: darkTextPrimary,
    surfaceContainerHighest: Color(0xFF2D3A4A),
    onSurfaceVariant: darkTextSecondary,
    outline: darkBorder,
    outlineVariant: Color(0xFF4A5C6E),
    shadow: Colors.black26,
    scrim: Colors.black87,
    inverseSurface: lightSurface,
    onInverseSurface: lightTextPrimary,
    inversePrimary: primary,
    tertiary: success,
    onTertiary: Colors.black,
    tertiaryContainer: Color(0xFF1A3A2A),
    onTertiaryContainer: success,
  );
}
