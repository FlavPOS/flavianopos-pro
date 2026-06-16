#!/usr/bin/env python3
"""
QuickPOS Pro - Add Excel + PDF Export to All Modules
Run: python3 add_exports.py
"""
import re, os

def add_import(content, import_line):
    """Add import if not already present."""
    if import_line in content:
        return content
    lines = content.split('\n')
    last_import_idx = 0
    for i, line in enumerate(lines):
        if line.strip().startswith('import '):
            last_import_idx = i
    lines.insert(last_import_idx + 1, import_line)
    return '\n'.join(lines)

def insert_actions(content, buttons_code):
    """Insert export buttons into the LAST actions: [ in the file (main AppBar)."""
    positions = [m.start() for m in re.finditer(r'actions:\s*\[', content)]
    if not positions:
        print("  WARNING: No 'actions: [' found!")
        return content
    pos = positions[-1]
    bracket_pos = content.index('[', pos)
    content = content[:bracket_pos+1] + '\n' + buttons_code + '\n' + content[bracket_pos+1:]
    return content

def insert_methods(content, methods_code):
    """Insert export methods before the build method."""
    pattern = r'(\n\s*@override\s*\n\s*Widget build\(BuildContext context\))'
    matches = list(re.finditer(pattern, content))
    if matches:
        # Use LAST match (main build method)
        pos = matches[-1].start()
        content = content[:pos] + '\n' + methods_code + '\n' + content[pos:]
    else:
        last_brace = content.rfind('}')
        second_last = content.rfind('}', 0, last_brace)
        content = content[:second_last] + '\n' + methods_code + '\n' + content[second_last:]
    return content

# ============================================================
# 1. INVENTORY SCREEN
# ============================================================
def patch_inventory():
    path = 'lib/screens/inventory/inventory_screen.dart'
    print(f"Patching {path}...")
    with open(path, 'r') as f:
        content = f.read()

    if '_exportExcel' in content:
        print("  Already patched, skipping.")
        return

    content = add_import(content, "import '../../utils/export_helper.dart';")

    buttons = """              IconButton(
                icon: const Icon(Icons.table_chart, color: Colors.green),
                tooltip: 'Export Excel',
                onPressed: _exportExcel,
              ),
              IconButton(
                icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
                tooltip: 'Export PDF',
                onPressed: _exportPdf,
              ),"""

    content = insert_actions(content, buttons)

    methods = """
  void _exportExcel() {
    final data = _filteredProducts;
    ExportHelper.exportExcel(
      headers: ['SKU', 'Name', 'Category', 'Unit', 'Cost', 'Selling Price', 'Stock', 'Reorder Level', 'Barcode'],
      rows: data.map((p) => [
        p.sku, p.name, p.category, p.unit,
        p.costPrice.toStringAsFixed(2), p.sellingPrice.toStringAsFixed(2),
        p.stockQty.toString(), p.reorderLevel.toString(), p.barcode,
      ]).toList(),
      sheetName: 'Inventory',
      fileName: 'Inventory_${DateTime.now().millisecondsSinceEpoch}.xlsx',
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('\u2705 Excel exported!'), backgroundColor: Colors.green));
  }

  void _exportPdf() {
    final data = _filteredProducts;
    ExportHelper.exportPdf(
      title: 'Inventory Report',
      subtitle: '${data.length} products',
      headers: ['SKU', 'Name', 'Category', 'Unit', 'Cost', 'Price', 'Stock', 'Reorder'],
      rows: data.map((p) => [
        p.sku, p.name, p.category, p.unit,
        p.costPrice.toStringAsFixed(2), p.sellingPrice.toStringAsFixed(2),
        p.stockQty.toString(), p.reorderLevel.toString(),
      ]).toList(),
      fileName: 'Inventory_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('\u2705 PDF exported!'), backgroundColor: Colors.green));
  }
"""
    content = insert_methods(content, methods)

    with open(path, 'w') as f:
        f.write(content)
    print("  Done!")

