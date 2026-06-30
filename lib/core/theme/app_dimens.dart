import 'package:flutter/material.dart';

/// 📏 MASTER DIMENSION SYSTEM
class AppDimens {
  AppDimens._();

  // ============ SPACING (4px base) ============
  static const double xxs = 4.0;
  static const double xs = 8.0;
  static const double sm = 12.0;
  static const double md = 16.0;
  static const double lg = 20.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
  static const double xxxl = 40.0;
  static const double huge = 48.0;

  // ============ EDGE INSETS ============
  static const EdgeInsets screenPadding = EdgeInsets.all(md);
  static const EdgeInsets cardPadding = EdgeInsets.all(sm);
  static const EdgeInsets listPadding = EdgeInsets.symmetric(horizontal: md, vertical: xs);
  static const EdgeInsets dialogPadding = EdgeInsets.all(xl);
  static const EdgeInsets inputPadding = EdgeInsets.symmetric(horizontal: md, vertical: sm);

  // ============ BORDER RADIUS ============
  static const double radiusXs = 4.0;
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 24.0;
  static const double radiusCircle = 100.0;

  // ============ ICON SIZES ============
  static const double iconXs = 16.0;
  static const double iconSm = 20.0;
  static const double iconMd = 24.0;
  static const double iconLg = 28.0;
  static const double iconXl = 32.0;

  // ============ BUTTON SIZES ============
  static const double buttonHeightSm = 36.0;
  static const double buttonHeightMd = 44.0;
  static const double buttonHeightLg = 52.0;

  // ============ CARD ============
  static const double cardElevation = 2.0;

  // ============ APP BAR ============
  static const double appBarHeight = 56.0;
  static const double bottomNavBarHeight = 60.0;

  // ============ AVATAR ============
  static const double avatarXs = 24.0;
  static const double avatarSm = 32.0;
  static const double avatarMd = 40.0;
  static const double avatarLg = 56.0;
  static const double avatarXl = 80.0;
}
