import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class _AprTheme {
  static const primary   = Color(0xFF16A34A);
  static const rowEven   = Colors.white;
  static const rowOdd    = Color(0xFFF8FCFA);
  static const border    = Color(0xFFE5E7EB);
  static const headerBg  = Color(0xFFF9FAFB);
  static const textDark  = Color(0xFF111827);
  static const textMuted = Color(0xFF6B7280);
  static const textLabel = Color(0xFF374151);
}

enum AprSortCol { date, drNumber, supplier, items, qty, totalValue, approvedBy, approvedDate }
enum AprSortDir { asc, desc }

class ApprovedListTable extends StatefulWidget {
  final List<ApprovedItem> items;
  final void Function(ApprovedItem) onView;
  final VoidCallback? onBack;
  final VoidCallback? onRefresh;
  final VoidCallback? onExportAll;
  final String externalSearchQuery;

  const ApprovedListTable({
    super.key,
    required this.items,
    required this.onView,
    this.onBack,
    this.onRefresh,
    this.onExportAll,
    this.externalSearchQuery = "",
  });

  @override
  State<ApprovedListTable> createState() => _ApprovedListTableState();
}

class _ApprovedListTableState extends State<ApprovedListTable> {
  final _searchCtrl = TextEditingController();
  AprSortCol _sortCol = AprSortCol.approvedDate;
  AprSortDir _sortDir = AprSortDir.desc;
  int _currentPage = 1;
  int _pageSize = 10;
  final List<int> _pageSizes = [10, 25, 50, 100];

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  List<ApprovedItem> get _processed {
    var list = List<ApprovedItem>.from(widget.items);
    final q = widget.externalSearchQuery.isNotEmpty ? widget.externalSearchQuery.toLowerCase() : _searchCtrl.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((d) =>
          d.drNumber.toLowerCase().contains(q) ||
          d.supplier.toLowerCase().contains(q) ||
          d.approvedBy.toLowerCase().contains(q)).toList();
    }
    list.sort((a, b) {
      int cmp;
      switch (_sortCol) {
        case AprSortCol.date:         cmp = a.date.compareTo(b.date); break;
        case AprSortCol.drNumber:     cmp = a.drNumber.compareTo(b.drNumber); break;
        case AprSortCol.supplier:     cmp = a.supplier.compareTo(b.supplier); break;
        case AprSortCol.items:        cmp = a.itemsCount.compareTo(b.itemsCount); break;
        case AprSortCol.qty:          cmp = a.totalQty.compareTo(b.totalQty); break;
        case AprSortCol.totalValue:   cmp = a.totalValue.compareTo(b.totalValue); break;
        case AprSortCol.approvedBy:   cmp = a.approvedBy.compareTo(b.approvedBy); break;
        case AprSortCol.approvedDate: cmp = (a.approvedDate ?? DateTime(1970)).compareTo(b.approvedDate ?? DateTime(1970)); break;
      }
      return _sortDir == AprSortDir.asc ? cmp : -cmp;
    });
    return list;
  }

  List<ApprovedItem> get _pageItems {
    final all = _processed;
    final start = (_currentPage - 1) * _pageSize;
    if (start >= all.length) return [];
    return all.sublist(start, (start + _pageSize).clamp(0, all.length));
  }

  int get _totalPages => (_processed.length / _pageSize).ceil().clamp(1, 9999);

  void _toggleSort(AprSortCol col) {
    setState(() {
      if (_sortCol == col) {
        _sortDir = _sortDir == AprSortDir.asc ? AprSortDir.desc : AprSortDir.asc;
      } else { _sortCol = col; _sortDir = AprSortDir.asc; }
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
      final showApprovedBy   = w >= 1000;
      final showApprovedDate = w >= 1200;

      return Container(
        color: Colors.white,
        child: Column(children: [
          _Header(
            controller: _searchCtrl,
            onSearch: (_) => setState(() => _currentPage = 1),
            onBack: widget.onBack,
            onRefresh: widget.onRefresh,
            onExportAll: widget.onExportAll,
            total: widget.items.length,
          ),
          _TableHeader(
            sortCol: _sortCol, sortDir: _sortDir, onSort: _toggleSort,
            showDate: showDate, showSupplier: showSupplier,
            showItems: showItems, showQty: showQty,
            showApprovedBy: showApprovedBy, showApprovedDate: showApprovedDate,
          ),
          Expanded(child: _pageItems.isEmpty
              ? const _EmptyState()
              : ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  itemCount: _pageItems.length,
                  itemExtent: 52,
                  itemBuilder: (c, i) => _TableRow(
                    item: _pageItems[i], isEven: i.isEven,
                    showDate: showDate, showSupplier: showSupplier,
                    showItems: showItems, showQty: showQty,
                    showApprovedBy: showApprovedBy, showApprovedDate: showApprovedDate,
                    onTap: () => widget.onView(_pageItems[i]),
                  ),
                ),
          ),
          _Footer(
            totalEntries: _processed.length,
            currentPage: _currentPage, totalPages: _totalPages,
            pageSize: _pageSize, pageSizes: _pageSizes,
            onPageChange: (p) => setState(() => _currentPage = p),
            onPageSizeChange: (s) => setState(() { _pageSize = s; _currentPage = 1; }),
            compact: w < 600,
          ),
        ]),
      );
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
    if (MediaQuery.of(context).size.width >= 900) return const SizedBox.shrink();
    return Container(
      color: _AprTheme.primary,
      padding: const EdgeInsets.fromLTRB(8, 12, 12, 16),
      child: Column(children: [
        Row(children: [
          IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back, color: Colors.white)),
          const Icon(Icons.check_circle_outline, color: Colors.white, size: 26),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('APPROVED', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
            Text('$total approved deliveries', style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12)),
          ])),
          if (onExportAll != null) IconButton(onPressed: onExportAll, icon: const Icon(Icons.file_download_outlined, color: Colors.white), tooltip: 'Export All'),
          IconButton(onPressed: onRefresh, icon: const Icon(Icons.refresh, color: Colors.white)),
        ]),
        const SizedBox(height: 6),
        Container(
          height: 48,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
          child: TextField(
            controller: controller, onChanged: onSearch,
            decoration: const InputDecoration(
              border: InputBorder.none,
              prefixIcon: Icon(Icons.search, color: Color(0xFF9CA3AF)),
              hintText: 'Search DR#, supplier, approver...',
              hintStyle: TextStyle(color: Color(0xFF9CA3AF), fontSize: 15),
              contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 14),
            ),
          ),
        ),
      ]),
    );
  }
}

