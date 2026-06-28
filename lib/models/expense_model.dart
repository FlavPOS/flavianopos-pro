import '../helpers/database_helper.dart';

class ExpenseCategory {
  final String id, name;
  final bool isActive;
  final DateTime dateCreated;
  ExpenseCategory({required this.id, required this.name, this.isActive = true, required this.dateCreated});
  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'isActive': isActive ? 1 : 0, 'dateCreated': dateCreated.toIso8601String()};
  factory ExpenseCategory.fromMap(Map<String, dynamic> m) => ExpenseCategory(id: m['id'] ?? '', name: m['name'] ?? '', isActive: (m['isActive'] ?? 1) == 1, dateCreated: DateTime.tryParse(m['dateCreated'] ?? '') ?? DateTime.now());
  ExpenseCategory copyWith({String? name, bool? isActive}) => ExpenseCategory(id: id, name: name ?? this.name, isActive: isActive ?? this.isActive, dateCreated: dateCreated);
}

class ExpenseSubCategory {
  final String id, categoryId, name;
  final bool isActive;
  final DateTime dateCreated;
  ExpenseSubCategory({required this.id, required this.categoryId, required this.name, this.isActive = true, required this.dateCreated});
  Map<String, dynamic> toMap() => {'id': id, 'categoryId': categoryId, 'name': name, 'isActive': isActive ? 1 : 0, 'dateCreated': dateCreated.toIso8601String()};
  factory ExpenseSubCategory.fromMap(Map<String, dynamic> m) => ExpenseSubCategory(id: m['id'] ?? '', categoryId: m['categoryId'] ?? '', name: m['name'] ?? '', isActive: (m['isActive'] ?? 1) == 1, dateCreated: DateTime.tryParse(m['dateCreated'] ?? '') ?? DateTime.now());
  ExpenseSubCategory copyWith({String? name, bool? isActive}) => ExpenseSubCategory(id: id, categoryId: categoryId, name: name ?? this.name, isActive: isActive ?? this.isActive, dateCreated: dateCreated);
}

class Expense {
  final String id, expenseNumber, expenseDate, dateCreated, branch;
  final String categoryId, categoryName, subCategoryId, subCategoryName;
  final double amount;
  final String paymentMethod, expenseType, priority;
  final String payeeSupplier, referenceNumber, remarks, preparedBy;
  final String status;
  final String checkedBy, checkedDate, approvedBy, approvedDate, approvalRemarks;
  final String rejectedBy, rejectedDate, rejectionReason;
  final String returnedBy, returnedDate, returnReason;
  final String attachmentPath, attachmentFileName, attachmentType;
  final String createdBy, updatedBy, updatedDate;
  final String department;

  Expense({required this.id, required this.expenseNumber, required this.expenseDate, required this.dateCreated, required this.branch,
    this.categoryId = '', this.categoryName = '', this.subCategoryId = '', this.subCategoryName = '',
    required this.amount, this.paymentMethod = 'Cash', this.expenseType = 'Regular Expense', this.priority = 'Normal',
    this.payeeSupplier = '', this.referenceNumber = '', this.remarks = '', required this.preparedBy,
    this.status = 'Draft',
    this.checkedBy = '', this.checkedDate = '', this.approvedBy = '', this.approvedDate = '', this.approvalRemarks = '',
    this.rejectedBy = '', this.rejectedDate = '', this.rejectionReason = '',
    this.returnedBy = '', this.returnedDate = '', this.returnReason = '',
    this.attachmentPath = '', this.attachmentFileName = '', this.attachmentType = '',
    this.createdBy = '', this.updatedBy = '', this.updatedDate = '', this.department = ''});

