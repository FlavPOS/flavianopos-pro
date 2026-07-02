import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class _RjTheme {
  static const primary   = Color(0xFFEF4444);
  static const rowEven   = Colors.white;
  static const rowOdd    = Color(0xFFFEF7F7);
  static const border    = Color(0xFFE5E7EB);
  static const headerBg  = Color(0xFFF9FAFB);
  static const textDark  = Color(0xFF111827);
  static const textMuted = Color(0xFF6B7280);
  static const textLabel = Color(0xFF374151);
}

enum RjSortCol { date, drNumber, supplier, items, qty, totalValue, rejectedBy, rejectedDate, reason }
enum RjSortDir { asc, desc }

class RejectedListTable extends StatefulWidget {
  final List<RejectedItem> items;
  final void Function(RejectedItem) onView;
  final VoidCallback? onBack;
  final VoidCallback? onRefresh;
  final VoidCallback? onExportAll;

  const RejectedListTable({
    super.key,
    required this.items,
    required this.onView,
    this.onBack,
    this.onRefresh,
    this.onExportAll,
  });

  @override
  State<RejectedListTable> createState() => _RejectedListTableState();
}

class _RejectedListTableState extends State<RejectedListTable> {
  final _searchCtrl = TextEditingController();
  RjSortCol _sortCol = RjSortCol.rejectedDate;
  RjSortDir _sortDir = RjSortDir.desc;
  int _currentPage = 1;
  int _pageSize = 10;
  final List<int> _pageSizes = [10, 25, 50, 100];

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  List<RejectedItem> get _processed {
    var list = List<RejectedItem>.from(widget.items);
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((d) =>
          d.drNumber.toLowerCase().contains(q) ||
          d.supplier.toLowerCase().contains(q) ||
          d.rejectedBy.toLowerCase().contains(q) ||
          d.reason.toLowerCase().contains(q)).toList();
    }
    list.sort((a, b) {
      int cmp;
      switch (_sortCol) {
        case RjSortCol.date:         cmp = a.date.compareTo(b.date); break;
        case RjSortCol.drNumber:     cmp = a.drNumber.compareTo(b.drNumber); break;
        case RjSortCol.supplier:     cmp = a.supplier.compareTo(b.supplier); break;
        case RjSortCol.items:        cmp = a.itemsCount.compareTo(b.itemsCount); break;
        case RjSortCol.qty:          cmp = a.totalQty.compareTo(b.totalQty); break;
        case RjSortCol.totalValue:   cmp = a.totalValue.compareTo(b.totalValue); break;
        case RjSortCol.rejectedBy:   cmp = a.rejectedBy.compareTo(b.rejectedBy); break;
        case RjSortCol.rejectedDate: cmp = (a.rejectedDate ?? DateTime(1970)).compareTo(b.rejectedDate ?? DateTime(1970)); break;
        case RjSortCol.reason:       cmp = a.reason.compareTo(b.reason); break;
      }
      return _sortDir == RjSortDir.asc ? cmp : -cmp;
    });
    return list;
  }

  List<RejectedItem> get _pageItems {
    final all = _processed;
    final start = (_currentPage - 1) * _pageSize;
    if (start >= all.length) return [];
    return all.sublist(start, (start + _pageSize).clamp(0, all.length));
  }

  int get _totalPages => (_processed.length / _pageSize).ceil().clamp(1, 9999);

  void _toggleSort(RjSortCol col) {
    setState(() {
      if (_sortCol == col) {
        _sortDir = _sortDir == RjSortDir.asc ? RjSortDir.desc : RjSortDir.asc;
      } else { _sortCol = col; _sortDir = RjSortDir.asc; }
      _currentPage = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, cons) {
      final w = cons.maxWidth;
      final showDate         = w >= 600;
      final showSupplier     = w >= 800;
      final showItems        = w >= 800;
      final showQty          = w >= 1200;
      final showRejectedBy   = w >= 1000;
      final showRejectedDate = w >= 1200;
      final showReason       = w >= 900;

      return Container(color: Colors.white, child: Column(children: [
        _Header(controller: _searchCtrl,
          onSearch: (_) => setState(() => _currentPage = 1),
          onBack: widget.onBack, onRefresh: widget.onRefresh, onExportAll: widget.onExportAll,
          total: widget.items.length),
        _TableHeader(sortCol: _sortCol, sortDir: _sortDir, onSort: _toggleSort,
          showDate: showDate, showSupplier: showSupplier, showItems: showItems, showQty: showQty,
          showRejectedBy: showRejectedBy, showRejectedDate: showRejectedDate, showReason: showReason),
        Expanded(child: _pageItems.isEmpty
            ? const _EmptyState()
            : ListView.builder(physics: const BouncingScrollPhysics(),
                itemCount: _pageItems.length, itemExtent: 52,
                itemBuilder: (c, i) => _TableRow(
                  item: _pageItems[i], isEven: i.isEven,
                  showDate: showDate, showSupplier: showSupplier, showItems: showItems, showQty: showQty,
                  showRejectedBy: showRejectedBy, showRejectedDate: showRejectedDate, showReason: showReason,
                  onTap: () => widget.onView(_pageItems[i])))),
        _Footer(totalEntries: _processed.length,
          currentPage: _currentPage, totalPages: _totalPages,
          pageSize: _pageSize, pageSizes: _pageSizes,
          onPageChange: (p) => setState(() => _currentPage = p),
          onPageSizeChange: (s) => setState(() { _pageSize = s; _currentPage = 1; }),
          compact: w < 600),
      ]));
    });
  }
}

