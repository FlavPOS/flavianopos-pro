import 'package:flutter/material.dart';
import 'adjustment_theme.dart';

/// Compact collapsible product card (~100px tall).
/// Shows: thumbnail | name+SKU+category | qty badge | cost impact | chevron
/// Left accent bar: Green (add) or Red (deduct).
class ProductCardCollapsed extends StatelessWidget {
  final String productName;
  final String sku;
  final String category;
  final String? imagePath;
  final int currentStock;
  final int newStock;
  final int quantity;
  final bool isAdd;
  final double costImpact;
  final bool isExpanded;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const ProductCardCollapsed({
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
    this.isExpanded = false,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final accent = AdjTheme.accentColor(isAdd);
    final accentBg = AdjTheme.accentColorLight(isAdd);
    final sign = isAdd ? '+' : '-';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: AdjTheme.s1),
      decoration: BoxDecoration(
        color: AdjTheme.card,
        borderRadius: BorderRadius.circular(AdjTheme.radiusCard),
        boxShadow: AdjTheme.shadowCard,
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: IntrinsicHeight(
            child: Row(
              children: [
                Container(width: 5, color: accent),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(AdjTheme.s3),
                    child: Row(
                      children: [
                        _buildThumbnail(),
                        const SizedBox(width: AdjTheme.s3),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                productName,
                                style: AdjTheme.productName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: AdjTheme.s1),
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      'SKU: $sku',
                                      style: AdjTheme.caption,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: AdjTheme.s2),
                                  _buildCategoryBadge(),
                                ],
                              ),
                              const SizedBox(height: AdjTheme.s1),
                              Row(
                                children: [
                                  Text('OH: ', style: AdjTheme.caption),
                                  Text('$currentStock',
                                      style: AdjTheme.body.copyWith(
                                        fontWeight: FontWeight.w600,
                                      )),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.arrow_forward_rounded,
                                      size: 14,
                                      color: AdjTheme.textSecondary),
                                  const SizedBox(width: 4),
                                  Text('$newStock',
                                      style: AdjTheme.body.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: accent,
                                      )),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AdjTheme.s2),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AdjTheme.s3,
                                vertical: AdjTheme.s1,
                              ),
                              decoration: BoxDecoration(
                                color: accentBg,
                                borderRadius: BorderRadius.circular(
                                    AdjTheme.radiusSmall),
                              ),
                              child: Text(
                                '$sign$quantity',
                                style: TextStyle(
                                  fontFamily: AdjTheme.fontFamily,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: accent,
                                ),
                              ),
                            ),
                            const SizedBox(height: AdjTheme.s1),
                            Text(
                              'Cost Impact',
                              style: AdjTheme.caption.copyWith(fontSize: 10),
                            ),
                            Text(
                              AdjTheme.peso(costImpact.abs() * (isAdd ? 1 : -1)),
                              style: AdjTheme.label.copyWith(
                                color: accent,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        AnimatedRotation(
                          turns: isExpanded ? 0.25 : 0,
                          duration: AdjTheme.animNormal,
                          child: const Icon(
                            Icons.chevron_right_rounded,
                            color: AdjTheme.textSecondary,
                            size: 22,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AdjTheme.bg,
        borderRadius: BorderRadius.circular(AdjTheme.radiusSmall),
      ),
      clipBehavior: Clip.antiAlias,
      child: (imagePath != null && imagePath!.isNotEmpty)
          ? Image.network(
              imagePath!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _placeholderIcon(),
            )
          : _placeholderIcon(),
    );
  }

  Widget _placeholderIcon() {
    return const Icon(
      Icons.inventory_2_rounded,
      color: AdjTheme.textDisabled,
      size: 24,
    );
  }

  Widget _buildCategoryBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AdjTheme.primaryLight,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        category,
        style: const TextStyle(
          fontFamily: AdjTheme.fontFamily,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: AdjTheme.primary,
        ),
      ),
    );
  }
}
