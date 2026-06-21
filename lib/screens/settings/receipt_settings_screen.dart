// lib/screens/settings/receipt_settings_screen.dart
import 'package:flutter/material.dart';
import '../../models/settings_model.dart';

class ReceiptSettingsScreen extends StatefulWidget {
  const ReceiptSettingsScreen({super.key});

  @override
  State<ReceiptSettingsScreen> createState() => _ReceiptSettingsScreenState();
}

class _ReceiptSettingsScreenState extends State<ReceiptSettingsScreen> {
  final _headerController = TextEditingController(text: AppSettings.receiptHeader);
  final _subheaderController = TextEditingController(
    text: AppSettings.receiptSubheader,
  );
  final _footerController = TextEditingController(
    text: AppSettings.receiptFooter,
  );
  final _footer2Controller = TextEditingController(text: AppSettings.receiptFooter2);
  final _tinController = TextEditingController(text: AppSettings.businessTin);
  bool _showLogo = AppSettings.showLogo;
  bool _showDate = AppSettings.showDate;
  bool _showCashier = AppSettings.showCashier;
  bool _showBranch = AppSettings.showBranch;
  bool _showItemCount = AppSettings.showItemCount;
  bool _showTaxBreakdown = true;
  bool _showBarcode = AppSettings.showBarcode;
  bool _showQRCode = AppSettings.showQRCode;
  String _paperSize = AppSettings.paperSize;
  String _fontSize = AppSettings.fontSize;

