// lib/utils/profit_loss_export.dart
// COMPLETE Export with ALL sections including Industry Benchmarks
// and Annual Summary

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:excel/excel.dart' as xl;
import '../models/profit_loss_model.dart';
import '../models/settings_model.dart';
import 'download_helper.dart';

class ProfitLossExport {
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
  static String _pct(double v) => '${v.toStringAsFixed(1)}%';

  // ═══════════════════ PDF SUMMARY ═══════════════════
  static Future<void> exportSummaryPDF(BuildContext context, PLReport report, {String? preparedBy}) async {
    try {
      final pdf = pw.Document();
      final business = AppSettings.businessName;
      final address = AppSettings.businessAddress;
      final tin = AppSettings.businessTin;
      String dateFmt(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (pw.Context ctx) => [
          // HEADER
          pw.Center(child: pw.Column(children: [
            pw.Text(business, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            if (address.isNotEmpty) pw.Text(address, style: const pw.TextStyle(fontSize: 10)),
            if (tin.isNotEmpty) pw.Text(tin, style: const pw.TextStyle(fontSize: 9)),
            pw.SizedBox(height: 8),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: pw.BoxDecoration(color: PdfColors.purple700, borderRadius: pw.BorderRadius.circular(20)),
              child: pw.Text('PROFIT & LOSS STATEMENT',
                style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
            ),
            pw.SizedBox(height: 6),
            pw.Text('Period: ${dateFmt(report.periodStart)} to ${dateFmt(report.periodEnd)}',
              style: const pw.TextStyle(fontSize: 11)),
            pw.Text('Branch: ${report.branchFilter}', style: const pw.TextStyle(fontSize: 10)),
          ])),
          pw.SizedBox(height: 16),
          pw.Divider(thickness: 1),

          // SALES SUMMARY
          _pdfSection('SALES SUMMARY', [
            _pdfRow('Gross Sales', _fmt(report.grossSales)),
            _pdfRow('Less: Discounts', '(${_fmt(report.totalDiscounts)})'),
            _pdfRow('Less: Refunds', '(${_fmt(report.totalRefunds)})'),
            _pdfRow('Less: Voided', '(${_fmt(report.totalVoided)})'),
            _pdfRowDivider(),
            _pdfRow('Net Sales (Revenue)', _fmt(report.netSales), bold: true),
            _pdfRow('Transactions: ${report.transactionCount}', 'Avg: ${_fmt(report.averageSale)}', small: true),
          ]),

          // COGS
          _pdfSection('COST OF GOODS SOLD', [
            _pdfRow('COGS', _fmt(report.cogs)),
            _pdfRow('COGS % of Sales', _pct(report.netSales > 0 ? (report.cogs / report.netSales) * 100 : 0)),
          ]),

          // GROSS PROFIT
          _pdfSection('GROSS PROFIT', [
            _pdfRow('Net Sales', _fmt(report.netSales)),
            _pdfRow('- COGS', _fmt(report.cogs)),
            _pdfRowDivider(),
            _pdfRow('Gross Profit', _fmt(report.grossProfit), bold: true),
            _pdfRow('Gross Margin', _pct(report.grossMargin), bold: true),
          ]),

          // SHRINKAGE
          if (report.shrinkageByReason.isNotEmpty) _pdfSection(
            'SHRINKAGE BREAKDOWN BY REASON (${_pct(report.shrinkageRate)} of Revenue)',
            [
              ...report.shrinkageByReason.entries.map((e) {
                final pctS = report.totalShrinkage > 0 ? (e.value / report.totalShrinkage) * 100 : 0;
                final pctR = report.netSales > 0 ? (e.value / report.netSales) * 100 : 0;
                return _pdfRow3(e.key, _fmt(e.value), '${_pct(pctS.toDouble())} | ${_pct(pctR.toDouble())}');
              }),
              _pdfRowDivider(),
              _pdfRow('TOTAL SHRINKAGE', _fmt(report.totalShrinkage), bold: true),
            ],
          ),

          // EXPENSES
          if (report.expensesByCategory.isNotEmpty) _pdfSection(
            'OPERATING EXPENSES BY CATEGORY (${_pct(report.operatingExpenseRate)} of Revenue)',
            [
              ...report.expensesByCategory.entries.expand((cat) {
                final catTotal = cat.value.values.fold<double>(0, (a, b) => a + b);
                return [
                  _pdfRow(cat.key, _fmt(catTotal), bold: true),
                  ...cat.value.entries.map((sub) => _pdfRow('   - ${sub.key}', _fmt(sub.value), small: true)),
                ];
              }),
              _pdfRowDivider(),
              _pdfRow('TOTAL EXPENSES', _fmt(report.totalOperatingExpenses), bold: true),
            ],
          ),

          // NET PROFIT
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: report.isProfit ? PdfColors.green700 : PdfColors.red700,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('NET PROFIT', style: pw.TextStyle(fontSize: 11, color: PdfColors.white, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text(_fmt(report.netProfit), style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: pw.BoxDecoration(color: PdfColors.white, borderRadius: pw.BorderRadius.circular(12)),
                  child: pw.Text('Margin: ${_pct(report.netMargin)}',
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold,
                      color: report.isProfit ? PdfColors.green700 : PdfColors.red700)),
                ),
              ]),
            ]),
          ),


          // NET PROFIT CALCULATION (Breakdown)
          pw.SizedBox(height: 8),
          _pdfSection('NET PROFIT CALCULATION', [
            _pdfRow('Gross Profit', _fmt(report.grossProfit)),
            _pdfRow('- Shrinkage', '(${_fmt(report.totalShrinkage)})'),
            _pdfRow('- Operating Expenses', '(${_fmt(report.totalOperatingExpenses)})'),
            _pdfRowDivider(),
            _pdfRow('NET PROFIT', _fmt(report.netProfit), bold: true),
            _pdfRow('Net Margin', _pct(report.netMargin), bold: true),
          ]),

          // KEY METRICS vs INDUSTRY
          pw.SizedBox(height: 14),
          _pdfMetricsCard(report),

          // SIGNATURES
          pw.SizedBox(height: 30),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            _pdfSignature('Prepared By', preparedBy ?? ''),
            _pdfSignature('Reviewed By', ''),
            _pdfSignature('Approved By', ''),
          ]),

          // FOOTER
          pw.SizedBox(height: 16),
          pw.Divider(),
          pw.Center(child: pw.Text(
            'Generated by FlavianoPOS PRO | ${DateTime.now().toString().split('.')[0]}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          )),
        ],
      ));

      final bytes = await pdf.save();
      await Printing.sharePdf(bytes: bytes, filename: 'PL_${dateFmt(report.periodStart)}_to_${dateFmt(report.periodEnd)}.pdf');
    } catch (e) {
      _showError(context, 'PDF export failed: $e');
    }
  }

  // ═══════════════════ PDF MONTHLY ═══════════════════
  static Future<void> exportMonthlyPDF(BuildContext context, AnnualPLReport report) async {
    try {
      final pdf = pw.Document();
      final business = AppSettings.businessName;

      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (pw.Context ctx) => [
          // HEADER
          pw.Center(child: pw.Column(children: [
            pw.Text(business, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: pw.BoxDecoration(color: PdfColors.purple700, borderRadius: pw.BorderRadius.circular(20)),
              child: pw.Text('ANNUAL P&L STATEMENT - ${report.year}',
                style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
            ),
          ])),
          pw.SizedBox(height: 16),

          // TABLE
          pw.Table.fromTextArray(
            headerStyle: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.purple700),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerRight,
              2: pw.Alignment.centerRight,
              3: pw.Alignment.centerRight,
              4: pw.Alignment.centerRight,
              5: pw.Alignment.centerRight,
            },
            headers: ['Month', 'Revenue', 'COGS', 'Shrinkage', 'Expenses', 'Net Profit'],
            data: [
              ...report.months.map((m) => [
                m.monthName,
                _fmt(m.revenue),
                _fmt(m.cogs),
                _fmt(m.shrinkage),
                _fmt(m.expenses),
                _fmt(m.netProfit),
              ]),
              ['TOTAL', _fmt(report.totalRevenue), _fmt(report.totalCogs),
                _fmt(report.totalShrinkage), _fmt(report.totalExpenses), _fmt(report.totalNetProfit)],
              ['AVG/Month', _fmt(report.avgRevenue), _fmt(report.totalCogs / 12),
                _fmt(report.totalShrinkage / 12), _fmt(report.totalExpenses / 12), _fmt(report.avgNetProfit)],
            ],
          ),

          pw.SizedBox(height: 16),

          // ANNUAL NET PROFIT BOX
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: report.totalNetProfit >= 0 ? PdfColors.green700 : PdfColors.red700,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('ANNUAL NET PROFIT (${report.year})',
                  style: pw.TextStyle(fontSize: 10, color: PdfColors.white, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                pw.Text(_fmt(report.totalNetProfit),
                  style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
              ]),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: pw.BoxDecoration(color: PdfColors.white, borderRadius: pw.BorderRadius.circular(12)),
                child: pw.Text('Net Margin: ${_pct(report.netMargin)}',
                  style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold,
                    color: report.totalNetProfit >= 0 ? PdfColors.green700 : PdfColors.red700)),
              ),
            ]),
          ),

          // ANNUAL SUMMARY SECTION
          pw.SizedBox(height: 14),
          _pdfSection('ANNUAL SUMMARY — ${report.year}', [
            _pdfRow('Total Revenue', _fmt(report.totalRevenue)),
            _pdfRow('Total COGS', _fmt(report.totalCogs)),
            _pdfRow('Total Shrinkage', _fmt(report.totalShrinkage)),
            _pdfRow('Total Operating Exp', _fmt(report.totalExpenses)),
            _pdfRowDivider(),
            _pdfRow('Total Net Profit', _fmt(report.totalNetProfit), bold: true),
            _pdfRow('Net Margin', _pct(report.netMargin), bold: true),
          ]),

          // BEST / SLOWEST MONTH
          if (report.bestMonth != null) ...[
            pw.SizedBox(height: 10),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.green50,
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: PdfColors.green200),
              ),
              child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text('BEST MONTH', style: pw.TextStyle(fontSize: 8, color: PdfColors.green800, fontWeight: pw.FontWeight.bold)),
                  pw.Text('${report.bestMonth!.monthName} ${report.year}',
                    style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                ]),
                pw.Text(_fmt(report.bestMonth!.netProfit),
                  style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
              ]),
            ),
          ],
          if (report.worstMonth != null) ...[
            pw.SizedBox(height: 6),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.orange50,
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: PdfColors.orange200),
              ),
              child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text('SLOWEST MONTH', style: pw.TextStyle(fontSize: 8, color: PdfColors.orange800, fontWeight: pw.FontWeight.bold)),
                  pw.Text('${report.worstMonth!.monthName} ${report.year}',
                    style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                ]),
                pw.Text(_fmt(report.worstMonth!.netProfit),
                  style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.orange800)),
              ]),
            ),
          ],

          // FOOTER
          pw.SizedBox(height: 16),
          pw.Divider(),
          pw.Center(child: pw.Text(
            'Generated by FlavianoPOS PRO | ${DateTime.now().toString().split('.')[0]}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          )),
        ],
      ));

      final bytes = await pdf.save();
      await Printing.sharePdf(bytes: bytes, filename: 'PL_Annual_${report.year}.pdf');
    } catch (e) {
      _showError(context, 'PDF export failed: $e');
    }
  }

  // ═══════════════════ EXCEL SUMMARY ═══════════════════
  static Future<void> exportSummaryExcel(BuildContext context, PLReport report) async {
    try {
      final excel = xl.Excel.createExcel();
      excel.delete('Sheet1');
      final sheet = excel['P&L Summary'];
      int row = 0;

      // Header
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row++)).value = xl.TextCellValue(AppSettings.businessName);
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row++)).value = xl.TextCellValue('PROFIT & LOSS STATEMENT');
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row++)).value = xl.TextCellValue(
        'Period: ${report.periodStart.toString().split(' ')[0]} to ${report.periodEnd.toString().split(' ')[0]}');
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row++)).value = xl.TextCellValue('Branch: ${report.branchFilter}');
      row++;

      // SALES
      _excelHeader(sheet, row++, 'SALES SUMMARY');
      _excelRow(sheet, row++, 'Gross Sales', report.grossSales);
      _excelRow(sheet, row++, 'Discounts', -report.totalDiscounts);
      _excelRow(sheet, row++, 'Refunds', -report.totalRefunds);
      _excelRow(sheet, row++, 'Voided', -report.totalVoided);
      _excelRow(sheet, row++, 'Net Sales (Revenue)', report.netSales);
      _excelRow(sheet, row++, 'Transactions', report.transactionCount.toDouble());
      _excelRow(sheet, row++, 'Average Sale', report.averageSale);
      row++;

      // COGS
      _excelHeader(sheet, row++, 'COST OF GOODS SOLD');
      _excelRow(sheet, row++, 'COGS', report.cogs);
      _excelRow(sheet, row++, 'COGS %', report.netSales > 0 ? (report.cogs / report.netSales) * 100 : 0);
      row++;

      // GROSS PROFIT
      _excelHeader(sheet, row++, 'GROSS PROFIT');
      _excelRow(sheet, row++, 'Gross Profit', report.grossProfit);
      _excelRow(sheet, row++, 'Gross Margin %', report.grossMargin);
      row++;

      // SHRINKAGE
      if (report.shrinkageByReason.isNotEmpty) {
        _excelHeader(sheet, row++, 'SHRINKAGE BY REASON');
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = xl.TextCellValue('Reason');
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = xl.TextCellValue('Amount');
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).value = xl.TextCellValue('% Shrink');
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).value = xl.TextCellValue('% Revenue');
        row++;
        for (final e in report.shrinkageByReason.entries) {
          final pctS = report.totalShrinkage > 0 ? (e.value / report.totalShrinkage) * 100 : 0;
          final pctR = report.netSales > 0 ? (e.value / report.netSales) * 100 : 0;
          sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = xl.TextCellValue(e.key);
          sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = xl.DoubleCellValue(e.value);
          sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).value = xl.DoubleCellValue(pctS.toDouble());
          sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).value = xl.DoubleCellValue(pctR.toDouble());
          row++;
        }
        _excelRow(sheet, row++, 'TOTAL SHRINKAGE', report.totalShrinkage);
        row++;
      }

      // EXPENSES
      if (report.expensesByCategory.isNotEmpty) {
        _excelHeader(sheet, row++, 'OPERATING EXPENSES');
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = xl.TextCellValue('Category / Sub-Category');
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = xl.TextCellValue('Amount');
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).value = xl.TextCellValue('% Expenses');
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).value = xl.TextCellValue('% Revenue');
        row++;
        for (final cat in report.expensesByCategory.entries) {
          final catTotal = cat.value.values.fold<double>(0, (a, b) => a + b);
          final pctE = report.totalOperatingExpenses > 0 ? (catTotal / report.totalOperatingExpenses) * 100 : 0;
          final pctR = report.netSales > 0 ? (catTotal / report.netSales) * 100 : 0;
          sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = xl.TextCellValue(cat.key);
          sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = xl.DoubleCellValue(catTotal);
          sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).value = xl.DoubleCellValue(pctE.toDouble());
          sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).value = xl.DoubleCellValue(pctR.toDouble());
          row++;
          for (final sub in cat.value.entries) {
            final subPctE = report.totalOperatingExpenses > 0 ? (sub.value / report.totalOperatingExpenses) * 100 : 0;
            final subPctR = report.netSales > 0 ? (sub.value / report.netSales) * 100 : 0;
            sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = xl.TextCellValue('   ${sub.key}');
            sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = xl.DoubleCellValue(sub.value);
            sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).value = xl.DoubleCellValue(subPctE.toDouble());
            sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).value = xl.DoubleCellValue(subPctR.toDouble());
            row++;
          }
        }
        _excelRow(sheet, row++, 'TOTAL EXPENSES', report.totalOperatingExpenses);
        row++;
      }

      // NET PROFIT
      _excelHeader(sheet, row++, 'NET PROFIT');
      _excelRow(sheet, row++, 'Net Profit', report.netProfit);
      _excelRow(sheet, row++, 'Net Margin %', report.netMargin);
      row++;

      // KEY METRICS vs INDUSTRY
      // NET PROFIT CALCULATION
      _excelHeader(sheet, row++, 'NET PROFIT CALCULATION');
      _excelRow(sheet, row++, 'Gross Profit', report.grossProfit);
      _excelRow(sheet, row++, 'Less: Shrinkage', -report.totalShrinkage);
      _excelRow(sheet, row++, 'Less: Operating Expenses', -report.totalOperatingExpenses);
      _excelRow(sheet, row++, 'NET PROFIT', report.netProfit);
      _excelRow(sheet, row++, 'Net Margin %', report.netMargin);
      row++;

      _excelHeader(sheet, row++, 'KEY METRICS vs INDUSTRY');
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = xl.TextCellValue('Metric');
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = xl.TextCellValue('Value');
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).value = xl.TextCellValue('Industry Low');
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).value = xl.TextCellValue('Industry High');
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row)).value = xl.TextCellValue('Status');
      row++;
      _excelMetric(sheet, row++, 'Gross Margin', report.grossMargin, 40, 50, true);
      _excelMetric(sheet, row++, 'Net Margin', report.netMargin, 5, 15, true);
      _excelMetric(sheet, row++, 'Shrinkage Rate', report.shrinkageRate, 1.5, 2.5, false);
      _excelMetric(sheet, row++, 'OpEx Ratio', report.operatingExpenseRate, 15, 25, false);

      final bytes = excel.save();
      if (bytes != null) {
        final filename = 'PL_${report.periodStart.toString().split(' ')[0]}.xlsx';
        await saveFileBytes(filename, bytes);
      }
    } catch (e) {
      _showError(context, 'Excel export failed: $e');
    }
  }

  // ═══════════════════ EXCEL MONTHLY ═══════════════════
  static Future<void> exportMonthlyExcel(BuildContext context, AnnualPLReport report) async {
    try {
      final excel = xl.Excel.createExcel();
      excel.delete('Sheet1');
      final sheet = excel['Annual P&L ${report.year}'];
      int row = 0;

      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row++)).value = xl.TextCellValue(AppSettings.businessName);
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row++)).value = xl.TextCellValue('ANNUAL P&L STATEMENT - ${report.year}');
      row++;

      // Headers
      final headers = ['Month', 'Revenue', 'COGS', 'Shrinkage', 'Expenses', 'Net Profit', 'Margin %'];
      for (int c = 0; c < headers.length; c++) {
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: row)).value = xl.TextCellValue(headers[c]);
      }
      row++;

      // Monthly data
      for (final m in report.months) {
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = xl.TextCellValue(m.monthName);
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = xl.DoubleCellValue(m.revenue);
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).value = xl.DoubleCellValue(m.cogs);
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).value = xl.DoubleCellValue(m.shrinkage);
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row)).value = xl.DoubleCellValue(m.expenses);
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row)).value = xl.DoubleCellValue(m.netProfit);
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row)).value = xl.DoubleCellValue(m.netMargin);
        row++;
      }

      // Totals
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = xl.TextCellValue('TOTAL');
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = xl.DoubleCellValue(report.totalRevenue);
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).value = xl.DoubleCellValue(report.totalCogs);
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).value = xl.DoubleCellValue(report.totalShrinkage);
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row)).value = xl.DoubleCellValue(report.totalExpenses);
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row)).value = xl.DoubleCellValue(report.totalNetProfit);
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row)).value = xl.DoubleCellValue(report.netMargin);
      row++;

      // Average
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = xl.TextCellValue('AVG/Month');
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = xl.DoubleCellValue(report.avgRevenue);
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).value = xl.DoubleCellValue(report.totalCogs / 12);
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).value = xl.DoubleCellValue(report.totalShrinkage / 12);
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row)).value = xl.DoubleCellValue(report.totalExpenses / 12);
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row)).value = xl.DoubleCellValue(report.avgNetProfit);
      row += 2;

      // ANNUAL SUMMARY SECTION
      _excelHeader(sheet, row++, 'ANNUAL SUMMARY ${report.year}');
      _excelRow(sheet, row++, 'Total Revenue', report.totalRevenue);
      _excelRow(sheet, row++, 'Total COGS', report.totalCogs);
      _excelRow(sheet, row++, 'Total Shrinkage', report.totalShrinkage);
      _excelRow(sheet, row++, 'Total Operating Exp', report.totalExpenses);
      _excelRow(sheet, row++, 'Total Net Profit', report.totalNetProfit);
      _excelRow(sheet, row++, 'Net Margin %', report.netMargin);
      row++;

      // BEST / SLOWEST MONTH
      if (report.bestMonth != null) {
        _excelHeader(sheet, row++, 'BEST MONTH');
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = xl.TextCellValue('${report.bestMonth!.monthName} ${report.year}');
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = xl.DoubleCellValue(report.bestMonth!.netProfit);
        row++;
      }
      if (report.worstMonth != null) {
        _excelHeader(sheet, row++, 'SLOWEST MONTH');
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = xl.TextCellValue('${report.worstMonth!.monthName} ${report.year}');
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = xl.DoubleCellValue(report.worstMonth!.netProfit);
        row++;
      }

      final bytes = excel.save();
      if (bytes != null) {
        await saveFileBytes('PL_Annual_${report.year}.xlsx', bytes);
      }
    } catch (e) {
      _showError(context, 'Excel export failed: $e');
    }
  }

  // ═══════════════════ PDF HELPERS ═══════════════════
  static pw.Widget _pdfSection(String title, List<pw.Widget> items) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 8),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          color: PdfColors.grey200,
          child: pw.Text(title, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        ),
        pw.SizedBox(height: 3),
        ...items,
      ]),
    );
  }

  static pw.Widget _pdfRow(String label, String value, {bool bold = false, bool small = false}) {
    final fs = small ? 8.0 : 10.0;
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5, horizontal: 6),
      child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text(label, style: pw.TextStyle(fontSize: fs, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        pw.Text(value, style: pw.TextStyle(fontSize: fs, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
      ]),
    );
  }

  static pw.Widget _pdfRow3(String label, String v1, String v2) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5, horizontal: 6),
      child: pw.Row(children: [
        pw.Expanded(flex: 3, child: pw.Text(label, style: const pw.TextStyle(fontSize: 9))),
        pw.Expanded(flex: 2, child: pw.Text(v1, textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 9))),
        pw.Expanded(flex: 2, child: pw.Text(v2, textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700))),
      ]),
    );
  }

  static pw.Widget _pdfRowDivider() => pw.Container(
    margin: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 6),
    height: 0.5, color: PdfColors.grey,
  );

  static pw.Widget _pdfSignature(String label, String name) {
    return pw.Column(children: [
      pw.SizedBox(height: 20),
      pw.Container(width: 100, height: 0.5, color: PdfColors.black),
      pw.SizedBox(height: 2),
      pw.Text(name.isEmpty ? '_____________' : name, style: const pw.TextStyle(fontSize: 9)),
      pw.Text(label, style: pw.TextStyle(fontSize: 7, color: PdfColors.grey700, fontWeight: pw.FontWeight.bold)),
    ]);
  }

  static pw.Widget _pdfMetricsCard(PLReport report) {
    final metrics = [
      ['Gross Margin', report.grossMargin, 40.0, 50.0, true],
      ['Net Margin', report.netMargin, 5.0, 15.0, true],
      ['Shrinkage Rate', report.shrinkageRate, 1.5, 2.5, false],
      ['OpEx Ratio', report.operatingExpenseRate, 15.0, 25.0, false],
    ];
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.indigo50,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: PdfColors.indigo200),
      ),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text('KEY METRICS vs INDUSTRY',
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo800)),
        pw.SizedBox(height: 6),
        ...metrics.map((m) {
          final label = m[0] as String;
          final value = m[1] as double;
          final lo = m[2] as double;
          final hi = m[3] as double;
          final higherIsBetter = m[4] as bool;
          final isGood = higherIsBetter ? value >= lo : value <= hi;
          final color = isGood ? PdfColors.green700 : PdfColors.orange700;
          final icon = isGood ? 'OK' : 'WARN';
          return pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 2),
            child: pw.Row(children: [
              pw.Expanded(flex: 3, child: pw.Text(label, style: const pw.TextStyle(fontSize: 10))),
              pw.Expanded(flex: 2, child: pw.Text(_pct(value), textAlign: pw.TextAlign.right,
                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: color))),
              pw.Expanded(flex: 3, child: pw.Text('Industry: ${lo.toStringAsFixed(1)}-${hi.toStringAsFixed(1)}%',
                textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700))),
              pw.SizedBox(width: 4),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: pw.BoxDecoration(color: color, borderRadius: pw.BorderRadius.circular(8)),
                child: pw.Text(icon, style: const pw.TextStyle(fontSize: 7, color: PdfColors.white)),
              ),
            ]),
          );
        }),
      ]),
    );
  }

  // ═══════════════════ EXCEL HELPERS ═══════════════════
  static void _excelHeader(xl.Sheet sheet, int row, String title) {
    sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = xl.TextCellValue(title);
  }

  static void _excelRow(xl.Sheet sheet, int row, String label, double value) {
    sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = xl.TextCellValue(label);
    sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = xl.DoubleCellValue(value);
  }

  static void _excelMetric(xl.Sheet sheet, int row, String label, double value, double lo, double hi, bool higherIsBetter) {
    final isGood = higherIsBetter ? value >= lo : value <= hi;
    sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = xl.TextCellValue(label);
    sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = xl.DoubleCellValue(value);
    sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).value = xl.DoubleCellValue(lo);
    sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).value = xl.DoubleCellValue(hi);
    sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row)).value = xl.TextCellValue(isGood ? 'GOOD' : 'WARNING');
  }

  static void _showError(BuildContext context, String msg) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
      );
    }
  }
}