# ============================================================
# 2. Z REPORT SCREEN
# ============================================================
def patch_z_report():
    path = 'lib/screens/reports/z_report_screen.dart'
    print(f"Patching {path}...")
    with open(path, 'r') as f:
        content = f.read()

    if '_exportExcel' in content:
        print("  Already patched, skipping.")
        return

    content = add_import(content, "import '../../utils/export_helper.dart';")

    buttons = """              IconButton(
                icon: const Icon(Icons.table_chart, color: Colors.green),
                tooltip: 'Export Excel',
                onPressed: _exportExcel,
              ),
              IconButton(
                icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
                tooltip: 'Export PDF',
                onPressed: _exportPdf,
              ),"""

    content = insert_actions(content, buttons)

    methods = """
  String _fmtDt(DateTime dt) {
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '${dt.month}/${dt.day}/${dt.year} $h:${dt.minute.toString().padLeft(2, '0')} $ampm';
  }

  void _exportExcel() {
    final data = _validTransactions;
    ExportHelper.exportExcel(
      headers: ['TXN ID', 'Date/Time', 'Items', 'Subtotal', 'Discount', 'Tax', 'Total', 'Payment', 'Status'],
      rows: data.map((t) => [
        t.id, _fmtDt(t.dateTime), t.items.length.toString(),
        t.subtotal.toStringAsFixed(2), t.totalDiscount.toStringAsFixed(2),
        t.tax.toStringAsFixed(2), t.total.toStringAsFixed(2),
        t.paymentMethod, t.status,
      ]).toList(),
      sheetName: 'Z_Report',
      fileName: 'ZReport_${DateTime.now().millisecondsSinceEpoch}.xlsx',
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('\u2705 Excel exported!'), backgroundColor: Colors.green));
  }

  void _exportPdf() {
    final data = _validTransactions;
    ExportHelper.exportPdf(
      title: 'Z Report',
      subtitle: 'Gross: \u20b1${_totalGrossSales.toStringAsFixed(2)} | Net: \u20b1${_totalNetSales.toStringAsFixed(2)} | ${data.length} transactions',
      headers: ['TXN ID', 'Date/Time', 'Items', 'Subtotal', 'Discount', 'Tax', 'Total', 'Payment', 'Status'],
      rows: data.map((t) => [
        t.id, _fmtDt(t.dateTime), t.items.length.toString(),
        t.subtotal.toStringAsFixed(2), t.totalDiscount.toStringAsFixed(2),
        t.tax.toStringAsFixed(2), t.total.toStringAsFixed(2),
        t.paymentMethod, t.status,
      ]).toList(),
      fileName: 'ZReport_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('\u2705 PDF exported!'), backgroundColor: Colors.green));
  }
"""
    content = insert_methods(content, methods)

    with open(path, 'w') as f:
        f.write(content)
    print("  Done!")

