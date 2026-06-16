// lib/models/cart_item_model.dart
import 'product_model.dart';

class CartItem {
  final Product product;
  int quantity;
  double discount;
  String discountType; // 'percentage' or 'fixed'

  CartItem({
    required this.product,
    this.quantity = 1,
    this.discount = 0,
    this.discountType = 'fixed',
  });

  double get subtotal {
    double total = product.sellingPrice * quantity;
    if (discountType == 'percentage') {
      total -= total * (discount / 100);
    } else {
      total -= discount;
    }
    return total < 0 ? 0 : total;
  }

  double get discountAmount {
    double total = product.sellingPrice * quantity;
    if (discountType == 'percentage') {
      return total * (discount / 100);
    }
    return discount;
  }
}
