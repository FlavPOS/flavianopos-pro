// lib/screens/expenses/expense_settings_screen.dart
// FlavianoPOS - PRO: Expense Settings (Mobile + Tablet + Web)
import 'package:flutter/material.dart';
import '../../models/expense_model.dart';
import '../../utils/responsive.dart';

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
  String _search = '';
  bool _showInactive = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final cats = await ExpenseStorage.getCategories();
    final subs = await ExpenseStorage.getSubCategories();
    setState(() { _categories = cats; _subCategories = subs; _loading = false; });
  }

  List<ExpenseCategory> get _filteredCategories {
    var list = List<ExpenseCategory>.from(_categories);
    if (!_showInactive) list = list.where((c) => c.isActive).toList();
    if (_search.isNotEmpty) {
      final s = _search.toLowerCase();
      list = list.where((c) {
        if (c.name.toLowerCase().contains(s)) return true;
        return _subCategories.any((sub) => sub.categoryId == c.id && sub.name.toLowerCase().contains(s));
      }).toList();
    }
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  Future<void> _addCategory() async {
    final ctrl = TextEditingController();
    final ok = await _showFormSheet(title: 'Add Category', icon: Icons.category,
      iconColor: const Color(0xFF7B1FA2), controller: ctrl, hint: 'e.g. Office Supplies');
    if (ok && ctrl.text.trim().isNotEmpty) {
      await ExpenseStorage.addCategory(ExpenseCategory(
        id: 'CAT-${DateTime.now().millisecondsSinceEpoch}',
        name: ctrl.text.trim(), dateCreated: DateTime.now()));
      _load(); _snack('Category added', Colors.green);
    }
  }

  Future<void> _editCategory(ExpenseCategory cat) async {
    final ctrl = TextEditingController(text: cat.name);
    final ok = await _showFormSheet(title: 'Edit Category', icon: Icons.edit,
      iconColor: Colors.blue.shade700, controller: ctrl, hint: 'Category name');
    if (ok && ctrl.text.trim().isNotEmpty) {
      await ExpenseStorage.updateCategory(cat.id, cat.copyWith(name: ctrl.text.trim()));
      _load(); _snack('Category updated', Colors.green);
    }
  }

  Future<void> _addSubCategory(ExpenseCategory cat) async {
    final ctrl = TextEditingController();
    final ok = await _showFormSheet(title: 'Add Sub-Category', subtitle: 'Under: ${cat.name}',
      icon: Icons.subdirectory_arrow_right, iconColor: Colors.orange.shade700, controller: ctrl, hint: 'e.g. Bond Paper');
    if (ok && ctrl.text.trim().isNotEmpty) {
      await ExpenseStorage.addSubCategory(ExpenseSubCategory(
        id: 'SUB-${DateTime.now().millisecondsSinceEpoch}',
        categoryId: cat.id, name: ctrl.text.trim(), dateCreated: DateTime.now()));
      _load(); _snack('Sub-category added', Colors.green);
    }
  }

  Future<void> _editSubCategory(ExpenseSubCategory sub) async {
    final ctrl = TextEditingController(text: sub.name);
    final ok = await _showFormSheet(title: 'Edit Sub-Category', icon: Icons.edit,
      iconColor: Colors.blue.shade700, controller: ctrl, hint: 'Sub-category name');
    if (ok && ctrl.text.trim().isNotEmpty) {
      await ExpenseStorage.updateSubCategory(sub.id, sub.copyWith(name: ctrl.text.trim()));
      _load(); _snack('Sub-category updated', Colors.green);
    }
  }

  Future<void> _toggleCategory(ExpenseCategory cat) async {
    await ExpenseStorage.updateCategory(cat.id, cat.copyWith(isActive: !cat.isActive)); _load();
  }

  Future<void> _toggleSubCategory(ExpenseSubCategory sub) async {
    await ExpenseStorage.updateSubCategory(sub.id, sub.copyWith(isActive: !sub.isActive)); _load();
  }

  void _snack(String m, Color c) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(m, style: const TextStyle(fontWeight: FontWeight.w600)),
    backgroundColor: c, behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));

  Future<bool> _showFormSheet({
    required String title, String? subtitle,
    required IconData icon, required Color iconColor,
    required TextEditingController controller, required String hint,
  }) async {
    final isPhone = Responsive.isPhone(context);
    final formWidget = Padding(
      padding: EdgeInsets.fromLTRB(
        Responsive.pad(context), Responsive.pad(context),
        Responsive.pad(context),
        MediaQuery.of(context).viewInsets.bottom + Responsive.pad(context)),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (isPhone) Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
        Row(children: [
          Container(padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: iconColor)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            if (subtitle != null) Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ])),
        ]),
        const SizedBox(height: 20),
        TextField(controller: controller, autofocus: true, textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(labelText: 'Name', hintText: hint,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: iconColor, width: 2))),
          onSubmitted: (_) => Navigator.pop(context, true)),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context, false),
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Cancel'))),
          const SizedBox(width: 10),
          Expanded(child: ElevatedButton(onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: iconColor, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)))),
        ]),
      ]));
    if (isPhone) {
      return (await showModalBottomSheet<bool>(context: context, isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (_) => formWidget)) ?? false;
    } else {
      return (await showDialog<bool>(context: context,
        builder: (_) => Dialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 500), child: formWidget)))) ?? false;
    }
  }

  Future<void> _restoreDefaults() async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(children: [Icon(Icons.restore, color: Colors.orange.shade700),
        const SizedBox(width: 8), const Text('Restore Defaults')]),
      content: const Text('This will add default categories and sub-categories. Existing items will NOT be removed.\n\nContinue?'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade700, foregroundColor: Colors.white),
          onPressed: () => Navigator.pop(ctx, true), child: const Text('Restore'))]));
    if (ok != true) return;
    int catCount = 0, subCount = 0;
    for (final c in ExpenseStorage.getDefaultCategories()) {
      if (!_categories.any((e) => e.name.toLowerCase() == c.name.toLowerCase())) {
        await ExpenseStorage.addCategory(c); catCount++;
      }
    }
    for (final s in ExpenseStorage.getDefaultSubCategories()) {
      if (!_subCategories.any((e) => e.name.toLowerCase() == s.name.toLowerCase() && e.categoryId == s.categoryId)) {
        await ExpenseStorage.addSubCategory(s); subCount++;
      }
    }
    _load(); _snack('Added $catCount cats, $subCount subs', Colors.green);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F3F8),
      appBar: AppBar(elevation: 0, backgroundColor: const Color(0xFF7B1FA2), foregroundColor: Colors.white,
        title: Text('Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: Responsive.titleSz(context))),
        actions: [PopupMenuButton<String>(icon: const Icon(Icons.more_vert),
          onSelected: (v) {
            if (v == 'toggle_inactive') setState(() => _showInactive = !_showInactive);
            if (v == 'restore_defaults') _restoreDefaults();
            if (v == 'refresh') _load();
          },
          itemBuilder: (_) => [
            PopupMenuItem(value: 'toggle_inactive', child: Row(children: [
              Icon(_showInactive ? Icons.visibility_off : Icons.visibility, size: 18),
              const SizedBox(width: 8), Text(_showInactive ? 'Hide Inactive' : 'Show Inactive')])),
            const PopupMenuItem(value: 'restore_defaults', child: Row(children: [
              Icon(Icons.restore, size: 18), SizedBox(width: 8), Text('Restore Defaults')])),
            const PopupMenuItem(value: 'refresh', child: Row(children: [
              Icon(Icons.refresh, size: 18), SizedBox(width: 8), Text('Refresh')])),
          ])]),
      body: _loading ? const Center(child: CircularProgressIndicator(color: Color(0xFF7B1FA2)))
        : Responsive.centered(context: context, child: Column(children: [
            _buildSearchBar(context),
            _buildStatsBar(context),
            Expanded(child: _buildList(context)),
          ])),
      floatingActionButton: FloatingActionButton.extended(onPressed: _addCategory,
        backgroundColor: const Color(0xFF7B1FA2), foregroundColor: Colors.white,
        icon: const Icon(Icons.add), label: const Text('Category', style: TextStyle(fontWeight: FontWeight.bold))),
    );
  }

  Widget _buildSearchBar(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(Responsive.pad(context), 12, Responsive.pad(context), 8),
    child: TextField(onChanged: (v) => setState(() => _search = v),
      decoration: InputDecoration(hintText: 'Search categories or sub-categories...',
        prefixIcon: const Icon(Icons.search, color: Color(0xFF7B1FA2)),
        filled: true, fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF7B1FA2), width: 2)))));

  Widget _buildStatsBar(BuildContext context) {
    final active = _categories.where((c) => c.isActive).length;
    final activeSubs = _subCategories.where((s) => s.isActive).length;
    return Padding(padding: EdgeInsets.fromLTRB(Responsive.pad(context), 0, Responsive.pad(context), 8),
      child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: const Color(0xFF7B1FA2).withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          Expanded(child: _statTile(Icons.category, 'Categories', '$active / ${_categories.length}', const Color(0xFF7B1FA2))),
          Container(width: 1, height: 28, color: Colors.grey.shade300),
          Expanded(child: _statTile(Icons.subdirectory_arrow_right, 'Sub-Categories', '$activeSubs / ${_subCategories.length}', Colors.orange.shade700)),
        ])));
  }

  Widget _statTile(IconData icon, String label, String value, Color color) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: Row(children: [Icon(icon, color: color, size: 18), const SizedBox(width: 8),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade700)),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
      ]))]));

  Widget _buildList(BuildContext context) {
    final cats = _filteredCategories;
    if (cats.isEmpty) return _buildEmptyState(context);
    return RefreshIndicator(color: const Color(0xFF7B1FA2), onRefresh: _load,
      child: ListView.separated(physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(Responsive.pad(context), 0, Responsive.pad(context), 90),
        itemCount: cats.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _buildCategoryCard(context, cats[i])));
  }

  Widget _buildEmptyState(BuildContext context) => Center(
    child: Padding(padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
          child: Icon(Icons.category_outlined, size: 56, color: Colors.grey.shade400)),
        const SizedBox(height: 16),
        Text(_search.isEmpty ? 'No categories yet' : 'No matches found',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
        const SizedBox(height: 6),
        Text(_search.isEmpty ? 'Tap + to add or restore defaults from menu' : 'Try a different search',
          textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
      ])));

  Widget _buildCategoryCard(BuildContext context, ExpenseCategory cat) {
    final subs = _subCategories.where((s) => s.categoryId == cat.id).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final activeSubs = subs.where((s) => s.isActive).length;
    return Material(color: Colors.white, borderRadius: BorderRadius.circular(Responsive.cardR(context)), elevation: 1,
      child: Theme(data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.only(bottom: 8),
          leading: Container(padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: (cat.isActive ? const Color(0xFF7B1FA2) : Colors.grey).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.folder, color: cat.isActive ? const Color(0xFF7B1FA2) : Colors.grey, size: 22)),
          title: Text(cat.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14,
            color: cat.isActive ? const Color(0xFF424242) : Colors.grey,
            decoration: cat.isActive ? null : TextDecoration.lineThrough)),
          subtitle: Row(children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: cat.isActive ? Colors.green.shade50 : Colors.red.shade50,
                borderRadius: BorderRadius.circular(6)),
              child: Text(cat.isActive ? 'Active' : 'Inactive',
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold,
                  color: cat.isActive ? Colors.green.shade700 : Colors.red.shade700))),
            const SizedBox(width: 6),
            Text('$activeSubs / ${subs.length} subs', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          ]),
          trailing: PopupMenuButton<String>(icon: const Icon(Icons.more_vert, size: 18),
            onSelected: (v) {
              if (v == 'edit') _editCategory(cat);
              if (v == 'toggle') _toggleCategory(cat);
              if (v == 'add_sub') _addSubCategory(cat);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Row(children: [
                Icon(Icons.edit, size: 16), SizedBox(width: 8), Text('Edit Name')])),
              PopupMenuItem(value: 'toggle', child: Row(children: [
                Icon(cat.isActive ? Icons.toggle_off : Icons.toggle_on, size: 16),
                const SizedBox(width: 8), Text(cat.isActive ? 'Deactivate' : 'Activate')])),
              const PopupMenuItem(value: 'add_sub', child: Row(children: [
                Icon(Icons.add, size: 16), SizedBox(width: 8), Text('Add Sub-Category')])),
            ]),
          children: [
            if (subs.isEmpty) Padding(padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 8),
              child: Text('No sub-categories yet',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontStyle: FontStyle.italic))),
            ...subs.map((sub) => Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(margin: const EdgeInsets.only(left: 32, bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200)),
                child: Row(children: [
                  Icon(Icons.subdirectory_arrow_right, size: 16,
                    color: sub.isActive ? Colors.orange.shade700 : Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(child: Text(sub.name, style: TextStyle(fontSize: 12,
                    color: sub.isActive ? const Color(0xFF424242) : Colors.grey,
                    decoration: sub.isActive ? null : TextDecoration.lineThrough))),
                  IconButton(icon: const Icon(Icons.edit_outlined, size: 16),
                    padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                    tooltip: 'Edit', onPressed: () => _editSubCategory(sub)),
                  const SizedBox(width: 12),
                  GestureDetector(onTap: () => _toggleSubCategory(sub),
                    child: Icon(sub.isActive ? Icons.toggle_on : Icons.toggle_off,
                      color: sub.isActive ? Colors.green.shade600 : Colors.grey, size: 26)),
                ])))),
            Padding(padding: const EdgeInsets.only(left: 60, right: 16, top: 4),
              child: SizedBox(width: double.infinity,
                child: OutlinedButton.icon(onPressed: () => _addSubCategory(cat),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Sub-Category', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.orange.shade700,
                    side: BorderSide(color: Colors.orange.shade300),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)))))),
          ])));
  }
}
