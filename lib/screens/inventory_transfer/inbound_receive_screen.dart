import 'package:flutter/material.dart';
import '../../services/branch_inventory_service.dart';
import '../../services/device_assignment_service.dart';
import '../../services/device_id_service.dart'; // v1.0.58+115
import '../../services/firebase_realtime_service.dart';
import '../../services/firebase_config_service.dart';
import '../../helpers/database_helper.dart';
import '../inventory_adjustment/approver_pin_dialog_v3.dart';
import 'dart:typed_data';
import 'package:pdf/pdf.dart' as pdf_pkg;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'transfer_v3_model.dart';
import '../../models/batch_model.dart'; // v1.0.56 — ProductBatch integration

class InboundReceiveScreen extends StatefulWidget {
  final String transferId;
  final String branch;
  final String userName;

  const InboundReceiveScreen({
    super.key,
    required this.transferId,
    required this.branch,
    required this.userName,
  });

  @override
  State<InboundReceiveScreen> createState() => _InboundReceiveScreenState();
}

class _InboundReceiveScreenState extends State<InboundReceiveScreen> {
  static const _amber = Color(0xFFF59E0B);
  static const _green = Color(0xFF22C55E);
  static const _yellow = Color(0xFFEAB308);
  static const _red = Color(0xFFEF4444);
  static const _bg = Color(0xFFF5F6FA);
  static const _card = Color(0xFFFFFFFF);
  static const _textPrimary = Color(0xFF111827);
  static const _textSecondary = Color(0xFF6B7280);
  static const _divider = Color(0xFFE5E7EB);

