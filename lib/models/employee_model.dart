// lib/models/employee_model.dart
import '../helpers/database_helper.dart';

class Employee {
  final String id;
  final String branchId;
  final String name;
  final String role;
  final String phone;
  final String email;
  final double salary;
  final bool isActive;
  final DateTime dateHired;
  final String notes;

  Employee({
    required this.id, required this.branchId, required this.name,
    this.role = 'Staff', this.phone = '', this.email = '',
    this.salary = 0, this.isActive = true, required this.dateHired,
    this.notes = '',
  });

  Employee copyWith({String? name, String? role, String? phone, String? email,
    double? salary, bool? isActive, String? notes, String? branchId}) => Employee(
    id: id, branchId: branchId ?? this.branchId, name: name ?? this.name,
    role: role ?? this.role, phone: phone ?? this.phone, email: email ?? this.email,
    salary: salary ?? this.salary, isActive: isActive ?? this.isActive,
    dateHired: dateHired, notes: notes ?? this.notes,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'branchId': branchId, 'name': name, 'role': role,
    'phone': phone, 'email': email, 'salary': salary,
    'isActive': isActive, 'dateHired': dateHired.toIso8601String(),
    'notes': notes,
  };

  factory Employee.fromJson(Map<String, dynamic> j) => Employee(
    id: j['id'] ?? '', branchId: j['branchId'] ?? '', name: j['name'] ?? '',
    role: j['role'] ?? 'Staff', phone: j['phone'] ?? '', email: j['email'] ?? '',
    salary: (j['salary'] ?? 0).toDouble(), isActive: j['isActive'] ?? true,
    dateHired: DateTime.tryParse(j['dateHired'] ?? '') ?? DateTime.now(),
    notes: j['notes'] ?? '',
  );

  Map<String, dynamic> toMap() => {
    'id': id, 'branchId': branchId, 'name': name, 'role': role,
    'phone': phone, 'email': email, 'salary': salary,
    'isActive': isActive ? 1 : 0,
    'dateHired': dateHired.toIso8601String(), 'notes': notes,
  };

  factory Employee.fromMap(Map<String, dynamic> m) => Employee(
    id: m['id'] ?? '', branchId: m['branchId'] ?? '', name: m['name'] ?? '',
    role: m['role'] ?? 'Staff', phone: m['phone'] ?? '', email: m['email'] ?? '',
    salary: (m['salary'] ?? 0).toDouble(),
    isActive: (m['isActive'] is bool) ? m['isActive'] : (m['isActive'] ?? 1) == 1,
    dateHired: DateTime.tryParse(m['dateHired'] ?? '') ?? DateTime.now(),
    notes: m['notes'] ?? '',
  );

  static List<Employee> getSampleEmployees() => [
    Employee(id: 'E-001', branchId: 'BR-001', name: 'Juan Dela Cruz', role: 'Store Manager', phone: '09171234567', email: 'juan@quickpos.com', salary: 25000, dateHired: DateTime(2024, 1, 15)),
    Employee(id: 'E-002', branchId: 'BR-001', name: 'Maria Santos', role: 'Cashier', phone: '09181234567', salary: 15000, dateHired: DateTime(2024, 3, 1)),
    Employee(id: 'E-003', branchId: 'BR-001', name: 'Pedro Reyes', role: 'Inventory Clerk', phone: '09191234567', salary: 14000, dateHired: DateTime(2024, 6, 15)),
    Employee(id: 'E-004', branchId: 'BR-002', name: 'Ana Garcia', role: 'Store Manager', phone: '09201234567', email: 'ana@quickpos.com', salary: 25000, dateHired: DateTime(2024, 2, 1)),
    Employee(id: 'E-005', branchId: 'BR-002', name: 'Carlo Mendoza', role: 'Cashier', salary: 15000, dateHired: DateTime(2024, 5, 10)),
  ];
}

class EmployeeStorage {
  static Future<void> saveAll(List<Employee> list) async {
    final db = DatabaseHelper();
    await db.bulkInsertEmployees(list.map((e) => e.toMap()).toList());
  }

  static Future<List<Employee>> getAll() async {
    final db = DatabaseHelper();
    final rows = await db.getAllEmployees();
    if (rows.isEmpty) {
      return [];
    }
    return rows.map((r) => Employee.fromMap(r)).toList();
  }

  static Future<List<Employee>> getByBranch(String branchId) async {
    final db = DatabaseHelper();
    final rows = await db.getEmployeesByBranch(branchId);
    if (rows.isEmpty) {
      // Fallback: load all then filter
      final all = await getAll();
      return all.where((e) => e.branchId == branchId).toList();
    }
    return rows.map((r) => Employee.fromMap(r)).toList();
  }

  static Future<void> addEmployee(Employee emp) async {
    await DatabaseHelper().insertEmployee(emp.toMap());
  }

  static Future<void> updateEmployee(Employee emp) async {
    await DatabaseHelper().updateEmployee(emp.id, emp.toMap());
  }

  static Future<void> deleteEmployee(String id) async {
    await DatabaseHelper().deleteEmployee(id);
  }
}
