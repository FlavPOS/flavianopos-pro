// =============================================================================
// QuickPOS Pro — database_helper.dart (CLEAN v2)
// Full SQLite Database — 17 Tables, All CRUD, Indexes, Migration
// Location: lib/helpers/database_helper.dart
// =============================================================================

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    _database ??= await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    final path = join(await getDatabasesPath(), 'quickpos_pro.db');
    return await openDatabase(
      path, version: 6,
      onCreate: _createDB, onUpgrade: _upgradeDB,
      onConfigure: (db) async => await db.execute('PRAGMA foreign_keys = ON'),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CREATE ALL 17 TABLES (fresh install)
  // ═══════════════════════════════════════════════════════════════════════════
  Future<void> _createDB(Database db, int version) async {
    // ── 1. products ──
    await db.execute('''
    CREATE TABLE products (
    id TEXT PRIMARY KEY, sku TEXT NOT NULL, name TEXT NOT NULL,
    category TEXT DEFAULT '', unit TEXT DEFAULT 'pcs',
    costPrice REAL DEFAULT 0, sellingPrice REAL DEFAULT 0,
    stockQty INTEGER DEFAULT 0, reorderLevel INTEGER DEFAULT 5,
    barcode TEXT DEFAULT '', imagePath TEXT, imageUrl TEXT DEFAULT ''
    )
    ''');

    // ── 2. batches ──
    await db.execute('''
    CREATE TABLE batches (
    id TEXT PRIMARY KEY, productId TEXT NOT NULL,
    productName TEXT DEFAULT '', productSku TEXT DEFAULT '',
    batchNumber TEXT NOT NULL, manufacturedDate TEXT NOT NULL,
    expiryDate TEXT NOT NULL, quantity INTEGER DEFAULT 0,
    originalQty INTEGER DEFAULT 0, costPrice REAL DEFAULT 0,
    supplier TEXT DEFAULT '', notes TEXT DEFAULT '', dateAdded TEXT NOT NULL,
    FOREIGN KEY (productId) REFERENCES products(id)
    )
    ''');

    // ── 3. transactions ──
    await db.execute('''
    CREATE TABLE transactions (
    id TEXT PRIMARY KEY, subtotal REAL DEFAULT 0,
    totalDiscount REAL DEFAULT 0, total REAL DEFAULT 0,
    paymentMethod TEXT DEFAULT 'Cash', amountPaid REAL DEFAULT 0,
    changeAmount REAL DEFAULT 0, status TEXT DEFAULT 'completed',
    cashier TEXT DEFAULT '', branch TEXT DEFAULT '',
    voidReason TEXT, voidedBy TEXT, voidedAt TEXT,
    refundAmount REAL, refundMethod TEXT, refundedBy TEXT,
    refundedAt TEXT, dateTime TEXT NOT NULL
    )
    ''');

    // ── 4. transaction_items ──
    await db.execute('''
    CREATE TABLE transaction_items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    transactionId TEXT NOT NULL, name TEXT NOT NULL,
    sku TEXT DEFAULT '', qty INTEGER DEFAULT 0,
    price REAL DEFAULT 0, discount REAL DEFAULT 0,
    discountType TEXT DEFAULT '', discountAmount REAL DEFAULT 0,
    FOREIGN KEY (transactionId) REFERENCES transactions(id)
    )
    ''');

    // ── 5. customers ──
    await db.execute('''
    CREATE TABLE customers (
    id TEXT PRIMARY KEY, name TEXT NOT NULL,
    phone TEXT DEFAULT '', email TEXT DEFAULT '',
    address TEXT DEFAULT '', notes TEXT DEFAULT '',
    loyaltyPoints INTEGER DEFAULT 0, totalPurchases REAL DEFAULT 0,
    dateAdded TEXT NOT NULL, totalPoints REAL DEFAULT 0,
    lifetimePoints REAL DEFAULT 0, totalTransactions INTEGER DEFAULT 0,
    birthday TEXT
    )
    ''');

    // ── 6. users ──
    await db.execute('''
    CREATE TABLE users (
    id TEXT PRIMARY KEY, username TEXT NOT NULL UNIQUE,
    password TEXT NOT NULL, fullName TEXT DEFAULT '',
    role TEXT DEFAULT 'cashier', branch TEXT DEFAULT '',
    pin TEXT DEFAULT '', isActive INTEGER DEFAULT 1,
    dateCreated TEXT NOT NULL, email TEXT DEFAULT '',
    phone TEXT DEFAULT '', lastLogin TEXT, permissions TEXT DEFAULT '',
    biometricEnabled INTEGER DEFAULT 0, biometricEnrolled INTEGER DEFAULT 0,
    preferredBiometricType TEXT DEFAULT 'face', lastBiometricVerifiedAt TEXT
    )
    ''');

    // ── 7. branches ──
    await db.execute('''
    CREATE TABLE branches (
    id TEXT PRIMARY KEY, name TEXT NOT NULL,
    address TEXT DEFAULT '', phone TEXT DEFAULT '',
    isActive INTEGER DEFAULT 1, email TEXT DEFAULT '',
    manager TEXT DEFAULT '', createdDate TEXT, imagePath TEXT
    )
    ''');

    // ── 8. employees ──
    await db.execute('''
    CREATE TABLE employees (
    id TEXT PRIMARY KEY, branchId TEXT NOT NULL, name TEXT NOT NULL,
    role TEXT DEFAULT 'Staff', phone TEXT DEFAULT '', email TEXT DEFAULT '',
    salary REAL DEFAULT 0, isActive INTEGER DEFAULT 1,
    dateHired TEXT NOT NULL, notes TEXT DEFAULT '',
    FOREIGN KEY (branchId) REFERENCES branches(id)
    )
    ''');

    // ── 9. batch_logs ──
    await db.execute('''
    CREATE TABLE batch_logs (
    id TEXT PRIMARY KEY, batchId TEXT NOT NULL,
    batchNumber TEXT DEFAULT '', productName TEXT DEFAULT '',
    productSku TEXT DEFAULT '', action TEXT NOT NULL,
    reason TEXT DEFAULT '', field TEXT DEFAULT '',
    oldValue TEXT DEFAULT '', newValue TEXT DEFAULT '',
    dateTime TEXT NOT NULL,
    FOREIGN KEY (batchId) REFERENCES batches(id)
    )
    ''');

    // ── 10. adjustment_records ──
    await db.execute('''
    CREATE TABLE adjustment_records (
    id TEXT PRIMARY KEY, itemName TEXT NOT NULL,
    sku TEXT DEFAULT '', adjustmentType TEXT NOT NULL,
    quantity INTEGER DEFAULT 0, oldStock INTEGER DEFAULT 0,
    newStock INTEGER DEFAULT 0, reason TEXT DEFAULT '',
    notes TEXT DEFAULT '', dateTime TEXT NOT NULL,
    cost REAL DEFAULT 0, retail REAL DEFAULT 0
    )
    ''');

    // ── 11. stock_transfers ──
    await db.execute('''
    CREATE TABLE stock_transfers (
    id TEXT PRIMARY KEY, transferNo TEXT NOT NULL UNIQUE,
    transferDate TEXT NOT NULL, fromBranchId TEXT DEFAULT '',
    fromBranchName TEXT DEFAULT '', toBranchId TEXT DEFAULT '',
    toBranchName TEXT DEFAULT '', status TEXT DEFAULT 'Draft',
    preparedBy TEXT DEFAULT '', approvedBy TEXT DEFAULT '',
    receivedBy TEXT DEFAULT '', receivedDate TEXT,
    remarks TEXT DEFAULT '', createdAt TEXT NOT NULL, updatedAt TEXT NOT NULL
    )
    ''');

    // ── 12. transfer_items ──
    await db.execute('''
    CREATE TABLE transfer_items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    transferId TEXT NOT NULL, itemId TEXT DEFAULT '',
    itemCode TEXT DEFAULT '', itemName TEXT DEFAULT '',
    category TEXT DEFAULT '', unit TEXT DEFAULT 'pcs',
    batchId TEXT DEFAULT '', batchNumber TEXT DEFAULT '',
    manufacturedDate TEXT, expiryDate TEXT,
    qtyTransferred INTEGER DEFAULT 0, qtyReceived INTEGER DEFAULT 0,
    cost REAL DEFAULT 0, remarks TEXT DEFAULT '',
    FOREIGN KEY (transferId) REFERENCES stock_transfers(id)
    )
    ''');

    // ── 13. transfer_ledger ──
    await db.execute('''
    CREATE TABLE transfer_ledger (
    id TEXT PRIMARY KEY, transferId TEXT DEFAULT '',
    referenceNo TEXT DEFAULT '', itemId TEXT DEFAULT '',
    itemCode TEXT DEFAULT '', itemName TEXT DEFAULT '',
    batchId TEXT DEFAULT '', batchNumber TEXT DEFAULT '',
    branchId TEXT DEFAULT '', branchName TEXT DEFAULT '',
    movementType TEXT DEFAULT '',
    manufacturedDate TEXT, expiryDate TEXT,
    beginningBalance INTEGER DEFAULT 0,
    qtyIn INTEGER DEFAULT 0, qtyOut INTEGER DEFAULT 0,
    endingBalance INTEGER DEFAULT 0, cost REAL DEFAULT 0,
    user TEXT DEFAULT '', date TEXT NOT NULL, remarks TEXT DEFAULT ''
    )
    ''');

    // ── 14. delivery_records ──
    await db.execute('''
    CREATE TABLE delivery_records (
    id TEXT PRIMARY KEY, refNumber TEXT DEFAULT '',
    supplier TEXT DEFAULT '', driverName TEXT DEFAULT '',
    plateNumber TEXT DEFAULT '', receivedBy TEXT DEFAULT '',
    notes TEXT DEFAULT '', totalItems INTEGER DEFAULT 0,
    totalQuantity INTEGER DEFAULT 0, totalCost REAL DEFAULT 0,
    totalRetail REAL DEFAULT 0, dateTime TEXT NOT NULL
    )
    ''');

    // ── 15. delivery_items ──
    await db.execute('''
    CREATE TABLE delivery_items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    deliveryId TEXT NOT NULL, productId TEXT DEFAULT '',
    itemName TEXT DEFAULT '', sku TEXT DEFAULT '',
    quantity INTEGER DEFAULT 0, oldStock INTEGER DEFAULT 0,
    newStock INTEGER DEFAULT 0, cost REAL DEFAULT 0, retail REAL DEFAULT 0,
    batchNumber TEXT DEFAULT '', mfgDate TEXT DEFAULT '', expDate TEXT DEFAULT '',
    FOREIGN KEY (deliveryId) REFERENCES delivery_records(id)
    )
    ''');

    // ── 16. discount_records ──
    await db.execute('''
    CREATE TABLE discount_records (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    transactionId TEXT NOT NULL, dateTime TEXT NOT NULL,
    discountType TEXT DEFAULT '', customerName TEXT DEFAULT '',
    idNumber TEXT DEFAULT '', age INTEGER,
    discountPercentage REAL DEFAULT 0, fixedDiscount REAL DEFAULT 0,
    isPercentage INTEGER DEFAULT 1, totalGross REAL DEFAULT 0,
    totalDiscount REAL DEFAULT 0, totalNet REAL DEFAULT 0,
    cashier TEXT DEFAULT '', branch TEXT DEFAULT ''
    )
    ''');

    // ── 17. discount_items ──
    await db.execute('''
    CREATE TABLE discount_items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    discountRecordId INTEGER NOT NULL,
    itemName TEXT DEFAULT '', sku TEXT DEFAULT '',
    qty INTEGER DEFAULT 0, unitPrice REAL DEFAULT 0,
    grossAmount REAL DEFAULT 0, discountAmount REAL DEFAULT 0,
    netAmount REAL DEFAULT 0,
    FOREIGN KEY (discountRecordId) REFERENCES discount_records(id)
    )
    ''');

    await _createAllIndexes(db);
    // ── expenses tables ──
    await db.execute('CREATE TABLE IF NOT EXISTS expenses (id TEXT PRIMARY KEY, expenseNumber TEXT UNIQUE, expenseDate TEXT, dateCreated TEXT, branch TEXT, categoryId TEXT, categoryName TEXT, subCategoryId TEXT, subCategoryName TEXT, amount REAL DEFAULT 0, paymentMethod TEXT DEFAULT "Cash", expenseType TEXT DEFAULT "Regular Expense", priority TEXT DEFAULT "Normal", payeeSupplier TEXT DEFAULT "", referenceNumber TEXT DEFAULT "", remarks TEXT DEFAULT "", preparedBy TEXT DEFAULT "", status TEXT DEFAULT "Draft", checkedBy TEXT DEFAULT "", checkedDate TEXT DEFAULT "", approvedBy TEXT DEFAULT "", approvedDate TEXT DEFAULT "", approvalRemarks TEXT DEFAULT "", rejectedBy TEXT DEFAULT "", rejectedDate TEXT DEFAULT "", rejectionReason TEXT DEFAULT "", returnedBy TEXT DEFAULT "", returnedDate TEXT DEFAULT "", returnReason TEXT DEFAULT "", attachmentPath TEXT DEFAULT "", attachmentFileName TEXT DEFAULT "", attachmentType TEXT DEFAULT "", createdBy TEXT DEFAULT "", updatedBy TEXT DEFAULT "", updatedDate TEXT DEFAULT "", department TEXT DEFAULT "")');
    await db.execute('CREATE TABLE IF NOT EXISTS expense_categories (id TEXT PRIMARY KEY, name TEXT NOT NULL, isActive INTEGER DEFAULT 1, dateCreated TEXT)');
    await db.execute('CREATE TABLE IF NOT EXISTS expense_sub_categories (id TEXT PRIMARY KEY, categoryId TEXT, name TEXT NOT NULL, isActive INTEGER DEFAULT 1, dateCreated TEXT)');
    await db.execute('CREATE TABLE IF NOT EXISTS expense_audit_trail (id TEXT PRIMARY KEY, expenseId TEXT, expenseNumber TEXT, action TEXT, oldValue TEXT DEFAULT "", newValue TEXT DEFAULT "", performedBy TEXT, performedDate TEXT, branch TEXT DEFAULT "")');
    await db.execute('CREATE TABLE IF NOT EXISTS expense_budgets (id TEXT PRIMARY KEY, branch TEXT DEFAULT "", categoryId TEXT DEFAULT "", categoryName TEXT DEFAULT "", monthlyBudget REAL DEFAULT 0, warningPercent REAL DEFAULT 80, blockOnExceed INTEGER DEFAULT 0, isActive INTEGER DEFAULT 1)');
    await db.execute('CREATE TABLE IF NOT EXISTS petty_cash_transactions (id TEXT PRIMARY KEY, branch TEXT, transactionType TEXT, amount REAL, balance REAL, referenceId TEXT DEFAULT "", remarks TEXT DEFAULT "", performedBy TEXT, performedDate TEXT)');
    await db.execute('CREATE TABLE IF NOT EXISTS exchanges (id TEXT PRIMARY KEY, exchangeNumber TEXT UNIQUE, originalTxnId TEXT, exchangeDate TEXT, returnedItemName TEXT, returnedItemSku TEXT, returnedQty INTEGER DEFAULT 0, returnedPrice REAL DEFAULT 0, newItemName TEXT, newItemSku TEXT, newQty INTEGER DEFAULT 0, newPrice REAL DEFAULT 0, priceDifference REAL DEFAULT 0, amountPaid REAL DEFAULT 0, reason TEXT DEFAULT "", processedBy TEXT DEFAULT "", approvedBy TEXT DEFAULT "", branch TEXT DEFAULT "", status TEXT DEFAULT "Completed", dateCreated TEXT)');
  }

  Future<void> _createAllIndexes(Database db) async {
    await db.execute('CREATE INDEX IF NOT EXISTS idx_products_sku ON products(sku)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_products_category ON products(category)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_products_barcode ON products(barcode)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_batches_productId ON batches(productId)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_batches_batchNumber ON batches(batchNumber)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_batches_expiryDate ON batches(expiryDate)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_txn_dateTime ON transactions(dateTime)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_txn_status ON transactions(status)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_txn_items_txnId ON transaction_items(transactionId)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_customers_phone ON customers(phone)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_employees_branchId ON employees(branchId)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_batch_logs_batchId ON batch_logs(batchId)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_batch_logs_dateTime ON batch_logs(dateTime)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_adj_dateTime ON adjustment_records(dateTime)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_transfers_transferNo ON stock_transfers(transferNo)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_transfers_status ON stock_transfers(status)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_transfer_items_transferId ON transfer_items(transferId)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_ledger_itemId ON transfer_ledger(itemId)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_ledger_referenceNo ON transfer_ledger(referenceNo)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_ledger_batchNumber ON transfer_ledger(batchNumber)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_delivery_refNumber ON delivery_records(refNumber)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_delivery_dateTime ON delivery_records(dateTime)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_delivery_items_deliveryId ON delivery_items(deliveryId)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_discount_transactionId ON discount_records(transactionId)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_discount_dateTime ON discount_records(dateTime)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_discount_items_recordId ON discount_items(discountRecordId)');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // UPGRADE v1 → v2
  // ═══════════════════════════════════════════════════════════════════════════
  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // ALTER existing tables
      await db.execute("ALTER TABLE customers ADD COLUMN totalPoints REAL DEFAULT 0");
      await db.execute("ALTER TABLE customers ADD COLUMN lifetimePoints REAL DEFAULT 0");
      await db.execute("ALTER TABLE customers ADD COLUMN totalTransactions INTEGER DEFAULT 0");
      await db.execute("ALTER TABLE customers ADD COLUMN birthday TEXT");
      await db.execute("ALTER TABLE users ADD COLUMN email TEXT DEFAULT ''");
      await db.execute("ALTER TABLE users ADD COLUMN phone TEXT DEFAULT ''");
      await db.execute("ALTER TABLE users ADD COLUMN lastLogin TEXT");
      await db.execute("ALTER TABLE users ADD COLUMN permissions TEXT DEFAULT ''");
      await db.execute("ALTER TABLE branches ADD COLUMN email TEXT DEFAULT ''");
      await db.execute("ALTER TABLE branches ADD COLUMN manager TEXT DEFAULT ''");
      await db.execute("ALTER TABLE branches ADD COLUMN createdDate TEXT");
      await db.execute("ALTER TABLE branches ADD COLUMN imagePath TEXT");

      // Create 10 new tables
      await db.execute('CREATE TABLE IF NOT EXISTS employees (id TEXT PRIMARY KEY, branchId TEXT NOT NULL, name TEXT NOT NULL, role TEXT DEFAULT \'Staff\', phone TEXT DEFAULT \'\', email TEXT DEFAULT \'\', salary REAL DEFAULT 0, isActive INTEGER DEFAULT 1, dateHired TEXT NOT NULL, notes TEXT DEFAULT \'\', FOREIGN KEY (branchId) REFERENCES branches(id))');
      await db.execute('CREATE TABLE IF NOT EXISTS batch_logs (id TEXT PRIMARY KEY, batchId TEXT NOT NULL, batchNumber TEXT DEFAULT \'\', productName TEXT DEFAULT \'\', productSku TEXT DEFAULT \'\', action TEXT NOT NULL, reason TEXT DEFAULT \'\', field TEXT DEFAULT \'\', oldValue TEXT DEFAULT \'\', newValue TEXT DEFAULT \'\', dateTime TEXT NOT NULL, FOREIGN KEY (batchId) REFERENCES batches(id))');
      await db.execute('CREATE TABLE IF NOT EXISTS adjustment_records (id TEXT PRIMARY KEY, itemName TEXT NOT NULL, sku TEXT DEFAULT \'\', adjustmentType TEXT NOT NULL, quantity INTEGER DEFAULT 0, oldStock INTEGER DEFAULT 0, newStock INTEGER DEFAULT 0, reason TEXT DEFAULT \'\', notes TEXT DEFAULT \'\', dateTime TEXT NOT NULL, cost REAL DEFAULT 0, retail REAL DEFAULT 0)');
      await db.execute('CREATE TABLE IF NOT EXISTS stock_transfers (id TEXT PRIMARY KEY, transferNo TEXT NOT NULL UNIQUE, transferDate TEXT NOT NULL, fromBranchId TEXT DEFAULT \'\', fromBranchName TEXT DEFAULT \'\', toBranchId TEXT DEFAULT \'\', toBranchName TEXT DEFAULT \'\', status TEXT DEFAULT \'Draft\', preparedBy TEXT DEFAULT \'\', approvedBy TEXT DEFAULT \'\', receivedBy TEXT DEFAULT \'\', receivedDate TEXT, remarks TEXT DEFAULT \'\', createdAt TEXT NOT NULL, updatedAt TEXT NOT NULL)');
      await db.execute('CREATE TABLE IF NOT EXISTS transfer_items (id INTEGER PRIMARY KEY AUTOINCREMENT, transferId TEXT NOT NULL, itemId TEXT DEFAULT \'\', itemCode TEXT DEFAULT \'\', itemName TEXT DEFAULT \'\', category TEXT DEFAULT \'\', unit TEXT DEFAULT \'pcs\', batchId TEXT DEFAULT \'\', batchNumber TEXT DEFAULT \'\', manufacturedDate TEXT, expiryDate TEXT, qtyTransferred INTEGER DEFAULT 0, qtyReceived INTEGER DEFAULT 0, cost REAL DEFAULT 0, remarks TEXT DEFAULT \'\', FOREIGN KEY (transferId) REFERENCES stock_transfers(id))');
      await db.execute('CREATE TABLE IF NOT EXISTS transfer_ledger (id TEXT PRIMARY KEY, transferId TEXT DEFAULT \'\', referenceNo TEXT DEFAULT \'\', itemId TEXT DEFAULT \'\', itemCode TEXT DEFAULT \'\', itemName TEXT DEFAULT \'\', batchId TEXT DEFAULT \'\', batchNumber TEXT DEFAULT \'\', branchId TEXT DEFAULT \'\', branchName TEXT DEFAULT \'\', movementType TEXT DEFAULT \'\', manufacturedDate TEXT, expiryDate TEXT, beginningBalance INTEGER DEFAULT 0, qtyIn INTEGER DEFAULT 0, qtyOut INTEGER DEFAULT 0, endingBalance INTEGER DEFAULT 0, cost REAL DEFAULT 0, user TEXT DEFAULT \'\', date TEXT NOT NULL, remarks TEXT DEFAULT \'\')');
      await db.execute('CREATE TABLE IF NOT EXISTS delivery_records (id TEXT PRIMARY KEY, refNumber TEXT DEFAULT \'\', supplier TEXT DEFAULT \'\', driverName TEXT DEFAULT \'\', plateNumber TEXT DEFAULT \'\', receivedBy TEXT DEFAULT \'\', notes TEXT DEFAULT \'\', totalItems INTEGER DEFAULT 0, totalQuantity INTEGER DEFAULT 0, totalCost REAL DEFAULT 0, totalRetail REAL DEFAULT 0, dateTime TEXT NOT NULL)');
      await db.execute('CREATE TABLE IF NOT EXISTS delivery_items (id INTEGER PRIMARY KEY AUTOINCREMENT, deliveryId TEXT NOT NULL, productId TEXT DEFAULT \'\', itemName TEXT DEFAULT \'\', sku TEXT DEFAULT \'\', quantity INTEGER DEFAULT 0, oldStock INTEGER DEFAULT 0, newStock INTEGER DEFAULT 0, cost REAL DEFAULT 0, retail REAL DEFAULT 0, FOREIGN KEY (deliveryId) REFERENCES delivery_records(id))');
      await db.execute('CREATE TABLE IF NOT EXISTS discount_records (id INTEGER PRIMARY KEY AUTOINCREMENT, transactionId TEXT NOT NULL, dateTime TEXT NOT NULL, discountType TEXT DEFAULT \'\', customerName TEXT DEFAULT \'\', idNumber TEXT DEFAULT \'\', age INTEGER, discountPercentage REAL DEFAULT 0, fixedDiscount REAL DEFAULT 0, isPercentage INTEGER DEFAULT 1, totalGross REAL DEFAULT 0, totalDiscount REAL DEFAULT 0, totalNet REAL DEFAULT 0, cashier TEXT DEFAULT \'\', branch TEXT DEFAULT \'\')');
      await db.execute('CREATE TABLE IF NOT EXISTS discount_items (id INTEGER PRIMARY KEY AUTOINCREMENT, discountRecordId INTEGER NOT NULL, itemName TEXT DEFAULT \'\', sku TEXT DEFAULT \'\', qty INTEGER DEFAULT 0, unitPrice REAL DEFAULT 0, grossAmount REAL DEFAULT 0, discountAmount REAL DEFAULT 0, netAmount REAL DEFAULT 0, FOREIGN KEY (discountRecordId) REFERENCES discount_records(id))');

      // New indexes
      await db.execute('CREATE INDEX IF NOT EXISTS idx_customers_phone ON customers(phone)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_employees_branchId ON employees(branchId)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_batch_logs_batchId ON batch_logs(batchId)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_batch_logs_dateTime ON batch_logs(dateTime)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_adj_dateTime ON adjustment_records(dateTime)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_transfers_transferNo ON stock_transfers(transferNo)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_transfers_status ON stock_transfers(status)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_transfer_items_transferId ON transfer_items(transferId)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_ledger_itemId ON transfer_ledger(itemId)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_ledger_referenceNo ON transfer_ledger(referenceNo)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_ledger_batchNumber ON transfer_ledger(batchNumber)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_delivery_refNumber ON delivery_records(refNumber)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_delivery_dateTime ON delivery_records(dateTime)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_delivery_items_deliveryId ON delivery_items(deliveryId)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_discount_transactionId ON discount_records(transactionId)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_discount_dateTime ON discount_records(dateTime)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_discount_items_recordId ON discount_items(discountRecordId)');
    }
    if (oldVersion < 3) {
      // v2 → v3: Add batch columns to delivery_items
      try { await db.execute("ALTER TABLE delivery_items ADD COLUMN batchNumber TEXT DEFAULT ''"); } catch (_) {}
      try { await db.execute("ALTER TABLE delivery_items ADD COLUMN mfgDate TEXT DEFAULT ''"); } catch (_) {}
      try { await db.execute("ALTER TABLE delivery_items ADD COLUMN expDate TEXT DEFAULT ''"); } catch (_) {}
    }
    if (oldVersion < 4) {
      await db.execute('CREATE TABLE IF NOT EXISTS expenses (id TEXT PRIMARY KEY, expenseNumber TEXT UNIQUE, expenseDate TEXT, dateCreated TEXT, branch TEXT, categoryId TEXT, categoryName TEXT, subCategoryId TEXT, subCategoryName TEXT, amount REAL DEFAULT 0, paymentMethod TEXT DEFAULT "Cash", expenseType TEXT DEFAULT "Regular Expense", priority TEXT DEFAULT "Normal", payeeSupplier TEXT DEFAULT "", referenceNumber TEXT DEFAULT "", remarks TEXT DEFAULT "", preparedBy TEXT DEFAULT "", status TEXT DEFAULT "Draft", checkedBy TEXT DEFAULT "", checkedDate TEXT DEFAULT "", approvedBy TEXT DEFAULT "", approvedDate TEXT DEFAULT "", approvalRemarks TEXT DEFAULT "", rejectedBy TEXT DEFAULT "", rejectedDate TEXT DEFAULT "", rejectionReason TEXT DEFAULT "", returnedBy TEXT DEFAULT "", returnedDate TEXT DEFAULT "", returnReason TEXT DEFAULT "", attachmentPath TEXT DEFAULT "", attachmentFileName TEXT DEFAULT "", attachmentType TEXT DEFAULT "", createdBy TEXT DEFAULT "", updatedBy TEXT DEFAULT "", updatedDate TEXT DEFAULT "", department TEXT DEFAULT "")');
      await db.execute('CREATE TABLE IF NOT EXISTS expense_categories (id TEXT PRIMARY KEY, name TEXT NOT NULL, isActive INTEGER DEFAULT 1, dateCreated TEXT)');
      await db.execute('CREATE TABLE IF NOT EXISTS expense_sub_categories (id TEXT PRIMARY KEY, categoryId TEXT, name TEXT NOT NULL, isActive INTEGER DEFAULT 1, dateCreated TEXT)');
      await db.execute('CREATE TABLE IF NOT EXISTS expense_audit_trail (id TEXT PRIMARY KEY, expenseId TEXT, expenseNumber TEXT, action TEXT, oldValue TEXT DEFAULT "", newValue TEXT DEFAULT "", performedBy TEXT, performedDate TEXT, branch TEXT DEFAULT "")');
      await db.execute('CREATE TABLE IF NOT EXISTS expense_budgets (id TEXT PRIMARY KEY, branch TEXT DEFAULT "", categoryId TEXT DEFAULT "", categoryName TEXT DEFAULT "", monthlyBudget REAL DEFAULT 0, warningPercent REAL DEFAULT 80, blockOnExceed INTEGER DEFAULT 0, isActive INTEGER DEFAULT 1)');
      await db.execute('CREATE TABLE IF NOT EXISTS petty_cash_transactions (id TEXT PRIMARY KEY, branch TEXT, transactionType TEXT, amount REAL, balance REAL, referenceId TEXT DEFAULT "", remarks TEXT DEFAULT "", performedBy TEXT, performedDate TEXT)');
    }
    if (oldVersion < 5) {
      await db.execute('CREATE TABLE IF NOT EXISTS exchanges (id TEXT PRIMARY KEY, exchangeNumber TEXT UNIQUE, originalTxnId TEXT, exchangeDate TEXT, returnedItemName TEXT, returnedItemSku TEXT, returnedQty INTEGER DEFAULT 0, returnedPrice REAL DEFAULT 0, newItemName TEXT, newItemSku TEXT, newQty INTEGER DEFAULT 0, newPrice REAL DEFAULT 0, priceDifference REAL DEFAULT 0, amountPaid REAL DEFAULT 0, reason TEXT DEFAULT "", processedBy TEXT DEFAULT "", approvedBy TEXT DEFAULT "", branch TEXT DEFAULT "", status TEXT DEFAULT "Completed", dateCreated TEXT)');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PRODUCTS CRUD
  // ═══════════════════════════════════════════════════════════════════════════

  Future<int> insertProduct(Map<String, dynamic> p) async { final db = await database; return await db.insert('products', p, conflictAlgorithm: ConflictAlgorithm.replace); }
  Future<int> updateProduct(String id, Map<String, dynamic> p) async { final db = await database; return await db.update('products', p, where: 'id = ?', whereArgs: [id]); }
  Future<int> deleteProduct(String id) async { final db = await database; return await db.delete('products', where: 'id = ?', whereArgs: [id]); }
  Future<List<Map<String, dynamic>>> getAllProducts() async { final db = await database; return await db.query('products', orderBy: 'name ASC'); }
  Future<Map<String, dynamic>?> getProductById(String id) async { final db = await database; final r = await db.query('products', where: 'id = ?', whereArgs: [id]); return r.isNotEmpty ? r.first : null; }
  Future<Map<String, dynamic>?> getProductBySku(String sku) async { final db = await database; final r = await db.query('products', where: 'sku = ?', whereArgs: [sku]); return r.isNotEmpty ? r.first : null; }
  Future<Map<String, dynamic>?> getProductByBarcode(String barcode) async { final db = await database; final r = await db.query('products', where: 'barcode = ?', whereArgs: [barcode]); return r.isNotEmpty ? r.first : null; }
  Future<void> updateStock(String id, int newQty) async { final db = await database; await db.update('products', {'stockQty': newQty}, where: 'id = ?', whereArgs: [id]); }
  Future<void> bulkInsertProducts(List<Map<String, dynamic>> products) async { final db = await database; final batch = db.batch(); for (final p in products) { batch.insert('products', p, conflictAlgorithm: ConflictAlgorithm.replace); } await batch.commit(noResult: true); }
  Future<List<Map<String, dynamic>>> searchProducts(String query) async { final db = await database; return await db.query('products', where: 'name LIKE ? OR sku LIKE ? OR barcode LIKE ?', whereArgs: ['%\$query%', '%\$query%', '%\$query%'], orderBy: 'name ASC'); }
  Future<List<Map<String, dynamic>>> getActiveProducts() async { final db = await database; return await db.query('products', where: 'stockQty > 0', orderBy: 'name ASC'); }
  Future<List<Map<String, dynamic>>> getLowStockProducts() async { final db = await database; return await db.query('products', where: 'stockQty <= reorderLevel', orderBy: 'stockQty ASC'); }

  // ═══════════════════════════════════════════════════════════════════════════
  // BATCHES CRUD
  // ═══════════════════════════════════════════════════════════════════════════

  Future<int> insertBatch(Map<String, dynamic> b) async { final db = await database; return await db.insert('batches', b, conflictAlgorithm: ConflictAlgorithm.replace); }
  Future<int> updateBatch(String id, Map<String, dynamic> b) async { final db = await database; return await db.update('batches', b, where: 'id = ?', whereArgs: [id]); }
  Future<int> deleteBatch(String id) async { final db = await database; return await db.delete('batches', where: 'id = ?', whereArgs: [id]); }
  Future<List<Map<String, dynamic>>> getAllBatches() async { final db = await database; return await db.query('batches', orderBy: 'expiryDate ASC'); }
  Future<Map<String, dynamic>?> getBatchById(String id) async { final db = await database; final r = await db.query('batches', where: 'id = ?', whereArgs: [id]); return r.isNotEmpty ? r.first : null; }
  Future<List<Map<String, dynamic>>> getBatchesByProduct(String productId) async { final db = await database; return await db.query('batches', where: 'productId = ?', whereArgs: [productId], orderBy: 'expiryDate ASC'); }
  Future<void> updateBatchQty(String id, int newQty) async { final db = await database; await db.update('batches', {'quantity': newQty}, where: 'id = ?', whereArgs: [id]); }
  Future<void> bulkInsertBatches(List<Map<String, dynamic>> batches) async { final db = await database; final b = db.batch(); for (final item in batches) { b.insert('batches', item, conflictAlgorithm: ConflictAlgorithm.replace); } await b.commit(noResult: true); }
  Future<List<Map<String, dynamic>>> getActiveBatches(String productId) async { final db = await database; return await db.query('batches', where: 'productId = ? AND quantity > 0', whereArgs: [productId], orderBy: 'expiryDate ASC'); }
  Future<List<Map<String, dynamic>>> getExpiringBatches(int daysFromNow) async { final db = await database; final futureDate = DateTime.now().add(Duration(days: daysFromNow)).toIso8601String().substring(0, 10); final today = DateTime.now().toIso8601String().substring(0, 10); return await db.query('batches', where: 'expiryDate BETWEEN ? AND ? AND quantity > 0', whereArgs: [today, futureDate], orderBy: 'expiryDate ASC'); }

  // ═══════════════════════════════════════════════════════════════════════════
  // TRANSACTIONS CRUD
  // ═══════════════════════════════════════════════════════════════════════════

  Future<int> insertTransaction(Map<String, dynamic> txn) async { final db = await database; return await db.insert('transactions', txn, conflictAlgorithm: ConflictAlgorithm.replace); }

  Future<void> insertTransactionWithItems(Map<String, dynamic> txn, List<Map<String, dynamic>> items) async {
    final db = await database;
    await db.transaction((dbTxn) async {
      await dbTxn.insert('transactions', txn, conflictAlgorithm: ConflictAlgorithm.replace);
      for (final item in items) {
        await dbTxn.insert('transaction_items', {'transactionId': txn['id'], ...item});
      }
    });
  }

  Future<int> updateTransaction(String id, Map<String, dynamic> txn) async { final db = await database; return await db.update('transactions', txn, where: 'id = ?', whereArgs: [id]); }
  Future<List<Map<String, dynamic>>> getAllTransactions() async { final db = await database; return await db.query('transactions', orderBy: 'dateTime DESC'); }
  Future<Map<String, dynamic>?> getTransactionById(String id) async { final db = await database; final r = await db.query('transactions', where: 'id = ?', whereArgs: [id]); return r.isNotEmpty ? r.first : null; }
  Future<List<Map<String, dynamic>>> getTransactionItems(String txnId) async { final db = await database; return await db.query('transaction_items', where: 'transactionId = ?', whereArgs: [txnId]); }
  Future<List<Map<String, dynamic>>> getTransactionsByDateRange(String startDate, String endDate) async { final db = await database; return await db.query('transactions', where: 'dateTime BETWEEN ? AND ?', whereArgs: [startDate, endDate], orderBy: 'dateTime DESC'); }
  Future<List<Map<String, dynamic>>> getTransactionsByStatus(String status) async { final db = await database; return await db.query('transactions', where: 'status = ?', whereArgs: [status], orderBy: 'dateTime DESC'); }
  Future<double> getDailySales(String date) async { final db = await database; final r = await db.rawQuery("SELECT COALESCE(SUM(total), 0.0) as total FROM transactions WHERE dateTime LIKE ? AND status = 'completed'", ['\$date%']); return (r.first['total'] as num?)?.toDouble() ?? 0.0; }

  // ═══════════════════════════════════════════════════════════════════════════
  // CUSTOMERS CRUD
  // ═══════════════════════════════════════════════════════════════════════════

  Future<int> insertCustomer(Map<String, dynamic> c) async { final db = await database; return await db.insert('customers', c, conflictAlgorithm: ConflictAlgorithm.replace); }
  Future<int> updateCustomer(String id, Map<String, dynamic> c) async { final db = await database; return await db.update('customers', c, where: 'id = ?', whereArgs: [id]); }
  Future<int> deleteCustomer(String id) async { final db = await database; return await db.delete('customers', where: 'id = ?', whereArgs: [id]); }
  Future<List<Map<String, dynamic>>> getAllCustomers() async { final db = await database; return await db.query('customers', orderBy: 'name ASC'); }
  Future<Map<String, dynamic>?> getCustomerById(String id) async { final db = await database; final r = await db.query('customers', where: 'id = ?', whereArgs: [id]); return r.isNotEmpty ? r.first : null; }
  Future<Map<String, dynamic>?> getCustomerByPhone(String phone) async { final db = await database; final r = await db.query('customers', where: 'phone = ?', whereArgs: [phone]); return r.isNotEmpty ? r.first : null; }
  Future<void> bulkInsertCustomers(List<Map<String, dynamic>> customers) async { final db = await database; final b = db.batch(); for (final c in customers) { b.insert('customers', c, conflictAlgorithm: ConflictAlgorithm.replace); } await b.commit(noResult: true); }

  // ═══════════════════════════════════════════════════════════════════════════
  // USERS CRUD
  // ═══════════════════════════════════════════════════════════════════════════

  Future<int> insertUser(Map<String, dynamic> u) async { final db = await database; return await db.insert('users', u, conflictAlgorithm: ConflictAlgorithm.replace); }
  Future<int> updateUser(String id, Map<String, dynamic> u) async { final db = await database; return await db.update('users', u, where: 'id = ?', whereArgs: [id]); }
  Future<int> deleteUser(String id) async { final db = await database; return await db.delete('users', where: 'id = ?', whereArgs: [id]); }
  Future<List<Map<String, dynamic>>> getAllUsers() async { final db = await database; return await db.query('users', orderBy: 'fullName ASC'); }
  Future<Map<String, dynamic>?> getUserById(String id) async { final db = await database; final r = await db.query('users', where: 'id = ?', whereArgs: [id]); return r.isNotEmpty ? r.first : null; }
  Future<Map<String, dynamic>?> authenticateUser(String username, String password) async { final db = await database; final r = await db.query('users', where: 'username = ? AND password = ? AND isActive = 1', whereArgs: [username, password]); return r.isNotEmpty ? r.first : null; }
  Future<void> bulkInsertUsers(List<Map<String, dynamic>> users) async { final db = await database; final b = db.batch(); for (final u in users) { b.insert('users', u, conflictAlgorithm: ConflictAlgorithm.replace); } await b.commit(noResult: true); }

  // ═══════════════════════════════════════════════════════════════════════════
  // BRANCHES CRUD
  // ═══════════════════════════════════════════════════════════════════════════

  Future<int> insertBranch(Map<String, dynamic> b) async { final db = await database; return await db.insert('branches', b, conflictAlgorithm: ConflictAlgorithm.replace); }
  Future<int> updateBranch(String id, Map<String, dynamic> b) async { final db = await database; return await db.update('branches', b, where: 'id = ?', whereArgs: [id]); }
  Future<int> deleteBranch(String id) async { final db = await database; return await db.delete('branches', where: 'id = ?', whereArgs: [id]); }
  Future<List<Map<String, dynamic>>> getAllBranches() async { final db = await database; return await db.query('branches', orderBy: 'name ASC'); }
  Future<Map<String, dynamic>?> getBranchById(String id) async { final db = await database; final r = await db.query('branches', where: 'id = ?', whereArgs: [id]); return r.isNotEmpty ? r.first : null; }
  Future<void> bulkInsertBranches(List<Map<String, dynamic>> branches) async { final db = await database; final b = db.batch(); for (final br in branches) { b.insert('branches', br, conflictAlgorithm: ConflictAlgorithm.replace); } await b.commit(noResult: true); }

  // ═══════════════════════════════════════════════════════════════════════════
  // EMPLOYEES CRUD
  // ═══════════════════════════════════════════════════════════════════════════

  Future<int> insertEmployee(Map<String, dynamic> e) async { final db = await database; return await db.insert('employees', e, conflictAlgorithm: ConflictAlgorithm.replace); }
  Future<int> updateEmployee(String id, Map<String, dynamic> e) async { final db = await database; return await db.update('employees', e, where: 'id = ?', whereArgs: [id]); }
  Future<int> deleteEmployee(String id) async { final db = await database; return await db.delete('employees', where: 'id = ?', whereArgs: [id]); }
  Future<List<Map<String, dynamic>>> getAllEmployees() async { final db = await database; return await db.query('employees', orderBy: 'name ASC'); }
  Future<Map<String, dynamic>?> getEmployeeById(String id) async { final db = await database; final r = await db.query('employees', where: 'id = ?', whereArgs: [id]); return r.isNotEmpty ? r.first : null; }
  Future<List<Map<String, dynamic>>> getEmployeesByBranch(String branchId) async { final db = await database; return await db.query('employees', where: 'branchId = ?', whereArgs: [branchId], orderBy: 'name ASC'); }
  Future<void> bulkInsertEmployees(List<Map<String, dynamic>> employees) async { final db = await database; final b = db.batch(); for (final e in employees) { b.insert('employees', e, conflictAlgorithm: ConflictAlgorithm.replace); } await b.commit(noResult: true); }

  // ═══════════════════════════════════════════════════════════════════════════
  // BATCH LOGS CRUD
  // ═══════════════════════════════════════════════════════════════════════════

  Future<int> insertBatchLog(Map<String, dynamic> log) async { final db = await database; return await db.insert('batch_logs', log, conflictAlgorithm: ConflictAlgorithm.replace); }
  Future<void> bulkInsertBatchLogs(List<Map<String, dynamic>> logs) async { final db = await database; final b = db.batch(); for (final log in logs) { b.insert('batch_logs', log, conflictAlgorithm: ConflictAlgorithm.replace); } await b.commit(noResult: true); }
  Future<List<Map<String, dynamic>>> getAllBatchLogs() async { final db = await database; return await db.query('batch_logs', orderBy: 'dateTime DESC'); }
  Future<List<Map<String, dynamic>>> getBatchLogsByBatchId(String batchId) async { final db = await database; return await db.query('batch_logs', where: 'batchId = ?', whereArgs: [batchId], orderBy: 'dateTime DESC'); }

  Future<List<Map<String, dynamic>>> getFilteredBatchLogs({String? dateFrom, String? dateTo, String? search}) async {
    final db = await database; String where = '1=1'; List<dynamic> args = [];
    if (dateFrom != null) { where += ' AND dateTime >= ?'; args.add(dateFrom); }
    if (dateTo != null) { where += ' AND dateTime <= ?'; args.add(dateTo); }
    if (search != null && search.isNotEmpty) { where += ' AND (batchNumber LIKE ? OR productName LIKE ? OR productSku LIKE ? OR action LIKE ?)'; args.addAll(['%\$search%', '%\$search%', '%\$search%', '%\$search%']); }
    return await db.query('batch_logs', where: where, whereArgs: args, orderBy: 'dateTime DESC');
  }

  Future<void> clearBatchLogs() async { final db = await database; await db.delete('batch_logs'); }

  // ═══════════════════════════════════════════════════════════════════════════
  // ADJUSTMENT RECORDS CRUD
  // ═══════════════════════════════════════════════════════════════════════════

  Future<int> insertAdjustmentRecord(Map<String, dynamic> r) async { final db = await database; return await db.insert('adjustment_records', r, conflictAlgorithm: ConflictAlgorithm.replace); }
  Future<void> bulkInsertAdjustments(List<Map<String, dynamic>> records) async { final db = await database; final b = db.batch(); for (final r in records) { b.insert('adjustment_records', r, conflictAlgorithm: ConflictAlgorithm.replace); } await b.commit(noResult: true); }
  Future<List<Map<String, dynamic>>> getAllAdjustmentRecords() async { final db = await database; return await db.query('adjustment_records', orderBy: 'dateTime DESC'); }

  Future<List<Map<String, dynamic>>> getFilteredAdjustments({String? dateFrom, String? dateTo, String? search}) async {
    final db = await database; String where = '1=1'; List<dynamic> args = [];
    if (dateFrom != null) { where += ' AND dateTime >= ?'; args.add(dateFrom); }
    if (dateTo != null) { where += ' AND dateTime <= ?'; args.add(dateTo); }
    if (search != null && search.isNotEmpty) { where += ' AND (itemName LIKE ? OR sku LIKE ? OR reason LIKE ?)'; args.addAll(['%\$search%', '%\$search%', '%\$search%']); }
    return await db.query('adjustment_records', where: where, whereArgs: args, orderBy: 'dateTime DESC');
  }

  Future<void> clearAdjustmentRecords() async { final db = await database; await db.delete('adjustment_records'); }

  // ═══════════════════════════════════════════════════════════════════════════
  // STOCK TRANSFERS CRUD
  // ═══════════════════════════════════════════════════════════════════════════

  Future<int> insertStockTransfer(Map<String, dynamic> t) async { final db = await database; return await db.insert('stock_transfers', t, conflictAlgorithm: ConflictAlgorithm.replace); }

  Future<void> insertTransferWithItems(Map<String, dynamic> transfer, List<Map<String, dynamic>> items) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert('stock_transfers', transfer, conflictAlgorithm: ConflictAlgorithm.replace);
      for (final item in items) { await txn.insert('transfer_items', {'transferId': transfer['id'], ...item}); }
    });
  }

  Future<int> updateStockTransfer(String id, Map<String, dynamic> t) async { final db = await database; return await db.update('stock_transfers', t, where: 'id = ?', whereArgs: [id]); }
  Future<int> deleteStockTransfer(String id) async { final db = await database; await db.delete('transfer_items', where: 'transferId = ?', whereArgs: [id]); return await db.delete('stock_transfers', where: 'id = ?', whereArgs: [id]); }
  Future<List<Map<String, dynamic>>> getAllStockTransfers() async { final db = await database; return await db.query('stock_transfers', orderBy: 'createdAt DESC'); }
  Future<Map<String, dynamic>?> getStockTransferById(String id) async { final db = await database; final r = await db.query('stock_transfers', where: 'id = ?', whereArgs: [id]); return r.isNotEmpty ? r.first : null; }
  Future<List<Map<String, dynamic>>> getTransfersByStatus(String status) async { final db = await database; return await db.query('stock_transfers', where: 'status = ?', whereArgs: [status], orderBy: 'createdAt DESC'); }
  Future<List<Map<String, dynamic>>> getTransferItems(String transferId) async { final db = await database; return await db.query('transfer_items', where: 'transferId = ?', whereArgs: [transferId]); }

  Future<void> replaceTransferItems(String transferId, List<Map<String, dynamic>> items) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('transfer_items', where: 'transferId = ?', whereArgs: [transferId]);
      for (final item in items) { await txn.insert('transfer_items', {'transferId': transferId, ...item}); }
    });
  }

  Future<void> bulkInsertTransfers(List<Map<String, dynamic>> transfers) async { final db = await database; final b = db.batch(); for (final t in transfers) { b.insert('stock_transfers', t, conflictAlgorithm: ConflictAlgorithm.replace); } await b.commit(noResult: true); }

  // ═══════════════════════════════════════════════════════════════════════════
  // TRANSFER LEDGER CRUD
  // ═══════════════════════════════════════════════════════════════════════════

  Future<int> insertLedgerEntry(Map<String, dynamic> entry) async { final db = await database; return await db.insert('transfer_ledger', entry, conflictAlgorithm: ConflictAlgorithm.replace); }
  Future<void> bulkInsertLedgerEntries(List<Map<String, dynamic>> entries) async { final db = await database; final b = db.batch(); for (final e in entries) { b.insert('transfer_ledger', e, conflictAlgorithm: ConflictAlgorithm.replace); } await b.commit(noResult: true); }
  Future<List<Map<String, dynamic>>> getAllLedgerEntries() async { final db = await database; return await db.query('transfer_ledger', orderBy: 'date DESC'); }
  Future<List<Map<String, dynamic>>> getLedgerByItem(String itemId) async { final db = await database; return await db.query('transfer_ledger', where: 'itemId = ?', whereArgs: [itemId], orderBy: 'date DESC'); }
  Future<List<Map<String, dynamic>>> getLedgerByRef(String refNo) async { final db = await database; return await db.query('transfer_ledger', where: 'referenceNo = ?', whereArgs: [refNo], orderBy: 'date DESC'); }
  Future<List<Map<String, dynamic>>> getLedgerByBatch(String batchNumber) async { final db = await database; return await db.query('transfer_ledger', where: 'batchNumber = ?', whereArgs: [batchNumber], orderBy: 'date DESC'); }

  // ═══════════════════════════════════════════════════════════════════════════
  // DELIVERY RECORDS CRUD
  // ═══════════════════════════════════════════════════════════════════════════

  Future<int> insertDeliveryRecord(Map<String, dynamic> d) async { final db = await database; return await db.insert('delivery_records', d, conflictAlgorithm: ConflictAlgorithm.replace); }

  Future<void> insertDeliveryWithItems(Map<String, dynamic> delivery, List<Map<String, dynamic>> items) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert('delivery_records', delivery, conflictAlgorithm: ConflictAlgorithm.replace);
      for (final item in items) { await txn.insert('delivery_items', {'deliveryId': delivery['id'], ...item}); }
    });
  }

  Future<List<Map<String, dynamic>>> getAllDeliveryRecords() async { final db = await database; return await db.query('delivery_records', orderBy: 'dateTime DESC'); }
  Future<Map<String, dynamic>?> getDeliveryById(String id) async { final db = await database; final r = await db.query('delivery_records', where: 'id = ?', whereArgs: [id]); return r.isNotEmpty ? r.first : null; }
  Future<List<Map<String, dynamic>>> getDeliveryItems(String deliveryId) async { final db = await database; return await db.query('delivery_items', where: 'deliveryId = ?', whereArgs: [deliveryId]); }

  Future<List<Map<String, dynamic>>> getFilteredDeliveries({String? dateFrom, String? dateTo, String? search}) async {
    final db = await database; String where = '1=1'; List<dynamic> args = [];
    if (dateFrom != null) { where += ' AND dateTime >= ?'; args.add(dateFrom); }
    if (dateTo != null) { where += ' AND dateTime <= ?'; args.add(dateTo); }
    if (search != null && search.isNotEmpty) { where += ' AND (refNumber LIKE ? OR supplier LIKE ? OR driverName LIKE ? OR receivedBy LIKE ?)'; args.addAll(['%\$search%', '%\$search%', '%\$search%', '%\$search%']); }
    return await db.query('delivery_records', where: where, whereArgs: args, orderBy: 'dateTime DESC');
  }

  Future<List<Map<String, dynamic>>> getDailyDeliveries(String date) async { final db = await database; return await db.query('delivery_records', where: 'dateTime LIKE ?', whereArgs: ['\$date%'], orderBy: 'dateTime DESC'); }
  Future<void> bulkInsertDeliveries(List<Map<String, dynamic>> deliveries) async { final db = await database; final b = db.batch(); for (final d in deliveries) { b.insert('delivery_records', d, conflictAlgorithm: ConflictAlgorithm.replace); } await b.commit(noResult: true); }
  Future<void> clearDeliveryRecords() async { final db = await database; await db.delete('delivery_items'); await db.delete('delivery_records'); }

  // ═══════════════════════════════════════════════════════════════════════════
  // DISCOUNT RECORDS CRUD
  // ═══════════════════════════════════════════════════════════════════════════

  Future<int> insertDiscountRecord(Map<String, dynamic> d) async { final db = await database; return await db.insert('discount_records', d); }

  Future<int> insertDiscountWithItems(Map<String, dynamic> record, List<Map<String, dynamic>> items) async {
    final db = await database; int recordId = 0;
    await db.transaction((txn) async {
      recordId = await txn.insert('discount_records', record);
      for (final item in items) { await txn.insert('discount_items', {'discountRecordId': recordId, ...item}); }
    });
    return recordId;
  }

  Future<List<Map<String, dynamic>>> getAllDiscountRecords() async { final db = await database; return await db.query('discount_records', orderBy: 'dateTime DESC'); }
  Future<List<Map<String, dynamic>>> getDiscountItems(int discountRecordId) async { final db = await database; return await db.query('discount_items', where: 'discountRecordId = ?', whereArgs: [discountRecordId]); }
  Future<List<Map<String, dynamic>>> getDiscountsByType(String type) async { final db = await database; if (type == 'All') return await getAllDiscountRecords(); return await db.query('discount_records', where: 'discountType = ?', whereArgs: [type], orderBy: 'dateTime DESC'); }
  Future<List<Map<String, dynamic>>> getDiscountsByDateRange(String startDate, String endDate) async { final db = await database; return await db.query('discount_records', where: 'dateTime BETWEEN ? AND ?', whereArgs: [startDate, endDate], orderBy: 'dateTime DESC'); }
  Future<void> clearDiscountRecords() async { final db = await database; await db.delete('discount_items'); await db.delete('discount_records'); }

  // ═══════════════════════════════════════════════════════════════════════════
  // UTILITY
  // ═══════════════════════════════════════════════════════════════════════════

  Future<bool> isDatabaseEmpty() async { final db = await database; final r = await db.rawQuery('SELECT COUNT(*) as c FROM products'); return (r.first['c'] as int) == 0; }

  Future<Map<String, dynamic>> getDashboardStats(String date) async {
    final db = await database;
    final sales = await db.rawQuery("SELECT COALESCE(SUM(total), 0.0) as s FROM transactions WHERE dateTime LIKE ? AND status = 'completed'", ['\$date%']);
    final txnCount = await db.rawQuery("SELECT COUNT(*) as c FROM transactions WHERE dateTime LIKE ? AND status = 'completed'", ['\$date%']);
    final prodCount = await db.rawQuery('SELECT COUNT(*) as c FROM products');
    final lowStock = await db.rawQuery('SELECT COUNT(*) as c FROM products WHERE stockQty <= reorderLevel');
    return { 'todaySales': (sales.first['s'] as num?)?.toDouble() ?? 0.0, 'todayTxnCount': (txnCount.first['c'] as int?) ?? 0, 'totalProducts': (prodCount.first['c'] as int?) ?? 0, 'lowStockCount': (lowStock.first['c'] as int?) ?? 0, };
  }

  Future<Map<String, List<Map<String, dynamic>>>> exportAllData() async {
    final db = await database;
    final tables = ['products', 'batches', 'transactions', 'transaction_items', 'customers', 'users', 'branches', 'employees', 'batch_logs', 'adjustment_records', 'stock_transfers', 'transfer_items', 'transfer_ledger', 'delivery_records', 'delivery_items', 'discount_records', 'discount_items'];
    final Map<String, List<Map<String, dynamic>>> data = {};
    for (final table in tables) { try { data[table] = await db.query(table); } catch (_) { data[table] = []; } }
    return data;
  }

  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('discount_items'); await db.delete('discount_records');
    await db.delete('delivery_items'); await db.delete('delivery_records');
    await db.delete('transfer_items'); await db.delete('transfer_ledger'); await db.delete('stock_transfers');
    await db.delete('adjustment_records'); await db.delete('batch_logs'); await db.delete('employees');
    await db.delete('transaction_items'); await db.delete('transactions');
    await db.delete('batches'); await db.delete('products');
    await db.delete('customers'); await db.delete('users'); await db.delete('branches');
  }

  Future<void> close() async { final db = await database; await db.close(); _database = null; }
  // ═══════════════════════════════════════════════════════════════════════════
  // EXPENSES CRUD
  // ═══════════════════════════════════════════════════════════════════════════
  Future<int> insertExpense(Map<String, dynamic> e) async { final db = await database; return await db.insert('expenses', e, conflictAlgorithm: ConflictAlgorithm.replace); }
  Future<int> updateExpense(String id, Map<String, dynamic> e) async { final db = await database; return await db.update('expenses', e, where: 'id = ?', whereArgs: [id]); }
  Future<List<Map<String, dynamic>>> getAllExpenses() async { final db = await database; return await db.query('expenses', orderBy: 'dateCreated DESC'); }
  Future<List<Map<String, dynamic>>> getExpensesByStatus(String status) async { final db = await database; return await db.query('expenses', where: 'status = ?', whereArgs: [status], orderBy: 'dateCreated DESC'); }
  Future<List<Map<String, dynamic>>> getFilteredExpenses({String? dateFrom, String? dateTo, String? branch, String? category, String? status, String? paymentMethod, String? preparedBy, String? search}) async {
    final db = await database; String w = '1=1'; final args = <dynamic>[];
    if (dateFrom != null) { w += ' AND expenseDate >= ?'; args.add(dateFrom); }
    if (dateTo != null) { w += ' AND expenseDate <= ?'; args.add(dateTo); }
    if (branch != null && branch.isNotEmpty) { w += ' AND branch = ?'; args.add(branch); }
    if (category != null && category.isNotEmpty) { w += ' AND categoryName = ?'; args.add(category); }
    if (status != null && status.isNotEmpty) { w += ' AND status = ?'; args.add(status); }
    if (paymentMethod != null && paymentMethod.isNotEmpty) { w += ' AND paymentMethod = ?'; args.add(paymentMethod); }
    if (preparedBy != null && preparedBy.isNotEmpty) { w += ' AND preparedBy = ?'; args.add(preparedBy); }
    if (search != null && search.isNotEmpty) { w += ' AND (expenseNumber LIKE ? OR remarks LIKE ? OR payeeSupplier LIKE ? OR categoryName LIKE ?)'; args.addAll(['%$search%', '%$search%', '%$search%', '%$search%']); }
    return await db.query('expenses', where: w, whereArgs: args, orderBy: 'dateCreated DESC');
  }
  Future<Map<String, dynamic>> getExpenseSummary({String? branch, String? month}) async {
    final db = await database; String w = '1=1'; final args = <dynamic>[];
    if (branch != null) { w += ' AND branch = ?'; args.add(branch); }
    if (month != null) { w += ' AND expenseDate LIKE ?'; args.add('$month%'); }
    final total = await db.rawQuery('SELECT SUM(amount) as total, COUNT(*) as cnt FROM expenses WHERE $w AND status = "Approved"', args);
    final forApproval = await db.rawQuery('SELECT COUNT(*) as cnt FROM expenses WHERE status = "For Approval"');
    final draft = await db.rawQuery('SELECT COUNT(*) as cnt FROM expenses WHERE status = "Draft"');
    final rejected = await db.rawQuery('SELECT COUNT(*) as cnt FROM expenses WHERE status = "Rejected"');
    final returned = await db.rawQuery('SELECT COUNT(*) as cnt FROM expenses WHERE status = "Returned"');
    return {'totalApproved': total.first['total'] ?? 0, 'countApproved': total.first['cnt'] ?? 0, 'forApproval': forApproval.first['cnt'] ?? 0, 'draft': draft.first['cnt'] ?? 0, 'rejected': rejected.first['cnt'] ?? 0, 'returned': returned.first['cnt'] ?? 0};
  }
  Future<List<Map<String, dynamic>>> rawQuery(String sql, [List<dynamic>? args]) async { final db = await database; return await db.rawQuery(sql, args); }

  Future<int> insertExpenseCategory(Map<String, dynamic> c) async { final db = await database; return await db.insert('expense_categories', c, conflictAlgorithm: ConflictAlgorithm.replace); }
  Future<int> updateExpenseCategory(String id, Map<String, dynamic> c) async { final db = await database; return await db.update('expense_categories', c, where: 'id = ?', whereArgs: [id]); }
  Future<List<Map<String, dynamic>>> getExpenseCategories() async { final db = await database; return await db.query('expense_categories', orderBy: 'name ASC'); }

  Future<int> insertExpenseSubCategory(Map<String, dynamic> c) async { final db = await database; return await db.insert('expense_sub_categories', c, conflictAlgorithm: ConflictAlgorithm.replace); }
  Future<int> updateExpenseSubCategory(String id, Map<String, dynamic> c) async { final db = await database; return await db.update('expense_sub_categories', c, where: 'id = ?', whereArgs: [id]); }
  Future<List<Map<String, dynamic>>> getExpenseSubCategories({String? categoryId}) async { final db = await database; if (categoryId != null) return await db.query('expense_sub_categories', where: 'categoryId = ?', whereArgs: [categoryId], orderBy: 'name ASC'); return await db.query('expense_sub_categories', orderBy: 'name ASC'); }

  Future<int> insertExpenseAudit(Map<String, dynamic> a) async { final db = await database; return await db.insert('expense_audit_trail', a, conflictAlgorithm: ConflictAlgorithm.replace); }
  Future<List<Map<String, dynamic>>> getExpenseAuditTrail({String? expenseId}) async { final db = await database; if (expenseId != null) return await db.query('expense_audit_trail', where: 'expenseId = ?', whereArgs: [expenseId], orderBy: 'performedDate DESC'); return await db.query('expense_audit_trail', orderBy: 'performedDate DESC'); }

  Future<int> insertExpenseBudget(Map<String, dynamic> b) async { final db = await database; return await db.insert('expense_budgets', b, conflictAlgorithm: ConflictAlgorithm.replace); }
  Future<int> updateExpenseBudget(String id, Map<String, dynamic> b) async { final db = await database; return await db.update('expense_budgets', b, where: 'id = ?', whereArgs: [id]); }
  Future<List<Map<String, dynamic>>> getExpenseBudgets() async { final db = await database; return await db.query('expense_budgets'); }

  Future<int> insertPettyCashTransaction(Map<String, dynamic> t) async { final db = await database; return await db.insert('petty_cash_transactions', t, conflictAlgorithm: ConflictAlgorithm.replace); }
  Future<List<Map<String, dynamic>>> getPettyCashTransactions({String? branch}) async { final db = await database; if (branch != null) return await db.query('petty_cash_transactions', where: 'branch = ?', whereArgs: [branch], orderBy: 'performedDate DESC'); return await db.query('petty_cash_transactions', orderBy: 'performedDate DESC'); }
  Future<double> getPettyCashBalance(String branch) async { final db = await database; final r = await db.rawQuery('SELECT SUM(CASE WHEN transactionType IN ("Add Fund","Replenish") THEN amount ELSE -amount END) as bal FROM petty_cash_transactions WHERE branch = ?', [branch]); return (r.first['bal'] as num?)?.toDouble() ?? 0; }

  // ── Exchanges ──
  Future<int> insertExchange(Map<String, dynamic> e) async { final db = await database; return await db.insert('exchanges', e, conflictAlgorithm: ConflictAlgorithm.replace); }
  Future<List<Map<String, dynamic>>> getAllExchanges() async { final db = await database; return await db.query('exchanges', orderBy: 'dateCreated DESC'); }
  Future<List<Map<String, dynamic>>> getExchangesByTxn(String txnId) async { final db = await database; return await db.query('exchanges', where: 'originalTxnId = ?', whereArgs: [txnId], orderBy: 'dateCreated DESC'); }

  // ── Branch Info ──
  Future<void> createBranchTable(db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS branch_info (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        address TEXT,
        phone TEXT,
        email TEXT,
        createdAt TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');
  }

  Future<int> saveBranch(Map<String, dynamic> data) async {
    final db = await database;
    await db.execute('''
      CREATE TABLE IF NOT EXISTS branch_info (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        address TEXT,
        phone TEXT,
        email TEXT,
        createdAt TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');
    return await db.insert('branch_info', data);
  }

  Future<Map<String, dynamic>?> getBranch() async {
    final db = await database;
    await db.execute('''
      CREATE TABLE IF NOT EXISTS branch_info (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        address TEXT,
        phone TEXT,
        email TEXT,
        createdAt TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');
    final result = await db.query('branch_info', limit: 1);
    return result.isNotEmpty ? result.first : null;
  }

  Future<bool> hasBranch() async {
    final branch = await getBranch();
    return branch != null;
  }

}