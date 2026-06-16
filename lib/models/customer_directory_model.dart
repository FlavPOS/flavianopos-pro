// lib/models/customer_directory_model.dart
import '../helpers/database_helper.dart';

class PurchaseRecord {
  final String id;
  final DateTime date;
  final double amount;
  final int itemCount;
  final String paymentMethod;

  PurchaseRecord({
    required this.id,
    required this.date,
    required this.amount,
    required this.itemCount,
    required this.paymentMethod,
  });
}

class DirectoryCustomer {
  final String id;
  final String name;
  final String phone;
  final String email;
  final String address;
  final String group;
  final String notes;
  final double totalSpent;
  final int totalVisits;
  final DateTime? lastVisitDate;
  final DateTime joinDate;
  final DateTime? birthday;
  final List<PurchaseRecord> purchases;

  DirectoryCustomer({
    required this.id,
    required this.name,
    required this.phone,
    this.email = '',
    this.address = '',
    this.group = 'Regular',
    this.notes = '',
    this.totalSpent = 0,
    this.totalVisits = 0,
    this.lastVisitDate,
    required this.joinDate,
    this.birthday,
    this.purchases = const [],
  });

  double get averagePerVisit =>
      totalVisits > 0 ? totalSpent / totalVisits : 0;

  DirectoryCustomer copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    String? address,
    String? group,
    String? notes,
    double? totalSpent,
    int? totalVisits,
    DateTime? lastVisitDate,
    DateTime? joinDate,
    DateTime? birthday,
    List<PurchaseRecord>? purchases,
  }) {
    return DirectoryCustomer(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      group: group ?? this.group,
      notes: notes ?? this.notes,
      totalSpent: totalSpent ?? this.totalSpent,
      totalVisits: totalVisits ?? this.totalVisits,
      lastVisitDate: lastVisitDate ?? this.lastVisitDate,
      joinDate: joinDate ?? this.joinDate,
      birthday: birthday ?? this.birthday,
      purchases: purchases ?? this.purchases,
    );
  }

  static List<DirectoryCustomer> getSampleDirectoryCustomers() {
    final now = DateTime.now();
    return [
      DirectoryCustomer(
        id: 'DIR-001',
        name: 'Roberto Cruz',
        phone: '09171112222',
        email: 'roberto.cruz@email.com',
        address: 'Cebu City, Cebu',
        group: 'VIP',
        notes: 'Preferred customer. Always pays on time.',
        totalSpent: 125000,
        totalVisits: 95,
        lastVisitDate: now.subtract(const Duration(hours: 3)),
        joinDate: now.subtract(const Duration(days: 400)),
        birthday: DateTime(1982, 6, 15),
        purchases: [
          PurchaseRecord(id: 'PR-001', date: now.subtract(const Duration(hours: 3)), amount: 2500, itemCount: 8, paymentMethod: 'Cash'),
          PurchaseRecord(id: 'PR-002', date: now.subtract(const Duration(days: 2)), amount: 1800, itemCount: 5, paymentMethod: 'GCash'),
          PurchaseRecord(id: 'PR-003', date: now.subtract(const Duration(days: 5)), amount: 3200, itemCount: 12, paymentMethod: 'Cash'),
          PurchaseRecord(id: 'PR-004', date: now.subtract(const Duration(days: 10)), amount: 950, itemCount: 3, paymentMethod: 'Maya'),
        ],
      ),
      DirectoryCustomer(
        id: 'DIR-002',
        name: 'Elena Villanueva',
        phone: '09183334444',
        email: 'elena.v@email.com',
        address: 'Mandaue City, Cebu',
        group: 'VIP',
        notes: 'Owns a small restaurant. Bulk buyer.',
        totalSpent: 89000,
        totalVisits: 60,
        lastVisitDate: now.subtract(const Duration(days: 1)),
        joinDate: now.subtract(const Duration(days: 350)),
        birthday: DateTime(1978, 9, 22),
        purchases: [
          PurchaseRecord(id: 'PR-005', date: now.subtract(const Duration(days: 1)), amount: 5600, itemCount: 20, paymentMethod: 'Card'),
          PurchaseRecord(id: 'PR-006', date: now.subtract(const Duration(days: 7)), amount: 4200, itemCount: 15, paymentMethod: 'GCash'),
        ],
      ),
      DirectoryCustomer(
        id: 'DIR-003',
        name: 'Miguel Fernandez',
        phone: '09195556666',
        email: '',
        address: 'Lapu-Lapu City, Cebu',
        group: 'Regular',
        totalSpent: 15200,
        totalVisits: 22,
        lastVisitDate: now.subtract(const Duration(days: 3)),
        joinDate: now.subtract(const Duration(days: 180)),
        birthday: DateTime(1990, 2, 14),
        purchases: [
          PurchaseRecord(id: 'PR-007', date: now.subtract(const Duration(days: 3)), amount: 780, itemCount: 4, paymentMethod: 'Cash'),
        ],
      ),
      DirectoryCustomer(
        id: 'DIR-004',
        name: 'Sofia Aquino',
        phone: '09207778888',
        email: 'sofia.a@email.com',
        address: 'Talisay City, Cebu',
        group: 'Wholesale',
        notes: 'Sari-sari store owner. Orders weekly.',
        totalSpent: 210000,
        totalVisits: 120,
        lastVisitDate: now.subtract(const Duration(hours: 6)),
        joinDate: now.subtract(const Duration(days: 500)),
        birthday: DateTime(1975, 12, 1),
        purchases: [
          PurchaseRecord(id: 'PR-008', date: now.subtract(const Duration(hours: 6)), amount: 8500, itemCount: 35, paymentMethod: 'Cash'),
          PurchaseRecord(id: 'PR-009', date: now.subtract(const Duration(days: 7)), amount: 7200, itemCount: 28, paymentMethod: 'GCash'),
          PurchaseRecord(id: 'PR-010', date: now.subtract(const Duration(days: 14)), amount: 9100, itemCount: 40, paymentMethod: 'Cash'),
        ],
      ),
      DirectoryCustomer(
        id: 'DIR-005',
        name: 'Daniel Ramos',
        phone: '09219990000',
        email: 'daniel.r@email.com',
        address: '',
        group: 'New',
        totalSpent: 1500,
        totalVisits: 3,
        lastVisitDate: now.subtract(const Duration(days: 2)),
        joinDate: now.subtract(const Duration(days: 10)),
        purchases: [
          PurchaseRecord(id: 'PR-011', date: now.subtract(const Duration(days: 2)), amount: 650, itemCount: 3, paymentMethod: 'Cash'),
        ],
      ),
      DirectoryCustomer(
        id: 'DIR-006',
        name: 'Carmen Torres',
        phone: '09331112233',
        email: '',
        address: 'Minglanilla, Cebu',
        group: 'Regular',
        totalSpent: 28500,
        totalVisits: 35,
        lastVisitDate: now.subtract(const Duration(days: 5)),
        joinDate: now.subtract(const Duration(days: 250)),
        birthday: DateTime(1988, 4, 18),
        purchases: [
          PurchaseRecord(id: 'PR-012', date: now.subtract(const Duration(days: 5)), amount: 1200, itemCount: 6, paymentMethod: 'Maya'),
        ],
      ),
      DirectoryCustomer(
        id: 'DIR-007',
        name: 'Antonio Bautista',
        phone: '09453344556',
        email: 'tony.b@email.com',
        address: 'Consolacion, Cebu',
        group: 'Wholesale',
        notes: 'Mini grocery owner.',
        totalSpent: 165000,
        totalVisits: 85,
        lastVisitDate: now.subtract(const Duration(days: 1)),
        joinDate: now.subtract(const Duration(days: 380)),
        birthday: DateTime(1980, 8, 5),
        purchases: [
          PurchaseRecord(id: 'PR-013', date: now.subtract(const Duration(days: 1)), amount: 6800, itemCount: 25, paymentMethod: 'Cash'),
          PurchaseRecord(id: 'PR-014', date: now.subtract(const Duration(days: 8)), amount: 5500, itemCount: 22, paymentMethod: 'GCash'),
        ],
      ),
      DirectoryCustomer(
        id: 'DIR-008',
        name: 'Patricia Reyes',
        phone: '09565566778',
        email: '',
        address: '',
        group: 'New',
        totalSpent: 800,
        totalVisits: 2,
        lastVisitDate: now.subtract(const Duration(days: 1)),
        joinDate: now.subtract(const Duration(days: 5)),
        purchases: [],
      ),
      DirectoryCustomer(
        id: 'DIR-009',
        name: 'Ricardo Santiago',
        phone: '09677788990',
        email: 'rico.s@email.com',
        address: 'Liloan, Cebu',
        group: 'Regular',
        totalSpent: 42000,
        totalVisits: 48,
        lastVisitDate: now.subtract(const Duration(days: 4)),
        joinDate: now.subtract(const Duration(days: 300)),
        birthday: DateTime(1985, 11, 30),
        purchases: [
          PurchaseRecord(id: 'PR-015', date: now.subtract(const Duration(days: 4)), amount: 1650, itemCount: 7, paymentMethod: 'Card'),
        ],
      ),
      DirectoryCustomer(
        id: 'DIR-010',
        name: 'Isabella Gomez',
        phone: '09789900112',
        email: 'bella.g@email.com',
        address: 'Cebu City, Cebu',
        group: 'VIP',
        notes: 'Corporate account. Monthly billing.',
        totalSpent: 95000,
        totalVisits: 70,
        lastVisitDate: now.subtract(const Duration(hours: 8)),
        joinDate: now.subtract(const Duration(days: 320)),
        birthday: DateTime(1991, 7, 7),
        purchases: [
          PurchaseRecord(id: 'PR-016', date: now.subtract(const Duration(hours: 8)), amount: 3800, itemCount: 14, paymentMethod: 'Card'),
          PurchaseRecord(id: 'PR-017', date: now.subtract(const Duration(days: 3)), amount: 2900, itemCount: 10, paymentMethod: 'GCash'),
        ],
      ),
    ];
  }

  static List<DirectoryCustomer> _allCustomers = [];
  static List<DirectoryCustomer> get allCustomers {
    if (_allCustomers.isEmpty) _allCustomers = [];
    return _allCustomers;
  }
  Map<String, dynamic> toMap() => {
    'id': id, 'name': name, 'phone': phone, 'email': email,
    'address': address, 'group': group, 'notes': notes,
    'totalSpent': totalSpent, 'totalVisits': totalVisits,
    'lastVisitDate': lastVisitDate?.toIso8601String(),
    'joinDate': joinDate.toIso8601String(),
    'birthday': birthday?.toIso8601String(),
  };

  factory DirectoryCustomer.fromMap(Map<String, dynamic> m) => DirectoryCustomer(
    id: m['id'] ?? '', name: m['name'] ?? '', phone: m['phone'] ?? '',
    email: m['email'] ?? '', address: m['address'] ?? '',
    group: m['group'] ?? 'Regular', notes: m['notes'] ?? '',
    totalSpent: (m['totalSpent'] as num?)?.toDouble() ?? 0,
    totalVisits: m['totalVisits'] ?? 0,
    lastVisitDate: m['lastVisitDate'] != null ? DateTime.tryParse(m['lastVisitDate']) : null,
    joinDate: DateTime.tryParse(m['joinDate'] ?? '') ?? DateTime.now(),
    birthday: m['birthday'] != null ? DateTime.tryParse(m['birthday']) : null,
  );

  static void addCustomer(DirectoryCustomer c) {
    _allCustomers = allCustomers; _allCustomers.insert(0, c);
    DatabaseHelper().insertCustomer(c.toMap()).catchError((_) => 0);
  }
  static void updateCustomer(String id, DirectoryCustomer u) {
    final i = _allCustomers.indexWhere((c) => c.id == id); if (i >= 0) _allCustomers[i] = u;
    DatabaseHelper().updateCustomer(id, u.toMap()).catchError((_) => 0);
  }
  static void deleteCustomer(String id) {
    _allCustomers.removeWhere((c) => c.id == id);
    DatabaseHelper().deleteCustomer(id).catchError((_) => 0);
  }

  static Future<void> loadFromDB() async {
    final rows = await DatabaseHelper().getAllCustomers();
    if (rows.isEmpty) { _allCustomers = []; } else { _allCustomers = rows.map((r) => DirectoryCustomer.fromMap(r)).toList(); }
  }
}
