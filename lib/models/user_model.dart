// lib/models/user_model.dart
import 'dart:convert';
import '../helpers/database_helper.dart';
import '../helpers/sync_bridge.dart';
import '../models/sync_queue_model.dart';

class AppUser {
  final String id;
  final String name;
  final String username;
  final String pin;
  final String email;
  final String phone;
  final String role;
  final String branch;
  final bool isActive;
  final bool biometricEnabled;
  final bool biometricEnrolled;
  final String preferredBiometricType;
  final DateTime? lastBiometricVerifiedAt;
  final DateTime joinDate;
  final DateTime? lastLogin;
  final List<String> permissions;
  // Soft delete + sync fields (added Phase 1)
  final bool isDeleted;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  final String deletedBy;
  final String deletedReason;
  final bool allowPosTransaction;

  AppUser({
    required this.id, required this.name, required this.username,
    required this.pin, this.biometricEnabled = false, this.biometricEnrolled = false, this.preferredBiometricType = 'face', this.lastBiometricVerifiedAt, this.email = '', this.phone = '',
    required this.role, required this.branch, this.isActive = true,
    required this.joinDate, this.lastLogin, List<String>? permissions,
    this.allowPosTransaction = false,
    this.isDeleted = false,
    this.updatedAt,
    this.deletedAt,
    this.deletedBy = '',
    this.deletedReason = '',
  }) : permissions = permissions ?? rolePresets[role] ?? [];

  static const List<String> allModules = [
    'Dashboard', 'Cashiering', 'Inventory', 'Stock Adjustment',
    'Stock Transfer', 'Receive Delivery', 'Item Ledger', 'Batch Management',
    'Sales History', 'Sales Analytics', 'Z Report', 'Discount Monitoring',
    'Customers', 'Branches', 'Users', 'Settings', 'Expenses', 'Profit & Loss',
  ];

  static const Map<String, List<String>> moduleCategories = {
    'Sales': ['Dashboard', 'Cashiering', 'Sales History'],
    'Reports': ['Sales Analytics', 'Z Report', 'Discount Monitoring', 'Profit & Loss'],
    'Inventory': ['Inventory', 'Stock Adjustment', 'Stock Transfer', 'Receive Delivery', 'Item Ledger', 'Batch Management'],
    'Management': ['Customers', 'Branches', 'Users', 'Settings', 'Expenses'],
    'Cashier Locking': ['End Shift', 'Cashier Report', 'Tab: Cashier', 'Tab: Inventory', 'Tab: Reports'],
  };

  static const Map<String, List<String>> rolePresets = {
    'Admin': ['Dashboard', 'Cashiering', 'Inventory', 'Stock Adjustment', 'Stock Transfer', 'Receive Delivery', 'Item Ledger', 'Batch Management', 'Sales History', 'Sales Analytics', 'Z Report', 'Discount Monitoring', 'Customers', 'Branches', 'Users', 'Settings', 'Expenses', 'Profit & Loss', 'End Shift', 'Cashier Report', 'Tab: Cashier', 'Tab: Inventory', 'Tab: Reports'],
    'Manager': ['Dashboard', 'Cashiering', 'Users', 'Inventory', 'Stock Adjustment', 'Stock Transfer', 'Receive Delivery', 'Item Ledger', 'Batch Management', 'Sales History', 'Sales Analytics', 'Z Report', 'Discount Monitoring', 'Customers', 'Branches', 'Expenses', 'Profit & Loss', 'End Shift', 'Cashier Report', 'Tab: Cashier', 'Tab: Inventory', 'Tab: Reports'],
    'Cashier': ['Dashboard', 'Cashiering', 'Sales History', 'End Shift', 'Tab: Cashier'],
    'Inventory Clerk': ['Dashboard', 'Inventory', 'Stock Adjustment', 'Stock Transfer', 'Receive Delivery', 'Item Ledger', 'Batch Management', 'Tab: Inventory'],
    'Custom': [],
  };

  static const List<String> availableRoles = ['Admin', 'Manager', 'Cashier', 'Inventory Clerk', 'Custom'];

  bool hasPermission(String module) => permissions.contains(module);

