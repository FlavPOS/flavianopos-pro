import 'package:flutter/material.dart';
import 'adjustment_v3_model.dart';
import 'approver_pin_dialog_v3.dart';
import 'adjustment_pdf_generator.dart';

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

  // ─── APPROVE ────────────────────────────────────────────
  Future<void> _approve() async {
    final result = await ApproverPinDialog.show(
      context: context,
      title: 'Approve Adjustment',
      headerColor: _green,
      subtitle: 'This will apply changes to inventory',
      allowedRoles: const ['Supervisor', 'Manager', 'Admin'],
    );
    if (result == null || !mounted) return;

    try {
      await AdjustmentV3Dao.updateStatus(
        adjustmentId: widget.adjustmentId,
        newStatus: AdjustmentStatus.approved,
        approvedBy: result.userName,
        approvedByPin: result.userPin,
        approvedByRole: result.userRole,
      );
      if (!mounted) return;
      _showSnack('Approved by ${result.userName}', color: _green);
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      _showSnack('Approve failed: $e', color: _red);
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
