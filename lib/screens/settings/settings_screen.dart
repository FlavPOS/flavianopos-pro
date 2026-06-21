// lib/screens/settings/settings_screen.dart
import 'package:flutter/material.dart';
import '../../utils/backup_helper.dart';
import '../../helpers/database_helper.dart';
import '../../models/settings_model.dart';
import '../../utils/theme_notifier.dart';
import 'store_profile_screen.dart';
import 'tax_settings_screen.dart';
import 'receipt_settings_screen.dart';
import 'printer_settings_screen.dart';

class SettingsScreen extends StatefulWidget {
  final String branch;
  const SettingsScreen({super.key, required this.branch});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {

  void _s(String key, dynamic value) => AppSettings.save(key, value);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blueGrey[700], foregroundColor: Colors.white,
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        // ══════ 1. STORE SETTINGS ══════
        _buildSectionHeader('Store Settings', Icons.store),
        const SizedBox(height: 8),
        _buildSettingsTile(icon: Icons.storefront, iconColor: Colors.blue,
          title: 'Store Profile', subtitle: 'Name, address, contact info',
          onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (context) => StoreProfileScreen(branch: widget.branch)))),
        _buildSettingsTile(icon: Icons.calculate, iconColor: Colors.orange,
          title: 'Tax Settings', subtitle: 'VAT, service charge, tax rates',
          onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (context) => const TaxSettingsScreen()))),
        _buildSettingsTile(icon: Icons.receipt_long, iconColor: Colors.green,
          title: 'Receipt Settings', subtitle: 'Header, footer, layout',
          onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (context) => const ReceiptSettingsScreen()))),
        _buildSettingsTile(icon: Icons.print, iconColor: Colors.deepPurple,
          title: 'Printer Settings', subtitle: 'Connect and manage printers',
          onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (context) => const PrinterSettingsScreen()))),

        // ══════ 2. CASHIERING ══════
        const SizedBox(height: 24),
        _buildSectionHeader('Cashiering', Icons.point_of_sale),
        const SizedBox(height: 8),
        Card(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Column(children: [
            SwitchListTile(
              secondary: _iconBox(Icons.touch_app, Colors.green),
              title: const Text('Qty Popup on Tap', style: TextStyle(fontWeight: FontWeight.w500)),
              subtitle: const Text('Show quantity dialog when tapping a product', style: TextStyle(fontSize: 12)),
              value: AppSettings.qtyPopupOnTap,
              onChanged: (v) => setState(() { AppSettings.qtyPopupOnTap = v; _s('qtyPopupOnTap', v); })),
            const Divider(height: 0),
            ListTile(
              leading: _iconBox(Icons.payment, Colors.blue),
              title: const Text('Default Payment', style: TextStyle(fontWeight: FontWeight.w500)),
              trailing: DropdownButton<String>(value: AppSettings.defaultPayment, underline: const SizedBox(),
                items: ['Cash', 'GCash', 'Maya', 'Card'].map((p) => DropdownMenuItem(value: p, child: Text(p, style: const TextStyle(fontSize: 14)))).toList(),
                onChanged: (v) => setState(() { AppSettings.defaultPayment = v!; _s('defaultPayment', v); }))),
            const Divider(height: 0),
            SwitchListTile(
              secondary: _iconBox(Icons.print, Colors.purple),
              title: const Text('Auto-Print Receipt', style: TextStyle(fontWeight: FontWeight.w500)),
              subtitle: const Text('Automatically print after payment', style: TextStyle(fontSize: 12)),
              value: AppSettings.autoPrintReceipt,
              onChanged: (v) => setState(() { AppSettings.autoPrintReceipt = v; _s('autoPrintReceipt', v); })),
            const Divider(height: 0),
            SwitchListTile(
              secondary: _iconBox(Icons.remove_shopping_cart, Colors.red),
              title: const Text('Allow Negative Stock', style: TextStyle(fontWeight: FontWeight.w500)),
              subtitle: const Text('Sell items even if stock is 0', style: TextStyle(fontSize: 12)),
              value: AppSettings.allowNegativeStock,
              onChanged: (v) => setState(() { AppSettings.allowNegativeStock = v; _s('allowNegativeStock', v); })),
            const Divider(height: 0),
            SwitchListTile(
              secondary: _iconBox(Icons.inventory_2, Colors.teal),
              title: const Text('Show Stock on Card', style: TextStyle(fontWeight: FontWeight.w500)),
              subtitle: const Text('Display available stock on product cards', style: TextStyle(fontSize: 12)),
              value: AppSettings.showStockOnCard,
              onChanged: (v) => setState(() { AppSettings.showStockOnCard = v; _s('showStockOnCard', v); })),
          ])),

        // ══════ 3. INVENTORY ══════
        const SizedBox(height: 24),
        _buildSectionHeader('Inventory', Icons.inventory_2),
        const SizedBox(height: 8),
        Card(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Column(children: [
            ListTile(
              leading: _iconBox(Icons.warning_amber, Colors.orange),
              title: const Text('Low Stock Threshold', style: TextStyle(fontWeight: FontWeight.w500)),
              subtitle: Text('Alert when stock <= ${AppSettings.lowStockThreshold}', style: const TextStyle(fontSize: 12))),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                const Text('1', style: TextStyle(fontSize: 11)),
                Expanded(child: Slider(value: AppSettings.lowStockThreshold.toDouble(), min: 1, max: 50, divisions: 49,
                  label: '${AppSettings.lowStockThreshold}', activeColor: Colors.orange,
                  onChanged: (v) => setState(() { AppSettings.lowStockThreshold = v.round(); _s('lowStockThreshold', v.round()); }))),
                Text('${AppSettings.lowStockThreshold}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ])),
            const Divider(height: 0),
            SwitchListTile(
              secondary: _iconBox(Icons.layers, Colors.blue),
              title: const Text('Batch & Expiry Tracking', style: TextStyle(fontWeight: FontWeight.w500)),
              subtitle: const Text('Track product batches and expiry dates', style: TextStyle(fontSize: 12)),
              value: AppSettings.enableBatchTracking,
              onChanged: (v) => setState(() { AppSettings.enableBatchTracking = v; _s('enableBatchTracking', v); })),
            const Divider(height: 0),
            SwitchListTile(
              secondary: _iconBox(Icons.remove_circle, Colors.green),
              title: const Text('Auto-Deduct Stock', style: TextStyle(fontWeight: FontWeight.w500)),
              subtitle: const Text('Automatically reduce stock after sale', style: TextStyle(fontSize: 12)),
              value: AppSettings.autoDeductStock,
              onChanged: (v) => setState(() { AppSettings.autoDeductStock = v; _s('autoDeductStock', v); })),
            const Divider(height: 0),
            SwitchListTile(
              secondary: _iconBox(Icons.visibility_off, Colors.red),
              title: const Text('Show Cost Price', style: TextStyle(fontWeight: FontWeight.w500)),
              subtitle: const Text('Display cost/purchase price in inventory', style: TextStyle(fontSize: 12)),
              value: AppSettings.showCostPrice,
              onChanged: (v) => setState(() { AppSettings.showCostPrice = v; _s('showCostPrice', v); })),
          ])),

        // ══════ 4. SALES & REPORTS ══════
        const SizedBox(height: 24),
        _buildSectionHeader('Sales & Reports', Icons.analytics),
        const SizedBox(height: 8),
        Card(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Column(children: [
            ListTile(
              leading: _iconBox(Icons.date_range, Colors.blue),
              title: const Text('Default Report Period', style: TextStyle(fontWeight: FontWeight.w500)),
              trailing: DropdownButton<String>(value: AppSettings.defaultReportPeriod, underline: const SizedBox(),
                items: ['Today', 'This Week', 'This Month', 'All Time'].map((p) => DropdownMenuItem(value: p, child: Text(p, style: const TextStyle(fontSize: 14)))).toList(),
                onChanged: (v) => setState(() { AppSettings.defaultReportPeriod = v!; _s('defaultReportPeriod', v); }))),
            const Divider(height: 0),
            SwitchListTile(
              secondary: _iconBox(Icons.local_offer, Colors.orange),
              title: const Text('Discount Monitoring', style: TextStyle(fontWeight: FontWeight.w500)),
              subtitle: const Text('Track and report all discounts given', style: TextStyle(fontSize: 12)),
              value: AppSettings.enableDiscountMonitoring,
              onChanged: (v) => setState(() { AppSettings.enableDiscountMonitoring = v; _s('enableDiscountMonitoring', v); })),
            const Divider(height: 0),
            ListTile(
              leading: _iconBox(Icons.schedule, Colors.purple),
              title: const Text('Z Report Reset Time', style: TextStyle(fontWeight: FontWeight.w500)),
              subtitle: const Text('Daily cutoff time for Z Report', style: TextStyle(fontSize: 12)),
              trailing: DropdownButton<String>(value: AppSettings.zReportResetTime, underline: const SizedBox(),
                items: ['12:00 AM', '3:00 AM', '6:00 AM', '8:00 AM'].map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 14)))).toList(),
                onChanged: (v) => setState(() { AppSettings.zReportResetTime = v!; _s('zReportResetTime', v); }))),
          ])),

        // ══════ 5. SECURITY ══════
        const SizedBox(height: 24),
        _buildSectionHeader('Security', Icons.security),
        const SizedBox(height: 8),
        Card(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Column(children: [
            SwitchListTile(
              secondary: _iconBox(Icons.lock, Colors.red),
              title: const Text('PIN for Void / Refund', style: TextStyle(fontWeight: FontWeight.w500)),
              subtitle: const Text('Require manager PIN to void transactions', style: TextStyle(fontSize: 12)),
              value: AppSettings.requirePinVoid,
              onChanged: (v) => setState(() { AppSettings.requirePinVoid = v; _s('requirePinVoid', v); })),
            const Divider(height: 0),
            SwitchListTile(
              secondary: _iconBox(Icons.discount, Colors.orange),
              title: const Text('PIN for High Discount', style: TextStyle(fontWeight: FontWeight.w500)),
              subtitle: Text('Require PIN for discounts > ${AppSettings.pinDiscountThreshold}%', style: const TextStyle(fontSize: 12)),
              value: AppSettings.requirePinDiscount,
              onChanged: (v) => setState(() { AppSettings.requirePinDiscount = v; _s('requirePinDiscount', v); })),
            if (AppSettings.requirePinDiscount) ...[
              const Divider(height: 0),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(children: [
                  const Text('Threshold: ', style: TextStyle(fontSize: 12)),
                  Expanded(child: Slider(value: AppSettings.pinDiscountThreshold.toDouble(), min: 5, max: 50, divisions: 9,
                    label: '${AppSettings.pinDiscountThreshold}%', activeColor: Colors.orange,
                    onChanged: (v) => setState(() { AppSettings.pinDiscountThreshold = v.round(); _s('pinDiscountThreshold', v.round()); }))),
                  Text('${AppSettings.pinDiscountThreshold}%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ])),
            ],
            const Divider(height: 0),
            ListTile(
              leading: _iconBox(Icons.percent, Colors.blue),
              title: const Text('Max Discount Allowed', style: TextStyle(fontWeight: FontWeight.w500)),
              subtitle: Text('Limit: ${AppSettings.maxDiscountPercent}%', style: const TextStyle(fontSize: 12))),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                const Text('0%', style: TextStyle(fontSize: 11)),
                Expanded(child: Slider(value: AppSettings.maxDiscountPercent.toDouble(), min: 0, max: 100, divisions: 20,
                  label: '${AppSettings.maxDiscountPercent}%', activeColor: Colors.blue,
                  onChanged: (v) => setState(() { AppSettings.maxDiscountPercent = v.round(); _s('maxDiscountPercent', v.round()); }))),
                Text('${AppSettings.maxDiscountPercent}%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ])),
            const Divider(height: 0),
            SwitchListTile(
              secondary: _iconBox(Icons.edit, Colors.purple),
              title: const Text('Allow Price Override', style: TextStyle(fontWeight: FontWeight.w500)),
              subtitle: const Text('Let cashiers change item price at POS', style: TextStyle(fontSize: 12)),
              value: AppSettings.allowPriceOverride,
              onChanged: (v) => setState(() { AppSettings.allowPriceOverride = v; _s('allowPriceOverride', v); })),
          ])),

        // ══════ 6. NOTIFICATIONS ══════
        const SizedBox(height: 24),
        _buildSectionHeader('Notifications', Icons.notifications),
        const SizedBox(height: 8),
        Card(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Column(children: [
            SwitchListTile(
              secondary: _iconBox(Icons.warning, Colors.orange),
              title: const Text('Low Stock Alerts', style: TextStyle(fontWeight: FontWeight.w500)),
              subtitle: Text('Notify when stock <= ${AppSettings.lowStockThreshold}', style: const TextStyle(fontSize: 12)),
              value: AppSettings.lowStockAlerts,
              onChanged: (v) => setState(() { AppSettings.lowStockAlerts = v; _s('lowStockAlerts', v); })),
            const Divider(height: 0),
            SwitchListTile(
              secondary: _iconBox(Icons.event_busy, Colors.red),
              title: const Text('Expiring Batch Alerts', style: TextStyle(fontWeight: FontWeight.w500)),
              subtitle: Text('Warn ${AppSettings.expiryAlertDays} days before expiry', style: const TextStyle(fontSize: 12)),
              value: AppSettings.expiryAlerts,
              onChanged: (v) => setState(() { AppSettings.expiryAlerts = v; _s('expiryAlerts', v); })),
            if (AppSettings.expiryAlerts) ...[
              const Divider(height: 0),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(children: [
                  const Text('Days: ', style: TextStyle(fontSize: 12)),
                  Expanded(child: Slider(value: AppSettings.expiryAlertDays.toDouble(), min: 7, max: 90, divisions: 83,
                    label: '${AppSettings.expiryAlertDays} days', activeColor: Colors.red,
                    onChanged: (v) => setState(() { AppSettings.expiryAlertDays = v.round(); _s('expiryAlertDays', v.round()); }))),
                  Text('${AppSettings.expiryAlertDays}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ])),
            ],
          ])),

        // ══════ 7. APP SETTINGS ══════
        const SizedBox(height: 24),
        _buildSectionHeader('App Settings', Icons.tune),
        const SizedBox(height: 8),
        Card(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Column(children: [
            SwitchListTile(
              secondary: _iconBox(Icons.dark_mode, Colors.indigo),
              title: const Text('Dark Mode', style: TextStyle(fontWeight: FontWeight.w500)),
              subtitle: const Text('Switch to dark theme', style: TextStyle(fontSize: 12)),
              value: AppSettings.darkMode,
              onChanged: (v) { ThemeNotifier.instance.setDark(v); setState(() {}); }),
            const Divider(height: 0),
            SwitchListTile(
              secondary: _iconBox(Icons.volume_up, Colors.teal),
              title: const Text('Sound Effects', style: TextStyle(fontWeight: FontWeight.w500)),
              subtitle: const Text('Beep on scan, payment sounds', style: TextStyle(fontSize: 12)),
              value: AppSettings.soundEffects,
              onChanged: (v) => setState(() { AppSettings.soundEffects = v; _s('soundEffects', v); })),
            const Divider(height: 0),
            SwitchListTile(
              secondary: _iconBox(Icons.timer, Colors.red),
              title: const Text('Auto Logout', style: TextStyle(fontWeight: FontWeight.w500)),
              subtitle: Text('After ${AppSettings.autoLogoutMinutes} minutes of inactivity', style: const TextStyle(fontSize: 12)),
              value: AppSettings.autoLogout,
              onChanged: (v) => setState(() { AppSettings.autoLogout = v; _s('autoLogout', v); })),
            if (AppSettings.autoLogout) ...[
              const Divider(height: 0),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(children: [
                  const Text('Timeout: ', style: TextStyle(fontSize: 13)),
                  Expanded(child: Slider(value: AppSettings.autoLogoutMinutes.toDouble(), min: 5, max: 120, divisions: 23,
                    label: '${AppSettings.autoLogoutMinutes} min',
                    onChanged: (v) => setState(() { AppSettings.autoLogoutMinutes = v.round(); _s('autoLogoutMinutes', v.round()); }))),
                  Text('${AppSettings.autoLogoutMinutes} min', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ])),
            ],
          ])),

        // ══════ 8. REGIONAL ══════
        const SizedBox(height: 24),
        _buildSectionHeader('Regional', Icons.language),
        const SizedBox(height: 8),
        Card(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Column(children: [
            ListTile(
              leading: _iconBox(Icons.language, Colors.purple),
              title: const Text('Language', style: TextStyle(fontWeight: FontWeight.w500)),
              subtitle: const Text('Multi-language coming soon', style: TextStyle(fontSize: 12, color: Colors.orange)),
              trailing: const Text('English', style: TextStyle(color: Colors.grey, fontSize: 13)),
              enabled: false,
            ),
            ListTile(
              leading: _iconBox(Icons.attach_money, Colors.green),
              title: const Text('Currency', style: TextStyle(fontWeight: FontWeight.w500)),
              trailing: DropdownButton<String>(value: AppSettings.currency, underline: const SizedBox(),
                items: ['PHP', 'USD', 'SGD'].map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 14)))).toList(),
                onChanged: (v) => setState(() { AppSettings.currency = v!; _s('currency', v); }))),
          ])),

        // ══════ 9. DATA MANAGEMENT ══════
        const SizedBox(height: 24),
        _buildSectionHeader('Data Management', Icons.storage),
        const SizedBox(height: 8),
        _buildSettingsTile(icon: Icons.backup, iconColor: Colors.blue,
          title: 'Backup Data', subtitle: 'Export data to cloud or file',
          onTap: _handleBackup),
        _buildSettingsTile(icon: Icons.restore, iconColor: Colors.orange,
          title: 'Restore Data', subtitle: 'Import from backup file',
          onTap: _handleRestore),
        _buildSettingsTile(icon: Icons.delete_forever, iconColor: Colors.red,
          title: 'Clear All Data', subtitle: 'Reset app to factory defaults',
          onTap: _confirmClearData),

        // ══════ 10. ABOUT ══════
        const SizedBox(height: 24),
        _buildSectionHeader('About', Icons.info_outline),
        const SizedBox(height: 8),
        Card(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(padding: const EdgeInsets.all(20),
            child: Column(children: [
              Container(padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: const Color(0xFF1565C0).withAlpha(20), shape: BoxShape.circle),
                child: const Icon(Icons.point_of_sale, color: Color(0xFF1565C0), size: 40)),
              const SizedBox(height: 12),
              const Text('FlavianoPOS - PRO', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Version 1.0.0', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
              const SizedBox(height: 4),
              Text('Built with Flutter', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              const SizedBox(height: 12),
              Text('Developed by Flaviano Dagondon Jr.', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            ]))),
        const SizedBox(height: 32),
      ]),
    );
  }

  Widget _iconBox(IconData icon, Color color) => Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(color: color.withAlpha(25), borderRadius: BorderRadius.circular(8)),
    child: Icon(icon, color: color, size: 20));

  Widget _buildSectionHeader(String title, IconData icon) => Row(children: [
    Icon(icon, size: 20, color: Colors.blueGrey[700]), const SizedBox(width: 8),
    Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey[800]))]);

  Widget _buildSettingsTile({required IconData icon, required Color iconColor,
    required String title, required String subtitle, required VoidCallback onTap}) {
    return Card(margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: _iconBox(icon, iconColor),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey), onTap: onTap));
  }

  void _handleBackup() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Creating backup...'),
          ],
        ),
      ),
    );
    try {
      final filename = await BackupHelper.saveBackupToFile();
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Backup created: $filename'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Backup failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _handleRestore() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('⚠️ Restore Backup'),
        content: const Text(
          'This will REPLACE all current data with backup data.\n\nContinue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Restoring data...'),
          ],
        ),
      ),
    );

    final result = await BackupHelper.pickAndRestoreBackup();
    if (mounted) Navigator.pop(context);
    if (result == null) return;

    if (result['success'] == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Restored ${result['restoredRows']} rows. Please restart app.',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Restore failed: ${result['error']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _confirmClearData() {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Clear All Data'),
      content: const Text('This will delete ALL data. This cannot be undone!'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(onPressed: () { Navigator.pop(ctx); _doClearAllData(); },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
          child: const Text('Clear All')),
      ]));
  }

  Future<void> _doClearAllData() async {
    try {
      await DatabaseHelper().clearAllData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All data cleared. Please restart the app.'),
            backgroundColor: Colors.green, behavior: SnackBarBehavior.floating));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error clearing data: $e'),
            backgroundColor: Colors.red, behavior: SnackBarBehavior.floating));
      }
    }
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg), behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
  }
}