  Map<String, dynamic> toMap() => {
    'id': id, 'expenseNumber': expenseNumber, 'expenseDate': expenseDate, 'dateCreated': dateCreated, 'branch': branch,
    'categoryId': categoryId, 'categoryName': categoryName, 'subCategoryId': subCategoryId, 'subCategoryName': subCategoryName,
    'amount': amount, 'paymentMethod': paymentMethod, 'expenseType': expenseType, 'priority': priority,
    'payeeSupplier': payeeSupplier, 'referenceNumber': referenceNumber, 'remarks': remarks, 'preparedBy': preparedBy,
    'status': status, 'checkedBy': checkedBy, 'checkedDate': checkedDate,
    'approvedBy': approvedBy, 'approvedDate': approvedDate, 'approvalRemarks': approvalRemarks,
    'rejectedBy': rejectedBy, 'rejectedDate': rejectedDate, 'rejectionReason': rejectionReason,
    'returnedBy': returnedBy, 'returnedDate': returnedDate, 'returnReason': returnReason,
    'attachmentPath': attachmentPath, 'attachmentFileName': attachmentFileName, 'attachmentType': attachmentType,
    'createdBy': createdBy, 'updatedBy': updatedBy, 'updatedDate': updatedDate, 'department': department,
  };

  factory Expense.fromMap(Map<String, dynamic> m) => Expense(
    id: m['id'] ?? '', expenseNumber: m['expenseNumber'] ?? '', expenseDate: m['expenseDate'] ?? '', dateCreated: m['dateCreated'] ?? '', branch: m['branch'] ?? '',
    categoryId: m['categoryId'] ?? '', categoryName: m['categoryName'] ?? '', subCategoryId: m['subCategoryId'] ?? '', subCategoryName: m['subCategoryName'] ?? '',
    amount: (m['amount'] as num?)?.toDouble() ?? 0.0, paymentMethod: m['paymentMethod'] ?? 'Cash', expenseType: m['expenseType'] ?? 'Regular Expense', priority: m['priority'] ?? 'Normal',
    payeeSupplier: m['payeeSupplier'] ?? '', referenceNumber: m['referenceNumber'] ?? '', remarks: m['remarks'] ?? '', preparedBy: m['preparedBy'] ?? '',
    status: m['status'] ?? 'Draft', checkedBy: m['checkedBy'] ?? '', checkedDate: m['checkedDate'] ?? '',
    approvedBy: m['approvedBy'] ?? '', approvedDate: m['approvedDate'] ?? '', approvalRemarks: m['approvalRemarks'] ?? '',
    rejectedBy: m['rejectedBy'] ?? '', rejectedDate: m['rejectedDate'] ?? '', rejectionReason: m['rejectionReason'] ?? '',
    returnedBy: m['returnedBy'] ?? '', returnedDate: m['returnedDate'] ?? '', returnReason: m['returnReason'] ?? '',
    attachmentPath: m['attachmentPath'] ?? '', attachmentFileName: m['attachmentFileName'] ?? '', attachmentType: m['attachmentType'] ?? '',
    createdBy: m['createdBy'] ?? '', updatedBy: m['updatedBy'] ?? '', updatedDate: m['updatedDate'] ?? '', department: m['department'] ?? '');

  Expense copyWith({String? status, String? checkedBy, String? checkedDate, String? approvedBy, String? approvedDate, String? approvalRemarks,
    String? rejectedBy, String? rejectedDate, String? rejectionReason, String? returnedBy, String? returnedDate, String? returnReason,
    String? updatedBy, String? updatedDate, String? categoryId, String? categoryName, String? subCategoryId, String? subCategoryName,
    double? amount, String? paymentMethod, String? expenseType, String? priority, String? payeeSupplier, String? referenceNumber,
    String? remarks, String? attachmentPath, String? attachmentFileName, String? attachmentType, String? department, String? branch, String? expenseDate}) =>
    Expense(id: id, expenseNumber: expenseNumber, expenseDate: expenseDate ?? this.expenseDate, dateCreated: dateCreated, branch: branch ?? this.branch,
      categoryId: categoryId ?? this.categoryId, categoryName: categoryName ?? this.categoryName, subCategoryId: subCategoryId ?? this.subCategoryId, subCategoryName: subCategoryName ?? this.subCategoryName,
      amount: amount ?? this.amount, paymentMethod: paymentMethod ?? this.paymentMethod, expenseType: expenseType ?? this.expenseType, priority: priority ?? this.priority,
      payeeSupplier: payeeSupplier ?? this.payeeSupplier, referenceNumber: referenceNumber ?? this.referenceNumber, remarks: remarks ?? this.remarks, preparedBy: preparedBy,
      status: status ?? this.status, checkedBy: checkedBy ?? this.checkedBy, checkedDate: checkedDate ?? this.checkedDate,
      approvedBy: approvedBy ?? this.approvedBy, approvedDate: approvedDate ?? this.approvedDate, approvalRemarks: approvalRemarks ?? this.approvalRemarks,
      rejectedBy: rejectedBy ?? this.rejectedBy, rejectedDate: rejectedDate ?? this.rejectedDate, rejectionReason: rejectionReason ?? this.rejectionReason,
      returnedBy: returnedBy ?? this.returnedBy, returnedDate: returnedDate ?? this.returnedDate, returnReason: returnReason ?? this.returnReason,
      attachmentPath: attachmentPath ?? this.attachmentPath, attachmentFileName: attachmentFileName ?? this.attachmentFileName, attachmentType: attachmentType ?? this.attachmentType,
      createdBy: createdBy, updatedBy: updatedBy ?? this.updatedBy, updatedDate: updatedDate ?? this.updatedDate, department: department ?? this.department);

