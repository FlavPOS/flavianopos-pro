import 'package:flutter/material.dart';
import 'adjustment_theme.dart';
import 'qty_stepper.dart';

/// Expanded product adjustment card with full details:
/// - Current/New/Adjustment blocks
/// - Large qty stepper [-] N [+]
/// - Reason dropdown
/// - Remarks textarea
/// - Cost impact
class ProductCardExpanded extends StatelessWidget {
  final String productName;
  final String sku;
  final String category;
  final String? imagePath;
  final int currentStock;
  final int newStock;
  final int quantity;
  final bool isAdd;
  final double costImpact;
  final String? selectedReason;
  final List<String> reasons;
  final TextEditingController remarksController;
  final ValueChanged<int> onQtyChanged;
  final ValueChanged<bool> onTypeChanged;
  final ValueChanged<String?> onReasonChanged;
  final VoidCallback? onClose;
  final VoidCallback? onCollapse;

  const ProductCardExpanded({
    super.key,
    required this.productName,
    required this.sku,
    required this.category,
    this.imagePath,
    required this.currentStock,
    required this.newStock,
    required this.quantity,
    required this.isAdd,
    required this.costImpact,
    required this.selectedReason,
    required this.reasons,
    required this.remarksController,
    required this.onQtyChanged,
    required this.onTypeChanged,
    required this.onReasonChanged,
    this.onClose,
    this.onCollapse,
  });

