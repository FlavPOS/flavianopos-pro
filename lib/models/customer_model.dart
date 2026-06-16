// lib/models/customer_model.dart
import '../helpers/database_helper.dart';

class PointTransaction {
  final String id;
  final String type; // 'earned' or 'redeemed'
  final double points;
  final String description;
  final DateTime dateTime;

  PointTransaction({
    required this.id,
    required this.type,
    required this.points,
    required this.description,
    required this.dateTime,
  });
}

class Customer {
  final String id;
  final String name;
  final String phone;
  final String email;
  final double totalPoints;
  final double lifetimePoints;
  final double totalSpent;
  final int totalTransactions;
  final DateTime joinDate;
  final DateTime? birthday;
  final List<PointTransaction> pointHistory;

  Customer({
    required this.id,
    required this.name,
    required this.phone,
    this.email = '',
    this.totalPoints = 0,
    this.lifetimePoints = 0,
    this.totalSpent = 0,
    this.totalTransactions = 0,
    required this.joinDate,
    this.birthday,
    this.pointHistory = const [],
  });

  String get tier {
    if (lifetimePoints >= 5000) return 'Platinum';
    if (lifetimePoints >= 1500) return 'Gold';
    if (lifetimePoints >= 500) return 'Silver';
    return 'Regular';
  }

  String get tierEmoji {
    switch (tier) {
      case 'Platinum': return '💎';
      case 'Gold': return '🥇';
      case 'Silver': return '🥈';
      default: return '🏷';
    }
  }

  double get tierDiscount {
    switch (tier) {
      case 'Platinum': return 10.0;
      case 'Gold': return 7.0;
      case 'Silver': return 5.0;
      default: return 0.0;
    }
  }

  double get tierMultiplier {
    switch (tier) {
      case 'Platinum': return 3.0;
      case 'Gold': return 2.0;
      case 'Silver': return 1.5;
      default: return 1.0;
    }
  }

  double get pointsToNextTier {
    if (tier == 'Platinum') return 0;
    if (tier == 'Gold') return 5000 - lifetimePoints;
    if (tier == 'Silver') return 1500 - lifetimePoints;
    return 500 - lifetimePoints;
  }

  String get nextTier {
    switch (tier) {
      case 'Regular': return 'Silver';
      case 'Silver': return 'Gold';
      case 'Gold': return 'Platinum';
      default: return 'MAX';
    }
  }

  Customer copyWith({
    String? id, String? name, String? phone, String? email,
    double? totalPoints, double? lifetimePoints, double? totalSpent,
    int? totalTransactions, DateTime? joinDate, DateTime? birthday,
    List<PointTransaction>? pointHistory,
  }) {
    return Customer(
      id: id ?? this.id, name: name ?? this.name,
      phone: phone ?? this.phone, email: email ?? this.email,
      totalPoints: totalPoints ?? this.totalPoints,
      lifetimePoints: lifetimePoints ?? this.lifetimePoints,
      totalSpent: totalSpent ?? this.totalSpent,
      totalTransactions: totalTransactions ?? this.totalTransactions,
      joinDate: joinDate ?? this.joinDate, birthday: birthday ?? this.birthday,
      pointHistory: pointHistory ?? this.pointHistory,
    );
  }

  // ══════════ SQLite Serialization ══════════

  Map<String, dynamic> toMap() => {
    'id': id, 'name': name, 'phone': phone, 'email': email,
    'address': '', 'notes': '',
    'loyaltyPoints': totalPoints.toInt(),
    'totalPurchases': totalSpent,
    'dateAdded': joinDate.toIso8601String(),
    'totalPoints': totalPoints,
    'lifetimePoints': lifetimePoints,
    'totalTransactions': totalTransactions,
    'birthday': birthday?.toIso8601String(),
  };

  factory Customer.fromMap(Map<String, dynamic> m) => Customer(
    id: m['id'] ?? '',
    name: m['name'] ?? '',
    phone: m['phone'] ?? '',
    email: m['email'] ?? '',
    totalPoints: (m['totalPoints'] ?? m['loyaltyPoints'] ?? 0).toDouble(),
    lifetimePoints: (m['lifetimePoints'] ?? 0).toDouble(),
    totalSpent: (m['totalPurchases'] ?? 0).toDouble(),
    totalTransactions: m['totalTransactions'] ?? 0,
    joinDate: DateTime.tryParse(m['dateAdded'] ?? '') ?? DateTime.now(),
    birthday: m['birthday'] != null ? DateTime.tryParse(m['birthday']) : null,
    pointHistory: const [],
  );

  // ══════════ In-Memory Cache + SQLite Backend ══════════

  static List<Customer> _allCustomers = [];
  static bool _loaded = false;

  static List<Customer> get allCustomers {
    if (!_loaded && _allCustomers.isEmpty) {
      _allCustomers = [];
    }
    return _allCustomers;
  }

