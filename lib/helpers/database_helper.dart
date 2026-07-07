import 'package:flutter/foundation.dart';
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
      path, version: 15,
      onCreate: _createDB, onUpgrade: _upgradeDB,
      onConfigure: (db) async => await db.execute('PRAGMA foreign_keys = ON'),
      onOpen: _ensureAllTables,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CREATE ALL 17 TABLES (fresh install)
  // ═══════════════════════════════════════════════════════════════════════════
  // ═══════════════════════════════════════════════════════════════════════════
  // 🛡️ BULLETPROOF: Ensure ALL critical tables exist on EVERY app open
  // This protects against DB version mismatches, failed migrations, etc.
  // ═══════════════════════════════════════════════════════════════════════════
  Future<void> _ensureAllTables(Database db) async {
    // Store Profile table
    // BRANCH INVENTORY V2 - per-branch stock tracking
    // SINGLE source of truth for stock (not dual update!)
    // products.stockQty is for INITIAL value only, never updated after creation
    try {
      await db.execute("""
        CREATE TABLE IF NOT EXISTS branch_inventory (
          branchId TEXT NOT NULL,
          productId TEXT NOT NULL,
          stockQty INTEGER DEFAULT 0,
          reservedQty INTEGER DEFAULT 0,
          inTransitInQty INTEGER DEFAULT 0,
          inTransitOutQty INTEGER DEFAULT 0,
          reorderLevel INTEGER DEFAULT 5,
          lastUpdated TEXT NOT NULL,
          updatedAt TEXT NOT NULL,
          deviceId TEXT DEFAULT '',
          isDeleted INTEGER DEFAULT 0,
          isMigrated INTEGER DEFAULT 0,
          PRIMARY KEY (branchId, productId)
        )
      """);
    } catch (_) {}
    try { await db.execute("CREATE INDEX IF NOT EXISTS idx_binv_branch ON branch_inventory(branchId)"); } catch (_) {}
    try { await db.execute("CREATE INDEX IF NOT EXISTS idx_binv_product ON branch_inventory(productId)"); } catch (_) {}
    // ALWAYS RUN USER COLUMN MIGRATIONS - runs on EVERY DB open
    // try/catch makes them idempotent (safe if column already exists)
    // This fixes existing devices where onUpgrade was skipped
    try { await db.execute("ALTER TABLE users ADD COLUMN allowPosTransaction INTEGER DEFAULT 0"); } catch (_) {}
    try { await db.execute("ALTER TABLE users ADD COLUMN isDeleted INTEGER DEFAULT 0"); } catch (_) {}
    try { await db.execute("ALTER TABLE users ADD COLUMN updatedAt TEXT DEFAULT ''"); } catch (_) {}
    try { await db.execute("ALTER TABLE users ADD COLUMN deletedAt TEXT DEFAULT ''"); } catch (_) {}
    try { await db.execute("ALTER TABLE users ADD COLUMN deletedBy TEXT DEFAULT ''"); } catch (_) {}
    try { await db.execute("ALTER TABLE users ADD COLUMN deletedReason TEXT DEFAULT ''"); } catch (_) {}
    try { await db.execute("ALTER TABLE users ADD COLUMN syncStatus TEXT DEFAULT ''"); } catch (_) {}
    try { await db.execute("ALTER TABLE users ADD COLUMN lastModifiedAt TEXT DEFAULT ''"); } catch (_) {}
    try { await db.execute("ALTER TABLE users ADD COLUMN lastSyncedAt TEXT DEFAULT ''"); } catch (_) {}
    try { await db.execute("ALTER TABLE users ADD COLUMN firebaseId TEXT DEFAULT ''"); } catch (_) {}
    try { await db.execute("ALTER TABLE users ADD COLUMN firebasePath TEXT DEFAULT ''"); } catch (_) {}
    try { await db.execute("ALTER TABLE users ADD COLUMN companyId TEXT DEFAULT ''"); } catch (_) {}
    try { await db.execute("ALTER TABLE users ADD COLUMN branchId_sync TEXT DEFAULT ''"); } catch (_) {}
    try { await db.execute("ALTER TABLE users ADD COLUMN deviceId TEXT DEFAULT ''"); } catch (_) {}
    try { await db.execute("ALTER TABLE users ADD COLUMN createdBy_sync TEXT DEFAULT ''"); } catch (_) {}
    try { await db.execute("ALTER TABLE users ADD COLUMN updatedBy_sync TEXT DEFAULT ''"); } catch (_) {}
    // ═══ WORKFLOW: Delivery Records status columns ═══
    try { await db.execute("ALTER TABLE delivery_records ADD COLUMN status TEXT DEFAULT 'Draft'"); } catch (_) {}
    try { await db.execute("ALTER TABLE delivery_records ADD COLUMN submittedDate TEXT DEFAULT ''"); } catch (_) {}
    try { await db.execute("ALTER TABLE delivery_records ADD COLUMN submittedBy TEXT DEFAULT ''"); } catch (_) {}
    try { await db.execute("ALTER TABLE delivery_records ADD COLUMN approvedDate TEXT DEFAULT ''"); } catch (_) {}
    try { await db.execute("ALTER TABLE delivery_records ADD COLUMN approvedBy TEXT DEFAULT ''"); } catch (_) {}
    try { await db.execute("ALTER TABLE delivery_records ADD COLUMN rejectedDate TEXT DEFAULT ''"); } catch (_) {}
    try { await db.execute("ALTER TABLE delivery_records ADD COLUMN rejectedBy TEXT DEFAULT ''"); } catch (_) {}
    try { await db.execute("ALTER TABLE delivery_records ADD COLUMN rejectionReason TEXT DEFAULT ''"); } catch (_) {}
    try { await db.execute("ALTER TABLE delivery_records ADD COLUMN lastEditedDate TEXT DEFAULT ''"); } catch (_) {}
    try { await db.execute("ALTER TABLE delivery_records ADD COLUMN syncStatus TEXT DEFAULT 'Pending'"); } catch (_) {}
    try { await db.execute("CREATE TABLE IF NOT EXISTS approval_history (id TEXT PRIMARY KEY, deliveryId TEXT NOT NULL, action TEXT NOT NULL, user TEXT DEFAULT '', date TEXT NOT NULL, remarks TEXT DEFAULT '')"); } catch (_) {}
    try { await db.execute("UPDATE delivery_records SET status = 'Approved' WHERE status IS NULL OR status = ''"); } catch (_) {}
    // DELIVERY RECORDS BRANCH MIGRATION - per-branch delivery tagging
    try { await db.execute("ALTER TABLE delivery_records ADD COLUMN branchId TEXT DEFAULT ''"); } catch (_) {}
    try { await db.execute("ALTER TABLE delivery_records ADD COLUMN branchName TEXT DEFAULT ''"); } catch (_) {}
    try {
    // STOCK TRANSFER DEVICE MIGRATION - device-based filtering support
    try { await db.execute("ALTER TABLE stock_transfers ADD COLUMN fromDeviceId TEXT DEFAULT ''"); } catch (_) {}
    try { await db.execute("ALTER TABLE stock_transfers ADD COLUMN toDeviceId TEXT DEFAULT ''"); } catch (_) {}
      await db.execute('CREATE TABLE IF NOT EXISTS store_profile (id INTEGER PRIMARY KEY, storeName TEXT DEFAULT "", branch TEXT DEFAULT "", businessType TEXT DEFAULT "Retail Store", owner TEXT DEFAULT "", address TEXT DEFAULT "", phone TEXT DEFAULT "", email TEXT DEFAULT "", tin TEXT DEFAULT "", logoPath TEXT DEFAULT "", receiptHeader TEXT DEFAULT "", receiptFooter TEXT DEFAULT "Thank you for shopping!", vatRegistered INTEGER DEFAULT 0, updatedAt TEXT)');
    } catch (_) {}

    // Cashier Locking System tables
    try {
      await db.execute('''CREATE TABLE IF NOT EXISTS cashier_sessions (id TEXT PRIMARY KEY, shiftId TEXT UNIQUE NOT NULL, cashierId TEXT NOT NULL, cashierName TEXT DEFAULT '', branch TEXT DEFAULT '', beginningCash REAL DEFAULT 0, beginningSource TEXT DEFAULT 'Vault', beginningRemarks TEXT DEFAULT '', endingCashDeclared REAL DEFAULT 0, systemExpectedCash REAL DEFAULT 0, variance REAL DEFAULT 0, varianceType TEXT DEFAULT 'balanced', status TEXT DEFAULT 'open', openedAt TEXT NOT NULL, closedAt TEXT, cashSales REAL DEFAULT 0, gcashSales REAL DEFAULT 0, mayaSales REAL DEFAULT 0, cardSales REAL DEFAULT 0, otherSales REAL DEFAULT 0, totalRefunds REAL DEFAULT 0, totalVoids REAL DEFAULT 0, totalDiscounts REAL DEFAULT 0, totalExchanges REAL DEFAULT 0, transactionCount INTEGER DEFAULT 0, originalDeclared REAL DEFAULT 0, originalVariance REAL DEFAULT 0, adjustedBy TEXT DEFAULT '', adjustedAt TEXT, adjustmentReason TEXT DEFAULT '', wasAdjusted INTEGER DEFAULT 0)''');
    } catch (_) {}

    try {
      await db.execute('''CREATE TABLE IF NOT EXISTS denomination_records (id INTEGER PRIMARY KEY AUTOINCREMENT, sessionId TEXT NOT NULL, type TEXT DEFAULT 'ending', denomination REAL NOT NULL, quantity INTEGER DEFAULT 0, total REAL DEFAULT 0, createdAt TEXT)''');
    } catch (_) {}

    try {
      await db.execute('''CREATE TABLE IF NOT EXISTS incident_reports (id TEXT PRIMARY KEY, irNumber TEXT UNIQUE, sessionId TEXT NOT NULL, cashierId TEXT DEFAULT '', cashierName TEXT DEFAULT '', branch TEXT DEFAULT '', variance REAL DEFAULT 0, varianceType TEXT DEFAULT '', reason TEXT DEFAULT '', remarks TEXT DEFAULT '', attachmentPath TEXT DEFAULT '', createdBy TEXT DEFAULT '', createdAt TEXT NOT NULL, approvedBy TEXT DEFAULT '', approvedAt TEXT, status TEXT DEFAULT 'pending')''');
    } catch (_) {}


    // 🛡️ Business Day State (BULLETPROOF safety net for fresh installs)
    try {
      await db.execute('''CREATE TABLE IF NOT EXISTS business_day_state (branchId TEXT PRIMARY KEY, status TEXT DEFAULT 'open', lockedAt TEXT DEFAULT '', lockedByZReportId TEXT DEFAULT '', unlockedAt TEXT DEFAULT '', unlockedBy TEXT DEFAULT '', unlockReason TEXT DEFAULT '', cashDeclared INTEGER DEFAULT 0, cashDeclaredAt TEXT DEFAULT '', updatedAt TEXT DEFAULT '')''');
    } catch (_) {}
    try { await db.execute("ALTER TABLE business_day_state ADD COLUMN cashDeclared INTEGER DEFAULT 0"); } catch (_) {}
    try { await db.execute("ALTER TABLE business_day_state ADD COLUMN cashDeclaredAt TEXT DEFAULT ''"); } catch (_) {}
    try {
      await db.execute('''CREATE TABLE IF NOT EXISTS z_reports (reportId TEXT PRIMARY KEY, reportDate TEXT NOT NULL, generatedAt TEXT NOT NULL, branch TEXT DEFAULT '', cashier TEXT DEFAULT '', grossSales REAL DEFAULT 0, totalDiscount REAL DEFAULT 0, netSales REAL DEFAULT 0, totalTransactions INTEGER DEFAULT 0, averageTransaction REAL DEFAULT 0, paymentBreakdownJson TEXT DEFAULT '', voidedCount INTEGER DEFAULT 0, voidedAmount REAL DEFAULT 0, voidedTransactionsJson TEXT DEFAULT '', beginningCash REAL DEFAULT 0, endingCash REAL DEFAULT 0, expectedCash REAL DEFAULT 0, overShort REAL DEFAULT 0, refundedCount INTEGER DEFAULT 0, refundedAmount REAL DEFAULT 0, allTransactionsJson TEXT DEFAULT '')''');
    try { await db.execute("ALTER TABLE z_reports ADD COLUMN refundedTransactionsJson TEXT DEFAULT ''"); } catch (_) {}
    } catch (_) {}

    try {
      await db.execute('''CREATE TABLE IF NOT EXISTS adjustment_reasons (id TEXT PRIMARY KEY, label TEXT NOT NULL, type TEXT NOT NULL, iconName TEXT DEFAULT 'edit', isDefault INTEGER DEFAULT 0, isActive INTEGER DEFAULT 1, sortOrder INTEGER DEFAULT 0, dateCreated TEXT NOT NULL)''');
    } catch (_) {}

    try {
      await db.execute('''CREATE TABLE IF NOT EXISTS adjustment_records (id TEXT PRIMARY KEY, itemName TEXT NOT NULL, sku TEXT DEFAULT '', adjustmentType TEXT NOT NULL, quantity INTEGER DEFAULT 0, oldStock INTEGER DEFAULT 0, newStock INTEGER DEFAULT 0, reason TEXT DEFAULT '', notes TEXT DEFAULT '', dateTime TEXT NOT NULL, cost REAL DEFAULT 0, retail REAL DEFAULT 0)''');
    } catch (_) {}

    
    // ═══ ENTERPRISE STOCK MOVEMENTS LEDGER ═══
    // Unified audit log for ALL SOH changes (Adjustment/Sale/Void/Refund/Delivery)

        
    // ═══ ADJUSTMENTS V3 approval columns (safety net) ═══
    try { await db.execute("ALTER TABLE adjustments_v3 ADD COLUMN submitted_by TEXT DEFAULT ''"); } catch (_) {}
    try { await db.execute("ALTER TABLE adjustments_v3 ADD COLUMN approved_by_pin TEXT DEFAULT ''"); } catch (_) {}
    try { await db.execute("ALTER TABLE adjustments_v3 ADD COLUMN approved_by_role TEXT DEFAULT ''"); } catch (_) {}

    // ═══ ADJUSTMENTS V3 HEADER (workflow) ═══
    // Stores adjustment documents with status: DRAFT/SUBMITTED/APPROVED/REJECTED
    try {
      await db.execute("""
        CREATE TABLE IF NOT EXISTS adjustments_v3 (
          adjustment_id     TEXT PRIMARY KEY,
          doc_number        TEXT,
          status            TEXT NOT NULL DEFAULT 'DRAFT',
          branch_code       TEXT NOT NULL,
          branch_name       TEXT DEFAULT '',
          created_by_name   TEXT DEFAULT '',
          created_by_pin    TEXT DEFAULT '',
          created_by_id     TEXT DEFAULT '',
          device_id         TEXT DEFAULT '',
          total_items       INTEGER NOT NULL DEFAULT 0,
          total_positive    INTEGER NOT NULL DEFAULT 0,
          total_negative    INTEGER NOT NULL DEFAULT 0,
          notes             TEXT DEFAULT '',
          submitted_at      TEXT DEFAULT '',
          approved_at       TEXT DEFAULT '',
          approved_by       TEXT DEFAULT '',
          rejected_at       TEXT DEFAULT '',
          rejected_by       TEXT DEFAULT '',
          rejection_reason  TEXT DEFAULT '',
          sync_status       TEXT DEFAULT 'PENDING',
          created_at        TEXT NOT NULL,
          updated_at        TEXT NOT NULL
        )
      """);
    } catch (_) {}
    try { await db.execute("CREATE INDEX IF NOT EXISTS idx_adj_v3_status ON adjustments_v3(status, branch_code)"); } catch (_) {}
    try { await db.execute("CREATE INDEX IF NOT EXISTS idx_adj_v3_created ON adjustments_v3(created_at DESC)"); } catch (_) {}

    // ═══ ADJUSTMENTS V3 LINE ITEMS ═══
    // Each row = one product in the adjustment document
    try {
      await db.execute("""
        CREATE TABLE IF NOT EXISTS adjustment_v3_items (
          item_id           INTEGER PRIMARY KEY AUTOINCREMENT,
          adjustment_id     TEXT NOT NULL,
          product_id        TEXT NOT NULL,
          sku               TEXT NOT NULL,
          product_name      TEXT NOT NULL,
          category          TEXT DEFAULT '',
          qty               INTEGER NOT NULL DEFAULT 0,
          reason_code       TEXT NOT NULL,
          reason_name       TEXT NOT NULL,
          direction         INTEGER NOT NULL DEFAULT -1,
          unit_cost         REAL DEFAULT 0,
          notes             TEXT DEFAULT '',
          created_at        TEXT NOT NULL,
          FOREIGN KEY (adjustment_id) REFERENCES adjustments_v3(adjustment_id) ON DELETE CASCADE
        )
      """);
    } catch (_) {}
    try { await db.execute("CREATE INDEX IF NOT EXISTS idx_adj_v3_items_doc ON adjustment_v3_items(adjustment_id)"); } catch (_) {}

    // ═══ ADJUSTMENT REASONS V3 (auto direction from name) ═══
    try {
      await db.execute("""
        CREATE TABLE IF NOT EXISTS adjustment_reasons_v3 (
          reason_code   TEXT PRIMARY KEY,
          reason_name   TEXT NOT NULL,
          direction     INTEGER NOT NULL DEFAULT -1,
          icon_name     TEXT DEFAULT 'warning_amber_rounded',
          is_active     INTEGER NOT NULL DEFAULT 1,
          sort_order    INTEGER NOT NULL DEFAULT 0,
          created_at    TEXT NOT NULL,
          updated_at    TEXT NOT NULL
        )
      """);
    } catch (_) {}
    try { await db.execute("CREATE INDEX IF NOT EXISTS idx_reasons_v3_active ON adjustment_reasons_v3(is_active, sort_order)"); } catch (_) {}

    try {
      await db.execute("""
        CREATE TABLE IF NOT EXISTS stock_movements (
          movement_id       TEXT PRIMARY KEY,
          movement_type     TEXT NOT NULL,
          sku               TEXT NOT NULL,
          product_id        TEXT DEFAULT '',
          product_name      TEXT DEFAULT '',
          barcode           TEXT DEFAULT '',
          qty_before        REAL NOT NULL DEFAULT 0,
          qty_change        REAL NOT NULL DEFAULT 0,
          qty_after         REAL NOT NULL DEFAULT 0,
          unit_cost         REAL DEFAULT 0,
          reason_code       TEXT DEFAULT '',
          reason_note       TEXT DEFAULT '',
          reference_no      TEXT DEFAULT '',
          batch_no          TEXT DEFAULT '',
          branch_code       TEXT NOT NULL,
          branch_name       TEXT DEFAULT '',
          user_pin          TEXT DEFAULT '',
          user_name         TEXT DEFAULT '',
          approved_by_pin   TEXT DEFAULT '',
          approved_by_name  TEXT DEFAULT '',
          local_timestamp   INTEGER NOT NULL,
          server_timestamp  INTEGER,
          sync_status       TEXT NOT NULL DEFAULT 'PENDING',
          z_report_id       TEXT DEFAULT '',
          created_at        TEXT NOT NULL,
          updated_at        TEXT NOT NULL
        )
      """);
    } catch (_) {}
    try { await db.execute("CREATE INDEX IF NOT EXISTS idx_mov_sku ON stock_movements(sku, branch_code)"); } catch (_) {}
    try { await db.execute("CREATE INDEX IF NOT EXISTS idx_mov_type ON stock_movements(movement_type, local_timestamp)"); } catch (_) {}
    try { await db.execute("CREATE INDEX IF NOT EXISTS idx_mov_sync ON stock_movements(sync_status)"); } catch (_) {}
    try { await db.execute("CREATE INDEX IF NOT EXISTS idx_mov_zreport ON stock_movements(z_report_id)"); } catch (_) {}
try {
      await db.execute('''CREATE TABLE IF NOT EXISTS exchanges (id TEXT PRIMARY KEY, exchangeNumber TEXT UNIQUE, originalTxnId TEXT, exchangeDate TEXT, returnedItemName TEXT, returnedItemSku TEXT, returnedQty INTEGER DEFAULT 0, returnedPrice REAL DEFAULT 0, newItemName TEXT, newItemSku TEXT, newQty INTEGER DEFAULT 0, newPrice REAL DEFAULT 0, priceDifference REAL DEFAULT 0, amountPaid REAL DEFAULT 0, reason TEXT DEFAULT '', processedBy TEXT DEFAULT '', approvedBy TEXT DEFAULT '', branch TEXT DEFAULT '', status TEXT DEFAULT 'Completed', dateCreated TEXT)''');
    } catch (_) {}

    // Auto-seed default reasons if empty
    try {
      final count = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM adjustment_reasons'),
      );
      if (count == null || count == 0) {
        await _seedDefaultReasons(db);
      }
    } catch (_) {}
  }

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
    branchType TEXT DEFAULT 'BRANCH',
    address TEXT DEFAULT '', phone TEXT DEFAULT '',
    isActive INTEGER DEFAULT 1, email TEXT DEFAULT '',
    manager TEXT DEFAULT '', createdDate TEXT, imagePath TEXT
    )
    ''');
    await db.execute("CREATE INDEX IF NOT EXISTS idx_branches_type ON branches(branchType)");
    await db.execute("CREATE INDEX IF NOT EXISTS idx_branches_active ON branches(isActive)");

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
    // 🛡️ BULLETPROOF: Ensure ALL critical tables exist FIRST!
    try { await db.execute("CREATE TABLE IF NOT EXISTS cashier_sessions (id TEXT PRIMARY KEY, shiftId TEXT UNIQUE NOT NULL, cashierId TEXT NOT NULL, cashierName TEXT DEFAULT '', branch TEXT DEFAULT '', beginningCash REAL DEFAULT 0, beginningSource TEXT DEFAULT 'Vault', beginningRemarks TEXT DEFAULT '', endingCashDeclared REAL DEFAULT 0, systemExpectedCash REAL DEFAULT 0, variance REAL DEFAULT 0, varianceType TEXT DEFAULT 'balanced', status TEXT DEFAULT 'open', openedAt TEXT NOT NULL, closedAt TEXT, cashSales REAL DEFAULT 0, gcashSales REAL DEFAULT 0, mayaSales REAL DEFAULT 0, cardSales REAL DEFAULT 0, otherSales REAL DEFAULT 0, totalRefunds REAL DEFAULT 0, totalVoids REAL DEFAULT 0, totalDiscounts REAL DEFAULT 0, totalExchanges REAL DEFAULT 0, transactionCount INTEGER DEFAULT 0, originalDeclared REAL DEFAULT 0, originalVariance REAL DEFAULT 0, adjustedBy TEXT DEFAULT '', adjustedAt TEXT, adjustmentReason TEXT DEFAULT '', wasAdjusted INTEGER DEFAULT 0)"); } catch (_) {}
    try { await db.execute("CREATE TABLE IF NOT EXISTS denomination_records (id INTEGER PRIMARY KEY AUTOINCREMENT, sessionId TEXT NOT NULL, type TEXT DEFAULT 'ending', denomination REAL NOT NULL, quantity INTEGER DEFAULT 0, total REAL DEFAULT 0, createdAt TEXT)"); } catch (_) {}
    try { await db.execute("CREATE TABLE IF NOT EXISTS incident_reports (id TEXT PRIMARY KEY, irNumber TEXT UNIQUE, sessionId TEXT NOT NULL, cashierId TEXT DEFAULT '', cashierName TEXT DEFAULT '', branch TEXT DEFAULT '', variance REAL DEFAULT 0, varianceType TEXT DEFAULT '', reason TEXT DEFAULT '', remarks TEXT DEFAULT '', attachmentPath TEXT DEFAULT '', createdBy TEXT DEFAULT '', createdAt TEXT NOT NULL, approvedBy TEXT DEFAULT '', approvedAt TEXT, status TEXT DEFAULT 'pending')"); } catch (_) {}
    try { await db.execute("CREATE TABLE IF NOT EXISTS z_reports (reportId TEXT PRIMARY KEY, reportDate TEXT NOT NULL, generatedAt TEXT NOT NULL, branch TEXT DEFAULT '', cashier TEXT DEFAULT '', grossSales REAL DEFAULT 0, totalDiscount REAL DEFAULT 0, netSales REAL DEFAULT 0, totalTransactions INTEGER DEFAULT 0, averageTransaction REAL DEFAULT 0, paymentBreakdownJson TEXT DEFAULT '', voidedCount INTEGER DEFAULT 0, voidedAmount REAL DEFAULT 0, voidedTransactionsJson TEXT DEFAULT '', beginningCash REAL DEFAULT 0, endingCash REAL DEFAULT 0, expectedCash REAL DEFAULT 0, overShort REAL DEFAULT 0, refundedCount INTEGER DEFAULT 0, refundedAmount REAL DEFAULT 0, refundedTransactionsJson TEXT DEFAULT '', allTransactionsJson TEXT DEFAULT '')"); } catch (_) {}
    try { await db.execute("CREATE TABLE IF NOT EXISTS business_day_state (branchId TEXT PRIMARY KEY, status TEXT DEFAULT 'open', lockedAt TEXT DEFAULT '', lockedByZReportId TEXT DEFAULT '', unlockedAt TEXT DEFAULT '', unlockedBy TEXT DEFAULT '', unlockReason TEXT DEFAULT '', cashDeclared INTEGER DEFAULT 0, cashDeclaredAt TEXT DEFAULT '', updatedAt TEXT DEFAULT '')"); } catch (_) {}
    try { await db.execute("ALTER TABLE business_day_state ADD COLUMN cashDeclared INTEGER DEFAULT 0"); } catch (_) {}
    try { await db.execute("ALTER TABLE business_day_state ADD COLUMN cashDeclaredAt TEXT DEFAULT ''"); } catch (_) {}

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
      // Branch Code architecture - Phase 1
      try { await db.execute("ALTER TABLE branches ADD COLUMN branchType TEXT DEFAULT 'BRANCH'"); } catch (_) {}
      try { await db.execute("CREATE INDEX IF NOT EXISTS idx_branches_type ON branches(branchType)"); } catch (_) {}
      try { await db.execute("CREATE INDEX IF NOT EXISTS idx_branches_active ON branches(isActive)"); } catch (_) {}

      // Create 10 new tables
      await db.execute('CREATE TABLE IF NOT EXISTS employees (id TEXT PRIMARY KEY, branchId TEXT NOT NULL, name TEXT NOT NULL, role TEXT DEFAULT \'Staff\', phone TEXT DEFAULT \'\', email TEXT DEFAULT \'\', salary REAL DEFAULT 0, isActive INTEGER DEFAULT 1, dateHired TEXT NOT NULL, notes TEXT DEFAULT \'\', FOREIGN KEY (branchId) REFERENCES branches(id))');
      await db.execute('CREATE TABLE IF NOT EXISTS batch_logs (id TEXT PRIMARY KEY, batchId TEXT NOT NULL, batchNumber TEXT DEFAULT \'\', productName TEXT DEFAULT \'\', productSku TEXT DEFAULT \'\', action TEXT NOT NULL, reason TEXT DEFAULT \'\', field TEXT DEFAULT \'\', oldValue TEXT DEFAULT \'\', newValue TEXT DEFAULT \'\', dateTime TEXT NOT NULL, FOREIGN KEY (batchId) REFERENCES batches(id))');
      await db.execute('CREATE TABLE IF NOT EXISTS adjustment_records (id TEXT PRIMARY KEY, itemName TEXT NOT NULL, sku TEXT DEFAULT \'\', adjustmentType TEXT NOT NULL, quantity INTEGER DEFAULT 0, oldStock INTEGER DEFAULT 0, newStock INTEGER DEFAULT 0, reason TEXT DEFAULT \'\', notes TEXT DEFAULT \'\', dateTime TEXT NOT NULL, cost REAL DEFAULT 0, retail REAL DEFAULT 0)');
      await db.execute('CREATE TABLE IF NOT EXISTS adjustment_reasons (id TEXT PRIMARY KEY, label TEXT NOT NULL, type TEXT NOT NULL, iconName TEXT DEFAULT \'edit\', isDefault INTEGER DEFAULT 0, isActive INTEGER DEFAULT 1, sortOrder INTEGER DEFAULT 0, dateCreated TEXT NOT NULL)');
      await _seedDefaultReasons(db);

    // === Z REPORTS TABLE (fresh installs) ===
    await db.execute('''
      CREATE TABLE IF NOT EXISTS z_reports (
        reportId TEXT PRIMARY KEY,
        reportDate TEXT NOT NULL,
        generatedAt TEXT NOT NULL,
        branch TEXT DEFAULT '',
        cashier TEXT DEFAULT '',
        grossSales REAL DEFAULT 0,
        totalDiscount REAL DEFAULT 0,
        netSales REAL DEFAULT 0,
        totalTransactions INTEGER DEFAULT 0,
        averageTransaction REAL DEFAULT 0,
        paymentBreakdownJson TEXT DEFAULT '',
        voidedCount INTEGER DEFAULT 0,
        voidedAmount REAL DEFAULT 0,
        voidedTransactionsJson TEXT DEFAULT '',
        beginningCash REAL DEFAULT 0,
        endingCash REAL DEFAULT 0,
        expectedCash REAL DEFAULT 0,
        overShort REAL DEFAULT 0,
        refundedCount INTEGER DEFAULT 0,
        refundedAmount REAL DEFAULT 0,
        allTransactionsJson TEXT DEFAULT ''
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_zreport_date ON z_reports(reportDate)');

    // === CASHIER LOCKING SYSTEM TABLES (fresh installs) ===
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cashier_sessions (
        id TEXT PRIMARY KEY,
        shiftId TEXT UNIQUE NOT NULL,
        cashierId TEXT NOT NULL,
        cashierName TEXT DEFAULT '',
        branch TEXT DEFAULT '',
        beginningCash REAL DEFAULT 0,
        beginningSource TEXT DEFAULT 'Vault',
        beginningRemarks TEXT DEFAULT '',
        endingCashDeclared REAL DEFAULT 0,
        systemExpectedCash REAL DEFAULT 0,
        variance REAL DEFAULT 0,
        varianceType TEXT DEFAULT 'balanced',
        status TEXT DEFAULT 'open',
        openedAt TEXT NOT NULL,
        closedAt TEXT,
        cashSales REAL DEFAULT 0,
        gcashSales REAL DEFAULT 0,
        mayaSales REAL DEFAULT 0,
        cardSales REAL DEFAULT 0,
        otherSales REAL DEFAULT 0,
        totalRefunds REAL DEFAULT 0,
        totalVoids REAL DEFAULT 0,
        totalDiscounts REAL DEFAULT 0,
        totalExchanges REAL DEFAULT 0,
        transactionCount INTEGER DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS denomination_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sessionId TEXT NOT NULL,
        type TEXT DEFAULT 'ending',
        denomination REAL NOT NULL,
        quantity INTEGER DEFAULT 0,
        total REAL DEFAULT 0,
        createdAt TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS incident_reports (
        id TEXT PRIMARY KEY,
        irNumber TEXT UNIQUE,
        sessionId TEXT NOT NULL,
        cashierId TEXT DEFAULT '',
        cashierName TEXT DEFAULT '',
        branch TEXT DEFAULT '',
        variance REAL DEFAULT 0,
        varianceType TEXT DEFAULT '',
        reason TEXT DEFAULT '',
        remarks TEXT DEFAULT '',
        attachmentPath TEXT DEFAULT '',
        createdBy TEXT DEFAULT '',
        createdAt TEXT NOT NULL,
        approvedBy TEXT DEFAULT '',
        approvedAt TEXT,
        status TEXT DEFAULT 'pending'
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_sessions_cashier ON cashier_sessions(cashierId, status)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_denom_session ON denomination_records(sessionId)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_ir_session ON incident_reports(sessionId)');
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
    if (oldVersion < 8) {
      try { await db.execute('CREATE TABLE IF NOT EXISTS adjustment_reasons (id TEXT PRIMARY KEY, label TEXT NOT NULL, type TEXT NOT NULL, iconName TEXT DEFAULT \'edit\', isDefault INTEGER DEFAULT 0, isActive INTEGER DEFAULT 1, sortOrder INTEGER DEFAULT 0, dateCreated TEXT NOT NULL)'); await db.execute('DELETE FROM adjustment_reasons'); } catch (_) {}
      await _seedDefaultReasons(db);
    }
    if (oldVersion < 9) {
      // Auto-grant Expenses permission to existing Admin & Manager users
      try {
        await db.execute("UPDATE users SET permissions = permissions || ',Expenses' WHERE (role = 'Admin' OR role = 'Manager') AND permissions NOT LIKE '%Expenses%'");
      } catch (_) {}
    }
    if (oldVersion < 10) {
      // Auto-grant Profit & Loss permission to existing Admin & Manager users
      try {
        await db.execute("UPDATE users SET permissions = permissions || ',Profit & Loss' WHERE (role = 'Admin' OR role = 'Manager') AND permissions NOT LIKE '%Profit & Loss%'");
      } catch (_) {}
    }
    if (oldVersion < 11) {
      // Auto-add Wrong Adjustment / Reversal default reason
      try {
        await db.insert('adjustment_reasons', {
          'id': 'def-add-07',
          'label': 'Wrong Adjustment / Reversal',
          'type': 'add',
          'iconName': 'undo',
          'isDefault': 1,
          'isActive': 1,
          'sortOrder': 7,
          'dateCreated': DateTime.now().toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      } catch (_) {}
    }
    if (oldVersion < 12) {
      // Add DirectoryCustomer fields to customers table
      try { await db.execute("ALTER TABLE customers ADD COLUMN customer_group TEXT DEFAULT 'Regular'"); } catch (_) {}
      try { await db.execute("ALTER TABLE customers ADD COLUMN totalSpent REAL DEFAULT 0"); } catch (_) {}
      try { await db.execute("ALTER TABLE customers ADD COLUMN totalVisits INTEGER DEFAULT 0"); } catch (_) {}
      try { await db.execute("ALTER TABLE customers ADD COLUMN lastVisitDate TEXT"); } catch (_) {}
      try { await db.execute("ALTER TABLE customers ADD COLUMN joinDate TEXT"); } catch (_) {}
    }
    if (oldVersion < 13) {
      // === CASHIER LOCKING SYSTEM (3 new tables) ===
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS cashier_sessions (
            id TEXT PRIMARY KEY,
            shiftId TEXT UNIQUE NOT NULL,
            cashierId TEXT NOT NULL,
            cashierName TEXT DEFAULT '',
            branch TEXT DEFAULT '',
            beginningCash REAL DEFAULT 0,
            beginningSource TEXT DEFAULT 'Vault',
            beginningRemarks TEXT DEFAULT '',
            endingCashDeclared REAL DEFAULT 0,
            systemExpectedCash REAL DEFAULT 0,
            variance REAL DEFAULT 0,
            varianceType TEXT DEFAULT 'balanced',
            status TEXT DEFAULT 'open',
            openedAt TEXT NOT NULL,
            closedAt TEXT,
            cashSales REAL DEFAULT 0,
            gcashSales REAL DEFAULT 0,
            mayaSales REAL DEFAULT 0,
            cardSales REAL DEFAULT 0,
            otherSales REAL DEFAULT 0,
            totalRefunds REAL DEFAULT 0,
            totalVoids REAL DEFAULT 0,
            totalDiscounts REAL DEFAULT 0,
            totalExchanges REAL DEFAULT 0,
            transactionCount INTEGER DEFAULT 0
          )
        ''');
      } catch (_) {}
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS denomination_records (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            sessionId TEXT NOT NULL,
            type TEXT DEFAULT 'ending',
            denomination REAL NOT NULL,
            quantity INTEGER DEFAULT 0,
            total REAL DEFAULT 0,
            createdAt TEXT
          )
        ''');
      } catch (_) {}
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS incident_reports (
            id TEXT PRIMARY KEY,
            irNumber TEXT UNIQUE,
            sessionId TEXT NOT NULL,
            cashierId TEXT DEFAULT '',
            cashierName TEXT DEFAULT '',
            branch TEXT DEFAULT '',
            variance REAL DEFAULT 0,
            varianceType TEXT DEFAULT '',
            reason TEXT DEFAULT '',
            remarks TEXT DEFAULT '',
            attachmentPath TEXT DEFAULT '',
            createdBy TEXT DEFAULT '',
            createdAt TEXT NOT NULL,
            approvedBy TEXT DEFAULT '',
            approvedAt TEXT,
            status TEXT DEFAULT 'pending'
          )
        ''');
      } catch (_) {}
      try {
        await db.execute('CREATE INDEX IF NOT EXISTS idx_sessions_cashier ON cashier_sessions(cashierId, status)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_denom_session ON denomination_records(sessionId)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_ir_session ON incident_reports(sessionId)');
      } catch (_) {}
    }
    if (oldVersion < 14) {
      // Add adjustment tracking columns to cashier_sessions
    try { await db.execute("ALTER TABLE users ADD COLUMN allowPosTransaction INTEGER DEFAULT 0"); } catch (_) {}
    // Phase 1: Soft delete + sync fields for users
    try { await db.execute("ALTER TABLE users ADD COLUMN isDeleted INTEGER DEFAULT 0"); } catch (_) {}
    try { await db.execute("ALTER TABLE users ADD COLUMN updatedAt TEXT DEFAULT ''"); } catch (_) {}
    try { await db.execute("ALTER TABLE users ADD COLUMN deletedAt TEXT DEFAULT ''"); } catch (_) {}
    try { await db.execute("ALTER TABLE users ADD COLUMN deletedBy TEXT DEFAULT ''"); } catch (_) {}
    try { await db.execute("ALTER TABLE users ADD COLUMN deletedReason TEXT DEFAULT ''"); } catch (_) {}
    // PHASE 4 FIX: Missing sync metadata columns (used by Branch Wizard)
    try { await db.execute("ALTER TABLE users ADD COLUMN syncStatus TEXT DEFAULT ''"); } catch (_) {}
    try { await db.execute("ALTER TABLE users ADD COLUMN lastModifiedAt TEXT DEFAULT ''"); } catch (_) {}
    try { await db.execute("ALTER TABLE users ADD COLUMN lastSyncedAt TEXT DEFAULT ''"); } catch (_) {}
    try { await db.execute("ALTER TABLE users ADD COLUMN firebaseId TEXT DEFAULT ''"); } catch (_) {}
    try { await db.execute("ALTER TABLE users ADD COLUMN firebasePath TEXT DEFAULT ''"); } catch (_) {}
    try { await db.execute("ALTER TABLE users ADD COLUMN companyId TEXT DEFAULT ''"); } catch (_) {}
    try { await db.execute("ALTER TABLE users ADD COLUMN branchId_sync TEXT DEFAULT ''"); } catch (_) {}
    try { await db.execute("ALTER TABLE users ADD COLUMN deviceId TEXT DEFAULT ''"); } catch (_) {}
    try { await db.execute("ALTER TABLE users ADD COLUMN createdBy_sync TEXT DEFAULT ''"); } catch (_) {}
    try { await db.execute("ALTER TABLE users ADD COLUMN updatedBy_sync TEXT DEFAULT ''"); } catch (_) {}
    try { await db.execute('''CREATE TABLE IF NOT EXISTS session_audit_log (id TEXT PRIMARY KEY, action TEXT NOT NULL, userId TEXT NOT NULL, role TEXT DEFAULT '', sessionId TEXT DEFAULT '', performedBy TEXT DEFAULT '', performedByRole TEXT DEFAULT '', targetUserName TEXT DEFAULT '', reason TEXT DEFAULT '', remarks TEXT DEFAULT '', oldValue TEXT DEFAULT '', newValue TEXT DEFAULT '', branch TEXT DEFAULT '', branchId TEXT DEFAULT '', deviceId TEXT DEFAULT '', timestamp TEXT NOT NULL, synced INTEGER DEFAULT 0)'''); } catch (_) {}
    try { await db.execute('CREATE INDEX IF NOT EXISTS idx_audit_action_time ON session_audit_log(action, timestamp)'); } catch (_) {}
    try { await db.execute('CREATE INDEX IF NOT EXISTS idx_audit_user ON session_audit_log(userId, timestamp)'); } catch (_) {}
      try { await db.execute("ALTER TABLE cashier_sessions ADD COLUMN originalDeclared REAL DEFAULT 0"); } catch (_) {}
      try { await db.execute("ALTER TABLE cashier_sessions ADD COLUMN originalVariance REAL DEFAULT 0"); } catch (_) {}
      try { await db.execute("ALTER TABLE cashier_sessions ADD COLUMN adjustedBy TEXT DEFAULT ''"); } catch (_) {}
      try { await db.execute("ALTER TABLE cashier_sessions ADD COLUMN adjustedAt TEXT"); } catch (_) {}
      try { await db.execute("ALTER TABLE cashier_sessions ADD COLUMN adjustmentReason TEXT DEFAULT ''"); } catch (_) {}
      try { await db.execute("ALTER TABLE cashier_sessions ADD COLUMN wasAdjusted INTEGER DEFAULT 0"); } catch (_) {}
    }
    if (oldVersion < 15) {
      // Z Reports persistence table
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS z_reports (
            reportId TEXT PRIMARY KEY,
            reportDate TEXT NOT NULL,
            generatedAt TEXT NOT NULL,
            branch TEXT DEFAULT '',
            cashier TEXT DEFAULT '',
            grossSales REAL DEFAULT 0,
            totalDiscount REAL DEFAULT 0,
            netSales REAL DEFAULT 0,
            totalTransactions INTEGER DEFAULT 0,
            averageTransaction REAL DEFAULT 0,
            paymentBreakdownJson TEXT DEFAULT '',
            voidedCount INTEGER DEFAULT 0,
            voidedAmount REAL DEFAULT 0,
            voidedTransactionsJson TEXT DEFAULT '',
            beginningCash REAL DEFAULT 0,
            endingCash REAL DEFAULT 0,
            expectedCash REAL DEFAULT 0,
            overShort REAL DEFAULT 0,
            refundedCount INTEGER DEFAULT 0,
            refundedAmount REAL DEFAULT 0,
            allTransactionsJson TEXT DEFAULT ''
          )
        ''');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_zreport_date ON z_reports(reportDate)');
      } catch (_) {}
    }
    if (oldVersion < 7) {
      await db.execute('CREATE TABLE IF NOT EXISTS adjustment_reasons (id TEXT PRIMARY KEY, label TEXT NOT NULL, type TEXT NOT NULL, iconName TEXT DEFAULT "edit", isDefault INTEGER DEFAULT 0, isActive INTEGER DEFAULT 1, sortOrder INTEGER DEFAULT 0, dateCreated TEXT NOT NULL)');
      await _seedDefaultReasons(db);
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

  // Delete a specific transaction item by SKU
  Future<int> deleteTransactionItem(String txnId, String sku) async {
    final db = await database;
    return await db.delete('transaction_items', where: 'transactionId = ? AND sku = ?', whereArgs: [txnId, sku]);
  }

  // Insert a single transaction item (used for exchange replacements)
  Future<int> insertTransactionItem(Map<String, dynamic> item) async {
    final db = await database;
    return await db.insert('transaction_items', item, conflictAlgorithm: ConflictAlgorithm.replace);
  }
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
  /// PHASE 2: Soft delete user (BIR-safe audit pattern)
  /// Sets isDeleted=1, captures who/when/why
  /// User remains in DB for audit, hidden from UI
  Future<int> softDeleteUser(String id, {required String deletedBy, required String reason}) async {
    final db = await database;
    final now = DateTime.now().toUtc().toIso8601String();
    return await db.update('users', {
      'isDeleted': 1,
      'deletedAt': now,
      'deletedBy': deletedBy,
      'deletedReason': reason,
      'updatedAt': now,
      'isActive': 0,
    }, where: 'id = ?', whereArgs: [id]);
  }

  /// PHASE 2: Restore soft-deleted user (Admin only)
  Future<int> restoreUser(String id, {required String restoredBy}) async {
    final db = await database;
    final now = DateTime.now().toUtc().toIso8601String();
    return await db.update('users', {
      'isDeleted': 0,
      'deletedAt': '',
      'deletedBy': '',
      'deletedReason': '',
      'updatedAt': now,
      'isActive': 1,
    }, where: 'id = ?', whereArgs: [id]);
  }

  /// PHASE 2: Get soft-deleted users (for Admin restore view)
  Future<List<Map<String, dynamic>>> getDeletedUsers() async {
    final db = await database;
    return await db.query('users', where: 'isDeleted = ?', whereArgs: [1], orderBy: 'deletedAt DESC');
  }

  Future<int> deleteUser(String id) async { final db = await database; return await db.delete('users', where: 'id = ?', whereArgs: [id]); }
  Future<List<Map<String, dynamic>>> getAllUsers() async { final db = await database; return await db.query('users', where: 'isDeleted = ? OR isDeleted IS NULL', whereArgs: [0], orderBy: 'fullName ASC'); }
  Future<Map<String, dynamic>?> getUserById(String id) async { final db = await database; final r = await db.query('users', where: 'id = ?', whereArgs: [id]); return r.isNotEmpty ? r.first : null; }
  Future<Map<String, dynamic>?> authenticateUser(String username, String password) async { final db = await database; final r = await db.query('users', where: 'LOWER(username) = LOWER(?) AND password = ? AND isActive = 1', whereArgs: [username, password]); return r.isNotEmpty ? r.first : null; }
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
  Future<int> updateDeliveryRecord(String id, Map<String, dynamic> updates) async { final db = await database; return await db.update('delivery_records', updates, where: 'id = ?', whereArgs: [id]); }
  Future<int> deleteDeliveryRecord(String id) async { final db = await database; await db.delete('delivery_items', where: 'deliveryId = ?', whereArgs: [id]); return await db.delete('delivery_records', where: 'id = ?', whereArgs: [id]); }
  Future<int> insertApprovalHistory(Map<String, dynamic> h) async { final db = await database; return await db.insert('approval_history', h); }
  Future<List<Map<String, dynamic>>> getApprovalHistoryFor(String deliveryId) async { final db = await database; return await db.query('approval_history', where: 'deliveryId = ?', whereArgs: [deliveryId], orderBy: 'date DESC'); }

  Future<void> insertDeliveryWithItems(Map<String, dynamic> delivery, List<Map<String, dynamic>> items) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert('delivery_records', delivery, conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.delete('delivery_items', where: 'deliveryId = ?', whereArgs: [delivery['id']]);
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


  // ═══════════ CASHIER SESSIONS ═══════════
  Future<int> insertCashierSession(Map<String, dynamic> s) async {
    final db = await database;
    return await db.insert('cashier_sessions', s, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> updateCashierSession(String id, Map<String, dynamic> s) async {
    final db = await database;
    return await db.update('cashier_sessions', s, where: 'id = ?', whereArgs: [id]);
  }

  Future<Map<String, dynamic>?> getActiveSession(String cashierId) async {
    final db = await database;
    final rows = await db.query('cashier_sessions',
      where: 'cashierId = ? AND status = ?', whereArgs: [cashierId, 'open'],
      orderBy: 'openedAt DESC', limit: 1);
    return rows.isNotEmpty ? rows.first : null;
  }

  Future<List<Map<String, dynamic>>> getAllSessions({String? cashierId, String? status}) async {
    final db = await database;
    String where = '';
    List<dynamic> args = [];
    if (cashierId != null) { where = 'cashierId = ?'; args.add(cashierId); }
    if (status != null) { where = where.isEmpty ? 'status = ?' : '$where AND status = ?'; args.add(status); }
    return await db.query('cashier_sessions',
      where: where.isEmpty ? null : where, whereArgs: args.isEmpty ? null : args,
      orderBy: 'openedAt DESC');
  }

  Future<Map<String, dynamic>?> getSessionById(String id) async {
    final db = await database;
    final rows = await db.query('cashier_sessions', where: 'id = ?', whereArgs: [id]);
    return rows.isNotEmpty ? rows.first : null;
  }

  // ═══════════ DENOMINATION RECORDS ═══════════
  Future<int> insertDenominationRecord(Map<String, dynamic> d) async {
    final db = await database;
    return await db.insert('denomination_records', d);
  }

  Future<void> insertDenominationBatch(List<Map<String, dynamic>> denoms) async {
    final db = await database;
    final batch = db.batch();
    for (final d in denoms) {
      batch.insert('denomination_records', d);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getDenominationsBySession(String sessionId, {String? type}) async {
    final db = await database;
    String where = 'sessionId = ?';
    List<dynamic> args = [sessionId];
    if (type != null) { where += ' AND type = ?'; args.add(type); }
    return await db.query('denomination_records', where: where, whereArgs: args, orderBy: 'denomination DESC');
  }

  // ═══════════ INCIDENT REPORTS ═══════════
  Future<int> insertIncidentReport(Map<String, dynamic> ir) async {
    final db = await database;
    return await db.insert('incident_reports', ir, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getAllIncidentReports() async {
    final db = await database;
    return await db.query('incident_reports', orderBy: 'createdAt DESC');
  }

  Future<Map<String, dynamic>?> getIncidentReportBySession(String sessionId) async {
    final db = await database;
    final rows = await db.query('incident_reports', where: 'sessionId = ?', whereArgs: [sessionId], limit: 1);
    return rows.isNotEmpty ? rows.first : null;
  }


  // ═══════════ Z REPORTS ═══════════
  Future<int> insertZReport(Map<String, dynamic> r) async {
    final db = await database;
    debugPrint('💾 INSERTING z_report: id=${r["reportId"]} reportDate="${r["reportDate"]}"'); return await db.insert('z_reports', r, conflictAlgorithm: ConflictAlgorithm.replace);
  }


  Future<int> updateZReport(String reportId, Map<String, dynamic> updates) async {
    final db = await database;
    return await db.update("z_reports", updates, where: "reportId = ?", whereArgs: [reportId]);
  }
  Future<List<Map<String, dynamic>>> getAllZReports() async {
    final db = await database;
    return await db.query('z_reports', orderBy: 'generatedAt DESC');
  }

  Future<bool> hasZReportForDate(DateTime date) async {
    final db = await database;
    final dayStart = DateTime(date.year, date.month, date.day).toIso8601String();
    final dayEnd = DateTime(date.year, date.month, date.day + 1).toIso8601String();
    final rows = await db.query("z_reports",
      where: "reportDate >= ? AND reportDate < ? AND (cashier NOT LIKE ? OR cashier IS NULL)",
      whereArgs: [dayStart, dayEnd, "VOIDED%"], limit: 1);
    debugPrint("🔍 hasZReportForDate: dayStart=$dayStart dayEnd=$dayEnd rows=${rows.length}");
    return rows.isNotEmpty;
  }

  Future<void> clearZReports() async {
    final db = await database;
    await db.delete('z_reports');
  }

  // ═══════════════════════════════════════════════════════
  // STORE PROFILE
  // ═══════════════════════════════════════════════════════
  
  Future<Map<String, dynamic>?> getStoreProfile() async {
    final db = await database;
    try {
      final result = await db.query('store_profile', limit: 1);
      return result.isNotEmpty ? result.first : null;
    } catch (_) {
      return null;
    }
  }
  
  Future<int> saveStoreProfile(Map<String, dynamic> data) async {
    final db = await database;
    data['updatedAt'] = DateTime.now().toIso8601String();
    
    final existing = await getStoreProfile();
    if (existing != null) {
      return await db.update(
        'store_profile',
        data,
        where: 'id = ?',
        whereArgs: [existing['id']],
      );
    } else {
      return await db.insert('store_profile', data);
    }
  }

  Future<void> clearAllData() async {
    final db = await database;
    // Order matters: delete child tables before parent tables
    // ALL 29 tables covered!
    
    // Cashier Locking (NEW v2.0)
    try { await db.delete('denomination_records'); } catch (_) {}
    try { await db.delete('incident_reports'); } catch (_) {}
    try { await db.delete('cashier_sessions'); } catch (_) {}
    
    // Z Reports
    try { await db.delete('z_reports'); } catch (_) {}
    
    // Exchanges
    try { await db.delete('exchanges'); } catch (_) {}
    
    // Expenses
    try { await db.delete('expense_audit_trail'); } catch (_) {}
    try { await db.delete('expense_budgets'); } catch (_) {}
    try { await db.delete('petty_cash_transactions'); } catch (_) {}
    try { await db.delete('expense_sub_categories'); } catch (_) {}
    try { await db.delete('expense_categories'); } catch (_) {}
    try { await db.delete('expenses'); } catch (_) {}
    
    // Discounts
    try { await db.delete('discount_items'); } catch (_) {}
    try { await db.delete('discount_records'); } catch (_) {}
    
    // Delivery
    try { await db.delete('delivery_items'); } catch (_) {}
    try { await db.delete('delivery_records'); } catch (_) {}
    
    // Stock Transfer
    try { await db.delete('transfer_items'); } catch (_) {}
    try { await db.delete('transfer_ledger'); } catch (_) {}
    try { await db.delete('stock_transfers'); } catch (_) {}
    
    // Adjustments
    try { await db.delete('adjustment_records'); } catch (_) {}
    try { await db.delete('adjustment_reasons'); } catch (_) {}
    
    // Batch
    try { await db.delete('batch_logs'); } catch (_) {}
    try { await db.delete('batches'); } catch (_) {}
    
    // Employees
    try { await db.delete('employees'); } catch (_) {}
    
    // Transactions
    try { await db.delete('transaction_items'); } catch (_) {}
    try { await db.delete('transactions'); } catch (_) {}
    
    // Products
    try { await db.delete('products'); } catch (_) {}
    
    // Customers
    try { await db.delete('customers'); } catch (_) {}
    
    // Users + Branches (LAST - so user must redo setup!)
    try { await db.delete('users'); } catch (_) {}
    try { await db.delete('branches'); } catch (_) {}
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


  // ═══════════════════════════════════════════════════════
  // ADJUSTMENT REASONS — Seed + CRUD
  // ═══════════════════════════════════════════════════════

  Future<void> seedDefaultReasonsIfEmpty() async { final db = await database; await _seedDefaultReasons(db); }

  Future<void> _seedDefaultReasons(Database db) async { await db.execute('CREATE TABLE IF NOT EXISTS adjustment_reasons (id TEXT PRIMARY KEY, label TEXT NOT NULL, type TEXT NOT NULL, iconName TEXT DEFAULT \'edit\', isDefault INTEGER DEFAULT 0, isActive INTEGER DEFAULT 1, sortOrder INTEGER DEFAULT 0, dateCreated TEXT NOT NULL)');
    final count = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM adjustment_reasons'));
    if (count != null && count > 0) return;

    final now = DateTime.now().toIso8601String();
    final defaults = <Map<String, dynamic>>[
      // ── ADD REASONS (6) ──
      {'id': 'def-add-01', 'label': 'New Stock / Restock',       'type': 'add',    'iconName': 'inventory',         'isDefault': 1, 'isActive': 1, 'sortOrder': 1, 'dateCreated': now},
      {'id': 'def-add-02', 'label': 'Customer Return',           'type': 'add',    'iconName': 'assignment_return', 'isDefault': 1, 'isActive': 1, 'sortOrder': 2, 'dateCreated': now},
      {'id': 'def-add-03', 'label': 'Transfer In',               'type': 'add',    'iconName': 'call_received',     'isDefault': 1, 'isActive': 1, 'sortOrder': 3, 'dateCreated': now},
      {'id': 'def-add-04', 'label': 'Found / Inventory Surplus', 'type': 'add',    'iconName': 'search',            'isDefault': 1, 'isActive': 1, 'sortOrder': 4, 'dateCreated': now},
      {'id': 'def-add-05', 'label': 'Promo / Free Items',        'type': 'add',    'iconName': 'card_giftcard',     'isDefault': 1, 'isActive': 1, 'sortOrder': 5, 'dateCreated': now},
      {'id': 'def-add-06', 'label': 'Correction / Data Fix',     'type': 'add',    'iconName': 'build',             'isDefault': 1, 'isActive': 1, 'sortOrder': 6, 'dateCreated': now},
      {'id': 'def-add-07', 'label': 'Wrong Adjustment / Reversal', 'type': 'add',    'iconName': 'undo',              'isDefault': 1, 'isActive': 1, 'sortOrder': 7, 'dateCreated': now},
      // ── DEDUCT REASONS (8) ──
      {'id': 'def-ded-01', 'label': 'Damaged / Broken',          'type': 'deduct', 'iconName': 'broken_image',      'isDefault': 1, 'isActive': 1, 'sortOrder': 1, 'dateCreated': now},
      {'id': 'def-ded-02', 'label': 'Expired',                   'type': 'deduct', 'iconName': 'event_busy',        'isDefault': 1, 'isActive': 1, 'sortOrder': 2, 'dateCreated': now},
      {'id': 'def-ded-03', 'label': 'Lost / Missing',            'type': 'deduct', 'iconName': 'help_outline',      'isDefault': 1, 'isActive': 1, 'sortOrder': 3, 'dateCreated': now},
      {'id': 'def-ded-04', 'label': 'Transfer Out',              'type': 'deduct', 'iconName': 'call_made',         'isDefault': 1, 'isActive': 1, 'sortOrder': 4, 'dateCreated': now},
      {'id': 'def-ded-05', 'label': 'Theft / Shrinkage',         'type': 'deduct', 'iconName': 'report_problem',    'isDefault': 1, 'isActive': 1, 'sortOrder': 5, 'dateCreated': now},
      {'id': 'def-ded-06', 'label': 'Sample / Tester',           'type': 'deduct', 'iconName': 'science',           'isDefault': 1, 'isActive': 1, 'sortOrder': 6, 'dateCreated': now},
      {'id': 'def-ded-07', 'label': 'Personal Use / Withdrawal', 'type': 'deduct', 'iconName': 'person_remove',     'isDefault': 1, 'isActive': 1, 'sortOrder': 7, 'dateCreated': now},
      {'id': 'def-ded-08', 'label': 'Correction / Data Fix (Deduct)', 'type': 'deduct', 'iconName': 'build',             'isDefault': 1, 'isActive': 1, 'sortOrder': 8, 'dateCreated': now},
    ];

    final batch = db.batch();
    for (final r in defaults) {
      batch.insert('adjustment_reasons', r);
    }
    await batch.commit(noResult: true);
  }

  /// Returns all active adjustment reasons, optionally filtered by type.
  Future<List<Map<String, dynamic>>> getAdjustmentReasons({String? type}) async {
    final db = await database;
    String where = 'isActive = 1';
    List<dynamic> args = [];
    if (type != null && type.isNotEmpty) {
      where += ' AND type = ?';
      args.add(type);
    }
    return await db.query(
      'adjustment_reasons',
      where: where,
      whereArgs: args,
      orderBy: 'type ASC, sortOrder ASC, label ASC',
    );
  }

  /// Inserts a new adjustment reason.
  Future<void> insertAdjustmentReason(Map<String, dynamic> reason) async {
    final db = await database;
    await db.insert('adjustment_reasons', reason,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Updates an existing adjustment reason by id.
  Future<void> updateAdjustmentReason(String id, Map<String, dynamic> data) async {
    final db = await database;
    await db.update('adjustment_reasons', data, where: 'id = ?', whereArgs: [id]);
  }

  /// Soft-deletes (sets isActive=0). Returns false if isDefault=1.
  Future<bool> deleteAdjustmentReason(String id) async {
    final db = await database;
    final rows = await db.query('adjustment_reasons',
        where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isNotEmpty && rows.first['isDefault'] == 1) return false;
    await db.update('adjustment_reasons', {'isActive': 0},
        where: 'id = ?', whereArgs: [id]);
    return true;
  }

  /// Restores a soft-deleted reason (sets isActive=1).
  Future<void> restoreAdjustmentReason(String id) async {
    final db = await database;
    await db.update('adjustment_reasons', {'isActive': 1},
        where: 'id = ?', whereArgs: [id]);
  }

  /// Returns a formatted string of all denominations for a given session.
  /// Example: "1000x2=2000; 500x3=1500; 100x5=500"
  Future<String> getDenominationsForSession(String sessionId) async {
    final db = await database;
    try {
      final rows = await db.query(
        'denomination_records',
        where: 'sessionId = ?',
        whereArgs: [sessionId],
        orderBy: 'denomination DESC',
      );
      if (rows.isEmpty) return '';
      return rows.map((r) {
        final denom = (r['denomination'] as num?)?.toStringAsFixed(0) ?? '0';
        final qty   = r['quantity'] ?? 0;
        final total = (r['total'] as num?)?.toStringAsFixed(2) ?? '0.00';
        return '${denom}x$qty=$total';
      }).join('; ');
    } catch (_) {
      return '';
    }
  }

  /// 💰 Returns Map<denomination, quantity> for a Z Report by sessionId (= reportId).
  Future<Map<double, int>> getDenominationMapForSession(String sessionId) async {
    final db = await database;
    final result = <double, int>{};
    try {
      final rows = await db.query(
        'denomination_records',
        where: 'sessionId = ? AND type = ?',
        whereArgs: [sessionId, 'ending'],
      );
      for (final r in rows) {
        final denom = (r['denomination'] as num?)?.toDouble() ?? 0;
        final qty = (r['quantity'] as num?)?.toInt() ?? 0;
        if (qty > 0) result[denom] = qty;
      }
    } catch (_) {}
    return result;
  }

  // ════════════════════════════════════════════════════════════
  // 📸 BRANCH PHOTO STORAGE (SKU-based, Firebase-sync-proof)
  // Added: 2026-06-30
  // ════════════════════════════════════════════════════════════

  Future<void> ensurePhotoTable() async {
    final db = await database;
    await db.execute("CREATE TABLE IF NOT EXISTS product_photos (sku TEXT PRIMARY KEY, imageBase64 TEXT NOT NULL, updatedAt TEXT NOT NULL)");
  }

  Future<void> savePhotoBySku(String sku, String base64) async {
    await ensurePhotoTable();
    final db = await database;
    await db.insert("product_photos", {"sku": sku, "imageBase64": base64, "updatedAt": DateTime.now().toIso8601String()}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> getPhotoBySku(String sku) async {
    await ensurePhotoTable();
    final db = await database;
    final r = await db.query("product_photos", where: "sku = ?", whereArgs: [sku], limit: 1);
    if (r.isEmpty) return null;
    return r.first["imageBase64"] as String?;
  }

  Future<void> deletePhotoBySku(String sku) async {
    await ensurePhotoTable();
    final db = await database;
    await db.delete("product_photos", where: "sku = ?", whereArgs: [sku]);
  }
}
