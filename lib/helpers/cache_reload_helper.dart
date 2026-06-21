import '../models/product_model.dart';
import '../models/batch_model.dart';
import '../models/transaction_model.dart';
import '../models/customer_model.dart';
import '../models/user_model.dart';
import '../models/branch_model.dart';
import '../models/customer_directory_model.dart';
import '../models/stock_transfer_model.dart';
import '../models/discount_record_model.dart';

/// Reloads all in-memory model caches from SQLite.
/// Call after any setup screen that writes directly via db.insert(...) so the
/// rest of the app sees the new rows without a full app restart.
class CacheReloadHelper {
  static Future<void> reloadAll() async {
    try { await Product.loadFromDB(); } catch (_) {}
    try { await ProductBatch.loadFromDB(); } catch (_) {}
    try { await Transaction.loadFromDB(); } catch (_) {}
    try { await Customer.loadFromDB(); } catch (_) {}
    try { await DirectoryCustomer.loadFromDB(); } catch (_) {}
    try { await AppUser.loadFromDB(); } catch (_) {}
    try { await Branch.loadFromDB(); } catch (_) {}
    try { await StockTransferStorage.loadFromDB(); } catch (_) {}
    try { await DiscountRecord.loadFromDB(); } catch (_) {}
  }
}
