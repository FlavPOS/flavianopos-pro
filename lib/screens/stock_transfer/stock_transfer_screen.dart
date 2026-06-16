// ============================================================
// STOCK TRANSFER HUB - QuickPOS Pro
// Main screen with dashboard cards + navigation to sub-screens
// ============================================================
import 'package:flutter/material.dart';
import '../../models/stock_transfer_model.dart';
import 'create_transfer_screen.dart';
import 'receive_transfer_screen.dart';
import 'transfer_history_screen.dart';

class StockTransferScreen extends StatefulWidget {
  final String currentUser;
  final String currentBranch;
  const StockTransferScreen({super.key, required this.currentUser, required this.currentBranch});
  @override
  State<StockTransferScreen> createState() => _StockTransferScreenState();
}

class _StockTransferScreenState extends State<StockTransferScreen> {
  Map<String, int> _stats = {'inTransit': 0, 'receivedToday': 0, 'outboundToday': 0, 'pendingReceive': 0};
  bool _isLoading = true;

  @override
  void initState() { super.initState(); _loadStats(); }

  Future<void> _loadStats() async {
    final stats = await StockTransferStorage.getDashboardStats();
    setState(() { _stats = stats; _isLoading = false; });
  }

  Future<void> _navigateAndRefresh(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    _loadStats();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Transfer', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue[800], foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _loadStats,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ---- Dashboard Stats ----
            _isLoading
              ? const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
              : Row(children: [
                  _dashCard('In Transit', '${_stats['inTransit']}', Icons.local_shipping, Colors.orange),
                  const SizedBox(width: 8),
                  _dashCard('Received Today', '${_stats['receivedToday']}', Icons.check_circle, Colors.green),
                  const SizedBox(width: 8),
                  _dashCard('Outbound Today', '${_stats['outboundToday']}', Icons.send, Colors.blue),
                  const SizedBox(width: 8),
                  _dashCard('Pending', '${_stats['pendingReceive']}', Icons.hourglass_bottom, Colors.red),
                ]),
            const SizedBox(height: 24),

            // ---- Quick Actions ----
            const Text('Quick Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            // Create Outbound Transfer
            _actionCard(
              icon: Icons.send, color: Colors.blue[800]!,
              title: 'Create Outbound Transfer',
              subtitle: 'Transfer stock from this branch to another branch',
              badge: 'OUTBOUND',
              onTap: () => _navigateAndRefresh(CreateTransferScreen(
                currentUser: widget.currentUser, currentBranch: widget.currentBranch)),
            ),
            const SizedBox(height: 10),

            // Receive Inbound Transfer
            _actionCard(
              icon: Icons.call_received, color: Colors.green[700]!,
              title: 'Receive Inbound Transfer',
              subtitle: '${_stats['inTransit']} transfer(s) waiting to be received',
              badge: _stats['inTransit']! > 0 ? '${_stats['inTransit']} PENDING' : 'INBOUND',
              badgeColor: _stats['inTransit']! > 0 ? Colors.orange : Colors.green,
              onTap: () => _navigateAndRefresh(ReceiveTransferScreen(
                currentUser: widget.currentUser, currentBranch: widget.currentBranch)),
            ),
            const SizedBox(height: 10),

            // Transfer History
            _actionCard(
              icon: Icons.history, color: Colors.purple[700]!,
              title: 'Transfer History',
              subtitle: 'View all transfers, filter, export Excel/PDF, print slips',
              badge: 'HISTORY',
              onTap: () => _navigateAndRefresh(TransferHistoryScreen(currentUser: widget.currentUser)),
            ),
            const SizedBox(height: 24),

            // ---- How It Works ----
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(12)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(Icons.info_outline, color: Colors.blue[800], size: 20),
                  const SizedBox(width: 8),
                  Text('How Stock Transfer Works', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[800])),
                ]),
                const SizedBox(height: 12),
                _stepRow('1', 'Create Outbound', 'Select items with batch, set quantities, post transfer'),
                _stepRow('2', 'In Transit', 'Stock deducted from source. Transfer moves to receiving queue'),
                _stepRow('3', 'Receive Inbound', 'Destination branch receives items. Stock added to inventory'),
                _stepRow('4', 'Completed', 'Transfer marked as Received. Ledger updated for both branches'),
              ]),
            ),
            const SizedBox(height: 16),
          ]),
        ),
      ),
    );
  }

  Widget _dashCard(String label, String value, IconData icon, Color color) => Expanded(
    child: Card(elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        child: Column(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color)),
          Text(label, style: TextStyle(fontSize: 8, color: Colors.grey[600]), textAlign: TextAlign.center),
        ]))));

  Widget _actionCard({required IconData icon, required Color color, required String title,
    required String subtitle, required String badge, Color? badgeColor, required VoidCallback onTap}) {
    return Card(
      elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(14),
        child: Padding(padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withAlpha(20), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 28)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: (badgeColor ?? color).withAlpha(20), borderRadius: BorderRadius.circular(6)),
                  child: Text(badge, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: badgeColor ?? color))),
              ]),
              const SizedBox(height: 4),
              Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ])),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ]))),
    );
  }

  Widget _stepRow(String num, String title, String desc) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 24, height: 24, alignment: Alignment.center,
        decoration: BoxDecoration(color: Colors.blue[800], shape: BoxShape.circle),
        child: Text(num, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blue[800])),
        Text(desc, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ])),
    ]),
  );
}
