import 'package:flutter/material.dart';
import 'transfer_v3_model.dart';
import 'inbound_receive_screen.dart';

class InboundPendingScreen extends StatefulWidget {
  final String branch;
  final String userName;
  final String branchId;

  const InboundPendingScreen({
    super.key,
    required this.branch,
    required this.userName,
    required this.branchId,
  });

  @override
  State<InboundPendingScreen> createState() => _InboundPendingScreenState();
}

class _InboundPendingScreenState extends State<InboundPendingScreen> {
  static const _amber = Color(0xFFF59E0B);
  static const _bg = Color(0xFFF5F6FA);
  static const _card = Color(0xFFFFFFFF);
  static const _textPrimary = Color(0xFF111827);
  static const _textSecondary = Color(0xFF6B7280);

  List<TransferV3> _pending = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    // Load transfers TO this branch (inbound direction)
    final list = await TransferV3Dao.getByStatuses(
      [TransferStatus.floating, TransferStatus.partiallyReceived],
      widget.branchId,
      'inbound',
    );
    if (!mounted) return;
    setState(() {
      _pending = list;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _amber,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.pending_actions_rounded, size: 20),
            SizedBox(width: 8),
            Text('Pending Receipts',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _pending.isEmpty
              ? _buildEmpty()
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _pending.length,
                  itemBuilder: (context, index) => _buildCard(_pending[index]),
                ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _amber.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.inbox_rounded, size: 64, color: _amber),
          ),
          const SizedBox(height: 12),
          const Text('No pending transfers',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _textPrimary)),
          const SizedBox(height: 4),
          const Text('Approved transfers to your branch will appear here',
              style: TextStyle(fontSize: 13, color: _textSecondary)),
        ],
      ),
    );
  }

  Widget _buildCard(TransferV3 doc) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => InboundReceiveScreen(
                transferId: doc.transferId,
                branch: widget.branch,
                userName: widget.userName,
              ),
            ),
          ).then((_) => _load());
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.local_shipping_rounded, color: _amber, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doc.docNumber.isEmpty ? doc.transferId : doc.docNumber,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text('From: ${doc.issuingBranchId} (${doc.issuingBranchName})',
                        style: const TextStyle(color: _textSecondary, fontSize: 11)),
                    Text('${doc.totalIssuedQty} pcs • ${doc.totalItems} items',
                        style: const TextStyle(color: _textSecondary, fontSize: 11)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('PENDING',
                    style: TextStyle(color: _amber, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
