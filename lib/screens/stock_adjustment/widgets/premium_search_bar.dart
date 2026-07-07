import 'package:flutter/material.dart';
import 'adjustment_theme.dart';

/// Rounded search bar with leading search icon + trailing filter icon.
class PremiumSearchBar extends StatelessWidget {
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onFilterTap;
  final String hintText;

  const PremiumSearchBar({
    super.key,
    this.controller,
    this.onChanged,
    this.onFilterTap,
    this.hintText = 'Search product or SKU',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AdjTheme.card,
        borderRadius: BorderRadius.circular(AdjTheme.radiusCard),
        boxShadow: AdjTheme.shadowCard,
      ),
      child: Row(
        children: [
          const SizedBox(width: AdjTheme.s4),
          Icon(Icons.search_rounded,
              color: AdjTheme.textSecondary, size: 22),
          const SizedBox(width: AdjTheme.s2),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: AdjTheme.body,
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: AdjTheme.body.copyWith(
                  color: AdjTheme.textSecondary,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: AdjTheme.s3,
                ),
              ),
            ),
          ),
          // Divider
          Container(
            height: 24,
            width: 1,
            color: AdjTheme.divider,
          ),
          // Filter button
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(AdjTheme.radiusCard),
              onTap: onFilterTap,
              child: Padding(
                padding: const EdgeInsets.all(AdjTheme.s3),
                child: Icon(Icons.tune_rounded,
                    color: AdjTheme.textSecondary, size: 22),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
