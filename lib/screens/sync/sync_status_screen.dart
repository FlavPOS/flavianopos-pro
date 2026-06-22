import 'package:flutter/material.dart';
import '../../helpers/sync_queue_dao.dart';
import '../../models/sync_queue_model.dart';
import '../../services/sync_manager.dart';

class SyncStatusScreen extends StatefulWidget {
  const SyncStatusScreen({super.key});
  @override
  State<SyncStatusScreen> createState() => _SyncStatusScreenState();
}

class _SyncStatusScreenState extends State<SyncStatusScreen> {
  static const Color _purple = Color(0xFF6A1B9A);
  List<SyncQueueItem> _items = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final items = await SyncQueueDao().getAll(limit: 100);
    if (mounted) setState(() { _items = items; _loading = false; });
  }

  Future<void> _syncNow() async {
    await SyncManager.instance.syncNow();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _purple, foregroundColor: Colors.white,
        title: const Text('Sync Status'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Sync Now',
            onPressed: _syncNow,
          ),
        ],
      ),
      body: ValueListenableBuilder<SyncStatusInfo>(
        valueListenable: SyncManager.instance.status,
        builder: (context, info, _) => Column(children: [
          Container(
            padding: const EdgeInsets.all(16), color: _purple.withValues(alpha: 0.08),
            child: Row(children: [
              Icon(info.online ? Icons.cloud_done : Icons.cloud_off,
                  size: 36, color: info.online ? Colors.green : Colors.red),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(info.label, style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
                  if (info.lastSyncAt != null)
                    Text('Last sync: ${info.lastSyncAt!.toLocal()}',
                        style: const TextStyle(fontSize: 11, color: Colors.black54)),
                ],
              )),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: _purple, foregroundColor: Colors.white),
                onPressed: _syncNow,
                icon: const Icon(Icons.sync, size: 16),
                label: const Text('Sync Now'),
              ),
            ]),
          ),
          Expanded(child: _loading
            ? const Center(child: CircularProgressIndicator(color: _purple))
            : _items.isEmpty
              ? const Center(child: Text('No sync activity yet.'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final q = _items[i];
                      final c = q.status == SyncStatus.synced ? Colors.green
                              : q.status == SyncStatus.failed ? Colors.red
                              : q.status == SyncStatus.processing ? Colors.blue
                              : Colors.orange;
                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          backgroundColor: c.withValues(alpha: 0.15), radius: 18,
                          child: Icon(_iconFor(q.status), color: c, size: 18),
                        ),
                        title: Text('${q.entityType} · ${q.operation}',
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          '${q.firebasePath}\n${q.status} · retries: ${q.retryCount}'
                          '${q.errorMessage != null ? "\n${q.errorMessage}" : ""}',
                          style: const TextStyle(fontSize: 11),
                        ),
                        isThreeLine: true,
                      );
                    },
                  ),
                ),
          ),
        ]),
      ),
    );
  }

  IconData _iconFor(String status) {
    switch (status) {
      case SyncStatus.synced: return Icons.check;
      case SyncStatus.failed: return Icons.error_outline;
      case SyncStatus.processing: return Icons.sync;
      default: return Icons.schedule;
    }
  }
}
