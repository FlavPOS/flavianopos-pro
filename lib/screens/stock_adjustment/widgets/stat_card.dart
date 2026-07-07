import 'package:flutter/material.dart';
import 'adjustment_theme.dart';

/// A compact statistic card for the summary dashboard.
/// Used for: Items, Adds, Deducts, Cost Impact.
class StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color? iconColor;
  final Color? iconBgColor;

  const StatCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.iconColor,
    this.iconBgColor,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedIconColor = iconColor ?? AdjTheme.primary;
    final resolvedBgColor = iconBgColor ?? AdjTheme.primaryLight;

    return Container(
      padding: const EdgeInsets.all(AdjTheme.s3),
      decoration: BoxDecoration(
        color: AdjTheme.card,
        borderRadius: BorderRadius.circular(AdjTheme.radiusCard),
        boxShadow: AdjTheme.shadowCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon in colored circle
          Container(
            padding: const EdgeInsets.all(AdjTheme.s2),
            decoration: BoxDecoration(
              color: resolvedBgColor,
              borderRadius: BorderRadius.circular(AdjTheme.radiusSmall),
            ),
            child: Icon(icon, size: 20, color: resolvedIconColor),
          ),
          const SizedBox(height: AdjTheme.s2),
          // Big number
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: AdjTheme.numberLarge),
          ),
          // Label
          Text(label, style: AdjTheme.caption),
        ],
      ),
    );
  }
}

/// Row of 4 stat cards (Items / Adds / Deducts / Cost Impact)
class StatCardRow extends StatelessWidget {
  final int itemCount;
  final int addsCount;
  final int deductsCount;
  final double costImpact;

  const StatCardRow({
    super.key,
    required this.itemCount,
    required this.addsCount,
    required this.deductsCount,
    required this.costImpact,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: StatCard(
            icon: Icons.list_alt_rounded,
            value: '$itemCount',
            label: 'Items',
            iconColor: AdjTheme.primary,
            iconBgColor: AdjTheme.primaryLight,
          ),
        ),
        const SizedBox(width: AdjTheme.s2),
        Expanded(
          child: StatCard(
            icon: Icons.arrow_upward_rounded,
            value: '$addsCount',
            label: 'Adds',
            iconColor: AdjTheme.success,
            iconBgColor: AdjTheme.successLight,
          ),
        ),
        const SizedBox(width: AdjTheme.s2),
        Expanded(
          child: StatCard(
            icon: Icons.arrow_downward_rounded,
            value: '$deductsCount',
            label: 'Deducts',
            iconColor: AdjTheme.danger,
            iconBgColor: AdjTheme.dangerLight,
          ),
        ),
        const SizedBox(width: AdjTheme.s2),
        Expanded(
          child: StatCard(
            icon: Icons.trending_up_rounded,
            value: AdjTheme.peso(costImpact),
            label: 'Cost Impact',
            iconColor: AdjTheme.warning,
            iconBgColor: AdjTheme.warningLight,
          ),
        ),
      ],
    );
  }
}
