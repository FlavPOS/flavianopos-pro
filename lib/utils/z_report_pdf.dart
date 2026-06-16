import 'dart:typed_data';
// // import 'dart:convert';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
// // import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/z_report_model.dart';
import 'web_download.dart' if (dart.library.io) 'web_download_stub.dart';

pw.Widget zDivider() {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2),
    child: pw.Center(child: pw.Text(
      '- - - - - - - - - - - - - - - - - - - - - - -',
      style: const pw.TextStyle(fontSize: 7),
    )),
  );
}

pw.Widget zSection(String title) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(top: 4, bottom: 2),
    child: pw.Text(title, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
  );
}

pw.Widget zRow(String label, String value, {bool bold = false}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 1),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 9,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        pw.Text(value, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
      ],
    ),
  );
}

pw.Widget zHeader(String branch, String cashier, DateTime date, bool gen) {
  return pw.Column(children: [
    pw.Center(child: pw.Text('Z REPORT',
      style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold))),
    pw.Center(child: pw.Text(gen ? 'END OF DAY' : 'PREVIEW',
      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
    pw.SizedBox(height: 4),
    pw.Center(child: pw.Text(branch,
      style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold))),
    pw.SizedBox(height: 2),
    pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
      pw.Text('Cashier: $cashier', style: const pw.TextStyle(fontSize: 9)),
      pw.Text('${date.month}/${date.day}/${date.year}', style: const pw.TextStyle(fontSize: 9)),
    ]),
    pw.SizedBox(height: 4),
  ]);
}

pw.Widget zOverShort(double val) {
  String label = val == 0 ? 'BALANCED' : val > 0 ? 'OVER' : 'SHORT';
  return pw.Container(
    padding: const pw.EdgeInsets.all(6),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(width: 0.5),
      borderRadius: pw.BorderRadius.circular(4),
    ),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
        pw.Text(val.abs().toStringAsFixed(2),
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
      ],
    ),
  );
}

