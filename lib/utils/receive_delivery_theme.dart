// lib/utils/receive_delivery_theme.dart
// Unified design system for Receive Delivery workflow
import 'package:flutter/material.dart';

class ReceiveDeliveryTheme {
  // Module colors
  static const purpleDraft    = Color(0xFF7C3AED);
  static const blueSubmitted  = Color(0xFF2563EB);
  static const greenApproved  = Color(0xFF16A34A);
  static const redRejected    = Color(0xFFEF4444);
  static const orangeReceive  = Color(0xFFF97316);

  // Light variants
  static const purpleLight = Color(0xFFEDE9FE);
  static const blueLight   = Color(0xFFDBEAFE);
  static const greenLight  = Color(0xFFDCFCE7);
  static const redLight    = Color(0xFFFEE2E2);
  static const orangeLight = Color(0xFFFED7AA);

  // Neutrals
  static const border     = Color(0xFFE5E7EB);
  static const rowOdd     = Color(0xFFF8F9FC);
  static const textDark   = Color(0xFF111827);
  static const textMuted  = Color(0xFF6B7280);
  static const textLabel  = Color(0xFF374151);
  static const headerBg   = Color(0xFFF9FAFB);
  static const cardBg     = Colors.white;
  static const scaffoldBg = Color(0xFFFAFAFA);

  // Text styles
  static const titleXLarge = TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 0.5);
  static const titleLarge  = TextStyle(fontSize: 18, fontWeight: FontWeight.bold);
  static const titleMedium = TextStyle(fontSize: 15, fontWeight: FontWeight.bold);
  static const titleSmall  = TextStyle(fontSize: 13, fontWeight: FontWeight.bold);
  static const bodyBold    = TextStyle(fontSize: 13, fontWeight: FontWeight.w600);
  static const bodyRegular = TextStyle(fontSize: 13, color: textDark);
  static const caption     = TextStyle(fontSize: 12, color: textMuted);
  static const labelBold   = TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: textLabel, letterSpacing: 0.6);

  // Border radius
  static const radiusSmall  = 6.0;
  static const radiusMedium = 10.0;
  static const radiusLarge  = 14.0;
  static const radiusXL     = 16.0;

  // Shadows
  static List<BoxShadow> cardShadow() => [
    BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2)),
  ];
  static List<BoxShadow> footerShadow() => [
    BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, -2)),
  ];

  // Snackbar helpers
  static void showSuccess(BuildContext context, String message, {Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle, color: Colors.white, size: 20),
        const SizedBox(width: 8),
        Expanded(child: Text(message)),
      ]),
      backgroundColor: color ?? greenApproved,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));
  }

  static void showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.error_outline, color: Colors.white, size: 20),
        const SizedBox(width: 8),
        Expanded(child: Text(message)),
      ]),
      backgroundColor: redRejected,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
    ));
  }

  static void showInfo(BuildContext context, String message, {Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.info_outline, color: Colors.white, size: 20),
        const SizedBox(width: 8),
        Expanded(child: Text(message)),
      ]),
      backgroundColor: color ?? blueSubmitted,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));
  }

  // Button styles
  static ButtonStyle primaryButton(Color color) => ElevatedButton.styleFrom(
    backgroundColor: color,
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(vertical: 12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMedium)),
    elevation: 0,
  );

  static ButtonStyle outlineButton(Color color) => OutlinedButton.styleFrom(
    foregroundColor: color,
    side: BorderSide(color: color.withValues(alpha: 0.5)),
    padding: const EdgeInsets.symmetric(vertical: 12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMedium)),
  );

  // Status color helper
  static Color statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'draft': return purpleDraft;
      case 'submitted': return blueSubmitted;
      case 'approved': return greenApproved;
      case 'rejected': return redRejected;
      default: return textMuted;
    }
  }

  static Color statusLightColor(String status) {
    switch (status.toLowerCase()) {
      case 'draft': return purpleLight;
      case 'submitted': return blueLight;
      case 'approved': return greenLight;
      case 'rejected': return redLight;
      default: return headerBg;
    }
  }
}
