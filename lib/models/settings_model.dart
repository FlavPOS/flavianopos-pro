// lib/models/settings_model.dart
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  static SharedPreferences? _prefs;

  // Cashiering
  static bool qtyPopupOnTap = true;
  static String defaultPayment = 'Cash';
  static bool autoPrintReceipt = true;
  static bool allowNegativeStock = false;
  static bool showStockOnCard = true;

  // Inventory
  static int lowStockThreshold = 10;
  static bool enableBatchTracking = true;
  static bool autoDeductStock = true;
  static bool showCostPrice = false;

  // Sales & Reports
  static String defaultReportPeriod = 'Today';
  static bool enableDiscountMonitoring = true;
  static String zReportResetTime = '12:00 AM';

  // Security
  static bool requirePinVoid = true;
  static bool requirePinDiscount = true;
  static int pinDiscountThreshold = 20;
  static int maxDiscountPercent = 50;
  static bool allowPriceOverride = false;

  // Notifications
  static bool lowStockAlerts = true;
  static bool expiryAlerts = true;
  static int expiryAlertDays = 30;

  // App Settings
  static bool soundEffects = true;
  static bool autoLogout = true;
  static int autoLogoutMinutes = 30;
  static String language = 'English';
  static bool darkMode = false;
  static String currency = 'PHP';

  // ─── TAX SETTINGS (NEW v1.6) ───
  static bool vatEnabled = true;
  static double vatRate = 12.0;
  static bool vatInclusive = true;
  static bool serviceChargeEnabled = false;
  static double serviceChargeRate = 10.0;
  static bool seniorDiscount = true;
  static double seniorDiscountRate = 20.0;
  static bool pwdDiscount = true;
  static double pwdDiscountRate = 20.0;
  static bool showTaxBreakdown = true;

  // ─── BUSINESS / RECEIPT SETTINGS (NEW v1.6) ───
  static String businessName = 'FlavianoPOS Store';
  static String businessAddress = 'Diversion Road, Consolacion, Cebu';
  static String businessPhone = '';
  static String businessTin = 'TIN: 123-456-789-000';
  static String businessEmail = '';

  // ─── BIR COMPLIANCE (v160a) ───
  static String vatRegStatus = 'VAT REG';  // VAT REG / NON-VAT / VAT-EXEMPT
  static String birPermitNumber = '';  // e.g. FP123456789 (from BIR accreditation)
  static String terminalSN = 'FLAV-POS-001';  // POS Terminal Serial Number
  static String machineIdentNumber = '';  // MIN assigned by BIR
  static String terminalNumber = 'POS-01';  // Register/Terminal number
  static String accreditationNumber = '';  // BIR Accreditation No

  // ─── STORE POLICY (v160a) ───
  static bool showStorePolicy = true;
  static String storePolicy = '''• 7-day replacement for defective items
• Present original receipt for claims
• Perishables and sale items non-refundable
• Contact: 0917-XXX-XXXX for warranty''';
  static String officialReceiptNotice = 'THIS SERVES AS YOUR OFFICIAL RECEIPT';
  static bool showSignatureLines = true;
  static String receiptHeader = 'FlavianoPOS Store';
  static String receiptSubheader = 'Diversion Road, Consolacion, Cebu';
  static String receiptFooter = 'Thank you for shopping with us!';
  static String receiptFooter2 = 'Please come again!';
  static bool showLogo = true;
  static bool showDate = true;
  static bool showCashier = true;
  static bool showBranch = true;
  static bool showItemCount = true;
  static bool showBarcode = false;
  static bool showQRCode = false;
  static String paperSize = '80mm';
  static String fontSize = 'Medium';

  // ─── HELPERS ───
  static String get currencySymbol {
    switch (currency) {
      case 'PHP': return '₱';
      case 'USD': return '\$';
      case 'SGD': return 'S\$';
      default: return '₱';
    }
  }

  static double get vatMultiplier => vatEnabled ? (1 + vatRate / 100) : 1.0;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _load();
  }

  static void _load() {
    if (_prefs == null) return;
    // Cashiering
    qtyPopupOnTap = _prefs!.getBool('qtyPopupOnTap') ?? true;
    defaultPayment = _prefs!.getString('defaultPayment') ?? 'Cash';
    autoPrintReceipt = _prefs!.getBool('autoPrintReceipt') ?? true;
    allowNegativeStock = _prefs!.getBool('allowNegativeStock') ?? false;
    showStockOnCard = _prefs!.getBool('showStockOnCard') ?? true;
    // Inventory
    lowStockThreshold = _prefs!.getInt('lowStockThreshold') ?? 10;
    enableBatchTracking = _prefs!.getBool('enableBatchTracking') ?? true;
    autoDeductStock = _prefs!.getBool('autoDeductStock') ?? true;
    showCostPrice = _prefs!.getBool('showCostPrice') ?? false;
    // Reports
    defaultReportPeriod = _prefs!.getString('defaultReportPeriod') ?? 'Today';
    enableDiscountMonitoring = _prefs!.getBool('enableDiscountMonitoring') ?? true;
    zReportResetTime = _prefs!.getString('zReportResetTime') ?? '12:00 AM';
    // Security
    requirePinVoid = _prefs!.getBool('requirePinVoid') ?? true;
    requirePinDiscount = _prefs!.getBool('requirePinDiscount') ?? true;
    pinDiscountThreshold = _prefs!.getInt('pinDiscountThreshold') ?? 20;
    maxDiscountPercent = _prefs!.getInt('maxDiscountPercent') ?? 50;
    allowPriceOverride = _prefs!.getBool('allowPriceOverride') ?? false;
    // Notifications
    lowStockAlerts = _prefs!.getBool('lowStockAlerts') ?? true;
    expiryAlerts = _prefs!.getBool('expiryAlerts') ?? true;
    expiryAlertDays = _prefs!.getInt('expiryAlertDays') ?? 30;
    // App
    soundEffects = _prefs!.getBool('soundEffects') ?? true;
    autoLogout = _prefs!.getBool('autoLogout') ?? true;
    autoLogoutMinutes = _prefs!.getInt('autoLogoutMinutes') ?? 30;
    language = _prefs!.getString('language') ?? 'English';
    darkMode = _prefs!.getBool('darkMode') ?? false;
    currency = _prefs!.getString('currency') ?? 'PHP';
    // Tax (NEW)
    vatEnabled = _prefs!.getBool('vatEnabled') ?? true;
    vatRate = _prefs!.getDouble('vatRate') ?? 12.0;
    vatInclusive = _prefs!.getBool('vatInclusive') ?? true;
    serviceChargeEnabled = _prefs!.getBool('serviceChargeEnabled') ?? false;
    serviceChargeRate = _prefs!.getDouble('serviceChargeRate') ?? 10.0;
    seniorDiscount = _prefs!.getBool('seniorDiscount') ?? true;
    seniorDiscountRate = _prefs!.getDouble('seniorDiscountRate') ?? 20.0;
    pwdDiscount = _prefs!.getBool('pwdDiscount') ?? true;
    pwdDiscountRate = _prefs!.getDouble('pwdDiscountRate') ?? 20.0;
    showTaxBreakdown = _prefs!.getBool('showTaxBreakdown') ?? true;
    // Business (NEW)
    businessName = _prefs!.getString('businessName') ?? 'FlavianoPOS Store';
    businessAddress = _prefs!.getString('businessAddress') ?? 'Diversion Road, Consolacion, Cebu';
    businessPhone = _prefs!.getString('businessPhone') ?? '';
    businessTin = _prefs!.getString('businessTin') ?? 'TIN: 123-456-789-000';
    businessEmail = _prefs!.getString('businessEmail') ?? '';
    receiptHeader = _prefs!.getString('receiptHeader') ?? 'FlavianoPOS Store';
    receiptSubheader = _prefs!.getString('receiptSubheader') ?? 'Diversion Road, Consolacion, Cebu';
    receiptFooter = _prefs!.getString('receiptFooter') ?? 'Thank you for shopping with us!';
    receiptFooter2 = _prefs!.getString('receiptFooter2') ?? 'Please come again!';
    showLogo = _prefs!.getBool('showLogo') ?? true;
    showDate = _prefs!.getBool('showDate') ?? true;
    showCashier = _prefs!.getBool('showCashier') ?? true;
    showBranch = _prefs!.getBool('showBranch') ?? true;
    showItemCount = _prefs!.getBool('showItemCount') ?? true;
    showBarcode = _prefs!.getBool('showBarcode') ?? false;
    showQRCode = _prefs!.getBool('showQRCode') ?? false;
    paperSize = _prefs!.getString('paperSize') ?? '80mm';
    fontSize = _prefs!.getString('fontSize') ?? 'Medium';;

    // v160a: BIR Compliance fields
    vatRegStatus = _prefs!.getString('vatRegStatus') ?? 'VAT REG';
    birPermitNumber = _prefs!.getString('birPermitNumber') ?? '';
    terminalSN = _prefs!.getString('terminalSN') ?? 'FLAV-POS-001';
    machineIdentNumber = _prefs!.getString('machineIdentNumber') ?? '';
    terminalNumber = _prefs!.getString('terminalNumber') ?? 'POS-01';
    accreditationNumber = _prefs!.getString('accreditationNumber') ?? '';

    // v160a: Store Policy fields
    showStorePolicy = _prefs!.getBool('showStorePolicy') ?? true;
    storePolicy = _prefs!.getString('storePolicy') ?? storePolicy;
    officialReceiptNotice = _prefs!.getString('officialReceiptNotice') ?? 'THIS SERVES AS YOUR OFFICIAL RECEIPT';
    showSignatureLines = _prefs!.getBool('showSignatureLines') ?? true;
  }

  static Future<void> save(String key, dynamic value) async {
    _prefs ??= await SharedPreferences.getInstance();
    if (value is bool) await _prefs!.setBool(key, value);
    if (value is int) await _prefs!.setInt(key, value);
    if (value is String) await _prefs!.setString(key, value);
    if (value is double) await _prefs!.setDouble(key, value);
  }
}