class ZReportPdf {
  static Future<Uint8List> _buildPdfBytes({
    required String branch,
    required String cashier,
    required DateTime reportDate,
    required double grossSales,
    required double totalDiscount,
    required double netSales,
    required int totalTransactions,
    required double averageTransaction,
    required Map<String, Map<String, dynamic>> paymentBreakdown,
    required int voidedCount,
    required double voidedAmount,
    required List<Map<String, dynamic>> voidedList,
    required double beginningCash,
    required double expectedCash,
    required double endingCash,
    required double overShort,
    required List<Map<String, dynamic>> transactions,
    required bool isGenerated,
  }) async {
    final pdf = pw.Document();
    final List<pw.Widget> w = [];

    w.add(zHeader(branch, cashier, reportDate, isGenerated));
    w.add(zDivider());
    w.add(zSection('SALES SUMMARY'));
    w.add(zRow('Gross Sales', grossSales.toStringAsFixed(2)));
    w.add(zRow('Less: Discounts', '-${totalDiscount.toStringAsFixed(2)}'));
    w.add(zDivider());
    w.add(zRow('NET SALES', netSales.toStringAsFixed(2), bold: true));
    w.add(zRow('Total TXN', '$totalTransactions'));
    w.add(zRow('Avg/TXN', averageTransaction.toStringAsFixed(2)));
    w.add(pw.SizedBox(height: 4));
    w.add(zDivider());
    w.add(zSection('PAYMENT BREAKDOWN'));
    for (final e in paymentBreakdown.entries) {
      final cnt = e.value['count'];
      final tot = (e.value['total'] as double).toStringAsFixed(2);
      w.add(zRow('${e.key} ($cnt)', tot));
    }
    w.add(zDivider());
    w.add(zRow('TOTAL', netSales.toStringAsFixed(2), bold: true));
    w.add(pw.SizedBox(height: 4));
    w.add(zDivider());
    w.add(zSection('VOIDED TRANSACTIONS'));
    w.add(zRow('Count', '$voidedCount'));
    w.add(zRow('Amount', voidedAmount.toStringAsFixed(2)));
    for (final v in voidedList) {
      final vid = v['id'] as String;
      final vr = v['reason'] as String;
      final va = (v['amount'] as double).toStringAsFixed(2);
      w.add(pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 1),
        child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Expanded(child: pw.Text('$vid - $vr', style: const pw.TextStyle(fontSize: 7))),
          pw.Text(va, style: const pw.TextStyle(fontSize: 7)),
        ]),
      ));
    }
    w.add(pw.SizedBox(height: 4));
    w.add(zDivider());
    w.add(zSection('CASH COUNT'));
    w.add(zRow('Beginning Cash', beginningCash.toStringAsFixed(2)));
    w.add(zRow('Cash Sales', '+${(expectedCash - beginningCash).toStringAsFixed(2)}'));
    w.add(zRow('Expected Cash', expectedCash.toStringAsFixed(2), bold: true));
    w.add(zRow('Ending Cash', endingCash.toStringAsFixed(2)));
    w.add(zDivider());
    w.add(zOverShort(overShort));
    w.add(pw.SizedBox(height: 4));
    w.add(zDivider());
    w.add(zSection('TRANSACTION LOG (${transactions.length})'));
    w.add(pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 0.5))),
      child: pw.Row(children: [
        pw.Expanded(flex: 3, child: pw.Text('TXN ID', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold))),
        pw.Expanded(flex: 2, child: pw.Text('Time', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center)),
        pw.Expanded(flex: 2, child: pw.Text('Pay', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center)),
        pw.Expanded(flex: 2, child: pw.Text('Amount', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
      ]),
    ));
    for (final t in transactions) {
      final dt = t['dateTime'] as DateTime;
      final st = t['status'] as String;
      final tid = t['id'] as String;
      final pay = t['payment'] as String;
      final amt = (t['amount'] as double).toStringAsFixed(2);
      final pre = st == 'voided' ? 'X ' : '';
      final hh = dt.hour.toString();
      final mm = dt.minute.toString().padLeft(2, '0');
      w.add(pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 1),
        child: pw.Row(children: [
          pw.Expanded(flex: 3, child: pw.Text('$pre$tid', style: const pw.TextStyle(fontSize: 7))),
          pw.Expanded(flex: 2, child: pw.Text('$hh:$mm', style: const pw.TextStyle(fontSize: 7), textAlign: pw.TextAlign.center)),
          pw.Expanded(flex: 2, child: pw.Text(pay, style: const pw.TextStyle(fontSize: 7), textAlign: pw.TextAlign.center)),
          pw.Expanded(flex: 2, child: pw.Text(amt, style: const pw.TextStyle(fontSize: 7), textAlign: pw.TextAlign.right)),
        ]),
      ));
    }
    w.add(pw.SizedBox(height: 6));
    w.add(zDivider());
    w.add(pw.SizedBox(height: 4));
    w.add(pw.Center(child: pw.Text(isGenerated ? 'Z REPORT GENERATED' : 'Z REPORT PREVIEW',
      style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))));
    final rdm = reportDate.month;
    final rdd = reportDate.day;
    final rdy = reportDate.year;
    final rdh = reportDate.hour;
    final rdmin = reportDate.minute.toString().padLeft(2, '0');
    w.add(pw.Center(child: pw.Text('$rdm/$rdd/$rdy $rdh:$rdmin', style: const pw.TextStyle(fontSize: 7))));
    w.add(pw.SizedBox(height: 4));
    w.add(zDivider());
    w.add(pw.SizedBox(height: 4));
    w.add(pw.Center(child: pw.Text('*** END OF Z REPORT ***', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))));
    w.add(pw.Center(child: pw.Text('Powered by FlavianoPOS - PRO', style: const pw.TextStyle(fontSize: 7))));

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      build: (context) => w,
    ));
    return pdf.save();
  }

  static Future<void> printCurrentDay({
    required String branch,
    required String cashier,
    required DateTime reportDate,
    required double grossSales,
    required double totalDiscount,
    required double netSales,
    required int totalTransactions,
    required double averageTransaction,
    required Map<String, Map<String, dynamic>> paymentBreakdown,
    required int voidedCount,
    required double voidedAmount,
    required List<Map<String, dynamic>> voidedList,
    required double beginningCash,
    required double expectedCash,
    required double endingCash,
    required double overShort,
    required List<Map<String, dynamic>> transactions,
    required bool isGenerated,
  }) async {
    final bytes = await _buildPdfBytes(
      branch: branch, cashier: cashier, reportDate: reportDate,
      grossSales: grossSales, totalDiscount: totalDiscount,
      netSales: netSales, totalTransactions: totalTransactions,
      averageTransaction: averageTransaction, paymentBreakdown: paymentBreakdown,
      voidedCount: voidedCount, voidedAmount: voidedAmount,
      voidedList: voidedList, beginningCash: beginningCash,
      expectedCash: expectedCash, endingCash: endingCash,
      overShort: overShort, transactions: transactions,
      isGenerated: isGenerated,
    );
    final name = 'Z-Report-${reportDate.month}-${reportDate.day}-${reportDate.year}.pdf';
    downloadPdf(bytes, name);
  }

  static Future<void> printFromRecord(ZReportRecord r) async {
    final paymentMap = <String, Map<String, dynamic>>{};
    for (final p in r.paymentBreakdown) {
      paymentMap[p.method] = {'count': p.count, 'total': p.total};
    }
    final vList = <Map<String, dynamic>>[];
    for (final v in r.voidedTransactions) {
      vList.add({'id': v.txnId, 'reason': v.reason, 'amount': v.amount});
    }
    final tList = <Map<String, dynamic>>[];
    for (final t in r.transactionLog) {
      tList.add({'id': t.txnId, 'dateTime': t.dateTime, 'payment': t.paymentMethod, 'amount': t.amount, 'status': t.status});
    }
    await printCurrentDay(
      branch: r.branch, cashier: r.cashier, reportDate: r.generatedAt,
      grossSales: r.grossSales, totalDiscount: r.totalDiscount,
      netSales: r.netSales, totalTransactions: r.totalTransactions,
      averageTransaction: r.averageTransaction, paymentBreakdown: paymentMap,
      voidedCount: r.voidedCount, voidedAmount: r.voidedAmount,
      voidedList: vList, beginningCash: r.beginningCash,
      expectedCash: r.expectedCash, endingCash: r.endingCash,
      overShort: r.overShort, transactions: tList, isGenerated: true,
    );
  }
}
