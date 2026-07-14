import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../services/branch_inventory_service.dart';
import '../../services/device_assignment_service.dart';
import '../../services/firebase_realtime_service.dart';
import '../../services/firebase_config_service.dart';
import '../../helpers/database_helper.dart';
import '../inventory_adjustment/approver_pin_dialog_v3.dart';
import 'package:pdf/pdf.dart' as pdf_pkg;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'transfer_v3_model.dart';

/// Submitted Transfer Detail — Approve/Reject actions
class TransferSubmittedDetailScreen extends StatefulWidget {
  final String transferId;
  final String branch;
  final String userName;

  const TransferSubmittedDetailScreen({
    super.key,
    required this.transferId,
    required this.branch,
    required this.userName,
  });

  @override
  State<TransferSubmittedDetailScreen> createState() =>
      _TransferSubmittedDetailScreenState();
}

class _TransferSubmittedDetailScreenState
    extends State<TransferSubmittedDetailScreen> {
  static const _blue = Color(0xFF3B82F6);
  static const _green = Color(0xFF22C55E);
  static const _red = Color(0xFFEF4444);
  static const _bg = Color(0xFFF5F6FA);
  static const _card = Color(0xFFFFFFFF);
  static const _textSecondary = Color(0xFF6B7280);
  static const _divider = Color(0xFFE5E7EB);

  TransferV3? _doc;
  List<TransferV3Item> _items = [];
  Map<String, List<TransferItemBatch>> _batchesByProduct = {};  // v1.0.51
  bool _loading = true;
  bool _actionInProgress = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final d = await TransferV3Dao.getById(widget.transferId);
    final it = await TransferV3Dao.getItems(widget.transferId);
    // v1.0.51 — Load batches
    final allBatches = await TransferV3Dao.getBatches(widget.transferId);
    final batchMap = <String, List<TransferItemBatch>>{};
    for (final b in allBatches) {
      batchMap.putIfAbsent(b.productId, () => []).add(b);
    }
    debugPrint('[SUBMITTED-VIEW] Loaded ${allBatches.length} batches for ${widget.transferId}');
    if (!mounted) return;
    setState(() {
      _doc = d;
      _items = it;
      _batchesByProduct = batchMap;
      _loading = false;
    });
  }

  int get _totalQty => _items.fold(0, (s, i) => s + i.issuedQty);
  double get _totalRetail => _items.fold(0.0, (s, i) => s + (i.issuedQty * i.unitCost));

  void _showSnack(String msg, {Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color ?? _blue,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ─── APPROVE + DISPATCH ─────────────────────────────────
  Future<void> _approveAndDispatch() async {
    if (_actionInProgress) return;
    if (_doc == null) return;
    if (_doc!.status != TransferStatus.submitted) {
      _showSnack('Only submitted transfers can be approved', color: _red);
      return;
    }

    final result = await ApproverPinDialog.show(
      context: context,
      title: 'Approve & Dispatch',
      headerColor: _green,
      subtitle: 'Stock will be deducted from source (In-Transit)',
      allowedRoles: const ['Supervisor', 'Manager', 'Admin'],
    );
    if (result == null || !mounted) return;

    _actionInProgress = true;

    // Progress dialog
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
                Text('Dispatching to destination...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final now = DateTime.now().toIso8601String();
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final assign = await DeviceAssignmentService().read();
      final companyCode = (assign['companyCode'] ?? '').toString();
      final realBranchId = (assign['branchId'] ?? '').toString();

      // ═══ STEP 1: Update status to FLOATING ═══
      await TransferV3Dao.updateStatus(
        transferId: widget.transferId,
        newStatus: TransferStatus.floating,
        extraFields: {
          'approved_by': result.userName,
          'approved_by_pin': result.userPin,
          'approved_by_role': result.userRole,
          'approved_date': now,
          'dispatched_by': result.userName,
          'dispatched_date': now,
          'total_floating_qty': _totalQty,
        },
      );

      // ═══ STEP 2: Deduct source SOH via BranchInventoryService ═══
      int successCount = 0;
      for (final item in _items) {
        final ok = await BranchInventoryService.decrementStock(
          realBranchId,
          item.productId,
          item.issuedQty,
        );
        if (ok) successCount++;
      }

      // ═══ STEP 3: Write stock_movements ledger (TRANSFER_OUT) ═══
      final db = await DatabaseHelper().database;
      for (final item in _items) {
        final currentSOH = await BranchInventoryService.getStock(
            realBranchId, item.productId);
        final movementId =
            'MOV-TRO-${widget.transferId}-${item.itemId ?? _items.indexOf(item)}';

        try {
          await db.insert('stock_movements', {
            'movement_id': movementId,
            'movement_type': 'TRANSFER_OUT',
            'sku': item.sku,
            'product_id': item.productId,
            'product_name': item.productName,
            'barcode': '',
            'qty_before': (currentSOH + item.issuedQty).toDouble(),
            'qty_change': -item.issuedQty.toDouble(),
            'qty_after': currentSOH.toDouble(),
            'unit_cost': item.unitCost,
            'reason_code': 'TRANSFER',
            'reason_note': 'To ${_doc!.receivingBranchId} (${_doc!.receivingBranchName})',
            'reference_no': widget.transferId,
            'batch_no': '',
            'branch_code': realBranchId,
            'branch_name': _doc!.issuingBranchName,
            'user_pin': _doc!.preparedById,
            'user_name': _doc!.preparedBy,
            'approved_by_pin': result.userPin,
            'approved_by_name': result.userName,
            'local_timestamp': nowMs,
            'sync_status': 'SYNCED',
            'z_report_id': '',
            'created_at': now,
            'updated_at': now,
          });

          // Also sync to Firebase stockMovements
          try {
            if (FirebaseRealtimeService.instance.isInitialized) {
              final fb = FirebaseRealtimeService.instance.db;
              if (fb != null && companyCode.isNotEmpty) {
                await fb.ref(
                  'companies/$companyCode/stockMovements/$realBranchId/$movementId'
                ).set({
                  'movement_id': movementId,
                  'movement_type': 'TRANSFER_OUT',
                  'sku': item.sku,
                  'product_id': item.productId,
                  'product_name': item.productName,
                  'qty_before': (currentSOH + item.issuedQty).toDouble(),
                  'qty_change': -item.issuedQty.toDouble(),
                  'qty_after': currentSOH.toDouble(),
                  'reference_no': widget.transferId,
                  'branch_code': realBranchId,
                  'approved_by_name': result.userName,
                  'created_at': now,
                });
              }
            }
          } catch (_) {}
        } catch (e) {
          debugPrint('[TRANSFER-APPROVE] Ledger insert failed: $e');
        }
      }

      // ═══ STEP 4: Write full transfer document to Firebase ═══
      try {
        if (!FirebaseRealtimeService.instance.isInitialized) {
          final cfg = await FirebaseConfigService().load();
          if (cfg != null) {
            await FirebaseRealtimeService.instance.initializeFromManualConfig(cfg);
          }
        }
        final fb = FirebaseRealtimeService.instance.db;

        if (fb != null && companyCode.isNotEmpty) {
          final itemsPayload = _items.map((i) => {
            'productId': i.productId,
            'sku': i.sku,
            'productName': i.productName,
            'issuedQty': i.issuedQty,
            'unitCost': i.unitCost,
          }).toList();

          final docPayload = {
            'transferId': widget.transferId,
            'docNumber': _doc!.docNumber,
            'status': 'FLOATING',
            'issuingBranchId': _doc!.issuingBranchId,
            'issuingBranchName': _doc!.issuingBranchName,
            'receivingBranchId': _doc!.receivingBranchId,
            'receivingBranchName': _doc!.receivingBranchName,
            'preparedBy': _doc!.preparedBy,
            'preparedDate': _doc!.preparedDate,
            'submittedBy': _doc!.submittedBy,
            'submittedDate': _doc!.submittedDate,
            'approvedBy': result.userName,
            'approvedByPin': result.userPin,
            'approvedByRole': result.userRole,
            'approvedDate': now,
            'dispatchedDate': now,
            'totalItems': _items.length,
            'totalIssuedQty': _totalQty,
            'totalFloatingQty': _totalQty,
            'items': itemsPayload,
            'notes': _doc!.notes,
            'updatedAt': now,
          };

          // v1.0.57+108 — Include batches so they're preserved through APPROVE
          final localBatches = await TransferV3Dao.getBatches(widget.transferId);
          final batchesPayload = localBatches.map((b) => {
            'productId': b.productId,
            'batchId': b.batchId,
            'batchNumber': b.batchNumber,
            'lotNumber': b.lotNumber,
            'mfgDate': b.mfgDate.toIso8601String(),
            'expiryDate': b.expiryDate.toIso8601String(),
            'transferQty': b.transferQty,
            'unitCost': b.unitCost,
            'receivedQty': b.receivedQty,
            'postbackQty': b.postbackQty,
            'shortReason': b.shortReason,
            'varianceNotes': b.varianceNotes,
          }).toList();
          docPayload['batches'] = batchesPayload;
          debugPrint('[TRANSFER-APPROVE] Attaching ${batchesPayload.length} batches to Firebase upload');

          // Index for outbound branch (source)
          await fb.ref(
            'companies/$companyCode/interStoreTransfers/${widget.transferId}'
          ).set(docPayload);

          // Index for inbound branch (destination)
          await fb.ref(
            'companies/$companyCode/inboundTransfers/${_doc!.receivingBranchId}/${widget.transferId}'
          ).set(docPayload);

          debugPrint('[TRANSFER-APPROVE] Firebase docs written');
        }
      } catch (e) {
        debugPrint('[TRANSFER-APPROVE] Firebase sync failed: $e');
      }

      if (!mounted) return;
      Navigator.pop(context); // Close progress

      await _load();
      if (!mounted) return;

      _showSnack(
        'Dispatched — $successCount item(s) in-transit to ${_doc?.receivingBranchName}',
        color: _green,
      );

      // Show print options popup
      await _showPrintOptions();
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (!mounted) return;
      _showSnack('Approve failed: $e', color: _red);
    } finally {
      _actionInProgress = false;
    }
  }

  // ─── REJECT ─────────────────────────────────────────────
  Future<void> _reject() async {
    if (_actionInProgress) return;
    if (_doc == null) return;

    final reasonCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.cancel_rounded, color: _red),
            SizedBox(width: 8),
            Text('Reject Transfer'),
          ],
        ),
        content: TextField(
          controller: reasonCtrl,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: 'Rejection Reason',
            hintText: 'Why is this being rejected?',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _red, foregroundColor: Colors.white),
            onPressed: () {
              if (reasonCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final pin = await ApproverPinDialog.show(
      context: context,
      title: 'Reject Transfer',
      headerColor: _red,
      subtitle: 'PIN required to confirm rejection',
      allowedRoles: const ['Supervisor', 'Manager', 'Admin'],
    );
    if (pin == null || !mounted) return;

    _actionInProgress = true;
    try {
      await TransferV3Dao.updateStatus(
        transferId: widget.transferId,
        newStatus: TransferStatus.rejected,
        extraFields: {
          'rejected_by': pin.userName,
          'rejected_date': DateTime.now().toIso8601String(),
          'rejection_reason': reasonCtrl.text.trim(),
        },
      );
      if (!mounted) return;
      _showSnack('Transfer rejected', color: _red);
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      _showSnack('Reject failed: $e', color: _red);
    } finally {
      _actionInProgress = false;
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
            const Text('Submitted Transfer',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            if (_doc != null)
              Text(
                _doc!.docNumber.isEmpty ? _doc!.transferId : _doc!.docNumber,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w400),
              ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildStatusBanner(),
                Expanded(child: _buildList()),
              ],
            ),
      bottomNavigationBar: _items.isEmpty || _loading ? null : _buildBottomBar(),
    );
  }

  Widget _buildStatusBanner() {
    return Container(
      color: _blue.withValues(alpha: 0.08),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.access_time_rounded, color: _blue, size: 18),
              const SizedBox(width: 8),
              const Text('AWAITING APPROVAL',
                  style: TextStyle(
                      color: _blue, fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
          if (_doc != null) ...[
            const SizedBox(height: 6),
            Text('From: ${_doc!.issuingBranchId} (${_doc!.issuingBranchName})',
                style: const TextStyle(color: _textSecondary, fontSize: 11)),
            Text('To: ${_doc!.receivingBranchId} (${_doc!.receivingBranchName})',
                style: const TextStyle(color: _textSecondary, fontSize: 11)),
            Text('Prepared by: ${_doc!.preparedBy}',
                style: const TextStyle(color: _textSecondary, fontSize: 11)),
          ],
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_items.isEmpty) return const Center(child: Text('No items'));
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        final itemBatches = _batchesByProduct[item.productId] ?? [];
        return _SubmittedItemCard(
          productName: item.productName,
          sku: item.sku,
          issuedQty: item.issuedQty,
          productId: item.productId,
          themeColor: _blue,
          batches: itemBatches,
        );
      },
    );
  }

  Widget _buildBottomBar() {
    return SafeArea(
      top: false,
      child: Column(
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
            decoration: BoxDecoration(
              color: _card,
            ),
            child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _actionInProgress ? null : _reject,
                icon: const Icon(Icons.close_rounded),
                label: const Text('Reject'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _red,
                  side: const BorderSide(color: _red, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _actionInProgress ? null : _approveAndDispatch,
                icon: const Icon(Icons.local_shipping_rounded, size: 18),
                label: const Text('Approve & Dispatch'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStrip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: _card,
        border: Border(top: BorderSide(color: _divider)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _summaryStat(Icons.shopping_bag_outlined, 'Items', '${_items.length}'),
          Container(width: 1, height: 26, color: _divider),
          _summaryStat(Icons.add_rounded, 'Qty', '$_totalQty pcs'),
          Container(width: 1, height: 26, color: _divider),
          _summaryStat(Icons.sell_outlined, 'Retail', _totalRetail.toStringAsFixed(2)),
        ],
      ),
    );
  }

  Widget _summaryStat(IconData icon, String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: _blue),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 11, color: _textSecondary)),
          ],
        ),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }

  // ═══ PRINT OPTIONS POPUP ═══
  Future<void> _showPrintOptions() async {
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
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: _green.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.local_shipping_rounded, color: _green, size: 40),
              ),
              const SizedBox(height: 12),
              const Text('Dispatched Successfully!',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('To: ${_doc?.receivingBranchName ?? ""}',
                  style: const TextStyle(fontSize: 12, color: _textSecondary)),
              const SizedBox(height: 20),
              const Divider(color: _divider),
              const SizedBox(height: 12),
              const Text('Print Transfer Slip?',
                  style: TextStyle(fontSize: 13, color: _textSecondary, fontWeight: FontWeight.w500)),
              const SizedBox(height: 16),
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
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Later',
                      style: TextStyle(color: _textSecondary, fontSize: 14, fontWeight: FontWeight.w600)),
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                    Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
                    Text(subtitle, style: const TextStyle(fontSize: 11, color: _textSecondary)),
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

  // ═══ PDF GENERATOR (A4 Landscape) ═══
  Future<Uint8List> _generatePdf() async {
    final pdf = pw.Document();
    // v1.0.58+120 — Grand Total uses batch sums (matches ITEM SUBTOTAL rows)
    // Bug: Was using ri.issuedQty which showed 20 instead of received 18
    // Retail was 4400 instead of 3960
    int totalQty = 0;
    double totalRetail = 0.0;
    for (final ri in _items) {
      final batches = _batchesByProduct[ri.productId] ?? [];
      if (batches.isEmpty) {
        totalQty += ri.issuedQty;
        totalRetail += ri.issuedQty * ri.unitCost;
      } else {
        for (final b in batches) {
          final actualQty = b.receivedQty > 0 ? b.receivedQty : b.transferQty;
          totalQty += actualQty;
          totalRetail += actualQty * b.unitCost;
        }
      }
    }

    final pageFormat = pdf_pkg.PdfPageFormat.a4.landscape;
    const itemsPerPage = 20;
    final totalPages = (_items.length / itemsPerPage).ceil().clamp(1, 999);

    pw.Widget buildCopy({
      required String copyLabel,
      required List<TransferV3Item> pageItems,
      required int currentPage,
      required int totalPagesCount,
    }) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          // Title Row
          pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 6),
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(width: 1.5)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Stock Transfer',
                        style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(width: 8),
                    pw.Text('· ' + (_doc?.status ?? ''),
                        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
                pw.Text(copyLabel,
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, letterSpacing: 1)),
              ],
            ),
          ),
          pw.SizedBox(height: 8),

          // Info Table
          pw.Table(
            border: pw.TableBorder.all(width: 0.5),
            columnWidths: {
              0: const pw.FixedColumnWidth(90),
              1: const pw.FlexColumnWidth(3),
              2: const pw.FixedColumnWidth(90),
              3: const pw.FlexColumnWidth(3),
            },
            children: [
              pw.TableRow(children: [
                _sd4Info('From Branch', bold: true),
                _sd4Info((_doc?.issuingBranchId ?? '') + ' (' + (_doc?.issuingBranchName ?? '') + ')'),
                _sd4Info('Date Created', bold: true),
                _sd4Info(_sd4Date(_doc?.createdAt ?? '')),
              ]),
              pw.TableRow(children: [
                _sd4Info('To Branch', bold: true),
                _sd4Info((_doc?.receivingBranchId ?? '') + ' (' + (_doc?.receivingBranchName ?? '') + ')'),
                _sd4Info('IST No.', bold: true),
                _sd4Info((_doc?.docNumber.isEmpty ?? true) ? (_doc?.transferId ?? '') : (_doc?.docNumber ?? '')),
              ]),
            ],
          ),
          pw.SizedBox(height: 6),

          // Items Table
          pw.Table(
            border: pw.TableBorder.all(width: 0.5),
            columnWidths: {
              0: const pw.FixedColumnWidth(70),
              1: const pw.FlexColumnWidth(3),
              2: const pw.FixedColumnWidth(55),
              3: const pw.FixedColumnWidth(75),
              4: const pw.FixedColumnWidth(85),
            },
            children: [
              pw.TableRow(children: [
                _sd4H('SKU'),
                _sd4H('Product Name'),
                _sd4H('Qty'),
                _sd4H('Unit Retail'),
                _sd4H('Retail Value'),
              ]),
              ...pageItems.expand<pw.TableRow>((item) {
                final batches = _batchesByProduct[item.productId] ?? [];
                final rows = <pw.TableRow>[];

                if (batches.isEmpty) {
                  final retail = item.issuedQty * item.unitCost;
                  rows.add(pw.TableRow(children: [
                    _sd4C(item.sku),
                    _sd4C(item.productName),
                    _sd4CR(item.issuedQty.toString()),
                    _sd4CR(item.unitCost.toStringAsFixed(2)),
                    _sd4CR(retail.toStringAsFixed(2)),
                  ]));
                } else {
                  // Product header row (bold)
                  rows.add(pw.TableRow(children: [
                    _sd4C(item.sku, bold: true),
                    _sd4C(item.productName, bold: true),
                    _sd4C(''),
                    _sd4C(''),
                    _sd4C(''),
                  ]));

                  int itemQty = 0;
                  double itemTotal = 0;
                  for (final b in batches) {
                    final bTotal = b.transferQty * b.unitCost;
                    itemQty += b.transferQty;
                    itemTotal += bTotal;
                    final mfgStr = '${b.mfgDate.year.toString().padLeft(4,'0')}-${b.mfgDate.month.toString().padLeft(2,'0')}-${b.mfgDate.day.toString().padLeft(2,'0')}';
                    final expStr = '${b.expiryDate.year.toString().padLeft(4,'0')}-${b.expiryDate.month.toString().padLeft(2,'0')}-${b.expiryDate.day.toString().padLeft(2,'0')}';
                    final info = '   Batch: ${b.batchNumber}  Lot: ${b.lotNumber}  MFG: $mfgStr  EXP: $expStr';
                    rows.add(pw.TableRow(children: [
                      _sd4C(''),
                      _sd4C(info),
                      _sd4CR(b.transferQty.toString()),
                      _sd4CR(b.unitCost.toStringAsFixed(2)),
                      _sd4CR(bTotal.toStringAsFixed(2)),
                    ]));
                  }

                  // ITEM SUBTOTAL row (light-blue)
                  rows.add(pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: pdf_pkg.PdfColor.fromInt(0xFFE3F2FD),
                    ),
                    children: [
                      _sd4C(''),
                      _sd4C('ITEM SUBTOTAL', bold: true),
                      _sd4CR(itemQty.toString(), bold: true),
                      _sd4CR('-'),
                      _sd4CR(itemTotal.toStringAsFixed(2), bold: true),
                    ],
                  ));
                }
                return rows;
              }),
              if (currentPage == totalPagesCount)
                pw.TableRow(children: [
                  _sd4C(''),
                  _sd4C('Grand Total', bold: true),
                  _sd4CR(totalQty.toString(), bold: true),
                  _sd4C(''),
                  _sd4CR(totalRetail.toStringAsFixed(2), bold: true),
                ]),
              for (int i = 0; i < 6; i++)
                pw.TableRow(children: [
                  _sd4Empty(),
                  _sd4Empty(),
                  _sd4Empty(),
                  _sd4Empty(),
                  _sd4Empty(),
                ]),
            ],
          ),

          if (currentPage != totalPagesCount) ...[
            pw.SizedBox(height: 4),
            pw.Center(
              child: pw.Text('— Continued on next page —',
                  style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic)),
            ),
          ],

          if (currentPage == totalPagesCount) ...[
            pw.Spacer(),
            pw.Row(
              children: [
                pw.Expanded(child: _sd4Sig('Prepared By:', _doc?.preparedBy ?? '')),
                pw.SizedBox(width: 12),
                pw.Expanded(child: _sd4Sig('Approved By:', _doc?.approvedBy ?? '')),
                pw.SizedBox(width: 12),
                pw.Expanded(child: _sd4Sig('Received By:', _doc?.receivedBy ?? '')),
                pw.SizedBox(width: 12),
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                    decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
                    child: pw.Text('Date Received',
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                        textAlign: pw.TextAlign.center),
                  ),
                ),
              ],
            ),
          ],
        ],
      );
    }

    for (int pageNum = 1; pageNum <= totalPages; pageNum++) {
      final startIdx = (pageNum - 1) * itemsPerPage;
      final endIdx = (startIdx + itemsPerPage).clamp(0, _items.length);
      final pageItems = _items.sublist(startIdx, endIdx);

      pdf.addPage(pw.Page(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.all(20),
        build: (context) => buildCopy(
          copyLabel: 'ISSUING STORE COPY',
          pageItems: pageItems,
          currentPage: pageNum,
          totalPagesCount: totalPages,
        ),
      ));

      pdf.addPage(pw.Page(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.all(20),
        build: (context) => buildCopy(
          copyLabel: 'RECEIVING STORE COPY',
          pageItems: pageItems,
          currentPage: pageNum,
          totalPagesCount: totalPages,
        ),
      ));
    }

    return pdf.save();
  }

  static pw.Widget _sd4Info(String text, {bool bold = false}) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 8),
    child: pw.Text(text, style: pw.TextStyle(
      fontSize: 10,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    )),
  );

  static pw.Widget _sd4H(String text) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 8),
    alignment: pw.Alignment.center,
    child: pw.Text(text, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
  );

  static pw.Widget _sd4C(String text, {bool bold = false}) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
    child: pw.Text(text, style: pw.TextStyle(
      fontSize: 10,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    )),
  );

  static pw.Widget _sd4CR(String text, {bool bold = false}) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
    alignment: pw.Alignment.centerRight,
    child: pw.Text(text, style: pw.TextStyle(
      fontSize: 10,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    )),
  );

  static pw.Widget _sd4Empty() => pw.Container(
    padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 8),
    child: pw.Text(' ', style: const pw.TextStyle(fontSize: 10)),
  );

  static pw.Widget _sd4Sig(String label, String name) => pw.Container(
    padding: const pw.EdgeInsets.only(top: 4),
    decoration: const pw.BoxDecoration(
      border: pw.Border(top: pw.BorderSide(width: 0.6)),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 2),
        pw.Text(name.isEmpty ? '________________' : name,
            style: const pw.TextStyle(fontSize: 10)),
      ],
    ),
  );

  static String _sd4Date(String iso) {
    if (iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso);
      return '${dt.year}-${dt.month.toString().padLeft(2, "0")}-${dt.day.toString().padLeft(2, "0")}';
    } catch (_) {
      return iso;
    }
  }

  static pw.Widget _hCell(String text) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 5),
    alignment: pw.Alignment.center,
    child: pw.Text(text, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
  );

  static pw.Widget _cell(String text) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 5),
    child: pw.Text(text, style: const pw.TextStyle(fontSize: 9)),
  );

  static pw.Widget _cellR(String text) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 5),
    alignment: pw.Alignment.centerRight,
    child: pw.Text(text, style: const pw.TextStyle(fontSize: 9)),
  );

  static pw.Widget _sigBlock(String label, String name, {String role = ''}) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Container(
        height: 20,
        decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(width: 0.5)),
        ),
      ),
      pw.SizedBox(height: 2),
      pw.Text(label, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
      pw.Text(name.isEmpty ? '_________________' : name,
          style: const pw.TextStyle(fontSize: 9)),
      if (role.isNotEmpty)
        pw.Text('($role)', style: const pw.TextStyle(fontSize: 8)),
    ],
  );

  Future<void> _printPdf() async {
    try {
      final bytes = await _generatePdf();
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    } catch (e) {
      _showSnack('Print failed: $e', color: _red);
    }
  }

  Future<void> _downloadPdf() async {
    try {
      final bytes = await _generatePdf();
      final docNum = _doc!.docNumber.isEmpty ? _doc!.transferId : _doc!.docNumber;
      await Printing.sharePdf(bytes: bytes, filename: 'IST-$docNum.pdf');
      _showSnack('PDF downloaded', color: _green);
    } catch (e) {
      _showSnack('Download failed: $e', color: _red);
    }
  }

}

