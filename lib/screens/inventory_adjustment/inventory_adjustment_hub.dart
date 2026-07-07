import 'package:flutter/material.dart';
import 'adjustment_prepared_screen.dart';
import 'adjustment_draft_screen.dart';
import 'adjustment_submitted_screen.dart';
import 'adjustment_approved_screen.dart';
import 'adjustment_rejected_screen.dart';

/// Main Hub for Inventory Adjustment module.
/// Shows 5 workflow cards: Prepared, Draft, Submitted, Approved, Rejected.
class InventoryAdjustmentHub extends StatefulWidget {
  final String branch;
  final String userName;

  const InventoryAdjustmentHub({
    super.key,
    required this.branch,
    required this.userName,
  });

  @override
  State<InventoryAdjustmentHub> createState() => _InventoryAdjustmentHubState();
}

class _InventoryAdjustmentHubState extends State<InventoryAdjustmentHub> {
  // Counts (to be wired to real data later)
  int _preparedCount = 0;
  int _draftCount = 0;
  int _submittedCount = 0;
  int _approvedCount = 0;
  int _rejectedCount = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF6A3AF5),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.inventory_2_rounded, size: 22),
            const SizedBox(width: 8),
            const Text(
              'INVENTORY ADJUSTMENT',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildCard(
              icon: Icons.assignment_rounded,
              iconColor: const Color(0xFFF59E0B),
              iconBg: const Color(0xFFFEF3C7),
              title: 'Prepared Adjustment',
              subtitle: 'Prepare and review inventory adjustments before submission.',
              count: _preparedCount,
              countColor: const Color(0xFFF59E0B),
              onTap: () => _open(const AdjustmentPreparedScreen()),
            ),
            const SizedBox(height: 12),
            _buildCard(
              icon: Icons.description_rounded,
              iconColor: const Color(0xFF8B5CF6),
              iconBg: const Color(0xFFEDE9FE),
              title: 'Draft',
              subtitle: 'Save adjustments as draft and continue later.',
              count: _draftCount,
              countColor: const Color(0xFF8B5CF6),
              onTap: () => _open(const AdjustmentDraftScreen()),
            ),
            const SizedBox(height: 12),
            _buildCard(
              icon: Icons.send_rounded,
              iconColor: const Color(0xFF3B82F6),
              iconBg: const Color(0xFFDBEAFE),
              title: 'Submitted',
              subtitle: 'View adjustments that are submitted and awaiting approval.',
              count: _submittedCount,
              countColor: const Color(0xFF3B82F6),
              onTap: () => _open(const AdjustmentSubmittedScreen()),
            ),
            const SizedBox(height: 12),
            _buildCard(
              icon: Icons.check_circle_rounded,
              iconColor: const Color(0xFF22C55E),
              iconBg: const Color(0xFFDCFCE7),
              title: 'Approved',
              subtitle: 'View all inventory adjustments that have been approved.',
              count: _approvedCount,
              countColor: const Color(0xFF22C55E),
              onTap: () => _open(const AdjustmentApprovedScreen()),
            ),
            const SizedBox(height: 12),
            _buildCard(
              icon: Icons.cancel_rounded,
              iconColor: const Color(0xFFEF4444),
              iconBg: const Color(0xFFFEE2E2),
              title: 'Rejected',
              subtitle: 'View all inventory adjustments that have been rejected.',
              count: _rejectedCount,
              countColor: const Color(0xFFEF4444),
              onTap: () => _open(const AdjustmentRejectedScreen()),
            ),
          ],
        ),
      ),
    );
  }

  void _open(Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    ).then((_) => setState(() {}));
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
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Icon
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 26),
              ),
              const SizedBox(width: 14),
              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Count badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: countColor,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '\$count',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              // Chevron
              Icon(
                Icons.chevron_right_rounded,
                color: countColor,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
