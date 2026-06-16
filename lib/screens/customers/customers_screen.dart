import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart' as xl;
import '../../utils/download_helper.dart';
import '../../models/customer_directory_model.dart';
import 'add_customer_screen.dart';
import 'customer_profile_screen.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});
  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final List<DirectoryCustomer> _customers = DirectoryCustomer.allCustomers;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedGroup = 'All';

  final List<String> _groups = ['All', 'VIP', 'Regular', 'New', 'Wholesale'];

  List<DirectoryCustomer> get _filteredCustomers {
    return _customers.where((c) {
      final matchesGroup = _selectedGroup == 'All' || c.group == _selectedGroup;
      final matchesSearch = _searchQuery.isEmpty ||
          c.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          c.phone.contains(_searchQuery) ||
          c.id.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesGroup && matchesSearch;
    }).toList()..sort((a, b) => b.totalSpent.compareTo(a.totalSpent));
  }

  int get _totalCustomers => _customers.length;
  int _groupCount(String group) => _customers.where((c) => c.group == group).length;
  double get _totalRevenue => _customers.fold(0, (sum, c) => sum + c.totalSpent);

  Color _getGroupColor(String group) {
    switch (group) {
      case 'VIP': return Colors.purple;
      case 'Wholesale': return Colors.indigo;
      case 'New': return Colors.green;
      default: return Colors.grey;
    }
  }

  void _addCustomer() async {
    final result = await Navigator.push(context,
      MaterialPageRoute(builder: (context) => const AddCustomerScreen()));
    if (result != null && result is DirectoryCustomer) {
      DirectoryCustomer.addCustomer(result);
      setState(() => _customers.add(result));
      _snack('${result.name} added!');
    }
  }

  void _updateCustomer(DirectoryCustomer updated) {
    setState(() {
      final index = _customers.indexWhere((c) => c.id == updated.id);
      DirectoryCustomer.updateCustomer(updated.id, updated);
      if (index >= 0) _customers[index] = updated;
    });
  }

  void _deleteCustomer(DirectoryCustomer customer) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Delete Customer'),
      content: Text('Remove "${customer.name}" from directory?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            setState(() => _customers.removeWhere((c) => c.id == customer.id));
            Navigator.pop(ctx);
            _snack('${customer.name} removed');
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
          child: const Text('Delete')),
      ],
    ));
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));

  String _pad(int n) => n.toString().padLeft(2, '0');
  String _fmtDate(DateTime d) => '${_pad(d.month)}/${_pad(d.day)}/${d.year}';
  String _fmtDateTime(DateTime d) => '${d.year}-${_pad(d.month)}-${_pad(d.day)} ${_pad(d.hour)}:${_pad(d.minute)}';

  Future<void> _exportExcel() async {
    final data = _filteredCustomers;
    if (data.isEmpty) { _snack('No customers to export'); return; }
    try {
      final excel = xl.Excel.createExcel();
      final sheet = excel['Customer Directory'];
      excel.delete('Sheet1');

      final hStyle = xl.CellStyle(bold: true, fontColorHex: xl.ExcelColor.fromHexString('#FFFFFF'),
        backgroundColorHex: xl.ExcelColor.fromHexString('#00838F'), horizontalAlign: xl.HorizontalAlign.Center);
      final titleStyle = xl.CellStyle(bold: true, fontSize: 14);
      final subStyle = xl.CellStyle(bold: true, fontSize: 11, fontColorHex: xl.ExcelColor.fromHexString('#555555'));
      final vipStyle = xl.CellStyle(fontColorHex: xl.ExcelColor.fromHexString('#7B1FA2'), bold: true);
      final wholeStyle = xl.CellStyle(fontColorHex: xl.ExcelColor.fromHexString('#283593'), bold: true);

      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).value = xl.TextCellValue('FlavianoPOS - PRO - Customer Directory');
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).cellStyle = titleStyle;
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1)).value = xl.TextCellValue(
        'Filter: $_selectedGroup | Generated: ${_fmtDateTime(DateTime.now())} | Total: ${data.length} customers');
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1)).cellStyle = subStyle;
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2)).value = xl.TextCellValue(
        'VIP: ${_groupCount('VIP')} | Regular: ${_groupCount('Regular')} | New: ${_groupCount('New')} | Wholesale: ${_groupCount('Wholesale')} | Total Revenue: ${_totalRevenue.toStringAsFixed(2)}');
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2)).cellStyle = subStyle;

      final headers = ['#', 'ID', 'Name', 'Phone', 'Email', 'Address', 'Group', 'Birthday', 'Total Spent', 'Visits', 'Avg/Visit', 'Last Visit', 'Join Date', 'Notes'];
      for (var c = 0; c < headers.length; c++) {
        final cell = sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 4));
        cell.value = xl.TextCellValue(headers[c]);
        cell.cellStyle = hStyle;
      }

      for (var i = 0; i < data.length; i++) {
        final c = data[i];
        final row = i + 5;
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = xl.IntCellValue(i + 1);
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = xl.TextCellValue(c.id);
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).value = xl.TextCellValue(c.name);
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).value = xl.TextCellValue(c.phone);
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row)).value = xl.TextCellValue(c.email);
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row)).value = xl.TextCellValue(c.address);
        final groupCell = sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row));
        groupCell.value = xl.TextCellValue(c.group);
        if (c.group == 'VIP') groupCell.cellStyle = vipStyle;
        if (c.group == 'Wholesale') groupCell.cellStyle = wholeStyle;
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: row)).value = xl.TextCellValue(c.birthday != null ? _fmtDate(c.birthday!) : '');
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: row)).value = xl.DoubleCellValue(c.totalSpent);
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: row)).value = xl.IntCellValue(c.totalVisits);
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: row)).value = xl.DoubleCellValue(c.averagePerVisit);
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 11, rowIndex: row)).value = xl.TextCellValue(c.lastVisitDate != null ? _fmtDate(c.lastVisitDate!) : 'Never');
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 12, rowIndex: row)).value = xl.TextCellValue(_fmtDate(c.joinDate));
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 13, rowIndex: row)).value = xl.TextCellValue(c.notes);
      }

      final sumStyle = xl.CellStyle(bold: true, backgroundColorHex: xl.ExcelColor.fromHexString('#E0F7FA'));
      final sumRow = data.length + 6;
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: sumRow)).value = xl.TextCellValue('TOTAL');
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: sumRow)).cellStyle = sumStyle;
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: sumRow)).value = xl.DoubleCellValue(_totalRevenue);
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: sumRow)).cellStyle = sumStyle;
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: sumRow)).value = xl.IntCellValue(data.fold(0, (s, c) => s + c.totalVisits));
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: sumRow)).cellStyle = sumStyle;

      sheet.setColumnWidth(0, 5); sheet.setColumnWidth(1, 14); sheet.setColumnWidth(2, 22);
      sheet.setColumnWidth(3, 14); sheet.setColumnWidth(4, 22); sheet.setColumnWidth(5, 24);
      sheet.setColumnWidth(6, 10); sheet.setColumnWidth(7, 12); sheet.setColumnWidth(8, 14);
      sheet.setColumnWidth(9, 8); sheet.setColumnWidth(10, 10); sheet.setColumnWidth(11, 12);
      sheet.setColumnWidth(12, 12); sheet.setColumnWidth(13, 20);

      final bytes = excel.save();
      if (bytes != null) {
        await saveFileBytes('customers_${DateTime.now().millisecondsSinceEpoch}.xlsx', bytes);
        if (mounted) _snack('Excel exported!');
      }
    } catch (e) { if (mounted) _snack('Export error: $e'); }
  }

  Future<void> _exportPdf() async {
    final data = _filteredCustomers;
    if (data.isEmpty) { _snack('No customers to export'); return; }
    try {
      final pdf = pw.Document();
      final rows = data.asMap().entries.map((e) {
        final c = e.value;
        return ['${e.key + 1}', c.name, c.phone, c.email.isNotEmpty ? c.email : '-',
          c.group, c.totalSpent.toStringAsFixed(0), '${c.totalVisits}',
          c.lastVisitDate != null ? _fmtDate(c.lastVisitDate!) : 'Never',
          _fmtDate(c.joinDate), c.address.isNotEmpty ? c.address : '-'];
      }).toList();

      const rpp = 18;
      final chunks = <List<List<String>>>[];
      for (var i = 0; i < rows.length; i += rpp) {
        chunks.add(rows.sublist(i, i + rpp > rows.length ? rows.length : i + rpp));
      }

      for (var p = 0; p < chunks.length; p++) {
        pdf.addPage(pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(24),
          build: (ctx) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            if (p == 0) ...[
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: const pw.BoxDecoration(color: PdfColors.cyan800, borderRadius: pw.BorderRadius.all(pw.Radius.circular(6))),
                child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.Text('FlavianoPOS - PRO', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                    pw.Text('CUSTOMER DIRECTORY', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.yellow)),
                  ]),
                  pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                    pw.Text('Filter: $_selectedGroup', style: const pw.TextStyle(fontSize: 10, color: PdfColors.white)),
                    pw.Text('Generated: ${_fmtDateTime(DateTime.now())}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey300)),
                  ]),
                ]),
              ),
              pw.SizedBox(height: 6),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: pw.BoxDecoration(color: PdfColors.cyan50, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4))),
                child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceAround, children: [
                  _pdfStat('Total', '${data.length}'),
                  _pdfStat('VIP', '${_groupCount('VIP')}'),
                  _pdfStat('Regular', '${_groupCount('Regular')}'),
                  _pdfStat('Wholesale', '${_groupCount('Wholesale')}'),
                  _pdfStat('Revenue', _totalRevenue.toStringAsFixed(0)),
                ]),
              ),
              pw.SizedBox(height: 8),
            ],
            if (p > 0) ...[
              pw.Text('Customer Directory (continued)', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.cyan800)),
              pw.SizedBox(height: 8),
            ],
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.cyan800),
              headerAlignment: pw.Alignment.center,
              cellStyle: const pw.TextStyle(fontSize: 6.5),
              cellAlignment: pw.Alignment.centerLeft,
              cellAlignments: {0: pw.Alignment.center, 5: pw.Alignment.centerRight, 6: pw.Alignment.center},
              headerPadding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 4),
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
              oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
              headers: ['#', 'Name', 'Phone', 'Email', 'Group', 'Total Spent', 'Visits', 'Last Visit', 'Join Date', 'Address'],
              data: chunks[p],
            ),
            pw.Spacer(),
            pw.Divider(color: PdfColors.grey400),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text('Total: ${data.length} customers | Revenue: ${_totalRevenue.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
              pw.Text('Page ${p + 1} of ${chunks.length}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
              pw.Text('System-generated from FlavianoPOS - PRO', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500)),
            ]),
          ]),
        ));
      }

      final pdfBytes = await pdf.save();
      await saveFileBytes('customers_${DateTime.now().millisecondsSinceEpoch}.pdf', pdfBytes);
      if (mounted) _snack('PDF exported!');
    } catch (e) { if (mounted) _snack('Export error: $e'); }
  }

  static pw.Widget _pdfStat(String label, String value) => pw.Column(children: [
    pw.Text(value, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.cyan800)),
    pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
  ]);

  @override
  void dispose() { _searchController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customers', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.cyan[700], foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.file_download), tooltip: 'Export',
            onSelected: (v) { if (v == 'excel') _exportExcel(); if (v == 'pdf') _exportPdf(); },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'excel', child: Row(children: [
                Icon(Icons.table_chart, color: Colors.green, size: 20), SizedBox(width: 10), Text('Export to Excel')])),
              const PopupMenuItem(value: 'pdf', child: Row(children: [
                Icon(Icons.picture_as_pdf, color: Colors.red, size: 20), SizedBox(width: 10), Text('Export to PDF')])),
            ],
          ),
        ],
      ),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(12), child: Row(children: [
          _summaryCard('Total', '$_totalCustomers', Icons.people, Colors.cyan),
          const SizedBox(width: 8),
          _summaryCard('VIP', '${_groupCount('VIP')}', Icons.star, Colors.purple),
          const SizedBox(width: 8),
          _summaryCard('Wholesale', '${_groupCount('Wholesale')}', Icons.store, Colors.indigo),
          const SizedBox(width: 8),
          _summaryCard('Revenue', '${_formatCompact(_totalRevenue)}', Icons.trending_up, Colors.green),
        ])),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: TextField(controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by name, phone, or ID...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty ? IconButton(icon: const Icon(Icons.clear),
                onPressed: () { _searchController.clear(); setState(() => _searchQuery = ''); }) : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true, fillColor: Colors.grey[50],
              contentPadding: const EdgeInsets.symmetric(vertical: 0)),
            onChanged: (v) => setState(() => _searchQuery = v))),
        SizedBox(height: 40,
          child: ListView.builder(scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _groups.length,
            itemBuilder: (context, index) {
              final g = _groups[index];
              final isSelected = _selectedGroup == g;
              return Padding(padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(g == 'All' ? 'All ($_totalCustomers)' : '$g (${_groupCount(g)})', style: const TextStyle(fontSize: 12)),
                  selected: isSelected, selectedColor: Colors.cyan[100], checkmarkColor: Colors.cyan[800],
                  onSelected: (_) => setState(() => _selectedGroup = g)));
            })),
        const SizedBox(height: 4),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(children: [
            Text('${_filteredCustomers.length} customers', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            const Spacer(),
            Text('Sorted by: Total Spent', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ])),
        Expanded(
          child: _filteredCustomers.isEmpty
            ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.people_outline, size: 64, color: Colors.grey),
                SizedBox(height: 8),
                Text('No customers found', style: TextStyle(color: Colors.grey))]))
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _filteredCustomers.length,
                itemBuilder: (context, index) {
                  final c = _filteredCustomers[index];
                  final gColor = _getGroupColor(c.group);
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: gColor.withAlpha(60))),
                    child: InkWell(
                      onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (context) => CustomerProfileScreen(customer: c, onUpdate: _updateCustomer))),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(padding: const EdgeInsets.all(12),
                        child: Row(children: [
                          CircleAvatar(radius: 24, backgroundColor: gColor.withAlpha(30),
                            child: Text(c.name[0], style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: gColor))),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Flexible(child: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14), overflow: TextOverflow.ellipsis)),
                              const SizedBox(width: 6),
                              Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(color: gColor.withAlpha(20), borderRadius: BorderRadius.circular(4)),
                                child: Text(c.group, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: gColor))),
                            ]),
                            const SizedBox(height: 2),
                            Text('${c.phone}  |  ${c.id}', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                            const SizedBox(height: 4),
                            Row(children: [
                              Icon(Icons.account_balance_wallet, size: 14, color: Colors.grey[500]),
                              const SizedBox(width: 4),
                              Text(c.totalSpent.toStringAsFixed(0), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              const SizedBox(width: 12),
                              Icon(Icons.calendar_today, size: 14, color: Colors.grey[500]),
                              const SizedBox(width: 4),
                              Text(c.lastVisitDate != null ? '${c.lastVisitDate!.month}/${c.lastVisitDate!.day}' : 'Never',
                                style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                            ]),
                          ])),
                          Column(children: [
                            IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                              onPressed: () => _deleteCustomer(c), constraints: const BoxConstraints(), padding: const EdgeInsets.all(4)),
                            const Icon(Icons.chevron_right, color: Colors.grey),
                          ]),
                        ])),
                    ),
                  );
                })),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addCustomer, backgroundColor: Colors.cyan[700], foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add), label: const Text('Add Customer')),
    );
  }

  String _formatCompact(double v) {
    if (v >= 1000000000) return '${(v / 1000000000).toStringAsFixed(1)}Bn';
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(2);
  }

  Widget _summaryCard(String label, String value, IconData icon, Color color) => Expanded(
    child: Card(elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
          Text(label, style: TextStyle(fontSize: 9, color: Colors.grey[600]), textAlign: TextAlign.center),
        ]))));
}