class _Header extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onSearch;
  final VoidCallback? onBack, onRefresh, onExportAll;
  final int total;
  const _Header({required this.controller, required this.onSearch, required this.onBack, required this.onRefresh, required this.onExportAll, required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(color: _RjTheme.primary,
      padding: const EdgeInsets.fromLTRB(8, 12, 12, 16),
      child: Column(children: [
        Row(children: [
          IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back, color: Colors.white)),
          const Icon(Icons.cancel_outlined, color: Colors.white, size: 26),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('REJECTED', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
            Text('$total rejected deliveries', style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12)),
          ])),
          if (onExportAll != null) IconButton(onPressed: onExportAll, icon: const Icon(Icons.file_download_outlined, color: Colors.white), tooltip: 'Export All'),
          IconButton(onPressed: onRefresh, icon: const Icon(Icons.refresh, color: Colors.white)),
        ]),
        const SizedBox(height: 6),
        Container(height: 48,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
          child: TextField(controller: controller, onChanged: onSearch,
            decoration: const InputDecoration(border: InputBorder.none,
              prefixIcon: Icon(Icons.search, color: Color(0xFF9CA3AF)),
              hintText: 'Search DR#, supplier, rejector, reason...',
              hintStyle: TextStyle(color: Color(0xFF9CA3AF), fontSize: 15),
              contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 14)))),
      ]));
  }
}

class _TableHeader extends StatelessWidget {
  final RjSortCol sortCol;
  final RjSortDir sortDir;
  final ValueChanged<RjSortCol> onSort;
  final bool showDate, showSupplier, showItems, showQty, showRejectedBy, showRejectedDate, showReason;
  const _TableHeader({required this.sortCol, required this.sortDir, required this.onSort, required this.showDate, required this.showSupplier, required this.showItems, required this.showQty, required this.showRejectedBy, required this.showRejectedDate, required this.showReason});

  @override
  Widget build(BuildContext context) {
    return Container(height: 44,
      decoration: const BoxDecoration(color: _RjTheme.headerBg, border: Border(bottom: BorderSide(color: _RjTheme.border))),
      child: Row(children: [
        if (showDate) _HCell(label: 'DATE', flex: 2, active: sortCol == RjSortCol.date, dir: sortDir, onTap: () => onSort(RjSortCol.date)),
        _HCell(label: 'DR #', flex: 2, active: sortCol == RjSortCol.drNumber, dir: sortDir, onTap: () => onSort(RjSortCol.drNumber)),
        if (showSupplier) _HCell(label: 'SUPPLIER', flex: 2, active: sortCol == RjSortCol.supplier, dir: sortDir, onTap: () => onSort(RjSortCol.supplier)),
        if (showItems) _HCell(label: 'ITEMS', flex: 1, align: TextAlign.center, active: sortCol == RjSortCol.items, dir: sortDir, onTap: () => onSort(RjSortCol.items)),
        if (showQty) _HCell(label: 'QTY', flex: 1, align: TextAlign.center, active: sortCol == RjSortCol.qty, dir: sortDir, onTap: () => onSort(RjSortCol.qty)),
        _HCell(label: 'TOTAL VALUE', flex: 2, align: TextAlign.right, active: sortCol == RjSortCol.totalValue, dir: sortDir, onTap: () => onSort(RjSortCol.totalValue)),
        if (showReason) _HCell(label: 'REASON', flex: 3, active: sortCol == RjSortCol.reason, dir: sortDir, onTap: () => onSort(RjSortCol.reason)),
        if (showRejectedBy) _HCell(label: 'REJECTED BY', flex: 2, active: sortCol == RjSortCol.rejectedBy, dir: sortDir, onTap: () => onSort(RjSortCol.rejectedBy)),
        if (showRejectedDate) _HCell(label: 'REJECTED DATE', flex: 2, active: sortCol == RjSortCol.rejectedDate, dir: sortDir, onTap: () => onSort(RjSortCol.rejectedDate)),
      ]));
  }
}

