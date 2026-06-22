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
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SyncStatusScreen()),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color, width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 16, color: color),
                    const SizedBox(width: 6),
                    Text(
                      info.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
