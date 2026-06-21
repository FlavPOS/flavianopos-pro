// lib/screens/users/users_screen.dart
import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import 'add_user_screen.dart';
import 'user_detail_screen.dart';
import '../../utils/export_helper.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});
  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  List<AppUser> _users = [];
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedRole = 'All';
  final List<String> _roles = ['All', ...AppUser.availableRoles];


  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    await AppUser.loadFromDB();
    if (mounted) {
      setState(() {
        _users = List<AppUser>.from(AppUser.allUsers);
      });
    }
  }

  List<AppUser> get _filtered {
    return _users.where((u) {
      final matchRole = _selectedRole == 'All' || u.role == _selectedRole;
      final matchSearch = _searchQuery.isEmpty ||
          u.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          u.username.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchRole && matchSearch;
    }).toList();
  }

  int _roleCount(String r) => _users.where((u) => u.role == r).length;
  int get _activeCount => _users.where((u) => u.isActive).length;

  void _showSnackBar(String msg, {Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg), backgroundColor: color ?? Colors.blue[700],
      behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
  }

  void _addUser() async {
    final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddUserScreen()));
    if (result != null && result is AppUser && mounted) {
      AppUser.addUser(result);
      await _loadUsers();
      if (mounted) _showSnackBar('${result.name} added successfully', color: Colors.green[700]);
    }
  }

  void _openUserDetail(AppUser user) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => UserDetailScreen(
      user: user, onUpdate: (updated) {
        setState(() { AppUser.updateUser(updated.id, updated); });
      })));
  }

  void _deleteUser(AppUser user) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Delete User?'),
      content: Text('Remove ${user.name}? This cannot be undone.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(onPressed: () {
          setState(() { AppUser.deleteUser(user.id); });
          Navigator.pop(ctx);
          _showSnackBar('${user.name} deleted', color: Colors.red);
        }, style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
          child: const Text('Delete')),
      ]));
  }

  void _exportExcel() {
    final data = _filtered;
    if (data.isEmpty) { _showSnackBar('No users to export', color: Colors.orange); return; }
    final headers = ['ID', 'Name', 'Username', 'Role', 'Branch', 'Status', 'Email', 'Phone', 'Permissions', 'Join Date'];
    final rows = data.map((u) => [
      u.id, u.name, u.username, u.role, u.branch,
      u.isActive ? 'Active' : 'Inactive', u.email, u.phone,
      u.permissions.join(', '),
      '${u.joinDate.month}/${u.joinDate.day}/${u.joinDate.year}',
    ]).toList();
    ExportHelper.exportExcel(sheetName: 'Users', headers: headers, rows: rows, fileName: 'users_export');
  }

  void _exportPdf() {
    final data = _filtered;
    if (data.isEmpty) { _showSnackBar('No users to export', color: Colors.orange); return; }
    final headers = ['ID', 'Name', 'Role', 'Branch', 'Status', 'Permissions'];
    final rows = data.map((u) => [
      u.id, u.name, u.role, u.branch,
      u.isActive ? 'Active' : 'Inactive', u.permissions.join(', '),
    ]).toList();
    ExportHelper.exportPdf(title: 'Users List', headers: headers, rows: rows, fileName: 'users_export');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('\ud83d\udc65 Users', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.red[700], foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (v) {
              if (v == 'excel') _exportExcel();
              if (v == 'pdf') _exportPdf();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'excel', child: ListTile(
                leading: Icon(Icons.table_chart, color: Colors.green), title: Text('Export Excel'), contentPadding: EdgeInsets.zero)),
              const PopupMenuItem(value: 'pdf', child: ListTile(
                leading: Icon(Icons.picture_as_pdf, color: Colors.red), title: Text('Export PDF'), contentPadding: EdgeInsets.zero)),
            ],
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF5F5F5),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addUser, icon: const Icon(Icons.person_add),
        label: const Text('Add User'),
        backgroundColor: Colors.red[700], foregroundColor: Colors.white,
      ),
      body: Column(children: [
        Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6), color: Colors.white,
          child: Row(children: [
            _statCard('Total', '${_users.length}', Icons.people, Colors.red),
            const SizedBox(width: 6),
            _statCard('Active', '$_activeCount', Icons.check_circle, Colors.green),
            const SizedBox(width: 6),
            _statCard('Admin', '${_roleCount("Admin")}', Icons.admin_panel_settings, Colors.purple),
            const SizedBox(width: 6),
            _statCard('Cashier', '${_roleCount("Cashier")}', Icons.point_of_sale, Colors.blue),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: InputDecoration(
              hintText: 'Search by name or username...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(icon: const Icon(Icons.clear), onPressed: () {
                      _searchController.clear(); setState(() => _searchQuery = ''); })
                  : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              filled: true, fillColor: Colors.white,
            ),
          ),
        ),
        SizedBox(height: 36, child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          children: _roles.map((r) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: _selectedRole == r,
              label: Text(r == 'All' ? 'All (${_users.length})' : '$r (${_roleCount(r)})'),
              labelStyle: TextStyle(fontSize: 11, color: _selectedRole == r ? Colors.white : Colors.grey[700]),
              selectedColor: Colors.red[700], backgroundColor: Colors.white,
              onSelected: (_) => setState(() => _selectedRole = r),
            ),
          )).toList(),
        )),
        const SizedBox(height: 8),
        Expanded(
          child: _filtered.isEmpty
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.person_off, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 8),
                Text('No users found', style: TextStyle(color: Colors.grey[500])),
              ]))
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
                itemCount: _filtered.length,
                itemBuilder: (_, i) => _buildUserCard(_filtered[i]),
              ),
        ),
      ]),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Expanded(child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 20), const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: TextStyle(fontSize: 9, color: Colors.grey[600])),
      ]),
    ));
  }

  Widget _buildUserCard(AppUser user) {
    final roleColors = {
      'Admin': Colors.purple, 'Manager': Colors.blue,
      'Cashier': Colors.green, 'Inventory Clerk': Colors.orange, 'Custom': Colors.teal,
    };
    final color = roleColors[user.role] ?? Colors.grey;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openUserDetail(user),
        child: IntrinsicHeight(child: Row(children: [
          Container(width: 5, color: color),
          Expanded(child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              CircleAvatar(radius: 22, backgroundColor: color.withValues(alpha: 0.15),
                child: Text(user.name[0].toUpperCase(),
                  style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 18))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(user.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                    child: Text(user.role, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
                  ),
                ]),
                const SizedBox(height: 2),
                Text('@${user.username} \u00b7 ${user.branch}', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                const SizedBox(height: 4),
                Row(children: [
                  Icon(Icons.security, size: 12, color: Colors.grey[400]), const SizedBox(width: 4),
                  Text('${user.permissions.length} modules', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: (user.isActive ? Colors.green : Colors.grey).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4)),
                    child: Text(user.isActive ? 'Active' : 'Inactive',
                      style: TextStyle(fontSize: 9, color: user.isActive ? Colors.green[700] : Colors.grey[600], fontWeight: FontWeight.w600)),
                  ),
                ]),
              ])),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: Colors.grey[400], size: 20),
                onSelected: (v) {
                  if (v == 'edit') {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => AddUserScreen(user: user))).then((result) {
                      if (result != null && result is AppUser) {
                        setState(() { AppUser.updateUser(result.id, result); });
                        _showSnackBar('${result.name} updated');
                      }
                    });
                  }
                  if (v == 'toggle') {
                    setState(() { AppUser.updateUser(user.id, user.copyWith(isActive: !user.isActive)); });
                    _showSnackBar('${user.name} ${!user.isActive ? "activated" : "deactivated"}');
                  }
                  if (v == 'delete') _deleteUser(user);
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit, color: Colors.blue), title: Text('Edit'), contentPadding: EdgeInsets.zero)),
                  PopupMenuItem(value: 'toggle', child: ListTile(
                    leading: Icon(user.isActive ? Icons.block : Icons.check_circle, color: user.isActive ? Colors.orange : Colors.green),
                    title: Text(user.isActive ? 'Deactivate' : 'Activate'), contentPadding: EdgeInsets.zero)),
                  const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete, color: Colors.red), title: Text('Delete'), contentPadding: EdgeInsets.zero)),
                ],
              ),
            ]),
          )),
        ])),
      ),
    );
  }
}
