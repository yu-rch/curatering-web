import 'dart:convert';
import 'dart:math' as math;

import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/print_tabular_report.dart';
import '../utils/web_csv_download.dart';
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
    this.compact = false,
  });

  final int currentPage;
  final int totalItems;
  final int pageSize;
  final ValueChanged<int> onPageChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (totalItems == 0) return const SizedBox.shrink();

    final pages = tablePageCount(totalItems, pageSize: pageSize);
    final safePage = currentPage.clamp(0, pages - 1);
    final start = safePage * pageSize + 1;
    final end = ((safePage + 1) * pageSize).clamp(0, totalItems);

    final content = Row(
      mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
      children: [
        Text(
          compact
              ? '$start–$end of $totalItems'
              : 'Showing $start–$end of $totalItems · Page ${safePage + 1} of $pages',
          style: TextStyle(color: AntdTokens.textSecondary, fontSize: 13),
        ),
        if (!compact) const Spacer() else const SizedBox(width: 8),
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
    );

    if (compact) return content;

    return AntdCard(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: content,
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
    this.forceVerticalScroll = false,
    this.title = 'Table export',
    this.enableSearch = true,
    this.enablePrint = true,
    this.enableCsv = true,
    this.filters = const [],
    this.maxTableHeight = 560,
    this.pdfExcludedColumnIndexes = const {},
    this.fullWidth = false,
    this.minTableWidth,
    this.dataRowMinHeight,
    this.dataRowMaxHeight,
    this.headingRowHeight,
    this.horizontalMargin,
    this.toolbarActions = const [],
  });

  final List<DataColumn> columns;
  final List<DataRow> rows;
  final int pageSize;
  final WidgetStateProperty<Color?>? headingRowColor;
  final double? columnSpacing;
  final bool showVerticalScrollbar;
  final bool forceVerticalScroll;
  final String title;
  final bool enableSearch;
  final bool enablePrint;
  final bool enableCsv;
  final List<Widget> filters;
  final double maxTableHeight;
  final Set<int> pdfExcludedColumnIndexes;
  final bool fullWidth;
  final double? minTableWidth;
  final double? dataRowMinHeight;
  final double? dataRowMaxHeight;
  final double? headingRowHeight;
  final double? horizontalMargin;
  final List<Widget> toolbarActions;

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

    final columnSpacing =
        widget.columnSpacing ?? (widget.fullWidth ? 12.0 : 28.0);
    final horizontalMargin =
        widget.horizontalMargin ?? (widget.fullWidth ? 8.0 : 16.0);

    final table = Theme(
      data: Theme.of(context).copyWith(
        dataTableTheme: DataTableThemeData(
          headingTextStyle: TextStyle(
            color: AntdTokens.valueDark,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
          dataTextStyle: TextStyle(
            color: AntdTokens.valueDark,
            fontSize: 13,
          ),
          dividerThickness: 0.7,
          decoration: BoxDecoration(
            color: AntdTokens.cardBg,
            border: Border.all(color: AntdTokens.borderSubtle),
            borderRadius: BorderRadius.circular(AntdTokens.radiusMd),
          ),
        ),
      ),
      child: DataTable(
        showCheckboxColumn: false,
        columns: widget.columns,
        rows: pageRows,
        border: TableBorder(
          horizontalInside: BorderSide(color: AntdTokens.borderSubtle),
          top: BorderSide(color: AntdTokens.borderSubtle),
          bottom: BorderSide(color: AntdTokens.borderSubtle),
          left: BorderSide(color: AntdTokens.borderSubtle),
          right: BorderSide(color: AntdTokens.borderSubtle),
          borderRadius: BorderRadius.circular(AntdTokens.radiusMd),
        ),
        headingRowColor:
            widget.headingRowColor ??
            WidgetStateProperty.all(AntdTokens.tableHeaderBg),
        dataRowColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AntdTokens.brandPrimary.withValues(alpha: 0.22);
          }
          if (states.contains(WidgetState.hovered)) {
            return AntdTokens.fillTertiary;
          }
          return AntdTokens.cardBg;
        }),
        columnSpacing: columnSpacing,
        dataRowMinHeight: widget.dataRowMinHeight ?? 44,
        dataRowMaxHeight: widget.dataRowMaxHeight ?? 64,
        headingRowHeight: widget.headingRowHeight ?? 44,
        horizontalMargin: horizontalMargin,
      ),
    );

    Widget horizontalTable = LayoutBuilder(
      builder: (context, constraints) {
        // Prefer stretching to the panel when there is room, but never drop
        // below [minTableWidth] so narrow monitors get horizontal scroll
        // instead of column overflow.
        final preferredMin = widget.minTableWidth ?? 720.0;
        final available = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : preferredMin;
        final minTableWidth = widget.fullWidth
            ? math.max(available, preferredMin)
            : preferredMin;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: minTableWidth,
            ),
            child: table,
          ),
        );
      },
    );

    return LayoutBuilder(
      builder: (context, outerConstraints) {
        final boundedHeight =
            widget.forceVerticalScroll && outerConstraints.maxHeight.isFinite;
        final useVerticalScroll =
            widget.showVerticalScrollbar &&
            (widget.forceVerticalScroll || pageRows.length > 12);

        Widget tableScroll;
        if (boundedHeight) {
          // Fill remaining modal space; scroll inside (don't overflow chrome).
          tableScroll = Scrollbar(
            thumbVisibility: true,
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: horizontalTable,
            ),
          );
        } else if (useVerticalScroll) {
          tableScroll = Scrollbar(
            thumbVisibility: true,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: widget.maxTableHeight),
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: horizontalTable,
              ),
            ),
          );
        } else {
          tableScroll = horizontalTable;
        }

        final columnChildren = <Widget>[
          _TableTitleBar(
            title: widget.title,
            pagination: TablePaginationBar(
              currentPage: _page,
              totalItems: filteredRows.length,
              pageSize: widget.pageSize,
              compact: true,
              onPageChanged: (p) => setState(() => _page = p),
            ),
          ),
          if (widget.enableSearch ||
              widget.enablePrint ||
              widget.enableCsv ||
              widget.filters.isNotEmpty ||
              widget.toolbarActions.isNotEmpty)
            _TableToolbar(
              tableTitle: widget.title,
              search: _search,
              enableSearch: widget.enableSearch,
              enablePrint: widget.enablePrint,
              enableCsv: widget.enableCsv,
              filters: widget.filters,
              filteredRows: filteredRows.length,
              totalRows: widget.rows.length,
              onSearchChanged: (_) => setState(() => _page = 0),
              onPrint: () => _printFilteredRows(filteredRows),
              onCsv: () => _exportCsv(filteredRows),
              extraActions: widget.toolbarActions,
            ),
          if (boundedHeight)
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AntdTokens.radiusMd),
                child: tableScroll,
              ),
            )
          else
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
        ];

        final cardChild = boundedHeight
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: columnChildren,
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: columnChildren,
              );

        if (boundedHeight) {
          // Parent already supplies a card / bounded box. Extra AntdCard
          // padding would make the table taller than the container.
          return ClipRRect(
            borderRadius: BorderRadius.circular(AntdTokens.radiusLg),
            child: cardChild,
          );
        }

        return AntdCard(
          padding: const EdgeInsets.all(12),
          child: cardChild,
        );
      },
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
    final generatedAt = DateTime.now();
    await printSingleTableReport(
      title: widget.title,
      headers: headers,
      rows: data,
      sectionTitle: widget.title,
      filename: '${widget.title}.pdf',
      subtitle:
          "Macrina's Kitchen and Catering · Generated ${generatedAt.toLocal()} · ${rows.length} row(s)",
    );
  }

  Future<void> _exportCsv(List<DataRow> rows) async {
    final includedIndexes = <int>[
      for (var i = 0; i < widget.columns.length; i++)
        if (!widget.pdfExcludedColumnIndexes.contains(i) &&
            !_isActionHeader(_widgetText(widget.columns[i].label)))
          i,
    ];
    final csvRows = <List<String>>[
      includedIndexes.map((i) => _widgetText(widget.columns[i].label)).toList(),
      ...rows.map(
        (row) =>
            includedIndexes
                .where((i) => i < row.cells.length)
                .map((i) => _widgetText(row.cells[i].child))
                .toList(),
      ),
    ];
    final csv = csvRows.map(_csvLine).join('\r\n');
    final fileName = '${_safeFileName(widget.title)}.csv';
    if (kIsWeb) {
      downloadCsvBytes(Uint8List.fromList(utf8.encode(csv)), fileName);
      return;
    }
    await Clipboard.setData(ClipboardData(text: csv));
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$fileName copied to clipboard.')));
    }
  }
}

