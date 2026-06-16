import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart' as xl;
import '../../utils/download_helper.dart';
import '../../models/employee_model.dart';
import 'add_employee_screen.dart';

class EmployeeListScreen extends StatefulWidget {
  final String branchId;
  final String branchName;
  const EmployeeListScreen({super.key, required this.branchId, required this.branchName});
  @override
  State<EmployeeListScreen> createState() => _EmployeeListScreenState();
}

class _EmployeeListScreenState extends State<EmployeeListScreen> {
  List<Employee> _employees = [];
  bool _isLoading = true;
  final _searchCtrl = TextEditingController();
  String _query = '';

  List<Employee> get _filtered => _employees.where((e) {
    if (_query.isEmpty) return true;
    final q = _query.toLowerCase();
    return e.name.toLowerCase().contains(q) || e.role.toLowerCase().contains(q) || e.phone.contains(q);
  }).toList();

  int get _activeCount => _employees.where((e) => e.isActive).length;
  double get _totalSalary => _employees.where((e) => e.isActive).fold(0, (s, e) => s + e.salary);

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    final list = await EmployeeStorage.getByBranch(widget.branchId);
    setState(() { _employees = list; _isLoading = false; });
  }

  void _snack(String msg, [Color? bg]) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: bg, behavior: SnackBarBehavior.floating));

  Future<void> _callPhone(String phone) async {
    if (phone.isEmpty) { _snack('No phone number'); return; }
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) { await launchUrl(uri); }
    else { if (mounted) _snack('Cannot call $phone'); }
  }

  Future<void> _sendSms(String phone) async {
    if (phone.isEmpty) { _snack('No phone number'); return; }
    final uri = Uri.parse('sms:$phone');
    if (await canLaunchUrl(uri)) { await launchUrl(uri); }
  }

  String _pad(int n) => n.toString().padLeft(2, '0');
  String _fmtDate(DateTime d) => '${_pad(d.month)}/${_pad(d.day)}/${d.year}';
  String _fmtDateTime(DateTime d) => '${d.year}-${_pad(d.month)}-${_pad(d.day)} ${_pad(d.hour)}:${_pad(d.minute)}';

  Future<void> _addEmployee() async {
    final result = await Navigator.push(context, MaterialPageRoute(
      builder: (_) => AddEmployeeScreen(branchId: widget.branchId, branchName: widget.branchName)));
    if (result != null) await _load();
  }

  Future<void> _editEmployee(Employee emp) async {
    final result = await Navigator.push(context, MaterialPageRoute(
      builder: (_) => AddEmployeeScreen(branchId: widget.branchId, branchName: widget.branchName, employee: emp)));
    if (result != null) await _load();
  }

  Future<void> _deleteEmployee(Employee emp) async {
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Delete Employee'),
      content: Text('Remove "${emp.name}"?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
          child: const Text('Delete')),
      ],
    ));
    if (confirmed == true) {
      await EmployeeStorage.deleteEmployee(emp.id);
      await _load();
      if (mounted) _snack('${emp.name} removed', Colors.red);
    }
  }

  Future<void> _exportExcel() async {
    final data = _filtered;
    if (data.isEmpty) { _snack('No employees to export', Colors.orange); return; }
    try {
      final excel = xl.Excel.createExcel();
      final sheet = excel['Employees'];
      excel.delete('Sheet1');

      final hStyle = xl.CellStyle(bold: true, fontColorHex: xl.ExcelColor.fromHexString('#FFFFFF'),
        backgroundColorHex: xl.ExcelColor.fromHexString('#283593'), horizontalAlign: xl.HorizontalAlign.Center);
      final titleStyle = xl.CellStyle(bold: true, fontSize: 14);
      final subStyle = xl.CellStyle(bold: true, fontSize: 11, fontColorHex: xl.ExcelColor.fromHexString('#555555'));

      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).value = xl.TextCellValue('FlavianoPOS - PRO - Employee List');
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).cellStyle = titleStyle;
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1)).value = xl.TextCellValue('Branch: ${widget.branchName} | Generated: ${_fmtDateTime(DateTime.now())}');
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1)).cellStyle = subStyle;
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2)).value = xl.TextCellValue(
        'Total: ${data.length} | Active: $_activeCount | Total Salary: ${_totalSalary.toStringAsFixed(2)}');
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2)).cellStyle = subStyle;

      final headers = ['#', 'Name', 'Role', 'Phone', 'Email', 'Salary', 'Date Hired', 'Status', 'Notes'];
      for (var c = 0; c < headers.length; c++) {
        final cell = sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 4));
        cell.value = xl.TextCellValue(headers[c]);
        cell.cellStyle = hStyle;
      }

      for (var i = 0; i < data.length; i++) {
        final e = data[i];
        final row = i + 5;
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = xl.IntCellValue(i + 1);
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = xl.TextCellValue(e.name);
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).value = xl.TextCellValue(e.role);
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).value = xl.TextCellValue(e.phone);
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row)).value = xl.TextCellValue(e.email);
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row)).value = xl.DoubleCellValue(e.salary);
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row)).value = xl.TextCellValue(_fmtDate(e.dateHired));
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: row)).value = xl.TextCellValue(e.isActive ? 'Active' : 'Inactive');
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: row)).value = xl.TextCellValue(e.notes);
      }

      final sumStyle = xl.CellStyle(bold: true, backgroundColorHex: xl.ExcelColor.fromHexString('#E8EAF6'));
      final sumRow = data.length + 6;
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: sumRow)).value = xl.TextCellValue('TOTAL');
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: sumRow)).cellStyle = sumStyle;
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: sumRow)).value = xl.DoubleCellValue(_totalSalary);
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: sumRow)).cellStyle = sumStyle;

      sheet.setColumnWidth(0, 5); sheet.setColumnWidth(1, 22); sheet.setColumnWidth(2, 16);
      sheet.setColumnWidth(3, 14); sheet.setColumnWidth(4, 22); sheet.setColumnWidth(5, 12);
      sheet.setColumnWidth(6, 12); sheet.setColumnWidth(7, 10); sheet.setColumnWidth(8, 20);

      final bytes = excel.save();
      if (bytes != null) {
        await saveFileBytes('employees_${widget.branchId}_${DateTime.now().millisecondsSinceEpoch}.xlsx', bytes);
        if (mounted) _snack('Excel exported!', Colors.green.shade700);
      }
    } catch (e) { if (mounted) _snack('Export error: $e', Colors.red); }
  }

  Future<void> _exportPdf() async {
    final data = _filtered;
    if (data.isEmpty) { _snack('No employees to export', Colors.orange); return; }
    try {
      final pdf = pw.Document();
      final rows = data.asMap().entries.map((e) {
        final emp = e.value;
        return ['${e.key + 1}', emp.name, emp.role, emp.phone, emp.salary.toStringAsFixed(0),
          _fmtDate(emp.dateHired), emp.isActive ? 'Active' : 'Inactive'];
      }).toList();

      const rpp = 22;
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
                decoration: const pw.BoxDecoration(color: PdfColors.indigo800, borderRadius: pw.BorderRadius.all(pw.Radius.circular(6))),
                child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.Text('FlavianoPOS - PRO', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                    pw.Text('EMPLOYEE LIST', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.yellow)),
                  ]),
                  pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                    pw.Text('Branch: ${widget.branchName}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.white)),
                    pw.Text('Generated: ${_fmtDateTime(DateTime.now())}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey300)),
                  ]),
                ]),
              ),
              pw.SizedBox(height: 6),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: pw.BoxDecoration(color: PdfColors.indigo50, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4))),
                child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceAround, children: [
                  _pdfStat('Total', '${data.length}'),
                  _pdfStat('Active', '$_activeCount'),
                  _pdfStat('Total Salary', _totalSalary.toStringAsFixed(0)),
                ]),
              ),
              pw.SizedBox(height: 8),
            ],
            if (p > 0) ...[
              pw.Text('Employee List (continued)', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo800)),
              pw.SizedBox(height: 8),
            ],
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo800),
              headerAlignment: pw.Alignment.center,
              cellStyle: const pw.TextStyle(fontSize: 7.5),
              cellAlignment: pw.Alignment.centerLeft,
              cellAlignments: {0: pw.Alignment.center, 4: pw.Alignment.centerRight},
              headerPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
              oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
              headers: ['#', 'Name', 'Role', 'Phone', 'Salary', 'Date Hired', 'Status'],
              data: chunks[p],
            ),
            pw.Spacer(),
            pw.Divider(color: PdfColors.grey400),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text('Total: ${data.length} employees', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
              pw.Text('Page ${p + 1} of ${chunks.length}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
              pw.Text('System-generated from FlavianoPOS - PRO', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500)),
            ]),
          ]),
        ));
      }

      final pdfBytes = await pdf.save();
      await saveFileBytes('employees_${widget.branchId}_${DateTime.now().millisecondsSinceEpoch}.pdf', pdfBytes);
      if (mounted) _snack('PDF exported!', Colors.green.shade700);
    } catch (e) { if (mounted) _snack('Export error: $e', Colors.red); }
  }

  static pw.Widget _pdfStat(String label, String value) => pw.Column(children: [
    pw.Text(value, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo800)),
    pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
  ]);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.branchName} Staff', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.indigo[700], foregroundColor: Colors.white,
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
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(children: [
        Container(color: Colors.white, padding: const EdgeInsets.all(12), child: Column(children: [
          Row(children: [
            _statCard('Total', '${_employees.length}', Icons.people, Colors.indigo),
            const SizedBox(width: 6),
            _statCard('Active', '$_activeCount', Icons.check_circle, Colors.green),
            const SizedBox(width: 6),
            _statCard('Salary', '${_formatCompact(_totalSalary)}', Icons.money, Colors.orange),
          ]),
          const SizedBox(height: 10),
          TextField(controller: _searchCtrl,
            decoration: InputDecoration(hintText: 'Search name, role, phone...', prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchCtrl.clear(); setState(() => _query = ''); }) : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), isDense: true, filled: true, fillColor: Colors.grey[100],
              contentPadding: const EdgeInsets.symmetric(vertical: 0)),
            onChanged: (v) => setState(() => _query = v)),
        ])),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Align(alignment: Alignment.centerLeft,
            child: Text('${_filtered.length} employee(s)', style: TextStyle(fontSize: 13, color: Colors.grey[600])))),
        Expanded(child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filtered.isEmpty
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.people_outline, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 10),
                Text('No employees found', style: TextStyle(color: Colors.grey[500], fontSize: 16)),
                const SizedBox(height: 16),
                ElevatedButton.icon(onPressed: _addEmployee, icon: const Icon(Icons.person_add),
                  label: const Text('Add First Employee'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo[700], foregroundColor: Colors.white)),
              ]))
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _filtered.length,
                itemBuilder: (_, i) {
                  final e = _filtered[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: (e.isActive ? Colors.indigo : Colors.grey).withAlpha(60))),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: CircleAvatar(
                        backgroundColor: (e.isActive ? Colors.indigo : Colors.grey).withAlpha(30),
                        child: Text(e.name.isNotEmpty ? e.name[0].toUpperCase() : '?',
                          style: TextStyle(fontWeight: FontWeight.bold, color: e.isActive ? Colors.indigo[700] : Colors.grey))),
                      title: Row(children: [
                        Expanded(child: Text(e.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: (e.isActive ? Colors.green : Colors.grey).withAlpha(20), borderRadius: BorderRadius.circular(8)),
                          child: Text(e.isActive ? 'Active' : 'Inactive',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: e.isActive ? Colors.green : Colors.grey))),
                      ]),
                      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const SizedBox(height: 4),
                        Text(e.role, style: TextStyle(fontSize: 12, color: Colors.indigo[600], fontWeight: FontWeight.w500)),
                        if (e.phone.isNotEmpty) Text(e.phone, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                        Row(children: [
                          if (e.salary > 0) Text('P${e.salary.toStringAsFixed(0)}', style: TextStyle(fontSize: 11, color: Colors.green[700], fontWeight: FontWeight.w600)),
                          if (e.salary > 0) const SizedBox(width: 10),
                          Text('Hired: ${_fmtDate(e.dateHired)}', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                        ]),
                      ]),
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) {
                          if (v == 'call') _callPhone(e.phone);
                          if (v == 'sms') _sendSms(e.phone);
                          if (v == 'edit') _editEmployee(e);
                          if (v == 'delete') _deleteEmployee(e);
                        },
                        itemBuilder: (_) => [
                          if (e.phone.isNotEmpty) const PopupMenuItem(value: 'call', child: Row(children: [Icon(Icons.phone, color: Colors.green, size: 18), SizedBox(width: 8), Text('Call')])),
                          if (e.phone.isNotEmpty) const PopupMenuItem(value: 'sms', child: Row(children: [Icon(Icons.sms, color: Colors.blue, size: 18), SizedBox(width: 8), Text('SMS')])),
                          const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, color: Colors.indigo, size: 18), SizedBox(width: 8), Text('Edit')])),
                          const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, color: Colors.red, size: 18), SizedBox(width: 8), Text('Delete')])),
                        ],
                      ),
                      onTap: () => _editEmployee(e),
                    ),
                  );
                }),
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addEmployee, backgroundColor: Colors.indigo[700], foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add), label: const Text('Add Employee')),
    );
  }

  String _formatCompact(double v) {
    if (v >= 1000000000) return '${(v / 1000000000).toStringAsFixed(1)}Bn';
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(2);
  }

  Widget _statCard(String label, String value, IconData icon, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(color: color.withAlpha(15), borderRadius: BorderRadius.circular(10)),
      child: Column(children: [
        Icon(icon, color: color, size: 18),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color)),
        Text(label, style: TextStyle(fontSize: 9, color: Colors.grey[600])),
      ]),
    ));
}
