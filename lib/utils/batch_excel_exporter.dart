// lib/utils/batch_excel_exporter.dart
// v1.0.43 — Batch Excel Export with full audit data
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import '../models/batch_model.dart';

class BatchExcelExporter {
  /// Export batches to Excel and return bytes for download
  static Uint8List exportBatches({
    required List<ProductBatch> batches,
    required String branchName,
    required String branchId,
    String? exportedBy,
  }) {
    final excel = Excel.createExcel();
    excel.rename('Sheet1', 'BATCHES');
    final sheet = excel['BATCHES'];

    // ═══ HEADER ROW ═══
    final headers = [
      '#',
      'Date',
      'Item Code',
      'Item Name',
      'Batch #',
      'Lot #',
      'Mfg Date',
      'Expiry Date',
      'Qty',
      'Original Qty',
      'Consumed',
      'Days Remaining',
      'Remarks',
      'Update Remarks',
      'Cost Price',
      'Total Value',
      'Supplier',
      'Branch',
      'Source',
      'Notes',
    ];

    // Write headers with styling
    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(
        columnIndex: i, rowIndex: 0,
      ));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = CellStyle(
        bold: true,
        fontColorHex: ExcelColor.white,
        backgroundColorHex: ExcelColor.fromHexString('#0D9488'),
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );
    }

    // ═══ DATA ROWS ═══
    final now = DateTime.now();
    for (int i = 0; i < batches.length; i++) {
      final b = batches[i];
      final row = i + 1;

      // Calculated fields
      final daysRemaining = b.expiryDate.difference(now).inDays;
      final consumed = b.originalQty - b.quantity;
      final totalValue = b.quantity * b.costPrice;

      // Remarks (expiry-based)
      String remarks;
      if (b.isExpired) {
        remarks = 'EXPIRED';
      } else if (b.quantity == 0) {
        remarks = 'DEPLETED';
      } else if (b.isNearExpiry) {
        remarks = 'NEAR EXPIRY';
      } else if (b.isWarning) {
        remarks = 'WARNING';
      } else {
        remarks = 'FRESH';
      }

      // Update Remarks (status-based)
      String updateRemarks = '';
      if (b.status == 'SOLD') {
        updateRemarks = 'ALREADY SOLD';
      } else if (b.status == 'RETURNED') {
        updateRemarks = 'ALREADY RETURNED';
      } else if (b.status == 'ADJUSTED') {
        updateRemarks = 'ALREADY ADJUSTED';
      } else if (b.status == 'CONSUMED') {
        updateRemarks = 'CONSUMED';
      } else if (b.status == 'EXPIRED') {
        updateRemarks = 'EXPIRED';
      }

      final values = [
        IntCellValue(i + 1),
        TextCellValue(_fmtDate(b.dateAdded)),
        TextCellValue(b.productSku),
        TextCellValue(b.productName),
        TextCellValue(b.batchNumber),
        TextCellValue(b.lotNumber),
        TextCellValue(_fmtDate(b.manufacturedDate)),
        TextCellValue(_fmtDate(b.expiryDate)),
        IntCellValue(b.quantity),
        IntCellValue(b.originalQty),
        IntCellValue(consumed),
        IntCellValue(daysRemaining),
        TextCellValue(remarks),
        TextCellValue(updateRemarks),
        DoubleCellValue(b.costPrice),
        DoubleCellValue(totalValue),
        TextCellValue(b.supplier),
        TextCellValue(b.branchName),
        TextCellValue(b.source),
        TextCellValue(b.notes),
      ];

      for (int c = 0; c < values.length; c++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(
          columnIndex: c, rowIndex: row,
        ));
        cell.value = values[c];

        // Color-code Remarks column
        if (c == 12) {
          String hex = '#FFFFFF';
          if (remarks == 'EXPIRED') hex = '#FEE2E2';
          else if (remarks == 'NEAR EXPIRY') hex = '#FED7AA';
          else if (remarks == 'WARNING') hex = '#FEF3C7';
          else if (remarks == 'FRESH') hex = '#DCFCE7';
          else if (remarks == 'DEPLETED') hex = '#F3F4F6';
          cell.cellStyle = CellStyle(
            backgroundColorHex: ExcelColor.fromHexString(hex),
            bold: true,
            horizontalAlign: HorizontalAlign.Center,
          );
        }
        // Color-code Update Remarks column
        if (c == 13 && updateRemarks.isNotEmpty) {
          String hex = '#F3F4F6';
          if (updateRemarks == 'ALREADY SOLD') hex = '#DCFCE7';
          else if (updateRemarks == 'ALREADY RETURNED') hex = '#DBEAFE';
          else if (updateRemarks == 'ALREADY ADJUSTED') hex = '#EDE9FE';
          cell.cellStyle = CellStyle(
            backgroundColorHex: ExcelColor.fromHexString(hex),
            bold: true,
            horizontalAlign: HorizontalAlign.Center,
          );
        }
      }
    }

    // Column widths
    final widths = [4.0, 12.0, 12.0, 28.0, 12.0, 12.0, 12.0, 12.0,
                    8.0, 10.0, 10.0, 10.0, 12.0, 16.0, 10.0, 12.0,
                    16.0, 16.0, 12.0, 30.0];
    for (int i = 0; i < widths.length; i++) {
      sheet.setColumnWidth(i, widths[i]);
    }

    // ═══ SUMMARY SHEET ═══
    _addSummarySheet(excel, batches, branchName, branchId, exportedBy, now);

    final bytes = excel.save();
    if (bytes == null) {
      throw Exception('Failed to generate Excel file');
    }
    debugPrint('[EXPORT] ✅ Generated ${bytes.length} bytes for ${batches.length} batches');
    return Uint8List.fromList(bytes);
  }

  static void _addSummarySheet(Excel excel, List<ProductBatch> batches,
      String branchName, String branchId, String? exportedBy, DateTime now) {
    final sheet = excel['SUMMARY'];

    // Header
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).value =
      TextCellValue('📦 FLAV POS - Batch Inventory Report');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).cellStyle =
      CellStyle(bold: true, fontSize: 14, fontColorHex: ExcelColor.fromHexString('#0D9488'));

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1)).value =
      TextCellValue('Branch: $branchName ($branchId)');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2)).value =
      TextCellValue('Generated: ${_fmtDateTime(now)}');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 3)).value =
      TextCellValue('Exported by: ${exportedBy ?? "admin"}');

    // Stats
    final totalValue = batches.fold<double>(0, (s, b) => s + (b.quantity * b.costPrice));
    final totalQty = batches.fold<int>(0, (s, b) => s + b.quantity);

    int freshCount = 0, nearExpCount = 0, expiredCount = 0, depletedCount = 0;
    int soldCount = 0, returnedCount = 0, adjustedCount = 0;

    for (final b in batches) {
      if (b.status == 'SOLD') { soldCount++; }
      else if (b.status == 'RETURNED') { returnedCount++; }
      else if (b.status == 'ADJUSTED') { adjustedCount++; }
      else if (b.isExpired) { expiredCount++; }
      else if (b.quantity == 0) { depletedCount++; }
      else if (b.isNearExpiry) { nearExpCount++; }
      else { freshCount++; }
    }

    final stats = [
      ['Total Batches:', batches.length.toString()],
      ['Total Quantity:', '$totalQty pcs'],
      ['Total Value:', '₱ ${totalValue.toStringAsFixed(2)}'],
      ['', ''],
      ['── By Expiry Status ──', ''],
      ['🟢 Fresh:', freshCount.toString()],
      ['🟡 Near Expiry:', nearExpCount.toString()],
      ['🔴 Expired:', expiredCount.toString()],
      ['⚪ Depleted:', depletedCount.toString()],
      ['', ''],
      ['── By Update Status ──', ''],
      ['💰 Already Sold:', soldCount.toString()],
      ['🔄 Already Returned:', returnedCount.toString()],
      ['⚙️ Already Adjusted:', adjustedCount.toString()],
    ];

    for (int i = 0; i < stats.length; i++) {
      final row = i + 5;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value =
        TextCellValue(stats[i][0]);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value =
        TextCellValue(stats[i][1]);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).cellStyle =
        CellStyle(bold: true);
    }

    sheet.setColumnWidth(0, 28.0);
    sheet.setColumnWidth(1, 20.0);
  }

  static String _fmtDate(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$mm/$dd/${d.year}';
  }

  static String _fmtDateTime(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final mn = d.minute.toString().padLeft(2, '0');
    return '$mm/$dd/${d.year} $hh:$mn';
  }
}
