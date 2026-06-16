import 'dart:convert';
import 'dart:typed_data';
// lib/screens/branches/branch_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/branch_model.dart';
import 'employee_list_screen.dart';
import '../../models/employee_model.dart';
import 'add_employee_screen.dart';
import 'add_branch_screen.dart';

class BranchDetailScreen extends StatefulWidget {
  final Branch branch;
  final Function(Branch) onUpdate;
  const BranchDetailScreen({
    super.key,
    required this.branch,
    required this.onUpdate,
  });
  @override
  State<BranchDetailScreen> createState() => _BranchDetailScreenState();
}

class _BranchDetailScreenState extends State<BranchDetailScreen> {
  late Branch _branch;
  List<Employee> _employees = [];
  @override
  void initState() {
    super.initState();
    _branch = widget.branch;
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    final list = await EmployeeStorage.getByBranch(_branch.id);
    setState(() => _employees = list);
  }

  Future<void> _callPhone() async {
    if (_branch.phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No phone number'), behavior: SnackBarBehavior.floating));
      return;
    }
    final uri = Uri.parse('tel:${_branch.phone}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cannot call ${_branch.phone}'), behavior: SnackBarBehavior.floating));
      }
    }
  }

  Future<void> _sendEmail() async {
    if (_branch.email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No email address'), behavior: SnackBarBehavior.floating));
      return;
    }
    final uri = Uri.parse('mailto:${_branch.email}?subject=FlavianoPOS - ${_branch.name}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cannot email ${_branch.email}'), behavior: SnackBarBehavior.floating));
      }
    }
  }

  Future<void> _openMap() async {
    if (_branch.address.isEmpty) return;
    final encoded = Uri.encodeComponent(_branch.address);
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$encoded');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _sendSms() async {
    if (_branch.phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No phone number'), behavior: SnackBarBehavior.floating));
      return;
    }
    final uri = Uri.parse('sms:${_branch.phone}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _edit() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddBranchScreen(branch: _branch)),
    );
    if (result != null && result is Branch) {
      setState(() => _branch = result);
      widget.onUpdate(_branch);
    }
  }

  void _toggleActive() {
    setState(() => _branch = _branch.copyWith(isActive: !_branch.isActive));
    widget.onUpdate(_branch);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${_branch.name} ${_branch.isActive ? 'activated' : 'deactivated'}',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Branch Details',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.indigo[700],
        foregroundColor: Colors.white,
        actions: [IconButton(icon: const Icon(Icons.edit), onPressed: _edit)],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: [Colors.indigo[700]!, Colors.indigo[500]!],
                  ),
                ),
                child: Column(
                  children: [
                    _buildBranchAvatar(),
                    const SizedBox(height: 12),
                    Text(
                      _branch.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _branch.id,
                      style: TextStyle(color: Colors.white.withAlpha(180)),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: (_branch.isActive ? Colors.green : Colors.grey)
                            .withAlpha(60),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _branch.isActive ? 'Active' : 'Inactive',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _stat('Users', '${_branch.userCount}'),
                        _stat('Products', '${_branch.totalProducts}'),
                        _stat(
                          'Today Sales',
                          _branch.todaySales.toStringAsFixed(0),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Quick Actions
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _actionBtn(Icons.phone, 'Call', Colors.green, _branch.phone.isNotEmpty ? _callPhone : null),
                    _actionBtn(Icons.sms, 'SMS', Colors.blue, _branch.phone.isNotEmpty ? _sendSms : null),
                    _actionBtn(Icons.email, 'Email', Colors.orange, _branch.email.isNotEmpty ? _sendEmail : null),
                    _actionBtn(Icons.map, 'Map', Colors.red, _branch.address.isNotEmpty ? _openMap : null),
                    _actionBtn(Icons.edit, 'Edit', Colors.indigo, _edit),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _toggleActive,
                    icon: Icon(_branch.isActive ? Icons.block : Icons.check_circle),
                    label: Text(_branch.isActive ? 'Deactivate' : 'Activate'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _infoRow(Icons.location_on, 'Address', _branch.address),
                    if (_branch.phone.isNotEmpty)
                      _infoRow(Icons.phone, 'Phone', _branch.phone),
                    if (_branch.email.isNotEmpty)
                      _infoRow(Icons.email, 'Email', _branch.email),
                    if (_branch.manager.isNotEmpty)
                      _infoRow(Icons.person, 'Manager', _branch.manager),
                    _infoRow(
                      Icons.calendar_today,
                      'Created',
                      '${_branch.createdDate.month}/${_branch.createdDate.day}/${_branch.createdDate.year}',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _section('Performance Overview', Icons.bar_chart),
            const SizedBox(height: 8),
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _perfRow(
                      'Today Sales',
                      _branch.todaySales.toStringAsFixed(2),
                      Colors.green,
                    ),
                    const Divider(),
                    _perfRow(
                      'This Week',
                      (_branch.todaySales * 6).toStringAsFixed(2),
                      Colors.blue,
                    ),
                    const Divider(),
                    _perfRow(
                      'This Month',
                      (_branch.todaySales * 25).toStringAsFixed(2),
                      Colors.orange,
                    ),
                    const Divider(),
                    _perfRow(
                      'Transactions Today',
                      '${(_branch.todaySales / 250).round()}',
                      Colors.purple,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(children: [
              _section('Staff (${_employees.length})', Icons.people),
              const Spacer(),
              TextButton.icon(onPressed: () async {
                await Navigator.push(context, MaterialPageRoute(
                  builder: (_) => EmployeeListScreen(branchId: _branch.id, branchName: _branch.name)));
                _loadEmployees();
              }, icon: Icon(Icons.settings, size: 16, color: Colors.indigo[700]),
                label: Text('Manage', style: TextStyle(fontSize: 12, color: Colors.indigo[700]))),
            ]),
            const SizedBox(height: 8),
            if (_employees.isEmpty)
              Card(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: InkWell(onTap: () async {
                  await Navigator.push(context, MaterialPageRoute(
                    builder: (_) => AddEmployeeScreen(branchId: _branch.id, branchName: _branch.name)));
                  _loadEmployees();
                }, child: const Padding(padding: EdgeInsets.all(24),
                  child: Center(child: Column(children: [
                    Icon(Icons.person_add, size: 40, color: Colors.grey),
                    SizedBox(height: 8),
                    Text('No employees yet. Tap to add', style: TextStyle(color: Colors.grey)),
                  ]))))),
            if (_employees.isNotEmpty)
              Card(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(padding: const EdgeInsets.all(12),
                  child: Column(children: _employees.map((e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(children: [
                      CircleAvatar(radius: 16, backgroundColor: (e.isActive ? Colors.indigo : Colors.grey).withAlpha(25),
                        child: Text(e.name.isNotEmpty ? e.name[0].toUpperCase() : '?',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: e.isActive ? Colors.indigo[700] : Colors.grey))),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(e.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        Text(e.role, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                      ])),
                      if (e.phone.isNotEmpty) IconButton(icon: const Icon(Icons.phone, size: 18, color: Colors.green),
                        onPressed: () async { final uri = Uri.parse('tel:${e.phone}'); if (await canLaunchUrl(uri)) await launchUrl(uri); },
                        constraints: const BoxConstraints(), padding: const EdgeInsets.all(4)),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: (e.isActive ? Colors.green : Colors.grey).withAlpha(20), borderRadius: BorderRadius.circular(6)),
                        child: Text(e.isActive ? 'Active' : 'Inactive',
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: e.isActive ? Colors.green : Colors.grey))),
                    ]),
                  )).toList()))),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildBranchAvatar() {
    if (_branch.imagePath != null && _branch.imagePath!.isNotEmpty) {
      try {
        String b64 = _branch.imagePath!;
        if (b64.contains(',')) b64 = b64.split(',').last;
        if (b64.length > 200) {
          final bytes = base64Decode(b64);
          return Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withAlpha(80), width: 2),
            ),
            child: ClipOval(
              child: Image.memory(Uint8List.fromList(bytes), fit: BoxFit.cover,
                errorBuilder: (c, e, s) => _buildStoreIcon()),
            ),
          );
        }
      } catch (_) {}
    }
    return _buildStoreIcon();
  }

  Widget _buildStoreIcon() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white.withAlpha(30), shape: BoxShape.circle),
      child: const Icon(Icons.store, size: 40, color: Colors.white),
    );
  }

  Widget _actionBtn(IconData icon, String label, Color color, VoidCallback? onTap) {
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Opacity(
        opacity: enabled ? 1.0 : 0.35,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withAlpha(20),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: enabled ? color : Colors.grey)),
        ]),
      ),
    );
  }

  Widget _stat(String label, String value) => Column(
    children: [
      Text(
        value,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      Text(
        label,
        style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 12),
      ),
    ],
  );

  Widget _infoRow(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    ),
  );

  Widget _section(String title, IconData icon) => Row(
    children: [
      Icon(icon, size: 20, color: Colors.indigo[700]),
      const SizedBox(width: 8),
      Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.indigo[800],
        ),
      ),
    ],
  );

  Widget _perfRow(String label, String value, Color color) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13)),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: color,
          ),
        ),
      ],
    ),
  );
}
