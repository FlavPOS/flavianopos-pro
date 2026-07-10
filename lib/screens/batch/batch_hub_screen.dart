import 'package:flutter/material.dart';
import '../../services/device_assignment_service.dart';
import '../../models/batch_model.dart';
import 'batch_screen.dart';
import 'add_batch_screen.dart';
import 'batch_log_screen.dart';

/// Enterprise Batch Management Hub
/// Same design pattern as Inventory Adjustment Hub
class BatchHubScreen extends StatefulWidget {
  const BatchHubScreen({super.key});

  @override
  State<BatchHubScreen> createState() => _BatchHubScreenState();
}

class _BatchHubScreenState extends State<BatchHubScreen> {
  static const _bg = Color(0xFFF5F6FA);
  static const _card = Color(0xFFFFFFFF);
  static const _textPrimary = Color(0xFF111827);
  static const _textSecondary = Color(0xFF6B7280);

  // Enterprise colors (matching Adjustment Hub)
  static const _amber = Color(0xFFF59E0B);
  static const _blue = Color(0xFF3B82F6);
  static const _green = Color(0xFF10B981);
  static const _orange = Color(0xFFF97316);
  static const _red = Color(0xFFEF4444);
  static const _gray = Color(0xFF6B7280);
  static const _purple = Color(0xFF7C3AED);

  bool _loading = true;
  String _branchId = '';

  int _totalCount = 0;
  int _freshCount = 0;
  int _warningCount = 0;
  int _nearExpiryCount = 0;
  int _expiredCount = 0;
  int _depletedCount = 0;

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    setState(() => _loading = true);
    try {
      final assign = await DeviceAssignmentService().read();
      _branchId = (assign['branchId'] ?? '').toString();
      
      await ProductBatch.loadFromDB(branchId: _branchId);
      final batches = ProductBatch.allBatches;
      
      _totalCount = batches.length;
      _freshCount = batches.where((b) => b.isFresh && b.quantity > 0).length;
      _warningCount = batches.where((b) => b.isWarning && b.quantity > 0).length;
      _nearExpiryCount = batches.where((b) => b.isNearExpiry && b.quantity > 0).length;
      _expiredCount = batches.where((b) => b.isExpired).length;
      _depletedCount = batches.where((b) => b.quantity == 0 && !b.isExpired).length;
      
      debugPrint('[BATCH-HUB] Counts: T=$_totalCount F=$_freshCount W=$_warningCount N=$_nearExpiryCount E=$_expiredCount D=$_depletedCount');
    } catch (e) {
      debugPrint('[BATCH-HUB] Load error: $e');
    }
    
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Widget _buildCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    required int count,
    required Color countColor,
    required VoidCallback onTap,
  }) {
    return Card(
      color: _card,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(title, style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: _textPrimary,
                        )),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: countColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            count.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(subtitle, style: const TextStyle(
                      fontSize: 12,
                      color: _textSecondary,
                    )),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: iconColor, size: 22),
            ],
          ),
        ),
      ),
    );
  }

  void _openBatchListWithFilter(String filter) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BatchScreen(initialFilter: filter),
      ),
    ).then((_) => _loadCounts());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _purple,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: const [
            Icon(Icons.inventory_2_rounded, size: 22),
            SizedBox(width: 8),
            Text('BATCH MANAGEMENT', style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.4,
            )),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Activity Log',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BatchLogScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _loadCounts,
          ),
        ],
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _loadCounts,
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: [
                _buildCard(
                  icon: Icons.inventory_rounded,
                  iconColor: _blue,
                  iconBg: _blue.withValues(alpha: 0.1),
                  title: 'All Batches',
                  subtitle: 'View complete batch inventory.',
                  count: _totalCount,
                  countColor: _blue,
                  onTap: () => _openBatchListWithFilter('All'),
                ),
                _buildCard(
                  icon: Icons.eco_rounded,
                  iconColor: _green,
                  iconBg: _green.withValues(alpha: 0.1),
                  title: 'Fresh',
                  subtitle: 'Batches with 90+ days to expiry.',
                  count: _freshCount,
                  countColor: _green,
                  onTap: () => _openBatchListWithFilter('Fresh'),
                ),
                _buildCard(
                  icon: Icons.access_time_rounded,
                  iconColor: _amber,
                  iconBg: _amber.withValues(alpha: 0.1),
                  title: 'Warning',
                  subtitle: 'Batches with 31-90 days to expiry.',
                  count: _warningCount,
                  countColor: _amber,
                  onTap: () => _openBatchListWithFilter('Warning'),
                ),
                _buildCard(
                  icon: Icons.warning_amber_rounded,
                  iconColor: _orange,
                  iconBg: _orange.withValues(alpha: 0.1),
                  title: 'Near Expiry',
                  subtitle: 'Batches with 30 days or less to expire.',
                  count: _nearExpiryCount,
                  countColor: _orange,
                  onTap: () => _openBatchListWithFilter('Near Expiry'),
                ),
                _buildCard(
                  icon: Icons.dangerous_rounded,
                  iconColor: _red,
                  iconBg: _red.withValues(alpha: 0.1),
                  title: 'Expired',
                  subtitle: 'Batches past their expiry date.',
                  count: _expiredCount,
                  countColor: _red,
                  onTap: () => _openBatchListWithFilter('Expired'),
                ),
                _buildCard(
                  icon: Icons.check_circle_rounded,
                  iconColor: _gray,
                  iconBg: _gray.withValues(alpha: 0.1),
                  title: 'Depleted',
                  subtitle: 'Batches with zero remaining quantity.',
                  count: _depletedCount,
                  countColor: _gray,
                  onTap: () => _openBatchListWithFilter('Depleted'),
                ),
              ],
            ),
          ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddBatchScreen()),
          );
          _loadCounts();
        },
        backgroundColor: _purple,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Batch'),
      ),
    );
  }
}
