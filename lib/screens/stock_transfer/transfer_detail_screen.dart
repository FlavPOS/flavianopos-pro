// ============================================================
// TRANSFER DETAIL SCREEN - FlavianoPOS - PRO
// View transfer details, print landscape PDF slip
// ============================================================
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../utils/download_helper.dart';
import '../../models/stock_transfer_model.dart';

class TransferDetailScreen extends StatelessWidget {
  final StockTransfer transfer;
  final String currentUser;
  const TransferDetailScreen({super.key, required this.transfer, required this.currentUser});

  String _pad(int n) => n.toString().padLeft(2, '0');
  String _fmtDate(DateTime d) => '${_pad(d.month)}/${_pad(d.day)}/${d.year}';
  String _fmtDateTime(DateTime d) => '${_pad(d.month)}/${_pad(d.day)}/${d.year} ${_pad(d.hour)}:${_pad(d.minute)}';

  Color _statusColor() {
    switch (transfer.status) {
      case 'In Transit': return Colors.orange;
      case 'Received': return Colors.green;
      case 'Cancelled': return Colors.red;
      default: return Colors.grey;
    }
  }

  // ---- Print Landscape PDF Transfer Slip ----
  Future<void> _printTransferSlip(BuildContext context) async {
    try {
      final pdf = pw.Document();
      final isReceived = transfer.isReceived;
      final title = isReceived ? 'STOCK RECEIVING SLIP' : 'STOCK TRANSFER SLIP';

      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        build: (ctx) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          // Header
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: const pw.BoxDecoration(color: PdfColors.blue800,
              borderRadius: pw.BorderRadius.all(pw.Radius.circular(6))),
            child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('FlavianoPOS - PRO', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                pw.Text(title, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.yellow)),
              ]),
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                pw.Text('Transfer No: ${transfer.transferNo}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                pw.Text('Date: ${_fmtDate(transfer.transferDate)}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.white)),
                pw.Text('Status: ${transfer.status}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold,
                  color: transfer.isReceived ? PdfColors.green200 : transfer.isCancelled ? PdfColors.red200 : PdfColors.orange200)),
              ]),
            ]),
          ),
          pw.SizedBox(height: 10),
          // Info section
          pw.Row(children: [
            pw.Expanded(child: pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4))),
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('From Branch:', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                pw.Text(transfer.fromBranchName, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
              ]),
            )),
            pw.SizedBox(width: 10),
            pw.Container(padding: const pw.EdgeInsets.all(6),
              child: pw.Icon(pw.IconData(0xe5c8), size: 20, color: PdfColors.blue800)),
            pw.SizedBox(width: 10),
            pw.Expanded(child: pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4))),
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('To Branch:', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                pw.Text(transfer.toBranchName, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
              ]),
            )),
            pw.SizedBox(width: 20),
            pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              _pdfInfoLine('Prepared By', transfer.preparedBy),
              if (transfer.approvedBy.isNotEmpty) _pdfInfoLine('Approved By', transfer.approvedBy),
              if (transfer.receivedBy.isNotEmpty) _pdfInfoLine('Received By', transfer.receivedBy),
              if (transfer.receivedDate != null) _pdfInfoLine('Received Date', _fmtDateTime(transfer.receivedDate!)),
              if (transfer.remarks.isNotEmpty) _pdfInfoLine('Remarks', transfer.remarks),
            ])),
          ]),
          pw.SizedBox(height: 10),
          // Items table
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
            headerAlignment: pw.Alignment.center,
            cellStyle: const pw.TextStyle(fontSize: 7.5),
            cellAlignment: pw.Alignment.centerLeft,
            cellAlignments: {0: pw.Alignment.center, 7: pw.Alignment.center, 8: pw.Alignment.center, 9: pw.Alignment.centerRight, 10: pw.Alignment.centerRight},
            headerPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
            oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
            headers: ['No.', 'Item Code', 'Item Name', 'Batch #', 'MFG Date', 'Expiry Date', 'Category', 'Qty Transferred', isReceived ? 'Qty Received' : 'Unit', 'Cost', 'Total'],
            data: transfer.items.asMap().entries.map((e) {
              final item = e.value;
              return [
                '${e.key + 1}', item.itemCode, item.itemName, item.batchNumber,
                item.fmtDate(item.manufacturedDate), item.fmtDate(item.expiryDate),
                item.category, '${item.qtyTransferred}',
                isReceived ? '${item.qtyReceived}' : item.unit,
                item.cost.toStringAsFixed(2), item.totalCost.toStringAsFixed(2),
              ];
            }).toList(),
          ),
          pw.SizedBox(height: 6),
          // Totals row
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: pw.BoxDecoration(color: PdfColors.blue50, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4))),
            child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text('Total Items: ${transfer.totalItems}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
              pw.Text('Total Qty: ${transfer.totalQtyTransferred}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
              if (isReceived) pw.Text('Total Received: ${transfer.totalQtyReceived}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
              pw.Text('Total Cost: ${transfer.totalCost.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
            ]),
          ),
          pw.Spacer(),
          // Signature section
          pw.Divider(color: PdfColors.grey400),
          pw.SizedBox(height: 10),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceAround, children: [
            _signatureBlock('Prepared By', transfer.preparedBy),
            _signatureBlock('Checked By', ''),
            _signatureBlock('Approved By', transfer.approvedBy),
            _signatureBlock('Received By', transfer.receivedBy),
          ]),
          pw.SizedBox(height: 10),
          pw.Divider(color: PdfColors.grey300),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text('Printed: ${_fmtDateTime(DateTime.now())}', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500)),
            pw.Text('FlavianoPOS - PRO - Stock Transfer System', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500)),
          ]),
        ]),
      ));

      final pdfBytes = await pdf.save();
      final docType = isReceived ? 'receiving' : 'transfer';
      await saveFileBytes('${docType}_slip_${transfer.transferNo}_${DateTime.now().millisecondsSinceEpoch}.pdf', pdfBytes);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${isReceived ? 'Receiving' : 'Transfer'} slip exported!'),
          backgroundColor: Colors.green.shade700, behavior: SnackBarBehavior.floating));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Print error: $e'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating));
      }
    }
  }

  static pw.Widget _pdfInfoLine(String label, String value) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 1),
    child: pw.Row(children: [
      pw.SizedBox(width: 70, child: pw.Text('$label:', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600))),
      pw.Text(value, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
    ]),
  );

  static pw.Widget _signatureBlock(String label, String name) => pw.Column(children: [
    pw.Container(width: 140, height: 30, decoration: const pw.BoxDecoration(
      border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400)))),
    pw.SizedBox(height: 4),
    pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
    if (name.isNotEmpty) pw.Text(name, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
  ]);

  @override
  Widget build(BuildContext context) {
    final sc = _statusColor();
    return Scaffold(
      appBar: AppBar(
        title: Text(transfer.transferNo, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue[800], foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.print), tooltip: 'Print Slip',
            onPressed: () => _printTransferSlip(context)),
        ],
      ),
      body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Status card
        Card(elevation: 4, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(width: double.infinity, padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(colors: [Colors.blue[800]!, Colors.blue[600]!])),
            child: Column(children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(color: sc.withAlpha(60), borderRadius: BorderRadius.circular(20)),
                child: Text(transfer.status, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))),
              const SizedBox(height: 12),
              Text(transfer.transferNo, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              Text(_fmtDate(transfer.transferDate), style: TextStyle(color: Colors.white.withAlpha(180))),
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                _stat('Items', '${transfer.totalItems}'),
                _stat('Qty', '${transfer.totalQtyTransferred}'),
                if (transfer.isReceived) _stat('Received', '${transfer.totalQtyReceived}'),
                _stat('Cost', transfer.totalCost.toStringAsFixed(0)),
              ]),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        // Branch info
        Card(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
            _detailRow(Icons.store, 'From Branch', transfer.fromBranchName),
            _detailRow(Icons.store_mall_directory, 'To Branch', transfer.toBranchName),
            _detailRow(Icons.person, 'Prepared By', transfer.preparedBy),
            if (transfer.approvedBy.isNotEmpty) _detailRow(Icons.verified, 'Approved By', transfer.approvedBy),
            if (transfer.receivedBy.isNotEmpty) _detailRow(Icons.call_received, 'Received By', transfer.receivedBy),
            if (transfer.receivedDate != null) _detailRow(Icons.calendar_today, 'Received Date', _fmtDateTime(transfer.receivedDate!)),
            if (transfer.remarks.isNotEmpty) _detailRow(Icons.note, 'Remarks', transfer.remarks),
          ]))),
        const SizedBox(height: 16),
        // Print button
        SizedBox(width: double.infinity, height: 48,
          child: ElevatedButton.icon(
            onPressed: () => _printTransferSlip(context),
            icon: const Icon(Icons.print),
            label: Text(transfer.isReceived ? 'PRINT RECEIVING SLIP' : 'PRINT TRANSFER SLIP',
              style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[800], foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
        const SizedBox(height: 16),
        // Items
        Row(children: [
          Icon(Icons.inventory_2, size: 20, color: Colors.blue[800]),
          const SizedBox(width: 8),
          Text('Items (${transfer.totalItems})', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue[800])),
        ]),
        const SizedBox(height: 8),
        ...transfer.items.asMap().entries.map((e) {
          final item = e.value;
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: item.isExpired ? Colors.red.withAlpha(80) : item.isNearExpiry ? Colors.orange.withAlpha(80) : Colors.blue.withAlpha(40))),
            child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8)),
                  child: Text('${e.key + 1}', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[800]))),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(item.itemName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text('${item.itemCode} | ${item.category}', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                ])),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('Sent: ${item.qtyTransferred}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue[800])),
                  if (transfer.isReceived)
                    Text('Recv: ${item.qtyReceived}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green[700])),
                ]),
              ]),
              const SizedBox(height: 8),
              // Batch info
              Container(padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: item.isExpired ? Colors.red[50] : item.isNearExpiry ? Colors.orange[50] : Colors.grey[50],
                  borderRadius: BorderRadius.circular(8)),
                child: Row(children: [
                  Icon(Icons.inventory_2, size: 14, color: Colors.teal[700]),
                  const SizedBox(width: 6),
                  Text('Batch: ${item.batchNumber}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text('MFG: ${item.fmtDate(item.manufacturedDate)}', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                  const SizedBox(width: 8),
                  Text('EXP: ${item.fmtDate(item.expiryDate)}', style: TextStyle(fontSize: 10,
                    color: item.isExpired ? Colors.red : item.isNearExpiry ? Colors.orange : Colors.grey[600],
                    fontWeight: item.isExpired || item.isNearExpiry ? FontWeight.bold : FontWeight.normal)),
                ]),
              ),
              const SizedBox(height: 6),
              Row(children: [
                Text('Cost: ${item.cost.toStringAsFixed(2)}', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                const Spacer(),
                Text('Total: ${item.totalCost.toStringAsFixed(2)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue[800])),
              ]),
            ])),
          );
        }),
        const SizedBox(height: 24),
      ])),
    );
  }

  Widget _stat(String label, String value) => Column(children: [
    Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
    Text(label, style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 11)),
  ]);

  Widget _detailRow(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(children: [
      Icon(icon, size: 18, color: Colors.grey[600]),
      const SizedBox(width: 12),
      SizedBox(width: 100, child: Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12))),
      Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
    ]),
  );
}
