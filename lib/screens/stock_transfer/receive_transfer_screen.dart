// ============================================================
import '../../models/batch_model.dart';
import '../../services/device_assignment_service.dart';
import '../../models/user_model.dart';
import '../../models/settings_model.dart';
// RECEIVE INBOUND TRANSFER - QuickPOS Pro
// View In Transit transfers, receive items, update stock
// ============================================================
import 'package:flutter/material.dart';
import '../../models/stock_transfer_model.dart';
import '../../models/product_model.dart';

class ReceiveTransferScreen extends StatefulWidget {
  final String currentUser;
  final String currentBranch;
  const ReceiveTransferScreen({super.key, required this.currentUser, required this.currentBranch});
  @override
  State<ReceiveTransferScreen> createState() => _ReceiveTransferScreenState();
}

class _ReceiveTransferScreenState extends State<ReceiveTransferScreen> {
  List<StockTransfer> _transfers = [];
  bool _isLoading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    // STX BRANCH FILTERED RECEIVE - only show transfers TO this device branch
    final assign = await DeviceAssignmentService().read();
    final currentBranchId = (assign["branchId"] ?? "").toString();
    final all = await StockTransferStorage.getInboundForBranch(currentBranchId);
    setState(() { _transfers = all; _isLoading = false; });
  }

  void _snack(String msg, [Color? bg]) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: bg, behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));

  String _pad(int n) => n.toString().padLeft(2, '0');
  String _fmtDate(DateTime d) => '${_pad(d.month)}/${_pad(d.day)}/${d.year}';
  String _fmtDateTime(DateTime d) => '${_pad(d.month)}/${_pad(d.day)}/${d.year} ${_pad(d.hour)}:${_pad(d.minute)}';

  // ---- Open receive dialog for a transfer ----
  void _openReceiveDialog(StockTransfer transfer) {
    // Create editable qty controllers for each item
    final qtyControllers = transfer.items.map((item) =>
      TextEditingController(text: item.qtyTransferred.toString())).toList();
    final remarksCtrl = TextEditingController();
    bool isPosting = false;

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => DraggableScrollableSheet(
          initialChildSize: 0.9, maxChildSize: 0.95, minChildSize: 0.5, expand: false,
          builder: (ctx2, scroll) => Column(children: [
            Container(width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            // Header
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(Icons.call_received, color: Colors.green[700]),
                  const SizedBox(width: 8),
                  const Text('Receive Transfer', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(8)),
                    child: Text('IN TRANSIT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange[800]))),
                ]),
                const SizedBox(height: 12),
                // Transfer info card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(12)),
                  child: Column(children: [
                    _infoRow('Transfer No.', transfer.transferNo),
                    _infoRow('Date', _fmtDate(transfer.transferDate)),
                    _infoRow('From Branch', transfer.fromBranchName),
                    _infoRow('To Branch', transfer.toBranchName),
                    _infoRow('Prepared By', transfer.preparedBy),
                    if (transfer.approvedBy.isNotEmpty) _infoRow('Approved By', transfer.approvedBy),
                    if (transfer.remarks.isNotEmpty) _infoRow('Remarks', transfer.remarks),
                  ]),
                ),
                const SizedBox(height: 12),
                TextField(controller: remarksCtrl,
                  decoration: InputDecoration(labelText: 'Receiving Remarks (Optional)', prefixIcon: const Icon(Icons.note),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), isDense: true)),
                const SizedBox(height: 8),
                Text('Items to Receive (${transfer.items.length})',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green[800])),
                const SizedBox(height: 4),
              ]),
            ),
            // Items list
            Expanded(child: ListView.builder(
              controller: scroll,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: transfer.items.length,
              itemBuilder: (_, i) {
                final item = transfer.items[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: Colors.green.withAlpha(60))),
                  child: Padding(padding: const EdgeInsets.all(12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Container(padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(8)),
                          child: Text('${i + 1}', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[800]))),
                        const SizedBox(width: 10),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(item.itemName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          Text('${item.itemCode} | ${item.category}', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                        ])),
                      ]),
                      const SizedBox(height: 8),
                      // Batch info
                      Container(padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(8)),
                        child: Row(children: [
                          Icon(Icons.inventory_2, size: 14, color: Colors.teal[700]),
                          const SizedBox(width: 6),
                          Text('Batch: ${item.batchNumber}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                          const SizedBox(width: 10),
                          Text('MFG: ${item.fmtDate(item.manufacturedDate)}', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                          const SizedBox(width: 10),
                          Text('EXP: ${item.fmtDate(item.expiryDate)}', style: TextStyle(fontSize: 10,
                            color: item.isExpired ? Colors.red : item.isNearExpiry ? Colors.orange : Colors.grey[600],
                            fontWeight: item.isExpired || item.isNearExpiry ? FontWeight.bold : FontWeight.normal)),
                        ]),
                      ),
                      const SizedBox(height: 8),
                      Row(children: [
                        Text('Transferred: ${item.qtyTransferred}', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                        const SizedBox(width: 12),
                        Text('Cost: ${item.cost.toStringAsFixed(2)}', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                        const Spacer(),
                        // Editable receive qty
                        SizedBox(width: 80,
                          child: TextField(controller: qtyControllers[i],
                            keyboardType: TextInputType.number, textAlign: TextAlign.center,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.green[800]),
                            decoration: InputDecoration(
                              labelText: 'Recv Qty', labelStyle: const TextStyle(fontSize: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                          ),
                        ),
                      ]),
                    ]),
                  ),
                );
              },
            )),
            // Receive button
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withAlpha(20), blurRadius: 8, offset: const Offset(0, -2))]),
              child: Row(children: [
                // Full Receive button
                Expanded(child: OutlinedButton.icon(
                  onPressed: () {
                    for (var i = 0; i < qtyControllers.length; i++) {
                      qtyControllers[i].text = transfer.items[i].qtyTransferred.toString();
                    }
                    setSheetState(() {});
                  },
                  icon: const Icon(Icons.select_all, size: 16),
                  label: const Text('Full Receive', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                )),
                const SizedBox(width: 10),
                // Post Receive button
                Expanded(flex: 2, child: ElevatedButton.icon(
                  onPressed: isPosting ? null : () async {
                    // Validate quantities
                    for (var i = 0; i < transfer.items.length; i++) {
                      final qty = int.tryParse(qtyControllers[i].text) ?? 0;
                      if (qty < 0) { _snack('Qty cannot be negative', Colors.red); return; }
                      if (qty > transfer.items[i].qtyTransferred) {
                        _snack('${transfer.items[i].itemName}: cannot exceed transferred qty', Colors.red); return;
                      }
                    // Manager PIN check
                    if (AppSettings.requirePinVoid) {
                      final pinCtrl = TextEditingController();
                      final pinOk = await showDialog<bool>(context: context, builder: (pCtx) => AlertDialog(
                        title: const Text('Manager PIN Required'),
                        content: TextField(controller: pinCtrl, obscureText: true, maxLength: 6,
                          decoration: InputDecoration(labelText: 'Enter Manager PIN',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(pCtx, false), child: const Text('Cancel')),
                          ElevatedButton(onPressed: () {
                            final mgr = AppUser.allUsers.where((u) => (u.role == 'Admin' || u.role == 'Manager') && u.pin == pinCtrl.text.trim()).firstOrNull;
                            if (mgr != null) { Navigator.pop(pCtx, true); }
                            else { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid Manager PIN'), backgroundColor: Colors.red)); }
                          }, child: const Text('Confirm')),
                        ]));
                      if (pinOk != true) return;
                    }
                    }
                    setSheetState(() => isPosting = true);
                    try {
                      await _processReceive(transfer, qtyControllers, remarksCtrl.text.trim());
                      if (mounted) Navigator.pop(ctx);
                    } catch (e) {
                      if (mounted) _snack('Error: $e', Colors.red);
                    }
                    setSheetState(() => isPosting = false);
                  },
                  icon: isPosting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_circle, size: 18),
                  label: Text(isPosting ? 'POSTING...' : 'CONFIRM RECEIVE',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700], foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                )),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  // ---- Process Receiving ----
  Future<void> _processReceive(StockTransfer transfer, List<TextEditingController> qtyControllers, String remarks) async {
    final now = DateTime.now();
    final ledgerEntries = <TransferLedgerEntry>[];

    // Update received quantities and add stock to destination
    for (var i = 0; i < transfer.items.length; i++) {
      final item = transfer.items[i];
      final recvQty = int.tryParse(qtyControllers[i].text) ?? 0;
      item.qtyReceived = recvQty;

      if (recvQty > 0) {
        // Add stock to destination branch inventory
        final products = Product.allProducts;
        final pIdx = products.indexWhere((p) => p.id == item.itemId);
        if (pIdx >= 0) {
          final p = products[pIdx];
          final beforeStock = p.stockQty;
          final newStock = p.stockQty + recvQty;
          Product.updateProduct(p.id, Product(
            id: p.id, name: p.name, sku: p.sku, category: p.category,
            sellingPrice: p.sellingPrice, costPrice: p.costPrice, stockQty: newStock,
            reorderLevel: p.reorderLevel, barcode: p.barcode,
          ));

          // Create or update batch record
          if (item.batchNumber.isNotEmpty) {
            final existingBatch = ProductBatch.allBatches.where(
              (b) => b.productId == item.itemId && b.batchNumber == item.batchNumber).toList();
            if (existingBatch.isNotEmpty) {
              // Update existing batch - add received qty
              final batch = existingBatch.first;
              ProductBatch.updateBatch(batch.id, batch.copyWith(quantity: batch.quantity + recvQty));
            } else {
              // Create new batch record
              ProductBatch.addBatch(ProductBatch(
                id: 'BT-${now.millisecondsSinceEpoch}-${item.itemId}',
                productId: item.itemId, productName: item.itemName,
                productSku: item.itemCode, batchNumber: item.batchNumber,
                manufacturedDate: item.manufacturedDate ?? now,
                expiryDate: item.expiryDate ?? now.add(const Duration(days: 365)),
                quantity: recvQty, originalQty: recvQty,
                costPrice: item.cost, supplier: transfer.fromBranchName,
                notes: 'Received via ${transfer.transferNo}',
                dateAdded: now,
              ));
            }
          }

          // Create ledger entry for inbound
          ledgerEntries.add(TransferLedgerEntry(
            id: 'TL-${now.millisecondsSinceEpoch}-${item.itemId}-IN',
            date: now, referenceNo: transfer.transferNo,
            itemId: item.itemId, itemCode: item.itemCode, itemName: item.itemName,
            branchId: transfer.toBranchId, branchName: transfer.toBranchName,
            movementType: 'Stock Transfer In',
            batchNumber: item.batchNumber,
            manufacturedDate: item.manufacturedDate, expiryDate: item.expiryDate,
            beginningBalance: beforeStock,
            qtyIn: recvQty, endingBalance: newStock,
            user: widget.currentUser,
            remarks: 'Received from ${transfer.fromBranchName}${remarks.isNotEmpty ? " | $remarks" : ""}',
          ));
        }
      }
    }

    // Update transfer status
    transfer.status = 'Received';
    transfer.receivedBy = widget.currentUser;
    transfer.receivedDate = now;
    transfer.updatedAt = now;
    if (remarks.isNotEmpty) transfer.remarks += (transfer.remarks.isNotEmpty ? ' | ' : '') + 'Recv: $remarks';

    await StockTransferStorage.updateTransfer(transfer);
    if (ledgerEntries.isNotEmpty) await StockTransferStorage.saveLedger(ledgerEntries);

    if (mounted) {
      _snack('${transfer.transferNo} received!', Colors.green.shade700);
      await _load();
    }
  }

  Widget _infoRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: [
      SizedBox(width: 110, child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600]))),
      Expanded(child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
    ]),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Receive Inbound Transfer', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.green[700], foregroundColor: Colors.white,
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _transfers.isEmpty
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[300]),
              const SizedBox(height: 10),
              Text('No pending transfers', style: TextStyle(color: Colors.grey[500], fontSize: 16)),
              const SizedBox(height: 4),
              Text('All transfers have been received', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
              const SizedBox(height: 16),
              ElevatedButton.icon(onPressed: _load, icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Refresh'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700], foregroundColor: Colors.white)),
            ]))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _transfers.length,
                itemBuilder: (_, i) {
                  final t = _transfers[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.orange.withAlpha(80))),
                    child: InkWell(
                      onTap: () => _openReceiveDialog(t),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(padding: const EdgeInsets.all(14),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Container(padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(10)),
                              child: Icon(Icons.local_shipping, color: Colors.orange[700], size: 24)),
                            const SizedBox(width: 12),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(t.transferNo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              Text(_fmtDateTime(t.transferDate), style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                            ])),
                            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(8)),
                              child: Text('IN TRANSIT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange[800]))),
                          ]),
                          const SizedBox(height: 10),
                          Row(children: [
                            Icon(Icons.store, size: 14, color: Colors.grey[500]),
                            const SizedBox(width: 4),
                            Text('From: ${t.fromBranchName}', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward, size: 12, color: Colors.grey),
                            const SizedBox(width: 8),
                            Icon(Icons.store_mall_directory, size: 14, color: Colors.grey[500]),
                            const SizedBox(width: 4),
                            Text('To: ${t.toBranchName}', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                          ]),
                          const SizedBox(height: 8),
                          // Batch info preview
                          if (t.items.isNotEmpty) ...[
                            Container(padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(8)),
                              child: Column(children: t.items.take(3).map((item) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2),
                                child: Row(children: [
                                  Expanded(child: Text(item.itemName, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
                                  Text('Batch: ${item.batchNumber}', style: TextStyle(fontSize: 10, color: Colors.teal[700])),
                                  const SizedBox(width: 8),
                                  Text('x${item.qtyTransferred}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue[800])),
                                ]),
                              )).toList()),
                            ),
                            if (t.items.length > 3)
                              Padding(padding: const EdgeInsets.only(top: 4),
                                child: Text('+${t.items.length - 3} more items...', style: TextStyle(fontSize: 10, color: Colors.grey[500]))),
                          ],
                          const SizedBox(height: 8),
                          Row(children: [
                            Text('${t.totalItems} items', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                            const SizedBox(width: 12),
                            Text('Total Qty: ${t.totalQtyTransferred}', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                            const Spacer(),
                            Text('Prepared by: ${t.preparedBy}', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                          ]),
                          const SizedBox(height: 8),
                          SizedBox(width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => _openReceiveDialog(t),
                              icon: const Icon(Icons.call_received, size: 16),
                              label: const Text('RECEIVE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700], foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                            ),
                          ),
                        ]),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
