import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'adjustment_model.dart';

class AdjustmentDetailsScreen extends StatefulWidget {
  final List<AdjustmentRecord> records;
  final String period;

  const AdjustmentDetailsScreen({super.key, required this.records, required this.period});

  @override
  State<AdjustmentDetailsScreen> createState() => _AdjustmentDetailsScreenState();
}

class _AdjustmentDetailsScreenState extends State<AdjustmentDetailsScreen> {

  Future<void> _exportCsv() async {
    final summaryData = _calculateSummary(widget.records);
    if (summaryData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No data to export'), backgroundColor: Colors.orange));
      return;
    }

    final buf = StringBuffer();
    buf.writeln('Reason,Items,Units,Total @ Cost,Total @ Retail');

    int grandItems = 0;
    int grandUnits = 0;
    double grandCost = 0.0;
    double grandRetail = 0.0;

    for (var entry in summaryData.entries) {
      final d = entry.value;
      final items = d['totalItems'] as int;
      final units = d['totalUnits'] as int;
      final cost = d['totalCost'] as double;
      final retail = d['totalRetail'] as double;
      buf.writeln('"${entry.key}",$items,$units,${cost.toStringAsFixed(2)},${retail.toStringAsFixed(2)}');
      grandItems += items;
      grandUnits += units;
      grandCost += cost;
      grandRetail += retail;
    }
    buf.writeln('TOTAL,$grandItems,$grandUnits,${grandCost.toStringAsFixed(2)},${grandRetail.toStringAsFixed(2)}');

    try {
      if (kIsWeb) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('CSV export not supported on web preview'),
            backgroundColor: Colors.blue));
      } else {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/adjustment_summary_${widget.period.replaceAll(' ', '_')}.csv');
        await file.writeAsString(buf.toString());
        await SharePlus.instance.share(ShareParams(
          files: [XFile(file.path)],
          text: 'FlavianoPOS - PRO - Adjustment Summary (${widget.period})',),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Export error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final summaryData = _calculateSummary(widget.records);

    // Calculate grand totals
    int grandTotalItems = 0;
    int grandTotalUnits = 0;
    double grandTotalCost = 0.0;
    double grandTotalRetail = 0.0;

    for (var data in summaryData.values) {
      grandTotalItems += data['totalItems'] as int;
      grandTotalUnits += data['totalUnits'] as int;
      grandTotalCost += data['totalCost'] as double;
      grandTotalRetail += data['totalRetail'] as double;
    }

    final reasons = summaryData.keys.toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Details for ${widget.period}', style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: 'Export CSV',
            onPressed: _exportCsv,
          ),
        ],
      ),
      body: summaryData.isEmpty
          ? const Center(child: Text('No adjustments for this period.'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Table(
                        columnWidths: const {
                          0: FlexColumnWidth(2),
                          1: FlexColumnWidth(0.8),
                          2: FlexColumnWidth(0.8),
                          3: FlexColumnWidth(1.3),
                          4: FlexColumnWidth(1.3),
                        },
                        children: [
                          // ── Header Row ──
                          TableRow(
                            decoration: BoxDecoration(
                              color: Colors.blue.shade700,
                            ),
                            children: const [
                              _HeaderCell(text: 'Reason'),
                              _HeaderCell(text: 'Items', alignment: TextAlign.center),
                              _HeaderCell(text: 'Units', alignment: TextAlign.center),
                              _HeaderCell(text: '@ Cost', alignment: TextAlign.right),
                              _HeaderCell(text: '@ Retail', alignment: TextAlign.right),
                            ],
                          ),
                          // ── Data Rows ──
                          for (int i = 0; i < reasons.length; i++)
                            TableRow(
                              decoration: BoxDecoration(
                                color: i.isEven ? Colors.white : Colors.grey.shade100,
                              ),
                              children: [
                                _DataCell(
                                  text: reasons[i],
                                  fontWeight: FontWeight.w600,
                                ),
                                _DataCell(
                                  text: summaryData[reasons[i]]!['totalItems'],
                                  alignment: TextAlign.center,
                                ),
                                _DataCell(
                                  text: summaryData[reasons[i]]!['totalUnits'],
                                  alignment: TextAlign.center,
                                ),
                                _DataCell(
                                  text: '${(summaryData[reasons[i]]!['totalCost'] as double).toStringAsFixed(2)}',
                                  alignment: TextAlign.right,
                                ),
                                _DataCell(
                                  text: '${(summaryData[reasons[i]]!['totalRetail'] as double).toStringAsFixed(2)}',
                                  alignment: TextAlign.right,
                                ),
                              ],
                            ),
                          // ── Total Row ──
                          TableRow(
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              border: const Border(
                                top: BorderSide(color: Colors.blue, width: 2),
                              ),
                            ),
                            children: [
                              const _DataCell(
                                text: 'TOTAL',
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                              _DataCell(
                                text: '$grandTotalItems',
                                alignment: TextAlign.center,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                              _DataCell(
                                text: '$grandTotalUnits',
                                alignment: TextAlign.center,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                              _DataCell(
                                text: '${grandTotalCost.toStringAsFixed(2)}',
                                alignment: TextAlign.right,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                              _DataCell(
                                text: '${grandTotalRetail.toStringAsFixed(2)}',
                                alignment: TextAlign.right,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Map<String, dynamic> _calculateSummary(List<AdjustmentRecord> records) {
    final summary = <String, dynamic>{};
    for (var record in records) {
      if (!summary.containsKey(record.reason)) {
        summary[record.reason] = {
          'totalItems': 0,
          'totalUnits': 0,
          'totalCost': 0.0,
          'totalRetail': 0.0,
        };
      }
      summary[record.reason]['totalItems'] += 1;
      summary[record.reason]['totalUnits'] += record.quantity;
      summary[record.reason]['totalCost'] += record.quantity * record.cost;
      summary[record.reason]['totalRetail'] += record.quantity * record.retail;
    }
    return summary;
  }
}

// ── Header Cell Widget ──
class _HeaderCell extends StatelessWidget {
  final String text;
  final TextAlign alignment;

  const _HeaderCell({
    required this.text,
    this.alignment = TextAlign.left,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 14.0),
      child: Text(
        text,
        textAlign: alignment,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }
}

// ── Data Cell Widget ──
class _DataCell extends StatelessWidget {
  final String text;
  final TextAlign alignment;
  final FontWeight fontWeight;
  final Color? color;

  const _DataCell({
    required this.text,
    this.alignment = TextAlign.left,
    this.fontWeight = FontWeight.normal,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
      child: Text(
        text,
        textAlign: alignment,
        style: TextStyle(
          fontSize: 13,
          fontWeight: fontWeight,
          color: color ?? Colors.black87,
        ),
      ),
    );
  }
}
