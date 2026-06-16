import 'package:flutter/material.dart';
import 'dart:convert';
import '../../models/expense_model.dart';
import 'encode_expense_screen.dart';

class ExpenseApprovalScreen extends StatefulWidget {
  final String currentUser, branch;
  final VoidCallback onChanged;
  const ExpenseApprovalScreen({super.key, required this.currentUser, required this.branch, required this.onChanged});
  @override
  State<ExpenseApprovalScreen> createState() => _ExpenseApprovalScreenState();
}

class _ExpenseApprovalScreenState extends State<ExpenseApprovalScreen> {
  List<Expense> _expenses = [];
  String _filter = 'For Approval';
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final all = await ExpenseStorage.getAll();
    setState(() { _expenses = all.where((e) => _filter == 'All' ? !e.isDraft : e.status == _filter).toList(); _loading = false; });
  }

  Future<void> _approve(Expense e) async {
    final remarksCtrl = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Approve Expense'), content: Column(mainAxisSize: MainAxisSize.min, children: [
      Text('${e.expenseNumber}\n${e.categoryName} - ${e.subCategoryName}\nAmount: ${e.amount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13)),
      const SizedBox(height: 12), TextField(controller: remarksCtrl, decoration: const InputDecoration(labelText: 'Approval Remarks (Optional)', border: OutlineInputBorder()), maxLines: 2)]),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.green), child: const Text('Approve', style: TextStyle(color: Colors.white)))]));
    if (ok == true) {
      final now = DateTime.now();
      final updated = e.copyWith(status: 'Approved', approvedBy: widget.currentUser, approvedDate: now.toIso8601String(), approvalRemarks: remarksCtrl.text.trim(), updatedBy: widget.currentUser, updatedDate: now.toIso8601String());
      await ExpenseStorage.updateExpense(e.id, updated);
      await ExpenseStorage.addAudit(ExpenseAudit(id: 'AUD-${now.millisecondsSinceEpoch}', expenseId: e.id, expenseNumber: e.expenseNumber, action: 'Approved', newValue: 'Approved by ${widget.currentUser}', performedBy: widget.currentUser, performedDate: now.toIso8601String(), branch: widget.branch));
      widget.onChanged(); _load(); _snack('Expense approved!', Colors.green);
    }
  }

  Future<void> _reject(Expense e) async {
    final reasonCtrl = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Reject Expense'), content: Column(mainAxisSize: MainAxisSize.min, children: [
      Text('${e.expenseNumber}\nAmount: ${e.amount.toStringAsFixed(2)}'),
      const SizedBox(height: 12), TextField(controller: reasonCtrl, decoration: const InputDecoration(labelText: 'Rejection Reason *', border: OutlineInputBorder()), maxLines: 2)]),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        ElevatedButton(onPressed: () { if (reasonCtrl.text.trim().isEmpty) { ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Reason required'))); return; } Navigator.pop(ctx, true); },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('Reject', style: TextStyle(color: Colors.white)))]));
    if (ok == true) {
      final now = DateTime.now();
      final updated = e.copyWith(status: 'Rejected', rejectedBy: widget.currentUser, rejectedDate: now.toIso8601String(), rejectionReason: reasonCtrl.text.trim(), updatedBy: widget.currentUser, updatedDate: now.toIso8601String());
      await ExpenseStorage.updateExpense(e.id, updated);
      await ExpenseStorage.addAudit(ExpenseAudit(id: 'AUD-${now.millisecondsSinceEpoch}', expenseId: e.id, expenseNumber: e.expenseNumber, action: 'Rejected', newValue: reasonCtrl.text.trim(), performedBy: widget.currentUser, performedDate: now.toIso8601String(), branch: widget.branch));
      widget.onChanged(); _load(); _snack('Expense rejected', Colors.red);
    }
  }

  Future<void> _returnExp(Expense e) async {
    final reasonCtrl = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Return for Correction'), content: Column(mainAxisSize: MainAxisSize.min, children: [
      Text('${e.expenseNumber}\nAmount: ${e.amount.toStringAsFixed(2)}'),
      const SizedBox(height: 12), TextField(controller: reasonCtrl, decoration: const InputDecoration(labelText: 'Return Reason *', border: OutlineInputBorder()), maxLines: 2)]),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        ElevatedButton(onPressed: () { if (reasonCtrl.text.trim().isEmpty) { ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Reason required'))); return; } Navigator.pop(ctx, true); },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue), child: const Text('Return', style: TextStyle(color: Colors.white)))]));
    if (ok == true) {
      final now = DateTime.now();
      final updated = e.copyWith(status: 'Returned', returnedBy: widget.currentUser, returnedDate: now.toIso8601String(), returnReason: reasonCtrl.text.trim(), updatedBy: widget.currentUser, updatedDate: now.toIso8601String());
      await ExpenseStorage.updateExpense(e.id, updated);
      await ExpenseStorage.addAudit(ExpenseAudit(id: 'AUD-${now.millisecondsSinceEpoch}', expenseId: e.id, expenseNumber: e.expenseNumber, action: 'Returned', newValue: reasonCtrl.text.trim(), performedBy: widget.currentUser, performedDate: now.toIso8601String(), branch: widget.branch));
      widget.onChanged(); _load(); _snack('Expense returned', Colors.blue);
    }
  }

  void _showDetail(Expense e) {
    showModalBottomSheet(context: context, isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(initialChildSize: 0.75, minChildSize: 0.4, maxChildSize: 0.95, expand: false,
        builder: (_, sc) => Padding(padding: const EdgeInsets.all(20), child: ListView(controller: sc, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 14), Center(child: Text('Expense Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.purple[800]))),
          const Divider(height: 24),
          _dRow('Expense #', e.expenseNumber), _dRow('Date', e.expenseDate), _dRow('Category', '${e.categoryName} > ${e.subCategoryName}'),
          _dRow('Amount', e.amount.toStringAsFixed(2)), _dRow('Payment', e.paymentMethod), _dRow('Type', e.expenseType),
          _dRow('Priority', e.priority), _dRow('Branch', e.branch), _dRow('Prepared By', e.preparedBy),
          _dRow('Status', e.status),
          if (e.payeeSupplier.isNotEmpty) _dRow('Payee', e.payeeSupplier),
          if (e.referenceNumber.isNotEmpty) _dRow('Reference #', e.referenceNumber),
          if (e.remarks.isNotEmpty) _dRow('Remarks', e.remarks),
          if (e.approvedBy.isNotEmpty) ...[_dRow('Approved By', e.approvedBy), _dRow('Approved Date', e.approvedDate)],
          if (e.rejectedBy.isNotEmpty) ...[_dRow('Rejected By', e.rejectedBy), _dRow('Rejection Reason', e.rejectionReason)],
          if (e.returnedBy.isNotEmpty) ...[_dRow('Returned By', e.returnedBy), _dRow('Return Reason', e.returnReason)],
          if (e.attachmentPath.isNotEmpty) ...[const SizedBox(height: 12), const Text('Attachment:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8), ClipRRect(borderRadius: BorderRadius.circular(8), child: _buildAttachment(e))],
          const SizedBox(height: 16),
          if (e.isForApproval) ...[
            Row(children: [
              Expanded(child: ElevatedButton.icon(onPressed: () { Navigator.pop(context); _approve(e); }, icon: const Icon(Icons.check), label: const Text('Approve'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))))),
              const SizedBox(width: 8),
              Expanded(child: ElevatedButton.icon(onPressed: () { Navigator.pop(context); _reject(e); }, icon: const Icon(Icons.close), label: const Text('Reject'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))))),
            ]),
            const SizedBox(height: 8),
            SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: () { Navigator.pop(context); _returnExp(e); }, icon: const Icon(Icons.undo), label: const Text('Return for Correction'),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))))),
          ],
        ]))));
  }

  Widget _buildAttachment(Expense e) { try { final bytes = base64Decode(e.attachmentPath); return Image.memory(bytes, height: 150, width: double.infinity, fit: BoxFit.cover); } catch (_) { return Text('File: ${e.attachmentFileName}'); } }
  Widget _dRow(String l, String v) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 110, child: Text(l, style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[700], fontSize: 13))), Expanded(child: Text(v, style: const TextStyle(fontSize: 13)))]));
  void _snack(String m, Color c) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: c, behavior: SnackBarBehavior.floating));

  Color _statusColor(String s) => switch (s) { 'For Approval' => Colors.orange, 'Approved' => Colors.green, 'Rejected' => Colors.red, 'Returned' => Colors.blue, 'Cancelled' => Colors.grey, _ => Colors.grey };

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(color: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
          for (final f in ['For Approval', 'Returned', 'Approved', 'Rejected', 'All'])
            Padding(padding: const EdgeInsets.only(right: 6), child: ChoiceChip(label: Text(f, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _filter == f ? Colors.white : Colors.grey[700])),
              selected: _filter == f, selectedColor: const Color(0xFF6A1B9A), onSelected: (_) { setState(() => _filter = f); _load(); })),
        ]))),
      Expanded(child: _loading ? const Center(child: CircularProgressIndicator())
        : _expenses.isEmpty ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.inbox_rounded, size: 48, color: Colors.grey[300]), const SizedBox(height: 8), Text('No $_filter expenses', style: TextStyle(color: Colors.grey[500]))]))
        : RefreshIndicator(onRefresh: _load, child: ListView.builder(padding: const EdgeInsets.all(12), itemCount: _expenses.length,
            itemBuilder: (_, i) { final e = _expenses[i]; final sc = _statusColor(e.status);
              return Card(margin: const EdgeInsets.only(bottom: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: InkWell(borderRadius: BorderRadius.circular(12), onTap: () => _showDetail(e),
                  child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [Text(e.expenseNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)), const Spacer(),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: sc.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                        child: Text(e.status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: sc)))]),
                    const SizedBox(height: 6), Text('${e.categoryName} > ${e.subCategoryName}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    const SizedBox(height: 4), Row(children: [Text(e.amount.toStringAsFixed(2), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF6A1B9A))),
                      const Spacer(), Text(e.expenseDate, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                      const SizedBox(width: 8), Text(e.preparedBy, style: TextStyle(fontSize: 11, color: Colors.grey[500]))]),
                    if (e.priority == 'Urgent') Padding(padding: const EdgeInsets.only(top: 4), child: Row(children: [const Icon(Icons.priority_high, size: 14, color: Colors.red), Text(' URGENT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red[700]))])),
                  ])))); }))),
    ]);
  }
}
