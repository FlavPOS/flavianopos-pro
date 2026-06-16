// lib/screens/users/user_detail_screen.dart
import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import 'add_user_screen.dart';

class UserDetailScreen extends StatefulWidget {
  final AppUser user;
  final Function(AppUser) onUpdate;
  const UserDetailScreen({super.key, required this.user, required this.onUpdate});
  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  late AppUser _user;
  @override
  void initState() { super.initState(); _user = widget.user; }

  void _editUser() async {
    final result = await Navigator.push(context,
        MaterialPageRoute(builder: (context) => AddUserScreen(user: _user)));
    if (result != null && result is AppUser) {
      setState(() => _user = result);
      widget.onUpdate(_user);
    }
  }

  void _toggleActive() {
    setState(() => _user = _user.copyWith(isActive: !_user.isActive));
    widget.onUpdate(_user);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${_user.name} ${_user.isActive ? 'activated' : 'deactivated'}'),
        behavior: SnackBarBehavior.floating));
  }

  void _resetPin() {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Reset PIN'),
      content: const Text('Reset PIN to default (0000)?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(onPressed: () {
          setState(() => _user = _user.copyWith(pin: '0000'));
          widget.onUpdate(_user); Navigator.pop(ctx);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('PIN reset to 0000'), behavior: SnackBarBehavior.floating));
        }, style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
            child: const Text('Reset')),
      ]));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Details', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.red[700], foregroundColor: Colors.white,
        actions: [IconButton(icon: const Icon(Icons.edit), onPressed: _editUser)]),
      body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [
        Card(elevation: 4, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(width: double.infinity, padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(colors: [Colors.red[700]!, Colors.red[500]!])),
            child: Column(children: [
              CircleAvatar(radius: 36, backgroundColor: Colors.white.withAlpha(50),
                child: Text(_user.name[0].toUpperCase(), style: const TextStyle(
                    fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white))),
              const SizedBox(height: 12),
              Text(_user.name, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              Text('@${_user.username}', style: TextStyle(color: Colors.white.withAlpha(180))),
              const SizedBox(height: 8),
              Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(color: Colors.white.withAlpha(50), borderRadius: BorderRadius.circular(20)),
                child: Text(_user.role, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))),
              const SizedBox(height: 8),
              Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                    color: (_user.isActive ? Colors.green : Colors.grey).withAlpha(50),
                    borderRadius: BorderRadius.circular(12)),
                child: Text(_user.isActive ? 'Active' : 'Inactive',
                    style: TextStyle(color: Colors.white.withAlpha(220), fontSize: 12))),
            ]))),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: OutlinedButton.icon(onPressed: _editUser,
              icon: const Icon(Icons.edit), label: const Text('Edit'))),
          const SizedBox(width: 8),
          Expanded(child: OutlinedButton.icon(onPressed: _toggleActive,
              icon: Icon(_user.isActive ? Icons.block : Icons.check_circle),
              label: Text(_user.isActive ? 'Deactivate' : 'Activate'))),
          const SizedBox(width: 8),
          Expanded(child: OutlinedButton.icon(onPressed: _resetPin,
              icon: const Icon(Icons.lock_reset), label: const Text('Reset PIN'))),
        ]),
        const SizedBox(height: 16),
        Card(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
            _infoRow(Icons.person, 'Username', '@${_user.username}'),
            _infoRow(Icons.lock, 'PIN', '****'),
            _infoRow(Icons.badge, 'Role', _user.role),
            _infoRow(Icons.store, 'Branch', _user.branch),
            if (_user.email.isNotEmpty) _infoRow(Icons.email, 'Email', _user.email),
            if (_user.phone.isNotEmpty) _infoRow(Icons.phone, 'Phone', _user.phone),
            _infoRow(Icons.calendar_today, 'Joined',
                '${_user.joinDate.month}/${_user.joinDate.day}/${_user.joinDate.year}'),
            _infoRow(Icons.access_time, 'Last Login',
                _user.lastLogin != null
                    ? '${_user.lastLogin!.month}/${_user.lastLogin!.day}/${_user.lastLogin!.year}'
                    : 'Never'),
          ]))),
        const SizedBox(height: 16),
        _buildSection('Permissions', Icons.security),
        const SizedBox(height: 8),
        Card(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(padding: const EdgeInsets.all(16), child: Column(
            children: _user.permissions.map((p) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                Icon(Icons.check_circle, color: Colors.green, size: 18),
                const SizedBox(width: 8),
                Text(p, style: const TextStyle(fontSize: 14)),
              ]))).toList()))),
        const SizedBox(height: 24),
      ])),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [
      Icon(icon, size: 18, color: Colors.grey[600]), const SizedBox(width: 12),
      Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
      const Spacer(),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))]));

  Widget _buildSection(String title, IconData icon) => Row(children: [
    Icon(icon, size: 20, color: Colors.red[700]), const SizedBox(width: 8),
    Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red[800]))]);
}