  TransferV3? _doc;
  final List<_ReceiveItem> _items = [];
  Map<String, List<TransferItemBatch>> _batchesByProduct = {}; // v1.0.54 — batches for PDF
  bool _loading = true;
  bool _actionInProgress = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final item in _items) {
      item.receivedCtrl.dispose();
      for (final rb in item.batches) {         // v1.0.56/57
        rb.qtyCtrl.dispose();
        rb.notesCtrl.dispose();
      }
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final d = await TransferV3Dao.getById(widget.transferId);
    final it = await TransferV3Dao.getItems(widget.transferId);
    // v1.0.54 — Load batches for PDF batch list
    final allBatches = await TransferV3Dao.getBatches(widget.transferId);
    final batchMap = <String, List<TransferItemBatch>>{};
    for (final b in allBatches) {
      batchMap.putIfAbsent(b.productId, () => []).add(b);
    }
    debugPrint('[INBOUND-RECEIVE] Loaded ${allBatches.length} batches for ${widget.transferId}');
    if (!mounted) return;

    _items.clear();
    for (final item in it) {
      // v1.0.56 — Build per-batch inputs
      final itemBatches = batchMap[item.productId] ?? [];
      final receiveBatches = itemBatches.map((b) => _ReceiveBatch(source: b)).toList();
      // v1.0.57+108 — For PARTIAL re-open, use previous received qty; else default to issued
      final isReopening = d?.status == TransferStatus.partiallyReceived;
      final initialQty = isReopening
          ? (item.receivedQty > 0 ? item.receivedQty : item.issuedQty)
          : item.issuedQty;
      _items.add(_ReceiveItem(
        item: item,
        receivedCtrl: TextEditingController(text: initialQty.toString()),
        receivedQty: initialQty,
        batches: receiveBatches,
      ));
    }

    setState(() {
      _doc = d;
      _batchesByProduct = batchMap;
      _loading = false;
    });
  }

  int get _totalIssued => _items.fold(0, (s, i) => s + i.item.issuedQty);
  int get _totalReceived => _items.fold(0, (s, i) => s + i.receivedQty);
  int get _totalShort => _totalIssued - _totalReceived;
  bool get _hasVariance => _totalShort > 0;

  // v1.0.57 — Check all short/overage batches have reasons
  bool get _allBatchesHaveReasons {
    for (final ri in _items) {
      for (final rb in ri.batches) {
        if (rb.needsReason && !rb.hasReason) return false;
      }
    }
    return true;
  }
  bool get _allRejected => _totalReceived == 0;

  void _showSnack(String msg, {Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color ?? _green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _confirmReceipt() async {
    if (_actionInProgress) return;
    // v1.0.57+108 — Allow overage (Phase 2A supports it with reason picker)
    for (final item in _items) {
      if (item.receivedQty < 0) {
        _showSnack('Invalid received qty for ${item.item.productName}', color: _red);
        return;
      }
    }
    if (_allRejected) {
      _showSnack('If receiving nothing, use Reject instead', color: _red);
      return;
    }

    final result = await ApproverPinDialog.show(
      context: context,
      // v1.0.57+108 — Same title regardless of variance (variance captured via Phase 2A)
      title: _hasVariance ? 'Confirm with Variance' : 'Confirm Full Receipt',
      headerColor: _hasVariance ? _yellow : _green,
      subtitle: _hasVariance
          ? 'Stock will be added with variance reasons recorded'
          : 'Stock will be added to your branch',
      allowedRoles: const ['Supervisor', 'Manager', 'Admin'],
    );
    if (result == null || !mounted) return;

    _actionInProgress = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: _hasVariance ? _yellow : _green),
                const SizedBox(height: 12),
                const Text('Receiving into inventory...'),
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

      // v1.0.57+108 — Variance is captured via Phase 2A reasons + Phase 2B postback
      // Confirm Partial closes the transfer as RECEIVED with variance recorded per batch
      // (Was: stuck at PARTIALLY_RECEIVED with no way to close)
      final newStatus = TransferStatus.received;

      await TransferV3Dao.updateStatus(
        transferId: widget.transferId,
        newStatus: newStatus,
        extraFields: {
          'received_by': result.userName,
          'received_by_pin': result.userPin,
          'received_date': now,
          'total_received_qty': _totalReceived,
          'total_short_qty': _totalShort,
        },
      );

      for (final ri in _items) {
        if (ri.item.itemId != null) {
          await TransferV3Dao.updateItemReceived(
            transferId: widget.transferId,
            itemId: ri.item.itemId!,
            receivedQty: ri.receivedQty,
            shortQty: ri.item.issuedQty - ri.receivedQty,
            varianceReason: '',
          );
        }
      }

      int successCount = 0;
      for (final ri in _items) {
        if (ri.receivedQty > 0) {
          final ok = await BranchInventoryService.incrementStock(
            realBranchId,
            ri.item.productId,
            ri.receivedQty,
          );
          if (ok) successCount++;
        }
      }

      // v1.0.56 — Save per-batch receivedQty + merge into ProductBatch (Batch Management)
      int batchesSaved = 0;
      int batchesCreated = 0;
      for (final ri in _items) {
        for (final rb in ri.batches) {
          if (rb.receivedQty <= 0) continue;

          // 1. Update transfer_item_batches.receivedQty + variance reason (v1.0.57)
          if (rb.source.id != null) {
            try {
              await TransferV3Dao.updateBatchReceivedQty(
                batchTableId: rb.source.id!,
                receivedQty: rb.receivedQty,
              );
              // v1.0.57 — Also save reason + notes
              final db = await DatabaseHelper().database;
              await db.update(
                'transfer_item_batches',
                {
                  'shortReason': rb.reason,
                  'varianceNotes': rb.notesCtrl.text.trim(),
                },
                where: 'id = ?',
                whereArgs: [rb.source.id],
              );
              if (rb.reason.isNotEmpty) {
                debugPrint('[INBOUND-BATCH] Variance: ${rb.reason} qty=${rb.variance} notes="${rb.notesCtrl.text.trim()}"');
              }
            } catch (e) {
              debugPrint('[INBOUND-BATCH] updateBatchReceivedQty failed: $e');
            }
          }

          // 2. Merge into ProductBatch (local branch inventory)
          try {
            final existing = await ProductBatch.findExistingBatch(
              productId: rb.source.productId,
              batchNumber: rb.source.batchNumber,
              lotNumber: rb.source.lotNumber,
              branchId: realBranchId,
            );

            if (existing != null) {
              await ProductBatch.addQuantityToBatch(existing.id, rb.receivedQty);
              batchesSaved++;
              debugPrint('[INBOUND-BATCH] Merged +${rb.receivedQty} → existing ${existing.id}');
            } else {
              final newBatchId = 'BATCH-${DateTime.now().millisecondsSinceEpoch}-${rb.source.batchId}';
              final newBatch = ProductBatch(
                id: newBatchId,
                productId: rb.source.productId,
                productName: ri.item.productName,
                productSku: ri.item.sku,
                batchNumber: rb.source.batchNumber,
                lotNumber: rb.source.lotNumber,
                manufacturedDate: rb.source.mfgDate,
                expiryDate: rb.source.expiryDate,
                quantity: rb.receivedQty,
                originalQty: rb.receivedQty,
                costPrice: rb.source.unitCost,
                branchId: realBranchId,
                branchName: _doc?.receivingBranchName ?? '',
                source: 'TRANSFER_IN',
                sourceDocId: widget.transferId,
                notes: 'IST-${_doc?.docNumber ?? widget.transferId}',
                dateAdded: DateTime.now(),
              );
              ProductBatch.addBatch(newBatch); // static void — auto-syncs via SyncBridge
              batchesCreated++;
              debugPrint('[INBOUND-BATCH] Created new $newBatchId qty=${rb.receivedQty}');
            }
          } catch (e) {
            debugPrint('[INBOUND-BATCH] ProductBatch merge/create failed: $e');
          }
        }
      }
      debugPrint('[INBOUND-BATCH] Summary: $batchesSaved merged, $batchesCreated created');

      // v1.0.58+112 — POSTBACK LOGIC (Phase 2B)
      // Return RETURN-reasoned short qtys back to issuing branch inventory
      int postbacksCreated = 0;
      final issuerBranchId = _doc?.issuingBranchId ?? '';
      final issuerBranchName = _doc?.issuingBranchName ?? '';

      if (issuerBranchId.isNotEmpty) {
        for (final ri in _items) {
          for (final rb in ri.batches) {
            // v1.0.58+113 — Postback ALL shorts (reason kept for audit trail)
            // Business logic: sender books say N left warehouse, receiver got M,
            // difference must be reconciled — reason is WHY (audit only)
            if (!rb.hasShort) continue;

            final postbackAmount = rb.short;

            try {
              // 1. Update transfer_item_batches.postbackQty
              if (rb.source.id != null) {
                final db = await DatabaseHelper().database;
                await db.update(
                  'transfer_item_batches',
                  {'postbackQty': postbackAmount},
                  where: 'id = ?',
                  whereArgs: [rb.source.id],
                );
              }

              // 2. Merge into ISSUER's ProductBatch (find or create)
              final existingAtIssuer = await ProductBatch.findExistingBatch(
                productId: rb.source.productId,
                batchNumber: rb.source.batchNumber,
                lotNumber: rb.source.lotNumber,
                branchId: issuerBranchId,
              );

              if (existingAtIssuer != null) {
                await ProductBatch.addQuantityToBatch(existingAtIssuer.id, postbackAmount);
                debugPrint('[POSTBACK] Returned +$postbackAmount to $issuerBranchId batch ${existingAtIssuer.id}');
              } else {
                final postbackBatchId = 'POSTBACK-${DateTime.now().millisecondsSinceEpoch}-${rb.source.batchId}';
                final postbackBatch = ProductBatch(
                  id: postbackBatchId,
                  productId: rb.source.productId,
                  productName: ri.item.productName,
                  productSku: ri.item.sku,
                  batchNumber: rb.source.batchNumber,
                  lotNumber: rb.source.lotNumber,
                  manufacturedDate: rb.source.mfgDate,
                  expiryDate: rb.source.expiryDate,
                  quantity: postbackAmount,
                  originalQty: postbackAmount,
                  costPrice: rb.source.unitCost,
                  branchId: issuerBranchId,
                  branchName: issuerBranchName,
                  source: 'POSTBACK',
                  sourceDocId: widget.transferId,
                  notes: 'Postback from $realBranchId (${_doc?.receivingBranchName ?? ""}) IST-${_doc?.docNumber ?? widget.transferId}',
                  dateAdded: DateTime.now(),
                );
                ProductBatch.addBatch(postbackBatch);
                debugPrint('[POSTBACK] Created new $postbackBatchId at $issuerBranchId qty=$postbackAmount');
              }

              // 3. v1.0.58+115 — Firebase-safe CROSS-BRANCH SOH with .set() to trigger onChildChanged
              // v113 used .update() which doesn't reliably trigger listeners.
              // v115 uses .set() with full payload + deviceId to properly notify other branches.
              try {
                final fb = FirebaseRealtimeService.instance.db;
                if (fb != null && companyCode.isNotEmpty) {
                  final sohPath = 'companies/$companyCode/branchInventory/$issuerBranchId/${rb.source.productId}';
                  final snap = await fb.ref(sohPath).get();
                  Map<String, dynamic> existingData = {};
                  if (snap.exists && snap.value is Map) {
                    existingData = (snap.value as Map).map((k, v) => MapEntry(k.toString(), v));
                  }
                  final currentSOH = (existingData['stockQty'] as num?)?.toInt() ?? 0;
                  final newSOH = currentSOH + postbackAmount;
                  final myDeviceId = await DeviceIdService().getOrCreate();
                  final nowIso = DateTime.now().toUtc().toIso8601String();
                  // Build FULL payload (preserve existing fields + update stockQty)
                  final fullPayload = <String, dynamic>{
                    ...existingData,
                    'branchId': issuerBranchId,
                    'productId': rb.source.productId,
                    'stockQty': newSOH,
                    'updatedAt': nowIso,
                    'lastUpdated': nowIso,
                    'deviceId': myDeviceId,
                    'isMigrated': existingData['isMigrated'] ?? true,
                  };
                  // Use .set() instead of .update() to trigger onChildChanged listener
                  await fb.ref(sohPath).set(fullPayload);
                  debugPrint('[POSTBACK-SOH] $issuerBranchId/${rb.source.productId}: $currentSOH + $postbackAmount = $newSOH (Firebase-safe, .set())');
                } else {
                  debugPrint('[POSTBACK-SOH] Firebase not available, SKIPPING SOH update for $issuerBranchId');
                }
              } catch (e) {
                debugPrint('[POSTBACK-SOH] Firebase update failed: $e');
              }

              // 4. Log to stock_movements at ISSUER's branch (BIR audit)
              try {
                final db = await DatabaseHelper().database;
                final postbackMovId = 'MOV-POSTBACK-${widget.transferId}-${rb.source.batchId}';
                await db.insert('stock_movements', {
                  'movement_id': postbackMovId,
                  'movement_type': 'POSTBACK_IN',
                  'sku': ri.item.sku,
                  'product_id': rb.source.productId,
                  'product_name': ri.item.productName,
                  'barcode': '',
                  'qty_before': 0,
                  'qty_change': postbackAmount.toDouble(),
                  'qty_after': 0,
                  'unit_cost': rb.source.unitCost,
                  'reason_code': 'POSTBACK',
                  'reason_note': 'Returned from $realBranchId (${_doc?.receivingBranchName ?? ""}) IST-${_doc?.docNumber ?? ""}',
                  'reference_no': widget.transferId,
                  'batch_no': rb.source.batchNumber,
                  'branch_code': issuerBranchId,
                  'branch_name': issuerBranchName,
                  'user_pin': result.userPin,
                  'user_name': result.userName,
                  'approved_by_pin': result.userPin,
                  'approved_by_name': result.userName,
                  'local_timestamp': nowMs,
                  'sync_status': 'SYNCED',
                  'z_report_id': '',
                  'created_at': now,
                  'updated_at': now,
                });
              } catch (e) {
                debugPrint('[POSTBACK] Ledger insert failed: $e');
              }

              postbacksCreated++;
            } catch (e) {
              debugPrint('[POSTBACK] Failed for batch ${rb.source.batchNumber}: $e');
            }
          }
        }
        if (postbacksCreated > 0) {
          debugPrint('[POSTBACK] Summary: $postbacksCreated batches returned to $issuerBranchId');
        }
      }

      // v1.0.57+111 — Reload updated batches for Firebase sync (variance-aware)
      List<Map<String, dynamic>> batchesPayload = [];
      try {
        final updatedBatches = await TransferV3Dao.getBatches(widget.transferId);
        batchesPayload = updatedBatches.map((b) => {
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
        debugPrint('[INBOUND-RECEIVE] Reloaded ${batchesPayload.length} batches for Firebase sync');
      } catch (e) {
        debugPrint('[INBOUND-RECEIVE] Batch reload failed: $e');
      }

      final db = await DatabaseHelper().database;
      for (final ri in _items) {
        if (ri.receivedQty <= 0) continue;
        final currentSOH = await BranchInventoryService.getStock(
            realBranchId, ri.item.productId);
        final movementId =
            'MOV-TRI-${widget.transferId}-${ri.item.itemId ?? _items.indexOf(ri)}';

        try {
          await db.insert('stock_movements', {
            'movement_id': movementId,
            'movement_type': 'TRANSFER_IN',
            'sku': ri.item.sku,
            'product_id': ri.item.productId,
            'product_name': ri.item.productName,
            'barcode': '',
            'qty_before': (currentSOH - ri.receivedQty).toDouble(),
            'qty_change': ri.receivedQty.toDouble(),
            'qty_after': currentSOH.toDouble(),
            'unit_cost': ri.item.unitCost,
            'reason_code': 'TRANSFER',
            'reason_note': 'From ${_doc!.issuingBranchId} (${_doc!.issuingBranchName})',
            'reference_no': widget.transferId,
            'batch_no': '',
            'branch_code': realBranchId,
            'branch_name': _doc!.receivingBranchName,
            'user_pin': '',
            'user_name': widget.userName,
            'approved_by_pin': result.userPin,
            'approved_by_name': result.userName,
            'local_timestamp': nowMs,
            'sync_status': 'SYNCED',
            'z_report_id': '',
            'created_at': now,
            'updated_at': now,
          });

          try {
            if (FirebaseRealtimeService.instance.isInitialized) {
              final fb = FirebaseRealtimeService.instance.db;
              if (fb != null && companyCode.isNotEmpty) {
                await fb.ref(
                  'companies/$companyCode/stockMovements/$realBranchId/$movementId'
                ).set({
                  'movement_id': movementId,
                  'movement_type': 'TRANSFER_IN',
                  'sku': ri.item.sku,
                  'product_id': ri.item.productId,
                  'product_name': ri.item.productName,
                  'qty_before': (currentSOH - ri.receivedQty).toDouble(),
                  'qty_change': ri.receivedQty.toDouble(),
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
          debugPrint('[INBOUND-RECEIVE] Ledger insert failed: $e');
        }
      }

      try {
        if (!FirebaseRealtimeService.instance.isInitialized) {
          final cfg = await FirebaseConfigService().load();
          if (cfg != null) {
            await FirebaseRealtimeService.instance.initializeFromManualConfig(cfg);
          }
        }
        final fb = FirebaseRealtimeService.instance.db;
        if (fb != null && companyCode.isNotEmpty) {
          await fb.ref('companies/$companyCode/interStoreTransfers/${widget.transferId}').update({
            'status': newStatus,
            'receivedBy': result.userName,
            'receivedByPin': result.userPin,
            'receivedDate': now,
            'totalReceivedQty': _totalReceived,
            'totalShortQty': _totalShort,
            'updatedAt': now,
            'batches': batchesPayload, // v1.0.57+111 — sync variance to Firebase
          });
          await fb.ref('companies/$companyCode/inboundTransfers/$realBranchId/${widget.transferId}').update({
            'status': newStatus,
            'receivedDate': now,
            'batches': batchesPayload, // v1.0.57+111 — sync variance to Firebase
          });
          debugPrint('[INBOUND-RECEIVE] Firebase status updated');
        }
      } catch (e) {
        debugPrint('[INBOUND-RECEIVE] Firebase sync failed: $e');
      }

      if (!mounted) return;
      Navigator.pop(context);
      await _load();
      if (!mounted) return;

      _showSnack(
        _hasVariance
            ? 'Partially received — $successCount items ($_totalShort short)'
            : 'Received — $successCount item(s) added to inventory',
        color: _hasVariance ? _yellow : _green,
      );

      // Show print options popup
      await _showReceivePrintOptions(receiverName: result.userName);
      if (!mounted) return;
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (!mounted) return;
      _showSnack('Receive failed: $e', color: _red);
    } finally {
      _actionInProgress = false;
    }
  }

  Future<void> _reject() async {
    if (_actionInProgress) return;
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
            hintText: 'Why are you rejecting?',
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
      
      // Upload REJECTED status to Firebase (cross-device sync)
      try {
        if (FirebaseRealtimeService.instance.isInitialized) {
          final fb = FirebaseRealtimeService.instance.db;
          final assign = await DeviceAssignmentService().read();
          final companyCode = (assign['companyCode'] ?? '').toString();
          if (fb != null && companyCode.isNotEmpty) {
            await fb.ref(
              'companies/$companyCode/interStoreTransfers/${widget.transferId}'
            ).update({
              'status': 'REJECTED',
              'rejectedBy': pin.userName,
              'rejectedDate': DateTime.now().toIso8601String(),
              'rejectionReason': reasonCtrl.text.trim(),
              'updatedAt': DateTime.now().toIso8601String(),
            });
            debugPrint('[TRANSFER-FB] ✅ Rejected uploaded: ${widget.transferId}');
          }
        }
      } catch (e) {
        debugPrint('[TRANSFER-FB] Reject upload error: $e');
      }
      
      if (!mounted) return;
      _showSnack('Transfer rejected — sender will be notified', color: _red);
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
        backgroundColor: _amber,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Receive Transfer',
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
                _buildBanner(),
                Expanded(child: _buildList()),
              ],
            ),
      bottomNavigationBar: _items.isEmpty || _loading ? null : _buildBottomBar(),
    );
  }

  Widget _buildBanner() {
    return Container(
      color: _amber.withValues(alpha: 0.08),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_shipping_rounded, color: _amber, size: 20),
              const SizedBox(width: 8),
              const Text('READY TO RECEIVE',
                  style: TextStyle(color: _amber, fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
          if (_doc != null) ...[
            const SizedBox(height: 6),
            Text('From: ${_doc!.issuingBranchId} (${_doc!.issuingBranchName})',
                style: const TextStyle(color: _textSecondary, fontSize: 11)),
            Text('Approved by: ${_doc!.approvedBy}',
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
      itemBuilder: (context, index) => _buildItemCard(_items[index]),
    );
  }

  Widget _buildItemCard(_ReceiveItem ri) {
    final isPartial = ri.receivedQty < ri.item.issuedQty;
    final isRejected = ri.receivedQty == 0;
    final borderColor = isRejected
        ? _red
        : (isPartial ? _yellow : _green);
    final hasBatches = ri.batches.isNotEmpty; // v1.0.56

    return GestureDetector(
      onLongPress: hasBatches ? () => _openBatchDialog(ri) : null,
      child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ri.item.productName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    Text('SKU: ${ri.item.sku}',
                        style: const TextStyle(color: _textSecondary, fontSize: 11)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('ISSUED', style: TextStyle(fontSize: 10, color: _textSecondary)),
                  Text('${ri.item.issuedQty} pcs',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text('Received:', style: TextStyle(fontSize: 12, color: _textSecondary)),
              const SizedBox(width: 8),
              SizedBox(
                width: 80,
                child: TextField(
                  controller: ri.receivedCtrl,
                  onChanged: (v) {
                    setState(() {
                      ri.receivedQty = int.tryParse(v) ?? 0;
                      if (ri.receivedQty < 0) ri.receivedQty = 0;
                      if (ri.receivedQty > ri.item.issuedQty) {
                        ri.receivedQty = ri.item.issuedQty;
                        ri.receivedCtrl.text = ri.item.issuedQty.toString();
                      }
                    });
                  },
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: borderColor),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: borderColor, width: 1.5),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: borderColor.withValues(alpha: 0.5)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text('/ ${ri.item.issuedQty} pcs',
                  style: const TextStyle(fontSize: 12, color: _textSecondary)),
              const Spacer(),
              if (isPartial && !isRejected)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _yellow.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('Short ${ri.item.issuedQty - ri.receivedQty}',
                      style: const TextStyle(color: _yellow, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              if (isRejected)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _red.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('Not receiving',
                      style: TextStyle(color: _red, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              // v1.0.56 — Chevron to expand batch list
              if (hasBatches)
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(
                    ri.expanded ? Icons.expand_less : Icons.expand_more,
                    color: borderColor,
                    size: 22,
                  ),
                  tooltip: 'Show batches',
                  onPressed: () => setState(() => ri.expanded = !ri.expanded),
                ),
            ],
          ),
          // v1.0.56 — Inline expandable batch section
          if (hasBatches && ri.expanded) ...[
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 8),
            _buildBatchList(ri, inDialog: false),
          ],
        ],
      ),
      ),
    );
  }

  // v1.0.56 — Batch list widget (reused for inline + dialog)
  Widget _buildBatchList(_ReceiveItem ri, {required bool inDialog}) {
    int subIssued = 0;
    int subReceived = 0;
    for (final rb in ri.batches) {
      subIssued += rb.source.transferQty;
      subReceived += rb.receivedQty;
    }
    final subShort = subIssued - subReceived;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: const [
            Icon(Icons.inventory_2_outlined, size: 15, color: _textSecondary),
            SizedBox(width: 6),
            Text('Batch Details',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _textPrimary)),
          ],
        ),
        const SizedBox(height: 6),
        ...ri.batches.asMap().entries.map((entry) {
          final rb = entry.value;
          final isLast = entry.key == ri.batches.length - 1;
          final rowColor = rb.hasShort ? _yellow : _green;
          final mfgStr = '${rb.source.mfgDate.year.toString().padLeft(4,'0')}-${rb.source.mfgDate.month.toString().padLeft(2,'0')}-${rb.source.mfgDate.day.toString().padLeft(2,'0')}';
          final expStr = '${rb.source.expiryDate.year.toString().padLeft(4,'0')}-${rb.source.expiryDate.month.toString().padLeft(2,'0')}-${rb.source.expiryDate.day.toString().padLeft(2,'0')}';
          return Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Batch: ${rb.source.batchNumber}   Lot: ${rb.source.lotNumber}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                Text('MFG: $mfgStr   EXP: $expStr',
                    style: const TextStyle(fontSize: 11, color: _textSecondary)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text('Issued: ${rb.source.transferQty}',
                        style: const TextStyle(fontSize: 11, color: _textSecondary)),
                    const SizedBox(width: 10),
                    const Text('Received:', style: TextStyle(fontSize: 11, color: _textSecondary)),
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 60,
                      child: TextField(
                        controller: rb.qtyCtrl,
                        onChanged: (v) {
                          setState(() {
                            var n = int.tryParse(v) ?? 0;
                            if (n < 0) n = 0;
                            // v1.0.57 — Allow overage (cap at 999)
                            if (n > 999) n = 999;
                            rb.receivedQty = n;
                            // Reset reason if variance became perfect
                            if (rb.isPerfect) rb.reason = '';
                            // Auto-sum to item level
                            final total = ri.batches.fold<int>(0, (s, x) => s + x.receivedQty);
                            ri.receivedQty = total;
                            ri.receivedCtrl.text = total.toString();
                          });
                        },
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: rowColor),
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: BorderSide(color: rowColor.withValues(alpha: 0.6), width: 1),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // v1.0.57 — Variance badge
                    if (rb.hasShort)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _yellow.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('Short ${rb.short}',
                            style: const TextStyle(color: _yellow, fontSize: 10, fontWeight: FontWeight.bold)),
                      )
                    else if (rb.hasOverage)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('+${rb.variance} Over',
                            style: const TextStyle(color: Color(0xFF3B82F6), fontSize: 10, fontWeight: FontWeight.bold)),
                      )
                    else
                      const Icon(Icons.check_circle_rounded, color: _green, size: 14),
                  ],
                ),
                // v1.0.57 — Reason picker (Phase 2A) - shown only if variance
                if (rb.needsReason) ...[
                  const SizedBox(height: 6),
                  _buildReasonPicker(rb, inDialog: inDialog),
                ],
              ],
            ),
          );
        }).toList(),
        const SizedBox(height: 6),
        const Divider(height: 1),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Batch Total  Issued: $subIssued', style: const TextStyle(fontSize: 11, color: _textSecondary)),
            Text('Received: $subReceived', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _green)),
            Text('Short: $subShort',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: subShort > 0 ? _yellow : _textSecondary)),
          ],
        ),
      ],
    );
  }

  // v1.0.57 — Reason picker widget (Phase 2A)
  Widget _buildReasonPicker(_ReceiveBatch rb, {required bool inDialog}) {
    final isOverage = rb.hasOverage;
    final options = isOverage ? _VarianceReasons.overage : _VarianceReasons.short;
    final labelColor = isOverage ? const Color(0xFF3B82F6) : _yellow;
    final label = isOverage ? 'Overage Reason (required)' : 'Short Reason (required)';
    final icon = isOverage ? Icons.info_outline_rounded : Icons.warning_amber_rounded;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: labelColor),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: labelColor)),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: options.map((opt) {
            final selected = rb.reason == opt.code;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: InkWell(
                  onTap: () => setState(() => rb.reason = opt.code),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected ? opt.color.withValues(alpha: 0.15) : _card,
                      border: Border.all(
                        color: selected ? opt.color : _divider,
                        width: selected ? 1.5 : 1,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(opt.icon, size: 16, color: selected ? opt.color : _textSecondary),
                        const SizedBox(height: 2),
                        Text(opt.label,
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: selected ? opt.color : _textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        if (selected)
                          Icon(Icons.check_circle, size: 10, color: opt.color),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 4),
        // Optional notes field
        SizedBox(
          height: 30,
          child: TextField(
            controller: rb.notesCtrl,
            style: const TextStyle(fontSize: 10),
            decoration: InputDecoration(
              isDense: true,
              hintText: '📝 Notes (optional)',
              hintStyle: const TextStyle(fontSize: 10, color: _textSecondary),
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: _divider),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // v1.0.56 — Long-press full-screen dialog
  Future<void> _openBatchDialog(_ReceiveItem ri) async {
    await showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: StatefulBuilder(
          builder: (ctx, setLocal) {
            return Container(
              padding: const EdgeInsets.all(16),
              constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.inventory_2_rounded, color: _green),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(ri.item.productName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  Text('SKU: ${ri.item.sku}',
                      style: const TextStyle(fontSize: 11, color: _textSecondary)),
                  const SizedBox(height: 12),
                  Flexible(
                    child: SingleChildScrollView(
                      child: _buildBatchList(ri, inDialog: true),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.of(ctx).pop(),
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Done'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
    if (mounted) setState(() {}); // refresh parent after dialog close
  }

  Widget _buildBottomBar() {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSummary(),
          Container(
            padding: EdgeInsets.only(
              left: 12, right: 12, top: 12,
              bottom: MediaQuery.of(context).padding.bottom + 12,
            ),
            decoration: const BoxDecoration(color: _card),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _actionInProgress ? null : _reject,
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Reject All'),
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
                    // v1.0.57 — Disable if any variance batch missing reason
                    onPressed: (_actionInProgress || !_allBatchesHaveReasons) ? null : _confirmReceipt,
                    icon: Icon(_hasVariance ? Icons.warning_rounded : Icons.check_rounded, size: 18),
                    label: Text(!_allBatchesHaveReasons
                        ? 'Select Reason(s)'
                        : (_hasVariance ? 'Confirm Partial' : 'Confirm Full')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: !_allBatchesHaveReasons
                          ? _textSecondary
                          : (_hasVariance ? _yellow : _green),
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

  Widget _buildSummary() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: _card,
        border: Border(top: BorderSide(color: _divider)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _summaryStat(Icons.local_shipping_rounded, 'Issued', '$_totalIssued', _textPrimary),
          Container(width: 1, height: 26, color: _divider),
          _summaryStat(Icons.check_circle_rounded, 'Received', '$_totalReceived', _green),
          Container(width: 1, height: 26, color: _divider),
          _summaryStat(
            Icons.warning_rounded,
            'Short',
            '$_totalShort',
            _totalShort > 0 ? _yellow : _textSecondary,
          ),
        ],
      ),
    );
  }

  Widget _summaryStat(IconData icon, String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 11, color: _textSecondary)),
          ],
        ),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Future<void> _showReceivePrintOptions({required String receiverName}) async {
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
                width: 60, height: 60,
                decoration: BoxDecoration(
                  color: (_hasVariance ? _yellow : _green).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _hasVariance ? Icons.warning_rounded : Icons.check_circle_rounded,
                  color: _hasVariance ? _yellow : _green,
                  size: 40,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _hasVariance ? 'Partial Receipt Recorded!' : 'Receipt Confirmed!',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Received by: $receiverName',
                style: const TextStyle(fontSize: 12, color: _textSecondary),
              ),
              const SizedBox(height: 20),
              const Divider(color: _divider),
              const SizedBox(height: 12),
              const Text(
                'Print Receipt Slip?',
                style: TextStyle(fontSize: 13, color: _textSecondary, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              _buildRcvOpt(
                icon: Icons.picture_as_pdf_rounded,
                label: 'Preview PDF',
                subtitle: 'View before printing',
                color: Colors.blue,
                onTap: () async {
                  Navigator.pop(ctx);
                  await _printReceivePdf();
                },
              ),
              const SizedBox(height: 10),
              _buildRcvOpt(
                icon: Icons.print_rounded,
                label: 'Print',
                subtitle: 'Send to printer',
                color: _green,
                onTap: () async {
                  Navigator.pop(ctx);
                  await _printReceivePdf();
                },
              ),
              const SizedBox(height: 10),
              _buildRcvOpt(
                icon: Icons.download_rounded,
                label: 'Download PDF',
                subtitle: 'Save to device',
                color: Colors.deepPurple,
                onTap: () async {
                  Navigator.pop(ctx);
                  await _downloadReceivePdf();
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

  Widget _buildRcvOpt({
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

  Future<Uint8List> _generateReceivePdf() async {
    final pdf = pw.Document();
    // v1.0.58+118 — Grand Total uses batch sums (matches ITEM SUBTOTAL rows)
    // Bug: Was using ri.receivedQty (item-level) which didn't match per-batch data,
    // causing Grand Total Received/Short/Retail to differ from ITEM SUBTOTAL.
    int totalIssued = 0;
    int totalReceived = 0;
    double totalRetail = 0.0;
    for (final ri in _items) {
      final batches = _batchesByProduct[ri.item.productId] ?? [];
      if (batches.isEmpty) {
        // No batches — fallback to item-level
        totalIssued += ri.item.issuedQty;
        totalReceived += ri.receivedQty;
        totalRetail += ri.receivedQty * ri.item.unitCost;
      } else {
        // Sum from batches (variance-aware)
        for (final b in batches) {
          final actualReceived = b.receivedQty > 0 ? b.receivedQty : b.transferQty;
          totalIssued += b.transferQty;
          totalReceived += actualReceived;
          totalRetail += actualReceived * b.unitCost;
        }
      }
    }
    final totalShort = totalIssued - totalReceived;

    final pageFormat = pdf_pkg.PdfPageFormat.a4.landscape;
    const itemsPerPage = 20;
    final totalPages = (_items.length / itemsPerPage).ceil().clamp(1, 999);

    pw.Widget buildCopy({
      required String copyLabel,
      required List<_ReceiveItem> pageItems,
      required int currentPage,
      required int totalPagesCount,
    }) {
      final status = _hasVariance ? 'PARTIALLY RECEIVED' : 'RECEIVED';
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
                    pw.Text('· ' + status,
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
                _rc4Info('From Branch', bold: true),
                _rc4Info((_doc?.issuingBranchId ?? '') + ' (' + (_doc?.issuingBranchName ?? '') + ')'),
                _rc4Info('Received Date', bold: true),
                _rc4Info(_rc4Date(_doc?.receivedDate ?? DateTime.now().toIso8601String())),
              ]),
              pw.TableRow(children: [
                _rc4Info('To Branch', bold: true),
                _rc4Info((_doc?.receivingBranchId ?? '') + ' (' + (_doc?.receivingBranchName ?? '') + ')'),
                _rc4Info('IST No.', bold: true),
                _rc4Info((_doc?.docNumber.isEmpty ?? true) ? (_doc?.transferId ?? '') : (_doc?.docNumber ?? '')),
              ]),
            ],
          ),
          pw.SizedBox(height: 6),

          // Items Table with Received columns
          pw.Table(
            border: pw.TableBorder.all(width: 0.5),
            columnWidths: {
              0: const pw.FixedColumnWidth(70),
              1: const pw.FlexColumnWidth(3),
              2: const pw.FixedColumnWidth(50),
              3: const pw.FixedColumnWidth(60),
              4: const pw.FixedColumnWidth(65),
              5: const pw.FixedColumnWidth(55),
              6: const pw.FixedColumnWidth(75),
              5: const pw.FixedColumnWidth(85),
            },
            children: [
              pw.TableRow(children: [
                _rc4H('SKU'),
                _rc4H('Product Name'),
                _rc4H('Issued'),
                _rc4H('Received'),
                _rc4H('Short'),
                _rc4H('Unit Retail'),
                _rc4H('Retail Value'),
              ]),
              ...pageItems.expand<pw.TableRow>((ri) {
                final item = ri.item;
                final batches = _batchesByProduct[item.productId] ?? [];
                final rows = <pw.TableRow>[];

                if (batches.isEmpty) {
                  final sh = item.issuedQty - ri.receivedQty;
                  final retail = ri.receivedQty * item.unitCost;
                  rows.add(pw.TableRow(children: [
                    _rc4C(item.sku),
                    _rc4C(item.productName),
                    _rc4CR(item.issuedQty.toString()),
                    _rc4CR(ri.receivedQty.toString()),
                    _rc4CR(sh > 0 ? sh.toString() : '-'),
                    _rc4CR(retail.toStringAsFixed(2)),
                  ]));
                } else {
                  // Product header row (bold)
                  rows.add(pw.TableRow(children: [
                    _rc4C(item.sku, bold: true),
                    _rc4C(item.productName, bold: true),
                    _rc4C(''),
                    _rc4C(''),
                    _rc4C(''),
                    _rc4C(''),
                  ]));

                  int itemIssued = 0;
                  double itemTotal = 0;
                  for (final b in batches) {
                    // v1.0.58+116 — Variance-aware auto-print PDF
                    // Show actual received qty, short/overage, and reason
                    final actualReceived = b.receivedQty > 0 ? b.receivedQty : b.transferQty;
                    final actualShort = b.transferQty - actualReceived;
                    final bTotal = actualReceived * b.unitCost;  // Value based on RECEIVED
                    itemIssued += b.transferQty;
                    itemTotal += bTotal;
                    final mfgStr = '${b.mfgDate.year.toString().padLeft(4,'0')}-${b.mfgDate.month.toString().padLeft(2,'0')}-${b.mfgDate.day.toString().padLeft(2,'0')}';
                    final expStr = '${b.expiryDate.year.toString().padLeft(4,'0')}-${b.expiryDate.month.toString().padLeft(2,'0')}-${b.expiryDate.day.toString().padLeft(2,'0')}';
                    // Variance suffix (short/overage with reason)
                    String varSuffix = '';
                    if (actualShort > 0) {
                      varSuffix = '  |  Short ${actualShort}${b.shortReason.isNotEmpty ? " · ${b.shortReason}" : ""}';
                    } else if (actualShort < 0) {
                      varSuffix = '  |  Overage ${-actualShort}${b.shortReason.isNotEmpty ? " · ${b.shortReason}" : ""}';
                    }
                    final info = '   Batch: ${b.batchNumber}  Lot: ${b.lotNumber}  MFG: $mfgStr  EXP: $expStr$varSuffix';
                    // Short col shows actual short with reason
                    final shortCol = actualShort > 0
                        ? '${actualShort}${b.shortReason.isNotEmpty ? " (${b.shortReason})" : ""}'
                        : actualShort < 0
                            ? '+${-actualShort}${b.shortReason.isNotEmpty ? " (${b.shortReason})" : ""}'
                            : '-';
                    rows.add(pw.TableRow(children: [
                      _rc4C(''),
                      _rc4C(info),
                      _rc4CR(b.transferQty.toString()),
                      _rc4CR(actualReceived.toString()),
                      _rc4CR(shortCol),
                      _rc4CR(b.unitCost.toStringAsFixed(2)),
                      _rc4CR(bTotal.toStringAsFixed(2)),
                    ]));
                  }

                  // v1.0.58+117 — ITEM SUBTOTAL uses SUM of batch received (matches batch rows)
                  int itemReceived = 0;
                  for (final b in batches) {
                    final ar = b.receivedQty > 0 ? b.receivedQty : b.transferQty;
                    itemReceived += ar;
                  }
                  final itemShort = itemIssued - itemReceived;
                  rows.add(pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: pdf_pkg.PdfColor.fromInt(0xFFE3F2FD),
                    ),
                    children: [
                      _rc4C(''),
                      _rc4C('ITEM SUBTOTAL', bold: true),
                      _rc4CR(itemIssued.toString(), bold: true),
                      _rc4CR(itemReceived.toString(), bold: true),
                      _rc4CR(itemShort > 0 ? itemShort.toString() : (itemShort < 0 ? '+${-itemShort}' : '-'), bold: true),
                      _rc4CR('-', bold: true),
                      _rc4CR(itemTotal.toStringAsFixed(2), bold: true),
                    ],
                  ));
                }
                return rows;
              }),
              if (currentPage == totalPagesCount)
                pw.TableRow(children: [
                  _rc4C(''),
                  _rc4C('Grand Total', bold: true),
                  _rc4CR(totalIssued.toString(), bold: true),
                  _rc4CR(totalReceived.toString(), bold: true),
                  _rc4CR(totalShort > 0 ? totalShort.toString() : '-', bold: true),
                  _rc4CR('-', bold: true),
                  _rc4CR(totalRetail.toStringAsFixed(2), bold: true),
                ]),
              for (int i = 0; i < 6; i++)
                pw.TableRow(children: [
                  _rc4Empty(),
                  _rc4Empty(),
                  _rc4Empty(),
                  _rc4Empty(),
                  _rc4Empty(),
                  _rc4Empty(),
                  _rc4Empty(),
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
                pw.Expanded(child: _rc4Sig('Dispatched By:', _doc?.approvedBy ?? '')),
                pw.SizedBox(width: 12),
                pw.Expanded(child: _rc4Sig('Received By:', _doc?.receivedBy ?? '')),
                pw.SizedBox(width: 12),
                pw.Expanded(child: _rc4Sig('Verified By:', '')),
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

  static pw.Widget _rc4Info(String text, {bool bold = false}) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 8),
    child: pw.Text(text, style: pw.TextStyle(
      fontSize: 10,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    )),
  );

  static pw.Widget _rc4H(String text) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 8),
    alignment: pw.Alignment.center,
    child: pw.Text(text, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
  );

  static pw.Widget _rc4C(String text, {bool bold = false}) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
    child: pw.Text(text, style: pw.TextStyle(
      fontSize: 10,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    )),
  );

  static pw.Widget _rc4CR(String text, {bool bold = false}) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
    alignment: pw.Alignment.centerRight,
    child: pw.Text(text, style: pw.TextStyle(
      fontSize: 10,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    )),
  );

  static pw.Widget _rc4Empty() => pw.Container(
    padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 8),
    child: pw.Text(' ', style: const pw.TextStyle(fontSize: 10)),
  );

  static pw.Widget _rc4Sig(String label, String name) => pw.Container(
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

  static String _rc4Date(String iso) {
    if (iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso);
      return '${dt.year}-${dt.month.toString().padLeft(2, "0")}-${dt.day.toString().padLeft(2, "0")}';
    } catch (_) {
      return iso;
    }
  }

  static pw.Widget _rcvH(String text) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 5),
    alignment: pw.Alignment.center,
    child: pw.Text(text, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
  );

  static pw.Widget _rcvC(String text) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 5),
    child: pw.Text(text, style: const pw.TextStyle(fontSize: 9)),
  );

  static pw.Widget _rcvCR(String text) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 5),
    alignment: pw.Alignment.centerRight,
    child: pw.Text(text, style: const pw.TextStyle(fontSize: 9)),
  );

  static pw.Widget _rcvSig(String label, String name) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Container(
        height: 20,
        decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 0.5))),
      ),
      pw.SizedBox(height: 2),
      pw.Text(label, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
      pw.Text(name.isEmpty ? '_________________' : name, style: const pw.TextStyle(fontSize: 9)),
    ],
  );

  Future<void> _printReceivePdf() async {
    try {
      final bytes = await _generateReceivePdf();
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    } catch (e) {
      _showSnack('Print failed: $e', color: _red);
    }
  }

  Future<void> _downloadReceivePdf() async {
    try {
      final bytes = await _generateReceivePdf();
      final docNum = _doc!.docNumber.isEmpty ? _doc!.transferId : _doc!.docNumber;
      await Printing.sharePdf(bytes: bytes, filename: 'RCV-$docNum.pdf');
      _showSnack('PDF downloaded', color: _green);
    } catch (e) {
      _showSnack('Download failed: $e', color: _red);
    }
  }
}

