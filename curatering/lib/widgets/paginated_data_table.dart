import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'antd_buttons.dart';
import 'antd_dialog.dart';
import 'antd_staff.dart';
import 'antd_tokens.dart';

/// Default page size for staff/admin data tables.
const int kTablePageSize = 80;

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

    return AntdCard(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Text(
            'Showing $start–$end of $totalItems · Page ${safePage + 1} of $pages',
            style: const TextStyle(
              color: AntdTokens.textSecondary,
              fontSize: 13,
            ),
          ),
          const Spacer(),
          AntdIconActionButton(
            tooltip: 'First page',
            onPressed: safePage > 0 ? () => onPageChanged(0) : null,
            icon: Icons.first_page,
          ),
          const SizedBox(width: 6),
          AntdIconActionButton(
            tooltip: 'Previous page',
            onPressed: safePage > 0 ? () => onPageChanged(safePage - 1) : null,
            icon: Icons.chevron_left,
          ),
          const SizedBox(width: 6),
          AntdIconActionButton(
            tooltip: 'Next page',
            onPressed:
                safePage < pages - 1 ? () => onPageChanged(safePage + 1) : null,
            icon: Icons.chevron_right,
          ),
          const SizedBox(width: 6),
          AntdIconActionButton(
            tooltip: 'Last page',
            onPressed:
                safePage < pages - 1 ? () => onPageChanged(pages - 1) : null,
            icon: Icons.last_page,
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
    this.title = 'Table export',
    this.enableSearch = true,
    this.enablePrint = true,
    this.filters = const [],
    this.maxTableHeight = 560,
    this.pdfExcludedColumnIndexes = const {},
    this.fullWidth = false,
    this.dataRowMinHeight,
    this.dataRowMaxHeight,
    this.headingRowHeight,
    this.horizontalMargin,
  });

  final List<DataColumn> columns;
  final List<DataRow> rows;
  final int pageSize;
  final WidgetStateProperty<Color?>? headingRowColor;
  final double? columnSpacing;
  final bool showVerticalScrollbar;
  final String title;
  final bool enableSearch;
  final bool enablePrint;
  final List<Widget> filters;
  final double maxTableHeight;
  final Set<int> pdfExcludedColumnIndexes;
  final bool fullWidth;
  final double? dataRowMinHeight;
  final double? dataRowMaxHeight;
  final double? headingRowHeight;
  final double? horizontalMargin;

  @override
  State<PagedDataTable> createState() => _PagedDataTableState();
}

