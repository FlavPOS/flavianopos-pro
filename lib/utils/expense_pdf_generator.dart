import 'dart:typed_data';
import 'dart:convert';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/settings_model.dart';
import '../models/expense_model.dart';

class ExpensePdfGenerator {
  static Future<Uint8List> generate(Expense e, {String? companyName}) async {
    final cName = companyName ?? AppSettings.businessName;
    final pdf = pw.Document(title: 'Expense Voucher ${e.expenseNumber}', author: e.preparedBy);

    pw.MemoryImage? attachmentImage;
    if (e.attachmentPath.isNotEmpty &&
        ['jpg', 'jpeg', 'png'].contains(e.attachmentType.toLowerCase())) {
      try { attachmentImage = pw.MemoryImage(base64Decode(e.attachmentPath)); } catch (_) {}
    }

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (pw.Context ctx) {
        return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          _buildHeader(cName, e),
          pw.SizedBox(height: 16),
          pw.Divider(thickness: 2, color: PdfColors.purple700),
          pw.SizedBox(height: 12),
          pw.Center(child: pw.Text('EXPENSE VOUCHER',
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold,
              color: PdfColors.purple800, letterSpacing: 2))),
          pw.SizedBox(height: 16),
          _buildInfoBox(e),
          pw.SizedBox(height: 14),
          _buildDetailsTable(e),
          pw.SizedBox(height: 14),
          if (e.remarks.isNotEmpty) ...[
            _buildRemarks(e),
            pw.SizedBox(height: 14),
          ],
          if (attachmentImage != null) ...[
            pw.Text('Attachment: ${e.attachmentFileName}',
              style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic)),
            pw.SizedBox(height: 6),
            pw.Container(height: 120,
              decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400)),
              child: pw.Image(attachmentImage, fit: pw.BoxFit.contain)),
            pw.SizedBox(height: 14),
          ] else if (e.attachmentFileName.isNotEmpty) ...[
            pw.Text('Attachment on file: ${e.attachmentFileName}',
              style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic)),
            pw.SizedBox(height: 14),
          ],
          pw.Spacer(),
          _buildSignatures(e),
          pw.SizedBox(height: 12),
          _buildFooter(e),
        ]);
      },
    ));
    return pdf.save();
  }

  static pw.Widget _buildHeader(String company, Expense e) {
    return pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text(company, style: pw.TextStyle(fontSize: 20,
          fontWeight: pw.FontWeight.bold, color: PdfColors.purple800)),
        pw.SizedBox(height: 2),
        pw.Text('Branch: ${e.branch}', style: const pw.TextStyle(fontSize: 10)),
        pw.Text('Department: ${e.department.isEmpty ? "N/A" : e.department}',
          style: const pw.TextStyle(fontSize: 10)),
      ]),
      pw.Container(padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.purple700, width: 1.5),
          borderRadius: pw.BorderRadius.circular(4)),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          pw.Text('VOUCHER NO.', style: pw.TextStyle(fontSize: 9,
            fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
          pw.Text(e.expenseNumber, style: pw.TextStyle(fontSize: 14,
            fontWeight: pw.FontWeight.bold, color: PdfColors.purple900)),
          pw.SizedBox(height: 4),
          pw.Text('Date: ${e.expenseDate}', style: const pw.TextStyle(fontSize: 10)),
        ])),
    ]);
  }

  static pw.Widget _buildInfoBox(Expense e) {
    final statusColor = e.status == 'Approved' ? PdfColors.green700
        : e.status == 'Pending Approval' ? PdfColors.orange700
        : e.status == 'Rejected' ? PdfColors.red700 : PdfColors.grey700;
    return pw.Container(padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(color: PdfColors.purple50,
        border: pw.Border.all(color: PdfColors.purple200),
        borderRadius: pw.BorderRadius.circular(6)),
      child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text('AMOUNT', style: pw.TextStyle(fontSize: 9,
            color: PdfColors.grey700, fontWeight: pw.FontWeight.bold)),
          pw.Text('PHP ${e.amount.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 20,
            fontWeight: pw.FontWeight.bold, color: PdfColors.purple900)),
        ]),
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          pw.Text('STATUS', style: pw.TextStyle(fontSize: 9,
            color: PdfColors.grey700, fontWeight: pw.FontWeight.bold)),
          pw.Container(padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: pw.BoxDecoration(color: statusColor,
              borderRadius: pw.BorderRadius.circular(12)),
            child: pw.Text(e.status.toUpperCase(), style: pw.TextStyle(fontSize: 10,
              color: PdfColors.white, fontWeight: pw.FontWeight.bold))),
          pw.SizedBox(height: 4),
          pw.Text('Priority: ${e.priority}', style: const pw.TextStyle(fontSize: 9)),
        ]),
      ]),
    );
  }

  static pw.Widget _buildDetailsTable(Expense e) {
    final rows = [
      ['Category', e.categoryName],
      ['Sub-Category', e.subCategoryName],
      ['Expense Type', e.expenseType],
      ['Payment Method', e.paymentMethod],
      ['Payee / Supplier', e.payeeSupplier.isEmpty ? 'N/A' : e.payeeSupplier],
      ['Reference No.', e.referenceNumber.isEmpty ? 'N/A' : e.referenceNumber],
    ];
    return pw.Table(border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: {0: const pw.FlexColumnWidth(1.2), 1: const pw.FlexColumnWidth(2)},
      children: rows.map((r) => pw.TableRow(children: [
        pw.Container(color: PdfColors.grey100, padding: const pw.EdgeInsets.all(6),
          child: pw.Text(r[0], style: pw.TextStyle(fontSize: 10,
            fontWeight: pw.FontWeight.bold))),
        pw.Container(padding: const pw.EdgeInsets.all(6),
          child: pw.Text(r[1], style: const pw.TextStyle(fontSize: 10))),
      ])).toList());
  }

  static pw.Widget _buildRemarks(Expense e) {
    return pw.Container(width: double.infinity, padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
        borderRadius: pw.BorderRadius.circular(4)),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text('REMARKS / PURPOSE:', style: pw.TextStyle(fontSize: 9,
          fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
        pw.SizedBox(height: 4),
        pw.Text(e.remarks, style: const pw.TextStyle(fontSize: 10)),
      ]));
  }

  static pw.Widget _buildSignatures(Expense e) {
    return pw.Column(children: [
      pw.Divider(color: PdfColors.grey400),
      pw.SizedBox(height: 8),
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        _sigBlock('PREPARED BY', e.preparedBy,
          e.dateCreated.isEmpty ? '___________' : e.dateCreated.split('T').first),
        _sigBlock('CHECKED BY',
          e.checkedBy.isEmpty ? '_______________' : e.checkedBy,
          e.checkedDate.isEmpty ? '___________' : e.checkedDate.split('T').first),
        _sigBlock('APPROVED BY',
          e.approvedBy.isEmpty ? '_______________' : e.approvedBy,
          e.approvedDate.isEmpty ? '___________' : e.approvedDate.split('T').first),
      ]),
    ]);
  }

  static pw.Widget _sigBlock(String label, String name, String date) {
    return pw.Container(width: 150,
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
        pw.SizedBox(height: 30),
        pw.Container(width: 140, height: 1, color: PdfColors.black),
        pw.SizedBox(height: 4),
        pw.Text(name, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        pw.Text(label, style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700,
          fontWeight: pw.FontWeight.bold, letterSpacing: 1)),
        pw.SizedBox(height: 2),
        pw.Text('Date: $date', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
      ]));
  }

  static pw.Widget _buildFooter(Expense e) {
    return pw.Column(children: [
      pw.Divider(color: PdfColors.grey300),
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text('Generated: ${DateTime.now().toString().split('.').first}',
          style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
        pw.Text('FlavianoPOS PRO - Expense Voucher',
          style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
      ]),
    ]);
  }

  static Future<void> printVoucher(Expense e, {String? companyName}) async {
    final bytes = await generate(e, companyName: companyName ?? AppSettings.businessName);
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  static Future<void> shareVoucher(Expense e, {String? companyName}) async {
    final bytes = await generate(e, companyName: companyName ?? AppSettings.businessName);
    await Printing.sharePdf(bytes: bytes, filename: 'Expense-${e.expenseNumber}.pdf');
  }
}
