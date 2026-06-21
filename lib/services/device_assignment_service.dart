import 'package:shared_preferences/shared_preferences.dart';

class DeviceAssignmentService {
  static const _kCompanyId = 'assignedCompanyId';
  static const _kCompanyCode = 'assignedCompanyCode';
  static const _kBranchId = 'assignedBranchId';
  static const _kBranchName = 'assignedBranchName';
  static const _kRole = 'assignedDeviceRole';
  static const _kAssignedAt = 'assignedAt';

  Future<void> assign({
    required String companyId,
    required String companyCode,
    required String branchId,
    required String branchName,
    String role = 'cashier',
  }) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kCompanyId, companyId);
    await p.setString(_kCompanyCode, companyCode);
    await p.setString(_kBranchId, branchId);
    await p.setString(_kBranchName, branchName);
    await p.setString(_kRole, role);
    await p.setString(_kAssignedAt, DateTime.now().toUtc().toIso8601String());
  }

  Future<Map<String, String?>> read() async {
    final p = await SharedPreferences.getInstance();
    return {
      'companyId': p.getString(_kCompanyId),
      'companyCode': p.getString(_kCompanyCode),
      'branchId': p.getString(_kBranchId),
      'branchName': p.getString(_kBranchName),
      'role': p.getString(_kRole),
      'assignedAt': p.getString(_kAssignedAt),
    };
  }

  Future<bool> isAssigned() async {
    final r = await read();
    return (r['branchId'] ?? '').isNotEmpty;
  }

  Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    for (final k in [
      _kCompanyId, _kCompanyCode, _kBranchId, _kBranchName, _kRole, _kAssignedAt
    ]) {
      await p.remove(k);
    }
  }
}