  AppUser copyWith({String? id, String? name, String? username, String? pin, bool? biometricEnabled, bool? biometricEnrolled, String? preferredBiometricType, DateTime? lastBiometricVerifiedAt,
    String? email, String? phone, String? role, String? branch,
    bool? isActive, DateTime? joinDate, DateTime? lastLogin, List<String>? permissions}) {
    return AppUser(id: id ?? this.id, name: name ?? this.name,
      username: username ?? this.username, pin: pin ?? this.pin,
      email: email ?? this.email, phone: phone ?? this.phone,
      role: role ?? this.role, branch: branch ?? this.branch,
      isActive: isActive ?? this.isActive, joinDate: joinDate ?? this.joinDate,
      lastLogin: lastLogin ?? this.lastLogin, permissions: permissions ?? this.permissions,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled, biometricEnrolled: biometricEnrolled ?? this.biometricEnrolled,
      preferredBiometricType: preferredBiometricType ?? this.preferredBiometricType, lastBiometricVerifiedAt: lastBiometricVerifiedAt ?? this.lastBiometricVerifiedAt);
  }

  // ══════════ SQLite Serialization ══════════

  Map<String, dynamic> toMap() => {
    'id': id, 'username': username, 'password': pin,
    'fullName': name, 'role': role, 'branch': branch,
    'pin': pin, 'isActive': isActive ? 1 : 0,
    'dateCreated': joinDate.toIso8601String(),
    'email': email, 'phone': phone,
    'lastLogin': lastLogin?.toIso8601String(),
    'permissions': jsonEncode(permissions),
    'biometricEnabled': biometricEnabled ? 1 : 0,
    'biometricEnrolled': biometricEnrolled ? 1 : 0,
    'preferredBiometricType': preferredBiometricType,
    'lastBiometricVerifiedAt': lastBiometricVerifiedAt?.toIso8601String(),
    'isDeleted': isDeleted ? 1 : 0,
    'updatedAt': updatedAt?.toIso8601String() ?? DateTime.now().toUtc().toIso8601String(),
    'deletedAt': deletedAt?.toIso8601String() ?? '',
    'deletedBy': deletedBy,
    'deletedReason': deletedReason,
  };

  factory AppUser.fromMap(Map<String, dynamic> m) {
    List<String> perms = [];
    try {
      final p = m['permissions'];
      if (p != null && p is String && p.isNotEmpty) {
        perms = List<String>.from(jsonDecode(p));
      }
    } catch (_) {}
    final role = m['role'] ?? 'cashier';
    if (perms.isEmpty) perms = rolePresets[role] ?? [];

    return AppUser(
      id: m['id'] ?? '',
      name: m['fullName'] ?? '',
      username: m['username'] ?? '',
      pin: m['pin'] ?? m['password'] ?? '',
      email: m['email'] ?? '',
      phone: m['phone'] ?? '',
      role: role,
      branch: m['branch'] ?? '',
      isActive: (m['isActive'] ?? 1) == 1,
      joinDate: DateTime.tryParse(m['dateCreated'] ?? '') ?? DateTime.now(),
      lastLogin: m['lastLogin'] != null ? DateTime.tryParse(m['lastLogin']) : null,
      permissions: perms,
      biometricEnabled: (m['biometricEnabled'] ?? 0) == 1,
      biometricEnrolled: (m['biometricEnrolled'] ?? 0) == 1,
      preferredBiometricType: m['preferredBiometricType'] ?? 'face',
      lastBiometricVerifiedAt: m['lastBiometricVerifiedAt'] != null ? DateTime.tryParse(m['lastBiometricVerifiedAt']) : null,
      isDeleted: (m['isDeleted'] ?? 0) == 1,
      updatedAt: m['updatedAt'] != null && m['updatedAt'].toString().isNotEmpty
        ? DateTime.tryParse(m['updatedAt']) : null,
      deletedAt: m['deletedAt'] != null && m['deletedAt'].toString().isNotEmpty
        ? DateTime.tryParse(m['deletedAt']) : null,
      deletedBy: m['deletedBy'] ?? '',
      deletedReason: m['deletedReason'] ?? '',
    );
  }

  // ══════════ In-Memory Cache + SQLite Backend ══════════

  static List<AppUser> _allUsers = [];
  static bool _loaded = false;

