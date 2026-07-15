// lib/screens/reports/sales_history_screen.dart
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'exchange_screen.dart';
import '../../models/user_model.dart';
import '../../models/product_model.dart';
import 'package:flutter/material.dart';
import '../../services/branch_inventory_service.dart'; // v1.0.60+136
import '../../services/device_assignment_service.dart'; // v1.0.60+136
import '../../models/transaction_model.dart';
import 'transaction_detail_screen.dart';
import 'sales_analytics_screen.dart';
import '../../utils/export_helper.dart';

class SalesHistoryScreen extends StatefulWidget {
  final String branch;
  const SalesHistoryScreen({super.key, required this.branch});
  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  // v1.0.59+131 — Branch-scoped for data isolation
  List<Transaction> _transactions = [];

  @override
  void initState() {
    super.initState();
    _loadBranchScoped();
  }

  Future<void> _loadBranchScoped() async {
    final txns = await Transaction.branchScopedTransactions;
    if (mounted) setState(() => _transactions = txns);
  }
  final _searchCtrl = TextEditingController();
  String _query = '';
  String _dateFilter = 'Today';
  final _dateFilters = ['Today', 'Yesterday', 'This Week', 'This Month', 'All'];

  List<Transaction> get _filtered {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _transactions.where((t) {
      final matchSearch = _query.isEmpty || t.id.toLowerCase().contains(_query.toLowerCase());
      bool matchDate = true;
      switch (_dateFilter) {
        case 'Today': matchDate = t.dateTime.isAfter(today); break;
        case 'Yesterday':
          final yesterday = today.subtract(const Duration(days: 1));
          matchDate = t.dateTime.isAfter(yesterday) && t.dateTime.isBefore(today); break;
        case 'This Week': matchDate = t.dateTime.isAfter(today.subtract(const Duration(days: 7))); break;
        case 'This Month': matchDate = t.dateTime.month == now.month && t.dateTime.year == now.year; break;
      }
      return matchSearch && matchDate;
    }).toList()..sort((a, b) => b.dateTime.compareTo(a.dateTime));
  }

  double get _todaySales {
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    return _transactions.where((t) => t.dateTime.isAfter(today) && t.status == 'completed')
        .fold(0.0, (s, t) => s + t.total);
  }
  int get _todayTxn {
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    return _transactions.where((t) => t.dateTime.isAfter(today)).length;
  }
  int get _voidedCount => _transactions.where((t) => t.status == 'voided').length;
  int get _refundedCount => _transactions.where((t) => t.status == 'refunded').length;

  Color _methodColor(String m) {
    switch (m) { case 'Cash': return Colors.green; case 'GCash': return Colors.blue;
      case 'Maya': return Colors.purple; case 'Card': return Colors.orange; default: return Colors.grey; }
  }
  Color _statusColor(String s) {
    switch (s) { case 'completed': return Colors.green; case 'voided': return Colors.red;
      case 'refunded': return Colors.orange; default: return Colors.grey; }
  }

  String _formatDate(DateTime dt) {
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '${dt.month}/${dt.day}/${dt.year} $h:${dt.minute.toString().padLeft(2, '0')} $ampm';
  }

