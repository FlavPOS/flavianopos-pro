import 'dart:convert';
import '../models/settings_model.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/product_model.dart';

class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;

  const ProductCard({super.key, required this.product, required this.onTap});

  IconData _getCategoryIcon() {
    switch (product.category) {
      case 'Beverages': return Icons.local_drink;
      case 'Snacks': return Icons.cookie;
      case 'Rice & Grains': return Icons.rice_bowl;
      case 'Canned Goods': return Icons.inventory;
      case 'Personal Care': return Icons.soap;
      default: return Icons.shopping_bag;
    }
  }

  Color _getCategoryColor() {
    switch (product.category) {
      case 'Beverages': return Colors.blue;
      case 'Snacks': return Colors.orange;
      case 'Rice & Grains': return Colors.brown;
      case 'Canned Goods': return Colors.red;
      case 'Personal Care': return Colors.teal;
      default: return Colors.grey;
    }
  }

  Uint8List? _getImageBytes() {
    if (product.imagePath != null && product.imagePath!.isNotEmpty) {
      try {
        String b64 = product.imagePath!;
        if (b64.contains(',')) b64 = b64.split(',').last;
        if (b64.length > 200) {
          return Uint8List.fromList(base64Decode(b64));
        }
      } catch (_) {}
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final color = _getCategoryColor();
    final bool lowStock = product.stockQty <= product.reorderLevel;
    final imageBytes = _getImageBytes();
    final hasImage = imageBytes != null;

    return GestureDetector(
      onTap: (AppSettings.allowNegativeStock || product.stockQty > 0) ? onTap : null,
      child: Card(
        elevation: 2,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: lowStock ? const BorderSide(color: Colors.red, width: 1.5) : BorderSide.none,
        ),
        child: Opacity(
          opacity: (AppSettings.allowNegativeStock || product.stockQty > 0) ? 1.0 : 0.5,
          child: hasImage ? _buildImageCard(imageBytes, lowStock) : _buildIconCard(color, lowStock),
        ),
      ),
    );
  }

  Widget _buildImageCard(Uint8List imageBytes, bool lowStock) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Full background image
        Image.memory(imageBytes, fit: BoxFit.cover,
          errorBuilder: (c, e, s) => _buildIconCard(_getCategoryColor(), lowStock)),

        // Gradient overlay for text readability
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black.withAlpha(40),
                  Colors.black.withAlpha(180),
                  Colors.black.withAlpha(220),
                ],
                stops: const [0.0, 0.3, 0.5, 0.75, 1.0],
              ),
            ),
          ),
        ),

        // Low stock badge
        if (lowStock)
          Positioned(top: 4, left: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)),
              child: Text(
                product.stockQty == 0 ? 'OUT' : 'LOW',
                style: const TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold),
              ),
            ),
          ),

        // Text at bottom
        Positioned(left: 6, right: 6, bottom: 6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(product.name,
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold,
                  shadows: [Shadow(blurRadius: 4, color: Colors.black)]),
                maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(product.sellingPrice.toStringAsFixed(2),
                    style: const TextStyle(color: Colors.yellowAccent, fontSize: 13, fontWeight: FontWeight.bold,
                      shadows: [Shadow(blurRadius: 4, color: Colors.black)])),
                  AppSettings.showStockOnCard ? Text(product.stockQty > 0 ? '${product.stockQty} pcs' : 'OUT',
                    style: TextStyle(
                      color: lowStock ? Colors.redAccent[100] : Colors.white70,
                      fontSize: 9, fontWeight: FontWeight.w600,
                      shadows: const [Shadow(blurRadius: 4, color: Colors.black)])) : const SizedBox(),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIconCard(Color color, bool lowStock) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withAlpha(25), shape: BoxShape.circle),
            child: Icon(_getCategoryIcon(), color: color, size: 28),
          ),
          const SizedBox(height: 6),
          Text(product.name,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text(product.sellingPrice.toStringAsFixed(2),
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
          Text(
            AppSettings.showStockOnCard ? (product.stockQty > 0 ? 'Stock: ${product.stockQty}' : 'OUT OF STOCK') : '',
            style: TextStyle(fontSize: 9,
              color: lowStock ? Colors.red : Colors.grey[600],
              fontWeight: lowStock ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}
