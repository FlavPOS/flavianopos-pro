import 'package:flutter/foundation.dart';
// lib/models/z_report_model.dart
import '../helpers/database_helper.dart';
import '../helpers/sync_bridge.dart';
import 'sync_queue_model.dart';

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

  // ═══ SQLite persistence methods ═══
  Map<String, dynamic> toMap() => {
    'reportId': reportId,
    'reportDate': reportDate.toIso8601String(),
    'generatedAt': generatedAt.toIso8601String(),
    'branch': branch,
    'cashier': cashier,
    'grossSales': grossSales,
    'totalDiscount': totalDiscount,
    'netSales': netSales,
    'totalTransactions': totalTransactions,
    'averageTransaction': averageTransaction,
    'paymentBreakdownJson': paymentBreakdown.map((p) => '${p.method}|${p.count}|${p.total}').join('||'),
    'voidedCount': voidedCount,
    'voidedAmount': voidedAmount,
    'voidedTransactionsJson': voidedTransactions.map((v) => '${v.txnId}|${v.reason}|${v.amount}').join('||'),
    'beginningCash': beginningCash,
    'endingCash': endingCash,
    'expectedCash': expectedCash,
    'overShort': overShort,
    'refundedCount': refundedCount,
    'refundedAmount': refundedAmount,
    'refundedTransactionsJson': refundedTransactions.map((v) => '${v.txnId}|${v.reason}|${v.amount}').join('||'),
    'allTransactionsJson': transactionLog.map((t) => '${t.txnId}|${t.dateTime.toIso8601String()}|${t.paymentMethod}|${t.amount}|${t.status}').join('||'),
  };

  factory ZReportRecord.fromMap(Map<String, dynamic> m) {
    // Deserialize payment breakdown
    final pbList = <ZReportPaymentBreakdown>[];
    final pbStr = m['paymentBreakdownJson'] as String? ?? '';
    if (pbStr.isNotEmpty) {
      for (final part in pbStr.split('||')) {
        if (part.isEmpty) continue;
        final p = part.split('|');
        if (p.length >= 3) {
          pbList.add(ZReportPaymentBreakdown(
            method: p[0], count: int.tryParse(p[1]) ?? 0, total: double.tryParse(p[2]) ?? 0));
        }
      }
    }

    // Deserialize voids
    final voidsList = <ZReportVoidRecord>[];
    final voidsStr = m['voidedTransactionsJson'] as String? ?? '';
    if (voidsStr.isNotEmpty) {
      for (final part in voidsStr.split('||')) {
        if (part.isEmpty) continue;
        final v = part.split('|');
        if (v.length >= 3) {
          voidsList.add(ZReportVoidRecord(
            txnId: v[0], reason: v[1], amount: double.tryParse(v[2]) ?? 0));
        }
      }
    }


    // Deserialize refunded transactions (same format as voids)
    final refundedList = <ZReportVoidRecord>[];
    final refundedStr = m['refundedTransactionsJson'] as String? ?? '';
    if (refundedStr.isNotEmpty) {
      for (final part in refundedStr.split('||')) {
        if (part.isEmpty) continue;
        final r = part.split('|');
        if (r.length >= 3) {
          refundedList.add(ZReportVoidRecord(
            txnId: r[0], reason: r[1], amount: double.tryParse(r[2]) ?? 0));
        }
      }
    }

    // Deserialize all transactions
    final txnList = <ZReportTxnRecord>[];
    final txnStr = m['allTransactionsJson'] as String? ?? '';
    if (txnStr.isNotEmpty) {
      for (final part in txnStr.split('||')) {
        if (part.isEmpty) continue;
        final t = part.split('|');
        if (t.length >= 5) {
          txnList.add(ZReportTxnRecord(
            txnId: t[0],
            dateTime: DateTime.tryParse(t[1]) ?? DateTime.now(),
            paymentMethod: t[2],
            amount: double.tryParse(t[3]) ?? 0,
            status: t[4]));
        }
      }
    }

    return ZReportRecord(
      reportId: m['reportId'] ?? '',
      reportDate: DateTime.tryParse(m['reportDate'] ?? '') ?? DateTime.now(),
      generatedAt: DateTime.tryParse(m['generatedAt'] ?? '') ?? DateTime.now(),
      branch: m['branch'] ?? '',
      cashier: m['cashier'] ?? '',
      grossSales: (m['grossSales'] as num?)?.toDouble() ?? 0,
      totalDiscount: (m['totalDiscount'] as num?)?.toDouble() ?? 0,
      netSales: (m['netSales'] as num?)?.toDouble() ?? 0,
      totalTransactions: m['totalTransactions'] ?? 0,
      averageTransaction: (m['averageTransaction'] as num?)?.toDouble() ?? 0,
      paymentBreakdown: pbList,
      voidedCount: m['voidedCount'] ?? 0,
      voidedAmount: (m['voidedAmount'] as num?)?.toDouble() ?? 0,
      voidedTransactions: voidsList,
      beginningCash: (m['beginningCash'] as num?)?.toDouble() ?? 0,
      endingCash: (m['endingCash'] as num?)?.toDouble() ?? 0,
      expectedCash: (m['expectedCash'] as num?)?.toDouble() ?? 0,
      overShort: (m['overShort'] as num?)?.toDouble() ?? 0,
      refundedCount: m['refundedCount'] ?? 0,
      refundedAmount: (m['refundedAmount'] as num?)?.toDouble() ?? 0,
      refundedTransactions: refundedList,
      transactionLog: txnList,
    );
  }

  /// Load all reports from SQLite into memory
  static Future<void> loadFromDB() async {
    try {
      final rows = await DatabaseHelper().getAllZReports();
      _history.clear();
      _history.addAll(rows.map((r) => ZReportRecord.fromMap(r)));
    } catch (e, st) { debugPrint("❌ Z Report SAVE FAILED: $e"); debugPrint("Stack: $st"); rethrow; }
  }

  /// Save report to SQLite + memory
  static Future<void> addReport(ZReportRecord report) async {
    _history.insert(0, report);
    try {
      await DatabaseHelper().insertZReport(report.toMap());
      SyncBridge.enqueueZReport(report, op: SyncOp.create);
    } catch (e, st) { debugPrint("❌ Z Report SAVE FAILED: $e"); debugPrint("Stack: $st"); rethrow; }
  }

  /// Check if today already has a Z Report (queries DB!)
  static Future<bool> hasReportForToday() async {
    try {
      return await DatabaseHelper().hasZReportForDate(DateTime.now());
    } catch (_) {
      // Fallback to memory check
      final now = DateTime.now();
      return _history.any((r) =>
        r.reportDate.year == now.year &&
        r.reportDate.month == now.month &&
        r.reportDate.day == now.day);
    }
  }

  static Future<void> clearHistory() async {
    _history.clear();
    try { await DatabaseHelper().clearZReports(); } catch (e, st) { debugPrint("❌ Z Report SAVE FAILED: $e"); debugPrint("Stack: $st"); rethrow; }
  }
}
