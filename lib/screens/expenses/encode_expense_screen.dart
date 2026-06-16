import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/expense_model.dart';
import '../../models/branch_model.dart';

class EncodeExpenseScreen extends StatefulWidget {
  final String currentUser, branch;
  final Expense? expense;
  const EncodeExpenseScreen({super.key, required this.currentUser, required this.branch, this.expense});
  @override
  State<EncodeExpenseScreen> createState() => _EncodeExpenseScreenState();
}

class _EncodeExpenseScreenState extends State<EncodeExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _remarksCtrl = TextEditingController();
  final _payeeCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  final _deptCtrl = TextEditingController();
  DateTime _expenseDate = DateTime.now();
  String? _categoryId, _categoryName, _subCategoryId, _subCategoryName;
  String _paymentMethod = 'Cash';
  String _expenseType = 'Regular Expense';
  String _priority = 'Normal';
  String _branch = '';
  List<ExpenseCategory> _categories = [];
  List<ExpenseSubCategory> _subCategories = [];
  List<ExpenseSubCategory> _filteredSubs = [];
  Uint8List? _attachmentBytes;
  String _attachmentName = '';
  bool _isEditing = false;
  bool _saving = false;

  static const _paymentMethods = ['Cash', 'GCash', 'Bank Transfer', 'Company Card', 'Petty Cash', 'Others'];
  static const _expenseTypes = ['Regular Expense', 'Emergency Expense', 'Reimbursement', 'Petty Cash Expense', 'Store Operating Expense'];
  static const _priorities = ['Normal', 'Urgent'];

  @override
  void initState() {
    super.initState();
    _branch = widget.branch;
    _isEditing = widget.expense != null;
    if (_isEditing) {
      final e = widget.expense!;
      _expenseDate = DateTime.tryParse(e.expenseDate) ?? DateTime.now();
      _categoryId = e.categoryId; _categoryName = e.categoryName;
      _subCategoryId = e.subCategoryId; _subCategoryName = e.subCategoryName;
      _amountCtrl.text = e.amount.toStringAsFixed(2);
      _remarksCtrl.text = e.remarks; _payeeCtrl.text = e.payeeSupplier;
      _refCtrl.text = e.referenceNumber; _deptCtrl.text = e.department;
      _paymentMethod = e.paymentMethod; _expenseType = e.expenseType;
      _priority = e.priority; _branch = e.branch;
      if (e.attachmentPath.isNotEmpty) { try { _attachmentBytes = base64Decode(e.attachmentPath); _attachmentName = e.attachmentFileName; } catch (_) {} }
    }
    _loadCategories();
  }

  @override
  void dispose() { _amountCtrl.dispose(); _remarksCtrl.dispose(); _payeeCtrl.dispose(); _refCtrl.dispose(); _deptCtrl.dispose(); super.dispose(); }

  Future<void> _loadCategories() async {
    var cats = await ExpenseStorage.getCategories();
    if (cats.isEmpty) { for (final c in ExpenseStorage.getDefaultCategories()) { await ExpenseStorage.addCategory(c); } for (final s in ExpenseStorage.getDefaultSubCategories()) { await ExpenseStorage.addSubCategory(s); } cats = await ExpenseStorage.getCategories(); }
    final subs = await ExpenseStorage.getSubCategories();
    setState(() { _categories = cats.where((c) => c.isActive).toList(); _subCategories = subs.where((s) => s.isActive).toList(); if (_categoryId != null) _filteredSubs = _subCategories.where((s) => s.categoryId == _categoryId).toList(); });
  }

  Future<void> _pickAttachment() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1200, imageQuality: 80);
    if (picked != null) { final bytes = await picked.readAsBytes(); setState(() { _attachmentBytes = bytes; _attachmentName = picked.name; }); }
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(context: context, initialDate: _expenseDate, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 7)));
    if (d != null) setState(() => _expenseDate = d);
  }

  String _fmtDate(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _save(String status) async {
    if (!_formKey.currentState!.validate()) return;
    if (_categoryId == null) { _snack('Select a category'); return; }
    if (_subCategoryId == null) { _snack('Select a sub category'); return; }
    setState(() => _saving = true);
    try {
      final now = DateTime.now();
      final id = _isEditing ? widget.expense!.id : 'EXP-${now.millisecondsSinceEpoch}';
      final expNum = _isEditing ? widget.expense!.expenseNumber : await ExpenseStorage.generateExpenseNumber();
      String attPath = ''; String attName = ''; String attType = '';
      if (_attachmentBytes != null) { attPath = base64Encode(_attachmentBytes!); attName = _attachmentName; attType = _attachmentName.split('.').last.toLowerCase(); }
      else if (_isEditing) { attPath = widget.expense!.attachmentPath; attName = widget.expense!.attachmentFileName; attType = widget.expense!.attachmentType; }
      final expense = Expense(id: id, expenseNumber: expNum, expenseDate: _fmtDate(_expenseDate), dateCreated: _isEditing ? widget.expense!.dateCreated : now.toIso8601String(), branch: _branch,
        categoryId: _categoryId!, categoryName: _categoryName!, subCategoryId: _subCategoryId!, subCategoryName: _subCategoryName!,
        amount: double.tryParse(_amountCtrl.text) ?? 0, paymentMethod: _paymentMethod, expenseType: _expenseType, priority: _priority,
        payeeSupplier: _payeeCtrl.text.trim(), referenceNumber: _refCtrl.text.trim(), remarks: _remarksCtrl.text.trim(), preparedBy: widget.currentUser,
        status: status, attachmentPath: attPath, attachmentFileName: attName, attachmentType: attType,
        createdBy: widget.currentUser, updatedBy: widget.currentUser, updatedDate: now.toIso8601String(), department: _deptCtrl.text.trim());
      if (_isEditing) { await ExpenseStorage.updateExpense(id, expense); } else { await ExpenseStorage.createExpense(expense); }
      await ExpenseStorage.addAudit(ExpenseAudit(id: 'AUD-${now.millisecondsSinceEpoch}', expenseId: id, expenseNumber: expNum,
        action: _isEditing ? 'Edited' : (status == 'Draft' ? 'Saved as Draft' : 'Submitted for Approval'),
        newValue: '${_categoryName} - ${_subCategoryName}: ${_amountCtrl.text}', performedBy: widget.currentUser, performedDate: now.toIso8601String(), branch: _branch));
      if (mounted) { _snack('Expense ${status == "Draft" ? "saved as draft" : "submitted"}!'); Navigator.pop(context, true); }
    } catch (e) { _snack('Error: $e'); } finally { if (mounted) setState(() => _saving = false); }
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), behavior: SnackBarBehavior.floating));
  InputDecoration _dec(String l, IconData ic) => InputDecoration(labelText: l, prefixIcon: Icon(ic, size: 20), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14), filled: true, fillColor: Colors.grey[50]);

  @override
  Widget build(BuildContext context) {
    final branches = Branch.allBranches.where((b) => b.isActive).toList();
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(elevation: 0, backgroundColor: const Color(0xFF6A1B9A), foregroundColor: Colors.white,
        title: Text(_isEditing ? 'Edit Expense' : 'Encode Expense', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
      body: Form(key: _formKey, child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _section('Required Information', Icons.edit_note),
        const SizedBox(height: 12),
        InkWell(onTap: _pickDate, child: InputDecorator(decoration: _dec('Expense Date *', Icons.calendar_today),
          child: Text(_fmtDate(_expenseDate), style: const TextStyle(fontSize: 14)))),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(value: _categoryId, decoration: _dec('Category *', Icons.category),
          items: _categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name, style: const TextStyle(fontSize: 14)))).toList(),
          onChanged: (v) { final cat = _categories.firstWhere((c) => c.id == v); setState(() { _categoryId = v; _categoryName = cat.name; _subCategoryId = null; _subCategoryName = null; _filteredSubs = _subCategories.where((s) => s.categoryId == v).toList(); }); },
          validator: (v) => v == null ? 'Required' : null),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(value: _subCategoryId, decoration: _dec('Sub Category *', Icons.subdirectory_arrow_right),
          items: _filteredSubs.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name, style: const TextStyle(fontSize: 14)))).toList(),
          onChanged: (v) { final sub = _filteredSubs.firstWhere((s) => s.id == v); setState(() { _subCategoryId = v; _subCategoryName = sub.name; }); },
          validator: (v) => v == null ? 'Required' : null),
        const SizedBox(height: 12),
        TextFormField(controller: _amountCtrl, decoration: _dec('Amount *', Icons.payments), keyboardType: TextInputType.number,
          validator: (v) { if (v == null || v.isEmpty) return 'Required'; final n = double.tryParse(v); if (n == null || n <= 0) return 'Must be > 0'; return null; }),
        const SizedBox(height: 12),
        TextFormField(controller: _remarksCtrl, decoration: _dec('Remarks *', Icons.notes), maxLines: 2, validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(value: _paymentMethod, decoration: _dec('Payment Method *', Icons.payment),
          items: _paymentMethods.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
          onChanged: (v) => setState(() => _paymentMethod = v!)),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(value: _branch, decoration: _dec('Branch *', Icons.store),
          items: branches.map((b) => DropdownMenuItem(value: b.name, child: Text(b.name))).toList(),
          onChanged: (v) => setState(() => _branch = v!),
          validator: (v) => v == null || v.isEmpty ? 'Required' : null),
        const SizedBox(height: 20),
        _section('Optional Information', Icons.info_outline),
        const SizedBox(height: 12),
        TextFormField(controller: _payeeCtrl, decoration: _dec('Payee / Supplier / Vendor', Icons.business)),
        const SizedBox(height: 12),
        TextFormField(controller: _refCtrl, decoration: _dec('Reference / OR / Invoice #', Icons.receipt_long)),
        const SizedBox(height: 12),
        TextFormField(controller: _deptCtrl, decoration: _dec('Department / Cost Center', Icons.apartment)),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(value: _expenseType, decoration: _dec('Expense Type', Icons.type_specimen),
          items: _expenseTypes.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 13)))).toList(),
          onChanged: (v) => setState(() => _expenseType = v!)),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(value: _priority, decoration: _dec('Priority', Icons.flag),
          items: _priorities.map((p) => DropdownMenuItem(value: p, child: Row(children: [Icon(p == 'Urgent' ? Icons.priority_high : Icons.flag_outlined, size: 16, color: p == 'Urgent' ? Colors.red : Colors.grey), const SizedBox(width: 8), Text(p)]))).toList(),
          onChanged: (v) => setState(() => _priority = v!)),
        const SizedBox(height: 16),
        _section('Attachment', Icons.attach_file),
        const SizedBox(height: 8),
        InkWell(onTap: _pickAttachment, child: Container(width: double.infinity, padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: _attachmentBytes != null ? Colors.green : Colors.grey.shade300, width: _attachmentBytes != null ? 2 : 1)),
          child: _attachmentBytes != null
            ? Row(children: [const Icon(Icons.check_circle, color: Colors.green), const SizedBox(width: 8), Expanded(child: Text(_attachmentName, style: const TextStyle(fontSize: 13))), IconButton(icon: const Icon(Icons.close, color: Colors.red, size: 20), onPressed: () => setState(() { _attachmentBytes = null; _attachmentName = ''; }))])
            : const Column(children: [Icon(Icons.cloud_upload_outlined, size: 36, color: Colors.grey), SizedBox(height: 4), Text('Tap to attach receipt', style: TextStyle(color: Colors.grey, fontSize: 13)), Text('JPG, PNG supported', style: TextStyle(color: Colors.grey, fontSize: 10))]))),
        if (_attachmentBytes != null) Padding(padding: const EdgeInsets.only(top: 8), child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.memory(_attachmentBytes!, height: 120, width: double.infinity, fit: BoxFit.cover))),
        const SizedBox(height: 24),
        Row(children: [
          Expanded(child: OutlinedButton.icon(onPressed: _saving ? null : () => _save('Draft'), icon: const Icon(Icons.save_outlined),
            label: const Text('Save Draft', style: TextStyle(fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
          const SizedBox(width: 12),
          Expanded(flex: 2, child: ElevatedButton.icon(onPressed: _saving ? null : () => _save('For Approval'), icon: const Icon(Icons.send),
            label: Text(_saving ? 'Saving...' : 'Submit for Approval', style: const TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6A1B9A), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
        ]),
        const SizedBox(height: 20),
      ]))),
    );
  }

  Widget _section(String title, IconData icon) => Row(children: [Icon(icon, size: 18, color: const Color(0xFF6A1B9A)), const SizedBox(width: 8), Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF6A1B9A)))]);
}
