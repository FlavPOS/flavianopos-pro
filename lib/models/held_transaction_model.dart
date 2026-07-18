// lib/models/held_transaction_model.dart
// v1.0.73+159 - HOLD Transaction feature (v153)
import 'dart:convert';
import '../helpers/database_helper.dart';
import 'cart_item_model.dart';
import 'product_model.dart';

class HeldTransaction {
  // v154: Status constants for permanent audit trail
  static const String statusHold = 'HOLD';
  static const String statusCompleted = 'COMPLETED';
  static const String statusCancelled = 'CANCELLED';
  static const String statusExpired = 'EXPIRED';

  final String id;
  final String heldNumber;
  final String branch;
  final String cashierId;
  final String cashierName;
  final String customerName;
  final String note;
  final List<CartItem> items;
  final double subtotal;
  final double totalDiscount;
  final double total;
  final DateTime heldAt;
  final String status;
  final String shiftId;
  // v154: Audit trail fields
  final String completedAt;
  final String completedBy;
  final String cancelledAt;
  final String cancelledBy;
  final String cancelReason;
  final String expiredAt;
  final String salesTransactionId;
  final String deviceId;
  final String modifiedAt;
  final String modifiedBy;

  HeldTransaction({
    required this.id,
    required this.heldNumber,
    required this.branch,
    required this.cashierId,
    this.cashierName = '',
    this.customerName = '',
    this.note = '',
    required this.items,
    required this.subtotal,
    this.totalDiscount = 0,
    required this.total,
    required this.heldAt,
    this.status = 'active',
    this.shiftId = '',
    // v154: Audit trail params
    this.completedAt = '',
    this.completedBy = '',
    this.cancelledAt = '',
    this.cancelledBy = '',
    this.cancelReason = '',
    this.expiredAt = '',
    this.salesTransactionId = '',
    this.deviceId = '',
    this.modifiedAt = '',
    this.modifiedBy = '',
  });

  int get totalQty => items.fold(0, (s, i) => s + i.quantity);

  Map<String, dynamic> toMap() => {
    'id': id,
    'heldNumber': heldNumber,
    'branch': branch,
    'cashierId': cashierId,
    'cashierName': cashierName,
    'customerName': customerName,
    'note': note,
    'itemsJson': jsonEncode(items.map((i) => {
      'sku': i.product.sku,
      'name': i.product.name,
      'price': i.product.sellingPrice,
      'quantity': i.quantity,
      'discount': i.discount,
      'discountType': i.discountType,
    }).toList()),
    'subtotal': subtotal,
    'totalDiscount': totalDiscount,
    'total': total,
    'heldAt': heldAt.toIso8601String(),
    'status': status,
    'shiftId': shiftId,
    // v154: Audit trail
    'completedAt': completedAt,
    'completedBy': completedBy,
    'cancelledAt': cancelledAt,
    'cancelledBy': cancelledBy,
    'cancelReason': cancelReason,
    'expiredAt': expiredAt,
    'salesTransactionId': salesTransactionId,
    'deviceId': deviceId,
    'modifiedAt': modifiedAt,
    'modifiedBy': modifiedBy,
  };

  static HeldTransaction fromMap(Map<String, dynamic> m) {
    final itemsJsonStr = (m['itemsJson'] ?? '[]').toString();
    List<CartItem> parsedItems = [];
    try {
      final decoded = jsonDecode(itemsJsonStr) as List;
      for (final item in decoded) {
        final map = item as Map<String, dynamic>;
        parsedItems.add(CartItem(
          product: Product(
            id: (map['sku'] ?? '').toString(),
            sku: (map['sku'] ?? '').toString(),
            name: (map['name'] ?? '').toString(),
            sellingPrice: ((map['price'] ?? 0) as num).toDouble(),
            costPrice: 0,
            stockQty: 0,
            category: '',
          ),
          quantity: (map['quantity'] ?? 1) as int,
          discount: ((map['discount'] ?? 0) as num).toDouble(),
          discountType: (map['discountType'] ?? 'fixed').toString(),
        ));
      }
    } catch (_) {}
    return HeldTransaction(
      id: (m['id'] ?? '').toString(),
      heldNumber: (m['heldNumber'] ?? '').toString(),
      branch: (m['branch'] ?? '').toString(),
      cashierId: (m['cashierId'] ?? '').toString(),
      cashierName: (m['cashierName'] ?? '').toString(),
      customerName: (m['customerName'] ?? '').toString(),
      note: (m['note'] ?? '').toString(),
      items: parsedItems,
      subtotal: ((m['subtotal'] ?? 0) as num).toDouble(),
      totalDiscount: ((m['totalDiscount'] ?? 0) as num).toDouble(),
      total: ((m['total'] ?? 0) as num).toDouble(),
      heldAt: DateTime.tryParse((m['heldAt'] ?? '').toString()) ?? DateTime.now(),
      status: (m['status'] ?? 'active').toString(),
      shiftId: (m['shiftId'] ?? '').toString(),
      // v154: Audit trail
      completedAt: (m['completedAt'] ?? '').toString(),
      completedBy: (m['completedBy'] ?? '').toString(),
      cancelledAt: (m['cancelledAt'] ?? '').toString(),
      cancelledBy: (m['cancelledBy'] ?? '').toString(),
      cancelReason: (m['cancelReason'] ?? '').toString(),
      expiredAt: (m['expiredAt'] ?? '').toString(),
      salesTransactionId: (m['salesTransactionId'] ?? '').toString(),
      deviceId: (m['deviceId'] ?? '').toString(),
      modifiedAt: (m['modifiedAt'] ?? '').toString(),
      modifiedBy: (m['modifiedBy'] ?? '').toString(),
    );
  }

  static Future<String> generateHldNumber() async {
    final now = DateTime.now();
    final dateStr = now.year.toString() +
      now.month.toString().padLeft(2, '0') +
      now.day.toString().padLeft(2, '0');
    final prefix = 'HLD-' + dateStr + '-';
    try {
      final rows = await DatabaseHelper().rawQuery(
        "SELECT heldNumber FROM held_transactions WHERE heldNumber LIKE '" + prefix + "%' ORDER BY heldNumber DESC LIMIT 1"
      );
      int seq = 1;
      if (rows.isNotEmpty) {
        final last = rows.first['heldNumber'].toString();
        final parts = last.split('-');
        if (parts.length == 3) {
          seq = (int.tryParse(parts[2]) ?? 0) + 1;
        }
      }
      return prefix + seq.toString().padLeft(4, '0');
    } catch (e) {
      return prefix + (now.millisecondsSinceEpoch % 10000).toString().padLeft(4, '0');
    }
  }
}