# ============================================================
# 3. SALES HISTORY SCREEN
# ============================================================
def patch_sales_history():
    path = 'lib/screens/reports/sales_history_screen.dart'
    print(f"Patching {path}...")
    with open(path, 'r') as f:
        content = f.read()

    if '_exportExcel' in content:
        print("  Already patched, skipping.")
        return

    content = add_import(content, "import '../../utils/export_helper.dart';")

    buttons = """              IconButton(
                icon: const Icon(Icons.table_chart, color: Colors.green),
                tooltip: 'Export Excel',
                onPressed: _exportExcel,
              ),
              IconButton(
                icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
                tooltip: 'Export PDF',
                onPressed: _exportPdf,
              ),"""

    content = insert_actions(content, buttons)

    methods = """
  String _fmtDtExport(DateTime dt) {
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '${dt.month}/${dt.day}/${dt.year} $h:${dt.minute.toString().padLeft(2, '0')} $ampm';
  }

  void _exportExcel() {
    final data = _filtered;
    ExportHelper.exportExcel(
      headers: ['TXN ID', 'Date/Time', 'Items', 'Subtotal', 'Discount', 'Total', 'Payment', 'Cashier', 'Status'],
      rows: data.map((t) => [
        t.id, _fmtDtExport(t.dateTime), t.items.length.toString(),
        t.subtotal.toStringAsFixed(2), t.totalDiscount.toStringAsFixed(2),
        t.total.toStringAsFixed(2), t.paymentMethod, t.cashier, t.status,
      ]).toList(),
      sheetName: 'Sales_History',
      fileName: 'SalesHistory_${DateTime.now().millisecondsSinceEpoch}.xlsx',
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('\u2705 Excel exported!'), backgroundColor: Colors.green));
  }

  void _exportPdf() {
    final data = _filtered;
    ExportHelper.exportPdf(
      title: 'Sales History Report',
      subtitle: '${data.length} transactions',
      headers: ['TXN ID', 'Date/Time', 'Items', 'Subtotal', 'Discount', 'Total', 'Payment', 'Cashier', 'Status'],
      rows: data.map((t) => [
        t.id, _fmtDtExport(t.dateTime), t.items.length.toString(),
        t.subtotal.toStringAsFixed(2), t.totalDiscount.toStringAsFixed(2),
        t.total.toStringAsFixed(2), t.paymentMethod, t.cashier, t.status,
      ]).toList(),
      fileName: 'SalesHistory_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('\u2705 PDF exported!'), backgroundColor: Colors.green));
  }
"""
    content = insert_methods(content, methods)

    with open(path, 'w') as f:
        f.write(content)
    print("  Done!")

# ============================================================
# 4. SALES ANALYTICS SCREEN
# ============================================================
def patch_sales_analytics():
    path = 'lib/screens/reports/sales_analytics_screen.dart'
    print(f"Patching {path}...")
    with open(path, 'r') as f:
        content = f.read()

    if '_exportExcel' in content:
        print("  Already patched, skipping.")
        return

    content = add_import(content, "import '../../utils/export_helper.dart';")

    # Check if AppBar has actions
    appbar_section = content[content.rfind('appBar: AppBar('):]
    if 'actions:' not in appbar_section.split('),')[0]:
        # Find the appBar line and add actions after title line
        lines = content.split('\n')
        for i, line in enumerate(lines):
            if 'appBar: AppBar(' in line:
                # Find the next line that has title or similar
                for j in range(i+1, min(i+5, len(lines))):
                    if 'title:' in lines[j]:
                        lines.insert(j+1, """        actions: [
          IconButton(
            icon: const Icon(Icons.table_chart, color: Colors.green),
            tooltip: 'Export Excel',
            onPressed: _exportExcel,
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
            tooltip: 'Export PDF',
            onPressed: _exportPdf,
          ),
        ],""")
                        break
                break
        content = '\n'.join(lines)
    else:
        buttons = """          IconButton(
            icon: const Icon(Icons.table_chart, color: Colors.green),
            tooltip: 'Export Excel',
            onPressed: _exportExcel,
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
            tooltip: 'Export PDF',
            onPressed: _exportPdf,
          ),"""
        content = insert_actions(content, buttons)

    methods = """
  void _exportExcel() {
    final data = _itemSales;
    ExportHelper.exportExcel(
      headers: ['SKU', 'Item Name', 'Qty Sold', 'Gross Sales', 'Discount', 'Net Sales'],
      rows: data.map((s) => [
        s.sku, s.name, s.qty.toString(),
        s.gross.toStringAsFixed(2), s.discount.toStringAsFixed(2),
        s.net.toStringAsFixed(2),
      ]).toList(),
      sheetName: 'Sales_Analytics',
      fileName: 'SalesAnalytics_${DateTime.now().millisecondsSinceEpoch}.xlsx',
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('\u2705 Excel exported!'), backgroundColor: Colors.green));
  }

  void _exportPdf() {
    final data = _itemSales;
    ExportHelper.exportPdf(
      title: 'Sales Analytics Report',
      subtitle: '${data.length} items sold',
      headers: ['SKU', 'Item Name', 'Qty Sold', 'Gross Sales', 'Discount', 'Net Sales'],
      rows: data.map((s) => [
        s.sku, s.name, s.qty.toString(),
        s.gross.toStringAsFixed(2), s.discount.toStringAsFixed(2),
        s.net.toStringAsFixed(2),
      ]).toList(),
      fileName: 'SalesAnalytics_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('\u2705 PDF exported!'), backgroundColor: Colors.green));
  }
"""
    content = insert_methods(content, methods)

    with open(path, 'w') as f:
        f.write(content)
    print("  Done!")

