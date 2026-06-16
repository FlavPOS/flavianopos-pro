// lib/screens/cashiering/payment_dialog.dart
import '../../models/settings_model.dart';
import 'package:flutter/material.dart';

class PaymentDialog extends StatefulWidget {
  final double totalAmount;
  final Function(String paymentMethod, double amountPaid) onPaymentComplete;

  const PaymentDialog({
    super.key,
    required this.totalAmount,
    required this.onPaymentComplete,
  });

  @override
  State<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<PaymentDialog> {
  String _selectedMethod = AppSettings.defaultPayment;
  final _amountController = TextEditingController();
  double _change = 0;
  bool _isValid = false;

  final List<Map<String, dynamic>> _paymentMethods = [
    {'name': 'Cash', 'icon': Icons.money, 'color': Colors.green},
    {'name': 'GCash', 'icon': Icons.phone_android, 'color': Colors.blue},
    {'name': 'Maya', 'icon': Icons.phone_iphone, 'color': Colors.green},
    {'name': 'Card', 'icon': Icons.credit_card, 'color': Colors.purple},
  ];

  final List<double> _quickAmounts = [20, 50, 100, 200, 500, 1000];

  @override
  void initState() {
    super.initState();
    _amountController.addListener(_calculateChange);
    // For non-cash, auto-fill exact amount
    if (_selectedMethod != 'Cash') {
      _amountController.text = widget.totalAmount.toStringAsFixed(2);
    }
  }

  void _calculateChange() {
    final paid = double.tryParse(_amountController.text) ?? 0;
    setState(() {
      _change = paid - widget.totalAmount;
      _isValid = paid >= widget.totalAmount;
    });
  }

  void _selectMethod(String method) {
    setState(() {
      _selectedMethod = method;
      if (method != 'Cash') {
        _amountController.text = widget.totalAmount.toStringAsFixed(2);
      } else {
        _amountController.clear();
      }
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              const Icon(Icons.payment, size: 48, color: Color(0xFF1565C0)),
              const SizedBox(height: 8),
              const Text(
                'Payment',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),

              // Total Amount
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1565C0).withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Total Amount',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    Text(
                      widget.totalAmount.toStringAsFixed(2),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1565C0),
                      ),
                    ),
                  ],
                ),
              ),

              // Payment Method Selection
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Payment Method',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children:
                    _paymentMethods.map((method) {
                      final isSelected = _selectedMethod == method['name'];
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => _selectMethod(method['name']),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color:
                                  isSelected
                                      ? (method['color'] as Color).withAlpha(25)
                                      : Colors.grey[100],
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color:
                                    isSelected
                                        ? method['color'] as Color
                                        : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  method['icon'] as IconData,
                                  color:
                                      isSelected
                                          ? method['color'] as Color
                                          : Colors.grey,
                                  size: 24,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  method['name'] as String,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight:
                                        isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                    color:
                                        isSelected
                                            ? method['color'] as Color
                                            : Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
              ),
              const SizedBox(height: 16),

              // Amount Paid Input
              if (_selectedMethod == 'Cash') ...[
                TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    labelText: 'Amount Paid',
                    prefixText: ' ',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Quick Amount Buttons
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      _quickAmounts.map((amount) {
                        return GestureDetector(
                          onTap: () {
                            _amountController.text = amount.toStringAsFixed(0);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              amount.toStringAsFixed(0),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                ),
                const SizedBox(height: 12),

                // Exact Amount Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      _amountController.text = widget.totalAmount
                          .toStringAsFixed(2);
                    },
                    child: const Text('Exact Amount'),
                  ),
                ),
                const SizedBox(height: 12),

                // Change Display
                if (_change >= 0 && _amountController.text.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withAlpha(20),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.green.withAlpha(80)),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Change',
                          style: TextStyle(color: Colors.green),
                        ),
                        Text(
                          _change.toStringAsFixed(2),
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
              const SizedBox(height: 20),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed:
                          (_selectedMethod != 'Cash' || _isValid)
                              ? () {
                                final paid =
                                    double.tryParse(_amountController.text) ??
                                    widget.totalAmount;
                                widget.onPaymentComplete(_selectedMethod, paid);
                              }
                              : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1565C0),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Complete Payment',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
