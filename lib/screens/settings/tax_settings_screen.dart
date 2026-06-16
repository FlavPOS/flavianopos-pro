// lib/screens/settings/tax_settings_screen.dart
import 'package:flutter/material.dart';

class TaxSettingsScreen extends StatefulWidget {
  const TaxSettingsScreen({super.key});

  @override
  State<TaxSettingsScreen> createState() => _TaxSettingsScreenState();
}

class _TaxSettingsScreenState extends State<TaxSettingsScreen> {
  bool _vatEnabled = true;
  double _vatRate = 12.0;
  bool _vatInclusive = true;
  bool _serviceChargeEnabled = false;
  double _serviceChargeRate = 10.0;
  bool _seniorDiscount = true;
  double _seniorDiscountRate = 20.0;
  bool _pwdDiscount = true;
  final double _pwdDiscountRate = 20.0;
  bool _showTaxBreakdown = true;

  void _saveSettings() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Tax settings saved!'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.green,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Tax Settings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.orange[700],
        foregroundColor: Colors.white,
        actions: [
          TextButton.icon(
            onPressed: _saveSettings,
            icon: const Icon(Icons.save, color: Colors.white),
            label: const Text(
              'Save',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeader('Value Added Tax (VAT)', Icons.calculate),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text(
                    'Enable VAT',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    '${_vatRate.toStringAsFixed(1)}% tax rate',
                    style: const TextStyle(fontSize: 12),
                  ),
                  value: _vatEnabled,
                  onChanged: (v) => setState(() => _vatEnabled = v),
                ),
                if (_vatEnabled) ...[
                  const Divider(height: 0),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        const Text(
                          'VAT Rate: ',
                          style: TextStyle(fontSize: 13),
                        ),
                        Expanded(
                          child: Slider(
                            value: _vatRate,
                            min: 0,
                            max: 25,
                            divisions: 50,
                            label: '${_vatRate.toStringAsFixed(1)}%',
                            activeColor: Colors.orange,
                            onChanged: (v) => setState(() => _vatRate = v),
                          ),
                        ),
                        Text(
                          '${_vatRate.toStringAsFixed(1)}%',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 0),
                  SwitchListTile(
                    title: const Text(
                      'VAT Inclusive Pricing',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      _vatInclusive
                          ? 'Prices already include VAT'
                          : 'VAT added on top of price',
                      style: const TextStyle(fontSize: 12),
                    ),
                    value: _vatInclusive,
                    onChanged: (v) => setState(() => _vatInclusive = v),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          _buildHeader('Service Charge', Icons.room_service),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text(
                    'Enable Service Charge',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    '${_serviceChargeRate.toStringAsFixed(1)}%',
                    style: const TextStyle(fontSize: 12),
                  ),
                  value: _serviceChargeEnabled,
                  onChanged: (v) => setState(() => _serviceChargeEnabled = v),
                ),
                if (_serviceChargeEnabled) ...[
                  const Divider(height: 0),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        const Text('Rate: ', style: TextStyle(fontSize: 13)),
                        Expanded(
                          child: Slider(
                            value: _serviceChargeRate,
                            min: 0,
                            max: 20,
                            divisions: 40,
                            label: '${_serviceChargeRate.toStringAsFixed(1)}%',
                            activeColor: Colors.orange,
                            onChanged:
                                (v) => setState(() => _serviceChargeRate = v),
                          ),
                        ),
                        Text(
                          '${_serviceChargeRate.toStringAsFixed(1)}%',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          _buildHeader('Special Discounts', Icons.discount),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text(
                    'Senior Citizen Discount',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    '${_seniorDiscountRate.toStringAsFixed(0)}% off + VAT exempt',
                    style: const TextStyle(fontSize: 12),
                  ),
                  value: _seniorDiscount,
                  onChanged: (v) => setState(() => _seniorDiscount = v),
                ),
                if (_seniorDiscount) ...[
                  const Divider(height: 0),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        const Text('Rate: ', style: TextStyle(fontSize: 13)),
                        Expanded(
                          child: Slider(
                            value: _seniorDiscountRate,
                            min: 5,
                            max: 30,
                            divisions: 25,
                            label: '${_seniorDiscountRate.toStringAsFixed(0)}%',
                            activeColor: Colors.orange,
                            onChanged:
                                (v) => setState(() => _seniorDiscountRate = v),
                          ),
                        ),
                        Text(
                          '${_seniorDiscountRate.toStringAsFixed(0)}%',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
                const Divider(height: 0),
                SwitchListTile(
                  title: const Text(
                    'PWD Discount',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    '${_pwdDiscountRate.toStringAsFixed(0)}% off + VAT exempt',
                    style: const TextStyle(fontSize: 12),
                  ),
                  value: _pwdDiscount,
                  onChanged: (v) => setState(() => _pwdDiscount = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          _buildHeader('Display Options', Icons.visibility),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: SwitchListTile(
              title: const Text(
                'Show Tax Breakdown',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              subtitle: const Text(
                'Show VAT and other taxes on receipt',
                style: TextStyle(fontSize: 12),
              ),
              value: _showTaxBreakdown,
              onChanged: (v) => setState(() => _showTaxBreakdown = v),
            ),
          ),
          const SizedBox(height: 16),

          _buildHeader('Tax Preview', Icons.preview),
          const SizedBox(height: 8),
          _buildTaxPreview(),
          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _saveSettings,
              icon: const Icon(Icons.save),
              label: const Text(
                'SAVE TAX SETTINGS',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  letterSpacing: 1,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[700],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaxPreview() {
    double subtotal = 1000.00;
    double vat =
        _vatEnabled
            ? (_vatInclusive
                ? subtotal - (subtotal / (1 + _vatRate / 100))
                : subtotal * _vatRate / 100)
            : 0;
    double sc = _serviceChargeEnabled ? subtotal * _serviceChargeRate / 100 : 0;
    double total = _vatInclusive ? subtotal + sc : subtotal + vat + sc;
    return Card(
      color: Colors.orange[50],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Sample Calculation',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const Divider(),
            _buildPreviewRow('Subtotal', subtotal.toStringAsFixed(2)),
            if (_vatEnabled)
              _buildPreviewRow(
                'VAT (${_vatRate.toStringAsFixed(1)}%)${_vatInclusive ? ' included' : ''}',
                vat.toStringAsFixed(2),
              ),
            if (_serviceChargeEnabled)
              _buildPreviewRow(
                'Service Charge (${_serviceChargeRate.toStringAsFixed(1)}%)',
                sc.toStringAsFixed(2),
              ),
            const Divider(),
            _buildPreviewRow(
              'TOTAL',
              total.toStringAsFixed(2),
              isBold: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewRow(String label, String value, {bool isBold = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              ),
            ),
          ],
        ),
      );

  Widget _buildHeader(String title, IconData icon) => Row(
    children: [
      Icon(icon, size: 20, color: Colors.orange[700]),
      const SizedBox(width: 8),
      Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.orange[800],
        ),
      ),
    ],
  );
}
