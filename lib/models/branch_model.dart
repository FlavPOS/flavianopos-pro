// lib/models/branch_model.dart
// v2 - Branch Code Architecture
// The `id` field IS the branchCode (backward compatible)
// `branchCode` is a getter alias for readability in new code

import '../helpers/database_helper.dart';
import '../helpers/sync_bridge.dart';
import 'sync_queue_model.dart';

class Branch {
  final String id;           // ⭐ THIS IS THE BRANCH CODE (BR001, HO001)
  final String name;         // Display name (Cebu Main Branch)
  final String branchType;   // ⭐ NEW: HEAD_OFFICE | WAREHOUSE | BRANCH
  final String address;
  final String phone;
  final String email;
  final String manager;
  final bool isActive;
  final DateTime createdDate;
  final int userCount;
  final double todaySales;
  final int totalProducts;
  final String? imagePath;

  Branch({
    required this.id,
    required this.name,
    this.branchType = typeBranch,
    required this.address,
    this.phone = '',
    this.email = '',
    this.manager = '',
    this.isActive = true,
    required this.createdDate,
    this.userCount = 0,
    this.todaySales = 0,
    this.totalProducts = 0,
    this.imagePath,
  });

  // ═══ Branch Type Constants ═══
  static const String typeHeadOffice = 'HEAD_OFFICE';
  static const String typeWarehouse = 'WAREHOUSE';
  static const String typeBranch = 'BRANCH';

  static const List<String> availableTypes = [
    typeBranch,
    typeHeadOffice,
    typeWarehouse,
  ];

  // ═══ Aliases for readability ═══
  String get branchCode => id;          // ⭐ NEW: alias
  String get branchName => name;         // ⭐ NEW: alias
  String get displayLabel => '$id - $name';
  bool get isHeadOffice => branchType == typeHeadOffice;
  bool get isWarehouse => branchType == typeWarehouse;
  bool get isBranch => branchType == typeBranch;

  Branch copyWith({
    String? id, String? name, String? branchType,
    String? address, String? phone,
    String? email, String? manager, bool? isActive, DateTime? createdDate,
    int? userCount, double? todaySales, int? totalProducts, String? imagePath,
  }) {
    return Branch(
      id: id ?? this.id,
      name: name ?? this.name,
      branchType: branchType ?? this.branchType,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      manager: manager ?? this.manager,
      isActive: isActive ?? this.isActive,
      createdDate: createdDate ?? this.createdDate,
      userCount: userCount ?? this.userCount,
      todaySales: todaySales ?? this.todaySales,
      totalProducts: totalProducts ?? this.totalProducts,
      imagePath: imagePath ?? this.imagePath,
    );
  }