# ============================================================
# 5. DISCOUNT MONITORING SCREEN
# ============================================================
def patch_discount_monitoring():
    path = 'lib/screens/reports/discount_monitoring_screen.dart'
    print(f"Patching {path}...")
    with open(path, 'r') as f:
        content = f.read()

    if '_exportExcel' in content:
        print("  Already patched, skipping.")
        return

    content = add_import(content, "import '../../utils/export_helper.dart';")

    # Check if AppBar has actions
    appbar_idx = content.rfind('appBar: AppBar(')
    if appbar_idx >= 0:
        appbar_section = content[appbar_idx:appbar_idx+500]
        if 'actions:' not in appbar_section.split('body:')[0]:
            lines = content.split('\n')
            for i, line in enumerate(lines):
                if 'appBar: AppBar(' in line:
                    for j in range(i+1, min(i+5, len(lines))):
                        if 'title:' in lines[j]:
                            lines.insert(j+1, """        actions: [
          IconButton(
            icon: const Icon(Icons.table_chart, color: Colors.green),
            tooltip: 'Export Excel',
            onPressed: _exportExcel,
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
            tooltip: 'Export PDF',
            onPressed: _exportPdf,
          ),
        ],""")
                            break
                    break
            content = '\n'.join(lines)
        else:
            buttons = """          IconButton(
            icon: const Icon(Icons.table_chart, color: Colors.green),
            tooltip: 'Export Excel',
            onPressed: _exportExcel,
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
            tooltip: 'Export PDF',
            onPressed: _exportPdf,
          ),"""
            content = insert_actions(content, buttons)

    methods = """
  String _fmtDtDiscount(DateTime dt) {
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '${dt.month}/${dt.day}/${dt.year} $h:${dt.minute.toString().padLeft(2, '0')} $ampm';
  }

  void _exportExcel() {
    final data = _filteredRecords;
    ExportHelper.exportExcel(
      headers: ['TXN ID', 'Date/Time', 'Type', 'Customer', 'Gross', 'Discount', 'Net', 'Cashier', 'Branch'],
      rows: data.map((r) => [
        r.transactionId, _fmtDtDiscount(r.dateTime), r.discountType,
        r.customerName ?? '', r.totalGross.toStringAsFixed(2),
        r.totalDiscount.toStringAsFixed(2), r.totalNet.toStringAsFixed(2),
        r.cashier, r.branch,
      ]).toList(),
      sheetName: 'Discount_Monitoring',
      fileName: 'DiscountMonitoring_${DateTime.now().millisecondsSinceEpoch}.xlsx',
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('\u2705 Excel exported!'), backgroundColor: Colors.green));
  }

  void _exportPdf() {
    final data = _filteredRecords;
    ExportHelper.exportPdf(
      title: 'Discount Monitoring Report',
      subtitle: '${data.length} records | Total Discount: \u20b1${_totalDiscount.toStringAsFixed(2)}',
      headers: ['TXN ID', 'Date/Time', 'Type', 'Customer', 'Gross', 'Discount', 'Net', 'Cashier', 'Branch'],
      rows: data.map((r) => [
        r.transactionId, _fmtDtDiscount(r.dateTime), r.discountType,
        r.customerName ?? '', r.totalGross.toStringAsFixed(2),
        r.totalDiscount.toStringAsFixed(2), r.totalNet.toStringAsFixed(2),
        r.cashier, r.branch,
      ]).toList(),
      fileName: 'DiscountMonitoring_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('\u2705 PDF exported!'), backgroundColor: Colors.green));
  }
"""
    content = insert_methods(content, methods)

    with open(path, 'w') as f:
        f.write(content)
    print("  Done!")

