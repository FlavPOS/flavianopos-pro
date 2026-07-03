// lib/screens/receive_delivery/receive_delivery_dashboard.dart
import 'package:flutter/material.dart';
import '../../models/product_model.dart';
import 'receive_delivery_screen.dart';
import 'delivery_model.dart';
import 'draft_list_screen.dart';
import 'submitted_list_screen.dart';
import 'approved_list_screen.dart';
import 'rejected_list_screen.dart';

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
  String _selectedModule = 'dashboard';

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
        title: Row(mainAxisSize: MainAxisSize.min, children: const [
          Icon(Icons.local_shipping_outlined, size: 24),
          SizedBox(width: 8),
          Text('RECEIVE DELIVERY',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1)),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 22),
            tooltip: 'Refresh',
            onPressed: _loadCounts,
          ),
        ],
      ),
      body: LayoutBuilder(builder: (context, cons) {
        final isWide = cons.maxWidth >= 900;
        if (isWide) {
          // ═══ WIDE SCREEN: Split-view Sidebar + Content ═══
          return Row(children: [
            _buildSidebar(),
            const VerticalDivider(width: 1, thickness: 1),
            Expanded(child: _buildMainContent()),
          ]);
        }
        // ═══ PHONE: Original dashboard ═══
        return _buildDashboardContent();
      }),
    );
  }

  // ═══════════════ SIDEBAR (Wide Screen) ═══════════════
  Widget _buildSidebar() {
    return Container(
      width: 90,
      color: Colors.orange[700],
      child: Column(children: [
        const SizedBox(height: 12),
        _sidebarButton(
          icon: Icons.dashboard_outlined,
          tooltip: 'Dashboard',
          isActive: _selectedModule == 'dashboard',
          onTap: () => setState(() => _selectedModule = 'dashboard'),
        ),
        const SizedBox(height: 4),
        _sidebarButton(
          icon: Icons.add_circle_outline,
          tooltip: 'New Delivery',
          isActive: false,
          onTap: _openReceiveDelivery,
        ),
        Divider(color: Colors.white.withValues(alpha: 0.2), height: 12),
        _sidebarButton(
          icon: Icons.description_outlined,
          tooltip: 'Draft',
          badge: _draftCount,
          isActive: _selectedModule == 'draft',
          onTap: () => setState(() => _selectedModule = 'draft'),
        ),
        const SizedBox(height: 4),
        _sidebarButton(
          icon: Icons.send_rounded,
          tooltip: 'Submitted',
          badge: _submittedCount,
          isActive: _selectedModule == 'submitted',
          onTap: () => setState(() => _selectedModule = 'submitted'),
        ),
        const SizedBox(height: 4),
        _sidebarButton(
          icon: Icons.check_circle_outline,
          tooltip: 'Approved',
          badge: _approvedCount,
          isActive: _selectedModule == 'approved',
          onTap: () => setState(() => _selectedModule = 'approved'),
        ),
        const SizedBox(height: 4),
        _sidebarButton(
          icon: Icons.cancel_outlined,
          tooltip: 'Rejected',
          badge: _rejectedCount,
          isActive: _selectedModule == 'rejected',
          onTap: () => setState(() => _selectedModule = 'rejected'),
        ),
      ]),
    );
  }

  Widget _sidebarButton({
    required IconData icon,
    required String tooltip,
    int? badge,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      preferBelow: false,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Container(
            width: 90,
            height: 60,
            decoration: BoxDecoration(
              color: isActive ? Colors.white : Colors.transparent,
              border: isActive
                  ? Border(left: BorderSide(color: Colors.white, width: 3))
                  : null,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  icon,
                  color: isActive ? Colors.orange[700] : Colors.white,
                  size: 28,
                ),
                if (badge != null && badge > 0)
                  Positioned(
                    top: 8,
                    right: 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                      decoration: BoxDecoration(
                        color: Colors.red[600],
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: Text(
                        '$badge',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════ MAIN CONTENT (Switcher) ═══════════════
  Widget _buildMainContent() {
    switch (_selectedModule) {
      case 'draft':
        return DraftListScreen(products: widget.products);
      case 'submitted':
        return SubmittedListScreen(products: widget.products);
      case 'approved':
        return ApprovedListScreen(products: widget.products);
      case 'rejected':
        return RejectedListScreen(products: widget.products);
      default:
        return _buildDashboardContent();
    }
  }

  // ═══════════════ DASHBOARD CONTENT (Cards) ═══════════════
  Widget _buildDashboardContent() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _loadCounts,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _buildDashboardCard(
            title: 'Receive Delivery',
            subtitle: 'Manually record and receive incoming deliveries.',
            icon: Icons.local_shipping_outlined,
            color: Colors.orange[700]!,
            bgColor: Colors.orange[50]!,
            onTap: _openReceiveDelivery,
          ),
          const SizedBox(height: 10),
          _buildDashboardCard(
            title: 'Draft',
            subtitle: 'Save deliveries as draft and continue later.',
            icon: Icons.description_outlined,
            color: const Color(0xFF7C3AED),
            bgColor: const Color(0xFFEDE9FE),
            count: _draftCount,
            onTap: _openDraftList,
          ),
          const SizedBox(height: 10),
          _buildDashboardCard(
            title: 'Submitted',
            subtitle: 'View deliveries that are submitted and awaiting approval.',
            icon: Icons.send_rounded,
            color: const Color(0xFF2563EB),
            bgColor: const Color(0xFFDBEAFE),
            count: _submittedCount,
            onTap: _openSubmittedList,
          ),
          const SizedBox(height: 10),
          _buildDashboardCard(
            title: 'Approved',
            subtitle: 'View all deliveries that have been approved.',
            icon: Icons.check_circle_outline,
            color: const Color(0xFF16A34A),
            bgColor: const Color(0xFFDCFCE7),
            count: _approvedCount,
            onTap: _openApprovedList,
          ),
          const SizedBox(height: 10),
          _buildDashboardCard(
            title: 'Rejected',
            subtitle: 'View all deliveries that have been rejected.',
            icon: Icons.cancel_outlined,
            color: const Color(0xFFDC2626),
            bgColor: const Color(0xFFFECACA),
            count: _rejectedCount,
            onTap: _openRejectedList,
          ),
        ],
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
          child: Row(children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                  if (count != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
                      child: Text('$count',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ]),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ]),
            ),
            Icon(Icons.chevron_right, color: color, size: 24),
          ]),
        ),
      ),
    );
  }

  // ═══════════════ NAVIGATION (Mobile) ═══════════════
  void _openReceiveDelivery() async {
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => ReceiveDeliveryScreen(products: widget.products)));
    _loadCounts();
  }

  void _openDraftList() async {
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => DraftListScreen(products: widget.products)));
    _loadCounts();
  }

  void _openSubmittedList() async {
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => SubmittedListScreen(products: widget.products)));
    _loadCounts();
  }

  void _openApprovedList() async {
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => ApprovedListScreen(products: widget.products)));
    _loadCounts();
  }

  void _openRejectedList() async {
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => RejectedListScreen(products: widget.products)));
    _loadCounts();
  }
}
