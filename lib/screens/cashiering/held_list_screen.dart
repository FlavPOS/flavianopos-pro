// lib/screens/cashiering/held_list_screen.dart
// v1.0.74+160 - Held Transactions List (v153.1)
import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/held_transaction_model.dart';
import '../../helpers/database_helper.dart';

class HeldListScreen extends StatefulWidget {
  final String branch;
  const HeldListScreen({super.key, required this.branch});

  @override
  State<HeldListScreen> createState() => _HeldListScreenState();
}

class _HeldListScreenState extends State<HeldListScreen> {
  List<HeldTransaction> _held = [];
  bool _loading = true;
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadHeld();
    // Auto-refresh every 5s (Q4=A)
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) _loadHeld();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadHeld() async {
    try {
      final rows = await DatabaseHelper().getActiveHeldTransactions(widget.branch);
      if (!mounted) return;
      setState(() {
        _held = rows.map((r) => HeldTransaction.fromMap(r)).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  List<HeldTransaction> get _filtered {
    if (_searchQuery.isEmpty) return _held;
    final q = _searchQuery.toLowerCase();
    return _held.where((h) =>
      h.heldNumber.toLowerCase().contains(q) ||
      h.customerName.toLowerCase().contains(q) ||
      h.cashierName.toLowerCase().contains(q)
    ).toList();
  }

  Future<void> _deleteHeld(HeldTransaction h) async {
    // Q2=C: Confirmation dialog (no PIN)
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          Icon(Icons.warning_amber, color: Colors.red[700]),
          const SizedBox(width: 8),
          const Text('Delete Held Transaction?'),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(h.heldNumber, style: const TextStyle(fontWeight: FontWeight.bold)),
          if (h.customerName.isNotEmpty) Text('Customer: ' + h.customerName),
          Text('Items: ' + h.items.length.toString()),
          Text('Total: PHP ' + h.total.toStringAsFixed(2)),
          const SizedBox(height: 12),
          const Text('This will permanently delete the held transaction.',
            style: TextStyle(color: Colors.red, fontSize: 12)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700], foregroundColor: Colors.white),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await DatabaseHelper().updateHeldTransactionStatus(h.id, 'deleted');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deleted: ' + h.heldNumber), backgroundColor: Colors.red[700]),
      );
      _loadHeld();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: ' + e.toString())),
      );
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return diff.inMinutes.toString() + ' min ago';
    if (diff.inHours < 24) return diff.inHours.toString() + ' hr ago';
    return diff.inDays.toString() + ' days ago';
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    return Scaffold(
      appBar: AppBar(
        title: Text('HELD TRANSACTIONS (' + _held.length.toString() + ')',
          style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.purple[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadHeld, tooltip: 'Refresh'),
        ],
      ),
      body: Column(children: [
        // Search bar
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.purple[50],
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Search HLD number or customer name',
              prefixIcon: Icon(Icons.search, color: Colors.purple[700]),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              filled: true,
              fillColor: Colors.white,
              isDense: true,
            ),
            onChanged: (v) => setState(() => _searchQuery = v),
          ),
        ),
        // List
        Expanded(
          child: _loading
            ? const Center(child: CircularProgressIndicator())
            : list.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.pause_circle_outline, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 12),
                      Text(_searchQuery.isEmpty ? 'No active holds' : 'No holds match your search',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(8),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (ctx, i) {
                    final h = list[i];
                    return Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Icon(Icons.pause_circle, color: Colors.purple[700], size: 20),
                            const SizedBox(width: 6),
                            Text(h.heldNumber,
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.purple[900])),
                            const Spacer(),
                            Text(_timeAgo(h.heldAt),
                              style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                          ]),
                          const SizedBox(height: 6),
                          if (h.customerName.isNotEmpty)
                            Text('Customer: ' + h.customerName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          if (h.note.isNotEmpty)
                            Text('Note: ' + h.note,
                              style: TextStyle(fontSize: 12, color: Colors.grey[700], fontStyle: FontStyle.italic)),
                          Text('Cashier: ' + h.cashierName,
                            style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                          const SizedBox(height: 6),
                          Row(children: [
                            Icon(Icons.shopping_cart, size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(h.items.length.toString() + ' items',
                              style: const TextStyle(fontSize: 12)),
                            const SizedBox(width: 12),
                            Icon(Icons.payments, size: 14, color: Colors.green[700]),
                            const SizedBox(width: 4),
                            Text('PHP ' + h.total.toStringAsFixed(2),
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.green[700])),
                          ]),
                          const SizedBox(height: 8),
                          Row(children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _deleteHeld(h),
                                icon: const Icon(Icons.delete_outline, size: 16),
                                label: const Text('DELETE'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red[700],
                                  side: BorderSide(color: Colors.red[300]!),
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton.icon(
                                onPressed: () => Navigator.pop(context, h),
                                icon: const Icon(Icons.replay_circle_filled, size: 16),
                                label: const Text('RESUME'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.purple[700],
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                ),
                              ),
                            ),
                          ]),
                        ]),
                      ),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}
