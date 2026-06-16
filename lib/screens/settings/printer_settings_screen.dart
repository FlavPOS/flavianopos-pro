// lib/screens/settings/printer_settings_screen.dart
import 'package:flutter/material.dart';

class SavedPrinter {
  final String id;
  final String name;
  final String type;
  final String address;
  bool isDefault;
  SavedPrinter({required this.id, required this.name, required this.type,
    required this.address, this.isDefault = false});
}

class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({super.key});
  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  final List<SavedPrinter> _printers = [];
  bool _autoPrint = false;
  String _paperSize = '80mm';
  int _copies = 1;
  bool _openDrawer = true;
  bool _printLogo = true;
  bool _cutPaper = true;

  void _addPrinter() {
    final nameCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    String selectedType = 'Bluetooth';

    showDialog(context: context, builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: const Text('Add Printer'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameCtrl,
              decoration: InputDecoration(labelText: 'Printer Name',
                  prefixIcon: const Icon(Icons.print),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: selectedType,
            decoration: InputDecoration(labelText: 'Connection Type',
                prefixIcon: const Icon(Icons.cable),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
            items: ['Bluetooth', 'USB', 'WiFi/Network'].map((t) =>
                DropdownMenuItem(value: t, child: Text(t))).toList(),
            onChanged: (v) => setDialogState(() => selectedType = v!)),
          const SizedBox(height: 12),
          TextField(controller: addressCtrl,
              decoration: InputDecoration(
                  labelText: selectedType == 'Bluetooth' ? 'MAC Address' :
                      selectedType == 'USB' ? 'USB Port' : 'IP Address',
                  prefixIcon: Icon(selectedType == 'Bluetooth' ? Icons.bluetooth :
                      selectedType == 'USB' ? Icons.usb : Icons.wifi),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  hintText: selectedType == 'Bluetooth' ? 'XX:XX:XX:XX:XX:XX' :
                      selectedType == 'USB' ? '/dev/usb/lp0' : '192.168.1.100')),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(onPressed: () {
            if (nameCtrl.text.trim().isNotEmpty) {
              setState(() => _printers.add(SavedPrinter(
                id: 'PRT-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
                name: nameCtrl.text.trim(), type: selectedType,
                address: addressCtrl.text.trim(),
                isDefault: _printers.isEmpty)));
              Navigator.pop(ctx);
              _snack('${nameCtrl.text.trim()} added!');
            }
          }, style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
              child: const Text('Add')),
        ])));
  }

  void _testPrint(SavedPrinter printer) {
    _snack('Testing ${printer.name}... Printer not found. Make sure printer is on and connected.');
  }

  void _setDefault(SavedPrinter printer) {
    setState(() { for (var p in _printers) { p.isDefault = false; } printer.isDefault = true; });
    _snack('${printer.name} set as default');
  }

  void _deletePrinter(SavedPrinter printer) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Remove Printer'),
      content: Text('Remove "${printer.name}"?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(onPressed: () {
          setState(() => _printers.removeWhere((p) => p.id == printer.id));
          Navigator.pop(ctx); _snack('${printer.name} removed');
        }, style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Remove')),
      ]));
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Printer Settings', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        _header('Saved Printers', Icons.print), const SizedBox(height: 8),
        if (_printers.isEmpty)
          Card(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(padding: const EdgeInsets.all(32),
              child: Column(children: [
                Icon(Icons.print_disabled, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 12),
                Text('No printers configured', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                const SizedBox(height: 4),
                Text('Tap "Add Printer" to connect a receipt printer',
                    style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                const SizedBox(height: 16),
                ElevatedButton.icon(onPressed: _addPrinter,
                  icon: const Icon(Icons.add), label: const Text('Add Printer'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white)),
              ])))
        else
          ..._printers.map((p) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: p.isDefault ? Colors.deepPurple.withAlpha(80) : Colors.transparent)),
            child: ListTile(
              leading: Container(padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.deepPurple.withAlpha(25), borderRadius: BorderRadius.circular(8)),
                child: Icon(p.type == 'Bluetooth' ? Icons.bluetooth : p.type == 'USB' ? Icons.usb : Icons.wifi,
                    color: Colors.deepPurple, size: 24)),
              title: Row(children: [
                Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                if (p.isDefault) ...[const SizedBox(width: 8),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(color: Colors.green.withAlpha(20), borderRadius: BorderRadius.circular(4)),
                    child: const Text('Default', style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.w600)))],
              ]),
              subtitle: Text('${p.type}  |  ${p.address.isEmpty ? 'No address' : p.address}',
                  style: const TextStyle(fontSize: 11)),
              trailing: PopupMenuButton<String>(onSelected: (v) {
                if (v == 'test') _testPrint(p);
                if (v == 'default') _setDefault(p);
                if (v == 'delete') _deletePrinter(p);
              }, itemBuilder: (context) => [
                const PopupMenuItem(value: 'test', child: Text('Test Print')),
                if (!p.isDefault) const PopupMenuItem(value: 'default', child: Text('Set as Default')),
                const PopupMenuItem(value: 'delete', child: Text('Remove', style: TextStyle(color: Colors.red))),
              ]),
            ))),
        const SizedBox(height: 8),
        if (_printers.isNotEmpty)
          OutlinedButton.icon(onPressed: _addPrinter,
            icon: const Icon(Icons.add), label: const Text('Add Another Printer')),
        const SizedBox(height: 24),

        _header('Print Options', Icons.tune), const SizedBox(height: 8),
        Card(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Column(children: [
            SwitchListTile(
              secondary: Container(padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.deepPurple.withAlpha(25), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.print, color: Colors.deepPurple, size: 20)),
              title: const Text('Auto-Print Receipt', style: TextStyle(fontWeight: FontWeight.w500)),
              subtitle: const Text('Automatically print after payment', style: TextStyle(fontSize: 12)),
              value: _autoPrint, onChanged: (v) => setState(() => _autoPrint = v)),
            const Divider(height: 0),
            ListTile(
              leading: Container(padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.orange.withAlpha(25), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.straighten, color: Colors.orange, size: 20)),
              title: const Text('Paper Size', style: TextStyle(fontWeight: FontWeight.w500)),
              trailing: DropdownButton<String>(value: _paperSize, underline: const SizedBox(),
                items: ['58mm', '80mm'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (v) => setState(() => _paperSize = v!))),
            const Divider(height: 0),
            ListTile(
              leading: Container(padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.blue.withAlpha(25), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.copy, color: Colors.blue, size: 20)),
              title: const Text('Number of Copies', style: TextStyle(fontWeight: FontWeight.w500)),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(icon: const Icon(Icons.remove_circle_outline),
                    onPressed: _copies > 1 ? () => setState(() => _copies--) : null),
                Text('$_copies', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                IconButton(icon: const Icon(Icons.add_circle_outline),
                    onPressed: _copies < 5 ? () => setState(() => _copies++) : null),
              ])),
          ])),
        const SizedBox(height: 16),

        _header('Advanced', Icons.settings), const SizedBox(height: 8),
        Card(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Column(children: [
            SwitchListTile(title: const Text('Print Store Logo', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
              subtitle: const Text('Show logo on receipt', style: TextStyle(fontSize: 11)),
              value: _printLogo, onChanged: (v) => setState(() => _printLogo = v), dense: true),
            const Divider(height: 0),
            SwitchListTile(title: const Text('Auto-Cut Paper', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
              subtitle: const Text('Cut receipt after printing', style: TextStyle(fontSize: 11)),
              value: _cutPaper, onChanged: (v) => setState(() => _cutPaper = v), dense: true),
            const Divider(height: 0),
            SwitchListTile(title: const Text('Open Cash Drawer', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
              subtitle: const Text('Open drawer on cash payment', style: TextStyle(fontSize: 11)),
              value: _openDrawer, onChanged: (v) => setState(() => _openDrawer = v), dense: true),
          ])),
        const SizedBox(height: 32),
      ]),
    );
  }

  Widget _header(String t, IconData i) => Row(children: [
    Icon(i, size: 20, color: Colors.deepPurple), const SizedBox(width: 8),
    Text(t, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
  ]);
}