  bool get isDraft => status == 'Draft';
  bool get isForApproval => status == 'For Approval';
  bool get isApproved => status == 'Approved';
  bool get isRejected => status == 'Rejected';
  bool get isReturned => status == 'Returned';
  bool get isCancelled => status == 'Cancelled';
  bool get canEdit => isDraft || isReturned;
  bool get canCancel => isDraft || isReturned || isForApproval;
}

class ExpenseAudit {
  final String id, expenseId, expenseNumber, action, oldValue, newValue, performedBy, performedDate, branch;
  ExpenseAudit({required this.id, required this.expenseId, required this.expenseNumber, required this.action, this.oldValue = '', this.newValue = '', required this.performedBy, required this.performedDate, this.branch = ''});
  Map<String, dynamic> toMap() => {'id': id, 'expenseId': expenseId, 'expenseNumber': expenseNumber, 'action': action, 'oldValue': oldValue, 'newValue': newValue, 'performedBy': performedBy, 'performedDate': performedDate, 'branch': branch};
  factory ExpenseAudit.fromMap(Map<String, dynamic> m) => ExpenseAudit(id: m['id'] ?? '', expenseId: m['expenseId'] ?? '', expenseNumber: m['expenseNumber'] ?? '', action: m['action'] ?? '', oldValue: m['oldValue'] ?? '', newValue: m['newValue'] ?? '', performedBy: m['performedBy'] ?? '', performedDate: m['performedDate'] ?? '', branch: m['branch'] ?? '');
}

class PettyCashTransaction {
  final String id, branch, transactionType, referenceId, remarks, performedBy, performedDate;
  final double amount, balance;
  PettyCashTransaction({required this.id, required this.branch, required this.transactionType, required this.amount, required this.balance, this.referenceId = '', this.remarks = '', required this.performedBy, required this.performedDate});
  Map<String, dynamic> toMap() => {'id': id, 'branch': branch, 'transactionType': transactionType, 'amount': amount, 'balance': balance, 'referenceId': referenceId, 'remarks': remarks, 'performedBy': performedBy, 'performedDate': performedDate};
  factory PettyCashTransaction.fromMap(Map<String, dynamic> m) => PettyCashTransaction(id: m['id'] ?? '', branch: m['branch'] ?? '', transactionType: m['transactionType'] ?? '', amount: (m['amount'] as num?)?.toDouble() ?? 0, balance: (m['balance'] as num?)?.toDouble() ?? 0, referenceId: m['referenceId'] ?? '', remarks: m['remarks'] ?? '', performedBy: m['performedBy'] ?? '', performedDate: m['performedDate'] ?? '');
}

class ExpenseBudget {
  final String id, branch, categoryId, categoryName;
  final double monthlyBudget, warningPercent;
  final bool blockOnExceed, isActive;
  ExpenseBudget({required this.id, this.branch = '', this.categoryId = '', this.categoryName = '', required this.monthlyBudget, this.warningPercent = 80, this.blockOnExceed = false, this.isActive = true});
  Map<String, dynamic> toMap() => {'id': id, 'branch': branch, 'categoryId': categoryId, 'categoryName': categoryName, 'monthlyBudget': monthlyBudget, 'warningPercent': warningPercent, 'blockOnExceed': blockOnExceed ? 1 : 0, 'isActive': isActive ? 1 : 0};
  factory ExpenseBudget.fromMap(Map<String, dynamic> m) => ExpenseBudget(id: m['id'] ?? '', branch: m['branch'] ?? '', categoryId: m['categoryId'] ?? '', categoryName: m['categoryName'] ?? '', monthlyBudget: (m['monthlyBudget'] as num?)?.toDouble() ?? 0, warningPercent: (m['warningPercent'] as num?)?.toDouble() ?? 80, blockOnExceed: (m['blockOnExceed'] ?? 0) == 1, isActive: (m['isActive'] ?? 1) == 1);
}

