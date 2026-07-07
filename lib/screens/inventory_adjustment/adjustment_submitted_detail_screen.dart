import 'package:flutter/material.dart';
import 'adjustment_v3_model.dart';
import 'approver_pin_dialog_v3.dart';
import 'adjustment_pdf_generator.dart';
import '../../helpers/database_helper.dart';
import '../../models/product_model.dart';
import '../../helpers/sync_bridge.dart';
import '../../services/firebase_realtime_service.dart';
import '../../services/device_assignment_service.dart';
import '../../services/firebase_config_service.dart';

class AdjustmentSubmittedDetailScreen extends StatefulWidget {
  final String adjustmentId;
  final String branch;
  final String userName;

  const AdjustmentSubmittedDetailScreen({
    super.key,
    required this.adjustmentId,
    required this.branch,
    required this.userName,
  });

  @override
  State<AdjustmentSubmittedDetailScreen> createState() =>
      _AdjustmentSubmittedDetailScreenState();
}

class _AdjustmentSubmittedDetailScreenState
    extends State<AdjustmentSubmittedDetailScreen> {
  static const _blue = Color(0xFF3B82F6);
  static const _red = Color(0xFFEF4444);
  static const _green = Color(0xFF22C55E);
  static const _bg = Color(0xFFF5F6FA);
  static const _card = Color(0xFFFFFFFF);
  static const _textPrimary = Color(0xFF111827);
  static const _textSecondary = Color(0xFF6B7280);
  static const _divider = Color(0xFFE5E7EB);

  AdjustmentV3? _doc;
  List<AdjustmentV3Item> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final d = await AdjustmentV3Dao.getById(widget.adjustmentId);
    final it = await AdjustmentV3Dao.getItems(widget.adjustmentId);
    if (!mounted) return;
    setState(() {
      _doc = d;
      _items = it;
      _loading = false;
    });
  }

  String _thousands(double v) {
    final parts = v.toStringAsFixed(2).split('.');
    final intPart = parts[0];
    final buf = StringBuffer();
    for (var i = 0; i < intPart.length; i++) {
      if (i > 0 && (intPart.length - i) % 3 == 0) buf.write(',');
      buf.write(intPart[i]);
    }
    return '${buf.toString()}.${parts[1]}';
  }

  int get _totalQty => _items.fold(0, (s, i) => s + i.qty);
  double get _totalCost =>
      _items.fold(0.0, (s, i) => s + (i.qty * i.unitCost * i.direction));

  void _showSnack(String msg, {Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color ?? _blue,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ─── APPROVE — Full SOH wire ────────────────────────────
  Future<void> _approve() async {
    final result = await ApproverPinDialog.show(
      context: context,
      title: 'Approve Adjustment',
      headerColor: _green,
      subtitle: 'This will apply changes to inventory',
      allowedRoles: const ['Supervisor', 'Manager', 'Admin'],
    );
    if (result == null || !mounted) return;

    // Show progress dialog while applying SOH changes
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: _green),
                SizedBox(height: 12),
                Text('Applying to inventory...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final now = DateTime.now().toIso8601String();
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final db = await DatabaseHelper().database;

      // Collect movements for Firebase sync AFTER SQLite commits
      final List<Map<String, dynamic>> movementsForSync = [];

      // ════════════════════════════════════════════════════
      // ATOMIC SQLite Transaction: SOH + Ledger + Status
      // ════════════════════════════════════════════════════
      await db.transaction((txn) async {
        // 1. Update adjustment header to APPROVED
        await txn.update('adjustments_v3', {
          'status': 'APPROVED',
          'approved_at': now,
          'approved_by': result.userName,
          'approved_by_pin': result.userPin,
          'approved_by_role': result.userRole,
          'updated_at': now,
        }, where: 'adjustment_id = ?', whereArgs: [widget.adjustmentId]);

        // 2. FOR EACH ITEM: Update SOH + Write ledger
        for (final item in _items) {
          // Read current SOH — try branch_inventory first, then products
          // Match by ID OR SKU (bulletproof for imported products with different IDs)
          int currentSOH = 0;

          // Try 1: branch_inventory JOIN products by SKU (most reliable)
          var invRows = <Map<String, Object?>>[];
          if (item.sku.isNotEmpty) {
            invRows = await txn.rawQuery('''
              SELECT bi.* FROM branch_inventory bi
              INNER JOIN products p ON bi.productId = p.id
              WHERE bi.branchId = ? AND p.sku = ?
              LIMIT 1
            ''', [widget.branch, item.sku]);
          }

          // Try 2: branch_inventory by direct productId
          if (invRows.isEmpty) {
            invRows = await txn.query(
              'branch_inventory',
              where: 'branchId = ? AND productId = ?',
              whereArgs: [widget.branch, item.productId],
            );
          }

          if (invRows.isNotEmpty) {
            currentSOH = ((invRows.first['stockQty'] as num?) ?? 0).toInt();
          } else {
            // Try 3: products by id
            var prodRows = await txn.query(
              'products',
              where: 'id = ?',
              whereArgs: [item.productId],
              limit: 1,
            );

            // Try 4: products by SKU (bulletproof — SKU is business ID)
            if (prodRows.isEmpty && item.sku.isNotEmpty) {
              prodRows = await txn.query(
                'products',
                where: 'sku = ?',
                whereArgs: [item.sku],
                limit: 1,
              );
            }

            currentSOH = prodRows.isEmpty
                ? 0
                : ((prodRows.first['stockQty'] as num?) ?? 0).toInt();
          }

          debugPrint('[APPROVE] SOH read: ${item.sku}/${item.productId} = $currentSOH');

          final qtyChange = item.qty * item.direction; // signed
          final newSOH = (currentSOH + qtyChange).clamp(0, 999999);
          if (currentSOH + qtyChange < 0) {
            debugPrint('[APPROVE] WARNING: Would go negative for ${item.sku}: $currentSOH + $qtyChange = ${currentSOH + qtyChange}, clamped to 0');
          }

          // Update or insert branch_inventory
          // Get REAL productId from products.sku (bulletproof)
          String realProductId = item.productId;
          if (item.sku.isNotEmpty) {
            final pRows = await txn.query(
              'products',
              columns: ['id'],
              where: 'sku = ?',
              whereArgs: [item.sku],
              limit: 1,
            );
            if (pRows.isNotEmpty) {
              realProductId = (pRows.first['id'] as String?) ?? item.productId;
            }
          }

          if (invRows.isEmpty) {
            await txn.insert('branch_inventory', {
              'branchId': widget.branch,
              'productId': realProductId,
              'stockQty': newSOH,
              'reservedQty': 0,
              'inTransitInQty': 0,
              'inTransitOutQty': 0,
              'reorderLevel': 5,
              'lastUpdated': now,
              'updatedAt': now,
              'deviceId': '',
              'isDeleted': 0,
              'isMigrated': 0,
            });
          } else {
            final existingProductId = (invRows.first['productId'] as String?) ?? realProductId;
            await txn.update('branch_inventory', {
              'stockQty': newSOH,
              'lastUpdated': now,
              'updatedAt': now,
            }, where: 'branchId = ? AND productId = ?',
                whereArgs: [widget.branch, existingProductId]);
          }

          // ⚠️ CAUTION: products.stockQty update disabled.
          // SKU has NO UNIQUE constraint — Excel imports create duplicates
          // and 'WHERE sku=X' would update ALL matching rows.
          // Piattos went from 245 → 635 because of this.
          //
          // Safe approach: only update by exact ID match (no SKU fallback).
          try {
            await txn.update('products', {
              'stockQty': newSOH,
            }, where: 'id = ?', whereArgs: [realProductId]);
            // NOTE: If ID doesn't match, we DON'T fallback to SKU.
            // Refresh will pull correct value from Firebase.
          } catch (_) {}

          // 3. Write to stock_movements (BIR ledger)
          final movementId =
              'MOV-ADJ-${widget.adjustmentId}-${item.itemId ?? _items.indexOf(item)}';

          final movement = {
            'movement_id': movementId,
            'movement_type': 'ADJUSTMENT',
            'sku': item.sku,
            'product_id': item.productId,
            'product_name': item.productName,
            'barcode': '',
            'qty_before': currentSOH.toDouble(),
            'qty_change': qtyChange.toDouble(),
            'qty_after': newSOH.toDouble(),
            'unit_cost': item.unitCost,
            'reason_code': item.reasonCode,
            'reason_note': item.reasonName,
            'reference_no': widget.adjustmentId,
            'batch_no': '',
            'branch_code': widget.branch,
            'branch_name': widget.branch,
            'user_pin': _doc?.createdByPin ?? '',
            'user_name': _doc?.createdByName ?? '',
            'approved_by_pin': result.userPin,
            'approved_by_name': result.userName,
            'local_timestamp': nowMs,
            'sync_status': 'PENDING',
            'z_report_id': '',
            'created_at': now,
            'updated_at': now,
          };

          await txn.insert('stock_movements', movement);
          movementsForSync.add(movement);
        }
      });

      // ════════════════════════════════════════════════════
      // Firebase sync — direct write (bypasses Solo mode guard)
      // ════════════════════════════════════════════════════
      try {
        // Ensure Firebase is initialized
        if (!FirebaseRealtimeService.instance.isInitialized) {
          final cfg = await FirebaseConfigService().load();
          if (cfg != null) {
            await FirebaseRealtimeService.instance.initializeFromManualConfig(cfg);
          }
        }
        final fb = FirebaseRealtimeService.instance.db;
        final assign = await DeviceAssignmentService().read();
        final companyCode = (assign['companyCode'] ?? '').toString();

        if (fb != null && companyCode.isNotEmpty) {
          for (final movement in movementsForSync) {
            final movId = movement['movement_id'] as String;
            final branchCode = movement['branch_code'] as String;
            final productId = movement['product_id'] as String;
            final newSOH = (movement['qty_after'] as num).toInt();

            // 1. Write stock movement (BIR ledger)
            await fb.ref(
              'companies/$companyCode/stockMovements/$branchCode/$movId'
            ).set(movement);

            // 2. Update branchInventory
            await fb.ref(
              'companies/$companyCode/branchInventory/$branchCode/$productId'
            ).update({
              'stockQty': newSOH,
              'lastUpdated': DateTime.now().toIso8601String(),
              'updatedAt': DateTime.now().toIso8601String(),
            });
          }
          debugPrint('[APPROVE] Firebase synced ${movementsForSync.length} movements');
        } else {
          debugPrint('[APPROVE] Firebase skipped: db=NULL or companyCode empty');
        }

        // Backup: also enqueue via SyncBridge (in case Multi-Store mode later)
        for (final movement in movementsForSync) {
          try {
            await SyncBridge.enqueueMovement(movement, op: 'create');
          } catch (_) {}
        }
      } catch (e) {
        debugPrint('[APPROVE] Firebase sync failed: $e');
      }

      if (!mounted) return;
      Navigator.pop(context); // Close progress dialog

      // Reload with APPROVED status (so PDF shows stamp)
      await _load();

      // Refresh Product cache so Inventory module shows new SOH
      try {
        await Product.loadFromDB();
      } catch (_) {}
      if (!mounted) return;

      _showSnack(
        'Approved — ${_items.length} item(s) applied to inventory',
        color: _green,
      );

      // Show print options
      await _showPrintOptions(approverName: result.userName);
      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) Navigator.pop(context); // Close progress dialog if still open
      if (!mounted) return;
      _showSnack('Approve failed: $e', color: _red);
    }
  }

  // ─── PRINT OPTIONS DIALOG ────────────────────────────────
  Future<void> _showPrintOptions({required String approverName}) async {
    await showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Success header
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: _green.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded,
                    color: _green, size: 40),
              ),
              const SizedBox(height: 12),
              const Text(
                'Approved Successfully!',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Approved by: $approverName',
                style: const TextStyle(
                    fontSize: 12, color: _textSecondary),
              ),
              const SizedBox(height: 20),
              const Divider(color: _divider),
              const SizedBox(height: 12),
              const Text(
                'What would you like to do?',
                style: TextStyle(
                    fontSize: 13,
                    color: _textSecondary,
                    fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),

              // Preview
              _buildPrintOption(
                icon: Icons.picture_as_pdf_rounded,
                label: 'Preview PDF',
                subtitle: 'View before printing',
                color: _blue,
                onTap: () async {
                  Navigator.pop(ctx);
                  await _printPdf();
                },
              ),
              const SizedBox(height: 10),

              // Print
              _buildPrintOption(
                icon: Icons.print_rounded,
                label: 'Print',
                subtitle: 'Send to printer',
                color: _green,
                onTap: () async {
                  Navigator.pop(ctx);
                  await _printPdf();
                },
              ),
              const SizedBox(height: 10),

              // Download
              _buildPrintOption(
                icon: Icons.download_rounded,
                label: 'Download PDF',
                subtitle: 'Save to device',
                color: Colors.deepPurple,
                onTap: () async {
                  Navigator.pop(ctx);
                  await _downloadPdf();
                },
              ),
              const SizedBox(height: 16),

              // Later
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Later',
                      style: TextStyle(
                          color: _textSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrintOption({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: color)),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 11, color: _textSecondary)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: color, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _downloadPdf() async {
    if (_doc == null) return;
    try {
      await AdjustmentPdfGenerator.downloadPdf(
        header: _doc!,
        items: _items,
      );
      if (!mounted) return;
      _showSnack('PDF downloaded', color: _green);
    } catch (e) {
      _showSnack('Download failed: $e', color: _red);
    }
  }

  // ─── REJECT ─────────────────────────────────────────────
  Future<void> _reject() async {
    final reasonCtrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.cancel_rounded, color: _red),
            SizedBox(width: 8),
            Text('Reject Adjustment'),
          ],
        ),
        content: TextField(
          controller: reasonCtrl,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: 'Rejection Reason',
            hintText: 'Explain why this adjustment is being rejected',
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              if (reasonCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (result != true || !mounted) return;

    final pin = await ApproverPinDialog.show(
      context: context,
      title: 'Reject Adjustment',
      headerColor: _red,
      subtitle: 'PIN required to confirm rejection',
      allowedRoles: const ['Supervisor', 'Manager', 'Admin'],
    );
    if (pin == null || !mounted) return;

    try {
      await AdjustmentV3Dao.updateStatus(
        adjustmentId: widget.adjustmentId,
        newStatus: AdjustmentStatus.rejected,
        rejectedBy: pin.userName,
        rejectionReason: reasonCtrl.text.trim(),
      );
      if (!mounted) return;
      _showSnack('Rejected by ${pin.userName}', color: _red);
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      _showSnack('Reject failed: $e', color: _red);
    }
  }

  Future<void> _printPdf() async {
    if (_doc == null) return;
    try {
      await AdjustmentPdfGenerator.printPdf(
        header: _doc!,
        items: _items,
      );
    } catch (e) {
      _showSnack('Print failed: $e', color: _red);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _blue,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Submitted',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            if (_doc != null)
              Text(_doc!.docNumber.isEmpty ? _doc!.adjustmentId : _doc!.docNumber,
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w400)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_rounded),
            tooltip: 'Preview PDF',
            onPressed: _printPdf,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildStatusBanner(),
                Expanded(child: _buildList()),
              ],
            ),
      bottomNavigationBar:
          _items.isEmpty || _loading ? null : _buildBottomBar(),
    );
  }

  Widget _buildStatusBanner() {
    return Container(
      color: _blue.withValues(alpha: 0.08),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.access_time_rounded, color: _blue, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('AWAITING APPROVAL',
                    style: TextStyle(
                        color: _blue,
                        fontWeight: FontWeight.bold,
                        fontSize: 12)),
                if (_doc != null)
                  Text('Prepared by ${_doc!.createdByName}',
                      style: const TextStyle(
                          color: _textSecondary, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_items.isEmpty) {
      return const Center(child: Text('No items'));
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: _items.length,
      itemBuilder: (context, index) => _buildItemCard(_items[index]),
    );
  }

  Widget _buildItemCard(AdjustmentV3Item item) {
    final color = item.direction < 0 ? _red : _green;
    final sign = item.direction < 0 ? '-' : '+';
    final cost = item.qty * item.unitCost * item.direction;
    final costSign = cost < 0 ? '-' : (cost > 0 ? '+' : '');
    final costStr = _thousands(cost.abs());

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('$sign${item.qty}',
                    style: TextStyle(
                        color: color,
                        fontSize: 13,
                        fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: RichText(
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    style: const TextStyle(
                        color: _textPrimary, fontSize: 14),
                    children: [
                      TextSpan(
                        text: '${item.sku} ',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, color: _blue),
                      ),
                      TextSpan(
                        text: item.productName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _bg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _divider),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: Text(item.reasonCode,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _textPrimary)),
                ),
                Expanded(
                  child: Text(item.reasonName,
                      style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Cost Impact',
                  style: TextStyle(
                      fontSize: 12,
                      color: _textSecondary,
                      fontWeight: FontWeight.w500)),
              Text('$costSign$costStr',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: color)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildSummaryStrip(),
        Container(
          padding: EdgeInsets.only(
            left: 12,
            right: 12,
            top: 12,
            bottom: MediaQuery.of(context).padding.bottom + 12,
          ),
          decoration: const BoxDecoration(color: _card),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _reject,
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Reject'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _red,
                    side: const BorderSide(color: _red, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _approve,
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Approve'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryStrip() {
    final total = _totalCost;
    final costColor = total == 0
        ? _textPrimary
        : (total < 0 ? _red : _green);
    final sign = total >= 0 ? '+' : '-';
    final costLabel = total == 0 ? '0.00' : '$sign${_thousands(total.abs())}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: _card,
        border: Border(top: BorderSide(color: _divider)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStat(Icons.shopping_bag_outlined, 'Items', '${_items.length}',
              _textPrimary),
          Container(width: 1, height: 30, color: _divider),
          _buildStat(Icons.add_rounded, 'Qty', '$_totalQty pcs', _textPrimary),
          Container(width: 1, height: 30, color: _divider),
          _buildStat(Icons.sell_outlined, 'Cost', costLabel, costColor),
        ],
      ),
    );
  }

  Widget _buildStat(IconData icon, String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: _blue),
            const SizedBox(width: 4),
            Text(label,
                style: const TextStyle(
                    fontSize: 11,
                    color: _textSecondary,
                    fontWeight: FontWeight.w500)),
          ],
        ),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}
