// lib/models/transaction_model.dart
import '../services/device_assignment_service.dart'; // v1.0.59+131
import '../helpers/database_helper.dart';
import '../helpers/sync_bridge.dart';
import 'sync_queue_model.dart';

class TransactionItem {
  final String name;
  final String sku;
  final int qty;
  final double price;
  final double discount;
  final String discountType;
  double get subtotal => (price * qty) - discountAmount;
  double get discountAmount {
    if (discountType == 'percentage') return price * qty * discount / 100;
    return discount;
  }
  TransactionItem({required this.name, this.sku = '', required this.qty,
    required this.price, this.discount = 0, this.discountType = 'fixed'});

  Map<String, dynamic> toMap() => {
    'name': name, 'sku': sku, 'qty': qty, 'price': price,
    'discount': discount, 'discountType': discountType,
    'discountAmount': discountAmount,
  };

  factory TransactionItem.fromMap(Map<String, dynamic> m) => TransactionItem(
    name: m['name'] ?? '', sku: m['sku'] ?? '',
    qty: m['qty'] ?? 0, price: (m['price'] ?? 0).toDouble(),
    discount: (m['discount'] ?? 0).toDouble(),
    discountType: m['discountType'] ?? 'fixed',
  );
}

class Transaction {
  final String id;
  final List<TransactionItem> items;
  final double subtotal;
  final double totalDiscount;
  final double tax;
  final double total;
  final String paymentMethod;
  final double amountPaid;
  final double change;
  // v159c: Payment audit trail
  final String paymentReference;
  final String bankName;
  final String cashier;
  final String branch;
  final DateTime dateTime;
  String status;
  String voidReason;
  String voidedBy;
  DateTime? voidedAt;
  double refundAmount;
  String refundMethod;
  String refundedBy;
  DateTime? refundedAt;

  Transaction({required this.id, required this.items, required this.subtotal,
    this.totalDiscount = 0, required this.tax, required this.total,
    required this.paymentMethod, required this.amountPaid, required this.change, this.paymentReference = '', this.bankName = '',
    required this.cashier, required this.branch, required this.dateTime,
    this.status = 'completed', this.voidReason = '', this.voidedBy = '',
    this.voidedAt, this.refundAmount = 0, this.refundMethod = '',
    this.refundedBy = '', this.refundedAt});

  int get totalQty => items.fold(0, (s, i) => s + i.qty);

  Map<String, dynamic> toMap() => {
    'id': id, 'subtotal': subtotal, 'totalDiscount': totalDiscount,
    'total': total, 'paymentMethod': paymentMethod,
    'amountPaid': amountPaid, 'changeAmount': change, 'paymentReference': paymentReference, 'bankName': bankName,
    'status': status, 'cashier': cashier, 'branch': branch,
    'voidReason': voidReason,
    'voidedBy': voidedBy,
    'voidedAt': voidedAt?.toIso8601String(),
    'refundAmount': refundAmount,
    'refundMethod': refundMethod,
    'refundedBy': refundedBy,
    'refundedAt': refundedAt?.toIso8601String(),
    'dateTime': dateTime.toIso8601String(),
  };

  factory Transaction.fromMap(Map<String, dynamic> m, List<TransactionItem> items) => Transaction(
    id: m['id'] ?? '', items: items, subtotal: (m['subtotal'] ?? 0).toDouble(),
    totalDiscount: (m['totalDiscount'] ?? 0).toDouble(),
    tax: 0, total: (m['total'] ?? 0).toDouble(),
    paymentMethod: m['paymentMethod'] ?? 'Cash',
    amountPaid: (m['amountPaid'] ?? 0).toDouble(),
    paymentReference: (m['paymentReference'] ?? '').toString(),
    bankName: (m['bankName'] ?? '').toString(),
    change: (m['changeAmount'] ?? 0).toDouble(),
    cashier: m['cashier'] ?? '', branch: m['branch'] ?? '',
    dateTime: DateTime.tryParse(m['dateTime'] ?? '') ?? DateTime.now(),
    status: m['status'] ?? 'completed',
    voidReason: m['voidReason'] ?? '', voidedBy: m['voidedBy'] ?? '',
    voidedAt: m['voidedAt'] != null ? DateTime.tryParse(m['voidedAt']) : null,
    refundAmount: (m['refundAmount'] ?? 0).toDouble(),
    refundMethod: m['refundMethod'] ?? '', refundedBy: m['refundedBy'] ?? '',
    refundedAt: m['refundedAt'] != null ? DateTime.tryParse(m['refundedAt']) : null,
  );

  static List<Transaction> _allTransactions = [];
  static bool _loaded = false;

  static List<Transaction> get allTransactions {
    if (!_loaded && _allTransactions.isEmpty) {
      _allTransactions = [];
    }
    return _allTransactions;
  }

