import 'package:flutter/material.dart';

/// ═══════════════════════════════════════════════════════════════
/// FLAV POS — Stock Adjustment v2 Design System
/// Inspired by SAP Fiori, Oracle Fusion, Zoho Inventory
/// ═══════════════════════════════════════════════════════════════
class AdjTheme {
  AdjTheme._();

  // ─── COLORS ─────────────────────────────────────────────
  static const Color primary       = Color(0xFF1565C0);  // Blue
  static const Color primaryLight  = Color(0xFFE3F2FD);  // Blue tint
  static const Color success       = Color(0xFF22C55E);  // Green
  static const Color successLight  = Color(0xFFDCFCE7);  // Green tint
  static const Color danger        = Color(0xFFEF4444);  // Red
  static const Color dangerLight   = Color(0xFFFEE2E2);  // Red tint
  static const Color warning       = Color(0xFFF59E0B);  // Amber
  static const Color warningLight  = Color(0xFFFEF3C7);  // Amber tint

  // ─── BACKGROUNDS ─────────────────────────────────────────
  static const Color bg            = Color(0xFFF4F6F8);  // Page background
  static const Color card          = Color(0xFFFFFFFF);  // Card white
  static const Color divider       = Color(0xFFE5E7EB);  // Subtle divider

  // ─── TEXT ────────────────────────────────────────────────
  static const Color textPrimary   = Color(0xFF111827);  // Body text
  static const Color textSecondary = Color(0xFF6B7280);  // Secondary
  static const Color textDisabled  = Color(0xFF9CA3AF);  // Disabled

  // ─── SPACING (8px grid) ──────────────────────────────────
  static const double s1 = 4;
  static const double s2 = 8;
  static const double s3 = 12;
  static const double s4 = 16;
  static const double s5 = 20;
  static const double s6 = 24;
  static const double s8 = 32;
  static const double s10 = 40;

  // ─── RADIUS ──────────────────────────────────────────────
  static const double radiusSmall  = 8;
  static const double radiusCard   = 16;
  static const double radiusLarge  = 24;

  // ─── SHADOWS ─────────────────────────────────────────────
  static final List<BoxShadow> shadowCard = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  static final List<BoxShadow> shadowElevated = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.08),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  static final List<BoxShadow> shadowFab = [
    BoxShadow(
      color: primary.withValues(alpha: 0.3),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  // ─── TYPOGRAPHY (Inter font family) ──────────────────────
  static const String fontFamily = 'Inter';

  static const TextStyle titleScreen = TextStyle(
    fontFamily: fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.bold,
    color: textPrimary,
    height: 1.2,
  );

  static const TextStyle titleCard = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    height: 1.3,
  );

  static const TextStyle productName = TextStyle(
    fontFamily: fontFamily,
    fontSize: 17,
    fontWeight: FontWeight.bold,
    color: textPrimary,
    height: 1.3,
  );

  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: textPrimary,
    height: 1.4,
  );

  static const TextStyle label = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: textSecondary,
    height: 1.3,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: textSecondary,
    height: 1.3,
  );

  static const TextStyle numberLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.bold,
    color: textPrimary,
    height: 1.2,
  );

  static const TextStyle numberXLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: textPrimary,
    height: 1.2,
  );

  // ─── ANIMATIONS ──────────────────────────────────────────
  static const Duration animFast   = Duration(milliseconds: 150);
  static const Duration animNormal = Duration(milliseconds: 200);
  static const Duration animSlow   = Duration(milliseconds: 300);

  static const Curve curveDefault = Curves.easeInOut;
  static const Curve curveEmphasized = Curves.easeOutCubic;

  // ─── HELPERS ─────────────────────────────────────────────
  /// Returns Green for add, Red for deduct
  static Color accentColor(bool isAdd) => isAdd ? success : danger;
  static Color accentColorLight(bool isAdd) => isAdd ? successLight : dangerLight;

  /// Format currency in Philippine Peso
  static String peso(double amount) {
    final sign = amount < 0 ? '-' : '';
    final absAmount = amount.abs();
    return '$sign\u20B1${absAmount.toStringAsFixed(2)}';
  }
}
