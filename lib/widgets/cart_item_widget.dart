import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/cart_item_model.dart';

class CartItemWidget extends StatelessWidget {
  final CartItem cartItem;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onRemove;
  final VoidCallback onDiscount;
  final VoidCallback? onTap;

  const CartItemWidget({
    super.key,
    required this.cartItem,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
    required this.onDiscount,
    this.onTap,
  });

  Widget _buildProductThumb() {
    final img = cartItem.product.imagePath;
    if (img != null && img.isNotEmpty && img.length > 200) {
      try {
        String b64 = img;
        if (b64.contains(',')) b64 = b64.split(',').last;
        final bytes = base64Decode(b64);
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            Uint8List.fromList(bytes),
            width: 40, height: 40,
            fit: BoxFit.cover,
            errorBuilder: (c, e, s) => _buildIconFallback(),
          ),
        );
      } catch (_) {}
    }
    return _buildIconFallback();
  }

  Widget _buildIconFallback() {
    return Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.shopping_bag, size: 20, color: Colors.grey[500]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            // Product Image
            _buildProductThumb(),
            const SizedBox(width: 10),

            // Product Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(cartItem.product.name,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text('${cartItem.product.sellingPrice.toStringAsFixed(2)} x ${cartItem.quantity}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                  if (cartItem.discount > 0)
                    Text('Discount: -${cartItem.discountAmount.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.w500)),
                ],
              ),
            ),

            // Quantity Controls
            Container(
              decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                InkWell(onTap: onDecrement,
                  child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.remove, size: 16))),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text('${cartItem.quantity}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                InkWell(onTap: onIncrement,
                  child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.add, size: 16))),
              ]),
            ),
            const SizedBox(width: 8),

            // Subtotal
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(cartItem.subtotal.toStringAsFixed(2),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1565C0))),
              Row(mainAxisSize: MainAxisSize.min, children: [
                InkWell(onTap: onDiscount,
                  child: const Padding(padding: EdgeInsets.all(4),
                    child: Icon(Icons.discount, size: 16, color: Colors.orange))),
                InkWell(onTap: onRemove,
                  child: const Padding(padding: EdgeInsets.all(4),
                    child: Icon(Icons.delete_outline, size: 16, color: Colors.red))),
              ]),
            ]),
          ],
        ),
      ),
    ));
  }
}
