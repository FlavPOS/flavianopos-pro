#!/usr/bin/env python3
import os

HOME = os.path.expanduser("~")
FPATH = os.path.join(HOME, "myapp/lib/screens/inventory/inventory_screen.dart")

with open(FPATH, "r", encoding="utf-8") as f:
    lines = f.readlines()

# Find line with "showModalBottomSheet(" in _showProductDetails
start = None
for i, line in enumerate(lines):
    if "showModalBottomSheet(" in line and i > 700:
        start = i
        break

# Find the closing ");" of showModalBottomSheet
depth = 0
end = None
for i in range(start, len(lines)):
    for ch in lines[i]:
        if ch == '(':
            depth += 1
        elif ch == ')':
            depth -= 1
            if depth == 0:
                end = i
                break
    if end is not None:
        break

# Also include the ";" on same or next line
if ";" in lines[end]:
    end_line = end
else:
    end_line = end + 1

print(f"Replacing lines {start+1} to {end_line+1}")

NEW_CODE = """    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Close button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        product.name,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Details
                _buildDetailRow('SKU', product.sku),
                _buildDetailRow('Category', product.category),
                _buildDetailRow('Unit', product.unit),
                _buildDetailRow('Barcode', product.barcode.isNotEmpty ? product.barcode : 'N/A'),
                const Divider(height: 20),
                _buildDetailRow('Cost Price', '\\u20B1${product.costPrice.toStringAsFixed(2)}'),
                _buildDetailRow('Selling Price', '\\u20B1${product.sellingPrice.toStringAsFixed(2)}'),
                _buildDetailRow('Profit', '\\u20B1${profit.toStringAsFixed(2)} (${margin.toStringAsFixed(1)}%)'),
                const Divider(height: 20),
                _buildDetailRow('Stock Qty', '${product.stockQty} ${product.unit}'),
                _buildDetailRow('Reorder Level', '${product.reorderLevel} ${product.unit}'),
                _buildDetailRow('Stock Value', '\\u20B1${(product.costPrice * product.stockQty).toStringAsFixed(2)}'),
                const SizedBox(height: 16),

                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _navigateToStockAdjust(product);
                        },
                        icon: const Icon(Icons.tune, size: 16),
                        label: const Text('Adjust Stock', style: TextStyle(fontSize: 13)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _navigateToEditProduct(product);
                        },
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('Edit', style: TextStyle(fontSize: 13)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange[700],
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
"""

new_lines = lines[:start] + [NEW_CODE] + lines[end_line+1:]

with open(FPATH, "w", encoding="utf-8") as f:
    f.writelines(new_lines)

print("DONE! Replaced showModalBottomSheet with centered showDialog")
print("Press R in Flutter terminal!")