bool _isActionHeader(String raw) {
  final text = raw.trim().toLowerCase();
  return text == 'action' || text == 'actions';
}

class _TableToolbar extends StatelessWidget {
  const _TableToolbar({
    required this.tableTitle,
    required this.search,
    required this.enableSearch,
    required this.enablePrint,
    required this.enableCsv,
    required this.filters,
    required this.filteredRows,
    required this.totalRows,
    required this.onSearchChanged,
    required this.onPrint,
    required this.onCsv,
    required this.extraActions,
  });

  final String tableTitle;
  final TextEditingController search;
  final bool enableSearch;
  final bool enablePrint;
  final bool enableCsv;
  final List<Widget> filters;
  final int filteredRows;
  final int totalRows;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onPrint;
  final VoidCallback onCsv;
  final List<Widget> extraActions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AntdToolbar(
        padding: const EdgeInsets.all(10),
        children: [
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
              onPressed: () => _showFilters(context, tableTitle),
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
          if (enableCsv)
            AntdSecondaryButton(
              onPressed: onCsv,
              icon: Icons.table_view,
              label: 'Export CSV',
            ),
          AntdStatusTag(
            label: '$filteredRows of $totalRows rows',
            color: AntdTokens.textSecondary,
          ),
          ...extraActions,
        ],
      ),
    );
  }

  void _showFilters(BuildContext context, String title) {
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

class _TableTitleBar extends StatelessWidget {
  const _TableTitleBar({required this.title, required this.pagination});

  final String title;
  final Widget pagination;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: AntdTokens.valueDark,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          pagination,
        ],
      ),
    );
  }
}

