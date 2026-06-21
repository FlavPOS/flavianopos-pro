// lib/utils/responsive.dart
// FlavianoPOS - PRO: Universal Responsive Helper
// Used by Expenses Module + future modules
// Supports: Small Phone, Phone, Tablet, Web

import 'package:flutter/material.dart';

class Responsive {
  // ═══════════════════════════════════════════
  // CORE MEASUREMENTS
  // ═══════════════════════════════════════════
  static double w(BuildContext c) => MediaQuery.of(c).size.width;
  static double h(BuildContext c) => MediaQuery.of(c).size.height;

  // ═══════════════════════════════════════════
  // BREAKPOINTS
  // ═══════════════════════════════════════════
  static bool isPhoneSm(BuildContext c) => w(c) < 360;
  static bool isPhone(BuildContext c) => w(c) < 600;
  static bool isTablet(BuildContext c) => w(c) >= 600 && w(c) < 1024;
  static bool isWeb(BuildContext c) => w(c) >= 1024;

  // ═══════════════════════════════════════════
  // ADAPTIVE VALUES
  // ═══════════════════════════════════════════
  static int gridCols(BuildContext c) =>
      isPhoneSm(c) ? 2 : isPhone(c) ? 2 : isTablet(c) ? 3 : 4;

  static int reportCols(BuildContext c) =>
      isPhone(c) ? 1 : isTablet(c) ? 2 : 3;

  static double pad(BuildContext c) =>
      isPhoneSm(c) ? 8 : isPhone(c) ? 12 : isTablet(c) ? 16 : 24;

  static double titleSz(BuildContext c) =>
      isPhone(c) ? 16 : isTablet(c) ? 18 : 22;

  static double bodySz(BuildContext c) =>
      isPhone(c) ? 13 : isTablet(c) ? 14 : 15;

  static double captionSz(BuildContext c) =>
      isPhone(c) ? 11 : isTablet(c) ? 12 : 13;

  static double cardR(BuildContext c) => isPhone(c) ? 12 : 16;

  static double iconSz(BuildContext c) =>
      isPhone(c) ? 22 : isTablet(c) ? 26 : 30;

  static double bigIconSz(BuildContext c) =>
      isPhone(c) ? 32 : isTablet(c) ? 40 : 48;

  static double touchTarget(BuildContext c) =>
      isPhone(c) ? 48 : 52; // Min Material guideline

  static double maxContentWidth(BuildContext c) =>
      isWeb(c) ? (w(c) > 1600 ? 1600 : (w(c) > 1280 ? w(c) * 0.92 : double.infinity)) : double.infinity;

  // ═══════════════════════════════════════════
  // ADAPTIVE WIDGET HELPERS
  // ═══════════════════════════════════════════

  /// Wrap content for web layout (max 1200dp centered)
  static Widget centered({
    required BuildContext context,
    required Widget child,
  }) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxContentWidth(context)),
        child: child,
      ),
    );
  }

  /// Show form: bottom sheet on phone, dialog on tablet/web
  static Future<T?> showAdaptiveForm<T>({
    required BuildContext context,
    required Widget child,
    String? title,
  }) {
    if (isPhone(context)) {
      return showModalBottomSheet<T>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: child,
        ),
      );
    } else {
      return showDialog<T>(
        context: context,
        builder: (_) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: child,
          ),
        ),
      );
    }
  }

  /// Get status color from string
  static Color statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green.shade600;
      case 'rejected':
        return Colors.red.shade600;
      case 'pending':
        return Colors.amber.shade700;
      case 'returned':
        return Colors.orange.shade600;
      case 'draft':
        return Colors.blue.shade400;
      case 'paid':
        return Colors.purple.shade400;
      default:
        return Colors.grey;
    }
  }

  /// Get status icon from string
  static IconData statusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      case 'pending':
        return Icons.hourglass_top;
      case 'returned':
        return Icons.replay;
      case 'draft':
        return Icons.edit_note;
      case 'paid':
        return Icons.attach_money;
      default:
        return Icons.help_outline;
    }
  }
}

// ═══════════════════════════════════════════════
// THEME CONSTANTS — FlavianoPOS - PRO Purple
// ═══════════════════════════════════════════════
class AppColors {
  static const Color primary = Color(0xFF7B1FA2);
  static const Color primaryLight = Color(0xFFAB47BC);
  static const Color primaryDark = Color(0xFF4A148C);
  static const Color background = Color(0xFFFAFAFA);
  static const Color cardBg = Colors.white;
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color divider = Color(0xFFE0E0E0);
}