  static List<AppUser> get allUsers {
    if (!_loaded && _allUsers.isEmpty) {
      _allUsers = [];
    }
    return _allUsers;
  }

  static Future<void> loadFromDB() async {
    final db = DatabaseHelper();
    final rows = await db.getAllUsers();
    if (rows.isEmpty) {
      _allUsers = [];
    } else {
      _allUsers = rows.map((r) => AppUser.fromMap(r)).toList();
    }
    _loaded = true;
  }

  static void addUser(AppUser u) {
    _allUsers = allUsers;
    _allUsers.insert(0, u);
    DatabaseHelper().insertUser(u.toMap()).catchError((_) => 0);
    SyncBridge.enqueueUser(u, op: SyncOp.create);
  }

  static void updateUser(String id, AppUser u) {
    final i = _allUsers.indexWhere((x) => x.id == id);
    if (i >= 0) _allUsers[i] = u;
    DatabaseHelper().updateUser(id, u.toMap()).catchError((_) => 0);
    SyncBridge.enqueueUser(u, op: SyncOp.update);
  }

  static void deleteUser(String id) {
    _allUsers.removeWhere((u) => u.id == id);
    DatabaseHelper().deleteUser(id).catchError((_) => 0);
    final removed = _allUsers.firstWhere((x) => x.id == id, orElse: () => AppUser(id: id, name: "", username: "", pin: "", role: "Cashier", branch: "", joinDate: DateTime.now()));
    SyncBridge.enqueueUser(removed, op: SyncOp.delete);
  }

  // ══════════ Sample Data ══════════

  static List<AppUser> getSampleUsers() {
    final now = DateTime.now();
    return [
      AppUser(id: 'USR-001', name: 'Flaviano Dagondon Jr.', username: 'admin',
        pin: '1234', email: 'admin@quickpos.com', phone: '09171234567',
        role: 'Admin', branch: 'Main Branch',
        joinDate: now.subtract(const Duration(days: 365)),
        lastLogin: now.subtract(const Duration(minutes: 30))),
      AppUser(id: 'USR-002', name: 'Maria Santos', username: 'maria',
        pin: '5678', email: 'maria@quickpos.com', phone: '09281234567',
        role: 'Manager', branch: 'Main Branch',
        joinDate: now.subtract(const Duration(days: 300)),
        lastLogin: now.subtract(const Duration(hours: 2))),
      AppUser(id: 'USR-003', name: 'Juan Dela Cruz', username: 'juan',
        pin: '1111', phone: '09351234567',
        role: 'Cashier', branch: 'Main Branch',
        joinDate: now.subtract(const Duration(days: 200)),
        lastLogin: now.subtract(const Duration(hours: 1))),
      AppUser(id: 'USR-004', name: 'Ana Reyes', username: 'ana',
        pin: '2222', email: 'ana@quickpos.com',
        role: 'Cashier', branch: 'Branch 2',
        joinDate: now.subtract(const Duration(days: 150)),
        lastLogin: now.subtract(const Duration(hours: 5))),
      AppUser(id: 'USR-005', name: 'Pedro Garcia', username: 'pedro',
        pin: '3333', phone: '09451234567',
        role: 'Inventory Clerk', branch: 'Main Branch',
        joinDate: now.subtract(const Duration(days: 180)),
        lastLogin: now.subtract(const Duration(days: 1))),
      AppUser(id: 'USR-006', name: 'Lisa Mendoza', username: 'lisa',
        pin: '4444', email: 'lisa@quickpos.com',
        role: 'Manager', branch: 'Branch 2',
        joinDate: now.subtract(const Duration(days: 100)),
        lastLogin: now.subtract(const Duration(hours: 3))),
      AppUser(id: 'USR-007', name: 'Carlo Tan', username: 'carlo',
        pin: '5555', role: 'Cashier', branch: 'Branch 3', isActive: false,
        joinDate: now.subtract(const Duration(days: 90))),
      AppUser(id: 'USR-008', name: 'Grace Lim', username: 'grace',
        pin: '6666', email: 'grace@quickpos.com', phone: '09551234567',
        role: 'Inventory Clerk', branch: 'Branch 2',
        joinDate: now.subtract(const Duration(days: 60)),
        lastLogin: now.subtract(const Duration(days: 2))),
    ];
  }
}