// v1.0.51 — Expandable item card with batch display
class _SubmittedItemCard extends StatefulWidget {
  final String productName;
  final String sku;
  final String productId;
  final int issuedQty;
  final Color themeColor;
  final List<TransferItemBatch> batches;

  const _SubmittedItemCard({
    required this.productName,
    required this.sku,
    required this.productId,
    required this.issuedQty,
    required this.themeColor,
    required this.batches,
  });

  @override
  State<_SubmittedItemCard> createState() => _SubmittedItemCardState();
}

class _SubmittedItemCardState extends State<_SubmittedItemCard> {
  static const _card = Color(0xFFFFFFFF);
  static const _textSecondary = Color(0xFF6B7280);
  bool _expanded = false;

  Future<void> _showBatchesPopup(BuildContext ctx0) async {
    await showDialog(
      context: ctx0,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 500, maxHeight: MediaQuery.of(ctx).size.height * 0.8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: widget.themeColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
              child: Row(children: [
                const Icon(Icons.qr_code_2, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.productName, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text('SKU: ${widget.sku}', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                ])),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('${widget.issuedQty}', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  const Text('pcs', style: TextStyle(color: Colors.white70, fontSize: 10)),
                ]),
                const SizedBox(width: 6),
                IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(ctx)),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(color: widget.themeColor.withValues(alpha: 0.08), border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
              child: Row(children: [
                Icon(Icons.inventory_2, size: 16, color: widget.themeColor),
                const SizedBox(width: 8),
                Text('${widget.batches.length} ${widget.batches.length == 1 ? "batch" : "batches"} selected', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: widget.themeColor)),
              ]),
            ),
            Flexible(child: ListView.builder(
              padding: const EdgeInsets.all(12),
              shrinkWrap: true,
              itemCount: widget.batches.length,
              itemBuilder: (context, i) {
                final b = widget.batches[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: widget.themeColor.withValues(alpha: 0.2))),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: widget.themeColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)), child: Icon(Icons.qr_code_2, size: 14, color: widget.themeColor)),
                      const SizedBox(width: 8),
                      Expanded(child: Text('Batch #${b.batchNumber}${b.lotNumber.isNotEmpty ? " · Lot #${b.lotNumber}" : ""}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
                    ]),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: Builder(builder: (_) {
                        // v1.0.57 — Variance-aware display: show receivedQty if variance recorded
                        final hasVariance = b.receivedQty != b.transferQty || b.shortReason.isNotEmpty;
                        final displayQty = hasVariance ? b.receivedQty : b.transferQty;
                        final variance = b.receivedQty - b.transferQty;
                        final varColor = variance < 0
                            ? const Color(0xFFF59E0B)  // yellow (short)
                            : variance > 0
                                ? const Color(0xFF3B82F6)  // blue (overage)
                                : widget.themeColor;
                        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('Received', style: TextStyle(fontSize: 10, color: _textSecondary)),
                          Text('$displayQty pcs', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: varColor)),
                          if (hasVariance) Text(
                            variance < 0
                                ? 'Issued ${b.transferQty} · Short ${-variance}${b.shortReason.isNotEmpty ? " · ${b.shortReason}" : ""}'
                                : variance > 0
                                    ? 'Issued ${b.transferQty} · +$variance${b.shortReason.isNotEmpty ? " · ${b.shortReason}" : ""}'
                                    : 'Issued ${b.transferQty}',
                            style: TextStyle(fontSize: 9, color: varColor, fontWeight: FontWeight.w600),
                          ),
                        ]);
                      })),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('MFG', style: TextStyle(fontSize: 10, color: _textSecondary)),
                        Text('${b.mfgDate.year}-${b.mfgDate.month.toString().padLeft(2, '0')}-${b.mfgDate.day.toString().padLeft(2, '0')}', style: const TextStyle(fontSize: 13)),
                      ])),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('EXP', style: TextStyle(fontSize: 10, color: _textSecondary)),
                        Text('${b.expiryDate.year}-${b.expiryDate.month.toString().padLeft(2, '0')}-${b.expiryDate.day.toString().padLeft(2, '0')}', style: const TextStyle(fontSize: 13)),
                      ])),
                    ]),
                  ]),
                );
              },
            )),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasBatches = widget.batches.isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: hasBatches ? () => setState(() => _expanded = !_expanded) : null,
          onLongPress: hasBatches ? () => _showBatchesPopup(context) : null,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.productName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('SKU: ${widget.sku}', style: const TextStyle(color: _textSecondary, fontSize: 12)),
              ])),
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: widget.themeColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                  child: Text('${widget.issuedQty}', style: TextStyle(color: widget.themeColor, fontSize: 15, fontWeight: FontWeight.bold)),
                ),
                const Text('pcs', style: TextStyle(color: _textSecondary, fontSize: 10)),
              ]),
              if (hasBatches) ...[
                const SizedBox(width: 6),
                Icon(_expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: widget.themeColor),
              ],
            ]),
          ),
        ),
        if (_expanded && hasBatches) Container(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Column(children: widget.batches.map((b) => Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.qr_code_2, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Expanded(child: Text('Batch #${b.batchNumber}${b.lotNumber.isNotEmpty ? " · Lot #${b.lotNumber}" : ""}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
              ]),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(child: Builder(builder: (_) {
                  // v1.0.57 — Variance-aware display
                  final hasVariance = b.receivedQty != b.transferQty || b.shortReason.isNotEmpty;
                  final displayQty = hasVariance ? b.receivedQty : b.transferQty;
                  final variance = b.receivedQty - b.transferQty;
                  final varColor = variance < 0
                      ? const Color(0xFFF59E0B)
                      : variance > 0
                          ? const Color(0xFF3B82F6)
                          : widget.themeColor;
                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Received', style: TextStyle(fontSize: 10, color: _textSecondary)),
                    Text('$displayQty pcs', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: varColor)),
                    if (hasVariance) Text(
                      variance < 0
                          ? 'Issued ${b.transferQty} · Short ${-variance}${b.shortReason.isNotEmpty ? " · ${b.shortReason}" : ""}'
                          : variance > 0
                              ? 'Issued ${b.transferQty} · +$variance${b.shortReason.isNotEmpty ? " · ${b.shortReason}" : ""}'
                              : 'Issued ${b.transferQty}',
                      style: TextStyle(fontSize: 9, color: varColor, fontWeight: FontWeight.w600),
                    ),
                  ]);
                })),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('MFG', style: TextStyle(fontSize: 10, color: _textSecondary)),
                  Text('${b.mfgDate.year}-${b.mfgDate.month.toString().padLeft(2, '0')}-${b.mfgDate.day.toString().padLeft(2, '0')}', style: const TextStyle(fontSize: 12)),
                ])),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('EXP', style: TextStyle(fontSize: 10, color: _textSecondary)),
                  Text('${b.expiryDate.year}-${b.expiryDate.month.toString().padLeft(2, '0')}-${b.expiryDate.day.toString().padLeft(2, '0')}', style: const TextStyle(fontSize: 12)),
                ])),
              ]),
            ]),
          )).toList()),
        ),
      ]),
    );
  }
}

