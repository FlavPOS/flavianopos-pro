import 'dart:convert';
import 'dart:typed_data';
// lib/screens/branches/branches_screen.dart
import 'package:flutter/material.dart';
import '../../models/branch_model.dart';
import 'add_branch_screen.dart';
import 'branch_detail_screen.dart';
import '../../utils/export_helper.dart';

class BranchesScreen extends StatefulWidget {
  const BranchesScreen({super.key});
  @override
  State<BranchesScreen> createState() => _BranchesScreenState();
}

class _BranchesScreenState extends State<BranchesScreen> {
  List<Branch> _branches = [];
  final _searchCtrl = TextEditingController();
  String _query = '';

  List<Branch> get _filtered =>
      _branches
          .where(
            (b) =>
                _query.isEmpty ||
                b.name.toLowerCase().contains(_query.toLowerCase()) ||
                b.address.toLowerCase().contains(_query.toLowerCase()),
          )
          .toList();


  @override
  void initState() {
    super.initState();
    _loadBranches();
  }

  Future<void> _loadBranches() async {
    await Branch.loadFromDB();
    if (mounted) {
      setState(() {
        _branches = List<Branch>.from(Branch.allBranches);
      });
    }
  }

  int get _activeCount => _branches.where((b) => b.isActive).length;
  int get _totalUsers => _branches.fold(0, (s, b) => s + b.userCount);
  double get _totalSales => _branches.fold(0, (s, b) => s + b.todaySales);