class _PagedDataTableState extends State<PagedDataTable> {
  int _page = 0;
  int _lastRowCount = -1;
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(PagedDataTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.rows.length != _lastRowCount) {
      _page = 0;
      _lastRowCount = widget.rows.length;
    }
    final maxPage =
        tablePageCount(widget.rows.length, pageSize: widget.pageSize) - 1;
    if (_page > maxPage) _page = maxPage < 0 ? 0 : maxPage;
  }

  @override
  Widget build(BuildContext context) {
    final filteredRows = _filteredRows();
    final pageRows = tablePageSlice(
      filteredRows,
      _page,
      pageSize: widget.pageSize,
    );

    final table = Theme(
      data: Theme.of(context).copyWith(
        dataTableTheme: DataTableThemeData(
          headingTextStyle: const TextStyle(
            color: AntdTokens.valueDark,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
          dataTextStyle: const TextStyle(
            color: AntdTokens.valueDark,
            fontSize: 13,
          ),
          dividerThickness: 0.7,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AntdTokens.borderSubtle),
            borderRadius: BorderRadius.circular(AntdTokens.radiusMd),
          ),
        ),
      ),
      child: DataTable(
        columns: widget.columns,
        rows: pageRows,
        border: TableBorder(
          horizontalInside: const BorderSide(color: AntdTokens.borderSubtle),
          top: const BorderSide(color: AntdTokens.borderSubtle),
          bottom: const BorderSide(color: AntdTokens.borderSubtle),
          left: const BorderSide(color: AntdTokens.borderSubtle),
          right: const BorderSide(color: AntdTokens.borderSubtle),
          borderRadius: BorderRadius.circular(AntdTokens.radiusMd),
        ),
        headingRowColor:
            widget.headingRowColor ??
            WidgetStateProperty.all(AntdTokens.tableHeaderBg),
        dataRowColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.hovered)
                  ? AntdTokens.fillTertiary
                  : Colors.white,
        ),
        columnSpacing: widget.columnSpacing ?? 28,
        dataRowMinHeight: widget.dataRowMinHeight ?? 44,
        dataRowMaxHeight: widget.dataRowMaxHeight ?? 64,
        headingRowHeight: widget.headingRowHeight ?? 44,
        horizontalMargin: widget.horizontalMargin ?? 16,
      ),
    );

    Widget tableScroll = LayoutBuilder(
      builder: (context, constraints) {
        final child =
            widget.fullWidth
                ? ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: table,
                )
                : table;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: child,
        );
      },
    );

    if (widget.showVerticalScrollbar && pageRows.length > 12) {
      tableScroll = Scrollbar(
        thumbVisibility: true,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: widget.maxTableHeight),
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: tableScroll,
          ),
        ),
      );
    }

    return AntdCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.enableSearch ||
              widget.enablePrint ||
              widget.filters.isNotEmpty)
            _TableToolbar(
              title: widget.title,
              search: _search,
              enableSearch: widget.enableSearch,
              enablePrint: widget.enablePrint,
              filters: widget.filters,
              filteredRows: filteredRows.length,
              totalRows: widget.rows.length,
              onSearchChanged: (_) => setState(() => _page = 0),
              onPrint: () => _printFilteredRows(filteredRows),
            ),
          ClipRRect(
            borderRadius: BorderRadius.circular(AntdTokens.radiusMd),
            child: tableScroll,
          ),
          TablePaginationBar(
            currentPage: _page,
            totalItems: filteredRows.length,
            pageSize: widget.pageSize,
            onPageChanged: (p) => setState(() => _page = p),
          ),
        ],
      ),
    );
  }

  List<DataRow> _filteredRows() {
    final query = _search.text.trim().toLowerCase();
    if (!widget.enableSearch || query.isEmpty) return widget.rows;
    return widget.rows.where((row) {
      return _rowText(row).toLowerCase().contains(query);
    }).toList();
  }

  String _rowText(DataRow row) {
    return row.cells.map((cell) => _widgetText(cell.child)).join(' ');
  }

  Future<void> _printFilteredRows(List<DataRow> rows) async {
    final includedIndexes = <int>[
      for (var i = 0; i < widget.columns.length; i++)
        if (!widget.pdfExcludedColumnIndexes.contains(i) &&
            !_isActionHeader(_widgetText(widget.columns[i].label)))
          i,
    ];
    final headers =
        includedIndexes
            .map((i) => _widgetText(widget.columns[i].label))
            .toList();
    final data =
        rows
            .map(
              (row) =>
                  includedIndexes
                      .where((i) => i < row.cells.length)
                      .map((i) => _widgetText(row.cells[i].child))
                      .toList(),
            )
            .toList();
    final doc = pw.Document(title: widget.title);
    final generatedAt = DateTime.now();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        footer:
            (context) => pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'Page ${context.pageNumber} of ${context.pagesCount}',
                style: const pw.TextStyle(fontSize: 8),
              ),
            ),
        build:
            (context) => [
              pw.Text(
                widget.title,
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Macrina\'s Kitchen and Catering',
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Generated ${generatedAt.toLocal()} · ${rows.length} row(s)',
                style: const pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey700,
                ),
              ),
              pw.SizedBox(height: 12),
              pw.TableHelper.fromTextArray(
                headers: headers,
                data: data,
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.grey200,
                ),
                headerStyle: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                ),
                cellStyle: const pw.TextStyle(fontSize: 7),
                cellAlignment: pw.Alignment.centerLeft,
                headerAlignment: pw.Alignment.centerLeft,
              ),
            ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (_) => doc.save(),
      name: '${widget.title}.pdf',
    );
  }
}

