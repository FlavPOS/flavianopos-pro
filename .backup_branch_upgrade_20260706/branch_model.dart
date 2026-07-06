// lib/models/branch_model.dart
import '../helpers/database_helper.dart';
import '../helpers/sync_bridge.dart';
import 'sync_queue_model.dart';

class Branch {
  final String id;
  final String name;
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
    required this.id, required this.name, required this.address,
    this.phone = '', this.email = '', this.manager = '',
    this.isActive = true, required this.createdDate,
    this.userCount = 0, this.todaySales = 0, this.totalProducts = 0,
    this.imagePath,
  });

  Branch copyWith({
    String? id, String? name, String? address, String? phone,
    String? email, String? manager, bool? isActive, DateTime? createdDate,
    int? userCount, double? todaySales, int? totalProducts, String? imagePath,
  }) {
    return Branch(
      id: id ?? this.id, name: name ?? this.name,
      address: address ?? this.address, phone: phone ?? this.phone,
      email: email ?? this.email, manager: manager ?? this.manager,
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
    'id': id, 'name': name, 'address': address, 'phone': phone,
    'isActive': isActive ? 1 : 0, 'email': email, 'manager': manager,
    'createdDate': createdDate.toIso8601String(), 'imagePath': imagePath,
  };

  factory Branch.fromMap(Map<String, dynamic> m) => Branch(
    id: m['id'] ?? '',
    name: m['name'] ?? '',
    address: m['address'] ?? '',
    phone: m['phone'] ?? '',
    email: m['email'] ?? '',
    manager: m['manager'] ?? '',
    isActive: (m['isActive'] ?? 1) == 1,
    createdDate: DateTime.tryParse(m['createdDate'] ?? '') ?? DateTime.now(),
    imagePath: m['imagePath'],
    // userCount, todaySales, totalProducts are computed at runtime, not stored
    userCount: 0, todaySales: 0, totalProducts: 0,
  );

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

  // ══════════ Sample Data ══════════

  static List<Branch> getSampleBranches() {
    final now = DateTime.now();
    return [
      Branch(id: 'BR-001', name: 'Main Branch', address: 'Diversion Road, Consolacion, Cebu City', phone: '09171234567', email: 'main@quickpos.com', manager: 'Flaviano Dagondon Jr.', userCount: 5, todaySales: 25680, totalProducts: 350, createdDate: now.subtract(const Duration(days: 500))),
      Branch(id: 'BR-002', name: 'Branch 2', address: 'A.S. Fortuna St., Mandaue City, Cebu', phone: '09281234567', email: 'branch2@quickpos.com', manager: 'Lisa Mendoza', userCount: 3, todaySales: 18450, totalProducts: 280, createdDate: now.subtract(const Duration(days: 300))),
      Branch(id: 'BR-003', name: 'Branch 3', address: 'Tabunok, Talisay City, Cebu', phone: '09351234567', email: 'branch3@quickpos.com', manager: 'Maria Santos', userCount: 3, todaySales: 12300, totalProducts: 200, createdDate: now.subtract(const Duration(days: 150))),
      Branch(id: 'BR-004', name: 'Branch 4', address: 'Pajo, Lapu-Lapu City, Cebu', phone: '09451234567', email: '', manager: '', isActive: false, userCount: 0, todaySales: 0, totalProducts: 0, createdDate: now.subtract(const Duration(days: 30))),
    ];
  }
}
