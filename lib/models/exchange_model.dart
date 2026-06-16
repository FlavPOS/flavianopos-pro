import '../helpers/database_helper.dart';

class Exchange {
  final String id, exchangeNumber, originalTxnId, exchangeDate;
  final String returnedItemName, returnedItemSku;
  final int returnedQty;
  final double returnedPrice;
  final String newItemName, newItemSku;
  final int newQty;
  final double newPrice;
  final double priceDifference, amountPaid;
  final String reason, processedBy, approvedBy, branch;
  final String status;
  final String dateCreated;

  Exchange({required this.id, required this.exchangeNumber, required this.originalTxnId, required this.exchangeDate,
    required this.returnedItemName, required this.returnedItemSku, required this.returnedQty, required this.returnedPrice,
    required this.newItemName, required this.newItemSku, required this.newQty, required this.newPrice,
    required this.priceDifference, this.amountPaid = 0, required this.reason,
    required this.processedBy, required this.approvedBy, required this.branch,
    this.status = 'Completed', required this.dateCreated});

  Map<String, dynamic> toMap() => {
    'id': id, 'exchangeNumber': exchangeNumber, 'originalTxnId': originalTxnId, 'exchangeDate': exchangeDate,
    'returnedItemName': returnedItemName, 'returnedItemSku': returnedItemSku, 'returnedQty': returnedQty, 'returnedPrice': returnedPrice,
    'newItemName': newItemName, 'newItemSku': newItemSku, 'newQty': newQty, 'newPrice': newPrice,
    'priceDifference': priceDifference, 'amountPaid': amountPaid, 'reason': reason,
    'processedBy': processedBy, 'approvedBy': approvedBy, 'branch': branch,
    'status': status, 'dateCreated': dateCreated,
  };

  factory Exchange.fromMap(Map<String, dynamic> m) => Exchange(
    id: m['id'] ?? '', exchangeNumber: m['exchangeNumber'] ?? '', originalTxnId: m['originalTxnId'] ?? '', exchangeDate: m['exchangeDate'] ?? '',
    returnedItemName: m['returnedItemName'] ?? '', returnedItemSku: m['returnedItemSku'] ?? '', returnedQty: m['returnedQty'] ?? 0, returnedPrice: (m['returnedPrice'] as num?)?.toDouble() ?? 0,
    newItemName: m['newItemName'] ?? '', newItemSku: m['newItemSku'] ?? '', newQty: m['newQty'] ?? 0, newPrice: (m['newPrice'] as num?)?.toDouble() ?? 0,
    priceDifference: (m['priceDifference'] as num?)?.toDouble() ?? 0, amountPaid: (m['amountPaid'] as num?)?.toDouble() ?? 0,
    reason: m['reason'] ?? '', processedBy: m['processedBy'] ?? '', approvedBy: m['approvedBy'] ?? '', branch: m['branch'] ?? '',
    status: m['status'] ?? 'Completed', dateCreated: m['dateCreated'] ?? '');

  static Future<String> generateExchangeNumber() async {
    final now = DateTime.now();
    final dateStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final prefix = 'EXC-$dateStr-';
    final rows = await DatabaseHelper().rawQuery("SELECT exchangeNumber FROM exchanges WHERE exchangeNumber LIKE '$prefix%' ORDER BY exchangeNumber DESC LIMIT 1");
    int seq = 1;
    if (rows.isNotEmpty) { final last = rows.first['exchangeNumber'] as String; final parts = last.split('-'); if (parts.length == 3) seq = (int.tryParse(parts[2]) ?? 0) + 1; }
    return '$prefix${seq.toString().padLeft(4, '0')}';
  }

  static Future<void> create(Exchange e) async { await DatabaseHelper().insertExchange(e.toMap()); }
  static Future<List<Exchange>> getAll() async { final rows = await DatabaseHelper().getAllExchanges(); return rows.map((r) => Exchange.fromMap(r)).toList(); }
  static Future<List<Exchange>> getByTxn(String txnId) async { final rows = await DatabaseHelper().getExchangesByTxn(txnId); return rows.map((r) => Exchange.fromMap(r)).toList(); }
}
