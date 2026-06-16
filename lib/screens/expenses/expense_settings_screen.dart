import 'package:flutter/material.dart';
import '../../models/expense_model.dart';

class ExpenseSettingsScreen extends StatefulWidget {
  final String branch;
  const ExpenseSettingsScreen({super.key, required this.branch});
  @override
  State<ExpenseSettingsScreen> createState() => _ExpenseSettingsScreenState();
}

class _ExpenseSettingsScreenState extends State<ExpenseSettingsScreen> {
  List<ExpenseCategory> _categories = [];
  List<ExpenseSubCategory> _subCategories = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final cats = await ExpenseStorage.getCategories(); final subs = await ExpenseStorage.getSubCategories();
    setState(() { _categories = cats; _subCategories = subs; _loading = false; });
  }

  Future<void> _addCategory() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Add Category'),
      content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Category Name', border: OutlineInputBorder()), textCapitalization: TextCapitalization.words),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add'))]));
    if (ok == true && ctrl.text.trim().isNotEmpty) {
      await ExpenseStorage.addCategory(ExpenseCategory(id: 'CAT-${DateTime.now().millisecondsSinceEpoch}', name: ctrl.text.trim(), dateCreated: DateTime.now()));
      _load();
    }
  }

  Future<void> _addSubCategory(ExpenseCategory cat) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: Text('Add Sub Category\n${cat.name}', style: const TextStyle(fontSize: 16)),
      content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Sub Category Name', border: OutlineInputBorder()), textCapitalization: TextCapitalization.words),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add'))]));
    if (ok == true && ctrl.text.trim().isNotEmpty) {
      await ExpenseStorage.addSubCategory(ExpenseSubCategory(id: 'SUB-${DateTime.now().millisecondsSinceEpoch}', categoryId: cat.id, name: ctrl.text.trim(), dateCreated: DateTime.now()));
      _load();
    }
  }

  Future<void> _toggleCategory(ExpenseCategory cat) async {
    await ExpenseStorage.updateCategory(cat.id, cat.copyWith(isActive: !cat.isActive));
    _load();
  }

  Future<void> _toggleSubCategory(ExpenseSubCategory sub) async {
    await ExpenseStorage.updateSubCategory(sub.id, sub.copyWith(isActive: !sub.isActive));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [const Icon(Icons.category, color: Color(0xFF6A1B9A)), const SizedBox(width: 8),
        const Text('Expense Categories', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), const Spacer(),
        IconButton(icon: const Icon(Icons.add_circle, color: Color(0xFF6A1B9A)), onPressed: _addCategory)]),
      const Divider(),
      ..._categories.map((cat) {
        final subs = _subCategories.where((s) => s.categoryId == cat.id).toList();
        return Card(margin: const EdgeInsets.only(bottom: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ExpansionTile(
            leading: Icon(cat.isActive ? Icons.check_circle : Icons.cancel, color: cat.isActive ? Colors.green : Colors.red, size: 20),
            title: Text(cat.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: cat.isActive ? Colors.black87 : Colors.grey)),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              Text('${subs.length} sub', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              PopupMenuButton<String>(icon: const Icon(Icons.more_vert, size: 18),
                onSelected: (v) { if (v == 'toggle') _toggleCategory(cat); if (v == 'add_sub') _addSubCategory(cat); },
                itemBuilder: (_) => [PopupMenuItem(value: 'toggle', child: Text(cat.isActive ? 'Deactivate' : 'Activate')), const PopupMenuItem(value: 'add_sub', child: Text('Add Sub Category'))])]),
            children: [
              if (subs.isEmpty) const ListTile(dense: true, title: Text('No sub categories', style: TextStyle(color: Colors.grey, fontSize: 12))),
              ...subs.map((sub) => ListTile(dense: true, contentPadding: const EdgeInsets.only(left: 40, right: 16),
                leading: Icon(sub.isActive ? Icons.check_circle_outline : Icons.cancel_outlined, size: 16, color: sub.isActive ? Colors.green : Colors.red),
                title: Text(sub.name, style: TextStyle(fontSize: 13, color: sub.isActive ? Colors.black87 : Colors.grey)),
                trailing: IconButton(icon: Icon(sub.isActive ? Icons.toggle_on : Icons.toggle_off, color: sub.isActive ? Colors.green : Colors.grey), onPressed: () => _toggleSubCategory(sub)))),
              Padding(padding: const EdgeInsets.only(left: 40, bottom: 8),
                child: TextButton.icon(icon: const Icon(Icons.add, size: 16), label: const Text('Add Sub Category', style: TextStyle(fontSize: 12)), onPressed: () => _addSubCategory(cat))),
            ]));
      }),
    ]));
  }
}
