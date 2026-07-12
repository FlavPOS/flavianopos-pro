
// ═══════════════════════════════════════════════════════════
// v1.0.42 — Update batch with reason code (BIR audit trail)
// ═══════════════════════════════════════════════════════════
Future<bool> updateBatchReason({
  required String batchId,
  required String branchCode,
  required String reason,
  int? qtyChange,
  String? note,
  required String updatedBy,
}) async {
  try {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now().millisecondsSinceEpoch;

    final existing = await db.query(
      'batches',
      where: 'id = ? AND branchCode = ?',
      whereArgs: [batchId, branchCode],
    );
    if (existing.isEmpty) {
      print('[BATCH-REASON] ❌ Batch \$batchId not found');
      return false;
    }

    final batch = Batch.fromMap(existing.first);
    final newQty = qtyChange != null
      ? (batch.qty + qtyChange).clamp(0, batch.originalQty)
      : batch.qty;
    final newStatus = _statusFromReason(reason, newQty);

    await db.update(
      'batches',
      {
        'qty': newQty,
        'status': newStatus,
        'lastReason': reason,
        'lastReasonNote': note,
        'lastUpdatedAt': now,
        'lastUpdatedBy': updatedBy,
      },
      where: 'id = ? AND branchCode = ?',
      whereArgs: [batchId, branchCode],
    );

    // Log to stockMovements ledger
    await StockMovementService.instance.logMovement(
      type: 'BATCH_UPDATE',
      subType: reason,
      batchId: batchId,
      sku: batch.sku,
      branchCode: branchCode,
      qtyChange: qtyChange ?? 0,
      qtyBefore: batch.qty,
      qtyAfter: newQty,
      reason: reason,
      note: note,
      userId: updatedBy,
    );

    // Sync to Firebase
    final companyCode = await SessionService.instance.getCompanyCode();
    await FirebaseDatabase.instance
      .ref('companies/\$companyCode/branchBatches/\$branchCode/\$batchId')
      .update({
        'qty': newQty,
        'status': newStatus,
        'lastReason': reason,
        'lastReasonNote': note,
        'lastUpdatedAt': now,
        'lastUpdatedBy': updatedBy,
      });

    print('[BATCH-REASON] ✅ \$batchId → \$reason (qty: \${batch.qty}→\$newQty)');
    return true;
  } catch (e) {
    print('[BATCH-REASON] ❌ Error: \$e');
    return false;
  }
}

String _statusFromReason(String reason, int qty) {
  if (qty == 0) {
    switch (reason) {
      case 'SOLD': return 'DEPLETED';
      case 'EXPIRED': return 'EXPIRED';
      case 'DAMAGE': return 'DAMAGED';
      case 'RETURN_VENDOR': return 'RETURNED';
      case 'CHARGED_EMPLOYEE': return 'CHARGED';
      default: return 'CLOSED';
    }
  }
  return 'ACTIVE';
}