class ExpenseStorage {
  static Future<String> generateExpenseNumber() async {
    final db = DatabaseHelper();
    final now = DateTime.now();
    final dateStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final prefix = 'EXP-$dateStr-';
    final rows = await db.rawQuery("SELECT expenseNumber FROM expenses WHERE expenseNumber LIKE '$prefix%' ORDER BY expenseNumber DESC LIMIT 1");
    int seq = 1;
    if (rows.isNotEmpty) { final last = rows.first['expenseNumber'] as String; final parts = last.split('-'); if (parts.length == 3) seq = (int.tryParse(parts[2]) ?? 0) + 1; }
    return '$prefix${seq.toString().padLeft(4, '0')}';
  }

  static Future<void> createExpense(Expense e) async { await DatabaseHelper().insertExpense(e.toMap()); }
  static Future<void> updateExpense(String id, Expense e) async { await DatabaseHelper().updateExpense(id, e.toMap()); }
  static Future<List<Expense>> getAll() async { final rows = await DatabaseHelper().getAllExpenses(); return rows.map((r) => Expense.fromMap(r)).toList(); }
  static Future<List<Expense>> getByStatus(String status) async { final rows = await DatabaseHelper().getExpensesByStatus(status); return rows.map((r) => Expense.fromMap(r)).toList(); }
  static Future<List<Expense>> getFiltered({String? dateFrom, String? dateTo, String? branch, String? category, String? status, String? paymentMethod, String? preparedBy, String? search}) async {
    final rows = await DatabaseHelper().getFilteredExpenses(dateFrom: dateFrom, dateTo: dateTo, branch: branch, category: category, status: status, paymentMethod: paymentMethod, preparedBy: preparedBy, search: search);
    return rows.map((r) => Expense.fromMap(r)).toList();
  }
  static Future<Map<String, dynamic>> getSummary({String? branch, String? month}) async { return await DatabaseHelper().getExpenseSummary(branch: branch, month: month); }

  static Future<void> addAudit(ExpenseAudit a) async { await DatabaseHelper().insertExpenseAudit(a.toMap()); }
  static Future<List<ExpenseAudit>> getAuditTrail({String? expenseId}) async { final rows = await DatabaseHelper().getExpenseAuditTrail(expenseId: expenseId); return rows.map((r) => ExpenseAudit.fromMap(r)).toList(); }

  static Future<List<ExpenseCategory>> getCategories() async { final rows = await DatabaseHelper().getExpenseCategories(); return rows.map((r) => ExpenseCategory.fromMap(r)).toList(); }
  static Future<void> addCategory(ExpenseCategory c) async { await DatabaseHelper().insertExpenseCategory(c.toMap()); }
  static Future<void> updateCategory(String id, ExpenseCategory c) async { await DatabaseHelper().updateExpenseCategory(id, c.toMap()); }

  static Future<List<ExpenseSubCategory>> getSubCategories({String? categoryId}) async { final rows = await DatabaseHelper().getExpenseSubCategories(categoryId: categoryId); return rows.map((r) => ExpenseSubCategory.fromMap(r)).toList(); }
  static Future<void> addSubCategory(ExpenseSubCategory c) async { await DatabaseHelper().insertExpenseSubCategory(c.toMap()); }
  static Future<void> updateSubCategory(String id, ExpenseSubCategory c) async { await DatabaseHelper().updateExpenseSubCategory(id, c.toMap()); }

  static Future<List<ExpenseBudget>> getBudgets() async { final rows = await DatabaseHelper().getExpenseBudgets(); return rows.map((r) => ExpenseBudget.fromMap(r)).toList(); }
  static Future<void> addBudget(ExpenseBudget b) async { await DatabaseHelper().insertExpenseBudget(b.toMap()); }
  static Future<void> updateBudget(String id, ExpenseBudget b) async { await DatabaseHelper().updateExpenseBudget(id, b.toMap()); }

