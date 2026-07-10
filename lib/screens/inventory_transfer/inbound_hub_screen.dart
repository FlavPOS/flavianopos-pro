import 'package:flutter/material.dart';
import '../../services/device_assignment_service.dart';
import '../../helpers/database_helper.dart';
import 'transfer_v3_model.dart';
import 'transfer_list_screen.dart';

class InboundHubScreen extends StatefulWidget {
  final String branch;
  final String userName;

  const InboundHubScreen({
    super.key,
    required this.branch,
    required this.userName,
  });

  @override
  State<InboundHubScreen> createState() => _InboundHubScreenState();
}

class _InboundHubScreenState extends State<InboundHubScreen> {
  static const _green = Color(0xFF22C55E);
  static const _amber = Color(0xFFF59E0B);
  static const _red = Color(0xFFEF4444);
  static const _bg = Color(0xFFF5F6FA);
  static const _card = Color(0xFFFFFFFF);
  static const _textPrimary = Color(0xFF111827);
  static const _textSecondary = Color(0xFF6B7280);

  String _branchId = '';
  bool _loading = true;

  int _pendingCount = 0;
  int _receivedCount = 0;
  int _rejectedCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final assign = await DeviceAssignmentService().read();
      _branchId = (assign['branchId'] ?? '').toString();

      // ═══ DEBUG: Show what's in DB ═══
      debugPrint('═══════════════════════════════════════');
      debugPrint('[INBOUND-DEBUG] branchId (from device): $_branchId');
      try {
        final db = await DatabaseHelper().database;
        final all = await db.query('interstore_transfers_v3',
            orderBy: 'created_at DESC', limit: 20);
        debugPrint('[INBOUND-DEBUG] Total transfers in DB: ${all.length}');
        for (final row in all) {
          debugPrint('  → id=${row['transfer_id']} status=${row['status']} from=${row['issuing_branch_id']} to=${row['receiving_branch_id']}');
        }
      } catch (e) {
        debugPrint('[INBOUND-DEBUG] DB error: $e');
      }
      debugPrint('═══════════════════════════════════════');

      // Pending = FLOATING/PARTIAL transfers TO us
      final pending = await TransferV3Dao.countByStatuses(
        [TransferStatus.floating, TransferStatus.partiallyReceived],
        _branchId, 'inbound',
      );
      debugPrint('[INBOUND-DEBUG] Pending count: $pending (expected FLOATING for $_branchId)');
      debugPrint('[INBOUND-DEBUG] Status constants — FLOATING="${TransferStatus.floating}" PARTIAL="${TransferStatus.partiallyReceived}"');

      // Received = successfully accepted
      final received = await TransferV3Dao.countByStatuses(
        [TransferStatus.received, TransferStatus.closed],
        _branchId, 'inbound',
      );

      // Rejected = we declined
      final rejected = await TransferV3Dao.countByStatus(
        TransferStatus.rejected, _branchId, 'inbound',
      );

      if (!mounted) return;
      setState(() {
        _pendingCount = pending;
        _receivedCount = received;
        _rejectedCount = rejected;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _green,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.download_rounded, size: 20),
            SizedBox(width: 8),
            Text('Inbound Transfer',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildCard(
                    icon: Icons.pending_actions_rounded,
                    iconColor: _amber,
                    iconBg: const Color(0xFFFEF3C7),
                    title: 'Pending Receipt',
                    subtitle: 'Transfers awaiting your confirmation',
                    count: _pendingCount,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TransferListScreen(
                            branch: widget.branch,
                            userName: widget.userName,
                            branchId: _branchId,
                            status: TransferStatus.floating,
                            title: 'Pending Receipts',
                            themeColor: _amber,
                            direction: 'inbound',
                          ),
                        ),
                      ).then((_) => _load());
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildCard(
                    icon: Icons.check_circle_rounded,
                    iconColor: _green,
                    iconBg: const Color(0xFFDCFCE7),
                    title: 'Received',
                    subtitle: 'Successfully received transfers',
                    count: _receivedCount,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TransferListScreen(
                            branch: widget.branch,
                            userName: widget.userName,
                            branchId: _branchId,
                            status: TransferStatus.received,
                            title: 'Received Transfers',
                            themeColor: _green,
                            direction: 'inbound',
                          ),
                        ),
                      ).then((_) => _load());
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildCard(
                    icon: Icons.cancel_rounded,
                    iconColor: _red,
                    iconBg: const Color(0xFFFEE2E2),
                    title: 'Rejected',
                    subtitle: 'Transfers you declined',
                    count: _rejectedCount,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TransferListScreen(
                            branch: widget.branch,
                            userName: widget.userName,
                            branchId: _branchId,
                            status: TransferStatus.rejected,
                            title: 'Rejected Transfers',
                            direction: 'inbound',
                            themeColor: _red,
                          ),
                        ),
                      ).then((_) => _load());
                    },
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    required int count,
    required VoidCallback onTap,
  }) {
    return Material(
      color: _card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(title, style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold,
                            color: _textPrimary)),
                        if (count > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: iconColor,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '$count',
                              style: const TextStyle(
                                  fontSize: 10, fontWeight: FontWeight.bold,
                                  color: Colors.white),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(
                        fontSize: 12, color: _textSecondary, height: 1.3)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: iconColor, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
