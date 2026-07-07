import 'package:flutter/material.dart';
import 'product_model.dart';

class AdjustmentItem {
  final Product product;
  int currentStock; // 🆕 Branch-specific SOH (source of truth)
  final TextEditingController qtyController = TextEditingController();
  final TextEditingController notesController = TextEditingController();
  String selectedReason = '';
  int quantity = 0;
  bool isAdd = true;

  AdjustmentItem({required this.product, this.currentStock = 0});

  bool get hasReason => selectedReason.isNotEmpty;

  int get newStock {
    if (isAdd) return currentStock + quantity;
    return (currentStock - quantity).clamp(0, 999999);
  }

  Product get updatedProduct => Product(
        id: product.id,
        sku: product.sku,
        name: product.name,
        category: product.category,
        unit: product.unit,
        costPrice: product.costPrice,
        sellingPrice: product.sellingPrice,
        stockQty: newStock,
        reorderLevel: product.reorderLevel,
        barcode: product.barcode,
        imageUrl: product.imageUrl,
      );

  void dispose() {
    qtyController.dispose();
    notesController.dispose();
  }
}