String _csvLine(List<String> cells) {
  return cells
      .map((value) {
        final escaped = value
            .replaceAll('"', '""')
            .replaceAll('\r', ' ')
            .replaceAll('\n', ' ');
        return '"$escaped"';
      })
      .join(',');
}

String _safeFileName(String value) {
  final cleaned = value.trim().replaceAll(RegExp(r'[\\/:*?"<>|]+'), '_');
  return cleaned.isEmpty ? 'table_export' : cleaned;
}

String _widgetText(Widget widget) {
  if (widget is Text) {
    return widget.data ?? widget.textSpan?.toPlainText() ?? '';
  }
  if (widget is RichText) return widget.text.toPlainText();
  if (widget is EditableText) return widget.controller.text;

  final typeName = widget.runtimeType.toString();
  if (typeName.startsWith('TextField') || typeName.startsWith('TextFormField')) {
    final dynamic field = widget;
    final controllerText = field.controller?.text;
    if (controllerText is String && controllerText.isNotEmpty) {
      return controllerText;
    }
    final initial = field.initialValue;
    if (initial is String) return initial;
    final hint = field.decoration?.hintText;
    if (hint is String && hint.isNotEmpty) return hint;
    final label = field.decoration?.labelText;
    if (label is String) return label;
    return '';
  }
  if (typeName.startsWith('DropdownButton')) {
    final dynamic dropdown = widget;
    final value = dropdown.value;
    final items = dropdown.items;
    if (items is List) {
      for (final item in items) {
        if (item is DropdownMenuItem && item.value == value) {
          return _widgetText(item.child);
        }
      }
    }
    return value == null ? '' : '$value';
  }
  if (widget is DropdownButtonHideUnderline) {
    return _widgetText(widget.child);
  }
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
  // Never export Widget.toStringShort() — in release builds it is the literal
  // string "Widget", which leaked into CSV/PDF exports for form cells.
  return '';
}
