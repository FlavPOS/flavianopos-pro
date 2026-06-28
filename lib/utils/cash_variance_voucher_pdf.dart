// lib/utils/cash_variance_voucher_pdf.dart
// Cash Variance Voucher PDF — for signature before IR

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/cashier_session_model.dart';
import '../models/incident_report_model.dart';
import '../models/settings_model.dart';

class CashVarianceVoucherPDF {
  static String _fmt(double v) {
    final c = AppSettings.currency;
    String prefix;
    if (c == 'PHP') {
      prefix = 'PHP ';
    } else if (c == 'USD') prefix = 'USD ';
    else if (c == 'SGD') prefix = 'SGD ';
    else prefix = AppSettings.currencySymbol;
    return prefix + v.toStringAsFixed(2);
  }

  static Future<void> generate({
    required BuildContext context,
    required CashierSession session,
    required double totalCounted,
    required double systemExpected,
    required double variance,
    required Map<double, int> denominations,
    bool isReprint = false,
    IncidentReport? incidentReport,
  }) async {
    try {
      final pdf = pw.Document();
      final business = AppSettings.businessName;
      final address = AppSettings.businessAddress;
      final tin = AppSettings.businessTin;
      final now = DateTime.now();
      final voucherNo = 'CVV-${now.year}${now.month.toString().padLeft(2, "0")}${now.day.toString().padLeft(2, "0")}-${now.hour.toString().padLeft(2, "0")}${now.minute.toString().padLeft(2, "0")}${now.second.toString().padLeft(2, "0")}';
      final varianceType = variance > 0 ? 'OVER' : 'SHORT';
      final isOver = variance > 0;

      // Sort denominations descending for display
      final sortedDenoms = denominations.entries.toList()
        ..sort((a, b) => b.key.compareTo(a.key));

      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (pw.Context ctx) => [
          // WATERMARK + FOOTER WIRED — Re-Print Copy banner
          if (isReprint)
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              margin: const pw.EdgeInsets.only(bottom: 12),
              decoration: pw.BoxDecoration(
                color: PdfColors.red700,
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Center(
                child: pw.Text(
                  '*** RE-PRINT COPY *** (NOT THE ORIGINAL)',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
          // HEADER
          pw.Center(child: pw.Column(children: [
            pw.Text(business, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            if (address.isNotEmpty) pw.Text(address, style: const pw.TextStyle(fontSize: 10)),
            if (tin.isNotEmpty) pw.Text(tin, style: const pw.TextStyle(fontSize: 9)),
            pw.SizedBox(height: 12),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: pw.BoxDecoration(
                color: variance.abs() < 0.01 ? PdfColors.green700 : (variance.abs() > 50 ? PdfColors.red700 : PdfColors.orange700),
                borderRadius: pw.BorderRadius.circular(20),
              ),
              child: pw.Text(variance.abs() < 0.01 ? 'CASH DECLARATION VOUCHER' : (variance.abs() > 50 ? 'CASH VARIANCE VOUCHER' : 'CASH DECLARATION VOUCHER'),
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
            ),
            pw.SizedBox(height: 4),
            pw.Text(variance.abs() > 50 ? '(Pre-Incident Report Document)' : (variance.abs() < 0.01 ? '(End of Shift - Balanced)' : '(End of Shift - Minor Variance)'),
              style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic, color: PdfColors.grey600)),
          ])),
          pw.SizedBox(height: 16),

          // Voucher Info
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: pw.BorderRadius.circular(6)),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              _row('Voucher #:', voucherNo),
              _row('Date:', '${now.year}-${now.month.toString().padLeft(2, "0")}-${now.day.toString().padLeft(2, "0")}'),
              _row('Time:', '${now.hour.toString().padLeft(2, "0")}:${now.minute.toString().padLeft(2, "0")}:${now.second.toString().padLeft(2, "0")}'),
              _row('Branch:', session.branch),
            ]),
          ),
          pw.SizedBox(height: 12),

          // Shift Details
          _section('SHIFT DETAILS', [
            _row('Cashier:', session.cashierName),
            _row('Shift ID:', session.shiftId.length > 40 ? '...${session.shiftId.substring(session.shiftId.length - 38)}' : session.shiftId),
            _row('Opened:', '${session.openedAt.year}-${session.openedAt.month.toString().padLeft(2, "0")}-${session.openedAt.day.toString().padLeft(2, "0")} ${session.openedAt.hour.toString().padLeft(2, "0")}:${session.openedAt.minute.toString().padLeft(2, "0")}'),
          ]),
          pw.SizedBox(height: 8),

          // Cash Reconciliation (COMPLETE - shows everything)
          _section('PAYMENT BREAKDOWN', [
            _row('Beginning Cash:', _fmt(session.beginningCash)),
            pw.SizedBox(height: 4),
            pw.Text('Sales by Payment Method:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
            _row('  💵 Cash Sales:', _fmt(session.cashSales)),
            _row('  📱 GCash Sales:', _fmt(session.gcashSales)),
            _row('  💳 Maya Sales:', _fmt(session.mayaSales)),
            _row('  💳 Card Sales:', _fmt(session.cardSales)),
            if (session.otherSales > 0) _row('  Other Sales:', _fmt(session.otherSales)),
            pw.Divider(thickness: 0.5),
            _row('Total Sales:', _fmt(session.totalSales), bold: true),
            pw.SizedBox(height: 6),
            pw.Text('Deductions:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
            _row('  Refunds:', '(${_fmt(session.totalRefunds)})'),
            _row('  Voids:', '(${_fmt(session.totalVoids)})'),
            _row('  Discounts:', '(${_fmt(session.totalDiscounts)})'),
            if (session.totalExchanges > 0) _row('  Exchanges:', '(${_fmt(session.totalExchanges)})'),
            pw.Divider(thickness: 0.5),
            _row('Transactions:', '${session.transactionCount}'),
          ]),

          // Cash Reconciliation (focuses on cash variance)
          _section('CASH RECONCILIATION', [
            _row('Beginning Cash:', _fmt(session.beginningCash)),
            _row('+ Cash Sales:', _fmt(session.cashSales)),
            _row('- Refunds:', '(${_fmt(session.totalRefunds)})'),
            pw.Divider(thickness: 0.5),
            _row('System Expected:', _fmt(systemExpected), bold: true),
            _row('Actual Counted:', _fmt(totalCounted), bold: true),
            pw.Divider(thickness: 0.5),
          ]),

          // Variance box (color-coded)
          pw.SizedBox(height: 4),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: isOver ? PdfColors.orange50 : PdfColors.red50,
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(color: isOver ? PdfColors.orange : PdfColors.red),
            ),
            child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('VARIANCE', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                pw.Text('Status: $varianceType',
                  style: pw.TextStyle(fontSize: 10, color: isOver ? PdfColors.orange800 : PdfColors.red800)),
              ]),
              pw.Text(
                (variance > 0 ? '+' : '') + _fmt(variance),
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                  color: isOver ? PdfColors.orange800 : PdfColors.red800,
                ),
              ),
            ]),
          ),
          pw.SizedBox(height: 14),

          // Denomination Breakdown (ALL PH denominations always shown!)
          _section('DENOMINATION BREAKDOWN', [
            pw.Text('Bills:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
            _denomRow('PHP 1000', 1000, denominations[1000] ?? 0),
            _denomRow('PHP 500',  500,  denominations[500] ?? 0),
            _denomRow('PHP 200',  200,  denominations[200] ?? 0),
            _denomRow('PHP 100',  100,  denominations[100] ?? 0),
            _denomRow('PHP 50',   50,   denominations[50] ?? 0),
            _denomRow('PHP 20',   20,   denominations[20] ?? 0),
            pw.SizedBox(height: 4),
            pw.Text('Coins:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
            _denomRow('PHP 10',     10,     denominations[10] ?? 0),
            _denomRow('PHP 5',      5,      denominations[5] ?? 0),
            _denomRow('PHP 1',      1,      denominations[1] ?? 0),
            _denomRow('PHP 0.25',   0.25,   denominations[0.25] ?? 0),
            _denomRow('PHP 0.10',   0.10,   denominations[0.10] ?? 0),
            _denomRow('PHP 0.05',   0.05,   denominations[0.05] ?? 0),
            pw.Divider(thickness: 0.5),
            _row('TOTAL COUNTED:', _fmt(totalCounted), bold: true),
          ]),
          pw.SizedBox(height: 20),

          // Signature blocks
          pw.Text('SIGNATURES', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 16),

          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            _signature('Prepared by', session.cashierName, 'Cashier'),
            _signature('Verified by', '', 'Vault Custodian'),
            _signature('Approved by', '', 'Manager'),
          ]),
          pw.SizedBox(height: 24),

          // Notes section
          // Reprint footer
          if (isReprint) _reprintFooter(),
        ],
      ));

      // ═══════ PAGE 2: NOTES / OBSERVATIONS / EXPLANATION ═══════
      // ONLY add Page 2 (Notes/Explanation) if there's a variance
      if (variance.abs() > 0.01) {
      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (pw.Context ctx) => [
          // WATERMARK + FOOTER WIRED — Re-Print Copy banner
          if (isReprint)
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              margin: const pw.EdgeInsets.only(bottom: 12),
              decoration: pw.BoxDecoration(
                color: PdfColors.red700,
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Center(
                child: pw.Text(
                  '*** RE-PRINT COPY *** (NOT THE ORIGINAL)',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
          // Header (compact for page 2)
          pw.Center(child: pw.Column(children: [
            pw.Text(business, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: pw.BoxDecoration(
                color: variance.abs() < 0.01 ? PdfColors.green700 : (variance.abs() > 50 ? PdfColors.red700 : PdfColors.orange700),
                borderRadius: pw.BorderRadius.circular(20),
              ),
              child: pw.Text('NOTES / OBSERVATIONS / EXPLANATION',
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
            ),
            pw.SizedBox(height: 6),
            pw.Text('Voucher #: $voucherNo',
              style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic)),
          ])),
          pw.SizedBox(height: 14),

          // Reference info (so reader knows which voucher this is)
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: pw.BorderRadius.circular(6)),
            child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('Cashier: ${session.cashierName}', style: const pw.TextStyle(fontSize: 10)),
                pw.Text('Branch: ${session.branch}', style: const pw.TextStyle(fontSize: 10)),
              ]),
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                pw.Text('Variance:', style: const pw.TextStyle(fontSize: 9)),
                pw.Text(
                  (variance > 0 ? '+' : '') + _fmt(variance),
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: isOver ? PdfColors.orange800 : PdfColors.red800,
                  ),
                ),
              ]),
            ]),
          ),
          pw.SizedBox(height: 16),

          // Instructions for filling out
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.amber50,
              border: pw.Border.all(color: PdfColors.amber200),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('INSTRUCTIONS',
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.amber800)),
              pw.SizedBox(height: 4),
              pw.Text('Please provide detailed explanation of the variance below.',
                style: const pw.TextStyle(fontSize: 9)),
              pw.Text('Include: timeline, possible causes, witnesses, corrective actions.',
                style: const pw.TextStyle(fontSize: 9)),
            ]),
          ),
          pw.SizedBox(height: 14),

          // Explanation (large writing area)
          pw.Text('EXPLANATION OF VARIANCE:',
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400)),
            child: pw.Column(children: List.generate(8, (i) =>
              pw.Container(
                height: 18,
                decoration: pw.BoxDecoration(
                  border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400, width: 0.3))
                ),
              )
            )),
          ),
          pw.SizedBox(height: 16),

          // Action Taken / Corrective Measures
          pw.Text('ACTION TAKEN / CORRECTIVE MEASURES:',
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400)),
            child: pw.Column(children: List.generate(5, (i) =>
              pw.Container(
                height: 18,
                decoration: pw.BoxDecoration(
                  border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400, width: 0.3))
                ),
              )
            )),
          ),
          pw.SizedBox(height: 16),

          // Witnesses
          pw.Text('WITNESS(ES) - if any:',
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400)),
            child: pw.Column(children: List.generate(3, (i) =>
              pw.Container(
                height: 18,
                decoration: pw.BoxDecoration(
                  border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400, width: 0.3))
                ),
              )
            )),
          ),
          pw.SizedBox(height: 20),

          // Re-confirmation signatures
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Column(children: [
              pw.SizedBox(height: 25),
              pw.Container(width: 150, height: 0.5, color: PdfColors.black),
              pw.SizedBox(height: 2),
              pw.Text(session.cashierName, style: const pw.TextStyle(fontSize: 9)),
              pw.Text('Cashier Signature', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
              pw.Text('Date: __________', style: const pw.TextStyle(fontSize: 8)),
            ]),
            pw.Column(children: [
              pw.SizedBox(height: 25),
              pw.Container(width: 150, height: 0.5, color: PdfColors.black),
              pw.SizedBox(height: 2),
              pw.Text('_______________', style: const pw.TextStyle(fontSize: 9)),
              pw.Text('Manager Signature', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
              pw.Text('Date: __________', style: const pw.TextStyle(fontSize: 8)),
            ]),
          ]),
          pw.SizedBox(height: 20),

          // Page 2 Footer
          pw.Divider(),
          pw.Center(child: pw.Text(
            'Page 2 of 2 | Voucher #: $voucherNo',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          )),
          pw.SizedBox(height: 2),
          pw.Center(child: pw.Text(
            'Generated by FlavianoPOS PRO | Submit with Page 1 for processing',
            style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic, color: PdfColors.grey600),
          )),
          // Footer
          pw.Divider(),
          pw.Center(child: pw.Text(
            'Generated by FlavianoPOS PRO | $voucherNo',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          )),
          pw.SizedBox(height: 4),
          pw.Center(child: pw.Text(
            'This voucher must be signed by all parties before submitting Incident Report.',
            style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic, color: PdfColors.grey600),
          )),
        ],
      ));
      } // end if variance > 0.01

      // INCIDENT REPORT PAGE — Page 3, only if incidentReport != null
      if (incidentReport != null) {
        final ir = incidentReport;
        pdf.addPage(pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(28),
          build: (pw.Context ctx) => [
            // Reprint banner (if reprint)
            if (isReprint)
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                margin: const pw.EdgeInsets.only(bottom: 12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.red700,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Center(
                  child: pw.Text(
                    '*** RE-PRINT COPY *** (NOT THE ORIGINAL)',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),

            // IR HEADER
            pw.Center(child: pw.Column(children: [
              pw.Text(business, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              if (address.isNotEmpty) pw.Text(address, style: const pw.TextStyle(fontSize: 9)),
              pw.SizedBox(height: 10),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: pw.BoxDecoration(
                  color: PdfColors.red800,
                  borderRadius: pw.BorderRadius.circular(20),
                ),
                child: pw.Text('INCIDENT REPORT',
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
              ),
              pw.SizedBox(height: 6),
              pw.Text('(Official Audit Document - BIR)',
                style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic, color: PdfColors.grey600)),
            ])),
            pw.SizedBox(height: 16),

            // IR Info Box
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: pw.BorderRadius.circular(6)),
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                _row('IR Number:', ir.irNumber),
                _row('Status:', ir.status.toUpperCase()),
                _row('Created:', '${ir.createdAt.year}-${ir.createdAt.month.toString().padLeft(2, "0")}-${ir.createdAt.day.toString().padLeft(2, "0")} ${ir.createdAt.hour.toString().padLeft(2, "0")}:${ir.createdAt.minute.toString().padLeft(2, "0")}'),
                _row('Linked Shift:', ir.sessionId.length > 30 ? '...${ir.sessionId.substring(ir.sessionId.length - 28)}' : ir.sessionId),
                _row('Cashier:', ir.cashierName.isEmpty ? 'N/A' : ir.cashierName),
                _row('Branch:', ir.branch.isEmpty ? 'N/A' : ir.branch),
              ]),
            ),
            pw.SizedBox(height: 14),

            // Variance Details
            _section('VARIANCE DETAILS', [
              _row('Amount:', 'PHP ${ir.variance.abs().toStringAsFixed(2)}', bold: true),
              _row('Type:', ir.varianceType.toUpperCase(), bold: true),
            ]),
            pw.SizedBox(height: 8),

            // Reason
            _section('REASON', [
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400)),
                child: pw.Text(
                  ir.reason.isEmpty ? '(No reason provided)' : ir.reason,
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ),
            ]),
            pw.SizedBox(height: 8),

            // Remarks (with Re-Declare audit trail!)
            if (ir.remarks.isNotEmpty)
              _section('REMARKS & AUDIT TRAIL', [
                pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400)),
                  child: pw.Text(
                    ir.remarks,
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ),
              ]),
            pw.SizedBox(height: 14),

            // Audit Info
            _section('AUDIT INFORMATION', [
              _row('Filed by:', ir.createdBy.isEmpty ? '(Unknown)' : ir.createdBy),
              if (ir.approvedBy.isNotEmpty) _row('Approved by:', ir.approvedBy),
              if (ir.approvedAt != null) _row('Approved at:', '${ir.approvedAt!.year}-${ir.approvedAt!.month.toString().padLeft(2, "0")}-${ir.approvedAt!.day.toString().padLeft(2, "0")} ${ir.approvedAt!.hour.toString().padLeft(2, "0")}:${ir.approvedAt!.minute.toString().padLeft(2, "0")}'),
            ]),
            pw.SizedBox(height: 20),

            // Signature blocks
            pw.Text('SIGNATURES', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 16),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              _signature('Filed by', ir.createdBy.isEmpty ? '_____________' : ir.createdBy, 'Cashier / Staff'),
              _signature('Reviewed by', '_____________', 'Manager'),
              _signature('Approved by', ir.approvedBy.isEmpty ? '_____________' : ir.approvedBy, 'Vault Custodian'),
            ]),
            pw.SizedBox(height: 16),

            // Reprint footer
            if (isReprint) _reprintFooter(),

            // Page Footer
            pw.SizedBox(height: 12),
            pw.Divider(),
            pw.Center(child: pw.Text(
              'Page 3 of 3 | ${ir.irNumber}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
            )),
            pw.Center(child: pw.Text(
              'Generated by FlavianoPOS PRO | BIR-Audit Compliant',
              style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic, color: PdfColors.grey600),
            )),
          ],
        ));
      }

      final bytes = await pdf.save();
      await Printing.sharePdf(bytes: bytes, filename: 'CashVariance_$voucherNo.pdf');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Voucher error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  static pw.Widget _row(String label, String value, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 10, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        pw.Text(value, style: pw.TextStyle(fontSize: 10, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
      ]),
    );
  }

  static pw.Widget _denomRow(String label, double denom, int qty) {
    final lineTotal = denom * qty;
    final isZero = qty == 0;
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(children: [
        pw.SizedBox(width: 12),
        pw.Container(width: 60, child: pw.Text(label, style: pw.TextStyle(fontSize: 9, color: isZero ? PdfColors.grey500 : PdfColors.black))),
        pw.Text(' × ', style: pw.TextStyle(fontSize: 9, color: isZero ? PdfColors.grey400 : PdfColors.black)),
        pw.Container(width: 30, child: pw.Text('$qty', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: isZero ? PdfColors.grey400 : PdfColors.black))),
        pw.Text(' = ', style: pw.TextStyle(fontSize: 9, color: isZero ? PdfColors.grey400 : PdfColors.black)),
        pw.Expanded(child: pw.Text(
          isZero ? 'PHP 0.00' : 'PHP ${lineTotal.toStringAsFixed(2)}',
          textAlign: pw.TextAlign.right,
          style: pw.TextStyle(fontSize: 9, color: isZero ? PdfColors.grey400 : PdfColors.black),
        )),
      ]),
    );
  }


  // RE-PRINT WATERMARK — adds diagonal "RE-PRINT COPY" overlay on each page
  static pw.Widget _watermarkOverlay() {
    return pw.Positioned.fill(
      child: pw.Center(
        child: pw.Transform.rotate(
          angle: -0.6,
          child: pw.Opacity(
            opacity: 0.15,
            child: pw.Text(
              'RE-PRINT COPY',
              style: pw.TextStyle(
                fontSize: 90,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.red700,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // RE-PRINT FOOTER — "Please attach to Original Copy" message
  static pw.Widget _reprintFooter() {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 12),
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: PdfColors.red50,
        border: pw.Border.all(color: PdfColors.red700, width: 1.5),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Text(
            'PLEASE ATTACH THIS TO ORIGINAL COPY',
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.red900,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }
  static pw.Widget _section(String title, List<pw.Widget> items) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 6),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          color: PdfColors.grey300,
          child: pw.Text(title, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        ),
        pw.SizedBox(height: 4),
        pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 8), child: pw.Column(children: items)),
      ]),
    );
  }

  static pw.Widget _signature(String role, String name, String position) {
    return pw.Container(
      width: 150,
      child: pw.Column(children: [
        pw.Text(role.toUpperCase(), style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
        pw.SizedBox(height: 30),
        pw.Container(width: 130, height: 0.5, color: PdfColors.black),
        pw.SizedBox(height: 4),
        pw.Text(name.isEmpty ? '_______________' : name, style: const pw.TextStyle(fontSize: 9)),
        pw.Text(position, style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
        pw.SizedBox(height: 8),
        pw.Text('Date: __________', style: const pw.TextStyle(fontSize: 8)),
      ]),
    );
  }
}
