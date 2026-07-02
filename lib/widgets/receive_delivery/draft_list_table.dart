import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class _DraftTheme {
  static const purple       = Color(0xFF7C3AED);
  static const purpleLight  = Color(0xFFEDE9FE);
  static const redDelete    = Color(0xFFEF4444);
  static const redLight     = Color(0xFFFEE2E2);
  static const rowEven      = Colors.white;
  static const rowOdd       = Color(0xFFF8F9FC);
  static const border       = Color(0xFFE5E7EB);
  static const headerBg     = Color(0xFFF9FAFB);
  static const textDark     = Color(0xFF111827);
  static const textMuted    = Color(0xFF6B7280);
  static const textLabel    = Color(0xFF374151);
}

enum SortColumn { date, drNumber, supplier, items, qty, totalValue, updated }
enum SortDir { asc, desc }

class DraftListTable extends StatefulWidget {
  final List<DraftItem> drafts;
  final void Function(DraftItem) onContinue;
  final void Function(DraftItem) onDelete;
  final void Function(String)? onSearch;
  final VoidCallback? onBack;
  final VoidCallback? onFilter;
  final VoidCallback? onRefresh;

  const DraftListTable({
    super.key,
    required this.drafts,
    required this.onContinue,
    required this.onDelete,
    this.onSearch,
    this.onBack,
    this.onFilter,
    this.onRefresh,
  });

  @override
  State<DraftListTable> createState() => _DraftListTableState();
}

