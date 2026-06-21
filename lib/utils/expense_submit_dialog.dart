import 'package:flutter/material.dart';
import '../models/expense_model.dart';
import 'expense_pdf_generator.dart';

class ExpenseSubmitDialog {
  static Future<void> show(BuildContext context, Expense expense) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.all(20),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle),
            child: const Icon(Icons.check_circle, color: Colors.green, size: 56)),
          const SizedBox(height: 12),
          const Text('Submitted for Approval!',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(expense.expenseNumber,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700,
              fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('PHP ${expense.amount.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
              color: Color(0xFF6A1B9A))),
          const SizedBox(height: 16),
          const Text('Would you like to print or save the voucher for filing?',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.black87)),
          const SizedBox(height: 20),
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
                      SnackBar(content: Text('Print failed: $e'), backgroundColor: Colors.red));
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
                      SnackBar(content: Text('Save failed: $e'), backgroundColor: Colors.red));
                  }
                }
              })),
          ]),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(ctx),
              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
              child: Text('Done', style: TextStyle(color: Colors.grey.shade700,
                fontWeight: FontWeight.w600)))),
        ]),
      ),
    );
  }
}
