import 'package:flutter/material.dart';
import '../../models/employee_model.dart';

class AddEmployeeScreen extends StatefulWidget {
  final String branchId;
  final String branchName;
  final Employee? employee;
  const AddEmployeeScreen({super.key, required this.branchId, required this.branchName, this.employee});
  @override
  State<AddEmployeeScreen> createState() => _AddEmployeeScreenState();
}

class _AddEmployeeScreenState extends State<AddEmployeeScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _salaryCtrl;
  late TextEditingController _notesCtrl;
  String _role = 'Staff';
  bool _isActive = true;
  DateTime _dateHired = DateTime.now();

  static const roles = ['Store Manager', 'Assistant Manager', 'Cashier', 'Inventory Clerk', 'Staff', 'Security', 'Rider', 'Other'];

  bool get _isEditing => widget.employee != null;

  @override
  void initState() {
    super.initState();
    final e = widget.employee;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _phoneCtrl = TextEditingController(text: e?.phone ?? '');
    _emailCtrl = TextEditingController(text: e?.email ?? '');
    _salaryCtrl = TextEditingController(text: e != null ? e.salary.toStringAsFixed(0) : '');
    _notesCtrl = TextEditingController(text: e?.notes ?? '');
    if (e != null) { _role = e.role; _isActive = e.isActive; _dateHired = e.dateHired; }
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _phoneCtrl.dispose(); _emailCtrl.dispose();
    _salaryCtrl.dispose(); _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(context: context, initialDate: _dateHired, firstDate: DateTime(2015), lastDate: DateTime.now());
    if (picked != null) setState(() => _dateHired = picked);
  }

  String _fmtD(DateTime d) => '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _save() async {
    if (_formKey.currentState!.validate()) {
      final emp = Employee(
        id: widget.employee?.id ?? 'E-${DateTime.now().millisecondsSinceEpoch}',
        branchId: widget.branchId,
        name: _nameCtrl.text.trim(),
        role: _role,
        phone: _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        salary: double.tryParse(_salaryCtrl.text) ?? 0,
        isActive: _isActive,
        dateHired: _dateHired,
        notes: _notesCtrl.text.trim(),
      );

      if (_isEditing) {
        await EmployeeStorage.updateEmployee(emp);
      } else {
        await EmployeeStorage.addEmployee(emp);
      }
      if (mounted) Navigator.pop(context, emp);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Employee' : 'Add Employee', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.indigo[700], foregroundColor: Colors.white,
        actions: [
          TextButton.icon(onPressed: _save,
            icon: const Icon(Icons.save, color: Colors.white),
            label: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.indigo[50], borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                Icon(Icons.store, color: Colors.indigo[700], size: 20),
                const SizedBox(width: 10),
                Text('Branch: ${widget.branchName}', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo[800])),
              ]),
            ),
            const SizedBox(height: 20),
            _sec('Personal Info', Icons.person),
            const SizedBox(height: 12),
            TextFormField(controller: _nameCtrl,
              decoration: _dec('Full Name *', Icons.person),
              textCapitalization: TextCapitalization.words,
              validator: (v) => v == null || v.isEmpty ? 'Required' : null),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _role,
              decoration: _dec('Role', Icons.badge),
              items: roles.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
              onChanged: (v) => setState(() => _role = v!),
            ),
            const SizedBox(height: 20),
            _sec('Contact', Icons.contact_phone),
            const SizedBox(height: 12),
            TextFormField(controller: _phoneCtrl,
              decoration: _dec('Phone (Optional)', Icons.phone),
              keyboardType: TextInputType.phone),
            const SizedBox(height: 12),
            TextFormField(controller: _emailCtrl,
              decoration: _dec('Email (Optional)', Icons.email),
              keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 20),
            _sec('Employment', Icons.work),
            const SizedBox(height: 12),
            TextFormField(controller: _salaryCtrl,
              decoration: _dec('Salary (Optional)', Icons.money),
              keyboardType: TextInputType.number),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[400]!),
                  borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  Icon(Icons.calendar_today, size: 18, color: Colors.indigo[700]),
                  const SizedBox(width: 10),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Date Hired', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                    Text(_fmtD(_dateHired), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  ]),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(controller: _notesCtrl,
              decoration: _dec('Notes (Optional)', Icons.note), maxLines: 2),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Active Employee', style: TextStyle(fontWeight: FontWeight.w500)),
              subtitle: Text(_isActive ? 'Currently employed' : 'Inactive / Separated'),
              value: _isActive,
              onChanged: (v) => setState(() => _isActive = v),
              secondary: Icon(_isActive ? Icons.check_circle : Icons.block,
                color: _isActive ? Colors.green : Colors.grey),
            ),
            const SizedBox(height: 24),
            SizedBox(width: double.infinity, height: 50,
              child: ElevatedButton.icon(onPressed: _save,
                icon: Icon(_isEditing ? Icons.save : Icons.person_add),
                label: Text(_isEditing ? 'UPDATE EMPLOYEE' : 'ADD EMPLOYEE',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo[700], foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
          ]),
        ),
      ),
    );
  }

  Widget _sec(String t, IconData i) => Row(children: [
    Icon(i, size: 20, color: Colors.indigo[700]), const SizedBox(width: 8),
    Text(t, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.indigo[800])),
  ]);

  InputDecoration _dec(String l, IconData i) => InputDecoration(
    labelText: l, prefixIcon: Icon(i),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)));
}
