import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class _SubTheme {
  static const primary      = Color(0xFF2563EB);
  static const primaryLight = Color(0xFFDBEAFE);
  static const green        = Color(0xFF16A34A);
  static const greenLight   = Color(0xFFDCFCE7);
  static const red          = Color(0xFFEF4444);
  static const redLight     = Color(0xFFFEE2E2);
  static const rowEven      = Colors.white;
  static const rowOdd       = Color(0xFFF8F9FC);
  static const border       = Color(0xFFE5E7EB);
  static const headerBg     = Color(0xFFF9FAFB);
  static const textDark     = Color(0xFF111827);
  static const textMuted    = Color(0xFF6B7280);
  static const textLabel    = Color(0xFF374151);
}

enum SubSortColumn { date, drNumber, supplier, items, qty, totalValue, submittedBy }
enum SubSortDir { asc, desc }

class SubmittedListTable extends StatefulWidget {
  final List<SubmittedItem> items;
  final void Function(SubmittedItem) onView;
  final void Function(SubmittedItem) onApprove;
  final void Function(SubmittedItem) onReject;
  final VoidCallback? onBack;
  final VoidCallback? onRefresh;
  final VoidCallback? onFilter;

  const SubmittedListTable({
    super.key,
    required this.items,
    required this.onView,
    required this.onApprove,
    required this.onReject,
    this.onBack,
    this.onRefresh,
    this.onFilter,
  });

  @override
  State<SubmittedListTable> createState() => _SubmittedListTableState();
}

