// lib/screens/cashiering/payment_dialog.dart
import '../../models/settings_model.dart';
import 'package:flutter/material.dart';

class PaymentDialog extends StatefulWidget {
  final double totalAmount;
  final Function(String paymentMethod, double amountPaid, String reference, String bankName) onPaymentComplete;

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
  // v159: Reference capture for e-payment methods
  final _referenceController = TextEditingController();
  final _bankController = TextEditingController();
  String _referenceError = '';

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

  // v159: Validate reference for e-payment methods
  bool _validateReference() {
    if (_selectedMethod == 'Cash') return true;
    final ref = _referenceController.text.trim();
    if (ref.length < 4) {
      setState(() => _referenceError = 'Reference must be at least 4 characters');
      return false;
    }
    if (_selectedMethod == 'Card' && _bankController.text.trim().isEmpty) {
      setState(() => _referenceError = 'Bank name is required for Card');
      return false;
    }
    setState(() => _referenceError = '');
    return true;
  }

    void _selectMethod(String method) {
    setState(() {
      _selectedMethod = method;
      _referenceError = '';
      if (method != 'Cash') {
        _amountController.text = widget.totalAmount.toStringAsFixed(2);
      } else {
        _amountController.clear();
        // Clear e-payment fields when switching to cash
        _referenceController.clear();
        _bankController.clear();
      }
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    _bankController.dispose();
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

              // v159: Reference number for e-payment methods
              if (_selectedMethod != 'Cash') ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue.withAlpha(60)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(Icons.info_outline, size: 16, color: Colors.blue.shade700),
                        const SizedBox(width: 6),
                        Text(
                          _selectedMethod == 'Card' ? 'Card Details Required' : '$_selectedMethod Reference Required',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue.shade700),
                        ),
                      ]),
                      const SizedBox(height: 10),
                      // Bank Name field (Card only)
                      if (_selectedMethod == 'Card') ...[
                        TextField(
                          controller: _bankController,
                          decoration: InputDecoration(
                            labelText: 'Bank Name *',
                            hintText: 'e.g. BDO, BPI, Metrobank',
                            prefixIcon: const Icon(Icons.account_balance, size: 20),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            isDense: true,
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          onChanged: (_) => setState(() {}),
                          textCapitalization: TextCapitalization.characters,
                        ),
                        const SizedBox(height: 8),
                      ],
                      // Reference Number field
                      TextField(
                        controller: _referenceController,
                        decoration: InputDecoration(
                          labelText: _selectedMethod == 'Card' ? 'Approval Code / Reference *' : '$_selectedMethod Reference No. *',
                          hintText: _selectedMethod == 'Card' ? 'e.g. 123456789' : 'e.g. ABC123XYZ456',
                          prefixIcon: const Icon(Icons.receipt_long, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          isDense: true,
                          filled: true,
                          fillColor: Colors.white,
                          errorText: _referenceError.isEmpty ? null : _referenceError,
                        ),
                        onChanged: (_) => setState(() {
                          _referenceError = '';
                        }),
                        textCapitalization: TextCapitalization.characters,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _selectedMethod == 'Card'
                          ? 'Save bank + approval code from POS terminal for audit trail'
                          : 'Save $_selectedMethod reference number for audit trail',
                        style: TextStyle(fontSize: 10, color: Colors.blue.shade900, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
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
                          ((_selectedMethod == 'Cash' && _isValid) || (_selectedMethod != 'Cash' && _referenceController.text.trim().length >= 4 && (_selectedMethod != 'Card' || _bankController.text.trim().isNotEmpty)))
                              ? () {
                                final paid =
                                    double.tryParse(_amountController.text) ??
                                    widget.totalAmount;
                                // v159: Validate reference for e-payment methods
                                if (!_validateReference()) return;
                                final reference = _referenceController.text.trim();
                                final bank = _bankController.text.trim();
                                widget.onPaymentComplete(_selectedMethod, paid, reference, bank);
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
