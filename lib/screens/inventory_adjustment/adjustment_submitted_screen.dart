import 'package:flutter/material.dart';
import 'adjustment_v3_model.dart';
import 'adjustment_submitted_detail_screen.dart';

class AdjustmentSubmittedScreen extends StatefulWidget {
  final String branch;
  final String userName;

  const AdjustmentSubmittedScreen({
    super.key,
    required this.branch,
    required this.userName,
  });

  @override
  State<AdjustmentSubmittedScreen> createState() =>
      _AdjustmentSubmittedScreenState();
}

class _AdjustmentSubmittedScreenState
    extends State<AdjustmentSubmittedScreen> {
  static const _blue = Color(0xFF3B82F6);
  static const _bg = Color(0xFFF5F6FA);
  static const _card = Color(0xFFFFFFFF);
  static const _textPrimary = Color(0xFF111827);
  static const _textSecondary = Color(0xFF6B7280);

  List<AdjustmentV3> _submitted = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await AdjustmentV3Dao.getByStatus(
      AdjustmentStatus.submitted,
      branchCode: widget.branch,
    );
    if (!mounted) return;
    setState(() {
      _submitted = list;
      _loading = false;
    });
  }

  Future<void> _openDetail(AdjustmentV3 sub) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdjustmentSubmittedDetailScreen(
          adjustmentId: sub.adjustmentId,
          branch: widget.branch,
          userName: widget.userName,
        ),
      ),
    );
    if (result == true || result == null) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _blue,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.send_rounded, size: 20),
            SizedBox(width: 8),
            Text('Submitted',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _submitted.isEmpty
              ? _buildEmpty()
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _submitted.length,
                  itemBuilder: (context, index) {
                    return _buildCard(_submitted[index]);
                  },
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
              color: _blue.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.send_rounded,
                size: 64, color: _blue),
          ),
          const SizedBox(height: 12),
          const Text('No submissions',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _textPrimary)),
          const SizedBox(height: 4),
          const Text('Submit a draft to see it here',
              style: TextStyle(fontSize: 13, color: _textSecondary)),
        ],
      ),
    );
  }

  Widget _buildCard(AdjustmentV3 sub) {
    String created = sub.createdAt;
    try {
      final dt = DateTime.parse(sub.submittedAt.isNotEmpty
          ? sub.submittedAt
          : sub.createdAt);
      created =
          '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {}

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
        onTap: () => _openDetail(sub),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.send_rounded,
                    color: _blue, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sub.docNumber.isEmpty
                          ? sub.adjustmentId
                          : sub.docNumber,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _textPrimary,
                          fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Prepared by: ${sub.createdByName}',
                      style: const TextStyle(
                          color: _textSecondary, fontSize: 11),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      created,
                      style: const TextStyle(
                          color: _textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'PENDING',
                  style: TextStyle(
                      color: _blue,
                      fontSize: 10,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
