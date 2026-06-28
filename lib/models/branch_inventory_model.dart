// lib/models/branch_inventory_model.dart
// BRANCH INVENTORY V2 - per-branch stock tracking

class BranchInventory {
  final String branchId;
  final String productId;
  final int stockQty;
  final int reservedQty;
  final int inTransitInQty;
  final int inTransitOutQty;
  final int reorderLevel;
  final DateTime lastUpdated;
  final DateTime updatedAt;
  final String deviceId;
  final bool isDeleted;
  final bool isMigrated;

  BranchInventory({
    required this.branchId,
    required this.productId,
    this.stockQty = 0,
    this.reservedQty = 0,
    this.inTransitInQty = 0,
    this.inTransitOutQty = 0,
    this.reorderLevel = 5,
    required this.lastUpdated,
    required this.updatedAt,
    this.deviceId = '',
    this.isDeleted = false,
    this.isMigrated = false,
  });

  // Computed properties
  int get availableQty => stockQty - reservedQty;
  int get branchTotalQty => stockQty + inTransitInQty;
  bool get isLowStock => stockQty <= reorderLevel;
  bool get isOutOfStock => stockQty == 0;
  bool get hasInTransit => inTransitInQty > 0 || inTransitOutQty > 0;

  // SQLite serialization
  Map<String, dynamic> toMap() => {
    'branchId': branchId,
    'productId': productId,
    'stockQty': stockQty,
    'reservedQty': reservedQty,
    'inTransitInQty': inTransitInQty,
    'inTransitOutQty': inTransitOutQty,
    'reorderLevel': reorderLevel,
    'lastUpdated': lastUpdated.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'deviceId': deviceId,
    'isDeleted': isDeleted ? 1 : 0,
    'isMigrated': isMigrated ? 1 : 0,
  };

  factory BranchInventory.fromMap(Map<String, dynamic> m) => BranchInventory(
    branchId: m['branchId']?.toString() ?? '',
    productId: m['productId']?.toString() ?? '',
    stockQty: (m['stockQty'] as num?)?.toInt() ?? 0,
    reservedQty: (m['reservedQty'] as num?)?.toInt() ?? 0,
    inTransitInQty: (m['inTransitInQty'] as num?)?.toInt() ?? 0,
    inTransitOutQty: (m['inTransitOutQty'] as num?)?.toInt() ?? 0,
    reorderLevel: (m['reorderLevel'] as num?)?.toInt() ?? 5,
    lastUpdated: DateTime.tryParse(m['lastUpdated']?.toString() ?? '') ?? DateTime.now(),
    updatedAt: DateTime.tryParse(m['updatedAt']?.toString() ?? '') ?? DateTime.now(),
    deviceId: m['deviceId']?.toString() ?? '',
    isDeleted: (m['isDeleted'] as num?)?.toInt() == 1,
    isMigrated: (m['isMigrated'] as num?)?.toInt() == 1,
  );

  BranchInventory copyWith({
    String? branchId,
    String? productId,
    int? stockQty,
    int? reservedQty,
    int? inTransitInQty,
    int? inTransitOutQty,
    int? reorderLevel,
    DateTime? lastUpdated,
    DateTime? updatedAt,
    String? deviceId,
    bool? isDeleted,
    bool? isMigrated,
  }) => BranchInventory(
    branchId: branchId ?? this.branchId,
    productId: productId ?? this.productId,
    stockQty: stockQty ?? this.stockQty,
    reservedQty: reservedQty ?? this.reservedQty,
    inTransitInQty: inTransitInQty ?? this.inTransitInQty,
    inTransitOutQty: inTransitOutQty ?? this.inTransitOutQty,
    reorderLevel: reorderLevel ?? this.reorderLevel,
    lastUpdated: lastUpdated ?? this.lastUpdated,
    updatedAt: updatedAt ?? this.updatedAt,
    deviceId: deviceId ?? this.deviceId,
    isDeleted: isDeleted ?? this.isDeleted,
    isMigrated: isMigrated ?? this.isMigrated,
  );

  @override
  String toString() => 'BranchInventory($branchId/$productId stock=$stockQty migrated=$isMigrated)';
}