class _DraftListTableState extends State<DraftListTable> {
  final _searchCtrl = TextEditingController();
  SortColumn _sortCol = SortColumn.date;
  SortDir _sortDir = SortDir.desc;
  int _currentPage = 1;
  int _pageSize = 10;
  final List<int> _pageSizes = [10, 25, 50, 100];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<DraftItem> get _processed {
    var list = List<DraftItem>.from(widget.drafts);
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((d) =>
          d.drNumber.toLowerCase().contains(q) ||
          d.supplier.toLowerCase().contains(q)).toList();
    }
    list.sort((a, b) {
      int cmp;
      switch (_sortCol) {
        case SortColumn.date:       cmp = a.date.compareTo(b.date); break;
        case SortColumn.drNumber:   cmp = a.drNumber.compareTo(b.drNumber); break;
        case SortColumn.supplier:   cmp = a.supplier.compareTo(b.supplier); break;
        case SortColumn.items:      cmp = a.itemsCount.compareTo(b.itemsCount); break;
        case SortColumn.qty:        cmp = a.totalQty.compareTo(b.totalQty); break;
        case SortColumn.totalValue: cmp = a.totalValue.compareTo(b.totalValue); break;
        case SortColumn.updated:    cmp = a.lastUpdated.compareTo(b.lastUpdated); break;
      }
      return _sortDir == SortDir.asc ? cmp : -cmp;
    });
    return list;
  }

  List<DraftItem> get _pageItems {
    final all = _processed;
    final start = (_currentPage - 1) * _pageSize;
    if (start >= all.length) return [];
    final end = (start + _pageSize).clamp(0, all.length);
    return all.sublist(start, end);
  }

  int get _totalPages => (_processed.length / _pageSize).ceil().clamp(1, 9999);

  void _toggleSort(SortColumn col) {
    setState(() {
      if (_sortCol == col) {
        _sortDir = _sortDir == SortDir.asc ? SortDir.desc : SortDir.asc;
      } else {
        _sortCol = col;
        _sortDir = SortDir.asc;
      }
      _currentPage = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final showDate     = width >= 600;
        final showSupplier = width >= 800;
        final showItems    = width >= 800;
        final showQty      = width >= 1200;
        final showUpdated  = width >= 1200;

        return Container(
          color: Colors.white,
          child: Column(
            children: [
              _PurpleHeader(
                controller: _searchCtrl,
                onSearch: (v) {
                  setState(() => _currentPage = 1);
                  widget.onSearch?.call(v);
                },
                onBack: widget.onBack,
                onFilter: widget.onFilter,
                onRefresh: widget.onRefresh,
                totalCount: widget.drafts.length,
              ),
              _TableHeader(
                sortCol: _sortCol,
                sortDir: _sortDir,
                onSort: _toggleSort,
                showDate: showDate,
                showSupplier: showSupplier,
                showItems: showItems,
                showQty: showQty,
                showUpdated: showUpdated,
              ),
              Expanded(
                child: _pageItems.isEmpty
                    ? const _EmptyState()
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        itemCount: _pageItems.length,
                        itemExtent: 52,
                        itemBuilder: (context, index) {
                          return _TableRow(
                            draft: _pageItems[index],
                            isEven: index.isEven,
                            showDate: showDate,
                            showSupplier: showSupplier,
                            showItems: showItems,
                            showQty: showQty,
                            showUpdated: showUpdated,
                            onContinue: () => widget.onContinue(_pageItems[index]),
                            onDelete: () => widget.onDelete(_pageItems[index]),
                          );
                        },
                      ),
              ),
              _PaginationFooter(
                totalEntries: _processed.length,
                currentPage: _currentPage,
                totalPages: _totalPages,
                pageSize: _pageSize,
                pageSizes: _pageSizes,
                onPageChange: (p) => setState(() => _currentPage = p),
                onPageSizeChange: (s) => setState(() {
                  _pageSize = s;
                  _currentPage = 1;
                }),
                compact: width < 600,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PurpleHeader extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onSearch;
  final VoidCallback? onBack, onFilter, onRefresh;
  final int totalCount;

  const _PurpleHeader({
    required this.controller,
    required this.onSearch,
    required this.onBack,
    required this.onFilter,
    required this.onRefresh,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _DraftTheme.purple,
      padding: const EdgeInsets.fromLTRB(8, 12, 12, 16),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back, color: Colors.white)),
              const Icon(Icons.description_outlined, color: Colors.white, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('DRAFT',
                        style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                    Text('$totalCount saved · Not submitted',
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
              controller: controller,
              onChanged: onSearch,
              decoration: const InputDecoration(
                border: InputBorder.none,
                prefixIcon: Icon(Icons.search, color: Color(0xFF9CA3AF)),
                hintText: 'Search DR# or supplier...',
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
  final SortColumn sortCol;
  final SortDir sortDir;
  final ValueChanged<SortColumn> onSort;
  final bool showDate, showSupplier, showItems, showQty, showUpdated;

  const _TableHeader({
    required this.sortCol,
    required this.sortDir,
    required this.onSort,
    required this.showDate,
    required this.showSupplier,
    required this.showItems,
    required this.showQty,
    required this.showUpdated,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: const BoxDecoration(
        color: _DraftTheme.headerBg,
        border: Border(bottom: BorderSide(color: _DraftTheme.border)),
      ),
      child: Row(
        children: [
          if (showDate)
            _SortableHeaderCell(label: 'DATE', flex: 2, active: sortCol == SortColumn.date, dir: sortDir, onTap: () => onSort(SortColumn.date)),
          _SortableHeaderCell(label: 'DR #', flex: 2, active: sortCol == SortColumn.drNumber, dir: sortDir, onTap: () => onSort(SortColumn.drNumber)),
          if (showSupplier)
            _SortableHeaderCell(label: 'SUPPLIER', flex: 3, active: sortCol == SortColumn.supplier, dir: sortDir, onTap: () => onSort(SortColumn.supplier)),
          if (showItems)
            _SortableHeaderCell(label: 'ITEMS', flex: 1, align: TextAlign.center, active: sortCol == SortColumn.items, dir: sortDir, onTap: () => onSort(SortColumn.items)),
          if (showQty)
            _SortableHeaderCell(label: 'QTY', flex: 1, align: TextAlign.center, active: sortCol == SortColumn.qty, dir: sortDir, onTap: () => onSort(SortColumn.qty)),
          _SortableHeaderCell(label: 'TOTAL VALUE', flex: 3, align: TextAlign.right, active: sortCol == SortColumn.totalValue, dir: sortDir, onTap: () => onSort(SortColumn.totalValue)),
          if (showUpdated)
            _SortableHeaderCell(label: 'UPDATED', flex: 2, active: sortCol == SortColumn.updated, dir: sortDir, onTap: () => onSort(SortColumn.updated)),
          const _Cell(
            flex: 2,
            align: Alignment.center,
            child: Text('ACTIONS', textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _DraftTheme.textLabel, letterSpacing: 0.6)),
          ),
        ],
      ),
    );
  }
}

class _SortableHeaderCell extends StatelessWidget {
  final String label;
  final int flex;
  final bool active;
  final SortDir dir;
  final VoidCallback onTap;
  final TextAlign align;

  const _SortableHeaderCell({
    required this.label,
    required this.flex,
    required this.active,
    required this.dir,
    required this.onTap,
    this.align = TextAlign.left,
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
              Flexible(
                child: Text(label, textAlign: align, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                    color: active ? _DraftTheme.purple : _DraftTheme.textLabel, letterSpacing: 0.6)),
              ),
              const SizedBox(width: 4),
              Icon(active ? (dir == SortDir.asc ? Icons.arrow_upward : Icons.arrow_downward) : Icons.unfold_more,
                size: 12, color: active ? _DraftTheme.purple : const Color(0xFF9CA3AF)),
            ],
          ),
        ),
      ),
    );
  }
}

class _TableRow extends StatelessWidget {
  final DraftItem draft;
  final bool isEven;
  final bool showDate, showSupplier, showItems, showQty, showUpdated;
  final VoidCallback onContinue, onDelete;

  const _TableRow({
    required this.draft,
    required this.isEven,
    required this.showDate,
    required this.showSupplier,
    required this.showItems,
    required this.showQty,
    required this.showUpdated,
    required this.onContinue,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final peso = NumberFormat.currency(locale: 'en_PH', symbol: '₱', decimalDigits: 0);
    final qtyFmt = NumberFormat.decimalPattern();
    final dateFmt = DateFormat('MM/dd/yyyy HH:mm');
    const cellStyle = TextStyle(fontSize: 13, color: _DraftTheme.textDark);
    const mutedStyle = TextStyle(fontSize: 13, color: _DraftTheme.textMuted);
    const valueStyle = TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _DraftTheme.purple);

    return Container(
      decoration: BoxDecoration(
        color: isEven ? _DraftTheme.rowEven : _DraftTheme.rowOdd,
        border: const Border(bottom: BorderSide(color: _DraftTheme.border, width: 0.5)),
      ),
      child: Row(
        children: [
          if (showDate)
            _Cell(flex: 2, child: Text(dateFmt.format(draft.date), style: mutedStyle, overflow: TextOverflow.ellipsis)),
          _Cell(flex: 2, child: Text(draft.drNumber, style: cellStyle.copyWith(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
          if (showSupplier)
            _Cell(flex: 3, child: Text(draft.supplier.isEmpty ? '—' : draft.supplier, style: cellStyle, overflow: TextOverflow.ellipsis)),
          if (showItems)
            _Cell(flex: 1, align: Alignment.center, child: Text('${draft.itemsCount}', style: cellStyle, textAlign: TextAlign.center)),
          if (showQty)
            _Cell(flex: 1, align: Alignment.center, child: Text(qtyFmt.format(draft.totalQty), style: cellStyle, textAlign: TextAlign.center)),
          _Cell(flex: 3, align: Alignment.centerRight,
            child: Text(peso.format(draft.totalValue), style: valueStyle, textAlign: TextAlign.right, overflow: TextOverflow.ellipsis)),
          if (showUpdated)
            _Cell(flex: 2, child: Text(_relative(draft.lastUpdated), style: mutedStyle, overflow: TextOverflow.ellipsis)),
          _Cell(flex: 2, align: Alignment.center,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
              _IconBtn(icon: Icons.edit_outlined, color: _DraftTheme.purple, bg: _DraftTheme.purpleLight, onTap: onContinue, tooltip: 'Continue'),
              const SizedBox(width: 6),
              _IconBtn(icon: Icons.delete_outline, color: _DraftTheme.redDelete, bg: _DraftTheme.redLight, onTap: onDelete, tooltip: 'Delete'),
            ])),
        ],
      ),
    );
  }

  String _relative(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MM/dd/yy').format(d);
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
          width: 32, height: 32,
          decoration: BoxDecoration(color: bg, border: Border.all(color: color.withValues(alpha: 0.5)), borderRadius: BorderRadius.circular(6)),
          child: Icon(icon, size: 16, color: color),
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
    required this.totalEntries,
    required this.currentPage,
    required this.totalPages,
    required this.pageSize,
    required this.pageSizes,
    required this.onPageChange,
    required this.onPageSizeChange,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final start = totalEntries == 0 ? 0 : (currentPage - 1) * pageSize + 1;
    final end = (currentPage * pageSize).clamp(0, totalEntries);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: _DraftTheme.border))),
      child: Row(
        children: [
          Expanded(
            child: Text(
              compact ? '$start–$end of $totalEntries' : 'Showing $start to $end of $totalEntries entries',
              style: const TextStyle(fontSize: 12, color: _DraftTheme.textMuted),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          _PageBtn(icon: Icons.chevron_left, enabled: currentPage > 1, onTap: () => onPageChange(currentPage - 1)),
          const SizedBox(width: 4),
          ..._buildPageNumbers(),
          const SizedBox(width: 4),
          _PageBtn(icon: Icons.chevron_right, enabled: currentPage < totalPages, onTap: () => onPageChange(currentPage + 1)),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(border: Border.all(color: _DraftTheme.border), borderRadius: BorderRadius.circular(6)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: pageSize,
                isDense: true,
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
    if (endP - startP < maxShow - 1) {
      startP = (endP - maxShow + 1).clamp(1, totalPages);
    }
    for (int i = startP; i <= endP; i++) {
      pages.add(i);
    }

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
              color: active ? _DraftTheme.purple : Colors.white,
              border: Border.all(color: active ? _DraftTheme.purple : _DraftTheme.border),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('$p',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: active ? Colors.white : _DraftTheme.textDark)),
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
        decoration: BoxDecoration(border: Border.all(color: _DraftTheme.border), borderRadius: BorderRadius.circular(6), color: Colors.white),
        child: Icon(icon, size: 16, color: enabled ? _DraftTheme.textDark : const Color(0xFFCBD5E1)),
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
    return Expanded(
      flex: flex,
      child: Container(alignment: align, padding: const EdgeInsets.symmetric(horizontal: 10), child: child),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 56, color: Color(0xFFCBD5E1)),
          SizedBox(height: 12),
          Text('No drafts found',
              style: TextStyle(color: _DraftTheme.textMuted, fontSize: 14, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class DraftItem {
  final String drNumber;
  final String supplier;
  final DateTime date;
  final int itemsCount;
  final int totalQty;
  final double totalValue;
  final DateTime lastUpdated;

  DraftItem({
    required this.drNumber,
    required this.supplier,
    required this.date,
    required this.itemsCount,
    required this.totalQty,
    required this.totalValue,
    required this.lastUpdated,
  });
}
