// lib/screens/receive_delivery/approved_list_screen.dart
import 'package:flutter/material.dart';
import '../../models/product_model.dart';
import '../../widgets/receive_delivery/approved_list_table.dart';
import 'approved_detail_screen.dart';
import 'delivery_model.dart';

class ApprovedListScreen extends StatefulWidget {
  final List<Product> products;
  const ApprovedListScreen({super.key, required this.products});

  @override
  State<ApprovedListScreen> createState() => _ApprovedListScreenState();
}

class _ApprovedListScreenState extends State<ApprovedListScreen> {
  List<DeliveryRecord> _approved = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadApproved();
  }

  Future<void> _loadApproved() async {
    setState(() => _loading = true);
    final list = await DeliveryStorage.getByStatus(DeliveryStatus.approved);
    if (mounted) {
      setState(() {
        _approved = list;
        _loading = false;
      });
    }
  }

  List<ApprovedItem> get _items => _approved.map((d) {
    DateTime? aprDate;
    try { if (d.approvedDate.isNotEmpty) aprDate = DateTime.parse(d.approvedDate); } catch (_) {}
    return ApprovedItem(
      drNumber: d.refNumber.isEmpty ? '(no DR)' : d.refNumber,
      supplier: d.supplier,
      date: d.dateTime,
      itemsCount: d.totalItems,
      totalQty: d.totalQuantity,
      totalValue: d.totalRetail,
      approvedBy: d.approvedBy,
      approvedDate: aprDate,
    );
  }).toList();

  DeliveryRecord? _findRecord(ApprovedItem item) {
    for (final d in _approved) {
      if (d.refNumber == item.drNumber && d.dateTime == item.date && d.totalRetail == item.totalValue) {
        return d;
      }
    }
    return null;
  }

  Future<void> _openDetail(ApprovedItem item) async {
    final record = _findRecord(item);
    if (record == null) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => ApprovedDetailScreen(record: record)));
    _loadApproved();
  }

  Future<void> _exportAll() async {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Export All: ${_approved.length} deliveries (tap individual row to export)'),
        backgroundColor: const Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ApprovedListTable(
                items: _items,
                onBack: () => Navigator.pop(context),
                onRefresh: _loadApproved,
                onExportAll: _exportAll,
                onView: _openDetail,
              ),
      ),
    );
  }
}
