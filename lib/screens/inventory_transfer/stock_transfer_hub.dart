import 'package:flutter/material.dart';
import '../../services/device_assignment_service.dart';
import 'transfer_v3_model.dart';
import 'outbound_hub_screen.dart';
import 'inbound_hub_screen.dart';

/// Main Stock Transfer Hub — matches enterprise ERP standards
/// Shows aggregate stats + entry to Outbound + Inbound flows
class StockTransferHub extends StatefulWidget {
  final String branch;
  final String userName;

  const StockTransferHub({
    super.key,
    required this.branch,
    required this.userName,
  });

  @override
  State<StockTransferHub> createState() => _StockTransferHubState();
}

class _StockTransferHubState extends State<StockTransferHub> {
  static const _blue = Color(0xFF3B82F6);
  static const _purple = Color(0xFF8B5CF6);
  static const _amber = Color(0xFFF59E0B);
  static const _green = Color(0xFF22C55E);
  static const _bg = Color(0xFFF5F6FA);
  static const _card = Color(0xFFFFFFFF);
  static const _textPrimary = Color(0xFF111827);
  static const _textSecondary = Color(0xFF6B7280);

  // ignore: unused_field
  String _branchId = '';
  bool _loading = true;

  // Aggregate counts
  int _inTransitCount = 0;
  int _receivedCount = 0;
  int _outboundCount = 0;
  int _pendingInboundCount = 0;

  @override
  void initState() {
    super.initState();
    _loadBranchAndCounts();
  }

  Future<void> _loadBranchAndCounts() async {
    try {
      final assign = await DeviceAssignmentService().read();
      final bid = (assign['branchId'] ?? '').toString();
      
      // Load counts
      final inTransit = await TransferV3Dao.countByStatuses(
        [TransferStatus.floating, TransferStatus.partiallyReceived],
        bid, 'outbound',
      );
      
      final received = await TransferV3Dao.countByStatuses(
        [TransferStatus.received, TransferStatus.closed],
        bid, 'inbound',
      );
      
      final outbound = await TransferV3Dao.countByStatuses(
        [TransferStatus.draft, TransferStatus.submitted, TransferStatus.approved],
        bid, 'outbound',
      );
      
      final pending = await TransferV3Dao.countByStatuses(
        [TransferStatus.floating, TransferStatus.partiallyReceived],
        bid, 'inbound',
      );
      
      if (!mounted) return;
      setState(() {
        _branchId = bid;
        _inTransitCount = inTransit;
        _receivedCount = received;
        _outboundCount = outbound;
        _pendingInboundCount = pending;
        _loading = false;
      });
    } catch (e) {
      debugPrint('[TRANSFER-HUB] Load error: PHOLDERR');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openOutbound() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OutboundHubScreen(
          branch: widget.branch,
          userName: widget.userName,
        ),
      ),
    ).then((_) => _loadBranchAndCounts());
  }

  void _openInbound() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InboundHubScreen(
          branch: widget.branch,
          userName: widget.userName,
        ),
      ),
    ).then((_) => _loadBranchAndCounts());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _blue,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.swap_horiz_rounded, size: 22),
            SizedBox(width: 8),
            Text(
              'STOCK TRANSFER',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadBranchAndCounts,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stat cards row
                  _buildStatsRow(),
                  const SizedBox(height: 20),

                  // Quick Actions section header
                  const Text(
                    'Quick Actions',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: _textPrimary,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Outbound button
                  _buildActionCard(
                    icon: Icons.send_rounded,
                    iconColor: _purple,
                    iconBg: const Color(0xFFEDE9FE),
                    title: 'Outbound Transfer',
                    subtitle: 'Create & dispatch transfers to other branches',
                    count: _outboundCount,
                    onTap: _openOutbound,
                  ),
                  const SizedBox(height: 12),

                  // Inbound button
                  _buildActionCard(
                    icon: Icons.download_rounded,
                    iconColor: _green,
                    iconBg: const Color(0xFFDCFCE7),
                    title: 'Inbound Transfer',
                    subtitle: 'Receive incoming transfers from other branches',
                    count: _pendingInboundCount,
                    onTap: _openInbound,
                  ),

                  const SizedBox(height: 24),

                  // Info panel
                  _buildInfoPanel(),
                ],
              ),
            ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.local_shipping_rounded,
            iconColor: _amber,
            value: '$_inTransitCount',
            label: 'In Transit',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            icon: Icons.check_circle_rounded,
            iconColor: _green,
            value: '$_receivedCount',
            label: 'Received',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            icon: Icons.send_rounded,
            iconColor: _purple,
            value: '$_outboundCount',
            label: 'Outbound',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            icon: Icons.pending_actions_rounded,
            iconColor: _blue,
            value: '$_pendingInboundCount',
            label: 'Pending',
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: _textPrimary,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: _textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
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
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _textPrimary,
                          ),
                        ),
                        if (count > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: iconColor,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '$count',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: _textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: iconColor,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _blue.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _blue.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded, color: _blue, size: 18),
              const SizedBox(width: 8),
              const Text(
                'How Stock Transfer Works',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: _textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoStep(
            step: '1',
            title: 'Create Outbound',
            subtitle: 'Select items to transfer to another branch',
          ),
          const SizedBox(height: 8),
          _buildInfoStep(
            step: '2',
            title: 'In-Transit (Floating)',
            subtitle: 'Once approved & dispatched, stock is deducted from source',
          ),
          const SizedBox(height: 8),
          _buildInfoStep(
            step: '3',
            title: 'Receive Inbound',
            subtitle: 'Destination confirms receipt (full/partial + variance)',
          ),
          const SizedBox(height: 8),
          _buildInfoStep(
            step: '4',
            title: 'Auto Post-Back',
            subtitle: 'Variances (shortage/damage) auto-return to source',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoStep({
    required String step,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: const BoxDecoration(
            color: _blue,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            step,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: _textPrimary,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11,
                  color: _textSecondary,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
