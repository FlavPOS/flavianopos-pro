import 'package:flutter/material.dart';
import 'adjustment_theme.dart';

/// Sticky bottom action bar with items count, total cost, and save button.
class BottomActionBar extends StatelessWidget {
  final int itemCount;
  final double totalCostImpact;
  final bool isEnabled;
  final VoidCallback? onSave;
  final String saveLabel;

  const BottomActionBar({
    super.key,
    required this.itemCount,
    required this.totalCostImpact,
    this.isEnabled = true,
    this.onSave,
    this.saveLabel = 'Save Adjustment',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: AdjTheme.s4,
        right: AdjTheme.s4,
        top: AdjTheme.s3,
        bottom: MediaQuery.of(context).padding.bottom + AdjTheme.s3,
      ),
      decoration: BoxDecoration(
        color: AdjTheme.card,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Left: Items count with icon
          _buildItemsBadge(),
          const SizedBox(width: AdjTheme.s3),

          // Middle: Total cost impact
          Expanded(
            child: _buildCostImpact(),
          ),

          const SizedBox(width: AdjTheme.s3),

          // Right: Save button
          _buildSaveButton(),
        ],
      ),
    );
  }

  Widget _buildItemsBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AdjTheme.s3,
        vertical: AdjTheme.s2,
      ),
      decoration: BoxDecoration(
        color: AdjTheme.bg,
        borderRadius: BorderRadius.circular(AdjTheme.radiusSmall),
      ),
      child: Row(
        children: [
          const Icon(Icons.list_alt_rounded,
              size: 18, color: AdjTheme.textSecondary),
          const SizedBox(width: 6),
          Text(
            '$itemCount Items',
            style: AdjTheme.body.copyWith(
              fontWeight: FontWeight.w600,
              color: AdjTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCostImpact() {
    final isPositive = totalCostImpact >= 0;
    final color = isPositive ? AdjTheme.success : AdjTheme.danger;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Total Cost Impact',
            style: AdjTheme.caption.copyWith(fontSize: 11)),
        const SizedBox(height: 2),
        Text(
          AdjTheme.peso(totalCostImpact),
          style: TextStyle(
            fontFamily: AdjTheme.fontFamily,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return ElevatedButton.icon(
      onPressed: isEnabled ? onSave : null,
      icon: const Icon(Icons.save_rounded, size: 20),
      label: Text(
        '$saveLabel ($itemCount)',
        style: const TextStyle(
          fontFamily: AdjTheme.fontFamily,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: AdjTheme.primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AdjTheme.textDisabled,
        disabledForegroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(
          horizontal: AdjTheme.s4,
          vertical: AdjTheme.s3,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AdjTheme.radiusCard),
        ),
      ),
    );
  }
}