  @override
  Widget build(BuildContext context) {
    final accent = AdjTheme.accentColor(isAdd);
    final accentBg = AdjTheme.accentColorLight(isAdd);
    final String sign = isAdd ? '+' : '-';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: AdjTheme.s1),
      decoration: BoxDecoration(
        color: AdjTheme.card,
        borderRadius: BorderRadius.circular(AdjTheme.radiusCard),
        boxShadow: AdjTheme.shadowCard,
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 5, color: accent),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AdjTheme.s4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: AdjTheme.s4),
                    _buildStockBlocks(accent, accentBg, sign),
                    const SizedBox(height: AdjTheme.s4),
                    _buildTypeToggle(),
                    const SizedBox(height: AdjTheme.s4),
                    _buildStepper(accent),
                    const SizedBox(height: AdjTheme.s4),
                    _buildReasonDropdown(),
                    const SizedBox(height: AdjTheme.s3),
                    _buildRemarks(),
                    const SizedBox(height: AdjTheme.s4),
                    _buildCostImpact(accent),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Header: thumbnail + name + close ────────────────────
  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AdjTheme.bg,
            borderRadius: BorderRadius.circular(AdjTheme.radiusSmall),
          ),
          clipBehavior: Clip.antiAlias,
          child: (imagePath != null && imagePath!.isNotEmpty)
              ? Image.network(imagePath!, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(
                        Icons.inventory_2_rounded,
                        color: AdjTheme.textDisabled,
                      ))
              : const Icon(Icons.inventory_2_rounded,
                  color: AdjTheme.textDisabled),
        ),
        const SizedBox(width: AdjTheme.s3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(productName, style: AdjTheme.productName,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text('SKU: $sku • $category',
                  style: AdjTheme.caption,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close_rounded,
              color: AdjTheme.danger, size: 22),
          onPressed: onClose,
        ),
      ],
    );
  }

  // ─── Stock blocks: Current → New | Adjustment ────────────
  Widget _buildStockBlocks(Color accent, Color accentBg, String sign) {
    return Row(
      children: [
        Expanded(child: _stockBlock('Current Stock', '$currentStock', AdjTheme.textPrimary, AdjTheme.bg)),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: AdjTheme.s2),
          child: Icon(Icons.arrow_forward_rounded,
              color: AdjTheme.textSecondary),
        ),
        Expanded(child: _stockBlock('New Stock', '$newStock', accent, accentBg)),
        const SizedBox(width: AdjTheme.s3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text('Adjustment', style: AdjTheme.caption),
              const SizedBox(height: AdjTheme.s1),
              Text('$sign$quantity',
                  style: TextStyle(
                    fontFamily: AdjTheme.fontFamily,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: accent,
                  )),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stockBlock(String label, String value, Color textColor, Color bgColor) {
    return Column(
      children: [
        Text(label, style: AdjTheme.caption),
        const SizedBox(height: AdjTheme.s1),
        Container(
          padding: const EdgeInsets.symmetric(
              vertical: AdjTheme.s2, horizontal: AdjTheme.s3),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(AdjTheme.radiusSmall),
          ),
          child: Text(value,
              style: AdjTheme.numberLarge.copyWith(color: textColor)),
        ),
      ],
    );
  }

  // ─── Type toggle: Add / Deduct ───────────────────────────
  Widget _buildTypeToggle() {
    return Row(
      children: [
        Expanded(
          child: _typeButton(
            label: 'Add',
            icon: Icons.add_circle_outline_rounded,
            isSelected: isAdd,
            color: AdjTheme.success,
            onTap: () => onTypeChanged(true),
          ),
        ),
        const SizedBox(width: AdjTheme.s2),
        Expanded(
          child: _typeButton(
            label: 'Deduct',
            icon: Icons.remove_circle_outline_rounded,
            isSelected: !isAdd,
            color: AdjTheme.danger,
            onTap: () => onTypeChanged(false),
          ),
        ),
      ],
    );
  }

  Widget _typeButton({
    required String label,
    required IconData icon,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: isSelected ? color.withValues(alpha: 0.1) : AdjTheme.bg,
      borderRadius: BorderRadius.circular(AdjTheme.radiusSmall),
      child: InkWell(
        borderRadius: BorderRadius.circular(AdjTheme.radiusSmall),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AdjTheme.s3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AdjTheme.radiusSmall),
            border: Border.all(
              color: isSelected ? color : AdjTheme.divider,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18,
                  color: isSelected ? color : AdjTheme.textSecondary),
              const SizedBox(width: AdjTheme.s2),
              Text(label,
                  style: AdjTheme.label.copyWith(
                    color: isSelected ? color : AdjTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                  )),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Stepper ─────────────────────────────────────────────
  Widget _buildStepper(Color accent) {
    return Center(
      child: QtyStepper(
        value: quantity,
        onChanged: onQtyChanged,
        accentColor: accent,
      ),
    );
  }

  // ─── Reason dropdown ─────────────────────────────────────
  Widget _buildReasonDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Reason', style: AdjTheme.label),
        const SizedBox(height: AdjTheme.s1),
        Container(
          decoration: BoxDecoration(
            color: AdjTheme.bg,
            borderRadius: BorderRadius.circular(AdjTheme.radiusSmall),
            border: Border.all(color: AdjTheme.divider),
          ),
          padding: const EdgeInsets.symmetric(horizontal: AdjTheme.s3),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedReason,
              hint: Text('Select a reason', style: AdjTheme.body.copyWith(
                color: AdjTheme.textSecondary,
              )),
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down_rounded,
                  color: AdjTheme.textSecondary),
              onChanged: onReasonChanged,
              items: reasons.map((r) => DropdownMenuItem<String>(
                value: r,
                child: Text(r, style: AdjTheme.body),
              )).toList(),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Remarks ─────────────────────────────────────────────
  Widget _buildRemarks() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Remarks', style: AdjTheme.label),
            const SizedBox(width: 4),
            Text('(Optional)', style: AdjTheme.caption.copyWith(fontSize: 11)),
          ],
        ),
        const SizedBox(height: AdjTheme.s1),
        TextField(
          controller: remarksController,
          maxLines: 2,
          style: AdjTheme.body,
          decoration: InputDecoration(
            hintText: 'Add remark here...',
            hintStyle: AdjTheme.body.copyWith(color: AdjTheme.textSecondary),
            filled: true,
            fillColor: AdjTheme.bg,
            contentPadding: const EdgeInsets.all(AdjTheme.s3),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AdjTheme.radiusSmall),
              borderSide: const BorderSide(color: AdjTheme.divider),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AdjTheme.radiusSmall),
              borderSide: const BorderSide(color: AdjTheme.divider),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Cost impact ─────────────────────────────────────────
  Widget _buildCostImpact(Color accent) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text('Cost Impact', style: AdjTheme.label.copyWith(
              color: accent, fontWeight: FontWeight.w600,
            )),
            const SizedBox(width: 4),
            Icon(Icons.info_outline_rounded, size: 14, color: accent),
          ],
        ),
        Text(
          AdjTheme.peso(costImpact.abs() * (isAdd ? 1 : -1)),
          style: TextStyle(
            fontFamily: AdjTheme.fontFamily,
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: accent,
          ),
        ),
      ],
    );
  }
}
