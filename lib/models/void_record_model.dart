// lib/models/void_record_model.dart
// v1.0.90+176 - Void Record Audit Trail (v161)
import '../helpers/database_helper.dart';

class VoidRecord {
  final String id;
  final String voidNumber;
  final String itemSku;
  final String itemName;
  final double itemPrice;
  final int quantity;
  final double totalAmount;
  final String cashierId;
  final String cashierName;
  final String managerName;
  final String reason;
  final String branch;
  final String branchId;
  final DateTime voidedAt;
  final String status;
  final String deviceId;

  VoidRecord({
    required this.id,
    required this.voidNumber,
    required this.itemSku,
    required this.itemName,
    required this.itemPrice,
    required this.quantity,
    required this.totalAmount,
    required this.cashierId,
    this.cashierName = '',
    this.managerName = '',
    this.reason = '',
    required this.branch,
    this.branchId = '',
    required this.voidedAt,
    this.status = 'active',
    this.deviceId = '',
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'voidNumber': voidNumber,
    'itemSku': itemSku,
    'itemName': itemName,
    'itemPrice': itemPrice,
    'quantity': quantity,
    'totalAmount': totalAmount,
    'cashierId': cashierId,
    'cashierName': cashierName,
    'managerName': managerName,
    'reason': reason,
    'branch': branch,
    'branchId': branchId,
    'voidedAt': voidedAt.toIso8601String(),
    'status': status,
    'deviceId': deviceId,
  };

  factory VoidRecord.fromMap(Map<String, dynamic> m) => VoidRecord(
    id: (m['id'] ?? '').toString(),
    voidNumber: (m['voidNumber'] ?? '').toString(),
    itemSku: (m['itemSku'] ?? '').toString(),
    itemName: (m['itemName'] ?? '').toString(),
    itemPrice: ((m['itemPrice'] ?? 0) as num).toDouble(),
    quantity: (m['quantity'] ?? 1) as int,
    totalAmount: ((m['totalAmount'] ?? 0) as num).toDouble(),
    cashierId: (m['cashierId'] ?? '').toString(),
    cashierName: (m['cashierName'] ?? '').toString(),
    managerName: (m['managerName'] ?? '').toString(),
    reason: (m['reason'] ?? '').toString(),
    branch: (m['branch'] ?? '').toString(),
    branchId: (m['branchId'] ?? '').toString(),
    voidedAt: DateTime.tryParse((m['voidedAt'] ?? '').toString()) ?? DateTime.now(),
    status: (m['status'] ?? 'active').toString(),
    deviceId: (m['deviceId'] ?? '').toString(),
  );

  static Future<String> generateVoidNumber() async {
    final now = DateTime.now();
    final dateStr = now.year.toString() +
      now.month.toString().padLeft(2, '0') +
      now.day.toString().padLeft(2, '0');
    final prefix = 'VOID-' + dateStr + '-';
    try {
      final rows = await DatabaseHelper().rawQuery(
        "SELECT voidNumber FROM void_records WHERE voidNumber LIKE '" + prefix + "%' ORDER BY voidNumber DESC LIMIT 1"
      );
      int seq = 1;
      if (rows.isNotEmpty) {
        final last = rows.first['voidNumber'].toString();
        final parts = last.split('-');
        if (parts.length == 3) seq = (int.tryParse(parts[2]) ?? 0) + 1;
      }
      return prefix + seq.toString().padLeft(4, '0');
    } catch (e) {
      return prefix + (now.millisecondsSinceEpoch % 10000).toString().padLeft(4, '0');
    }
  }
}