class _TableHeader extends StatelessWidget {
  final AprSortCol sortCol;
  final AprSortDir sortDir;
  final ValueChanged<AprSortCol> onSort;
  final bool showDate, showSupplier, showItems, showQty, showApprovedBy, showApprovedDate;
  const _TableHeader({required this.sortCol, required this.sortDir, required this.onSort, required this.showDate, required this.showSupplier, required this.showItems, required this.showQty, required this.showApprovedBy, required this.showApprovedDate});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: const BoxDecoration(color: _AprTheme.headerBg, border: Border(bottom: BorderSide(color: _AprTheme.border))),
      child: Row(children: [
        if (showDate) _HCell(label: 'DATE', flex: 2, active: sortCol == AprSortCol.date, dir: sortDir, onTap: () => onSort(AprSortCol.date)),
        _HCell(label: 'DR #', flex: 2, active: sortCol == AprSortCol.drNumber, dir: sortDir, onTap: () => onSort(AprSortCol.drNumber)),
        if (showSupplier) _HCell(label: 'SUPPLIER', flex: 3, active: sortCol == AprSortCol.supplier, dir: sortDir, onTap: () => onSort(AprSortCol.supplier)),
        if (showItems) _HCell(label: 'ITEMS', flex: 1, align: TextAlign.center, active: sortCol == AprSortCol.items, dir: sortDir, onTap: () => onSort(AprSortCol.items)),
        if (showQty) _HCell(label: 'QTY', flex: 1, align: TextAlign.center, active: sortCol == AprSortCol.qty, dir: sortDir, onTap: () => onSort(AprSortCol.qty)),
        _HCell(label: 'TOTAL VALUE', flex: 3, align: TextAlign.right, active: sortCol == AprSortCol.totalValue, dir: sortDir, onTap: () => onSort(AprSortCol.totalValue)),
        if (showApprovedBy) _HCell(label: 'APPROVED BY', flex: 2, active: sortCol == AprSortCol.approvedBy, dir: sortDir, onTap: () => onSort(AprSortCol.approvedBy)),
        if (showApprovedDate) _HCell(label: 'APPROVED DATE', flex: 2, active: sortCol == AprSortCol.approvedDate, dir: sortDir, onTap: () => onSort(AprSortCol.approvedDate)),
      ]),
    );
  }
}

class _HCell extends StatelessWidget {
  final String label;
  final int flex;
  final bool active;
  final AprSortDir dir;
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
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: active ? _AprTheme.primary : _AprTheme.textLabel, letterSpacing: 0.6))),
          const SizedBox(width: 4),
          Icon(active ? (dir == AprSortDir.asc ? Icons.arrow_upward : Icons.arrow_downward) : Icons.unfold_more,
            size: 12, color: active ? _AprTheme.primary : const Color(0xFF9CA3AF)),
        ],
      ),
    )));
  }
}

