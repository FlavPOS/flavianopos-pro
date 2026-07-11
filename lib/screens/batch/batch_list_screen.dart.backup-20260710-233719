import 'package:flutter/material.dart';
import '../../services/device_assignment_service.dart';
import '../../models/batch_model.dart';
import 'add_batch_screen.dart';
import 'batch_log_screen.dart';
import '../../utils/approver_pin_dialog.dart';

/// Enterprise Batch List — matches modern SaaS design
/// Green header, status cards, FEFO sort, beautiful batch cards
class BatchListScreen extends StatefulWidget {
  final String? initialFilter;
  const BatchListScreen({super.key, this.initialFilter});

  @override
  State<BatchListScreen> createState() => _BatchListScreenState();
}

class _BatchListScreenState extends State<BatchListScreen> {
  // ═══ ENTERPRISE PALETTE ═══
  static const _teal = Color(0xFF0D9488);       // Header teal
  static const _tealDark = Color(0xFF0F766E);   // Darker teal
  static const _bg = Color(0xFFF9FAFB);         // Off-white bg
  static const _card = Color(0xFFFFFFFF);       // Card white
  static const _border = Color(0xFFE5E7EB);     // Light gray border
  static const _textPrimary = Color(0xFF111827);
  static const _textSecondary = Color(0xFF6B7280);
  static const _textMuted = Color(0xFF9CA3AF);
  
  // Status colors
  static const _greenSoft = Color(0xFF10B981);   // Fresh
  static const _orangeSoft = Color(0xFFF97316);  // Near Expiry
  static const _redSoft = Color(0xFFEF4444);     // Expired
  static const _blueSoft = Color(0xFF3B82F6);    // MFG date
  
  // Backgrounds for icons
  static const _greenBg = Color(0xFFDCFCE7);
  static const _orangeBg = Color(0xFFFED7AA);
  static const _redBg = Color(0xFFFEE2E2);
  static const _blueBg = Color(0xFFDBEAFE);
  static const _tealBg = Color(0xFFCCFBF1);
  
  bool _loading = true;
  String _branchId = '';
  final _searchCtrl = TextEditingController();
  String _query = '';
  String _statusFilter = 'All'; // All | Fresh | Near Expiry | Expired
  
  List<ProductBatch> _allBatches = [];
  
  @override
  void initState() {
    super.initState();
    if (widget.initialFilter != null) {
      _statusFilter = widget.initialFilter!;
    }
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final assign = await DeviceAssignmentService().read();
      _branchId = (assign['branchId'] ?? '').toString();
      await ProductBatch.loadFromDB(branchId: _branchId);
      _allBatches = List.from(ProductBatch.allBatches);
      // Sort by FEFO (nearest expiry first)
      _allBatches.sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
      debugPrint('[BATCH-LIST] Loaded ${_allBatches.length} for branch=$_branchId');
    } catch (e) {
      debugPrint('[BATCH-LIST] Load error: $e');
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  List<ProductBatch> get _filteredBatches {
    var list = _allBatches;
    
    // Status filter
    if (_statusFilter == 'Fresh') {
      list = list.where((b) => b.isFresh && b.quantity > 0).toList();
    } else if (_statusFilter == 'Warning') {
      list = list.where((b) => b.isWarning && b.quantity > 0).toList();
    } else if (_statusFilter == 'Near Expiry') {
      list = list.where((b) => b.isNearExpiry && b.quantity > 0).toList();
    } else if (_statusFilter == 'Expired') {
      list = list.where((b) => b.isExpired).toList();
    } else if (_statusFilter == 'Depleted') {
      list = list.where((b) => b.quantity == 0 && !b.isExpired).toList();
    }
    
    // Search filter
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      list = list.where((b) =>
        b.productName.toLowerCase().contains(q) ||
        b.productSku.toLowerCase().contains(q) ||
        b.batchNumber.toLowerCase().contains(q) ||
        b.lotNumber.toLowerCase().contains(q) ||
        b.supplier.toLowerCase().contains(q)
      ).toList();
    }
    
    return list;
  }

  int get _totalCount => _allBatches.length;
  int get _expiredCount => _allBatches.where((b) => b.isExpired).length;
  int get _nearExpCount => _allBatches.where((b) => b.isNearExpiry && b.quantity > 0).length;
  int get _freshCount => _allBatches.where((b) => (b.isFresh || b.isWarning) && b.quantity > 0).length;

