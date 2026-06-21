import 'dart:convert';

/// Step 4 — SyncQueueItem
/// Represents one pending Firebase upload waiting to be processed.
class SyncQueueItem {
  final int? id;
  final String queueId;
  final String entityType;
  final String entityId;
  final String operation;
  final String firebasePath;
  final String payloadJson;
  final String status;
  final int retryCount;
  final String? errorMessage;
  final String companyId;
  final String branchId;
  final String deviceId;
  final String createdAt;
  final String updatedAt;
  final String? lastAttemptAt;
  final int priority;

  const SyncQueueItem({
    this.id,
    required this.queueId,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.firebasePath,
    required this.payloadJson,
    this.status = 'pending',
    this.retryCount = 0,
    this.errorMessage,
    this.companyId = '',
    this.branchId = '',
    this.deviceId = '',
    required this.createdAt,
    required this.updatedAt,
    this.lastAttemptAt,
    this.priority = 0,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'queueId': queueId,
        'entityType': entityType,
        'entityId': entityId,
        'operation': operation,
        'firebasePath': firebasePath,
        'payloadJson': payloadJson,
        'status': status,
        'retryCount': retryCount,
        'errorMessage': errorMessage,
        'companyId': companyId,
        'branchId': branchId,
        'deviceId': deviceId,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'lastAttemptAt': lastAttemptAt,
        'priority': priority,
      };

  factory SyncQueueItem.fromMap(Map<String, dynamic> m) => SyncQueueItem(
        id: m['id'] as int?,
        queueId: (m['queueId'] ?? '').toString(),
        entityType: (m['entityType'] ?? '').toString(),
        entityId: (m['entityId'] ?? '').toString(),
        operation: (m['operation'] ?? '').toString(),
        firebasePath: (m['firebasePath'] ?? '').toString(),
        payloadJson: (m['payloadJson'] ?? '').toString(),
        status: (m['status'] ?? 'pending').toString(),
        retryCount: (m['retryCount'] as int?) ?? 0,
        errorMessage: m['errorMessage']?.toString(),
        companyId: (m['companyId'] ?? '').toString(),
        branchId: (m['branchId'] ?? '').toString(),
        deviceId: (m['deviceId'] ?? '').toString(),
        createdAt: (m['createdAt'] ?? '').toString(),
        updatedAt: (m['updatedAt'] ?? '').toString(),
        lastAttemptAt: m['lastAttemptAt']?.toString(),
        priority: (m['priority'] as int?) ?? 0,
      );

  Map<String, dynamic> payloadDecoded() {
    if (payloadJson.isEmpty) return {};
    try {
      final v = jsonDecode(payloadJson);
      if (v is Map<String, dynamic>) return v;
    } catch (_) {}
    return {};
  }
}

/// Operation constants
class SyncOp {
  static const String create = 'create';
  static const String update = 'update';
  static const String delete = 'delete';
  static const String softDelete = 'softDelete';
  static const String receiveTransfer = 'receiveTransfer';
  static const String inventoryAdjust = 'inventoryAdjust';
  static const String approveAdjustment = 'approveAdjustment';
  static const String rejectAdjustment = 'rejectAdjustment';
}

/// Status constants
class SyncStatus {
  static const String pending = 'pending';
  static const String processing = 'processing';
  static const String synced = 'synced';
  static const String failed = 'failed';
  static const String conflict = 'conflict';
}

/// Priority levels (lower number = higher priority)
class SyncPriority {
  /// Company, Main Branch, Branches, Users, Roles, Permissions
  static const int p1Critical = 1;

  /// Products, Categories, Units, Reasons, Batches
  static const int p2MasterData = 2;

  /// Stock movements, adjustments, transfers, inbound
  static const int p3Stock = 3;

  /// Sales, expenses, reports
  static const int p4Transactional = 4;
}