  // v1.0.60+134 — Strict per-branch, accepts branchId OR branchName (backwards compat)
  // Legacy transactions saved 'Main Branch' (name), new saves use 'BR006' (id)
  static Future<List<Transaction>> get branchScopedTransactions async {
    try {
      final assign = await DeviceAssignmentService().read();
      final branchId = (assign['branchId'] ?? '').toString().trim();
      final branchName = (assign['branchName'] ?? '').toString().trim();
      
      print('[BRANCH-SCOPE] Filtering for branchId="$branchId" branchName="$branchName" total=${allTransactions.length}');
      
      if (branchId.isEmpty && branchName.isEmpty) {
        print('[BRANCH-SCOPE] Both empty - returning empty list');
        return <Transaction>[];
      }
      
      // Match by branchId OR branchName (case-insensitive) for backwards compat
      final filtered = allTransactions.where((t) {
        final txnBranch = t.branch.trim();
        if (txnBranch.isEmpty) return false;
        // Match id (preferred) OR name (legacy)
        return txnBranch.toLowerCase() == branchId.toLowerCase() ||
               txnBranch.toLowerCase() == branchName.toLowerCase();
      }).toList();
      
      print('[BRANCH-SCOPE] "$branchId" sees ${filtered.length} own transactions');
      return filtered;
    } catch (e) {
      print('[BRANCH-SCOPE] Error: $e');
      return <Transaction>[];
    }
  }

  // v1.0.60+137 - Deduplicated loadFromDB (prevents 8 to 16 doubling)
  static Future<void> loadFromDB() async {
    final db = DatabaseHelper();
    final txnRows = await db.getAllTransactions();
    final Set<String> seenIds = {};
    final tempList = <Transaction>[];
    for (final row in txnRows) {
      final id = row['id']?.toString() ?? '';
      if (id.isEmpty) {
        print('[TXN-LOAD] Skipping row with empty ID');
        continue;
      }
      if (seenIds.contains(id)) {
        print('[TXN-LOAD] Skipping duplicate ID: $id');
        continue;
      }
      seenIds.add(id);
      final itemRows = await db.getTransactionItems(id);
      final items = itemRows.map((r) => TransactionItem.fromMap(r)).toList();
      tempList.add(Transaction.fromMap(row, items));
    }
    _allTransactions = tempList;  // Atomic replace
    _loaded = true;
    print('[TXN-LOAD] Loaded ${_allTransactions.length} unique transactions');
  }

  // v1.0.60+137 - Deduplicated addTransaction
  static void addTransaction(Transaction txn) {
    _allTransactions = allTransactions;
    // Check if transaction already exists in memory (prevent duplicates)
    final existingIdx = _allTransactions.indexWhere((t) => t.id == txn.id);
    if (existingIdx >= 0) {
      print('[TXN-DEDUP] Updating existing ${txn.id} instead of adding duplicate');
      _allTransactions[existingIdx] = txn;
      DatabaseHelper().updateTransaction(txn.id, txn.toMap()).catchError((_) => null);
      SyncBridge.enqueueTransaction(txn, op: SyncOp.update);
      return;
    }
    _allTransactions.insert(0, txn);
    DatabaseHelper().insertTransactionWithItems(txn.toMap(), txn.items.map((i) => i.toMap()).toList()).catchError((_) => null);
    SyncBridge.enqueueTransaction(txn, op: SyncOp.create);
  }

  static void updateTransaction(String id, Transaction updated) {
    final index = _allTransactions.indexWhere((t) => t.id == id);
    if (index >= 0) _allTransactions[index] = updated;
    DatabaseHelper().updateTransaction(id, updated.toMap()).then((r) => print("DB UPDATE: $r rows for $id status=${updated.status}")).catchError((e) => print("DB ERROR: $e"));
    SyncBridge.enqueueTransaction(updated, op: SyncOp.update);
  }