  static Future<void> loadFromDB() async {
    final db = DatabaseHelper();
    final rows = await db.getAllCustomers();
    if (rows.isEmpty) {
      _allCustomers = [];
    } else {
      _allCustomers = rows.map((r) => Customer.fromMap(r)).toList();
    }

    _loaded = true;
  }

  static void addCustomer(Customer c) {
    _allCustomers = allCustomers;
    _allCustomers.insert(0, c);
    DatabaseHelper().insertCustomer(c.toMap()).catchError((_) => 0);
  }

  static void updateCustomer(String id, Customer c) {
    final index = _allCustomers.indexWhere((x) => x.id == id);
    if (index >= 0) _allCustomers[index] = c;
    DatabaseHelper().updateCustomer(id, c.toMap()).catchError((_) => 0);
  }

  static void removeCustomer(String id) {
    _allCustomers.removeWhere((c) => c.id == id);
    DatabaseHelper().deleteCustomer(id).catchError((_) => 0);
  }

  // ══════════ Sample Data ══════════

  static List<Customer> getSampleCustomers() {
    final now = DateTime.now();
    return [
      Customer(
        id: 'CUST-001', name: 'Maria Santos', phone: '09171234567',
        email: 'maria.santos@email.com', totalPoints: 1250, lifetimePoints: 5200,
        totalSpent: 52000, totalTransactions: 85,
        joinDate: now.subtract(const Duration(days: 365)),
        birthday: DateTime(1990, 3, 15),
        pointHistory: [
          PointTransaction(id: 'PT-001', type: 'earned', points: 35, description: 'Purchase TXN-001 (3500)', dateTime: now.subtract(const Duration(hours: 2))),
          PointTransaction(id: 'PT-002', type: 'redeemed', points: 100, description: 'Redeemed 10 discount', dateTime: now.subtract(const Duration(days: 1))),
          PointTransaction(id: 'PT-003', type: 'earned', points: 50, description: 'Birthday Bonus Points', dateTime: now.subtract(const Duration(days: 5))),
          PointTransaction(id: 'PT-004', type: 'earned', points: 28, description: 'Purchase TXN-045 (2800)', dateTime: now.subtract(const Duration(days: 7))),
        ],
      ),
      Customer(
        id: 'CUST-002', name: 'Juan Dela Cruz', phone: '09281234567',
        email: 'juan.dc@email.com', totalPoints: 820, lifetimePoints: 1800,
        totalSpent: 18000, totalTransactions: 42,
        joinDate: now.subtract(const Duration(days: 200)),
        birthday: DateTime(1985, 7, 22),
        pointHistory: [
          PointTransaction(id: 'PT-005', type: 'earned', points: 15, description: 'Purchase TXN-089 (1500)', dateTime: now.subtract(const Duration(hours: 5))),
        ],
      ),
      Customer(
        id: 'CUST-003', name: 'Ana Reyes', phone: '09351234567',
        email: '', totalPoints: 350, lifetimePoints: 680,
        totalSpent: 6800, totalTransactions: 18,
        joinDate: now.subtract(const Duration(days: 120)),
        birthday: DateTime(1995, 11, 8),
      ),
      Customer(
        id: 'CUST-004', name: 'Pedro Garcia', phone: '09451234567',
        email: 'pedro.g@email.com', totalPoints: 95, lifetimePoints: 250,
        totalSpent: 2500, totalTransactions: 8,
        joinDate: now.subtract(const Duration(days: 45)),
        birthday: DateTime(1988, 1, 30),
      ),
      Customer(
        id: 'CUST-005', name: 'Lisa Mendoza', phone: '09551234567',
        email: 'lisa.m@email.com', totalPoints: 2100, lifetimePoints: 3800,
        totalSpent: 38000, totalTransactions: 65,
        joinDate: now.subtract(const Duration(days: 300)),
        birthday: DateTime(1992, 5, 18),
      ),
      Customer(
        id: 'CUST-006', name: 'Carlo Tan', phone: '09661234567',
        email: '', totalPoints: 45, lifetimePoints: 120,
        totalSpent: 1200, totalTransactions: 5,
        joinDate: now.subtract(const Duration(days: 20)),
      ),
      Customer(
        id: 'CUST-007', name: 'Grace Lim', phone: '09771234567',
        email: 'grace.lim@email.com', totalPoints: 580, lifetimePoints: 950,
        totalSpent: 9500, totalTransactions: 28,
        joinDate: now.subtract(const Duration(days: 180)),
        birthday: DateTime(1993, 9, 25),
      ),
      Customer(
        id: 'CUST-008', name: 'Mark Rivera', phone: '09881234567',
        email: '', totalPoints: 1650, lifetimePoints: 2200,
        totalSpent: 22000, totalTransactions: 50,
        joinDate: now.subtract(const Duration(days: 250)),
        birthday: DateTime(1987, 12, 3),
      ),
    ];
  }
}
