import 'package:flutter/material.dart';
import 'product_model.dart';

class AdjustmentItem {
  final Product product;
  final TextEditingController qtyController = TextEditingController();
  final TextEditingController notesController = TextEditingController();
  bool isAdd = true;
  String selectedReason = 'Other';
  int quantity = 0;

  AdjustmentItem({required this.product});

  int get newStock {
    if (isAdd) return product.stockQty + quantity;
    return (product.stockQty - quantity).clamp(0, 999999);
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