class _HCell extends StatelessWidget {
  final String label;
  final int flex;
  final bool active;
  final RjSortDir dir;
  final VoidCallback onTap;
  final TextAlign align;
  const _HCell({required this.label, required this.flex, required this.active, required this.dir, required this.onTap, this.align = TextAlign.left});

  @override
  Widget build(BuildContext context) {
    return Expanded(flex: flex, child: InkWell(onTap: onTap, child: Container(
      alignment: align == TextAlign.center ? Alignment.center : align == TextAlign.right ? Alignment.centerRight : Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: align == TextAlign.center ? MainAxisAlignment.center : align == TextAlign.right ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Flexible(child: Text(label, textAlign: align, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
              color: active ? _RjTheme.primary : _RjTheme.textLabel, letterSpacing: 0.6))),
          const SizedBox(width: 4),
          Icon(active ? (dir == RjSortDir.asc ? Icons.arrow_upward : Icons.arrow_downward) : Icons.unfold_more,
            size: 12, color: active ? _RjTheme.primary : const Color(0xFF9CA3AF)),
        ]))));
  }
}

class _TableRow extends StatelessWidget {
  final RejectedItem item;
  final bool isEven;
  final bool showDate, showSupplier, showItems, showQty, showRejectedBy, showRejectedDate, showReason;
  final VoidCallback onTap;
  const _TableRow({required this.item, required this.isEven, required this.showDate, required this.showSupplier, required this.showItems, required this.showQty, required this.showRejectedBy, required this.showRejectedDate, required this.showReason, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final peso = NumberFormat.currency(locale: 'en_PH', symbol: '₱', decimalDigits: 0);
    final qtyFmt = NumberFormat.decimalPattern();
    final dateFmt = DateFormat('MM/dd/yyyy HH:mm');
    const cellStyle = TextStyle(fontSize: 13, color: _RjTheme.textDark);
    const mutedStyle = TextStyle(fontSize: 13, color: _RjTheme.textMuted);
    const valueStyle = TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _RjTheme.primary);
    const reasonStyle = TextStyle(fontSize: 12, color: _RjTheme.primary, fontStyle: FontStyle.italic);

    return Material(color: isEven ? _RjTheme.rowEven : _RjTheme.rowOdd,
      child: InkWell(onTap: onTap, hoverColor: _RjTheme.primary.withValues(alpha: 0.05),
        child: Container(decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _RjTheme.border, width: 0.5))),
          child: Row(children: [
            if (showDate) _Cell(flex: 2, child: Text(dateFmt.format(item.date), style: mutedStyle, overflow: TextOverflow.ellipsis)),
            _Cell(flex: 2, child: Text(item.drNumber, style: cellStyle.copyWith(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
            if (showSupplier) _Cell(flex: 2, child: Text(item.supplier.isEmpty ? '—' : item.supplier, style: cellStyle, overflow: TextOverflow.ellipsis)),
            if (showItems) _Cell(flex: 1, align: Alignment.center, child: Text('${item.itemsCount}', style: cellStyle, textAlign: TextAlign.center)),
            if (showQty) _Cell(flex: 1, align: Alignment.center, child: Text(qtyFmt.format(item.totalQty), style: cellStyle, textAlign: TextAlign.center)),
            _Cell(flex: 2, align: Alignment.centerRight, child: Text(peso.format(item.totalValue), style: valueStyle, textAlign: TextAlign.right, overflow: TextOverflow.ellipsis)),
            if (showReason) _Cell(flex: 3, child: Text(item.reason.isEmpty ? '—' : item.reason, style: reasonStyle, overflow: TextOverflow.ellipsis)),
            if (showRejectedBy) _Cell(flex: 2, child: Text(item.rejectedBy.isEmpty ? '—' : item.rejectedBy, style: mutedStyle, overflow: TextOverflow.ellipsis)),
            if (showRejectedDate) _Cell(flex: 2, child: Text(item.rejectedDate == null ? '—' : dateFmt.format(item.rejectedDate!), style: mutedStyle, overflow: TextOverflow.ellipsis)),
          ]))));
  }
}

