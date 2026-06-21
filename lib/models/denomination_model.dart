// lib/models/denomination_model.dart

class DenominationRecord {
  final int? id;
  final String sessionId;
  final String type;  // 'beginning' or 'ending'
  final double denomination;
  final int quantity;
  final double total;
  final DateTime createdAt;

  DenominationRecord({
    this.id, required this.sessionId, this.type = 'ending',
    required this.denomination, this.quantity = 0,
    required this.total, required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'sessionId': sessionId, 'type': type,
    'denomination': denomination, 'quantity': quantity,
    'total': total, 'createdAt': createdAt.toIso8601String(),
  };

  factory DenominationRecord.fromMap(Map<String, dynamic> m) => DenominationRecord(
    id: m['id'], sessionId: m['sessionId'] ?? '',
    type: m['type'] ?? 'ending',
    denomination: (m['denomination'] as num?)?.toDouble() ?? 0,
    quantity: m['quantity'] ?? 0,
    total: (m['total'] as num?)?.toDouble() ?? 0,
    createdAt: DateTime.tryParse(m['createdAt'] ?? '') ?? DateTime.now(),
  );

  // PH currency denominations (Q3: A - ALL)
  static const List<double> phDenominations = [
    1000, 500, 200, 100, 50, 20,  // Bills
    10, 5, 1,                       // Major coins
    0.25, 0.10, 0.05,              // Minor coins
  ];

  static String labelFor(double denom) {
    if (denom >= 1) return '₱${denom.toInt()}';
    return '₱${denom.toStringAsFixed(2)}';
  }
}
