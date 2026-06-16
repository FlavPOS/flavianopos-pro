import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'adjustment_model.dart';
import '../../utils/export_helper.dart';

class AdjustmentHistoryScreen extends StatefulWidget {
  const AdjustmentHistoryScreen({super.key});

  @override
  State<AdjustmentHistoryScreen> createState() => _AdjustmentHistoryScreenState();
}

class _AdjustmentHistoryScreenState extends State<AdjustmentHistoryScreen> {
  List<AdjustmentRecord> _records = [];
  List<AdjustmentRecord> _filtered = [];
  bool _isLoading = true;

  final _searchCtrl = TextEditingController();
  DateTime? _dateFrom;
  DateTime? _dateTo;

  @override
  void initState() {
    super.initState();
    _loadRecords();
    _searchCtrl.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRecords() async {
    final all = await AdjustmentStorage.getAll();
    setState(() {
      _records = all;
      _filtered = all;
      _isLoading = false;
    });
  }

  Future<void> _applyFilters() async {
    final results = await AdjustmentStorage.getFiltered(
      dateFrom: _dateFrom,
      dateTo: _dateTo,
      searchQuery: _searchCtrl.text,
    );
    setState(() => _filtered = results);
  }

  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (isFrom ? _dateFrom : _dateTo) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _dateFrom = picked;
        } else {
          _dateTo = picked;
        }
      });
      _applyFilters();
    }
  }

  void _clearFilters() {
    setState(() {
      _dateFrom = null;
      _dateTo = null;
      _searchCtrl.clear();
      _filtered = _records;
    });
  }

  void _exportExcel() {
    if (_filtered.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No records to export.'), backgroundColor: Colors.orange));
      return;
    }
    ExportHelper.exportExcel(
      headers: ['Date', 'Time', 'Item', 'SKU', 'Type', 'Qty', 'Old Stock', 'New Stock', 'Reason', 'Notes'],
      rows: _filtered.map((r) => [
        _fmtDate(r.dateTime), _fmtTime(r.dateTime), r.itemName, r.sku,
        r.adjustmentType, '${r.quantity}', '${r.oldStock}', '${r.newStock}',
        r.reason, r.notes,
      ]).toList(),
      sheetName: 'Adjustment_History',
      fileName: 'Adjustment_History_${DateTime.now().millisecondsSinceEpoch}.xlsx');
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Excel exported!'), backgroundColor: Colors.green));
  }

  void _exportPdf() {
    if (_filtered.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No records to export.'), backgroundColor: Colors.orange));
      return;
    }
    ExportHelper.exportPdf(
      title: 'Adjustment History Report',
      subtitle: '${_filtered.length} records',
      headers: ['Date', 'Item', 'SKU', 'Type', 'Qty', 'Old', 'New', 'Reason'],
      rows: _filtered.map((r) => [
        _fmtDate(r.dateTime), r.itemName, r.sku,
        r.adjustmentType, '${r.quantity}', '${r.oldStock}', '${r.newStock}',
        r.reason,
      ]).toList(),
      fileName: 'Adjustment_History_${DateTime.now().millisecondsSinceEpoch}.pdf');
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('PDF exported!'), backgroundColor: Colors.green));
  }

  String _fmtDate(DateTime d) => '${d.year}-${_pad(d.month)}-${_pad(d.day)}';
  String _fmtTime(DateTime d) => '${_pad(d.hour)}:${_pad(d.minute)}';
  String _pad(int n) => n.toString().padLeft(2, '0');

  // ★ Print / Save PDF for a single adjustment record
  Future<void> _printSingleReceipt(AdjustmentRecord r) async {
    final date = _fmtDate(r.dateTime);
    final time = '${_pad(r.dateTime.hour)}:${_pad(r.dateTime.minute)}:${_pad(r.dateTime.second)}';
    final sign = r.adjustmentType == 'Add Stock' ? 1.0 : -1.0;
    final costAdj = sign * r.quantity * r.cost;
    final costAdjStr = '${costAdj < 0 ? "-" : ""}P${costAdj.abs().toStringAsFixed(2)}';

    final pdf = pw.Document();
    pdf.addPage(pw.Page(
      pageFormat: const PdfPageFormat(58 * PdfPageFormat.mm, double.infinity, marginAll: 4 * PdfPageFormat.mm),
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text('FlavianoPOS - PRO', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 2),
            pw.Text('STOCK ADJUSTMENT', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
            pw.Divider(thickness: 0.5),
            pw.SizedBox(height: 4),
            pw.Text('Date: $date', style: const pw.TextStyle(fontSize: 9)),
            pw.Text('Time: $time', style: const pw.TextStyle(fontSize: 9)),
            pw.Text('Ref#: ${r.id}', style: const pw.TextStyle(fontSize: 8)),
            pw.SizedBox(height: 6),
            pw.Divider(thickness: 0.5),
            _pdfRow('Item:', r.itemName),
            _pdfRow('SKU:', r.sku),
            _pdfRow('Type:', r.adjustmentType),
            _pdfRow('Quantity:', '${r.quantity} pcs'),
            pw.Divider(thickness: 0.5),
            _pdfRow('Old Stock:', '${r.oldStock} pcs'),
            _pdfRow('New Stock:', '${r.newStock} pcs'),
            pw.Divider(thickness: 0.5),
            _pdfRow('Unit Cost:', 'P${r.cost.toStringAsFixed(2)}'),
            _pdfRow('Unit Retail:', 'P${r.retail.toStringAsFixed(2)}'),
            _pdfRow('@Cost Adj:', costAdjStr),
            pw.Divider(thickness: 0.5),
            _pdfRow('Reason:', r.reason),
            if (r.notes.isNotEmpty) _pdfRow('Notes:', r.notes),
            pw.SizedBox(height: 10),
            pw.Divider(thickness: 0.5),
            pw.SizedBox(height: 4),
            pw.Text('--- End of Receipt ---', style: const pw.TextStyle(fontSize: 8)),
          ],
        );
      },
    ));
    await Printing.layoutPdf(onLayout: (_) async => pdf.save(), name: 'Adjustment_${r.id}');
  }

  pw.Widget _pdfRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.SizedBox(width: 60, child: pw.Text(label, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
        pw.Expanded(child: pw.Text(value, style: const pw.TextStyle(fontSize: 9))),
      ]),
    );
  }

  void _showDetail(AdjustmentRecord r) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 14),
              const Center(
                child: Text('Adjustment Details',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              const Divider(height: 24),
              _detailRow('Date', _fmtDate(r.dateTime)),
              _detailRow('Time', _fmtTime(r.dateTime)),
              _detailRow('Item', r.itemName),
              _detailRow('SKU', r.sku),
              _detailRow('Type', r.adjustmentType),
              _detailRow('Quantity', '${r.quantity} pcs'),
              _detailRow('Old Stock', '${r.oldStock} pcs'),
              _detailRow('New Stock', '${r.newStock} pcs'),
              _detailRow('Unit Cost', r.cost.toStringAsFixed(2)),
              _detailRow('Unit Retail', r.retail.toStringAsFixed(2)),
              _detailRow('Total @ Cost', (r.cost * r.quantity).toStringAsFixed(2)),
              _detailRow('Total @ Retail', (r.retail * r.quantity).toStringAsFixed(2)),
              const Divider(),
              _detailRow('Reason', r.reason),
              if (r.notes.isNotEmpty) _detailRow('Notes', r.notes),
              _detailRow('Ref #', r.id),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.print, color: Colors.white),
                  label: const Text('Print / Save as PDF', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2196F3),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    _printSingleReceipt(r);
                  },
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
              width: 110,
              child: Text(label,
                  style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[700]))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Adjustment History',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
        elevation: 0,
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
        ],
      ),
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              children: [
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search item name or SKU...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchCtrl.clear();
                              _applyFilters();
                            })
                        : null,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    isDense: true,
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _pickDate(true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.grey[100],
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                              const SizedBox(width: 6),
                              Text(
                                _dateFrom != null ? _fmtDate(_dateFrom!) : 'From Date',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: _dateFrom != null ? Colors.black87 : Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: Text('-'),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () => _pickDate(false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.grey[100],
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                              const SizedBox(width: 6),
                              Text(
                                _dateTo != null ? _fmtDate(_dateTo!) : 'To Date',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: _dateTo != null ? Colors.black87 : Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (_dateFrom != null || _dateTo != null || _searchCtrl.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.filter_alt_off, color: Colors.red, size: 22),
                        tooltip: 'Clear Filters',
                        onPressed: _clearFilters,
                      ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('${_filtered.length} record(s)',
                  style: TextStyle(
                      fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w500)),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.inbox, size: 64, color: Colors.grey[300]),
                            const SizedBox(height: 10),
                            Text('No adjustments found',
                                style: TextStyle(color: Colors.grey[500], fontSize: 16)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: _filtered.length,
                        itemBuilder: (_, i) {
                          final r = _filtered[i];
                          final isAdd = r.adjustmentType == 'Add Stock';
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () => _showDetail(r),
                              child: Padding(
                                 padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 42, height: 42,
                                      decoration: BoxDecoration(
                                        color: isAdd
                                            ? Colors.green.withAlpha(15)
                                            : Colors.red.withAlpha(15),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        isAdd ? Icons.add_circle : Icons.remove_circle,
                                         color: isAdd ? Colors.green : Colors.red,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(r.itemName,
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.bold, fontSize: 14)),
                                            const SizedBox(height: 2),
                                             Text(
                                              'SKU: ${r.sku}  |  ${r.reason}',
                                               style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                             ),
                                              const SizedBox(height: 2),
                                             Text(
                                               '${_fmtDate(r.dateTime)}  ${_fmtTime(r.dateTime)}',
                                              style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                                             ),
                                          ],
                                       ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                           '${isAdd ? "+" : "-"}${r.quantity}',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: isAdd ? Colors.green : Colors.red,
                                         ),
                                        ),
                                        Text(
                                           '${r.oldStock} \u2192 ${r.newStock}',
                                           style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                        ),
                                      ],
                                    ),
                                ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
