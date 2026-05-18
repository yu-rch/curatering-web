import 'package:flutter/material.dart';

/// Default page size for staff/admin data tables.
const int kTablePageSize = 75;

/// Slices [items] for zero-based [pageIndex].
List<T> tablePageSlice<T>(
  List<T> items,
  int pageIndex, {
  int pageSize = kTablePageSize,
}) {
  if (items.isEmpty || pageIndex < 0) return const [];
  final start = pageIndex * pageSize;
  if (start >= items.length) return const [];
  final end = (start + pageSize).clamp(0, items.length);
  return items.sublist(start, end);
}

int tablePageCount(int totalItems, {int pageSize = kTablePageSize}) {
  if (totalItems <= 0) return 1;
  return ((totalItems - 1) / pageSize).floor() + 1;
}

class TablePaginationBar extends StatelessWidget {
  const TablePaginationBar({
    super.key,
    required this.currentPage,
    required this.totalItems,
    this.pageSize = kTablePageSize,
    required this.onPageChanged,
  });

  final int currentPage;
  final int totalItems;
  final int pageSize;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    if (totalItems == 0) return const SizedBox.shrink();

    final pages = tablePageCount(totalItems, pageSize: pageSize);
    final safePage = currentPage.clamp(0, pages - 1);
    final start = safePage * pageSize + 1;
    final end = ((safePage + 1) * pageSize).clamp(0, totalItems);

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Text(
            'Showing $start–$end of $totalItems · Page ${safePage + 1} of $pages',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'First page',
            onPressed: safePage > 0 ? () => onPageChanged(0) : null,
            icon: const Icon(Icons.first_page),
          ),
          IconButton(
            tooltip: 'Previous page',
            onPressed: safePage > 0 ? () => onPageChanged(safePage - 1) : null,
            icon: const Icon(Icons.chevron_left),
          ),
          IconButton(
            tooltip: 'Next page',
            onPressed:
                safePage < pages - 1 ? () => onPageChanged(safePage + 1) : null,
            icon: const Icon(Icons.chevron_right),
          ),
          IconButton(
            tooltip: 'Last page',
            onPressed:
                safePage < pages - 1 ? () => onPageChanged(pages - 1) : null,
            icon: const Icon(Icons.last_page),
          ),
        ],
      ),
    );
  }
}

/// [DataTable] with client-side pagination ([kTablePageSize] rows per page).
class PagedDataTable extends StatefulWidget {
  const PagedDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.pageSize = kTablePageSize,
    this.headingRowColor,
    this.columnSpacing,
    this.showVerticalScrollbar = true,
  });

  final List<DataColumn> columns;
  final List<DataRow> rows;
  final int pageSize;
  final WidgetStateProperty<Color?>? headingRowColor;
  final double? columnSpacing;
  final bool showVerticalScrollbar;

  @override
  State<PagedDataTable> createState() => _PagedDataTableState();
}

class _PagedDataTableState extends State<PagedDataTable> {
  int _page = 0;
  int _lastRowCount = -1;

  @override
  void didUpdateWidget(PagedDataTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.rows.length != _lastRowCount) {
      _page = 0;
      _lastRowCount = widget.rows.length;
    }
    final maxPage = tablePageCount(widget.rows.length, pageSize: widget.pageSize) - 1;
    if (_page > maxPage) _page = maxPage < 0 ? 0 : maxPage;
  }

  @override
  Widget build(BuildContext context) {
    final pageRows = tablePageSlice(widget.rows, _page, pageSize: widget.pageSize);

    final table = DataTable(
      columns: widget.columns,
      rows: pageRows,
      headingRowColor: widget.headingRowColor,
      columnSpacing: widget.columnSpacing,
    );

    Widget tableScroll = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: table,
    );

    if (widget.showVerticalScrollbar && pageRows.length > 12) {
      tableScroll = Scrollbar(
        thumbVisibility: true,
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: tableScroll,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        tableScroll,
        TablePaginationBar(
          currentPage: _page,
          totalItems: widget.rows.length,
          pageSize: widget.pageSize,
          onPageChanged: (p) => setState(() => _page = p),
        ),
      ],
    );
  }
}