class _ReceiveItem {
  final TransferV3Item item;
  final TextEditingController receivedCtrl;
  int receivedQty;
  bool expanded;                                // v1.0.56 — chevron state
  List<_ReceiveBatch> batches;                  // v1.0.56 — per-batch inputs

  _ReceiveItem({
    required this.item,
    required this.receivedCtrl,
    required this.receivedQty,
    this.expanded = false,
    List<_ReceiveBatch>? batches,
  }) : batches = batches ?? [];
}

// v1.0.56/57 — Per-batch received qty input with variance reason (Phase 2A)
class _ReceiveBatch {
  final TransferItemBatch source;
  final TextEditingController qtyCtrl;
  final TextEditingController notesCtrl;   // v1.0.57
  int receivedQty;
  String reason;                            // v1.0.57 — RETURN/DAMAGED/MISSING/EXTRA_PACKED/BONUS/UNKNOWN

  _ReceiveBatch({required this.source})
      : qtyCtrl = TextEditingController(text: source.transferQty.toString()),
        notesCtrl = TextEditingController(text: source.varianceNotes),
        receivedQty = source.transferQty,
        reason = source.shortReason;

  int get variance => receivedQty - source.transferQty;  // -N=short, +N=overage, 0=perfect
  int get short => source.transferQty - receivedQty;      // positive when short
  bool get hasShort => receivedQty < source.transferQty;
  bool get hasOverage => receivedQty > source.transferQty;
  bool get isPerfect => receivedQty == source.transferQty;
  bool get needsReason => !isPerfect;                     // v1.0.57
  bool get hasReason => reason.isNotEmpty;                // v1.0.57
}

// v1.0.57 — Variance reason constants (Phase 2A)
class _VarianceReasons {
  // SHORT reasons
  static const short = <_ReasonOption>[
    _ReasonOption('RETURN', 'Return', Icons.undo_rounded, Color(0xFF3B82F6)),      // blue
    _ReasonOption('DAMAGED', 'Damaged', Icons.broken_image_rounded, Color(0xFFEF4444)),  // red
    _ReasonOption('MISSING', 'Missing', Icons.help_outline_rounded, Color(0xFFF97316)),  // orange
  ];
  // OVERAGE reasons
  static const overage = <_ReasonOption>[
    _ReasonOption('EXTRA_PACKED', 'Extra', Icons.inventory_2_rounded, Color(0xFF3B82F6)),  // blue
    _ReasonOption('BONUS', 'Bonus', Icons.card_giftcard_rounded, Color(0xFF10B981)),        // green
    _ReasonOption('UNKNOWN', 'Unknown', Icons.help_rounded, Color(0xFF6B7280)),             // gray
  ];
}

class _ReasonOption {
  final String code;
  final String label;
  final IconData icon;
  final Color color;
  const _ReasonOption(this.code, this.label, this.icon, this.color);
}
