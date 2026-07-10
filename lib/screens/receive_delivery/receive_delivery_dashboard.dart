// lib/screens/receive_delivery/receive_delivery_dashboard.dart
// Modern SaaS-style dashboard with Plus Jakarta Sans typography
import 'package:flutter/material.dart';
import '../../services/device_assignment_service.dart';
import '../../theme/business_theme.dart';
import 'package:google_fonts/google_fonts.dart';
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
  String _selectedModule = 'receive';
  bool _sidebarCollapsed = false;
  bool _detailShowing = false;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = "";

  // Modern SaaS Palette 2026
  static const _indigo   = Color(0xFF5B5CEB);
  static const _violet   = Color(0xFF7C3AED);
  static const _indigoDeep = Color(0xFF312E81);
  static const _indigoMid  = Color(0xFF4F46E5);
  static const _orange   = Color(0xFFF97316);
  static const _cyan     = Color(0xFF06B6D4);
  static const _success  = Color(0xFF22C55E);
  static const _warning  = Color(0xFFF59E0B);
  static const _error    = Color(0xFFEF4444);
  static const _bgSlate  = Color(0xFFF8FAFC);
  static const _bgIndigo = Color(0xFFEEF2FF);
  static const _bgWhite  = Colors.white;
  static const _textDark = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);
  static const _border   = Color(0xFFE5E7EB);

  // Typography scale
  static const String _fontFamily = 'PlusJakartaSans';

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCounts() async {
    setState(() => _loading = true);
    // Get current branchId for filtering (matches synced data)
    final assign = await DeviceAssignmentService().read();
    final branchId = (assign['branchId'] ?? '').toString();
    debugPrint('[DELIV-DASH] Loading counts for branchId: $branchId');
    
    final drafts = await DeliveryStorage.countByStatus(DeliveryStatus.draft, branchId: branchId);
    final submitted = await DeliveryStorage.countByStatus(DeliveryStatus.submitted, branchId: branchId);
    final approved = await DeliveryStorage.countByStatus(DeliveryStatus.approved, branchId: branchId);
    final rejected = await DeliveryStorage.countByStatus(DeliveryStatus.rejected, branchId: branchId);
    
    debugPrint('[DELIV-DASH] Counts: D=$drafts S=$submitted A=$approved R=$rejected');
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
    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: GoogleFonts.plusJakartaSansTextTheme(Theme.of(context).textTheme),
      ),
      child: Scaffold(
      backgroundColor: _bgSlate,
      body: LayoutBuilder(builder: (context, cons) {
        final isWide = cons.maxWidth >= 900;
        if (isWide) {
          return Row(children: [
            _buildSidebar(),
            Expanded(child: _buildMainArea()),
          ]);
        }
        return _buildMobileLayout();
      }),
    ));
  }

  // ═══════════════ SIDEBAR (Wide Screen) ═══════════════
  Widget _buildSidebar() {
    final width = _sidebarCollapsed ? 84.0 : 260.0;
    return Container(
      width: width,
      color: _bgWhite,
      child: Column(children: [
        // ═══ Indigo Gradient Header with Logo ═══
        Container(
          height: 140,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_indigoDeep, _indigoMid, _violet],
            ),
          ),
          child: Center(
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: _bgWhite,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(Icons.shopping_cart, color: _violet, size: 26),
              ),
              if (!_sidebarCollapsed) ...[
                const SizedBox(width: 10),
                const Text('FLAV POS',
                  style: TextStyle(
                    fontFamily: _fontFamily,
                    color: _bgWhite,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ]),
          ),
        ),
        const SizedBox(height: 16),

        // ═══ Sidebar Menu Items ═══
        Expanded(child: SingleChildScrollView(
          child: Column(children: [
            _sidebarItem(
              icon: Icons.local_shipping_outlined,
              label: 'Receive Delivery',
              itemColor: _violet,
              isActive: _selectedModule == 'receive',
              onTap: () => setState(() => _selectedModule = 'receive'),
            ),
            _sidebarItem(
              icon: Icons.description_outlined,
              label: 'Draft',
              badge: _draftCount,
              badgeColor: _violet,
              itemColor: _violet,
              isActive: _selectedModule == 'draft',
              onTap: () => setState(() => _selectedModule = 'draft'),
            ),
            _sidebarItem(
              icon: Icons.send_rounded,
              label: 'Submitted',
              badge: _submittedCount,
              badgeColor: _indigo,
              itemColor: _indigo,
              isActive: _selectedModule == 'submitted',
              onTap: () => setState(() => _selectedModule = 'submitted'),
            ),
            _sidebarItem(
              icon: Icons.check_circle_outline,
              label: 'Approved',
              badge: _approvedCount,
              badgeColor: _success,
              itemColor: _success,
              isActive: _selectedModule == 'approved',
              onTap: () => setState(() => _selectedModule = 'approved'),
            ),
            _sidebarItem(
              icon: Icons.cancel_outlined,
              label: 'Rejected',
              badge: _rejectedCount,
              badgeColor: _error,
              itemColor: _error,
              isActive: _selectedModule == 'rejected',
              onTap: () => setState(() => _selectedModule = 'rejected'),
            ),
          ]),
        )),

        // ═══ Collapse Toggle ═══
        Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: _border)),
          ),
          child: InkWell(
            onTap: () => setState(() => _sidebarCollapsed = !_sidebarCollapsed),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(_sidebarCollapsed ? Icons.chevron_right : Icons.chevron_left,
                    color: _textMuted, size: 20),
                if (!_sidebarCollapsed) ...[
                  const SizedBox(width: 8),
                  const Text('Collapse', style: TextStyle(
                    fontFamily: _fontFamily,
                    color: _textMuted, fontSize: 14, fontWeight: FontWeight.w600)),
                ],
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _sidebarItem({
    required IconData icon,
    required String label,
    int? badge,
    Color badgeColor = _violet,
    required Color itemColor,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: isActive ? _bgIndigo : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: isActive
                ? const Border(left: BorderSide(color: _orange, width: 3))
                : null,
            ),
            child: Row(children: [
              Icon(icon, color: isActive ? itemColor : _textMuted, size: 22),
              if (!_sidebarCollapsed) ...[
                const SizedBox(width: 12),
                Expanded(child: Text(label, style: TextStyle(
                  fontFamily: _fontFamily,
                  color: isActive ? itemColor : _textDark,
                  fontSize: 15,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                ))),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('$badge', style: const TextStyle(
                      fontFamily: _fontFamily,
                      color: _bgWhite,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    )),
                  ),
              ],
            ]),
          ),
        ),
      ),
    );
  }

  // ═══════════════ MAIN AREA ═══════════════
  Widget _buildMainArea() {
    return Column(children: [
      if (!_detailShowing) _buildTopBar(),
      Expanded(child: _buildMainContent()),
      _buildFooter(),
    ]);
  }

  Widget _buildTopBar() {
    String title = 'Dashboard';
    String subtitle = '';
    switch (_selectedModule) {
      case 'receive':
        title = 'Receive Delivery';
        subtitle = 'Manage and track all incoming deliveries';
        break;
      case 'draft':
        title = 'Draft';
        subtitle = 'Deliveries saved as draft';
        break;
      case 'submitted':
        title = 'Submitted';
        subtitle = 'Deliveries awaiting approval';
        break;
      case 'approved':
        title = 'Approved';
        subtitle = 'Deliveries that have been approved';
        break;
      case 'rejected':
        title = 'Rejected';
        subtitle = 'Deliveries that have been rejected';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      color: _bgWhite,
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(
            fontFamily: _fontFamily,
            fontSize: 28, fontWeight: FontWeight.w800, color: _textDark, height: 1.2)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(
            fontFamily: _fontFamily,
            fontSize: 14, color: _textMuted, fontWeight: FontWeight.w500)),
        ])),
        const SizedBox(width: 20),

        // Search Bar
        Container(
          width: 380,
          height: 46,
          decoration: BoxDecoration(
            color: _bgSlate,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: _border),
          ),
          child: Row(children: [
            SizedBox(width: 14),
            Icon(Icons.search, color: _textMuted, size: 20),
            SizedBox(width: 10),
            Expanded(child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Search deliveries...',
                hintStyle: TextStyle(
                  fontFamily: _fontFamily,
                  color: _textMuted, fontSize: 14, fontWeight: FontWeight.w500),
              ),
              style: TextStyle(fontFamily: _fontFamily, fontSize: 14),
            )),
            SizedBox(width: 12),
          ]),
        ),
        const SizedBox(width: 16),

        // Notification Bell
        Stack(children: [
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: _bgSlate,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: _border),
            ),
            child: const Icon(Icons.notifications_none, color: _textDark, size: 22),
          ),
          Positioned(
            top: 9, right: 9,
            child: Container(
              width: 9, height: 9,
              decoration: const BoxDecoration(color: _error, shape: BoxShape.circle),
            ),
          ),
        ]),
        const SizedBox(width: 12),

        // User Avatar
        Container(
          width: 46, height: 46,
          decoration: const BoxDecoration(color: _violet, shape: BoxShape.circle),
          child: const Center(child: Text('JD', style: TextStyle(
            fontFamily: _fontFamily,
            color: _bgWhite, fontSize: 15, fontWeight: FontWeight.w800))),
        ),
      ]),
    );
  }

  Widget _buildMainContent() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    switch (_selectedModule) {
      case 'receive':
        return Navigator(
          key: ValueKey('nav-receive'),
          observers: [_DetailRouteObserver(onPush: () => setState(() => _detailShowing = true), onPop: () => setState(() => _detailShowing = false))],
          onGenerateRoute: (settings) => MaterialPageRoute(
            builder: (_) => ReceiveDeliveryScreen(products: widget.products),
          ),
        );
      case 'draft':
        return Navigator(
          key: ValueKey('nav-draft'),
          observers: [_DetailRouteObserver(onPush: () => setState(() => _detailShowing = true), onPop: () => setState(() => _detailShowing = false))],
          onGenerateRoute: (settings) => MaterialPageRoute(
            builder: (_) => DraftListScreen(products: widget.products, externalSearchQuery: _searchQuery),
          ),
        );
      case 'submitted':
        return Navigator(
          key: ValueKey('nav-submitted'),
          observers: [_DetailRouteObserver(onPush: () => setState(() => _detailShowing = true), onPop: () => setState(() => _detailShowing = false))],
          onGenerateRoute: (settings) => MaterialPageRoute(
            builder: (_) => SubmittedListScreen(products: widget.products, externalSearchQuery: _searchQuery),
          ),
        );
      case 'approved':
        return Navigator(
          key: ValueKey('nav-approved'),
          observers: [_DetailRouteObserver(onPush: () => setState(() => _detailShowing = true), onPop: () => setState(() => _detailShowing = false))],
          onGenerateRoute: (settings) => MaterialPageRoute(
            builder: (_) => ApprovedListScreen(products: widget.products, externalSearchQuery: _searchQuery),
          ),
        );
      case 'rejected':
        return Navigator(
          key: ValueKey('nav-rejected'),
          observers: [_DetailRouteObserver(onPush: () => setState(() => _detailShowing = true), onPop: () => setState(() => _detailShowing = false))],
          onGenerateRoute: (settings) => MaterialPageRoute(
            builder: (_) => RejectedListScreen(products: widget.products, externalSearchQuery: _searchQuery),
          ),
        );
      default: return _buildDashboardCards();
    }
  }

  Widget _buildDashboardCards() {
    return RefreshIndicator(
      onRefresh: _loadCounts,
      child: ListView(padding: const EdgeInsets.all(32), children: [
        _bigCard(
          title: 'Receive Delivery',
          subtitle: 'Manually record and receive incoming deliveries.',
          icon: Icons.local_shipping_outlined,
          iconColor: _orange,
          iconBg: const Color(0xFFFFEDD5),
          isActive: true,
          onTap: _openReceiveDelivery,
        ),
        const SizedBox(height: 14),
        _bigCard(
          title: 'Draft',
          subtitle: 'Save deliveries as draft and continue later.',
          icon: Icons.description_outlined,
          iconColor: _violet,
          iconBg: const Color(0xFFEDE9FE),
          count: _draftCount,
          badgeColor: _violet,
          onTap: () => setState(() => _selectedModule = 'draft'),
        ),
        const SizedBox(height: 14),
        _bigCard(
          title: 'Submitted',
          subtitle: 'View deliveries that are submitted and awaiting approval.',
          icon: Icons.send_rounded,
          iconColor: _indigo,
          iconBg: const Color(0xFFE0E7FF),
          count: _submittedCount,
          badgeColor: _indigo,
          onTap: () => setState(() => _selectedModule = 'submitted'),
        ),
        const SizedBox(height: 14),
        _bigCard(
          title: 'Approved',
          subtitle: 'View all deliveries that have been approved.',
          icon: Icons.check_circle_outline,
          iconColor: _success,
          iconBg: const Color(0xFFDCFCE7),
          count: _approvedCount,
          badgeColor: _success,
          onTap: () => setState(() => _selectedModule = 'approved'),
        ),
        const SizedBox(height: 14),
        _bigCard(
          title: 'Rejected',
          subtitle: 'View all deliveries that have been rejected.',
          icon: Icons.cancel_outlined,
          iconColor: _error,
          iconBg: const Color(0xFFFEE2E2),
          count: _rejectedCount,
          badgeColor: _error,
          onTap: () => setState(() => _selectedModule = 'rejected'),
        ),
      ]),
    );
  }

  Widget _bigCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    int? count,
    Color badgeColor = _violet,
    bool isActive = false,
    required VoidCallback onTap,
  }) {
    return Material(
      color: _bgWhite,
      borderRadius: BorderRadius.circular(14),
      elevation: isActive ? 2 : 0.5,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFFFFFBEB) : _bgWhite,
            borderRadius: BorderRadius.circular(14),
            border: isActive
              ? const Border(left: BorderSide(color: _orange, width: 4))
              : Border.all(color: _border, width: 1),
          ),
          child: Row(children: [
            Container(
              width: 62, height: 62,
              decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(13)),
              child: Icon(icon, color: iconColor, size: 30),
            ),
            const SizedBox(width: 18),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(title, style: const TextStyle(
                  fontFamily: _fontFamily,
                  fontSize: 18, fontWeight: FontWeight.w700, color: _textDark)),
                if (count != null) ...[
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(10)),
                    child: Text('$count', style: const TextStyle(
                      fontFamily: _fontFamily,
                      color: _bgWhite, fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                ],
              ]),
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(
                fontFamily: _fontFamily,
                fontSize: 13, color: _textMuted, fontWeight: FontWeight.w500)),
            ])),
            Icon(Icons.chevron_right, color: iconColor, size: 26),
          ]),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      color: _bgSlate,
      child: Row(children: [
        const Text('© 2024 ', style: TextStyle(
          fontFamily: _fontFamily, color: _textMuted, fontSize: 13, fontWeight: FontWeight.w400)),
        const Text('FLAV POS', style: TextStyle(
          fontFamily: _fontFamily, color: _violet, fontSize: 13, fontWeight: FontWeight.w700)),
        const Text('. All rights reserved.', style: TextStyle(
          fontFamily: _fontFamily, color: _textMuted, fontSize: 13, fontWeight: FontWeight.w400)),
        const Spacer(),
        const Text('Version 1.0.0', style: TextStyle(
          fontFamily: _fontFamily, color: _textMuted, fontSize: 13, fontWeight: FontWeight.w500)),
      ]),
    );
  }

  // ═══════════════ MOBILE LAYOUT ═══════════════
  Widget _buildMobileLayout() {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _violet,
        foregroundColor: _bgWhite,
        title: Row(mainAxisSize: MainAxisSize.min, children: const [
          Icon(Icons.local_shipping_outlined, size: 24),
          SizedBox(width: 8),
          Text('RECEIVE DELIVERY', style: TextStyle(
            fontFamily: _fontFamily,
            fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: 1)),
        ]),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded, size: 22),
            tooltip: 'Refresh', onPressed: _loadCounts),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadCounts,
              child: ListView(padding: const EdgeInsets.all(12), children: [
                _mobileCard('Receive Delivery', 'Manually record and receive incoming deliveries.',
                    Icons.local_shipping_outlined, _orange, const Color(0xFFFFEDD5), null, _openReceiveDelivery),
                const SizedBox(height: 10),
                _mobileCard('Draft', 'Save deliveries as draft and continue later.',
                    Icons.description_outlined, _violet, const Color(0xFFEDE9FE), _draftCount, _openDraftList),
                const SizedBox(height: 10),
                _mobileCard('Submitted', 'View deliveries that are submitted and awaiting approval.',
                    Icons.send_rounded, _indigo, const Color(0xFFE0E7FF), _submittedCount, _openSubmittedList),
                const SizedBox(height: 10),
                _mobileCard('Approved', 'View all deliveries that have been approved.',
                    Icons.check_circle_outline, _success, const Color(0xFFDCFCE7), _approvedCount, _openApprovedList),
                const SizedBox(height: 10),
                _mobileCard('Rejected', 'View all deliveries that have been rejected.',
                    Icons.cancel_outlined, _error, const Color(0xFFFEE2E2), _rejectedCount, _openRejectedList),
              ]),
            ),
    );
  }

  Widget _mobileCard(String title, String subtitle, IconData icon, Color color, Color bg, int? count, VoidCallback onTap) {
    return Material(
      color: _bgWhite,
      borderRadius: BorderRadius.circular(16),
      elevation: 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(width: 56, height: 56,
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: color, size: 28)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(title, style: const TextStyle(
                  fontFamily: _fontFamily,
                  fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black87)),
                if (count != null) ...[
                  const SizedBox(width: 8),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
                    child: Text('$count', style: const TextStyle(
                      fontFamily: _fontFamily,
                      color: _bgWhite, fontSize: 11, fontWeight: FontWeight.w700))),
                ],
              ]),
              const SizedBox(height: 4),
              Text(subtitle, style: TextStyle(
                fontFamily: _fontFamily,
                fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
            ])),
            Icon(Icons.chevron_right, color: color, size: 24),
          ]),
        ),
      ),
    );
  }

  // ═══════════════ NAVIGATION ═══════════════
  void _openReceiveDelivery() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => ReceiveDeliveryScreen(products: widget.products)));
    _loadCounts();
  }
  void _openDraftList() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => DraftListScreen(products: widget.products)));
    _loadCounts();
  }
  void _openSubmittedList() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => SubmittedListScreen(products: widget.products)));
    _loadCounts();
  }
  void _openApprovedList() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => ApprovedListScreen(products: widget.products)));
    _loadCounts();
  }
  void _openRejectedList() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => RejectedListScreen(products: widget.products)));
    _loadCounts();
  }
}
// Custom NavigatorObserver to detect route push/pop
class _DetailRouteObserver extends NavigatorObserver {
  final VoidCallback onPush;
  final VoidCallback onPop;
  _DetailRouteObserver({required this.onPush, required this.onPop});
  @override
  void didPush(Route route, Route? previousRoute) {
    if (previousRoute != null) onPush();
  }
  @override
  void didPop(Route route, Route? previousRoute) {
    onPop();
  }
}