  static List<Transaction> getSampleTransactions() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return [
      Transaction(id: 'TXN-20260607-001',
        items: [TransactionItem(name: 'Coca-Cola 1.5L', sku: 'BEV-001', qty: 2, price: 65),
          TransactionItem(name: 'Piattos Cheese', sku: 'SNK-001', qty: 1, price: 28)],
        subtotal: 158, tax: 16.93, total: 158, paymentMethod: 'Cash',
        amountPaid: 200, change: 42, cashier: 'admin', branch: 'Main Branch',
        dateTime: today.add(const Duration(hours: 9, minutes: 15))),
      Transaction(id: 'TXN-20260607-002',
        items: [TransactionItem(name: 'Nescafe 3-in-1', sku: 'BEV-003', qty: 3, price: 8.50),
          TransactionItem(name: 'Pancit Canton', sku: 'NUD-001', qty: 2, price: 12)],
        subtotal: 49.50, tax: 5.30, total: 49.50, paymentMethod: 'GCash',
        amountPaid: 49.50, change: 0, cashier: 'admin', branch: 'Main Branch',
        dateTime: today.add(const Duration(hours: 10, minutes: 30))),
      Transaction(id: 'TXN-20260607-003',
        items: [TransactionItem(name: 'Rice 5kg', sku: 'GRC-001', qty: 1, price: 285),
          TransactionItem(name: 'Cooking Oil 1L', sku: 'GRC-002', qty: 1, price: 95),
          TransactionItem(name: 'Soy Sauce 1L', sku: 'GRC-003', qty: 1, price: 45)],
        subtotal: 425, tax: 45.54, total: 425, paymentMethod: 'Cash',
        amountPaid: 500, change: 75, cashier: 'maria', branch: 'Main Branch',
        dateTime: today.add(const Duration(hours: 11, minutes: 45))),
      Transaction(id: 'TXN-20260607-004',
        items: [TransactionItem(name: 'Shampoo Sachet', sku: 'PRC-001', qty: 5, price: 7),
          TransactionItem(name: 'Soap Bar', sku: 'PRC-002', qty: 2, price: 35)],
        subtotal: 105, tax: 11.25, total: 105, paymentMethod: 'Maya',
        amountPaid: 105, change: 0, cashier: 'juan', branch: 'Main Branch',
        dateTime: today.add(const Duration(hours: 13, minutes: 20)),
        status: 'voided', voidReason: 'Customer changed mind', voidedBy: 'admin',
        voidedAt: today.add(const Duration(hours: 13, minutes: 35))),
      Transaction(id: 'TXN-20260607-005',
        items: [TransactionItem(name: 'Bottled Water 500ml', sku: 'BEV-005', qty: 6, price: 15),
          TransactionItem(name: 'Bread Loaf', sku: 'BAK-001', qty: 1, price: 55)],
        subtotal: 145, tax: 15.54, total: 145, paymentMethod: 'Cash',
        amountPaid: 150, change: 5, cashier: 'admin', branch: 'Main Branch',
        dateTime: today.add(const Duration(hours: 14, minutes: 10))),
      Transaction(id: 'TXN-20260606-001',
        items: [TransactionItem(name: 'Canned Tuna', sku: 'CAN-001', qty: 3, price: 32),
          TransactionItem(name: 'Sardines', sku: 'CAN-002', qty: 2, price: 22)],
        subtotal: 140, tax: 15, total: 140, paymentMethod: 'Cash',
        amountPaid: 200, change: 60, cashier: 'admin', branch: 'Main Branch',
        dateTime: today.subtract(const Duration(days: 1)).add(const Duration(hours: 10))),
      Transaction(id: 'TXN-20260606-002',
        items: [TransactionItem(name: 'Milk 1L', sku: 'DAI-001', qty: 2, price: 85),
          TransactionItem(name: 'Eggs 12pcs', sku: 'DAI-002', qty: 1, price: 95)],
        subtotal: 265, tax: 28.39, total: 265, paymentMethod: 'GCash',
        amountPaid: 265, change: 0, cashier: 'maria', branch: 'Main Branch',
        dateTime: today.subtract(const Duration(days: 1)).add(const Duration(hours: 14)),
        status: 'refunded', refundAmount: 265, refundMethod: 'GCash',
        refundedBy: 'admin', refundedAt: today.subtract(const Duration(days: 1)).add(const Duration(hours: 15))),
      Transaction(id: 'TXN-20260605-001',
        items: [TransactionItem(name: 'Detergent Powder', sku: 'HOM-001', qty: 1, price: 145),
          TransactionItem(name: 'Fabric Softener', sku: 'HOM-002', qty: 1, price: 65)],
        subtotal: 210, tax: 22.50, total: 210, paymentMethod: 'Card',
        amountPaid: 210, change: 0, cashier: 'juan', branch: 'Main Branch',
        dateTime: today.subtract(const Duration(days: 2)).add(const Duration(hours: 11))),
      Transaction(id: 'TXN-20260604-001',
        items: [TransactionItem(name: 'Instant Noodles', sku: 'NUD-002', qty: 10, price: 8),
          TransactionItem(name: 'Coffee 3in1', sku: 'BEV-006', qty: 5, price: 8.50)],
        subtotal: 122.50, tax: 13.13, total: 122.50, paymentMethod: 'Cash',
        amountPaid: 150, change: 27.50, cashier: 'admin', branch: 'Main Branch',
        dateTime: today.subtract(const Duration(days: 3)).add(const Duration(hours: 9, minutes: 30))),
      Transaction(id: 'TXN-20260603-001',
        items: [TransactionItem(name: 'Toothpaste', sku: 'PRC-003', qty: 2, price: 75),
          TransactionItem(name: 'Toothbrush', sku: 'PRC-004', qty: 2, price: 45),
          TransactionItem(name: 'Mouthwash', sku: 'PRC-005', qty: 1, price: 120)],
        subtotal: 360, tax: 38.57, total: 360, paymentMethod: 'Maya',
        amountPaid: 360, change: 0, cashier: 'maria', branch: 'Main Branch',
        dateTime: today.subtract(const Duration(days: 4)).add(const Duration(hours: 16))),
    ];
  }
}
