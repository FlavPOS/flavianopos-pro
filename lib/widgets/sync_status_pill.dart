import 'package:flutter/material.dart';
import '../services/sync_manager.dart';
import '../screens/sync/sync_status_screen.dart';

class SyncStatusPill extends StatelessWidget {
  const SyncStatusPill({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SyncStatusInfo>(
      valueListenable: SyncManager.instance.status,
      builder: (context, info, _) {
        Color color;
        IconData icon;
        if (!info.online) {
          color = Colors.red.shade700; icon = Icons.cloud_off;
        } else if (info.syncing) {
          color = Colors.blueGrey; icon = Icons.sync;
        } else if (info.failedCount > 0) {
          color = Colors.orange.shade700; icon = Icons.warning_amber;
        } else if (info.pendingCount > 0) {
          color = Colors.amber.shade800; icon = Icons.cloud_upload_outlined;
        } else {
          color = Colors.green.shade700; icon = Icons.cloud_done_outlined;
        }
        return InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SyncStatusScreen()),
          ),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 5),
              Text(info.label, style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: color)),
            ]),
          ),
        );
      },
    );
  }
}
