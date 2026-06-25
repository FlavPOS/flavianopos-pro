// lib/screens/users/add_user_screen.dart

import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../models/branch_model.dart';

class AddUserScreen extends StatefulWidget {
  final AppUser? user;
  const AddUserScreen({super.key, this.user});
  @override
  State<AddUserScreen> createState() => _AddUserScreenState();
}

class _AddUserScreenState extends State<AddUserScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _usernameCtrl;
  late TextEditingController _pinCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _phoneCtrl;
  String _selectedRole = 'Cashier';
  bool _allowPosTransaction = false;
  String _selectedBranch = 'Main Branch';
  bool _isActive = true;
  late List<String> _selectedPermissions;

  bool get _isEditing => widget.user != null;

  @override
  void initState() {
    super.initState();
    final u = widget.user;
    _nameCtrl = TextEditingController(text: u?.name ?? '');
    _usernameCtrl = TextEditingController(text: u?.username ?? '');
    _pinCtrl = TextEditingController(text: u?.pin ?? '');
    _emailCtrl = TextEditingController(text: u?.email ?? '');
    _phoneCtrl = TextEditingController(text: u?.phone ?? '');
    if (u != null) {
      _selectedRole = u.role;
      _allowPosTransaction = u.allowPosTransaction;
      _selectedBranch = u.branch;
      _isActive = u.isActive;
      _selectedPermissions = List<String>.from(u.permissions);
    } else {
      _selectedPermissions = List<String>.from(AppUser.rolePresets['Cashier'] ?? []);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _usernameCtrl.dispose(); _pinCtrl.dispose();
    _emailCtrl.dispose(); _phoneCtrl.dispose(); super.dispose();
  }

  void _onRoleChanged(String role) {
    setState(() {
      _selectedRole = role;
      if (role != 'Custom') {
        _selectedPermissions = List<String>.from(AppUser.rolePresets[role] ?? []);
      }
    });
  }

  void _selectAll() => setState(() => _selectedPermissions = List<String>.from(AppUser.allModules));
  void _deselectAll() => setState(() => _selectedPermissions.clear());

  void _togglePermission(String module) {
    // Role stays as user selected - permissions are independent!
    // This preserves Cashier role → Beginning Cash flow trigger
    setState(() {
      if (_selectedPermissions.contains(module)) {
        _selectedPermissions.remove(module);
      } else {
        _selectedPermissions.add(module);
      }
    });
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      if (_selectedPermissions.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select at least one permission'), backgroundColor: Colors.red));
        return;
      }
      final user = AppUser(
        id: widget.user?.id ?? 'USR-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
        name: _nameCtrl.text.trim(), username: _usernameCtrl.text.trim(),
        pin: _pinCtrl.text.trim(), email: _emailCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(), role: _selectedRole,
        branch: _selectedBranch, isActive: _isActive,
        joinDate: widget.user?.joinDate ?? DateTime.now(),
        lastLogin: widget.user?.lastLogin, permissions: _selectedPermissions, allowPosTransaction: _allowPosTransaction);
      Navigator.pop(context, user);
    }
  }

  @override
  Widget build(BuildContext context) {
    final branches = Branch.allBranches.map((b) => b.name).toList();
    if (!branches.contains(_selectedBranch)) branches.add(_selectedBranch);
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit User' : 'Add User', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.red[700], foregroundColor: Colors.white,
        actions: [TextButton.icon(onPressed: _save,
            icon: const Icon(Icons.save, color: Colors.white),
            label: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))]),
      body: SingleChildScrollView(padding: const EdgeInsets.all(16),
        child: Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _header('Account Info', Icons.person), const SizedBox(height: 12),
          TextFormField(controller: _nameCtrl, decoration: _dec('Full Name', Icons.person_outline),
              textCapitalization: TextCapitalization.words,
              validator: (v) => v == null || v.isEmpty ? 'Required' : null),
          const SizedBox(height: 12),
          TextFormField(controller: _usernameCtrl, decoration: _dec('Username', Icons.alternate_email),
              validator: (v) => v == null || v.isEmpty ? 'Required' : null),
          const SizedBox(height: 12),
          TextFormField(controller: _pinCtrl, decoration: _dec('PIN (6 digits)', Icons.lock),
              keyboardType: TextInputType.number, maxLength: 6, obscureText: true,
              validator: (v) { if (v == null || v.isEmpty) return 'Required';
                if (v.length != 6) return 'PIN must be 6 digits'; return null; }),
          const SizedBox(height: 12),
          _header('Contact', Icons.contact_mail), const SizedBox(height: 12),
          TextFormField(controller: _emailCtrl, decoration: _dec('Email (Optional)', Icons.email),
              keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 12),
          TextFormField(controller: _phoneCtrl, decoration: _dec('Phone (Optional)', Icons.phone),
              keyboardType: TextInputType.phone),
          const SizedBox(height: 24),
          _header('Role & Branch', Icons.badge), const SizedBox(height: 12),
          DropdownButtonFormField<String>(value: AppUser.availableRoles.contains(_selectedRole) ? _selectedRole : 'Custom',
            decoration: _dec('Role', Icons.admin_panel_settings),
            items: AppUser.availableRoles.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
            onChanged: (v) { if (v != null) _onRoleChanged(v); }),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(value: _selectedBranch,
            decoration: _dec('Branch', Icons.store),
            items: branches.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
            onChanged: (v) => setState(() => _selectedBranch = v!)),
          const SizedBox(height: 12),
          SwitchListTile(title: const Text('Active', style: TextStyle(fontWeight: FontWeight.w500)),
            subtitle: Text(_isActive ? 'User can login' : 'User is disabled', style: const TextStyle(fontSize: 12)),
            value: _isActive, onChanged: (v) => setState(() => _isActive = v)),

          // 🔒 BIR-grade POS Transaction permission (only for privileged roles)
          if (['Admin', 'Manager', 'Supervisor'].contains(_selectedRole)) ...[
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: SwitchListTile(
                title: const Text('Allow POS Transaction',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text(
                  'Permission to process sales transactions (BIR-compliant). Cashier role always allowed.',
                  style: TextStyle(fontSize: 11),
                ),
                value: _allowPosTransaction,
                onChanged: (v) => setState(() => _allowPosTransaction = v),
                secondary: Icon(
                  Icons.shopping_cart_checkout,
                  color: _allowPosTransaction ? Colors.green : Colors.grey,
                ),
                activeColor: Colors.green,
              ),
            ),
          ],
          if (_selectedRole == 'Cashier') ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(children: [
                Icon(Icons.check_circle, color: Colors.green.shade700, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Cashier role: POS transactions always allowed',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ]),
            ),
          ],
          const SizedBox(height: 24),
          Row(children: [
            _header('Module Permissions', Icons.security), const Spacer(),
            TextButton(onPressed: _selectAll, child: const Text('Select All', style: TextStyle(fontSize: 11))),
            TextButton(onPressed: _deselectAll, child: const Text('Clear All', style: TextStyle(fontSize: 11, color: Colors.red))),
          ]),
          const SizedBox(height: 4),
          Container(padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              Icon(Icons.info_outline, size: 14, color: Colors.red[400]), const SizedBox(width: 6),
              Expanded(child: Text('${_selectedPermissions.length} of ${AppUser.allModules.length} modules selected',
                style: TextStyle(fontSize: 11, color: Colors.red[700], fontWeight: FontWeight.w600))),
            ])),
          const SizedBox(height: 8),
          ...AppUser.moduleCategories.entries.map((entry) => _buildCategorySection(entry.key, entry.value)),
          const SizedBox(height: 24),
          SizedBox(width: double.infinity, height: 50, child: ElevatedButton.icon(
            onPressed: _save, icon: Icon(_isEditing ? Icons.save : Icons.person_add),
            label: Text(_isEditing ? 'UPDATE USER' : 'ADD USER',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700], foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
        ]))),
    );
  }

  Widget _buildCategorySection(String category, List<String> modules) {
    final icons = {'Sales': Icons.point_of_sale, 'Reports': Icons.analytics, 'Inventory': Icons.inventory_2, 'Management': Icons.settings};
    final colors = {'Sales': Colors.green, 'Reports': Colors.blue, 'Inventory': Colors.orange, 'Management': Colors.purple};
    final color = colors[category] ?? Colors.grey;
    final modIcons = {'Dashboard': Icons.dashboard, 'Cashiering': Icons.point_of_sale, 'Inventory': Icons.inventory_2,
      'Stock Adjustment': Icons.tune, 'Stock Transfer': Icons.swap_horiz, 'Receive Delivery': Icons.local_shipping,
      'Item Ledger': Icons.receipt_long, 'Batch Management': Icons.layers, 'Sales History': Icons.history,
      'Sales Analytics': Icons.analytics, 'Z Report': Icons.assessment, 'Discount Monitoring': Icons.local_offer,
      'Customers': Icons.people, 'Branches': Icons.store, 'Users': Icons.group, 'Settings': Icons.settings};
    return Card(margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10))),
          child: Row(children: [
            Icon(icons[category] ?? Icons.folder, color: color, size: 18), const SizedBox(width: 8),
            Text(category, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13)),
            const Spacer(),
            Text('${modules.where((m) => _selectedPermissions.contains(m)).length}/${modules.length}',
              style: TextStyle(fontSize: 11, color: color)),
          ])),
        ...modules.map((module) => CheckboxListTile(
          value: _selectedPermissions.contains(module), onChanged: (_) => _togglePermission(module),
          title: Text(module, style: const TextStyle(fontSize: 13)),
          secondary: Icon(modIcons[module] ?? Icons.circle, size: 20, color: Colors.grey[600]),
          dense: true, controlAffinity: ListTileControlAffinity.trailing)),
      ]));
  }

  Widget _header(String t, IconData i) => Row(children: [
    Icon(i, size: 20, color: Colors.red[700]), const SizedBox(width: 8),
    Text(t, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red[800]))]);

  InputDecoration _dec(String l, IconData i) => InputDecoration(labelText: l, prefixIcon: Icon(i),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)));
}