class _TableRow extends StatelessWidget {
  final ApprovedItem item;
  final bool isEven;
  final bool showDate, showSupplier, showItems, showQty, showApprovedBy, showApprovedDate;
  final VoidCallback onTap;
  const _TableRow({required this.item, required this.isEven, required this.showDate, required this.showSupplier, required this.showItems, required this.showQty, required this.showApprovedBy, required this.showApprovedDate, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final peso = NumberFormat.currency(locale: 'en_PH', symbol: '₱', decimalDigits: 0);
    final qtyFmt = NumberFormat.decimalPattern();
    final dateFmt = DateFormat('MM/dd/yyyy HH:mm');
    const cellStyle = TextStyle(fontSize: 13, color: _AprTheme.textDark);
    const mutedStyle = TextStyle(fontSize: 13, color: _AprTheme.textMuted);
    const valueStyle = TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _AprTheme.primary);

    return Material(color: isEven ? _AprTheme.rowEven : _AprTheme.rowOdd,
      child: InkWell(onTap: onTap, hoverColor: _AprTheme.primary.withValues(alpha: 0.05),
        child: Container(decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _AprTheme.border, width: 0.5))),
          child: Row(children: [
            if (showDate) _Cell(flex: 2, child: Text(dateFmt.format(item.date), style: mutedStyle, overflow: TextOverflow.ellipsis)),
            _Cell(flex: 2, child: Text(item.drNumber, style: cellStyle.copyWith(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
            if (showSupplier) _Cell(flex: 3, child: Text(item.supplier.isEmpty ? '—' : item.supplier, style: cellStyle, overflow: TextOverflow.ellipsis)),
            if (showItems) _Cell(flex: 1, align: Alignment.center, child: Text('${item.itemsCount}', style: cellStyle, textAlign: TextAlign.center)),
            if (showQty) _Cell(flex: 1, align: Alignment.center, child: Text(qtyFmt.format(item.totalQty), style: cellStyle, textAlign: TextAlign.center)),
            _Cell(flex: 3, align: Alignment.centerRight, child: Text(peso.format(item.totalValue), style: valueStyle, textAlign: TextAlign.right, overflow: TextOverflow.ellipsis)),
            if (showApprovedBy) _Cell(flex: 2, child: Text(item.approvedBy.isEmpty ? '—' : item.approvedBy, style: mutedStyle, overflow: TextOverflow.ellipsis)),
            if (showApprovedDate) _Cell(flex: 2, child: Text(item.approvedDate == null ? '—' : dateFmt.format(item.approvedDate!), style: mutedStyle, overflow: TextOverflow.ellipsis)),
          ]),
        ),
      ),
    );
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: _AprTheme.border))),
      child: Row(children: [
        Expanded(child: Text(compact ? '$start–$end of $totalEntries' : 'Showing $start to $end of $totalEntries entries',
            style: const TextStyle(fontSize: 12, color: _AprTheme.textMuted), overflow: TextOverflow.ellipsis)),
        _PageBtn(icon: Icons.chevron_left, enabled: currentPage > 1, onTap: () => onPageChange(currentPage - 1)),
        const SizedBox(width: 4),
        ..._buildPages(),
        const SizedBox(width: 4),
        _PageBtn(icon: Icons.chevron_right, enabled: currentPage < totalPages, onTap: () => onPageChange(currentPage + 1)),
        const SizedBox(width: 10),
        Container(padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(border: Border.all(color: _AprTheme.border), borderRadius: BorderRadius.circular(6)),
          child: DropdownButtonHideUnderline(child: DropdownButton<int>(value: pageSize, isDense: true,
            items: pageSizes.map((s) => DropdownMenuItem(value: s, child: Text('$s / page', style: const TextStyle(fontSize: 12)))).toList(),
            onChanged: (v) => v != null ? onPageSizeChange(v) : null))),
      ]),
    );
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
            decoration: BoxDecoration(color: active ? _AprTheme.primary : Colors.white,
              border: Border.all(color: active ? _AprTheme.primary : _AprTheme.border),
              borderRadius: BorderRadius.circular(6)),
            child: Text('$p', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: active ? Colors.white : _AprTheme.textDark)))));
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
        decoration: BoxDecoration(border: Border.all(color: _AprTheme.border), borderRadius: BorderRadius.circular(6), color: Colors.white),
        child: Icon(icon, size: 16, color: enabled ? _AprTheme.textDark : const Color(0xFFCBD5E1))));
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
    Icon(Icons.check_circle_outline, size: 56, color: Color(0xFFCBD5E1)),
    SizedBox(height: 12),
    Text('No approved deliveries', style: TextStyle(color: _AprTheme.textMuted, fontSize: 14, fontWeight: FontWeight.w500)),
  ]));
}

class ApprovedItem {
  final String drNumber;
  final String supplier;
  final DateTime date;
  final int itemsCount;
  final int totalQty;
  final double totalValue;
  final String approvedBy;
  final DateTime? approvedDate;
  ApprovedItem({required this.drNumber, required this.supplier, required this.date, required this.itemsCount, required this.totalQty, required this.totalValue, required this.approvedBy, this.approvedDate});
}