class _Footer extends StatelessWidget {
  final int totalEntries, currentPage, totalPages, pageSize;
  final List<int> pageSizes;
  final ValueChanged<int> onPageChange, onPageSizeChange;
  final bool compact;
  const _Footer({required this.totalEntries, required this.currentPage, required this.totalPages, required this.pageSize, required this.pageSizes, required this.onPageChange, required this.onPageSizeChange, required this.compact});

  @override
  Widget build(BuildContext context) {
    final start = totalEntries == 0 ? 0 : (currentPage - 1) * pageSize + 1;
    final end = (currentPage * pageSize).clamp(0, totalEntries);
    return Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: _RjTheme.border))),
      child: Row(children: [
        Expanded(child: Text(compact ? '$start–$end of $totalEntries' : 'Showing $start to $end of $totalEntries entries',
          style: const TextStyle(fontSize: 12, color: _RjTheme.textMuted), overflow: TextOverflow.ellipsis)),
        _PageBtn(icon: Icons.chevron_left, enabled: currentPage > 1, onTap: () => onPageChange(currentPage - 1)),
        const SizedBox(width: 4),
        ..._buildPages(),
        const SizedBox(width: 4),
        _PageBtn(icon: Icons.chevron_right, enabled: currentPage < totalPages, onTap: () => onPageChange(currentPage + 1)),
        const SizedBox(width: 10),
        Container(padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(border: Border.all(color: _RjTheme.border), borderRadius: BorderRadius.circular(6)),
          child: DropdownButtonHideUnderline(child: DropdownButton<int>(value: pageSize, isDense: true,
            items: pageSizes.map((s) => DropdownMenuItem(value: s, child: Text('$s / page', style: const TextStyle(fontSize: 12)))).toList(),
            onChanged: (v) => v != null ? onPageSizeChange(v) : null))),
      ]));
  }

  List<Widget> _buildPages() {
    final pages = <int>[];
    final maxShow = compact ? 1 : 3;
    int startP = (currentPage - (maxShow ~/ 2)).clamp(1, totalPages);
    int endP = (startP + maxShow - 1).clamp(1, totalPages);
    if (endP - startP < maxShow - 1) { startP = (endP - maxShow + 1).clamp(1, totalPages); }
    for (int i = startP; i <= endP; i++) { pages.add(i); }
    return pages.map((p) {
      final active = p == currentPage;
      return Padding(padding: const EdgeInsets.symmetric(horizontal: 2),
        child: InkWell(onTap: () => onPageChange(p), borderRadius: BorderRadius.circular(6),
          child: Container(width: 30, height: 30, alignment: Alignment.center,
            decoration: BoxDecoration(color: active ? _RjTheme.primary : Colors.white,
              border: Border.all(color: active ? _RjTheme.primary : _RjTheme.border),
              borderRadius: BorderRadius.circular(6)),
            child: Text('$p', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: active ? Colors.white : _RjTheme.textDark)))));
    }).toList();
  }
}

class _PageBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  const _PageBtn({required this.icon, required this.enabled, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(onTap: enabled ? onTap : null, borderRadius: BorderRadius.circular(6),
      child: Container(width: 30, height: 30, alignment: Alignment.center,
        decoration: BoxDecoration(border: Border.all(color: _RjTheme.border), borderRadius: BorderRadius.circular(6), color: Colors.white),
        child: Icon(icon, size: 16, color: enabled ? _RjTheme.textDark : const Color(0xFFCBD5E1))));
  }
}

class _Cell extends StatelessWidget {
  final int flex;
  final Widget child;
  final Alignment align;
  const _Cell({required this.flex, required this.child, this.align = Alignment.centerLeft});
  @override
  Widget build(BuildContext context) => Expanded(flex: flex,
    child: Container(alignment: align, padding: const EdgeInsets.symmetric(horizontal: 10), child: child));
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Icon(Icons.cancel_outlined, size: 56, color: Color(0xFFCBD5E1)),
    SizedBox(height: 12),
    Text('No rejected deliveries', style: TextStyle(color: _RjTheme.textMuted, fontSize: 14, fontWeight: FontWeight.w500)),
  ]));
}

class RejectedItem {
  final String drNumber;
  final String supplier;
  final DateTime date;
  final int itemsCount;
  final int totalQty;
  final double totalValue;
  final String reason;
  final String rejectedBy;
  final DateTime? rejectedDate;
  RejectedItem({required this.drNumber, required this.supplier, required this.date, required this.itemsCount, required this.totalQty, required this.totalValue, required this.reason, required this.rejectedBy, this.rejectedDate});
}
