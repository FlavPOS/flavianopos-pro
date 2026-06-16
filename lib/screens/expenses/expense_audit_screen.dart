import 'package:flutter/material.dart';
import '../../models/expense_model.dart';

class ExpenseAuditScreen extends StatefulWidget {
  final String branch;
  const ExpenseAuditScreen({super.key, required this.branch});
  @override
  State<ExpenseAuditScreen> createState() => _ExpenseAuditScreenState();
}

class _ExpenseAuditScreenState extends State<ExpenseAuditScreen> {
  List<ExpenseAudit> _audits = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async { final a = await ExpenseStorage.getAuditTrail(); setState(() { _audits = a; _loading = false; }); }

  Color _actionColor(String a) => switch (a) { 'Approved' => Colors.green, 'Rejected' => Colors.red, 'Returned' => Colors.blue, 'Cancelled' => Colors.grey, 'Submitted for Approval' => Colors.orange, 'Saved as Draft' => Colors.blueGrey, 'Edited' => Colors.teal, _ => Colors.purple };
  IconData _actionIcon(String a) => switch (a) { 'Approved' => Icons.check_circle, 'Rejected' => Icons.cancel, 'Returned' => Icons.undo, 'Cancelled' => Icons.block, 'Submitted for Approval' => Icons.send, 'Saved as Draft' => Icons.save, 'Edited' => Icons.edit, _ => Icons.info };

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_audits.isEmpty) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.policy, size: 48, color: Colors.grey[300]), const SizedBox(height: 8), Text('No audit trail yet', style: TextStyle(color: Colors.grey[500]))]));
    return RefreshIndicator(onRefresh: _load, child: ListView.builder(padding: const EdgeInsets.all(12), itemCount: _audits.length,
      itemBuilder: (_, i) { final a = _audits[i]; final c = _actionColor(a.action);
        return Card(margin: const EdgeInsets.only(bottom: 6), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            leading: CircleAvatar(radius: 16, backgroundColor: c.withOpacity(0.1), child: Icon(_actionIcon(a.action), size: 16, color: c)),
            title: Row(children: [Text(a.expenseNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(width: 8), Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1), decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                child: Text(a.action, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: c)))]),
            subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (a.newValue.isNotEmpty) Text(a.newValue, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
              Row(children: [Text(a.performedBy, style: TextStyle(fontSize: 10, color: Colors.grey[500])), const Spacer(),
                Text(a.performedDate.length > 16 ? a.performedDate.substring(0, 16).replaceAll('T', ' ') : a.performedDate, style: TextStyle(fontSize: 10, color: Colors.grey[400]))])])));
      }));
  }
}
