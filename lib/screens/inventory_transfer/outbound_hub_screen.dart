import 'package:flutter/material.dart';
import '../../services/device_assignment_service.dart';
import 'transfer_v3_model.dart';
import 'transfer_prepared_screen.dart';

class OutboundHubScreen extends StatefulWidget {
  final String branch;
  final String userName;

  const OutboundHubScreen({
    super.key,
    required this.branch,
    required this.userName,
  });

  @override
  State<OutboundHubScreen> createState() => _OutboundHubScreenState();
}

class _OutboundHubScreenState extends State<OutboundHubScreen> {
  static const _purple = Color(0xFF8B5CF6);
  static const _amber = Color(0xFFF59E0B);
  static const _blue = Color(0xFF3B82F6);
  static const _cyan = Color(0xFF06B6D4);
  static const _red = Color(0xFFEF4444);
  static const _bg = Color(0xFFF5F6FA);
  static const _card = Color(0xFFFFFFFF);
  static const _textPrimary = Color(0xFF111827);
  static const _textSecondary = Color(0xFF6B7280);

  String _branchId = '';
  bool _loading = true;

  int _draftCount = 0;
  int _submittedCount = 0;
  int _approvedCount = 0;
  int _floatingCount = 0;
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
      final draft = await TransferV3Dao.countByStatus(
          TransferStatus.draft, _branchId, 'outbound');
      final submitted = await TransferV3Dao.countByStatus(
          TransferStatus.submitted, _branchId, 'outbound');
      final approved = await TransferV3Dao.countByStatus(
          TransferStatus.approved, _branchId, 'outbound');
      final floating = await TransferV3Dao.countByStatuses(
          [TransferStatus.floating, TransferStatus.partiallyReceived],
          _branchId, 'outbound');
      final rejected = await TransferV3Dao.countByStatus(
          TransferStatus.rejected, _branchId, 'outbound');
      if (!mounted) return;
      setState(() {
        _draftCount = draft;
        _submittedCount = submitted;
        _approvedCount = approved;
        _floatingCount = floating;
        _rejectedCount = rejected;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openPrepared() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TransferPreparedScreen(
          branch: widget.branch,
          userName: widget.userName,
        ),
      ),
    ).then((_) => _load());
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature coming in next phase!'),
        backgroundColor: _purple,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _purple,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.send_rounded, size: 20),
            SizedBox(width: 8),
            Text('Outbound Transfer',
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
                    icon: Icons.assignment_rounded, iconColor: _amber,
                    iconBg: const Color(0xFFFEF3C7),
                    title: 'Prepare Transfer',
                    subtitle: 'Create new outbound transfer to another branch',
                    count: -1, onTap: _openPrepared,
                  ),
                  const SizedBox(height: 12),
                  _buildCard(
                    icon: Icons.description_rounded, iconColor: _purple,
                    iconBg: const Color(0xFFEDE9FE),
                    title: 'Draft',
                    subtitle: 'Saved but not yet submitted',
                    count: _draftCount,
                    onTap: () => _showComingSoon('Draft list'),
                  ),
                  const SizedBox(height: 12),
                  _buildCard(
                    icon: Icons.send_rounded, iconColor: _blue,
                    iconBg: const Color(0xFFDBEAFE),
                    title: 'Submitted',
                    subtitle: 'Awaiting manager approval',
                    count: _submittedCount,
                    onTap: () => _showComingSoon('Submitted list'),
                  ),
                  const SizedBox(height: 12),
                  _buildCard(
                    icon: Icons.check_circle_rounded, iconColor: _cyan,
                    iconBg: const Color(0xFFCFFAFE),
                    title: 'Approved',
                    subtitle: 'Ready to dispatch',
                    count: _approvedCount,
                    onTap: () => _showComingSoon('Approved list'),
                  ),
                  const SizedBox(height: 12),
                  _buildCard(
                    icon: Icons.local_shipping_rounded, iconColor: _amber,
                    iconBg: const Color(0xFFFEF3C7),
                    title: 'In-Transit (Floating)',
                    subtitle: 'Dispatched, awaiting receipt at destination',
                    count: _floatingCount,
                    onTap: () => _showComingSoon('Floating list'),
                  ),
                  const SizedBox(height: 12),
                  _buildCard(
                    icon: Icons.cancel_rounded, iconColor: _red,
                    iconBg: const Color(0xFFFEE2E2),
                    title: 'Rejected',
                    subtitle: 'Declined by destination',
                    count: _rejectedCount,
                    onTap: () => _showComingSoon('Rejected list'),
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
