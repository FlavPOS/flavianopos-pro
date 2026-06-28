// lib/screens/reports/discount_monitoring_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/discount_record_model.dart';
import '../../models/transaction_model.dart';
import '../../utils/export_helper.dart';

class DiscountMonitoringScreen extends StatefulWidget {
  final String branch;
  const DiscountMonitoringScreen({super.key, required this.branch});
  @override
  State<DiscountMonitoringScreen> createState() => _DiscountMonitoringScreenState();
}

class _DiscountMonitoringScreenState extends State<DiscountMonitoringScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  String _dateFilter = 'All';
  DateTimeRange? _customRange;
  final _dateFilters = ['Today', 'Yesterday', 'This Week', 'This Month', 'All', 'Custom'];
  String? _expandedTxnId;

  final _tabs = ['All', 'Senior', 'PWD', 'Employee', 'Manual'];
  final _tabIcons = [Icons.list_alt, Icons.elderly, Icons.accessible, Icons.badge, Icons.edit];
// //   final _tabColors = [Colors.teal, Colors.blue, Colors.purple, Colors.teal, Colors.orange];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _tabs.length, vsync: this);
    _tabCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  // 🎯 Status filter for void/refund/exchange awareness
  final String _statusFilter = 'Active';  // 'All', 'Active', 'Voided', 'Refunded'

  /// Get transaction status by ID (returns 'completed' if not found)
  String _getTxnStatus(String transactionId) {
    try {
      final txn = Transaction.allTransactions.firstWhere(
        (t) => t.id == transactionId,
      );
      return txn.status;
    } catch (_) {
      return 'completed'; // Default if transaction not found
    }
  }

  /// Returns color for status badge
  Color _statusColor(String status) {
    switch (status) {
      case 'voided': return Colors.red;
      case 'refunded': return Colors.orange;
      case 'exchanged': return Colors.purple;
      default: return Colors.green; // completed/active
    }
  }

  /// Returns icon for status
  IconData _statusIcon(String status) {
    switch (status) {
      case 'voided': return Icons.cancel;
      case 'refunded': return Icons.undo;
      case 'exchanged': return Icons.swap_horiz;
      default: return Icons.check_circle;
    }
  }

  /// Returns label for status
  String _statusLabel(String status) {
    switch (status) {
      case 'voided': return 'VOIDED';
      case 'refunded': return 'REFUNDED';
      case 'exchanged': return 'EXCHANGED';
      default: return 'ACTIVE';
    }
  }

  List<DiscountRecord> get _filteredRecords {
    final type = _tabs[_tabCtrl.index];
    var records = DiscountRecord.getByType(type);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return records.where((r) {
      // 🎯 Apply status filter
      if (_statusFilter != 'All') {
        final txnStatus = _getTxnStatus(r.transactionId);
        if (_statusFilter == 'Active' && txnStatus != 'completed') return false;
        if (_statusFilter == 'Voided' && txnStatus != 'voided') return false;
        if (_statusFilter == 'Refunded' && txnStatus != 'refunded') return false;
        if (_statusFilter == 'Exchanged' && txnStatus != 'exchanged') return false;
      }

      switch (_dateFilter) {
        case 'Today': return r.dateTime.isAfter(today);
        case 'Yesterday':
          final y = today.subtract(const Duration(days: 1));
          return r.dateTime.isAfter(y) && r.dateTime.isBefore(today);
        case 'This Week': return r.dateTime.isAfter(today.subtract(const Duration(days: 7)));
        case 'This Month': return r.dateTime.month == now.month && r.dateTime.year == now.year;
        case 'Custom':
          if (_customRange != null) {
            return r.dateTime.isAfter(_customRange!.start) &&
                r.dateTime.isBefore(_customRange!.end.add(const Duration(days: 1)));
          }
          return true;
        default: return true;
      }
    }).toList();
  }

  double get _totalGross => _filteredRecords.fold(0, (s, r) => s + r.totalGross);
  double get _totalDiscount => _filteredRecords.fold(0, (s, r) => s + r.totalDiscount);
  double get _totalNet => _filteredRecords.fold(0, (s, r) => s + r.totalNet);
  int get _totalTxn => _filteredRecords.length;
  int get _totalUnits => _filteredRecords.fold(0, (s, r) => s + r.totalUnits);

  Map<String, int> get _typeCounts {
    final all = DiscountRecord.allRecords;
    return {
      'Senior': all.where((r) => r.discountType == 'Senior').length,
      'PWD': all.where((r) => r.discountType == 'PWD').length,
      'Employee': all.where((r) => r.discountType == 'Employee').length,
      'Manual': all.where((r) => r.discountType == 'Manual').length,
    };
  }

  void _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context, firstDate: DateTime(2024), lastDate: DateTime.now(),
      initialDateRange: _customRange ?? DateTimeRange(
        start: DateTime.now().subtract(const Duration(days: 7)), end: DateTime.now()),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(colorScheme: ColorScheme.light(primary: Colors.teal[700]!)),
        child: child!),
    );
    if (picked != null) setState(() { _customRange = picked; _dateFilter = 'Custom'; });
  }

  Future<void> _exportCSV() async {
    final buf = StringBuffer();
    final type = _tabs[_tabCtrl.index];
    buf.writeln('Discount Monitoring Report - $type');
    buf.writeln('Date Filter: $_dateFilter');
    buf.writeln('');
    buf.writeln('TXN ID,Date,Type,Name,ID Number,Age,Item,SKU,Qty,Unit Price,Gross,Discount,Net');

    for (final r in _filteredRecords) {
      for (final item in r.items) {
        buf.writeln(
          '${r.transactionId},'
          '${r.dateTime.month}/${r.dateTime.day}/${r.dateTime.year},'
          '${r.discountType},'
          '${r.customerName ?? ""},'
          '${r.idNumber ?? ""},'
          '${r.age ?? ""},'
          '${item.itemName},'
          '${item.sku},'
          '${item.qty},'
          '${item.unitPrice.toStringAsFixed(2)},'
          '${item.grossAmount.toStringAsFixed(2)},'
          '${item.discountAmount.toStringAsFixed(2)},'
          '${item.netAmount.toStringAsFixed(2)}'
        );
      }
    }

    buf.writeln('');
    buf.writeln('SUMMARY');
    buf.writeln('Total Transactions,$_totalTxn');
    buf.writeln('Total Units,$_totalUnits');
    buf.writeln('Total Gross,${_totalGross.toStringAsFixed(2)}');
    buf.writeln('Total Discount,${_totalDiscount.toStringAsFixed(2)}');
    buf.writeln('Total Net,${_totalNet.toStringAsFixed(2)}');

    await Clipboard.setData(ClipboardData(text: buf.toString()));
    if (mounted) _snack('CSV copied to clipboard!');
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));

  String _formatDate(DateTime dt) {
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '${dt.month}/${dt.day}/${dt.year} $h:${dt.minute.toString().padLeft(2, '0')} $ampm';
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'Senior': return Colors.blue;
      case 'PWD': return Colors.purple;
      case 'Employee': return Colors.teal;
      case 'Manual': return Colors.orange;
      default: return Colors.grey;
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'Senior': return Icons.elderly;
      case 'PWD': return Icons.accessible;
      case 'Employee': return Icons.badge;
      case 'Manual': return Icons.edit;
      default: return Icons.discount;
    }
  }

  String _typeEmoji(String type) {
    switch (type) {
      case 'Senior': return '👴';
      case 'PWD': return '♿';
      case 'Employee': return '🏢';
      case 'Manual': return '✏️';
      default: return '🏷️';
    }
  }

  String _fmtDtDiscount(DateTime dt) {
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '${dt.month}/${dt.day}/${dt.year} $h:${dt.minute.toString().padLeft(2, '0')} $ampm';
  }

  void _exportExcel() {
    final data = _filteredRecords;
    ExportHelper.exportExcel(
      headers: ['TXN ID', 'Date/Time', 'Type', 'Customer', 'Gross', 'Discount', 'Net', 'Cashier', 'Branch'],
      rows: data.map((r) => [
        r.transactionId, _fmtDtDiscount(r.dateTime), r.discountType,
        r.customerName ?? '', r.totalGross.toStringAsFixed(2),
        r.totalDiscount.toStringAsFixed(2), r.totalNet.toStringAsFixed(2),
        r.cashier, r.branch,
      ]).toList(),
      sheetName: 'Discount_Monitoring',
      fileName: 'DiscountMonitoring_${DateTime.now().millisecondsSinceEpoch}.xlsx',
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ Excel exported!'), backgroundColor: Colors.green));
  }

  void _exportPdf() {
    final data = _filteredRecords;
    ExportHelper.exportPdf(
      title: 'Discount Monitoring Report',
      subtitle: '${data.length} records | Total Discount: ${_totalDiscount.toStringAsFixed(2)}',
      headers: ['TXN ID', 'Date/Time', 'Type', 'Customer', 'Gross', 'Discount', 'Net', 'Cashier', 'Branch'],
      rows: data.map((r) => [
        r.transactionId, _fmtDtDiscount(r.dateTime), r.discountType,
        r.customerName ?? '', r.totalGross.toStringAsFixed(2),
        r.totalDiscount.toStringAsFixed(2), r.totalNet.toStringAsFixed(2),
        r.cashier, r.branch,
      ]).toList(),
      fileName: 'DiscountMonitoring_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ PDF exported!'), backgroundColor: Colors.green));
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Discount Monitoring', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.file_download), tooltip: 'Export',
            onSelected: (v) { if (v == 'excel') _exportExcel(); if (v == 'pdf') _exportPdf(); },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'excel', child: Row(children: [
                Icon(Icons.table_chart, color: Colors.green, size: 20), SizedBox(width: 10), Text('Export to Excel')])),
              const PopupMenuItem(value: 'pdf', child: Row(children: [
                Icon(Icons.picture_as_pdf, color: Colors.red, size: 20), SizedBox(width: 10), Text('Export to PDF')])),
            ]),
        ],
        backgroundColor: Colors.teal[700], foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabCtrl,
          isScrollable: true,
          indicatorColor: Colors.white, labelColor: Colors.white, unselectedLabelColor: Colors.white70,
          tabs: List.generate(_tabs.length, (i) => Tab(
            icon: Icon(_tabIcons[i], size: 18),
            text: '${_tabs[i]}${i > 0 ? " (${_typeCounts[_tabs[i]] ?? 0})" : ""}',
          )),
        ),
      ),
      body: Column(
        children: [
          // Date filter
          Container(
            color: Colors.grey[50],
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(children: [
              PopupMenuButton<String>(
                onSelected: (v) { setState(() => _dateFilter = v); if (v == 'Custom') _pickDateRange(); },
                itemBuilder: (context) => _dateFilters.map((f) {
                  final sel = _dateFilter == f;
                  return PopupMenuItem<String>(value: f, child: Row(children: [
                    if (sel) Icon(Icons.check, size: 16, color: Colors.teal[700]),
                    if (sel) const SizedBox(width: 8),
                    Text(f, style: TextStyle(
                      fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                      color: sel ? Colors.teal[700] : Colors.black87)),
                  ]));
                }).toList(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(color: Colors.teal[50], borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.teal[300]!)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.calendar_today, size: 14, color: Colors.teal[700]),
                    const SizedBox(width: 6),
                    Text(_dateFilter, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.teal[700])),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_drop_down, size: 18, color: Colors.teal[700]),
                  ]),
                ),
              ),
              const Spacer(),
              Text('${_filteredRecords.length} records', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ]),
          ),
          // Records list
          Expanded(child: _buildRecordsList()),
        ],
      ),
    );
  }


  Widget _buildRecordsList() {
    final records = _filteredRecords;
    if (records.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 8),
          const Text('No discount records found', style: TextStyle(color: Colors.grey)),
          Text('${_tabs[_tabCtrl.index]} discounts will appear here', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
        ]),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      itemCount: records.length,
      itemBuilder: (context, index) {
        final r = records[index];
        final isExpanded = _expandedTxnId == r.transactionId;
        final color = _typeColor(r.discountType);

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: color.withAlpha(60))),
          child: Column(children: [
            // Header
            InkWell(
              onTap: () => setState(() => _expandedTxnId = isExpanded ? null : r.transactionId),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(children: [
                  // Row 1: Type badge + TXN ID
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: color.withAlpha(20), borderRadius: BorderRadius.circular(6)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(_typeIcon(r.discountType), size: 14, color: color),
                        const SizedBox(width: 4),
                        Text(r.discountType, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
                      ]),
                    ),
                    const SizedBox(width: 8),
                    Text(r.transactionId, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                    const Spacer(),
                    Icon(isExpanded ? Icons.expand_less : Icons.expand_more, color: Colors.grey),
                  ]),
                  const SizedBox(height: 6),
                  // Row 2: Customer info
                  Row(children: [
                    if (r.customerName != null) ...[
                      Icon(Icons.person, size: 14, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text(r.customerName!, style: TextStyle(fontSize: 12, color: Colors.grey[700], fontWeight: FontWeight.w500)),
                      const SizedBox(width: 12),
                    ],
                    if (r.idNumber != null) ...[
                      Icon(Icons.badge, size: 14, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text(r.idNumber!, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                      const SizedBox(width: 12),
                    ],
                    if (r.age != null) ...[
                      Icon(Icons.cake, size: 14, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text('${r.age} yrs', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                    ],
                  ]),
                  const SizedBox(height: 6),
                  // Row 3: Date + amounts
                  Row(children: [
                    Icon(Icons.access_time, size: 12, color: Colors.grey[400]),
                    const SizedBox(width: 4),
                    Text(_formatDate(r.dateTime), style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                    const Spacer(),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('Disc: -${r.totalDiscount.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red)),
                      Text('Net: ${r.totalNet.toStringAsFixed(2)}',
                        style: TextStyle(fontSize: 11, color: Colors.teal[700], fontWeight: FontWeight.w600)),
                    ]),
                  ]),
                ]),
              ),
            ),
            // Expanded: Item details table
            if (isExpanded) ...[
              const Divider(height: 1),
              Container(
                color: Colors.grey[50],
                child: Column(children: [
                  // Table header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    color: color.withAlpha(15),
                    child: const Row(children: [
                      Expanded(flex: 3, child: Text('Item', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                      SizedBox(width: 35, child: Center(child: Text('Qty', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)))),
                      Expanded(flex: 2, child: Text('Unit Price', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                      Expanded(flex: 2, child: Text('Gross', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                      Expanded(flex: 2, child: Text('Discount', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red), textAlign: TextAlign.right)),
                      Expanded(flex: 2, child: Text('Net', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                    ]),
                  ),
                  // Items
                  ...r.items.map((item) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey[200]!))),
                    child: Row(children: [
                      Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(item.itemName, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis),
                        if (item.sku.isNotEmpty) Text(item.sku, style: TextStyle(fontSize: 8, color: Colors.grey[400])),
                      ])),
                      SizedBox(width: 35, child: Center(child: Text('${item.qty}', style: const TextStyle(fontSize: 11)))),
                      Expanded(flex: 2, child: Text(item.unitPrice.toStringAsFixed(2), style: const TextStyle(fontSize: 10), textAlign: TextAlign.right)),
                      Expanded(flex: 2, child: Text(item.grossAmount.toStringAsFixed(2), style: const TextStyle(fontSize: 10), textAlign: TextAlign.right)),
                      Expanded(flex: 2, child: Text('-${item.discountAmount.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 10, color: Colors.red), textAlign: TextAlign.right)),
                      Expanded(flex: 2, child: Text(item.netAmount.toStringAsFixed(2),
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.teal[700]), textAlign: TextAlign.right)),
                    ]),
                  )),
                  // Total row
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    color: color.withAlpha(10),
                    child: Row(children: [
                      const Expanded(flex: 3, child: Text('TOTAL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                      SizedBox(width: 35, child: Center(child: Text('${r.totalUnits}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)))),
                      const Expanded(flex: 2, child: SizedBox()),
                      Expanded(flex: 2, child: Text(r.totalGross.toStringAsFixed(2),
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                      Expanded(flex: 2, child: Text('-${r.totalDiscount.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red), textAlign: TextAlign.right)),
                      Expanded(flex: 2, child: Text(r.totalNet.toStringAsFixed(2),
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.teal[700]), textAlign: TextAlign.right)),
                    ]),
                  ),
                  // Discount info
                  Container(
                    padding: const EdgeInsets.all(10),
                    child: Row(children: [
                      Text('${_typeEmoji(r.discountType)} ', style: const TextStyle(fontSize: 14)),
                      Text(
                        r.isPercentage
                            ? '${r.discountPercentage.toInt()}% Discount Applied'
                            : '${r.fixedDiscount.toStringAsFixed(2)} Fixed Discount',
                        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Text('Saved: ${r.totalDiscount.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red)),
                    ]),
                  ),
                ]),
              ),
            ],
          ]),
        );
      },
    );
  }
}