class _SubmittedListTableState extends State<SubmittedListTable> {
  final _searchCtrl = TextEditingController();
  SubSortColumn _sortCol = SubSortColumn.date;
  SubSortDir _sortDir = SubSortDir.desc;
  int _currentPage = 1;
  int _pageSize = 10;
  final List<int> _pageSizes = [10, 25, 50, 100];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<SubmittedItem> get _processed {
    var list = List<SubmittedItem>.from(widget.items);
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((d) =>
          d.drNumber.toLowerCase().contains(q) ||
          d.supplier.toLowerCase().contains(q) ||
          d.submittedBy.toLowerCase().contains(q)).toList();
    }
    list.sort((a, b) {
      int cmp;
      switch (_sortCol) {
        case SubSortColumn.date:        cmp = a.date.compareTo(b.date); break;
        case SubSortColumn.drNumber:    cmp = a.drNumber.compareTo(b.drNumber); break;
        case SubSortColumn.supplier:    cmp = a.supplier.compareTo(b.supplier); break;
        case SubSortColumn.items:       cmp = a.itemsCount.compareTo(b.itemsCount); break;
        case SubSortColumn.qty:         cmp = a.totalQty.compareTo(b.totalQty); break;
        case SubSortColumn.totalValue:  cmp = a.totalValue.compareTo(b.totalValue); break;
        case SubSortColumn.submittedBy: cmp = a.submittedBy.compareTo(b.submittedBy); break;
      }
      return _sortDir == SubSortDir.asc ? cmp : -cmp;
    });
    return list;
  }

  List<SubmittedItem> get _pageItems {
    final all = _processed;
    final start = (_currentPage - 1) * _pageSize;
    if (start >= all.length) return [];
    final end = (start + _pageSize).clamp(0, all.length);
    return all.sublist(start, end);
  }

  int get _totalPages => (_processed.length / _pageSize).ceil().clamp(1, 9999);

  void _toggleSort(SubSortColumn col) {
    setState(() {
      if (_sortCol == col) {
        _sortDir = _sortDir == SubSortDir.asc ? SubSortDir.desc : SubSortDir.asc;
      } else {
        _sortCol = col;
        _sortDir = SubSortDir.asc;
      }
      _currentPage = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final showDate        = width >= 600;
        final showSupplier    = width >= 800;
        final showItems       = width >= 800;
        final showQty         = width >= 1200;
        final showSubmittedBy = width >= 1200;

        return Container(
          color: Colors.white,
          child: Column(
            children: [
              _Header(
                controller: _searchCtrl,
                onSearch: (v) {
                  setState(() => _currentPage = 1);
                },
                onBack: widget.onBack,
                onFilter: widget.onFilter,
                onRefresh: widget.onRefresh,
                totalCount: widget.items.length,
              ),
              _TableHeader(
                sortCol: _sortCol, sortDir: _sortDir, onSort: _toggleSort,
                showDate: showDate, showSupplier: showSupplier,
                showItems: showItems, showQty: showQty, showSubmittedBy: showSubmittedBy,
              ),
              Expanded(
                child: _pageItems.isEmpty
                    ? const _EmptyState()
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        itemCount: _pageItems.length,
                        itemExtent: 52,
                        itemBuilder: (context, index) => _TableRow(
                          item: _pageItems[index], isEven: index.isEven,
                          showDate: showDate, showSupplier: showSupplier,
                          showItems: showItems, showQty: showQty, showSubmittedBy: showSubmittedBy,
                          onView: () => widget.onView(_pageItems[index]),
                          onApprove: () => widget.onApprove(_pageItems[index]),
                          onReject: () => widget.onReject(_pageItems[index]),
                        ),
                      ),
              ),
              _PaginationFooter(
                totalEntries: _processed.length,
                currentPage: _currentPage, totalPages: _totalPages,
                pageSize: _pageSize, pageSizes: _pageSizes,
                onPageChange: (p) => setState(() => _currentPage = p),
                onPageSizeChange: (s) => setState(() { _pageSize = s; _currentPage = 1; }),
                compact: width < 600,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onSearch;
  final VoidCallback? onBack, onFilter, onRefresh;
  final int totalCount;

  const _Header({
    required this.controller, required this.onSearch,
    required this.onBack, required this.onFilter, required this.onRefresh,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _SubTheme.primary,
      padding: const EdgeInsets.fromLTRB(8, 12, 12, 16),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back, color: Colors.white)),
              const Icon(Icons.send_rounded, color: Colors.white, size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('SUBMITTED',
                        style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                    Text('$totalCount pending approval',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12)),
                  ],
                ),
              ),
              IconButton(onPressed: onFilter, icon: const Icon(Icons.sort, color: Colors.white)),
              IconButton(onPressed: onRefresh, icon: const Icon(Icons.refresh, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            height: 48,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: TextField(
              controller: controller, onChanged: onSearch,
              decoration: const InputDecoration(
                border: InputBorder.none,
                prefixIcon: Icon(Icons.search, color: Color(0xFF9CA3AF)),
                hintText: 'Search DR#, supplier, submitter...',
                hintStyle: TextStyle(color: Color(0xFF9CA3AF), fontSize: 15),
                contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  final SubSortColumn sortCol;
  final SubSortDir sortDir;
  final ValueChanged<SubSortColumn> onSort;
  final bool showDate, showSupplier, showItems, showQty, showSubmittedBy;

  const _TableHeader({
    required this.sortCol, required this.sortDir, required this.onSort,
    required this.showDate, required this.showSupplier,
    required this.showItems, required this.showQty, required this.showSubmittedBy,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: const BoxDecoration(
        color: _SubTheme.headerBg,
        border: Border(bottom: BorderSide(color: _SubTheme.border)),
      ),
      child: Row(
        children: [
          if (showDate) _SortHeaderCell(label: 'DATE', flex: 2, active: sortCol == SubSortColumn.date, dir: sortDir, onTap: () => onSort(SubSortColumn.date)),
          _SortHeaderCell(label: 'DR #', flex: 2, active: sortCol == SubSortColumn.drNumber, dir: sortDir, onTap: () => onSort(SubSortColumn.drNumber)),
          if (showSupplier) _SortHeaderCell(label: 'SUPPLIER', flex: 3, active: sortCol == SubSortColumn.supplier, dir: sortDir, onTap: () => onSort(SubSortColumn.supplier)),
          if (showItems) _SortHeaderCell(label: 'ITEMS', flex: 1, align: TextAlign.center, active: sortCol == SubSortColumn.items, dir: sortDir, onTap: () => onSort(SubSortColumn.items)),
          if (showQty) _SortHeaderCell(label: 'QTY', flex: 1, align: TextAlign.center, active: sortCol == SubSortColumn.qty, dir: sortDir, onTap: () => onSort(SubSortColumn.qty)),
          _SortHeaderCell(label: 'TOTAL VALUE', flex: 3, align: TextAlign.right, active: sortCol == SubSortColumn.totalValue, dir: sortDir, onTap: () => onSort(SubSortColumn.totalValue)),
          if (showSubmittedBy) _SortHeaderCell(label: 'BY', flex: 2, active: sortCol == SubSortColumn.submittedBy, dir: sortDir, onTap: () => onSort(SubSortColumn.submittedBy)),
          const _Cell(flex: 3, align: Alignment.center,
            child: Text('ACTIONS', textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _SubTheme.textLabel, letterSpacing: 0.6))),
        ],
      ),
    );
  }
}

class _SortHeaderCell extends StatelessWidget {
  final String label;
  final int flex;
  final bool active;
  final SubSortDir dir;
  final VoidCallback onTap;
  final TextAlign align;

  const _SortHeaderCell({
    required this.label, required this.flex, required this.active,
    required this.dir, required this.onTap, this.align = TextAlign.left,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: InkWell(
        onTap: onTap,
        child: Container(
          alignment: align == TextAlign.center ? Alignment.center : align == TextAlign.right ? Alignment.centerRight : Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: align == TextAlign.center ? MainAxisAlignment.center : align == TextAlign.right ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              Flexible(child: Text(label, textAlign: align, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                      color: active ? _SubTheme.primary : _SubTheme.textLabel, letterSpacing: 0.6))),
              const SizedBox(width: 4),
              Icon(active ? (dir == SubSortDir.asc ? Icons.arrow_upward : Icons.arrow_downward) : Icons.unfold_more,
                  size: 12, color: active ? _SubTheme.primary : const Color(0xFF9CA3AF)),
            ],
          ),
        ),
      ),
    );
  }
}

class _TableRow extends StatelessWidget {
  final SubmittedItem item;
  final bool isEven;
  final bool showDate, showSupplier, showItems, showQty, showSubmittedBy;
  final VoidCallback onView, onApprove, onReject;

  const _TableRow({
    required this.item, required this.isEven,
    required this.showDate, required this.showSupplier,
    required this.showItems, required this.showQty, required this.showSubmittedBy,
    required this.onView, required this.onApprove, required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final peso = NumberFormat.currency(locale: 'en_PH', symbol: '₱', decimalDigits: 0);
    final qtyFmt = NumberFormat.decimalPattern();
    final dateFmt = DateFormat('MM/dd/yyyy HH:mm');
    const cellStyle = TextStyle(fontSize: 13, color: _SubTheme.textDark);
    const mutedStyle = TextStyle(fontSize: 13, color: _SubTheme.textMuted);
    const valueStyle = TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _SubTheme.primary);

    return Container(
      decoration: BoxDecoration(
        color: isEven ? _SubTheme.rowEven : _SubTheme.rowOdd,
        border: const Border(bottom: BorderSide(color: _SubTheme.border, width: 0.5)),
      ),
      child: Row(
        children: [
          if (showDate) _Cell(flex: 2, child: Text(dateFmt.format(item.date), style: mutedStyle, overflow: TextOverflow.ellipsis)),
          _Cell(flex: 2, child: Text(item.drNumber, style: cellStyle.copyWith(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
          if (showSupplier) _Cell(flex: 3, child: Text(item.supplier.isEmpty ? '—' : item.supplier, style: cellStyle, overflow: TextOverflow.ellipsis)),
          if (showItems) _Cell(flex: 1, align: Alignment.center, child: Text('${item.itemsCount}', style: cellStyle, textAlign: TextAlign.center)),
          if (showQty) _Cell(flex: 1, align: Alignment.center, child: Text(qtyFmt.format(item.totalQty), style: cellStyle, textAlign: TextAlign.center)),
          _Cell(flex: 3, align: Alignment.centerRight,
              child: Text(peso.format(item.totalValue), style: valueStyle, textAlign: TextAlign.right, overflow: TextOverflow.ellipsis)),
          if (showSubmittedBy) _Cell(flex: 2, child: Text(item.submittedBy.isEmpty ? '—' : item.submittedBy, style: mutedStyle, overflow: TextOverflow.ellipsis)),
          _Cell(flex: 3, align: Alignment.center,
              child: Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
                _IconBtn(icon: Icons.visibility_outlined, color: _SubTheme.primary, bg: _SubTheme.primaryLight, onTap: onView, tooltip: 'View'),
                const SizedBox(width: 4),
                _IconBtn(icon: Icons.check_circle_outline, color: _SubTheme.green, bg: _SubTheme.greenLight, onTap: onApprove, tooltip: 'Approve'),
                const SizedBox(width: 4),
                _IconBtn(icon: Icons.cancel_outlined, color: _SubTheme.red, bg: _SubTheme.redLight, onTap: onReject, tooltip: 'Reject'),
              ])),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final Color color, bg;
  final VoidCallback onTap;
  final String tooltip;

  const _IconBtn({required this.icon, required this.color, required this.bg, required this.onTap, required this.tooltip});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 30, height: 30,
          decoration: BoxDecoration(color: bg, border: Border.all(color: color.withValues(alpha: 0.5)), borderRadius: BorderRadius.circular(6)),
          child: Icon(icon, size: 15, color: color),
        ),
      ),
    );
  }
}

class _PaginationFooter extends StatelessWidget {
  final int totalEntries, currentPage, totalPages, pageSize;
  final List<int> pageSizes;
  final ValueChanged<int> onPageChange, onPageSizeChange;
  final bool compact;

  const _PaginationFooter({
    required this.totalEntries, required this.currentPage,
    required this.totalPages, required this.pageSize, required this.pageSizes,
    required this.onPageChange, required this.onPageSizeChange, required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final start = totalEntries == 0 ? 0 : (currentPage - 1) * pageSize + 1;
    final end = (currentPage * pageSize).clamp(0, totalEntries);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: _SubTheme.border))),
      child: Row(
        children: [
          Expanded(
            child: Text(compact ? '$start–$end of $totalEntries' : 'Showing $start to $end of $totalEntries entries',
                style: const TextStyle(fontSize: 12, color: _SubTheme.textMuted),
                overflow: TextOverflow.ellipsis),
          ),
          _PageBtn(icon: Icons.chevron_left, enabled: currentPage > 1, onTap: () => onPageChange(currentPage - 1)),
          const SizedBox(width: 4),
          ..._buildPageNumbers(),
          const SizedBox(width: 4),
          _PageBtn(icon: Icons.chevron_right, enabled: currentPage < totalPages, onTap: () => onPageChange(currentPage + 1)),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(border: Border.all(color: _SubTheme.border), borderRadius: BorderRadius.circular(6)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: pageSize, isDense: true,
                items: pageSizes.map((s) => DropdownMenuItem(value: s, child: Text('$s / page', style: const TextStyle(fontSize: 12)))).toList(),
                onChanged: (v) => v != null ? onPageSizeChange(v) : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPageNumbers() {
    final pages = <int>[];
    final maxShow = compact ? 1 : 3;
    int startP = (currentPage - (maxShow ~/ 2)).clamp(1, totalPages);
    int endP = (startP + maxShow - 1).clamp(1, totalPages);
    if (endP - startP < maxShow - 1) startP = (endP - maxShow + 1).clamp(1, totalPages);
    for (int i = startP; i <= endP; i++) { pages.add(i); }
    return pages.map((p) {
      final active = p == currentPage;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: InkWell(
          onTap: () => onPageChange(p),
          borderRadius: BorderRadius.circular(6),
          child: Container(
            width: 30, height: 30, alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? _SubTheme.primary : Colors.white,
              border: Border.all(color: active ? _SubTheme.primary : _SubTheme.border),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('$p',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: active ? Colors.white : _SubTheme.textDark)),
          ),
        ),
      );
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
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 30, height: 30, alignment: Alignment.center,
        decoration: BoxDecoration(border: Border.all(color: _SubTheme.border), borderRadius: BorderRadius.circular(6), color: Colors.white),
        child: Icon(icon, size: 16, color: enabled ? _SubTheme.textDark : const Color(0xFFCBD5E1)),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  final int flex;
  final Widget child;
  final Alignment align;

  const _Cell({required this.flex, required this.child, this.align = Alignment.centerLeft});

  @override
  Widget build(BuildContext context) {
    return Expanded(flex: flex, child: Container(alignment: align, padding: const EdgeInsets.symmetric(horizontal: 10), child: child));
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.inbox_outlined, size: 56, color: Color(0xFFCBD5E1)),
        SizedBox(height: 12),
        Text('No pending submissions',
            style: TextStyle(color: _SubTheme.textMuted, fontSize: 14, fontWeight: FontWeight.w500)),
      ]),
    );
  }
}

class SubmittedItem {
  final String drNumber;
  final String supplier;
  final DateTime date;
  final int itemsCount;
  final int totalQty;
  final double totalValue;
  final String submittedBy;

  SubmittedItem({
    required this.drNumber, required this.supplier, required this.date,
    required this.itemsCount, required this.totalQty,
    required this.totalValue, required this.submittedBy,
  });
}
