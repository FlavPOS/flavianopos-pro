// lib/screens/receive_delivery/draft_list_screen.dart
import 'package:flutter/material.dart';
import '../../models/product_model.dart';
import '../../widgets/receive_delivery/draft_list_table.dart';
import 'delivery_model.dart';
import 'receive_delivery_screen.dart';

class DraftListScreen extends StatefulWidget {
  final List<Product> products;
  const DraftListScreen({super.key, required this.products});

  @override
  State<DraftListScreen> createState() => _DraftListScreenState();
}

class _DraftListScreenState extends State<DraftListScreen> {
  List<DeliveryRecord> _drafts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDrafts();
  }

  Future<void> _loadDrafts() async {
    setState(() => _loading = true);
    final list = await DeliveryStorage.getByStatus(DeliveryStatus.draft);
    if (mounted) {
      setState(() {
        _drafts = list;
        _loading = false;
      });
    }
  }

  List<DraftItem> get _draftItems => _drafts.map((d) {
    DateTime updated;
    try {
      updated = d.lastEditedDate.isNotEmpty
          ? DateTime.parse(d.lastEditedDate)
          : d.dateTime;
    } catch (_) {
      updated = d.dateTime;
    }
    return DraftItem(
      drNumber: d.refNumber.isEmpty ? '(no DR)' : d.refNumber,
      supplier: d.supplier,
      date: d.dateTime,
      itemsCount: d.totalItems,
      totalQty: d.totalQuantity,
      totalValue: d.totalRetail,
      lastUpdated: updated,
    );
  }).toList();

  DeliveryRecord? _findRecord(DraftItem item) {
    for (final d in _drafts) {
      if (d.refNumber == item.drNumber &&
          d.dateTime == item.date &&
          d.totalRetail == item.totalValue) {
        return d;
      }
    }
    return null;
  }

  Future<void> _openDraft(DraftItem item) async {
    final record = _findRecord(item);
    if (record == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReceiveDeliveryScreen(products: widget.products, existingDraft: record),
      ),
    );
    _loadDrafts();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : DraftListTable(
                drafts: _draftItems,
                onBack: () => Navigator.pop(context),
                onRefresh: _loadDrafts,
                onTap: _openDraft,
              ),
      ),
    );
  }
}
