// lib/screens/expenses/encode_expense_screen.dart
// FlavianoPOS - PRO: Encode Expense (Mobile + Tablet + Web)
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../models/settings_model.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/expense_model.dart';
import '../../utils/expense_submit_dialog.dart';
import '../../utils/responsive.dart';

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
      if (e.attachmentPath.isNotEmpty) {
        try { _attachmentBytes = base64Decode(e.attachmentPath); _attachmentName = e.attachmentFileName; } catch (_) {}
      }
    }
    _loadCategories();
  }

  @override
  void dispose() {
    _amountCtrl.dispose(); _remarksCtrl.dispose(); _payeeCtrl.dispose();
    _refCtrl.dispose(); _deptCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    var cats = await ExpenseStorage.getCategories();
    if (cats.isEmpty) {
      for (final c in ExpenseStorage.getDefaultCategories()) { await ExpenseStorage.addCategory(c); }
      for (final s in ExpenseStorage.getDefaultSubCategories()) { await ExpenseStorage.addSubCategory(s); }
      cats = await ExpenseStorage.getCategories();
    }
    final subs = await ExpenseStorage.getSubCategories();
    setState(() {
      _categories = cats.where((c) => c.isActive).toList();
      _subCategories = subs.where((s) => s.isActive).toList();
      if (_categoryId != null) {
        _filteredSubs = _subCategories.where((s) => s.categoryId == _categoryId).toList();
      }
    });
  }

  Future<void> _pickAttachment({required ImageSource source}) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, maxWidth: 1200, imageQuality: 80);
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _attachmentBytes = bytes;
          _attachmentName = picked.name;
        });
      }
    } catch (e) {
      if (mounted) _snack('Could not pick image: $e', Colors.red);
    }
  }

  void _showAttachmentMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(top: 12, bottom: 8),
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          ListTile(
            leading: Container(padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.camera_alt, color: Colors.blue.shade700)),
            title: const Text('Take Photo', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Snap receipt with camera'),
            onTap: () { Navigator.pop(ctx); _pickAttachment(source: ImageSource.camera); },
          ),
          ListTile(
            leading: Container(padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.photo_library, color: Colors.green.shade700)),
            title: const Text('Choose from Gallery', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Pick existing receipt photo'),
            onTap: () { Navigator.pop(ctx); _pickAttachment(source: ImageSource.gallery); },
          ),
          if (_attachmentBytes != null)
            ListTile(
              leading: Container(padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.delete, color: Colors.red.shade700)),
              title: const Text('Remove Attachment', style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(ctx);
                setState(() { _attachmentBytes = null; _attachmentName = ''; });
              },
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _expenseDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 7)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF7B1FA2)),
        ),
        child: child!,
      ),
    );
    if (d != null) setState(() => _expenseDate = d);
  }

  String _fmtDate(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _save(String status) async {
    if (!_formKey.currentState!.validate()) return;
    if (_categoryId == null) { _snack('Select a category', Colors.orange); return; }
    if (_subCategoryId == null) { _snack('Select a sub category', Colors.orange); return; }
    setState(() => _saving = true);
    try {
      final now = DateTime.now();
      final id = _isEditing ? widget.expense!.id : 'EXP-${now.millisecondsSinceEpoch}';
      final expNum = _isEditing ? widget.expense!.expenseNumber : await ExpenseStorage.generateExpenseNumber();
      String attPath = ''; String attName = ''; String attType = '';
      if (_attachmentBytes != null) {
        attPath = base64Encode(_attachmentBytes!);
        attName = _attachmentName;
        attType = _attachmentName.contains('.') ? _attachmentName.split('.').last.toLowerCase() : '';
      } else if (_isEditing) {
        attPath = widget.expense!.attachmentPath;
        attName = widget.expense!.attachmentFileName;
        attType = widget.expense!.attachmentType;
      }
      final expense = Expense(
        id: id, expenseNumber: expNum,
        expenseDate: _fmtDate(_expenseDate),
        dateCreated: _isEditing ? widget.expense!.dateCreated : now.toIso8601String(),
        branch: _branch,
        categoryId: _categoryId!, categoryName: _categoryName!,
        subCategoryId: _subCategoryId!, subCategoryName: _subCategoryName!,
        amount: double.tryParse(_amountCtrl.text) ?? 0,
        paymentMethod: _paymentMethod, expenseType: _expenseType, priority: _priority,
        payeeSupplier: _payeeCtrl.text.trim(),
        referenceNumber: _refCtrl.text.trim(),
        remarks: _remarksCtrl.text.trim(),
        preparedBy: widget.currentUser,
        status: status,
        attachmentPath: attPath, attachmentFileName: attName, attachmentType: attType,
        createdBy: widget.currentUser, updatedBy: widget.currentUser,
        updatedDate: now.toIso8601String(),
        department: _deptCtrl.text.trim(),
      );
      if (_isEditing) {
        await ExpenseStorage.updateExpense(id, expense);
      } else {
        await ExpenseStorage.createExpense(expense);
      }
      await ExpenseStorage.addAudit(ExpenseAudit(
        id: 'AUD-${now.millisecondsSinceEpoch}',
        expenseId: id, expenseNumber: expNum,
        action: _isEditing ? 'Edited' : (status == 'Draft' ? 'Saved as Draft' : 'Submitted for Approval'),
        newValue: '$_categoryName - $_subCategoryName: ${_amountCtrl.text}',
        performedBy: widget.currentUser,
        performedDate: now.toIso8601String(),
        branch: _branch,
      ));
      if (mounted) {
        if (status == 'Draft') { _snack('Saved as draft', Colors.green); Navigator.pop(context, true); } else { await ExpenseSubmitDialog.show(context, expense); if (mounted) Navigator.pop(context, true); }
      }
    } catch (e) {
      if (mounted) _snack('Error: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String m, Color c) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(m, style: const TextStyle(fontWeight: FontWeight.w600)),
    backgroundColor: c,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  ));

  // ════════════ BUILD ════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F3F8),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF7B1FA2),
        foregroundColor: Colors.white,
        title: Text(_isEditing ? 'Edit Expense' : 'New Expense',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: Responsive.titleSz(context))),
      ),
      body: Responsive.centered(
        context: context,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              Responsive.pad(context), Responsive.pad(context),
              Responsive.pad(context), 100, // bottom padding for sticky bar
            ),
            child: _buildResponsiveLayout(context),
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomBar(context),
    );
  }

  Widget _buildResponsiveLayout(BuildContext context) {
    if (Responsive.isWeb(context)) {
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(flex: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _sectionAmount(context),
          const SizedBox(height: 16),
          _sectionCategory(context),
        ])),
        const SizedBox(width: 16),
        Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _sectionDetails(context),
          const SizedBox(height: 16),
          _sectionAttachment(context),
        ])),
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionAmount(context),
      const SizedBox(height: 16),
      _sectionCategory(context),
      const SizedBox(height: 16),
      _sectionDetails(context),
      const SizedBox(height: 16),
      _sectionAttachment(context),
    ]);
  }

  // ════════════ SECTION: AMOUNT (Hero) ════════════
  Widget _sectionAmount(BuildContext context) => _card(context, [
    _sectionTitle(context, '💰', 'Amount', const Color(0xFF7B1FA2)),
    const SizedBox(height: 14),
    TextFormField(
      controller: _amountCtrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
      style: TextStyle(
        fontSize: Responsive.isPhone(context) ? 32 : 40,
        fontWeight: FontWeight.bold,
        color: const Color(0xFF7B1FA2),
      ),
      textAlign: TextAlign.center,
      decoration: InputDecoration(
        prefixText: '${AppSettings.currencySymbol} ',
        prefixStyle: TextStyle(
          fontSize: Responsive.isPhone(context) ? 28 : 36,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF7B1FA2),
        ),
        hintText: '0.00',
        hintStyle: TextStyle(
          fontSize: Responsive.isPhone(context) ? 32 : 40,
          color: Colors.grey.shade300,
        ),
        filled: true,
        fillColor: const Color(0xFF7B1FA2).withValues(alpha: 0.05),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: const Color(0xFF7B1FA2).withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF7B1FA2), width: 2),
        ),
      ),
      validator: (v) {
        if (v == null || v.isEmpty) return 'Required';
        final n = double.tryParse(v);
        if (n == null || n <= 0) return 'Enter valid amount';
        return null;
      },
    ),
    const SizedBox(height: 14),
    _priorityChips(context),
  ]);

  Widget _priorityChips(BuildContext context) => Wrap(spacing: 8, children: _priorities.map((p) {
    final selected = _priority == p;
    final color = p == 'Urgent' ? Colors.red.shade700 : Colors.blue.shade600;
    return ChoiceChip(
      label: Row(mainAxisSize: MainAxisSize.min, children: [
        if (p == 'Urgent') Icon(Icons.priority_high, size: 14, color: selected ? Colors.white : color),
        Text(p, style: TextStyle(
          color: selected ? Colors.white : color,
          fontWeight: FontWeight.w600, fontSize: 12)),
      ]),
      selected: selected,
      selectedColor: color,
      backgroundColor: color.withValues(alpha: 0.1),
      side: BorderSide(color: selected ? color : color.withValues(alpha: 0.3)),
      onSelected: (_) => setState(() => _priority = p),
    );
  }).toList());

  // ════════════ SECTION: CATEGORY ════════════
  Widget _sectionCategory(BuildContext context) => _card(context, [
    _sectionTitle(context, '📁', 'Category', Colors.orange.shade700),
    const SizedBox(height: 14),
    DropdownButtonFormField<String>(
      initialValue: _categoryId,
      isExpanded: true,
      decoration: _inputDec('Category *', Icons.category),
      items: _categories.map((c) => DropdownMenuItem(value: c.id,
        child: Text(c.name, overflow: TextOverflow.ellipsis))).toList(),
      onChanged: (v) {
        if (v == null) return;
        final cat = _categories.firstWhere((c) => c.id == v);
        setState(() {
          _categoryId = v; _categoryName = cat.name;
          _subCategoryId = null; _subCategoryName = null;
          _filteredSubs = _subCategories.where((s) => s.categoryId == v).toList();
        });
      },
      validator: (v) => v == null ? 'Required' : null,
    ),
    const SizedBox(height: 12),
    DropdownButtonFormField<String>(
      initialValue: _subCategoryId,
      isExpanded: true,
      decoration: _inputDec('Sub-Category *', Icons.subdirectory_arrow_right),
      items: _filteredSubs.map((s) => DropdownMenuItem(value: s.id,
        child: Text(s.name, overflow: TextOverflow.ellipsis))).toList(),
      onChanged: _filteredSubs.isEmpty ? null : (v) {
        if (v == null) return;
        final sub = _filteredSubs.firstWhere((s) => s.id == v);
        setState(() { _subCategoryId = v; _subCategoryName = sub.name; });
      },
      validator: (v) => v == null ? 'Required' : null,
    ),
    if (_filteredSubs.isEmpty && _categoryId != null) ...[
      const SizedBox(height: 6),
      Text('No sub-categories. Add some in Settings.',
        style: TextStyle(fontSize: 11, color: Colors.orange.shade700)),
    ],
  ]);

  // ════════════ SECTION: DETAILS ════════════
  Widget _sectionDetails(BuildContext context) => _card(context, [
    _sectionTitle(context, '📝', 'Details', Colors.blue.shade700),
    const SizedBox(height: 14),
    InkWell(
      onTap: _pickDate,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: _inputDec('Expense Date *', Icons.calendar_today),
        child: Text(_fmtDate(_expenseDate), style: const TextStyle(fontSize: 14)),
      ),
    ),
    const SizedBox(height: 12),
    DropdownButtonFormField<String>(
      initialValue: _paymentMethod,
      isExpanded: true,
      decoration: _inputDec('Payment Method', Icons.payment),
      items: _paymentMethods.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
      onChanged: (v) => setState(() => _paymentMethod = v!),
    ),
    const SizedBox(height: 12),
    DropdownButtonFormField<String>(
      initialValue: _expenseType,
      isExpanded: true,
      decoration: _inputDec('Expense Type', Icons.label),
      items: _expenseTypes.map((t) => DropdownMenuItem(value: t,
        child: Text(t, overflow: TextOverflow.ellipsis))).toList(),
      onChanged: (v) => setState(() => _expenseType = v!),
    ),
    const SizedBox(height: 12),
    TextFormField(
      controller: _payeeCtrl,
      decoration: _inputDec('Payee / Supplier', Icons.person_pin),
    ),
    const SizedBox(height: 12),
    TextFormField(
      controller: _refCtrl,
      decoration: _inputDec('Reference # (Optional)', Icons.tag),
    ),
    const SizedBox(height: 12),
    TextFormField(
      controller: _deptCtrl,
      decoration: _inputDec('Department (Optional)', Icons.business),
    ),
    const SizedBox(height: 12),
    TextFormField(
      controller: _remarksCtrl,
      maxLines: 3,
      decoration: _inputDec('Remarks (Optional)', Icons.notes),
    ),
  ]);

  // ════════════ SECTION: ATTACHMENT ════════════
  Widget _sectionAttachment(BuildContext context) => _card(context, [
    _sectionTitle(context, '📷', 'Receipt Attachment', Colors.teal.shade700),
    const SizedBox(height: 14),
    if (_attachmentBytes != null)
      Stack(children: [
        Container(
          width: double.infinity,
          height: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(_attachmentBytes!, fit: BoxFit.cover),
          ),
        ),
        Positioned(top: 8, right: 8,
          child: Material(color: Colors.black54, shape: const CircleBorder(),
            child: IconButton(icon: const Icon(Icons.close, color: Colors.white, size: 18),
              onPressed: () => setState(() { _attachmentBytes = null; _attachmentName = ''; })))),
      ])
    else
      InkWell(
        onTap: _showAttachmentMenu,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 30),
          decoration: BoxDecoration(
            color: Colors.teal.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.teal.shade200, style: BorderStyle.solid, width: 1.5),
          ),
          child: Column(children: [
            Icon(Icons.cloud_upload, size: 40, color: Colors.teal.shade400),
            const SizedBox(height: 8),
            Text('Tap to Add Receipt', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade700)),
            const SizedBox(height: 4),
            Text('Camera or Gallery',
              style: TextStyle(fontSize: 11, color: Colors.teal.shade600)),
          ]),
        ),
      ),
    if (_attachmentBytes != null) ...[
      const SizedBox(height: 8),
      Row(children: [
        Icon(Icons.check_circle, color: Colors.green.shade600, size: 16),
        const SizedBox(width: 6),
        Expanded(child: Text(_attachmentName,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
          overflow: TextOverflow.ellipsis)),
        TextButton.icon(
          onPressed: _showAttachmentMenu,
          icon: const Icon(Icons.swap_horiz, size: 16),
          label: const Text('Change', style: TextStyle(fontSize: 12)),
        ),
      ]),
    ],
  ]);

  // ════════════ STICKY BOTTOM BAR ════════════
  Widget _buildBottomBar(BuildContext context) => SafeArea(
    child: Container(
      padding: EdgeInsets.all(Responsive.pad(context)),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [
        BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, -2)),
      ]),
      child: Row(children: [
        Expanded(child: OutlinedButton.icon(
          onPressed: _saving ? null : () => _save('Draft'),
          icon: const Icon(Icons.save, size: 18),
          label: const Text('Save Draft'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF7B1FA2),
            side: const BorderSide(color: Color(0xFF7B1FA2)),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        )),
        const SizedBox(width: 10),
        Expanded(flex: 2, child: ElevatedButton.icon(
          onPressed: _saving ? null : () => _save('For Approval'),
          icon: _saving
              ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.send, size: 18),
          label: Text(_saving ? 'Saving...' : 'Submit for Approval',
            style: const TextStyle(fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF7B1FA2),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        )),
      ]),
    ),
  );

  // ════════════ HELPER WIDGETS ════════════
  Widget _card(BuildContext context, List<Widget> children) => Container(
    width: double.infinity,
    padding: EdgeInsets.all(Responsive.pad(context)),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(Responsive.cardR(context)),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
  );

  Widget _sectionTitle(BuildContext context, String emoji, String title, Color color) => Row(children: [
    Text(emoji, style: const TextStyle(fontSize: 18)),
    const SizedBox(width: 8),
    Text(title, style: TextStyle(
      fontSize: Responsive.titleSz(context) - 2,
      fontWeight: FontWeight.bold,
      color: color,
    )),
  ]);

  InputDecoration _inputDec(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, size: 20),
    isDense: true,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.grey.shade300),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFF7B1FA2), width: 2),
    ),
  );
}
