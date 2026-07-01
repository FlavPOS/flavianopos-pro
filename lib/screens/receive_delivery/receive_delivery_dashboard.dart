// lib/screens/receive_delivery/receive_delivery_dashboard.dart
import 'package:flutter/material.dart';
import '../../models/product_model.dart';
import 'receive_delivery_screen.dart';
import 'delivery_model.dart';
import 'delivery_history_screen.dart';
import 'draft_list_screen.dart';

class ReceiveDeliveryDashboard extends StatefulWidget {
  final List<Product> products;
  const ReceiveDeliveryDashboard({super.key, required this.products});

  @override
  State<ReceiveDeliveryDashboard> createState() => _ReceiveDeliveryDashboardState();
}

class _ReceiveDeliveryDashboardState extends State<ReceiveDeliveryDashboard> {
  int _draftCount = 0;
  int _submittedCount = 0;
  int _approvedCount = 0;
  int _rejectedCount = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    setState(() => _loading = true);
    final drafts = await DeliveryStorage.countByStatus(DeliveryStatus.draft);
    final submitted = await DeliveryStorage.countByStatus(DeliveryStatus.submitted);
    final approved = await DeliveryStorage.countByStatus(DeliveryStatus.approved);
    final rejected = await DeliveryStorage.countByStatus(DeliveryStatus.rejected);
    if (mounted) {
      setState(() {
        _draftCount = drafts;
        _submittedCount = submitted;
        _approvedCount = approved;
        _rejectedCount = rejected;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.orange[700],
        foregroundColor: Colors.white,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.local_shipping_outlined, size: 24),
            SizedBox(width: 8),
            Text(
              'RECEIVE DELIVERY',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded, size: 22),
            tooltip: 'History',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DeliveryHistoryScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 22),
            tooltip: 'Refresh',
            onPressed: _loadCounts,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadCounts,
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  // Receive Delivery Card
                  _buildDashboardCard(
                    title: 'Receive Delivery',
                    subtitle: 'Manually record and receive incoming deliveries.',
                    icon: Icons.local_shipping_outlined,
                    color: Colors.orange[700]!,
                    bgColor: Colors.orange[50]!,
                    onTap: () => _openReceiveDelivery(),
                  ),
                  const SizedBox(height: 10),

                  // Draft Card
                  _buildDashboardCard(
                    title: 'Draft',
                    subtitle: 'Save deliveries as draft and continue later.',
                    icon: Icons.description_outlined,
                    color: const Color(0xFF7C3AED), // Purple
                    bgColor: const Color(0xFFEDE9FE),
                    count: _draftCount,
                    onTap: () => _openDraftList(),
                  ),
                  const SizedBox(height: 10),

                  // Submitted Card
                  _buildDashboardCard(
                    title: 'Submitted',
                    subtitle: 'View deliveries that are submitted and awaiting approval.',
                    icon: Icons.send_rounded,
                    color: const Color(0xFF2563EB), // Blue
                    bgColor: const Color(0xFFDBEAFE),
                    count: _submittedCount,
                    onTap: () => _showComingSoon('Submitted Module'),
                  ),
                  const SizedBox(height: 10),

                  // Approved Card
                  _buildDashboardCard(
                    title: 'Approved',
                    subtitle: 'View all deliveries that have been approved.',
                    icon: Icons.check_circle_outline,
                    color: const Color(0xFF16A34A), // Green
                    bgColor: const Color(0xFFDCFCE7),
                    count: _approvedCount,
                    onTap: () => _showComingSoon('Approved Module'),
                  ),
                  const SizedBox(height: 10),

                  // Rejected Card
                  _buildDashboardCard(
                    title: 'Rejected',
                    subtitle: 'View all deliveries that have been rejected.',
                    icon: Icons.cancel_outlined,
                    color: const Color(0xFFDC2626), // Red
                    bgColor: const Color(0xFFFECACA),
                    count: _rejectedCount,
                    onTap: () => _showComingSoon('Rejected Module'),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildDashboardCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color bgColor,
    int? count,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon container
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 14),
              // Text content
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
                            color: Colors.black87,
                          ),
                        ),
                        if (count != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$count',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              // Chevron
              Icon(
                Icons.chevron_right,
                color: color,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openReceiveDelivery() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReceiveDeliveryScreen(products: widget.products),
      ),
    );
    // Refresh counts when user returns
    _loadCounts();
  }

  void _openDraftList() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DraftListScreen(products: widget.products)),
    );
    _loadCounts();
  }

  void _showComingSoon(String module) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$module - Coming next!'),
        backgroundColor: Colors.orange[700],
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