  void _voidTransaction(Transaction txn) {
    final reasonCtrl = TextEditingController();
    final pinCtrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Void Transaction', style: TextStyle(color: Colors.red)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('TXN: ${txn.id}', style: const TextStyle(fontWeight: FontWeight.bold)),
        Text('Total: ${txn.total.toStringAsFixed(2)}'),
        const SizedBox(height: 16),
        TextField(controller: reasonCtrl, decoration: InputDecoration(labelText: 'Reason for void *',
            prefixIcon: const Icon(Icons.note), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
        const SizedBox(height: 12),
        TextField(controller: pinCtrl, decoration: InputDecoration(labelText: 'Manager PIN *',
            prefixIcon: const Icon(Icons.lock), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
            obscureText: true, keyboardType: TextInputType.number, maxLength: 6),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(onPressed: () {
          if (reasonCtrl.text.trim().isEmpty) { _snack('Please enter a reason'); return; }
          final mgr = AppUser.allUsers.where((u) => (u.role == 'Admin' || u.role == 'Manager') && u.pin == pinCtrl.text.trim()).firstOrNull;
          if (mgr == null) { _snack('Invalid Manager PIN'); return; }
          setState(() {
            txn.status = 'voided'; txn.voidReason = reasonCtrl.text.trim();
            txn.voidedBy = mgr.name; txn.voidedAt = DateTime.now();
            for (final item in txn.items) {
              final pIdx = Product.allProducts.indexWhere((p) => p.sku == item.sku);
              if (pIdx >= 0) {
                final p = Product.allProducts[pIdx];
                Product.updateProduct(p.id, Product(id: p.id, name: p.name, sku: p.sku, category: p.category, sellingPrice: p.sellingPrice, costPrice: p.costPrice, stockQty: p.stockQty + item.qty, reorderLevel: p.reorderLevel, barcode: p.barcode, imagePath: p.imagePath, imageUrl: p.imageUrl, unit: p.unit));
              }
            }
          });
          Transaction.updateTransaction(txn.id, txn);
          Navigator.pop(ctx);
          _printVoidReceipt(txn, mgr.name, reasonCtrl.text.trim());
        }, style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Void Transaction')),
      ]));
  }

  void _refundTransaction(Transaction txn) {
    String refundMethod = txn.paymentMethod;
    final pinCtrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => StatefulBuilder(
      builder: (ctx, setD) => AlertDialog(
        title: const Text('Refund Transaction', style: TextStyle(color: Colors.orange)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('TXN: ${txn.id}', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(12)),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Refund Amount:', style: TextStyle(fontSize: 14)),
              Text(txn.total.toStringAsFixed(2), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange)),
            ])),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(initialValue: refundMethod,
            decoration: InputDecoration(labelText: 'Refund Method', prefixIcon: const Icon(Icons.payment),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
            items: ['Cash', 'GCash', 'Maya', 'Card'].map((m) =>
                DropdownMenuItem(value: m, child: Text(m))).toList(),
            onChanged: (v) => setD(() => refundMethod = v!)),
          const SizedBox(height: 12),
          TextField(controller: pinCtrl, decoration: InputDecoration(labelText: 'Manager PIN *',
              prefixIcon: const Icon(Icons.lock), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              obscureText: true, keyboardType: TextInputType.number, maxLength: 6),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(onPressed: () async {
            final mgr = AppUser.allUsers.where((u) => (u.role == 'Admin' || u.role == 'Manager') && u.pin == pinCtrl.text.trim()).firstOrNull;
            if (mgr == null) { _snack('Invalid Manager PIN'); return; }
            // v1.0.60+136 - Fixed inventory restore via BranchInventoryService
            setState(() {
              txn.status = 'refunded'; txn.refundAmount = txn.total;
              txn.refundMethod = refundMethod; txn.refundedBy = mgr.name;
              txn.refundedAt = DateTime.now();
            });
            // Restore inventory per branch via BranchInventoryService
            try {
              final assign = await DeviceAssignmentService().read();
              final branchId = (assign['branchId'] ?? '').toString();
              if (branchId.isNotEmpty) {
                int restored = 0;
                for (final item in txn.items) {
                  final pIdx = Product.allProducts.indexWhere((p) => p.sku == item.sku);
                  if (pIdx < 0) {
                    debugPrint('[REFUND-HIST-STOCK] Product not found for SKU: ${item.sku}');
                    continue;
                  }
                  final p = Product.allProducts[pIdx];
                  final ok = await BranchInventoryService.incrementStock(
                    branchId, p.id, item.qty,
                  );
                  if (ok) {
                    restored++;
                    debugPrint('[REFUND-HIST-STOCK] Restored ${item.qty} x ${item.name} to $branchId');
                  }
                }
                debugPrint('[REFUND-HIST-STOCK] Summary: $restored items restored to $branchId');
              } else {
                debugPrint('[REFUND-HIST-STOCK] No branchId - skipping inventory restore');
              }
            } catch (e) {
              debugPrint('[REFUND-HIST-STOCK] Error: $e');
            }
            Transaction.updateTransaction(txn.id, txn);
            if (!mounted) return;
            Navigator.pop(ctx);
            _printRefundReceipt(txn, mgr.name, refundMethod);
          }, style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
              child: const Text('Process Refund')),
        ])));
  }

  void _printVoidReceipt(Transaction txn, String approvedBy, String reason) {
    showDialog(context: context, barrierDismissible: false, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(children: [Icon(Icons.check_circle, color: Colors.red, size: 28), SizedBox(width: 8), Text('Transaction Voided', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red))]),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        _rLine('TXN ID', txn.id), _rLine('Date', '${txn.dateTime.month}/${txn.dateTime.day}/${txn.dateTime.year}'),
        const Divider(),
        ...txn.items.map((i) => _rLine(i.name, '${i.qty} x ${i.price.toStringAsFixed(2)}')),
        const Divider(),
        _rLine('Total', txn.total.toStringAsFixed(2)),
        _rLine('Reason', reason), _rLine('Voided By', approvedBy),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ElevatedButton.icon(icon: const Icon(Icons.print, size: 18), label: const Text('Print Cashier Copy'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
          onPressed: () async {
            final pdf = pw.Document();
            pdf.addPage(pw.Page(pageFormat: PdfPageFormat.roll80, margin: const pw.EdgeInsets.all(8),
              build: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
                pw.Text('VOID RECEIPT', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.Text('CASHIER COPY', style: const pw.TextStyle(fontSize: 8)),
                pw.Divider(), pw.SizedBox(height: 4),
                _pRow('TXN:', txn.id), _pRow('Date:', '${txn.dateTime.month}/${txn.dateTime.day}/${txn.dateTime.year}'),
                _pRow('Time:', '${txn.dateTime.hour}:${txn.dateTime.minute.toString().padLeft(2, '0')}'),
                _pRow('Branch:', txn.branch),
                pw.Divider(), pw.Text('VOIDED ITEMS', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                ...txn.items.map((i) => _pRow(i.name, '${i.qty} x ${i.price.toStringAsFixed(2)}')),
                pw.Divider(),
                _pRow('Total:', txn.total.toStringAsFixed(2)),
                _pRow('Payment:', txn.paymentMethod),
                pw.SizedBox(height: 6),
                _pRow('Reason:', reason), _pRow('Voided By:', approvedBy),
                _pRow('Cashier:', txn.cashier),
                pw.SizedBox(height: 8), pw.Divider(),
                pw.Text('*** VOID ***', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                pw.Text('FlavianoPOS - PRO', style: const pw.TextStyle(fontSize: 8)),
              ])));
            await Printing.layoutPdf(onLayout: (_) => pdf.save());
          }),
      ]));
  }

  void _printRefundReceipt(Transaction txn, String approvedBy, String refundMethod) {
    showDialog(context: context, barrierDismissible: false, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(children: [Icon(Icons.check_circle, color: Colors.orange, size: 28), SizedBox(width: 8), Text('Transaction Refunded', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange))]),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        _rLine('TXN ID', txn.id), _rLine('Date', '${txn.dateTime.month}/${txn.dateTime.day}/${txn.dateTime.year}'),
        const Divider(),
        ...txn.items.map((i) => _rLine(i.name, '${i.qty} x ${i.price.toStringAsFixed(2)}')),
        const Divider(),
        _rLine('Refund Amount', txn.total.toStringAsFixed(2)),
        _rLine('Refund Method', refundMethod), _rLine('Approved By', approvedBy),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ElevatedButton.icon(icon: const Icon(Icons.print, size: 18), label: const Text('Print Cashier Copy'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
          onPressed: () async {
            final pdf = pw.Document();
            pdf.addPage(pw.Page(pageFormat: PdfPageFormat.roll80, margin: const pw.EdgeInsets.all(8),
              build: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
                pw.Text('REFUND RECEIPT', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.Text('CASHIER COPY', style: const pw.TextStyle(fontSize: 8)),
                pw.Divider(), pw.SizedBox(height: 4),
                _pRow('TXN:', txn.id), _pRow('Date:', '${txn.dateTime.month}/${txn.dateTime.day}/${txn.dateTime.year}'),
                _pRow('Time:', '${txn.dateTime.hour}:${txn.dateTime.minute.toString().padLeft(2, '0')}'),
                _pRow('Branch:', txn.branch),
                pw.Divider(), pw.Text('REFUNDED ITEMS', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                ...txn.items.map((i) => _pRow(i.name, '${i.qty} x ${i.price.toStringAsFixed(2)}')),
                pw.Divider(),
                _pRow('Refund Amount:', txn.total.toStringAsFixed(2)),
                _pRow('Refund Method:', refundMethod),
                _pRow('Original Payment:', txn.paymentMethod),
                pw.SizedBox(height: 6),
                _pRow('Approved By:', approvedBy),
                _pRow('Cashier:', txn.cashier),
                pw.SizedBox(height: 8), pw.Divider(),
                pw.Text('*** REFUND ***', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                pw.Text('FlavianoPOS - PRO', style: const pw.TextStyle(fontSize: 8)),
              ])));
            await Printing.layoutPdf(onLayout: (_) => pdf.save());
          }),
      ]));
  }

  Widget _rLine(String l, String v) => Padding(padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(l, style: TextStyle(fontSize: 12, color: Colors.grey[700])), Flexible(child: Text(v, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.right))]));

  pw.Widget _pRow(String l, String v) => pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 1),
    child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
      pw.Text(l, style: const pw.TextStyle(fontSize: 9)), pw.Text(v, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))]));
  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  String _fmtDtExport(DateTime dt) {
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '${dt.month}/${dt.day}/${dt.year} $h:${dt.minute.toString().padLeft(2, '0')} $ampm';
  }

  void _exportExcel() {
    final data = _filtered;
    ExportHelper.exportExcel(
      headers: ['TXN ID', 'Date/Time', 'Items', 'Subtotal', 'Discount', 'Total', 'Payment', 'Cashier', 'Status'],
      rows: data.map((t) => [
        t.id, _fmtDtExport(t.dateTime), t.items.length.toString(),
        t.subtotal.toStringAsFixed(2), t.totalDiscount.toStringAsFixed(2),
        t.total.toStringAsFixed(2), t.paymentMethod, t.cashier, t.status,
      ]).toList(),
      sheetName: 'Sales_History',
      fileName: 'SalesHistory_${DateTime.now().millisecondsSinceEpoch}.xlsx',
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ Excel exported!'), backgroundColor: Colors.green));
  }

  void _exportPdf() {
    final data = _filtered;
    ExportHelper.exportPdf(
      title: 'Sales History Report',
      subtitle: '${data.length} transactions',
      headers: ['TXN ID', 'Date/Time', 'Items', 'Subtotal', 'Discount', 'Total', 'Payment', 'Cashier', 'Status'],
      rows: data.map((t) => [
        t.id, _fmtDtExport(t.dateTime), t.items.length.toString(),
        t.subtotal.toStringAsFixed(2), t.totalDiscount.toStringAsFixed(2),
        t.total.toStringAsFixed(2), t.paymentMethod, t.cashier, t.status,
      ]).toList(),
      fileName: 'SalesHistory_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ PDF exported!'), backgroundColor: Colors.green));
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sales History', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.teal[700], foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'Export',
            onSelected: (v) {
              if (v == 'excel') _exportExcel();
              if (v == 'pdf') _exportPdf();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'excel', child: ListTile(leading: Icon(Icons.table_chart, color: Colors.green), title: Text('Export Excel'), contentPadding: EdgeInsets.zero)),
              const PopupMenuItem(value: 'pdf', child: ListTile(leading: Icon(Icons.picture_as_pdf, color: Colors.red), title: Text('Export PDF'), contentPadding: EdgeInsets.zero)),
            ],
          ),
          IconButton(icon: const Icon(Icons.analytics), tooltip: 'Sales Analytics',
            onPressed: () => Navigator.push(context, MaterialPageRoute(
                builder: (context) => SalesAnalyticsScreen(branch: widget.branch)))),
        ]),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(12), child: Row(children: [
          _card('Today', _formatCompact(_todaySales), Icons.trending_up, Colors.teal),
          const SizedBox(width: 8),
          _card('TXN', '$_todayTxn', Icons.receipt_long, Colors.blue),
          const SizedBox(width: 8),
          _card('Voided', '$_voidedCount', Icons.block, Colors.red),
          const SizedBox(width: 8),
          _card('Refund', '$_refundedCount', Icons.undo, Colors.orange),
        ])),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: TextField(controller: _searchCtrl,
            decoration: InputDecoration(hintText: 'Search transaction ID...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isNotEmpty ? IconButton(icon: const Icon(Icons.clear),
                  onPressed: () { _searchCtrl.clear(); setState(() => _query = ''); }) : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true, fillColor: Colors.grey[50],
              contentPadding: const EdgeInsets.symmetric(vertical: 0)),
            onChanged: (v) => setState(() => _query = v))),
        SizedBox(height: 40, child: ListView.builder(
          scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: _dateFilters.length, itemBuilder: (context, i) {
            final f = _dateFilters[i]; final sel = _dateFilter == f;
            return Padding(padding: const EdgeInsets.only(right: 8), child: FilterChip(
              label: Text(f, style: const TextStyle(fontSize: 12)),
              selected: sel, selectedColor: Colors.teal[100], checkmarkColor: Colors.teal[800],
              onSelected: (_) => setState(() => _dateFilter = f)));
          })),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(children: [
            Text('${_filtered.length} transactions', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            const Spacer(),
            Text('Latest first', style: TextStyle(fontSize: 12, color: Colors.grey[600]))])),
        Expanded(child: _filtered.isEmpty
            ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 8),
                const Text('No transactions found', style: TextStyle(color: Colors.grey))]))
            : ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _filtered.length, itemBuilder: (context, i) {
                  final t = _filtered[i];
                  return Card(margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: _statusColor(t.status).withAlpha(60))),
                    child: InkWell(
                      onTap: () => Navigator.push(context, MaterialPageRoute(
                          builder: (context) => TransactionDetailScreen(
                              transaction: t, onUpdate: () => setState(() {})))),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(padding: const EdgeInsets.all(14), child: Column(children: [
                        Row(children: [
                          Icon(Icons.receipt, size: 16, color: Colors.grey[500]),
                          const SizedBox(width: 6),
                          Text(t.id, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          const Spacer(),
                          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: _statusColor(t.status).withAlpha(20),
                                borderRadius: BorderRadius.circular(6)),
                            child: Text(t.status.toUpperCase(), style: TextStyle(fontSize: 10,
                                fontWeight: FontWeight.w700, color: _statusColor(t.status)))),
                        ]),
                        const SizedBox(height: 6),
                        Row(children: [
                          Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Text(_formatDate(t.dateTime), style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                          const Spacer(),
                          Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(color: _methodColor(t.paymentMethod).withAlpha(20),
                                borderRadius: BorderRadius.circular(4)),
                            child: Text(t.paymentMethod, style: TextStyle(fontSize: 10,
                                fontWeight: FontWeight.w600, color: _methodColor(t.paymentMethod)))),
                        ]),
                        const SizedBox(height: 6),
                        Row(children: [
                          Text('${t.totalQty} items', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                          const Spacer(),
                          Text(t.total.toStringAsFixed(2), style: TextStyle(fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: t.status == 'voided' ? Colors.grey : Colors.teal[700],
                              decoration: t.status == 'voided' ? TextDecoration.lineThrough : null)),
                          PopupMenuButton<String>(onSelected: (v) {
                            if (v == 'detail') {
                              Navigator.push(context, MaterialPageRoute(
                                builder: (context) => TransactionDetailScreen(
                                    transaction: t, onUpdate: () => setState(() {}))));
                            }
                            if (v == 'void') _voidTransaction(t);
                            if (v == 'refund') _refundTransaction(t);
                            if (v == 'exchange') {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => ExchangeScreen(transaction: t, currentUser: widget.branch, branch: widget.branch))).then((r) { if (r == true) setState(() {}); });
                            }
                          }, itemBuilder: (context) => [
                            const PopupMenuItem(value: 'detail', child: Text('View Receipt')),
                            if (t.status == 'completed')
                              // v1.0.60+135 — Void removed (moved to POS module)
                            if (t.status == 'completed')
                              const PopupMenuItem(value: 'refund', child: Text('Refund', style: TextStyle(color: Colors.orange))),
                            if (t.status == 'completed')
                              const PopupMenuItem(value: 'exchange', child: Text('Exchange Item', style: TextStyle(color: Color(0xFF1565C0)))),
                          ]),
                        ]),
                      ]))));
                })),
      ]),
    );
  }

  String _formatCompact(double v) {
    if (v >= 1000000000) return '${(v / 1000000000).toStringAsFixed(1)}Bn';
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(2);
  }

  Widget _card(String label, String value, IconData icon, Color color) =>
    Expanded(child: Card(elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(children: [
          Icon(icon, color: color, size: 20), const SizedBox(height: 4),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
          Text(label, style: TextStyle(fontSize: 9, color: Colors.grey[600]), textAlign: TextAlign.center),
        ]))));
}