# ============================================================
# 6. CUSTOMERS SCREEN
# ============================================================
def patch_customers():
    path = 'lib/screens/customers/customers_screen.dart'
    print(f"Patching {path}...")
    with open(path, 'r') as f:
        content = f.read()

    if '_exportExcel' in content:
        print("  Already patched, skipping.")
        return

    content = add_import(content, "import '../../utils/export_helper.dart';")

    buttons = """              IconButton(
                icon: const Icon(Icons.table_chart, color: Colors.green),
                tooltip: 'Export Excel',
                onPressed: _exportExcel,
              ),
              IconButton(
                icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
                tooltip: 'Export PDF',
                onPressed: _exportPdf,
              ),"""

    content = insert_actions(content, buttons)

    methods = """
  String _fmtDateCust(DateTime dt) => '${dt.month}/${dt.day}/${dt.year}';

  void _exportExcel() {
    final data = _filteredCustomers;
    ExportHelper.exportExcel(
      headers: ['ID', 'Name', 'Phone', 'Email', 'Group', 'Total Spent', 'Visits', 'Join Date'],
      rows: data.map((c) => [
        c.id, c.name, c.phone, c.email, c.group,
        c.totalSpent.toStringAsFixed(2), c.totalVisits.toString(),
        _fmtDateCust(c.joinDate),
      ]).toList(),
      sheetName: 'Customers',
      fileName: 'Customers_${DateTime.now().millisecondsSinceEpoch}.xlsx',
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('\u2705 Excel exported!'), backgroundColor: Colors.green));
  }

  void _exportPdf() {
    final data = _filteredCustomers;
    ExportHelper.exportPdf(
      title: 'Customer Directory',
      subtitle: '${data.length} customers | Total Revenue: \u20b1${_totalRevenue.toStringAsFixed(2)}',
      headers: ['ID', 'Name', 'Phone', 'Email', 'Group', 'Total Spent', 'Visits', 'Join Date'],
      rows: data.map((c) => [
        c.id, c.name, c.phone, c.email, c.group,
        c.totalSpent.toStringAsFixed(2), c.totalVisits.toString(),
        _fmtDateCust(c.joinDate),
      ]).toList(),
      fileName: 'Customers_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('\u2705 PDF exported!'), backgroundColor: Colors.green));
  }
"""
    content = insert_methods(content, methods)

    with open(path, 'w') as f:
        f.write(content)
    print("  Done!")

# ============================================================
# 7. USERS SCREEN
# ============================================================
def patch_users():
    path = 'lib/screens/users/users_screen.dart'
    print(f"Patching {path}...")
    with open(path, 'r') as f:
        content = f.read()

    if '_exportExcel' in content:
        print("  Already patched, skipping.")
        return

    content = add_import(content, "import '../../utils/export_helper.dart';")

    buttons = """              IconButton(
                icon: const Icon(Icons.table_chart, color: Colors.green),
                tooltip: 'Export Excel',
                onPressed: _exportExcel,
              ),
              IconButton(
                icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
                tooltip: 'Export PDF',
                onPressed: _exportPdf,
              ),"""

    content = insert_actions(content, buttons)

    methods = """
  String _fmtDateUser(DateTime dt) => '${dt.month}/${dt.day}/${dt.year}';

  void _exportExcel() {
    final data = _filtered;
    ExportHelper.exportExcel(
      headers: ['ID', 'Name', 'Username', 'Email', 'Phone', 'Role', 'Branch', 'Status', 'Join Date'],
      rows: data.map((u) => [
        u.id, u.name, u.username, u.email, u.phone, u.role, u.branch,
        u.isActive ? 'Active' : 'Inactive',
        _fmtDateUser(u.joinDate),
      ]).toList(),
      sheetName: 'Users',
      fileName: 'Users_${DateTime.now().millisecondsSinceEpoch}.xlsx',
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('\u2705 Excel exported!'), backgroundColor: Colors.green));
  }

  void _exportPdf() {
    final data = _filtered;
    ExportHelper.exportPdf(
      title: 'Users Report',
      subtitle: '${data.length} users | Active: ${_activeCount}',
      headers: ['ID', 'Name', 'Username', 'Email', 'Phone', 'Role', 'Branch', 'Status', 'Join Date'],
      rows: data.map((u) => [
        u.id, u.name, u.username, u.email, u.phone, u.role, u.branch,
        u.isActive ? 'Active' : 'Inactive',
        _fmtDateUser(u.joinDate),
      ]).toList(),
      fileName: 'Users_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('\u2705 PDF exported!'), backgroundColor: Colors.green));
  }
"""
    content = insert_methods(content, methods)

    with open(path, 'w') as f:
        f.write(content)
    print("  Done!")

