// lib/utils/export_helper.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:excel/excel.dart' as exc;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'web_download_stub.dart' if (dart.library.html) 'web_download.dart';

class ExportHelper {
  // Export as real Excel (.xlsx)
  static void exportExcel({
    required List<String> headers,
    required List<List<String>> rows,
    required String sheetName,
    required String fileName,
  }) {
    final excel = exc.Excel.createExcel();
    final sheet = excel[sheetName];
    if (sheetName != 'Sheet1') {
      excel.delete('Sheet1');
    }
    for (int i = 0; i < headers.length; i++) {
      sheet.cell(exc.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
        ..value = exc.TextCellValue(headers[i])
        ..cellStyle = exc.CellStyle(bold: true);
    }
    for (int r = 0; r < rows.length; r++) {
      for (int c = 0; c < rows[r].length; c++) {
        sheet.cell(exc.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 1))
          .value = exc.TextCellValue(rows[r][c]);
      }
    }
    final bytes = excel.save();
    if (bytes != null) {
      downloadExcel(Uint8List.fromList(bytes), fileName);
    }
  }

  // Export as PDF
  static Future<void> exportPdf({
    required String title,
    required List<String> headers,
    required List<List<String>> rows,
    required String fileName,
    String? subtitle,
  }) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(20),
        build: (context) => [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(title, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              if (subtitle != null)
                pw.Text(subtitle, style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
              pw.SizedBox(height: 4),
              pw.Text('Generated: ${DateTime.now().toString().substring(0, 19)}',
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500)),
              pw.SizedBox(height: 12),
            ],
          ),
          pw.TableHelper.fromTextArray(
            headers: headers,
            data: rows,
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
            cellStyle: const pw.TextStyle(fontSize: 7),
            cellAlignment: pw.Alignment.centerLeft,
            headerDecoration: const pw.BoxDecoration(color: PdfColors.teal50),
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            cellPadding: const pw.EdgeInsets.all(4),
          ),
        ],
      ),
    );
    final data = await pdf.save();
    downloadPdf(data, fileName);
  }

  // Export as CSV file
  static void exportCsvFile({
    required List<String> headers,
    required List<List<String>> rows,
    required String fileName,
  }) {
    final buf = StringBuffer();
    buf.writeln(headers.join(','));
    for (final row in rows) {
      buf.writeln(row.map((cell) {
        if (cell.contains(',') || cell.contains('"')) {
          return '"${cell.replaceAll('"', '""')}"';
        }
        return cell;
      }).join(','));
    }
    final bytes = Uint8List.fromList(utf8.encode(buf.toString()));
    downloadCsv(bytes, fileName);
  }
}
