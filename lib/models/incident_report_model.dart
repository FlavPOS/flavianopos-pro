// lib/models/incident_report_model.dart

class IncidentReport {
  final String id;
  final String irNumber;
  final String sessionId;
  final String cashierId;
  final String cashierName;
  final String branch;
  final double variance;
  final String varianceType;  // 'short' or 'over'
  final String reason;
  final String remarks;
  final String attachmentPath;
  final String createdBy;
  final DateTime createdAt;
  final String approvedBy;
  final DateTime? approvedAt;
  final String status;  // 'pending', 'approved', 'rejected'

  IncidentReport({
    required this.id, required this.irNumber, required this.sessionId,
    this.cashierId = '', this.cashierName = '', this.branch = '',
    required this.variance, required this.varianceType,
    this.reason = '', this.remarks = '', this.attachmentPath = '',
    this.createdBy = '', required this.createdAt,
    this.approvedBy = '', this.approvedAt,
    this.status = 'pending',
  });

  Map<String, dynamic> toMap() => {
    'id': id, 'irNumber': irNumber, 'sessionId': sessionId,
    'cashierId': cashierId, 'cashierName': cashierName, 'branch': branch,
    'variance': variance, 'varianceType': varianceType,
    'reason': reason, 'remarks': remarks, 'attachmentPath': attachmentPath,
    'createdBy': createdBy, 'createdAt': createdAt.toIso8601String(),
    'approvedBy': approvedBy, 'approvedAt': approvedAt?.toIso8601String(),
    'status': status,
  };

  factory IncidentReport.fromMap(Map<String, dynamic> m) => IncidentReport(
    id: m['id'] ?? '', irNumber: m['irNumber'] ?? '',
    sessionId: m['sessionId'] ?? '',
    cashierId: m['cashierId'] ?? '', cashierName: m['cashierName'] ?? '',
    branch: m['branch'] ?? '',
    variance: (m['variance'] as num?)?.toDouble() ?? 0,
    varianceType: m['varianceType'] ?? '',
    reason: m['reason'] ?? '', remarks: m['remarks'] ?? '',
    attachmentPath: m['attachmentPath'] ?? '',
    createdBy: m['createdBy'] ?? '',
    createdAt: DateTime.tryParse(m['createdAt'] ?? '') ?? DateTime.now(),
    approvedBy: m['approvedBy'] ?? '',
    approvedAt: m['approvedAt'] != null && m['approvedAt'].toString().isNotEmpty
      ? DateTime.tryParse(m['approvedAt']) : null,
    status: m['status'] ?? 'pending',
  );

  static String generateIRNumber() {
    final now = DateTime.now();
    final dateStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final ts = '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    return 'IR-$dateStr-$ts';
  }
}