  void _addBranch() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddBranchScreen()),
    );
    if (result != null && result is Branch && mounted) {
      Branch.addBranch(result);
      await _loadBranches();
      if (mounted) _snack('${result.name} added!');
    }
  }

  void _updateBranch(Branch updated) {
    setState(() {
      final i = _branches.indexWhere((b) => b.id == updated.id);
      if (i >= 0) _branches[i] = updated;
      Branch.updateBranch(updated.id, updated);
    });
  }

  void _toggleActive(Branch branch) {
    setState(() {
      final i = _branches.indexWhere((b) => b.id == branch.id);
      if (i >= 0) _branches[i] = branch.copyWith(isActive: !branch.isActive);
    });
    _snack('${branch.name} ${branch.isActive ? 'deactivated' : 'activated'}');
  }

  void _deleteBranch(Branch branch) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Delete Branch'),
            content: Text('Remove "${branch.name}"? This cannot be undone.'),
            actions: [

              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Branch.deleteBranch(branch.id);
                  setState(
                    () => _branches.removeWhere((b) => b.id == branch.id),
                  );
                  Navigator.pop(ctx);
                  _snack('${branch.name} removed');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  );

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _exportExcel() {
    final data = _filtered;
    ExportHelper.exportExcel(
      headers: ['ID', 'Name', 'Address', 'Phone', 'Users', 'Today Sales', 'Status'],
      rows: data.map((b) => [
        b.id, b.name, b.address, b.phone,
        b.userCount.toString(), b.todaySales.toStringAsFixed(2),
        b.isActive ? 'Active' : 'Inactive',
      ]).toList(),
      sheetName: 'Branches',
      fileName: 'Branches_${DateTime.now().millisecondsSinceEpoch}.xlsx',
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ Excel exported!'), backgroundColor: Colors.green));
  }

  void _exportPdf() {
    final data = _filtered;
    ExportHelper.exportPdf(
      title: 'Branches Report',
      subtitle: '${data.length} branches | Active: $_activeCount | Total Sales: ${_totalSales.toStringAsFixed(2)}',
      headers: ['ID', 'Name', 'Address', 'Phone', 'Users', 'Today Sales', 'Status'],
      rows: data.map((b) => [
        b.id, b.name, b.address, b.phone,
        b.userCount.toString(), b.todaySales.toStringAsFixed(2),
        b.isActive ? 'Active' : 'Inactive',
      ]).toList(),
      fileName: 'Branches_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ PDF exported!'), backgroundColor: Colors.green));
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Branches',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.indigo[700],
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.file_download),
            onSelected: (v) { if (v == 'excel') _exportExcel(); if (v == 'pdf') _exportPdf(); },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'excel', child: Row(children: [Icon(Icons.table_chart, color: Colors.green, size: 20), SizedBox(width: 10), Text('Export Excel')])),
              const PopupMenuItem(value: 'pdf', child: Row(children: [Icon(Icons.picture_as_pdf, color: Colors.red, size: 20), SizedBox(width: 10), Text('Export PDF')])),
            ]),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _card(
                  'Branches',
                  '${_branches.length}',
                  Icons.store,
                  Colors.indigo,
                ),
                const SizedBox(width: 8),
                _card(
                  'Active',
                  '$_activeCount',
                  Icons.check_circle,
                  Colors.green,
                ),
                const SizedBox(width: 8),
                _card('Users', '$_totalUsers', Icons.people, Colors.blue),
                const SizedBox(width: 8),
                _card(
                  'Sales',
                  '${_formatCompact(_totalSales)}',
                  Icons.trending_up,
                  Colors.orange,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search branches...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon:
                    _query.isNotEmpty
                        ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _query = '');
                          },
                        )
                        : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[50],
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  '${_filtered.length} branches',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const Spacer(),
                Text(
                  'Sorted by: Name',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Expanded(
            child:
                _filtered.isEmpty
                    ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.store_outlined,
                            size: 64,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'No branches found',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                    : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: _filtered.length,
                      itemBuilder: (context, i) {
                        final b = _filtered[i];
                        final imgBytes = _getBranchImageBytes(b);
                        final hasImg = imgBytes != null;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          clipBehavior: Clip.antiAlias,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(
                              color: b.isActive
                                  ? Colors.indigo.withAlpha(60)
                                  : Colors.grey.withAlpha(60)),
                          ),
                          child: InkWell(
                            onTap: () => Navigator.push(context,
                              MaterialPageRoute(builder: (context) =>
                                BranchDetailScreen(branch: b, onUpdate: _updateBranch))),
                            borderRadius: BorderRadius.circular(14),
                            child: hasImg
                              ? _buildImageBranchCard(b, imgBytes)
                              : _buildIconBranchCard(b),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addBranch,
        backgroundColor: Colors.indigo[700],
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_business),
        label: const Text('Add Branch'),
      ),
    );
  }

  Uint8List? _getBranchImageBytes(Branch b) {
    if (b.imagePath != null && b.imagePath!.isNotEmpty) {
      try {
        String b64 = b.imagePath!;
        if (b64.contains(',')) b64 = b64.split(',').last;
        if (b64.length > 200) {
          return Uint8List.fromList(base64Decode(b64));
        }
      } catch (_) {}
    }
    return null;
  }

  Widget _buildImageBranchCard(Branch b, Uint8List imgBytes) {
    return SizedBox(
      height: 140,
      child: Stack(fit: StackFit.expand, children: [
        Image.memory(imgBytes, fit: BoxFit.cover),
        // Gradient overlay
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.black.withAlpha(200),
                Colors.black.withAlpha(160),
                Colors.black.withAlpha(80),
                Colors.transparent,
              ],
              stops: const [0.0, 0.3, 0.6, 1.0],
            ),
          ),
        ),
        // Content
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: Text(b.name,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18,
                  shadows: [Shadow(blurRadius: 4, color: Colors.black)]))),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: (b.isActive ? Colors.green : Colors.grey).withAlpha(180),
                  borderRadius: BorderRadius.circular(8)),
                child: Text(b.isActive ? 'Active' : 'Inactive',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              const Spacer(),
              PopupMenuButton<String>(
                iconColor: Colors.white,
                onSelected: (v) {
                  if (v == 'toggle') _toggleActive(b);
                  if (v == 'delete') _deleteBranch(b);
                },
                itemBuilder: (context) => [
                  PopupMenuItem(value: 'toggle', child: Text(b.isActive ? 'Deactivate' : 'Activate')),
                  const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                ],
              ),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.location_on, size: 12, color: Colors.white70),
              const SizedBox(width: 4),
              Flexible(child: Text(b.address,
                style: const TextStyle(fontSize: 11, color: Colors.white70,
                  shadows: [Shadow(blurRadius: 3, color: Colors.black)]),
                overflow: TextOverflow.ellipsis)),
            ]),
            if (b.manager.isNotEmpty) ...[
              const SizedBox(height: 2),
              Row(children: [
                const Icon(Icons.person, size: 12, color: Colors.white70),
                const SizedBox(width: 4),
                Text('Manager: ${b.manager}',
                  style: const TextStyle(fontSize: 11, color: Colors.white70,
                    shadows: [Shadow(blurRadius: 3, color: Colors.black)])),
              ]),
            ],
            const Spacer(),
            Row(children: [
              _imgStatChip(Icons.people, '${b.userCount} users', Colors.lightBlueAccent),
              const SizedBox(width: 6),
              _imgStatChip(Icons.inventory_2, '${b.totalProducts} items', Colors.orangeAccent),
              const SizedBox(width: 6),
              _imgStatChip(Icons.trending_up, b.todaySales.toStringAsFixed(0), Colors.greenAccent),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _imgStatChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(100),
        borderRadius: BorderRadius.circular(6)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 3),
        Text(text, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: color)),
      ]),
    );
  }

  Widget _buildIconBranchCard(Branch b) {
    final color = b.isActive ? Colors.indigo : Colors.grey;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withAlpha(25), borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.store, color: color, size: 28)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: Text(b.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: (b.isActive ? Colors.green : Colors.grey).withAlpha(20),
                  borderRadius: BorderRadius.circular(8)),
                child: Text(b.isActive ? 'Active' : 'Inactive',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                    color: b.isActive ? Colors.green : Colors.grey)),
              ),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              Icon(Icons.location_on, size: 14, color: Colors.grey[500]),
              const SizedBox(width: 4),
              Flexible(child: Text(b.address,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                overflow: TextOverflow.ellipsis)),
            ]),
            if (b.manager.isNotEmpty) ...[
              const SizedBox(height: 2),
              Row(children: [
                Icon(Icons.person, size: 14, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text('Manager: ${b.manager}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ]),
            ],
          ])),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'toggle') _toggleActive(b);
              if (v == 'delete') _deleteBranch(b);
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'toggle', child: Text(b.isActive ? 'Deactivate' : 'Activate')),
              const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
            ],
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          _statChip(Icons.people, '${b.userCount} users', Colors.blue),
          const SizedBox(width: 8),
          _statChip(Icons.inventory_2, '${b.totalProducts} products', Colors.orange),
          const SizedBox(width: 8),
          _statChip(Icons.trending_up, b.todaySales.toStringAsFixed(0), Colors.green),
        ]),
      ]),
    );
  }

  String _formatCompact(double v) {
    if (v >= 1000000000) return '${(v / 1000000000).toStringAsFixed(1)}Bn';
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(2);
  }

  Widget _card(String label, String value, IconData icon, Color color) =>
      Expanded(
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Column(
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(fontSize: 9, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );

  Widget _statChip(IconData icon, String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withAlpha(15),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    ),
  );
}