# ============================================================
# 8. BRANCHES SCREEN
# ============================================================
def patch_branches():
    path = 'lib/screens/branches/branches_screen.dart'
    print(f"Patching {path}...")
    with open(path, 'r') as f:
        content = f.read()

    if '_exportExcel' in content:
        print("  Already patched, skipping.")
        return

    content = add_import(content, "import '../../utils/export_helper.dart';")

    buttons = """              IconButton(
                icon: const Icon(Icons.table_chart, color: Colors.green),
                tooltip: 'Export Excel',
                onPressed: _exportExcel,
              ),
              IconButton(
                icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
                tooltip: 'Export PDF',
                onPressed: _exportPdf,
              ),"""

    content = insert_actions(content, buttons)

    methods = """
  void _exportExcel() {
    final data = _filtered;
    ExportHelper.exportExcel(
      headers: ['ID', 'Name', 'Address', 'Phone', 'Users', 'Today Sales', 'Status'],
      rows: data.map((b) => [
        b.id, b.name, b.address, b.phone,
        b.userCount.toString(), b.todaySales.toStringAsFixed(2),
        b.isActive ? 'Active' : 'Inactive',
      ]).toList(),
      sheetName: 'Branches',
      fileName: 'Branches_${DateTime.now().millisecondsSinceEpoch}.xlsx',
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('\u2705 Excel exported!'), backgroundColor: Colors.green));
  }

  void _exportPdf() {
    final data = _filtered;
    ExportHelper.exportPdf(
      title: 'Branches Report',
      subtitle: '${data.length} branches | Active: ${_activeCount} | Total Sales: \u20b1${_totalSales.toStringAsFixed(2)}',
      headers: ['ID', 'Name', 'Address', 'Phone', 'Users', 'Today Sales', 'Status'],
      rows: data.map((b) => [
        b.id, b.name, b.address, b.phone,
        b.userCount.toString(), b.todaySales.toStringAsFixed(2),
        b.isActive ? 'Active' : 'Inactive',
      ]).toList(),
      fileName: 'Branches_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('\u2705 PDF exported!'), backgroundColor: Colors.green));
  }
"""
    content = insert_methods(content, methods)

    with open(path, 'w') as f:
        f.write(content)
    print("  Done!")

# ============================================================
# RUN ALL PATCHES
# ============================================================
if __name__ == '__main__':
    print("=" * 50)
    print("QuickPOS Pro - Adding Export to All Modules")
    print("=" * 50)
    
    patches = [
        patch_inventory,
        patch_z_report,
        patch_sales_history,
        patch_sales_analytics,
        patch_discount_monitoring,
        patch_customers,
        patch_users,
        patch_branches,
    ]
    
    success = 0
    for patch in patches:
        try:
            patch()
            success += 1
        except Exception as e:
            print(f"  ERROR: {e}")
    
    print("=" * 50)
    print(f"\u2705 {success}/{len(patches)} modules patched successfully!")
    print("Now run: flutter analyze")
    print("=" * 50)
