import 'package:flutter/material.dart';

/// ✍️ MASTER TYPOGRAPHY SYSTEM
class AppTypography {
  AppTypography._();

  // ============ FONTS ============
  static const String fontPoppins = 'Poppins';

  // ============ WEIGHTS ============
  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semiBold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;

  // ============ TEXT THEME ============
  static TextTheme get textTheme => const TextTheme(
    displayLarge: TextStyle(fontSize: 32.0, fontWeight: FontWeight.w700, fontFamily: fontPoppins),
    displayMedium: TextStyle(fontSize: 28.0, fontWeight: FontWeight.w700, fontFamily: fontPoppins),
    displaySmall: TextStyle(fontSize: 24.0, fontWeight: FontWeight.w600, fontFamily: fontPoppins),
    headlineLarge: TextStyle(fontSize: 22.0, fontWeight: FontWeight.w600, fontFamily: fontPoppins),
    headlineMedium: TextStyle(fontSize: 20.0, fontWeight: FontWeight.w600, fontFamily: fontPoppins),
    headlineSmall: TextStyle(fontSize: 18.0, fontWeight: FontWeight.w600, fontFamily: fontPoppins),
    titleLarge: TextStyle(fontSize: 18.0, fontWeight: FontWeight.w600, fontFamily: fontPoppins),
    titleMedium: TextStyle(fontSize: 16.0, fontWeight: FontWeight.w500, fontFamily: fontPoppins),
    titleSmall: TextStyle(fontSize: 14.0, fontWeight: FontWeight.w500, fontFamily: fontPoppins),
    bodyLarge: TextStyle(fontSize: 16.0, fontWeight: FontWeight.w400, fontFamily: fontPoppins),
    bodyMedium: TextStyle(fontSize: 14.0, fontWeight: FontWeight.w400, fontFamily: fontPoppins),
    bodySmall: TextStyle(fontSize: 12.0, fontWeight: FontWeight.w400, fontFamily: fontPoppins),
    labelLarge: TextStyle(fontSize: 14.0, fontWeight: FontWeight.w500, fontFamily: fontPoppins),
    labelMedium: TextStyle(fontSize: 12.0, fontWeight: FontWeight.w500, fontFamily: fontPoppins),
    labelSmall: TextStyle(fontSize: 10.0, fontWeight: FontWeight.w500, fontFamily: fontPoppins),
  );
}