bool _isActionHeader(String raw) {
  final text = raw.trim().toLowerCase();
  return text == 'action' || text == 'actions';
}

class _TableToolbar extends StatelessWidget {
  const _TableToolbar({
    required this.title,
    required this.search,
    required this.enableSearch,
    required this.enablePrint,
    required this.filters,
    required this.filteredRows,
    required this.totalRows,
    required this.onSearchChanged,
    required this.onPrint,
  });

  final String title;
  final TextEditingController search;
  final bool enableSearch;
  final bool enablePrint;
  final List<Widget> filters;
  final int filteredRows;
  final int totalRows;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onPrint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AntdToolbar(
        padding: const EdgeInsets.all(10),
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AntdTokens.valueDark,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (enableSearch)
            AntdSearchInput(
              controller: search,
              hintText: 'Search table',
              onChanged: onSearchChanged,
              onClear: () {
                search.clear();
                onSearchChanged('');
              },
            ),
          if (filters.isNotEmpty)
            AntdSecondaryButton(
              onPressed: () => _showFilters(context),
              icon: Icons.filter_list,
              label: 'Filters',
            )
          else if (enableSearch)
            AntdSecondaryButton(
              onPressed:
                  search.text.isEmpty
                      ? null
                      : () {
                        search.clear();
                        onSearchChanged('');
                      },
              icon: Icons.filter_alt_off,
              label: 'Clear filter',
            ),
          if (enablePrint)
            AntdSecondaryButton(
              onPressed: onPrint,
              icon: Icons.picture_as_pdf,
              label: 'Print PDF',
            ),
          AntdStatusTag(
            label: '$filteredRows of $totalRows rows',
            color: AntdTokens.textSecondary,
          ),
        ],
      ),
    );
  }

  void _showFilters(BuildContext context) {
    showAntdModal<void>(
      context: context,
      title: '$title filters',
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: filters,
      ),
      actions: antdModalActions(
        context: context,
        okLabel: 'Done',
        onOk: () => Navigator.of(context).pop(),
      ),
    );
  }
}

String _widgetText(Widget widget) {
  if (widget is Text) {
    return widget.data ?? widget.textSpan?.toPlainText() ?? '';
  }
  if (widget is RichText) return widget.text.toPlainText();
  if (widget is Tooltip)
    return widget.message ?? _widgetText(widget.child ?? const SizedBox());
  if (widget is Padding) return _widgetText(widget.child ?? const SizedBox());
  if (widget is Center) return _widgetText(widget.child ?? const SizedBox());
  if (widget is Align) return _widgetText(widget.child ?? const SizedBox());
  if (widget is SizedBox && widget.child != null)
    return _widgetText(widget.child!);
  if (widget is Container && widget.child != null)
    return _widgetText(widget.child!);
  if (widget is Expanded) return _widgetText(widget.child);
  if (widget is Flexible) return _widgetText(widget.child);
  if (widget is Row) return widget.children.map(_widgetText).join(' ');
  if (widget is Column) return widget.children.map(_widgetText).join(' ');
  if (widget is Wrap) return widget.children.map(_widgetText).join(' ');
  if (widget is Icon) return '';
  if (widget is IconButton) return widget.tooltip ?? '';
  if (widget is TextButton)
    return _widgetText(widget.child ?? const SizedBox());
  if (widget is OutlinedButton)
    return _widgetText(widget.child ?? const SizedBox());
  if (widget is ElevatedButton)
    return _widgetText(widget.child ?? const SizedBox());
  return widget.toStringShort();
}
