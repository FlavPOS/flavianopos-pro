// lib/models/cashier_session_model.dart

class CashierSession {
  final String id;
  final String shiftId;
  final String cashierId;
  final String cashierName;
  final String branch;
  final double beginningCash;
  final String beginningSource;
  final String beginningRemarks;
  final double endingCashDeclared;
  final double systemExpectedCash;
  final double variance;
  final String varianceType;  // 'short', 'over', 'balanced'
  final String status;  // 'open', 'declared', 'closed'
  final DateTime openedAt;
  final DateTime? closedAt;
  // Sales breakdown
  final double cashSales;
  final double gcashSales;
  final double mayaSales;
  final double cardSales;
  final double otherSales;
  final double totalRefunds;
  final double totalVoids;
  final double totalDiscounts;
  final double totalExchanges;
  final int transactionCount;

  CashierSession({
    required this.id,
    required this.shiftId,
    required this.cashierId,
    this.cashierName = '',
    this.branch = '',
    this.beginningCash = 0,
    this.beginningSource = 'Vault',
    this.beginningRemarks = '',
    this.endingCashDeclared = 0,
    this.systemExpectedCash = 0,
    this.variance = 0,
    this.varianceType = 'balanced',
    this.status = 'open',
    required this.openedAt,
    this.closedAt,
    this.cashSales = 0,
    this.gcashSales = 0,
    this.mayaSales = 0,
    this.cardSales = 0,
    this.otherSales = 0,
    this.totalRefunds = 0,
    this.totalVoids = 0,
    this.totalDiscounts = 0,
    this.totalExchanges = 0,
    this.transactionCount = 0,
  });

  Map<String, dynamic> toMap() => {
    'id': id, 'shiftId': shiftId, 'cashierId': cashierId,
    'cashierName': cashierName, 'branch': branch,
    'beginningCash': beginningCash, 'beginningSource': beginningSource,
    'beginningRemarks': beginningRemarks,
    'endingCashDeclared': endingCashDeclared,
    'systemExpectedCash': systemExpectedCash,
    'variance': variance, 'varianceType': varianceType, 'status': status,
    'openedAt': openedAt.toIso8601String(),
    'closedAt': closedAt?.toIso8601String(),
    'cashSales': cashSales, 'gcashSales': gcashSales,
    'mayaSales': mayaSales, 'cardSales': cardSales, 'otherSales': otherSales,
    'totalRefunds': totalRefunds, 'totalVoids': totalVoids,
    'totalDiscounts': totalDiscounts, 'totalExchanges': totalExchanges,
    'transactionCount': transactionCount,
  };

  factory CashierSession.fromMap(Map<String, dynamic> m) => CashierSession(
    id: m['id'] ?? '', shiftId: m['shiftId'] ?? '',
    cashierId: m['cashierId'] ?? '', cashierName: m['cashierName'] ?? '',
    branch: m['branch'] ?? '',
    beginningCash: (m['beginningCash'] as num?)?.toDouble() ?? 0,
    beginningSource: m['beginningSource'] ?? 'Vault',
    beginningRemarks: m['beginningRemarks'] ?? '',
    endingCashDeclared: (m['endingCashDeclared'] as num?)?.toDouble() ?? 0,
    systemExpectedCash: (m['systemExpectedCash'] as num?)?.toDouble() ?? 0,
    variance: (m['variance'] as num?)?.toDouble() ?? 0,
    varianceType: m['varianceType'] ?? 'balanced',
    status: m['status'] ?? 'open',
    openedAt: DateTime.tryParse(m['openedAt'] ?? '') ?? DateTime.now(),
    closedAt: m['closedAt'] != null && m['closedAt'].toString().isNotEmpty
      ? DateTime.tryParse(m['closedAt']) : null,
    cashSales: (m['cashSales'] as num?)?.toDouble() ?? 0,
    gcashSales: (m['gcashSales'] as num?)?.toDouble() ?? 0,
    mayaSales: (m['mayaSales'] as num?)?.toDouble() ?? 0,
    cardSales: (m['cardSales'] as num?)?.toDouble() ?? 0,
    otherSales: (m['otherSales'] as num?)?.toDouble() ?? 0,
    totalRefunds: (m['totalRefunds'] as num?)?.toDouble() ?? 0,
    totalVoids: (m['totalVoids'] as num?)?.toDouble() ?? 0,
    totalDiscounts: (m['totalDiscounts'] as num?)?.toDouble() ?? 0,
    totalExchanges: (m['totalExchanges'] as num?)?.toDouble() ?? 0,
    transactionCount: m['transactionCount'] ?? 0,
  );

  static String generateShiftId(String cashierId) {
    final now = DateTime.now();
    final ts = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    return 'SHIFT-$cashierId-$ts';
  }

  double get totalSales => cashSales + gcashSales + mayaSales + cardSales + otherSales;
  bool get isOpen => status == 'open';
  bool get isDeclared => status == 'declared';
  bool get isClosed => status == 'closed';
  bool get hasVariance => variance != 0;
  bool get requiresIR => variance.abs() > 50;
}
