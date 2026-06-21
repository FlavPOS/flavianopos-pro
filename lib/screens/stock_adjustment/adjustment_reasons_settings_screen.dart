import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../helpers/database_helper.dart';
import 'adjustment_icon_map.dart';

class AdjustmentReasonsSettingsScreen extends StatefulWidget {
  const AdjustmentReasonsSettingsScreen({super.key});

  @override
  State<AdjustmentReasonsSettingsScreen> createState() =>
      _AdjustmentReasonsSettingsScreenState();
}

class _AdjustmentReasonsSettingsScreenState
    extends State<AdjustmentReasonsSettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _addReasons = [];
  List<Map<String, dynamic>> _deductReasons = [];
  bool _loading = true;

  static const Color _purple = Color(0xFF7C4DFF);
  static const Color _addColor = Colors.green;
  static const Color _deductColor = Colors.red;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadReasons();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadReasons() async {
    setState(() => _loading = true);
    var adds = await DatabaseHelper().getAdjustmentReasons(type: 'add');
    var deducts = await DatabaseHelper().getAdjustmentReasons(type: 'deduct');
    if (adds.isEmpty && deducts.isEmpty) {
      await DatabaseHelper().seedDefaultReasonsIfEmpty();
      adds = await DatabaseHelper().getAdjustmentReasons(type: 'add');
      deducts = await DatabaseHelper().getAdjustmentReasons(type: 'deduct');
    }
    setState(() {
      _addReasons = adds;
      _deductReasons = deducts;
      _loading = false;
    });
  }

  // ═══════════════════════════════════════════════════════
  // ADD / EDIT DIALOG (Bottom Sheet)
  // ═══════════════════════════════════════════════════════

  Future<void> _showReasonDialog({Map<String, dynamic>? existing}) async {
    final isEdit = existing != null;
    final labelController = TextEditingController(
        text: isEdit ? existing['label'] ?? '' : '');
    String selectedType = isEdit
        ? (existing['type'] ?? 'add')
        : (_tabController.index == 0 ? 'add' : 'deduct');
    String selectedIcon = isEdit ? (existing['iconName'] ?? 'edit') : 'edit';
    final formKey = GlobalKey<FormState>();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx2, setSheetState) {
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx2).size.height * 0.85,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20, right: 20, top: 16,
                  bottom: MediaQuery.of(ctx2).viewInsets.bottom + 16,
                ),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── Handle bar ──
                      Container(
                        width: 40, height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ── Title ──
                      Text(
                        isEdit ? 'Edit Reason' : 'Add New Reason',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 20),

                      // ── Type Dropdown ──
                      DropdownButtonFormField<String>(
                        initialValue: selectedType,
                        decoration: InputDecoration(
                          labelText: 'Type',
                          prefixIcon: Icon(
                            selectedType == 'add'
                                ? Icons.add_circle
                                : Icons.remove_circle,
                            color: selectedType == 'add'
                                ? _addColor
                                : _deductColor,
                          ),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 14),
                        ),
                        items: const [
                          DropdownMenuItem(
                              value: 'add',
                              child: Text('Add Stock',
                                  style: TextStyle(color: Colors.green))),
                          DropdownMenuItem(
                              value: 'deduct',
                              child: Text('Deduct Stock',
                                  style: TextStyle(color: Colors.red))),
                        ],
                        onChanged: (v) {
                          if (v != null) setSheetState(() => selectedType = v);
                        },
                      ),
                      const SizedBox(height: 14),

                      // ── Label TextField ──
                      TextFormField(
                        controller: labelController,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          labelText: 'Reason Label',
                          hintText: 'e.g. Donation, Promotion Giveaway...',
                          prefixIcon: const Icon(Icons.label, color: _purple),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 14),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Please enter a reason label';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // ── Icon Picker Label ──
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Choose Icon:',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey)),
                      ),
                      const SizedBox(height: 8),

                      // ── Icon Picker Grid ──
                      SizedBox(
                        height: 180,
                        child: GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 6,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                          ),
                          itemCount: availableIconNames.length,
                          itemBuilder: (_, i) {
                            final name = availableIconNames[i];
                            final isSelected = name == selectedIcon;
                            return GestureDetector(
                              onTap: () =>
                                  setSheetState(() => selectedIcon = name),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? _purple.withValues(alpha: 0.15)
                                      : Colors.grey[100],
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSelected
                                        ? _purple
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                child: Icon(
                                  getReasonIcon(name),
                                  size: 22,
                                  color: isSelected
                                      ? _purple
                                      : Colors.grey[600],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ── Action Buttons ──
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(ctx2),
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                if (!formKey.currentState!.validate()) return;
                                final label = labelController.text.trim();

                                if (isEdit) {
                                  await DatabaseHelper()
                                      .updateAdjustmentReason(existing['id'], {
                                    'label': label,
                                    'type': selectedType,
                                    'iconName': selectedIcon,
                                  });
                                } else {
                                  await DatabaseHelper()
                                      .insertAdjustmentReason({
                                    'id': const Uuid().v4(),
                                    'label': label,
                                    'type': selectedType,
                                    'iconName': selectedIcon,
                                    'isDefault': 0,
                                    'isActive': 1,
                                    'sortOrder': 99,
                                    'dateCreated':
                                        DateTime.now().toIso8601String(),
                                  });
                                }
                                if (ctx2.mounted) Navigator.pop(ctx2);
                                _loadReasons();
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(isEdit
                                          ? 'Reason updated successfully'
                                          : 'Reason added successfully'),
                                      backgroundColor: _purple,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              },
                              icon: Icon(isEdit ? Icons.save : Icons.add),
                              label: Text(isEdit ? 'Update' : 'Save'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _purple,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    labelController.dispose();
  }

  // ═══════════════════════════════════════════════════════
  // DELETE REASON
  // ═══════════════════════════════════════════════════════

  Future<void> _deleteReason(Map<String, dynamic> reason) async {
    if (reason['isDefault'] == 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot delete default reasons'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_forever, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete Reason?'),
          ],
        ),
        content: Text(
            'Are you sure you want to delete "${reason['label']}"?\n\nThis will hide it from the dropdown list.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await DatabaseHelper().deleteAdjustmentReason(reason['id']);
      _loadReasons();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${reason['label']}" deleted'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'UNDO',
              textColor: Colors.white,
              onPressed: () async {
                await DatabaseHelper()
                    .restoreAdjustmentReason(reason['id']);
                _loadReasons();
              },
            ),
          ),
        );
      }
    }
  }

  // ═══════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Adjustment Reasons',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: _purple,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_circle, size: 18),
                  const SizedBox(width: 6),
                  Text('Add (${_addReasons.length})'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.remove_circle, size: 18),
                  const SizedBox(width: 6),
                  Text('Deduct (${_deductReasons.length})'),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showReasonDialog(),
        backgroundColor: _purple,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Reason'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _purple))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildReasonList(_addReasons, 'add'),
                _buildReasonList(_deductReasons, 'deduct'),
              ],
            ),
    );
  }

  Widget _buildReasonList(List<Map<String, dynamic>> reasons, String type) {
    final color = type == 'add' ? _addColor : _deductColor;

    if (reasons.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(
              'No ${type == 'add' ? 'add stock' : 'deduct stock'} reasons yet.',
              style: TextStyle(fontSize: 15, color: Colors.grey[500]),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap + to add one.',
              style: TextStyle(fontSize: 13, color: Colors.grey[400]),
            ),
            const SizedBox(height: 80),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
      itemCount: reasons.length,
      itemBuilder: (_, i) {
        final r = reasons[i];
        final isDefault = r['isDefault'] == 1;
        return Card(
          elevation: 1,
          margin: const EdgeInsets.only(bottom: 8),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.1),
              child:
                  Icon(getReasonIcon(r['iconName']), color: color, size: 22),
            ),
            title: Text(
              r['label'] ?? '',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Row(
              children: [
                Text(
                  type == 'add' ? 'Add Stock' : 'Deduct Stock',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
                if (isDefault) ...
                [
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _purple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _purple.withValues(alpha: 0.3), width: 1),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star, size: 10, color: _purple),
                        SizedBox(width: 3),
                        Text(
                          'Default',
                          style: TextStyle(
                            fontSize: 9,
                            color: _purple,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  color: _purple,
                  tooltip: 'Edit',
                  onPressed: () => _showReasonDialog(existing: r),
                ),
                IconButton(
                  icon: Icon(
                    Icons.delete,
                    size: 20,
                    color: isDefault ? Colors.grey[300] : Colors.red,
                  ),
                  tooltip: isDefault ? 'Cannot delete default' : 'Delete',
                  onPressed: () => _deleteReason(r),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
