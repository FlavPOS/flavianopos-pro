import 'package:flutter/material.dart';
import '../models/expense_model.dart';
import 'expense_pdf_generator.dart';

class ExpensePrintDialog {
  static Future<void> show(BuildContext context, Expense expense) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.all(20),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF6A1B9A).withOpacity(0.1),
              shape: BoxShape.circle),
            child: const Icon(Icons.receipt_long, color: Color(0xFF6A1B9A), size: 48)),
          const SizedBox(height: 12),
          const Text('Expense Voucher',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(expense.expenseNumber,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700,
              fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('PHP ${expense.amount.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold,
              color: Color(0xFF6A1B9A))),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: _statusColor(expense.status),
              borderRadius: BorderRadius.circular(12)),
            child: Text(expense.status.toUpperCase(),
              style: const TextStyle(fontSize: 10, color: Colors.white,
                fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 18),
          const Text('Choose an action:',
            style: TextStyle(fontSize: 13, color: Colors.black87)),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: OutlinedButton.icon(
              icon: const Icon(Icons.print, size: 18),
              label: const Text('Print'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF6A1B9A),
                side: const BorderSide(color: Color(0xFF6A1B9A)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: () async {
                try { await ExpensePdfGenerator.printVoucher(expense); }
                catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('Print failed: $e'),
                        backgroundColor: Colors.red));
                  }
                }
              })),
            const SizedBox(width: 8),
            Expanded(child: ElevatedButton.icon(
              icon: const Icon(Icons.picture_as_pdf, size: 18),
              label: const Text('Save PDF'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6A1B9A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: () async {
                try { await ExpensePdfGenerator.shareVoucher(expense); }
                catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('Save failed: $e'),
                        backgroundColor: Colors.red));
                  }
                }
              })),
          ]),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(ctx),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 10)),
              child: Text('Close', style: TextStyle(color: Colors.grey.shade700,
                fontWeight: FontWeight.w600)))),
        ]),
      ),
    );
  }

  static Color _statusColor(String status) {
    if (status == 'Approved') return Colors.green.shade700;
    if (status == 'Pending Approval') return Colors.orange.shade700;
    if (status == 'Rejected') return Colors.red.shade700;
    if (status == 'Returned') return Colors.amber.shade800;
    return Colors.grey.shade700;
  }
}