  // ═══ STATUS CARD (top row) ═══
  Widget _buildStatusCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required int count,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? iconColor : _border,
              width: selected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(height: 6),
              Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: iconColor,
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
        ),
      ),
    );
  }

  // ═══ BATCH CARD ═══
  Widget _buildBatchCard(ProductBatch b) {
    // Determine status
    final isExpired = b.isExpired;
    final isNearExp = b.isNearExpiry;
    final isDepleted = b.quantity == 0;
    
    Color statusColor;
    Color statusBg;
    String statusLabel;
    IconData statusIcon;
    Color iconBg;
    Color iconColor;
    
    if (isExpired) {
      statusColor = _redSoft;
      statusBg = _redBg;
      statusLabel = 'EXPIRED';
      statusIcon = Icons.close_rounded;
      iconBg = _redBg;
      iconColor = _redSoft;
    } else if (isNearExp) {
      statusColor = _orangeSoft;
      statusBg = _orangeBg;
      statusLabel = 'NEAR EXP';
      statusIcon = Icons.warning_rounded;
      iconBg = _orangeBg;
      iconColor = _orangeSoft;
    } else if (isDepleted) {
      statusColor = _textMuted;
      statusBg = const Color(0xFFF3F4F6);
      statusLabel = 'DEPLETED';
      statusIcon = Icons.check_circle_outline;
      iconBg = const Color(0xFFF3F4F6);
      iconColor = _textMuted;
    } else {
      statusColor = _greenSoft;
      statusBg = _greenBg;
      statusLabel = 'FRESH';
      statusIcon = Icons.check_rounded;
      iconBg = _greenBg;
      iconColor = _greenSoft;
    }
    
    // Days until expiry text
    String daysText;
    if (isExpired) {
      daysText = 'Expired ${-b.daysUntilExpiry} days ago';
    } else {
      daysText = 'Expires in ${b.daysUntilExpiry} days';
    }
    
    // Progress
    final progress = b.originalQty > 0 ? b.quantity / b.originalQty : 0.0;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: icon, product, status, menu
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(statusIcon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        b.productName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: _textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            '${b.quantity}',
                            style: const TextStyle(fontSize: 12, color: _textSecondary),
                          ),
                          const Text(' | ', style: TextStyle(color: _textMuted, fontSize: 12)),
                          Text(
                            'SKU: ${b.productSku}',
                            style: const TextStyle(fontSize: 12, color: _textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, size: 20, color: _textMuted),
                  onSelected: (val) => _handleMenu(val, b),
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'edit', child: Row(
                      children: [
                        Icon(Icons.edit_rounded, size: 18, color: _textSecondary),
                        SizedBox(width: 8),
                        Text('Edit'),
                      ],
                    )),
                    const PopupMenuItem(value: 'delete', child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded, size: 18, color: _redSoft),
                        SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: _redSoft)),
                      ],
                    )),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            
            // Batch # + Lot # chips
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _bg,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _border),
                    ),
                    child: Text(
                      'Batch #: ${b.batchNumber.isEmpty ? "-" : b.batchNumber}',
                      style: const TextStyle(fontSize: 12, color: _textPrimary, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _bg,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _border),
                    ),
                    child: Text(
                      'Lot #: ${b.lotNumber.isEmpty ? "-" : b.lotNumber}',
                      style: const TextStyle(fontSize: 12, color: _textPrimary, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            
            // MFG + EXP dates row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _blueBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_today_rounded, size: 12, color: _blueSoft),
                      const SizedBox(width: 4),
                      Text(
                        'MFG: ${_fmtDate(b.manufacturedDate)}',
                        style: TextStyle(fontSize: 11, color: _blueSoft, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _greenBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.event_rounded, size: 12, color: _greenSoft),
                      const SizedBox(width: 4),
                      Text(
                        'EXP: ${_fmtDate(b.expiryDate)}',
                        style: TextStyle(fontSize: 11, color: _greenSoft, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  '${b.quantity} / ${b.originalQty} pcs',
                  style: const TextStyle(fontSize: 12, color: _textPrimary, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 3,
                backgroundColor: _bg,
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              ),
            ),
            const SizedBox(height: 6),
            
            // Days until expiry
            Text(
              daysText,
              style: TextStyle(
                fontSize: 11,
                color: statusColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtDate(DateTime d) {
    return '${d.month.toString().padLeft(2, "0")}/${d.day.toString().padLeft(2, "0")}/${d.year}';
  }

  void _handleMenu(String action, ProductBatch b) async {
    if (action == 'edit') {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => AddBatchScreen(batch: b)),
      );
      _load();
    } else if (action == 'delete') {
      // Step 1: Confirm delete
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          icon: const Icon(Icons.warning_amber_rounded, color: _redSoft, size: 48),
          title: const Text('Delete Batch?', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(b.productName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text('Batch: ${b.batchNumber}', style: const TextStyle(fontSize: 12, color: _textSecondary)),
                    if (b.lotNumber.isNotEmpty)
                      Text('Lot: ${b.lotNumber}', style: const TextStyle(fontSize: 12, color: _textSecondary)),
                    const SizedBox(height: 4),
                    Text('Qty: ${b.quantity} pcs', style: const TextStyle(fontSize: 12, color: _textSecondary)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Manager/Supervisor/Admin PIN required to delete.',
                style: TextStyle(fontSize: 12, color: _textSecondary),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: _redSoft, foregroundColor: Colors.white),
              icon: const Icon(Icons.delete_forever_rounded, size: 18),
              label: const Text('Proceed'),
              onPressed: () => Navigator.pop(ctx, true),
            ),
          ],
        ),
      );
      
      if (confirmed != true || !mounted) return;
      
      // Step 2: Manager/Supervisor/Admin PIN required
      final pin = await showApproverPinDialog(
        context,
        themeColor: _redSoft,
        title: 'Verify Authorization',
        subtitle: 'Enter your PIN to delete batch',
        actionLabel: 'Verify & Delete',
      );
      
      if (pin == null || !mounted) return;
      
      // Step 3: Delete
      try {
        ProductBatch.deleteBatch(b.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Row(children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text('Deleted by ${pin['name']}: ${b.batchNumber}')),
            ]),
            backgroundColor: _greenSoft,
            behavior: SnackBarBehavior.floating,
          ));
        }
        _load();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Delete failed: $e'),
            backgroundColor: _redSoft,
            behavior: SnackBarBehavior.floating,
          ));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredBatches;
    
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _teal,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Batch Management',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded),
            tooltip: 'Export',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Export coming soon'), behavior: SnackBarBehavior.floating),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Activity Log',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BatchLogScreen()),
            ),
          ),
        ],
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator(color: _teal))
        : Column(
            children: [
              // ═══ SEARCH BAR ═══
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: _card,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _border),
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _query = v),
                    decoration: const InputDecoration(
                      hintText: 'Search batch, product, supplier...',
                      hintStyle: TextStyle(color: _textMuted, fontSize: 14),
                      prefixIcon: Icon(Icons.search_rounded, color: _textMuted),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              
              // ═══ STATUS CARDS ═══
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    _buildStatusCard(
                      icon: Icons.inventory_2_rounded,
                      iconColor: _tealDark,
                      iconBg: _tealBg,
                      count: _totalCount,
                      label: 'Total',
                      selected: _statusFilter == 'All',
                      onTap: () => setState(() => _statusFilter = 'All'),
                    ),
                    _buildStatusCard(
                      icon: Icons.error_rounded,
                      iconColor: _redSoft,
                      iconBg: _redBg,
                      count: _expiredCount,
                      label: 'Expired',
                      selected: _statusFilter == 'Expired',
                      onTap: () => setState(() => _statusFilter = 'Expired'),
                    ),
                    _buildStatusCard(
                      icon: Icons.warning_rounded,
                      iconColor: _orangeSoft,
                      iconBg: _orangeBg,
                      count: _nearExpCount,
                      label: 'Near Exp',
                      selected: _statusFilter == 'Near Expiry',
                      onTap: () => setState(() => _statusFilter = 'Near Expiry'),
                    ),
                    _buildStatusCard(
                      icon: Icons.check_circle_rounded,
                      iconColor: _greenSoft,
                      iconBg: _greenBg,
                      count: _freshCount,
                      label: 'Fresh',
                      selected: _statusFilter == 'Fresh' || _statusFilter == 'Warning',
                      onTap: () => setState(() => _statusFilter = 'Fresh'),
                    ),
                  ],
                ),
              ),
              
              // ═══ RESULTS COUNT + SORT INDICATOR ═══
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Row(
                  children: [
                    Text(
                      '${filtered.length} batches',
                      style: const TextStyle(fontSize: 13, color: _textSecondary, fontWeight: FontWeight.w500),
                    ),
                    const Spacer(),
                    const Text(
                      'Sorted by: Expiry (FEFO)',
                      style: TextStyle(fontSize: 12, color: _textMuted),
                    ),
                  ],
                ),
              ),
              
              // ═══ BATCH LIST ═══
              Expanded(
                child: filtered.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox_outlined, size: 64, color: _textMuted),
                          SizedBox(height: 12),
                          Text('No batches found', style: TextStyle(fontSize: 15, color: _textSecondary)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: _teal,
                      child: ListView.builder(
                        padding: const EdgeInsets.only(bottom: 80),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) => _buildBatchCard(filtered[i]),
                      ),
                    ),
              ),
            ],
          ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddBatchScreen()),
          );
          _load();
        },
        backgroundColor: _teal,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Batch'),
      ),
    );
  }
}
