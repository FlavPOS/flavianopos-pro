// lib/models/z_report_model.dart

class ZReportPaymentBreakdown {
  final String method;
  final int count;
  final double total;
  ZReportPaymentBreakdown({required this.method, required this.count, required this.total});
}

class ZReportVoidRecord {
  final String txnId;
  final String reason;
  final double amount;
  ZReportVoidRecord({required this.txnId, required this.reason, required this.amount});
}

class ZReportTxnRecord {
  final String txnId;
  final DateTime dateTime;
  final String paymentMethod;
  final double amount;
  final String status;
  ZReportTxnRecord({required this.txnId, required this.dateTime, required this.paymentMethod, required this.amount, required this.status});
}

class ZReportRecord {
  final String reportId;
  final DateTime reportDate;
  final DateTime generatedAt;
  final String branch;
  final String cashier;

  // Sales
  final double grossSales;
  final double totalDiscount;
  final double netSales;
  final int totalTransactions;
  final double averageTransaction;

  // Payment
  final List<ZReportPaymentBreakdown> paymentBreakdown;

  // Voids
  final int voidedCount;
  final double voidedAmount;
  final List<ZReportVoidRecord> voidedTransactions;

  // Cash count
  final double beginningCash;
  // Refunds
  final int refundedCount;
  final double refundedAmount;
  final List<ZReportVoidRecord> refundedTransactions;
  final double expectedCash;
  final double endingCash;
  final double overShort;

  // Transaction log
  final List<ZReportTxnRecord> transactionLog;

  ZReportRecord({
    required this.reportId,
    required this.reportDate,
    required this.generatedAt,
    required this.branch,
    required this.cashier,
    required this.grossSales,
    required this.totalDiscount,
    required this.netSales,
    required this.totalTransactions,
    required this.averageTransaction,
    required this.paymentBreakdown,
    required this.voidedCount,
    required this.voidedAmount,
    required this.voidedTransactions,
    required this.refundedCount,
    required this.refundedAmount,
    required this.refundedTransactions,
    required this.beginningCash,
    required this.expectedCash,
    required this.endingCash,
    required this.overShort,
    required this.transactionLog,
  });

  // ✅ Static storage for all generated Z Reports
  static final List<ZReportRecord> _history = [];

  static List<ZReportRecord> get history => List.unmodifiable(_history);

  static void addReport(ZReportRecord report) {
    _history.insert(0, report); // newest first
  }

  static void clearHistory() => _history.clear();

  static ZReportRecord? getByDate(DateTime date) {
    try {
      return _history.firstWhere((r) =>
        r.reportDate.year == date.year &&
        r.reportDate.month == date.month &&
        r.reportDate.day == date.day);
    } catch (_) {
      return null;
    }
  }

  static bool hasReportForToday() {
    final now = DateTime.now();
    return _history.any((r) =>
      r.reportDate.year == now.year &&
      r.reportDate.month == now.month &&
      r.reportDate.day == now.day);
  }
}
