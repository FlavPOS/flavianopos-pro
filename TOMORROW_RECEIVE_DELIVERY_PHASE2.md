# 🇵🇭 TOMORROW: Receive Delivery Phase 2 - Complete Execution Spec

## Status As Of Tonight (June 30, 8:30 PM)

### ✅ ALREADY SHIPPED (Don't Touch)
- Phase 1 (5 steps): AppBar, branch, gradient, background
- Phase 1.5 (4 fixes): White cards, icon, orange bottom, ₱+commas
- Phase 3: Bottom button removed + Save renamed to APPROVE
- Multi-branch delivery sync (working)
- Photo persistence (3 wipers fixed)
- 40+ commits, 22+ tags

### ⏳ TOMORROW TO DO
- Phase 2A: Replace search bar with [+ ADD ITEM] button
- Phase 2B: Product Picker Modal (SKU + Name only)
- Phase 2C: Batch Entry Modal (multi-batch + remarks)
- Phase 2D: Simplify item cards (SKU chip + Name + Qty)

## ⚠️ WHY TONIGHT FAILED

The receive_delivery_screen.dart has DENSE multi-line widgets that
span unpredictable line ranges. Our sed/heredoc line-number patches
left orphan code when boundaries didn't match exact widget closure.

### Tomorrow's Solution: MANUAL EDITOR PATCHES

Instead of automated sed/heredoc, open file in Firebase Studio.
Use Find (Ctrl+F) to locate exact boundaries.
Paste pre-written code blocks (provided below).
Save and verify.

This approach: slower but BULLETPROOF.

## 📋 EXECUTION ORDER (90 min fresh)