  // ══════════ SQLite Serialization ══════════

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'branchType': branchType,      // ⭐ NEW
    'address': address,
    'phone': phone,
    'isActive': isActive ? 1 : 0,
    'email': email,
    'manager': manager,
    'createdDate': createdDate.toIso8601String(),
    'imagePath': imagePath,
  };

  factory Branch.fromMap(Map<String, dynamic> m) => Branch(
    id: m['id'] ?? '',
    name: m['name'] ?? '',
    branchType: (m['branchType'] ?? typeBranch).toString(),   // ⭐ NEW
    address: m['address'] ?? '',
    phone: m['phone'] ?? '',
    email: m['email'] ?? '',
    manager: m['manager'] ?? '',
    isActive: (m['isActive'] ?? 1) == 1,
    createdDate: DateTime.tryParse(m['createdDate'] ?? '') ?? DateTime.now(),
    imagePath: m['imagePath'],
    userCount: 0, todaySales: 0, totalProducts: 0,
  );

  // ══════════ Validation Helpers ══════════

  /// Validates branch code format: BR001, HO001, WH001
  /// Rules: 3-20 chars, UPPERCASE, letters/numbers/dash/underscore only
  static String? validateBranchCode(String code) {
    if (code.isEmpty) return 'Branch Code is required';
    if (code.length < 3) return 'Branch Code must be at least 3 characters';
    if (code.length > 20) return 'Branch Code max 20 characters';
    if (code != code.toUpperCase()) return 'Branch Code must be UPPERCASE';
    if (code.contains(' ')) return 'Branch Code cannot contain spaces';
    if (!RegExp(r'^[A-Z0-9_-]+$').hasMatch(code)) {
      return 'Only letters, numbers, dash, underscore allowed';
    }
    return null;
  }

  static String? validateBranchName(String name) {
    if (name.trim().isEmpty) return 'Branch Name is required';
    if (name.trim().length < 2) return 'Branch Name too short';
    return null;
  }

  static String sanitizeBranchCode(String input) {
    return input.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9_-]'), '');
  }

  // ══════════ In-Memory Cache + SQLite Backend ══════════

  static List<Branch> _allBranches = [];
  static bool _loaded = false;

  static List<Branch> get allBranches {
    if (!_loaded && _allBranches.isEmpty) {
      _allBranches = [];
    }
    return _allBranches;
  }

  static Future<void> loadFromDB() async {
    final db = DatabaseHelper();
    final rows = await db.getAllBranches();
    if (rows.isEmpty) {
      _allBranches = [];
    } else {
      _allBranches = rows.map((r) => Branch.fromMap(r)).toList();
    }
    _loaded = true;
  }

  static void addBranch(Branch b) {
    _allBranches = allBranches;
    _allBranches.insert(0, b);
    DatabaseHelper().insertBranch(b.toMap()).catchError((_) => 0);
    SyncBridge.enqueueBranch(b, op: SyncOp.create);
  }

  static void updateBranch(String id, Branch u) {
    final i = _allBranches.indexWhere((b) => b.id == id);
    if (i >= 0) _allBranches[i] = u;
    DatabaseHelper().updateBranch(id, u.toMap()).catchError((_) => 0);
    SyncBridge.enqueueBranch(u, op: SyncOp.update);
  }

  static void deleteBranch(String id) {
    _allBranches.removeWhere((b) => b.id == id);
    DatabaseHelper().deleteBranch(id).catchError((_) => 0);
    final removed = _allBranches.firstWhere((x) => x.id == id, orElse: () => Branch(id: id, name: "", address: "", createdDate: DateTime.now()));
    SyncBridge.enqueueBranch(removed, op: SyncOp.delete);
  }

  // ══════════ Helper: Find by code ══════════
  static Branch? findByCode(String code) {
    if (code.isEmpty) return null;
    final upper = code.toUpperCase();
    for (final b in _allBranches) {
      if (b.id.toUpperCase() == upper) return b;
    }
    return null;
  }

  static bool codeExists(String code, {String? excludeId}) {
    if (code.isEmpty) return false;
    final upper = code.toUpperCase();
    for (final b in _allBranches) {
      if (b.id.toUpperCase() == upper && b.id != excludeId) return true;
    }
    return false;
  }

  static Branch? getHeadOffice() {
    for (final b in _allBranches) {
      if (b.isHeadOffice && b.isActive) return b;
    }
    return null;
  }

  static String generateNextCode({String prefix = 'BR'}) {
    int max = 0;
    final regex = RegExp('^${RegExp.escape(prefix)}0*(\d+)');
    for (final b in _allBranches) {
      final match = regex.firstMatch(b.id.toUpperCase());
      if (match != null) {
        final num = int.tryParse(match.group(1) ?? '0') ?? 0;
        if (num > max) max = num;
      }
    }
    return '$prefix${(max + 1).toString().padLeft(3, '0')}';
  }

  // ══════════ Sample Data (Updated to spec format: BR001 not BR-001) ══════════

  static List<Branch> getSampleBranches() {
    final now = DateTime.now();
    return [
      Branch(id: 'HO001', name: 'Head Office / Warehouse', branchType: typeHeadOffice, address: 'Diversion Road, Consolacion, Cebu City', phone: '09171234567', email: 'ho@quickpos.com', manager: 'Flaviano Dagondon Jr.', userCount: 3, todaySales: 0, totalProducts: 350, createdDate: now.subtract(const Duration(days: 500))),
      Branch(id: 'BR001', name: 'Cebu Main Branch', branchType: typeBranch, address: 'A.S. Fortuna St., Mandaue City, Cebu', phone: '09281234567', email: 'br001@quickpos.com', manager: 'Lisa Mendoza', userCount: 5, todaySales: 25680, totalProducts: 280, createdDate: now.subtract(const Duration(days: 300))),
      Branch(id: 'BR002', name: 'Talisay Branch', branchType: typeBranch, address: 'Tabunok, Talisay City, Cebu', phone: '09351234567', email: 'br002@quickpos.com', manager: 'Maria Santos', userCount: 3, todaySales: 12300, totalProducts: 200, createdDate: now.subtract(const Duration(days: 150))),
    ];
  }
}
