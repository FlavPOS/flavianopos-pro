import 'package:flutter/material.dart';
import '../../models/expense_model.dart';

class ExpenseReportsScreen extends StatefulWidget {
  final String branch;
  const ExpenseReportsScreen({super.key, required this.branch});
  @override
  State<ExpenseReportsScreen> createState() => _ExpenseReportsScreenState();
}

class _ExpenseReportsScreenState extends State<ExpenseReportsScreen> {
  List<Expense> _expenses = [];
  bool _loading = true;
  String _reportType = 'Category';

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final all = await ExpenseStorage.getAll();
    setState(() { _expenses = all.where((e) => e.isApproved).toList(); _loading = false; });
  }

  Map<String, double> _groupBy(String Function(Expense) keyFn) {
    final map = <String, double>{};
    for (final e in _expenses) { final k = keyFn(e); map[k] = (map[k] ?? 0) + e.amount; }
    final sorted = map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(sorted);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final total = _expenses.fold(0.0, (s, e) => s + e.amount);
    final grouped = switch (_reportType) {
      'Category' => _groupBy((e) => e.categoryName),
      'Sub Category' => _groupBy((e) => '${e.categoryName} > ${e.subCategoryName}'),
      'Payment Method' => _groupBy((e) => e.paymentMethod),
      'Branch' => _groupBy((e) => e.branch),
      'Prepared By' => _groupBy((e) => e.preparedBy),
      _ => _groupBy((e) => e.categoryName),
    };
    return Column(children: [
      Container(color: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
          for (final r in ['Category', 'Sub Category', 'Payment Method', 'Branch', 'Prepared By'])
            Padding(padding: const EdgeInsets.only(right: 6), child: ChoiceChip(label: Text(r, style: TextStyle(fontSize: 10, color: _reportType == r ? Colors.white : Colors.grey[700])),
              selected: _reportType == r, selectedColor: const Color(0xFF6A1B9A), onSelected: (_) => setState(() => _reportType = r)))]))),
      Container(padding: const EdgeInsets.all(16), margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF6A1B9A), Color(0xFF8E24AA)]), borderRadius: BorderRadius.circular(12)),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Total Approved', style: TextStyle(color: Colors.white70, fontSize: 11)),
            Text(total.toStringAsFixed(2), style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold))]),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [const Text('Count', style: TextStyle(color: Colors.white70, fontSize: 11)),
            Text('${_expenses.length}', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold))])])),
      Expanded(child: grouped.isEmpty
        ? Center(child: Text('No approved expenses', style: TextStyle(color: Colors.grey[500])))
        : ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 12), itemCount: grouped.length,
            itemBuilder: (_, i) { final entry = grouped.entries.elementAt(i); final pct = total > 0 ? (entry.value / total * 100) : 0.0;
              return Card(margin: const EdgeInsets.only(bottom: 6), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [Expanded(child: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                    Text(entry.value.toStringAsFixed(2), style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purple[800]))]),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(value: pct / 100, backgroundColor: Colors.grey[200], valueColor: AlwaysStoppedAnimation(Colors.purple[400]!), minHeight: 6),
                  const SizedBox(height: 4), Text('${pct.toStringAsFixed(1)}%', style: TextStyle(fontSize: 10, color: Colors.grey[500]))])));
            })),
    ]);
  }
}