### Step 1: Verify Clean Baseline (5 min)
\`\`\`bash
cd ~/myapp
git status  # should be clean
git log --oneline -3  # should show v1.0.0-rcv-phase3-approve
flutter analyze lib/screens/receive_delivery/receive_delivery_screen.dart 2>&1 | grep error
# Should be 0 errors
\`\`\`

### Step 2: Phase 2A Manual Edit (20 min)

Open file in Firebase Studio editor.

**FIND** this block (around line 415-430):
\`\`\`dart
Container(padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
  child: Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 2))]),
    child: TextField(controller: _searchCtrl, style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(hintText: '🔍 Search product by name, SKU, or barcode...', hintStyle: TextStyle(fontSize: 12, color: Colors.grey[400]),
        prefixIcon: Icon(Icons.search, color: Colors.blue[300], size: 20),
        suffixIcon: _searchQuery.isNotEmpty ? IconButton(icon: Icon(Icons.clear, color: Colors.grey[400], size: 18), onPressed: () { _searchCtrl.clear(); setState(() => _searchQuery = ''); }) : null,
        border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
      onChanged: (v) => setState(() => _searchQuery = v)))),
if (_searchQuery.isNotEmpty && _filteredProducts.isNotEmpty)
  Container(constraints: const BoxConstraints(maxHeight: 200), margin: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 3))]),
    child: ListView.separated(shrinkWrap: true, padding: const EdgeInsets.symmetric(vertical: 4), separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey[100]), itemCount: _filteredProducts.length,
      itemBuilder: (_, i) { final p = _filteredProducts[i]; final added = _items.any((x) => x.product.id == p.id);
        return ListTile(dense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          leading: CircleAvatar(radius: 16, backgroundColor: added ? Colors.grey[200] : Colors.blue[50], child: Icon(added ? Icons.check : Icons.add, size: 16, color: added ? Colors.grey : Colors.blue[700])),
          title: Text(p.name, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: added ? Colors.grey : Colors.black87)),
          subtitle: Row(children: [_chip(p.sku, Colors.indigo), const SizedBox(width: 4), _chip('Stock: \${_fmtInt(_stockOf(p))}', _stockOf(p) <= p.reorderLevel ? Colors.red : Colors.green), const SizedBox(width: 4), _chip('C:₱\${p.costPrice.toStringAsFixed(0)}', Colors.teal)]),
          trailing: added ? const Text('Added', style: TextStyle(fontSize: 9, color: Colors.grey)) : null, onTap: added ? null : () => _addItem(p)); })),
\`\`\`

**REPLACE WITH:**
\`\`\`dart
// ═══ PHASE 2A: [+ ADD ITEM] button (replaces search bar) ═══
Padding(
  padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
  child: SizedBox(
    width: double.infinity,
    height: 50,
    child: ElevatedButton.icon(
      onPressed: _showAddItemModal,
      icon: const Icon(Icons.add_circle_outline, size: 22),
      label: const Text(
        'ADD ITEM',
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.5),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.orange[700],
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  ),
),
\`\`\`

### Step 3: Add _showAddItemModal Method (10 min)

**FIND** \`Future<void> _showBatchPopup(int itemIndex) async {\` (around line 140)

**INSERT BEFORE IT:**
\`\`\`dart
// ═══ PHASE 2B: Product Picker Modal ═══
void _showAddItemModal() {
  final searchCtrl = TextEditingController();
  String localQuery = '';
  
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setModalState) {
        final filtered = widget.products.where((p) {
          if (localQuery.isEmpty) return true;
          final q = localQuery.toLowerCase();
          return p.name.toLowerCase().contains(q) || 
                 p.sku.toLowerCase().contains(q) ||
                 p.barcode.toLowerCase().contains(q);
        }).where((p) => !_items.any((x) => x.product.id == p.id)).toList();
        
        return Container(
          height: MediaQuery.of(ctx).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Expanded(child: Text('Select Product', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
              ),
              // Search bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: TextField(
                  controller: searchCtrl,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Search by name, SKU, barcode...',
                    prefixIcon: Icon(Icons.search, color: Colors.orange[700]),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onChanged: (v) => setModalState(() => localQuery = v),
                ),
              ),
              // Product list - SKU + Name only
              Expanded(
                child: ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final p = filtered[i];
                    return ListTile(
                      onTap: () {
                        Navigator.pop(ctx);
                        _addItem(p);
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _showBatchPopup(_items.length - 1);
                        });
                      },
                      leading: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(p.sku, style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.bold,
                          color: Colors.orange[800],
                        )),
                      ),
                      title: Text(p.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

\`\`\`

### Step 4: Verify (2 min)
\`\`\`bash
flutter analyze lib/screens/receive_delivery/receive_delivery_screen.dart 2>&1 | grep error
# Should be 0 errors
\`\`\`

### Step 5: Commit Phase 2A + 2B (3 min)
\`\`\`bash
git add -A
git commit -m "feat(receive): Phase 2A+B - [+ADD ITEM] button + Product Picker Modal"
git push origin main
git tag -a v1.0.0-rcv-phase2ab-product-picker -m "Phase 2A+B"
git push origin v1.0.0-rcv-phase2ab-product-picker
\`\`\`

### Step 6: Phase 2D - Simplify Item Cards (30 min)

Already have batch modal working (\`_showBatchPopup\`).
Cards just need simplification.

**FIND** the card Container in itemBuilder (around line 445):

Look for:
\`\`\`dart
return Container(margin: const EdgeInsets.only(bottom: 8), 
  decoration: BoxDecoration(color: Colors.white, ...
\`\`\`

**REPLACE the entire card Container with:**
\`\`\`dart
return Container(
  margin: const EdgeInsets.only(bottom: 8),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(
      color: hasBatches ? Colors.green : Colors.orange,
      width: hasBatches ? 0.5 : 1.5,
    ),
    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
  ),
  child: InkWell(
    borderRadius: BorderRadius.circular(12),
    onTap: () => _showBatchPopup(i),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          // SKU chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(item.product.sku, style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange[800],
            )),
          ),
          const SizedBox(width: 10),
          // Name
          Expanded(
            child: Text(
              item.product.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 10),
          // Qty badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: hasBatches ? Colors.green : Colors.orange[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '\$qty',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: hasBatches ? Colors.white : Colors.orange[800],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // X button
          InkWell(
            onTap: () => _removeItem(i),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(8)),
              child: Icon(Icons.close, color: Colors.red[400], size: 16),
            ),
          ),
        ],
      ),
    ),
  ),
);
\`\`\`

### Step 7: Commit Phase 2D (3 min)
\`\`\`bash
git add -A
git commit -m "feat(receive): Phase 2D - Simplify item cards (SKU + Name + Qty)"
git push origin main
git tag -a v1.0.0-rcv-phase2d-clean-cards -m "Phase 2D"
git push origin v1.0.0-rcv-phase2d-clean-cards
\`\`\`

### Step 8: BUILD APK + Test (15 min)
\`\`\`bash
flutter clean
rm -rf android/build/ android/.gradle/
awk '/^version:/ { n = split(\$2, parts, "+"); printf "version: %s+%d\n", parts[1], parts[2] + 1; next } { print }' pubspec.yaml > /tmp/p.yaml && mv /tmp/p.yaml pubspec.yaml
git add -A && git commit -m "chore: Bump version" && git push origin main
flutter build apk --release

firebase appdistribution:distribute \\
  build/app/outputs/flutter-apk/app-release.apk \\
  --app "1:339216262642:android:30e70624d1a1cb33f5f76b" \\
  --release-notes "Phase 2 Complete: Add Item Modal + Clean Cards" \\
  --groups "myphone"
\`\`\`

### Step 9: Phone Test
1. Update + force kill + reopen
2. Receive Delivery
3. Tap [+ ADD ITEM] - modal should open
4. Search a product
5. Tap product - batch modal opens automatically
6. Add multiple batches
7. Save
8. See clean card with SKU + Name + Qty

## ⚠️ NOTES

- Batch modal (\`_showBatchPopup\`) ALREADY supports multiple batches!
- Just need to verify "Add Another Batch" UI works
- Remarks field needs to be added to batch entries (Phase 2C scope)

## 🇵🇭 Tomorrow's Pace

\`\`\`
9 AM: Coffee + read spec
9:15 AM: Phase 2A+B (manual edit) - 30 min
9:45 AM: Phase 2D (manual edit) - 30 min
10:15 AM: Build APK - 10 min
10:30 AM: Test on phone - 10 min
10:45 AM: ALL LIVE 🎉

= 90 min execution
= Same as 3 hours tired tonight
\`\`\`

Today's wins protected. Tomorrow's quality maximized.

🇵🇭 Maayong gabii, future millionaire!