  static Future<void> addPettyCash(PettyCashTransaction t) async { await DatabaseHelper().insertPettyCashTransaction(t.toMap()); }
  static Future<List<PettyCashTransaction>> getPettyCashHistory({String? branch}) async { final rows = await DatabaseHelper().getPettyCashTransactions(branch: branch); return rows.map((r) => PettyCashTransaction.fromMap(r)).toList(); }
  static Future<double> getPettyCashBalance(String branch) async { return await DatabaseHelper().getPettyCashBalance(branch); }

  static List<ExpenseCategory> getDefaultCategories() => [
    ExpenseCategory(id: 'CAT-001', name: 'Utilities', dateCreated: DateTime.now()),
    ExpenseCategory(id: 'CAT-002', name: 'Transportation', dateCreated: DateTime.now()),
    ExpenseCategory(id: 'CAT-003', name: 'Office Supplies', dateCreated: DateTime.now()),
    ExpenseCategory(id: 'CAT-004', name: 'Store Maintenance', dateCreated: DateTime.now()),
    ExpenseCategory(id: 'CAT-005', name: 'Communication', dateCreated: DateTime.now()),
    ExpenseCategory(id: 'CAT-006', name: 'Food & Meals', dateCreated: DateTime.now()),
    ExpenseCategory(id: 'CAT-007', name: 'Marketing', dateCreated: DateTime.now()),
    ExpenseCategory(id: 'CAT-008', name: 'Repairs & Maintenance', dateCreated: DateTime.now()),
    ExpenseCategory(id: 'CAT-009', name: 'Salary & Wages', dateCreated: DateTime.now()),
    ExpenseCategory(id: 'CAT-010', name: 'Miscellaneous', dateCreated: DateTime.now()),
  ];

  static List<ExpenseSubCategory> getDefaultSubCategories() => [
    ExpenseSubCategory(id: 'SUB-001', categoryId: 'CAT-001', name: 'Electricity', dateCreated: DateTime.now()),
    ExpenseSubCategory(id: 'SUB-002', categoryId: 'CAT-001', name: 'Water', dateCreated: DateTime.now()),
    ExpenseSubCategory(id: 'SUB-003', categoryId: 'CAT-001', name: 'Internet', dateCreated: DateTime.now()),
    ExpenseSubCategory(id: 'SUB-004', categoryId: 'CAT-002', name: 'Gas/Fuel', dateCreated: DateTime.now()),
    ExpenseSubCategory(id: 'SUB-005', categoryId: 'CAT-002', name: 'Fare/Commute', dateCreated: DateTime.now()),
    ExpenseSubCategory(id: 'SUB-006', categoryId: 'CAT-003', name: 'Paper & Printing', dateCreated: DateTime.now()),
    ExpenseSubCategory(id: 'SUB-007', categoryId: 'CAT-003', name: 'Pens & Stationery', dateCreated: DateTime.now()),
    ExpenseSubCategory(id: 'SUB-008', categoryId: 'CAT-004', name: 'Cleaning Supplies', dateCreated: DateTime.now()),
    ExpenseSubCategory(id: 'SUB-009', categoryId: 'CAT-005', name: 'Mobile Load', dateCreated: DateTime.now()),
    ExpenseSubCategory(id: 'SUB-010', categoryId: 'CAT-006', name: 'Staff Meals', dateCreated: DateTime.now()),
    ExpenseSubCategory(id: 'SUB-011', categoryId: 'CAT-006', name: 'Meeting Meals', dateCreated: DateTime.now()),
    ExpenseSubCategory(id: 'SUB-012', categoryId: 'CAT-008', name: 'Equipment Repair', dateCreated: DateTime.now()),
    ExpenseSubCategory(id: 'SUB-013', categoryId: 'CAT-008', name: 'Plumbing', dateCreated: DateTime.now()),
    ExpenseSubCategory(id: 'SUB-014', categoryId: 'CAT-008', name: 'Electrical', dateCreated: DateTime.now()),
    ExpenseSubCategory(id: 'SUB-015', categoryId: 'CAT-010', name: 'Other', dateCreated: DateTime.now()),
  ];
}
