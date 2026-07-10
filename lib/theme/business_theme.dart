import 'package:flutter/material.dart';

/// Business Design System for Desktop/Tablet
/// Applied when screen width >= 900px
/// Cellphone (< 900px) keeps original design
class BusinessTheme {
  // Breakpoint
  static const double desktopBreakpoint = 900;
  static const double contentMaxWidth = 1100;
  static const double dialogMaxWidth = 900;
  
  // ═══ BUSINESS PALETTE (Muted Professional) ═══
  static const Color primary = Color(0xFF475569);       // Slate 600
  static const Color primaryDark = Color(0xFF334155);   // Slate 700
  static const Color accent = Color(0xFF3B82F6);         // Blue 500
  static const Color success = Color(0xFF10B981);        // Emerald 500
  static const Color error = Color(0xFFEF4444);          // Red 500
  static const Color warning = Color(0xFFF59E0B);        // Amber 500
  
  static const Color background = Color(0xFFF8FAFC);     // Slate 50
  static const Color surface = Color(0xFFFFFFFF);        // White
  static const Color surfaceAlt = Color(0xFFF1F5F9);     // Slate 100
  
  static const Color textPrimary = Color(0xFF0F172A);    // Slate 900
  static const Color textSecondary = Color(0xFF64748B);  // Slate 500
  static const Color textMuted = Color(0xFF94A3B8);      // Slate 400
  
  static const Color border = Color(0xFFE2E8F0);         // Slate 200
  static const Color borderStrong = Color(0xFFCBD5E1);   // Slate 300
  
  // ═══ HELPER — Is Desktop/Tablet? ═══
  static bool isWideScreen(BuildContext context) {
    return MediaQuery.of(context).size.width >= desktopBreakpoint;
  }
  
  // ═══ RESPONSIVE WRAPPER ═══
  /// Wraps content: centers + max-width on desktop, full-width on mobile
  static Widget responsiveContainer({
    required BuildContext context,
    required Widget child,
    double? maxWidth,
    EdgeInsets? padding,
    Color? backgroundColor,
  }) {
    if (!isWideScreen(context)) {
      return child; // Mobile: no wrapping
    }
    
    // Desktop: center + constrain + business background
    return Container(
      color: backgroundColor ?? background,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth ?? contentMaxWidth),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(24),
            child: child,
          ),
        ),
      ),
    );
  }
  
  // ═══ BUSINESS CARD ═══
  static BoxDecoration cardDecoration({BuildContext? context}) {
    return BoxDecoration(
      color: surface,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: border, width: 1),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }
  
  // ═══ BUSINESS APP BAR ═══
  static AppBar businessAppBar({
    required BuildContext context,
    required String title,
    List<Widget>? actions,
    Widget? leading,
  }) {
    final wide = isWideScreen(context);
    return AppBar(
      backgroundColor: wide ? surface : null,
      foregroundColor: wide ? textPrimary : null,
      elevation: wide ? 0 : null,
      title: Text(
        title,
        style: TextStyle(
          fontSize: wide ? 18 : 16,
          fontWeight: FontWeight.w600,
          color: wide ? textPrimary : null,
        ),
      ),
      actions: actions,
      leading: leading,
      shape: wide 
          ? const Border(bottom: BorderSide(color: border, width: 1))
          : null,
    );
  }
  
  // ═══ BUSINESS BUTTON STYLES ═══
  static ButtonStyle primaryButton({BuildContext? context}) {
    return ElevatedButton.styleFrom(
      backgroundColor: primary,
      foregroundColor: Colors.white,
      elevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      textStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
  }
  
  static ButtonStyle secondaryButton({BuildContext? context}) {
    return OutlinedButton.styleFrom(
      foregroundColor: primary,
      side: const BorderSide(color: borderStrong, width: 1),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      textStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
  }
  
  static ButtonStyle accentButton({BuildContext? context}) {
    return ElevatedButton.styleFrom(
      backgroundColor: accent,
      foregroundColor: Colors.white,
      elevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      textStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
  }
  
  // ═══ BUSINESS TEXT STYLES ═══
  static TextStyle heading(BuildContext context) => TextStyle(
    fontSize: isWideScreen(context) ? 20 : 18,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    letterSpacing: -0.3,
  );
  
  static TextStyle subheading(BuildContext context) => TextStyle(
    fontSize: isWideScreen(context) ? 15 : 14,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );
  
  static TextStyle body(BuildContext context) => TextStyle(
    fontSize: isWideScreen(context) ? 14 : 13,
    color: textPrimary,
    height: 1.5,
  );
  
  static TextStyle caption(BuildContext context) => TextStyle(
    fontSize: 12,
    color: textSecondary,
    letterSpacing: 0.3,
  );
  
  static TextStyle label(BuildContext context) => TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: textSecondary,
    letterSpacing: 0.5,
  );
}