  void _saveSettings() {
    AppSettings.receiptHeader = _headerController.text; AppSettings.save('receiptHeader', _headerController.text);
    AppSettings.businessName = _headerController.text; AppSettings.save('businessName', _headerController.text);
    AppSettings.receiptSubheader = _subheaderController.text; AppSettings.save('receiptSubheader', _subheaderController.text);
    AppSettings.businessAddress = _subheaderController.text; AppSettings.save('businessAddress', _subheaderController.text);
    AppSettings.receiptFooter = _footerController.text; AppSettings.save('receiptFooter', _footerController.text);
    AppSettings.receiptFooter2 = _footer2Controller.text; AppSettings.save('receiptFooter2', _footer2Controller.text);
    AppSettings.businessTin = _tinController.text; AppSettings.save('businessTin', _tinController.text);
    AppSettings.showLogo = _showLogo; AppSettings.save('showLogo', _showLogo);
    AppSettings.showDate = _showDate; AppSettings.save('showDate', _showDate);
    AppSettings.showCashier = _showCashier; AppSettings.save('showCashier', _showCashier);
    AppSettings.showBranch = _showBranch; AppSettings.save('showBranch', _showBranch);
    AppSettings.showItemCount = _showItemCount; AppSettings.save('showItemCount', _showItemCount);
    AppSettings.showBarcode = _showBarcode; AppSettings.save('showBarcode', _showBarcode);
    AppSettings.showQRCode = _showQRCode; AppSettings.save('showQRCode', _showQRCode);
    AppSettings.paperSize = _paperSize; AppSettings.save('paperSize', _paperSize);
    AppSettings.fontSize = _fontSize; AppSettings.save('fontSize', _fontSize);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Receipt settings saved!'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.green,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  void dispose() {
    _headerController.dispose();
    _subheaderController.dispose();
    _footerController.dispose();
    _footer2Controller.dispose();
    _tinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Receipt Settings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.green[700],
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
          _buildHeader('Receipt Header', Icons.text_fields),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _headerController,
                    decoration: _decor('Store Name (Header)', Icons.store),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _subheaderController,
                    decoration: _decor(
                      'Address (Sub-header)',
                      Icons.location_on,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _tinController,
                    decoration: _decor('TIN Number', Icons.numbers),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          _buildHeader('Receipt Footer', Icons.text_snippet),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _footerController,
                    decoration: _decor('Footer Line 1', Icons.message),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _footer2Controller,
                    decoration: _decor('Footer Line 2', Icons.message_outlined),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          _buildHeader('Display Options', Icons.visibility),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _buildSwitch(
                  'Show Logo',
                  'Display store logo',
                  _showLogo,
                  (v) => setState(() => _showLogo = v),
                ),
                _buildSwitch(
                  'Show Date/Time',
                  'Transaction date and time',
                  _showDate,
                  (v) => setState(() => _showDate = v),
                ),
                _buildSwitch(
                  'Show Cashier',
                  'Cashier name',
                  _showCashier,
                  (v) => setState(() => _showCashier = v),
                ),
                _buildSwitch(
                  'Show Branch',
                  'Branch name',
                  _showBranch,
                  (v) => setState(() => _showBranch = v),
                ),
                _buildSwitch(
                  'Show Item Count',
                  'Total items',
                  _showItemCount,
                  (v) => setState(() => _showItemCount = v),
                ),
                _buildSwitch(
                  'Tax Breakdown',
                  'VAT details',
                  _showTaxBreakdown,
                  (v) => setState(() => _showTaxBreakdown = v),
                ),
                _buildSwitch(
                  'Show Barcode',
                  'Transaction barcode',
                  _showBarcode,
                  (v) => setState(() => _showBarcode = v),
                ),
                _buildSwitch(
                  'Show QR Code',
                  'Digital receipt QR',
                  _showQRCode,
                  (v) => setState(() => _showQRCode = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          _buildHeader('Paper & Font', Icons.description),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.straighten),
                  title: const Text(
                    'Paper Size',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  trailing: DropdownButton<String>(
                    value: _paperSize,
                    underline: const SizedBox(),
                    items:
                        ['58mm', '80mm']
                            .map(
                              (s) => DropdownMenuItem(value: s, child: Text(s)),
                            )
                            .toList(),
                    onChanged: (v) => setState(() => _paperSize = v!),
                  ),
                ),
                const Divider(height: 0),
                ListTile(
                  leading: const Icon(Icons.format_size),
                  title: const Text(
                    'Font Size',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  trailing: DropdownButton<String>(
                    value: _fontSize,
                    underline: const SizedBox(),
                    items:
                        ['Small', 'Medium', 'Large']
                            .map(
                              (s) => DropdownMenuItem(value: s, child: Text(s)),
                            )
                            .toList(),
                    onChanged: (v) => setState(() => _fontSize = v!),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          _buildHeader('Receipt Preview', Icons.preview),
          const SizedBox(height: 8),
          _buildReceiptPreview(),
          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _saveSettings,
              icon: const Icon(Icons.save),
              label: const Text(
                'SAVE RECEIPT SETTINGS',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  letterSpacing: 1,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
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

  Widget _buildReceiptPreview() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Column(
          children: [
            if (_showLogo) ...[
              const Icon(Icons.store, size: 32, color: Colors.grey),
              const SizedBox(height: 4),
            ],
            Text(
              _headerController.text,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            Text(
              _subheaderController.text,
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            Text(
              _tinController.text,
              style: TextStyle(fontSize: 10, color: Colors.grey[500]),
            ),
            const Divider(),
            if (_showDate) _buildReceiptRow('Date:', '06/07/2026 2:30 PM'),
            if (_showCashier) _buildReceiptRow('Cashier:', 'admin'),
            if (_showBranch) _buildReceiptRow('Branch:', 'Main Branch'),
            const Text('TXN-20260607-001', style: TextStyle(fontSize: 11)),
            const Divider(),
            _buildReceiptItem('Coca-Cola 1.5L x2', 'P130.00'),
            _buildReceiptItem('Piattos Cheese x1', 'P28.00'),
            _buildReceiptItem('Nescafe 3-in-1 x1', 'P95.00'),
            const Divider(),
            if (_showItemCount)
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Items: 4', style: TextStyle(fontSize: 11)),
              ),
            _buildReceiptItem('Subtotal', 'P253.00'),
            if (_showTaxBreakdown)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'VAT (12%)',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                    Text(
                      'P27.11',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            const Divider(),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'TOTAL',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  'P253.00',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            _buildReceiptRow('Cash', 'P300.00'),
            _buildReceiptRow('Change', 'P47.00'),
            const Divider(),
            Text(
              _footerController.text,
              style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
              textAlign: TextAlign.center,
            ),
            Text(
              _footer2Controller.text,
              style: TextStyle(fontSize: 10, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
            if (_showBarcode) ...[
              const SizedBox(height: 8),
              Container(
                height: 30,
                width: 150,
                color: Colors.grey[200],
                child: const Center(
                  child: Text(
                    '||||||||||||',
                    style: TextStyle(letterSpacing: 2),
                  ),
                ),
              ),
            ],
            if (_showQRCode) ...[
              const SizedBox(height: 8),
              Container(
                height: 60,
                width: 60,
                color: Colors.grey[200],
                child: const Center(child: Icon(Icons.qr_code, size: 40)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 1),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        Text(value, style: const TextStyle(fontSize: 11)),
      ],
    ),
  );

  Widget _buildReceiptItem(String name, String price) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(name, style: const TextStyle(fontSize: 12)),
        Text(price, style: const TextStyle(fontSize: 12)),
      ],
    ),
  );

  Widget _buildSwitch(
    String title,
    String subtitle,
    bool value,
    Function(bool) onChanged,
  ) => Column(
    children: [
      SwitchListTile(
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        ),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
        value: value,
        onChanged: onChanged,
        dense: true,
      ),
      const Divider(height: 0),
    ],
  );

  Widget _buildHeader(String title, IconData icon) => Row(
    children: [
      Icon(icon, size: 20, color: Colors.green[700]),
      const SizedBox(width: 8),
      Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.green[800],
        ),
      ),
    ],
  );

  InputDecoration _decor(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
  );
}
