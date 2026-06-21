import 'package:flutter/material.dart';

/// Maps icon name strings (stored in SQLite) to Flutter IconData.
const Map<String, IconData> adjustmentIconMap = {
  // ── Stock / Inventory ──
  'inventory': Icons.inventory,
  'inventory_2': Icons.inventory_2,
  'storefront': Icons.storefront,
  'local_shipping': Icons.local_shipping,
  'warehouse': Icons.warehouse,
  'shopping_cart': Icons.shopping_cart,

  // ── Movement / Transfer ──
  'call_received': Icons.call_received,
  'call_made': Icons.call_made,
  'swap_horiz': Icons.swap_horiz,
  'move_to_inbox': Icons.move_to_inbox,
  'outbox': Icons.outbox,

  // ── Returns / Refunds ──
  'assignment_return': Icons.assignment_return,
  'undo': Icons.undo,
  'replay': Icons.replay,

  // ── Damage / Loss ──
  'broken_image': Icons.broken_image,
  'report_problem': Icons.report_problem,
  'warning': Icons.warning,
  'delete_forever': Icons.delete_forever,
  'remove_circle': Icons.remove_circle,

  // ── Time / Expiry ──
  'event_busy': Icons.event_busy,
  'timer_off': Icons.timer_off,
  'schedule': Icons.schedule,

  // ── Search / Correction ──
  'search': Icons.search,
  'build': Icons.build,
  'handyman': Icons.handyman,
  'tune': Icons.tune,

  // ── People ──
  'person_remove': Icons.person_remove,
  'person_add': Icons.person_add,
  'people': Icons.people,

  // ── Misc ──
  'card_giftcard': Icons.card_giftcard,
  'science': Icons.science,
  'help_outline': Icons.help_outline,
  'add_circle': Icons.add_circle,
  'edit': Icons.edit,
  'category': Icons.category,
  'label': Icons.label,
  'bookmark': Icons.bookmark,
  'star': Icons.star,
  'flag': Icons.flag,
  'info': Icons.info,
};

/// Returns IconData for a given icon name string. Falls back to Icons.edit.
IconData getReasonIcon(String? iconName) {
  if (iconName == null || iconName.isEmpty) return Icons.edit;
  return adjustmentIconMap[iconName] ?? Icons.edit;
}

/// Sorted list of all available icon names for the icon picker UI.
final List<String> availableIconNames = adjustmentIconMap.keys.toList()..sort();
