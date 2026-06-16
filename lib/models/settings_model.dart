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
  static String currency = 'PHP';

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _load();
  }

  static void _load() {
    if (_prefs == null) return;
    qtyPopupOnTap = _prefs!.getBool('qtyPopupOnTap') ?? true;
    defaultPayment = _prefs!.getString('defaultPayment') ?? 'Cash';
    autoPrintReceipt = _prefs!.getBool('autoPrintReceipt') ?? true;
    allowNegativeStock = _prefs!.getBool('allowNegativeStock') ?? false;
    showStockOnCard = _prefs!.getBool('showStockOnCard') ?? true;
    lowStockThreshold = _prefs!.getInt('lowStockThreshold') ?? 10;
    enableBatchTracking = _prefs!.getBool('enableBatchTracking') ?? true;
    autoDeductStock = _prefs!.getBool('autoDeductStock') ?? true;
    showCostPrice = _prefs!.getBool('showCostPrice') ?? false;
    defaultReportPeriod = _prefs!.getString('defaultReportPeriod') ?? 'Today';
    enableDiscountMonitoring = _prefs!.getBool('enableDiscountMonitoring') ?? true;
    zReportResetTime = _prefs!.getString('zReportResetTime') ?? '12:00 AM';
    requirePinVoid = _prefs!.getBool('requirePinVoid') ?? true;
    requirePinDiscount = _prefs!.getBool('requirePinDiscount') ?? true;
    pinDiscountThreshold = _prefs!.getInt('pinDiscountThreshold') ?? 20;
    maxDiscountPercent = _prefs!.getInt('maxDiscountPercent') ?? 50;
    allowPriceOverride = _prefs!.getBool('allowPriceOverride') ?? false;
    lowStockAlerts = _prefs!.getBool('lowStockAlerts') ?? true;
    expiryAlerts = _prefs!.getBool('expiryAlerts') ?? true;
    expiryAlertDays = _prefs!.getInt('expiryAlertDays') ?? 30;
    soundEffects = _prefs!.getBool('soundEffects') ?? true;
    autoLogout = _prefs!.getBool('autoLogout') ?? true;
    autoLogoutMinutes = _prefs!.getInt('autoLogoutMinutes') ?? 30;
    language = _prefs!.getString('language') ?? 'English';
    currency = _prefs!.getString('currency') ?? 'PHP';
  }

  static Future<void> save(String key, dynamic value) async {
    _prefs ??= await SharedPreferences.getInstance();
    if (value is bool) await _prefs!.setBool(key, value);
    if (value is int) await _prefs!.setInt(key, value);
    if (value is String) await _prefs!.setString(key, value);
    if (value is double) await _prefs!.setDouble(key, value);
  }
}
