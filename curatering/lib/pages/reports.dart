import 'package:flutter/material.dart';

import '../auth/auth_session.dart';
import '../auth/roles.dart';
import '../services/reports_api.dart';
import '../services/reports_pdf_service.dart';
import '../utils/order_calculations.dart';
import '../widgets/antd_buttons.dart';
import '../widgets/antd_message.dart';
import '../widgets/antd_staff.dart';
import '../widgets/antd_tokens.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/paginated_data_table.dart';

enum _ReportScope { catering, cateringEvents, restaurant, combined }

class _DetailRow {
  const _DetailRow(this.label, this.value);

  final String label;
  final String value;
}

class Reports extends StatefulWidget {
  const Reports({super.key});

  @override
  State<Reports> createState() => _ReportsState();
}

class _ReportsState extends State<Reports> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  _ReportScope _scope = _ReportScope.combined;
  bool _annualMode = false;

  DateTime _selectedMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );
  int _selectedYear = DateTime.now().year;

  ReportsSummaryData? _data;
  bool _isLoading = false;
  bool _exportingPdf = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (AuthSession.instance.currentRole != Role.manager &&
        AuthSession.instance.currentRole != Role.superAdmin) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await ReportsApi.instance.loadSummary(
        year: _annualMode ? _selectedYear : _selectedMonth.year,
        month: _annualMode ? null : _selectedMonth.month,
        annual: _annualMode,
      );
      setState(() => _data = data);
    } catch (e) {
      setState(() => _errorMessage = 'Failed to load reports: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<ReportRankItem> _filteredRank(List<ReportRankItem> items) {
    if (_searchQuery.isEmpty) return items;
    return items
        .where((e) => e.name.toLowerCase().contains(_searchQuery))
        .toList();
  }

  Future<void> _previewPdf() async {
    final data = _data;
    if (data == null) return;

    setState(() => _exportingPdf = true);
    try {
      final scopeLabel = switch (_scope) {
        _ReportScope.catering => 'catering',
        _ReportScope.cateringEvents => 'catering+events',
        _ReportScope.restaurant => 'restaurant',
        _ => 'combined',
      };
      await previewOperationsReportPdf(
        data: data,
        scope: scopeLabel,
        annual: _annualMode,
        year: _annualMode ? _selectedYear : _selectedMonth.year,
        month: _annualMode ? null : _selectedMonth.month,
      );
      if (!mounted) return;
      showAntdMessage(
        context,
        'PDF preview opened.',
        type: AntdMessageType.success,
      );
    } catch (e) {
      if (!mounted) return;
      showAntdMessage(
        context,
        'Could not generate PDF: $e',
        type: AntdMessageType.error,
      );
    } finally {
      if (mounted) setState(() => _exportingPdf = false);
    }
  }

  Widget _rankTable(String title, List<ReportRankItem> items) {
    final filtered = _filteredRank(items);
    if (filtered.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Text(
          '$title: no data for this period.',
          style: TextStyle(color: Colors.grey.shade600),
        ),
      );
    }

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AntdTokens.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            PagedDataTable(
              title: '',
              columns: const [
                DataColumn(label: Text('Name')),
                DataColumn(label: Text('Count')),
              ],
              rows: [
                for (final e in filtered)
                  DataRow(
                    cells: [
                      DataCell(Text(e.name)),
                      DataCell(Text('${e.count}')),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryTable(String title, List<_DetailRow> rows) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AntdTokens.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final table = Table(
                  columnWidths: const {
                    0: FlexColumnWidth(2),
                    1: FlexColumnWidth(3),
                  },
                  border: TableBorder.all(color: AntdTokens.borderSubtle),
                  children: [
                    const TableRow(
                      decoration: BoxDecoration(color: Color(0xFFF5F7F9)),
                      children: [
                        Padding(
                          padding: EdgeInsets.all(8),
                          child: Text(
                            'Metric',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.all(8),
                          child: Text(
                            'Value',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    for (final row in rows)
                      TableRow(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text(row.label),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text(
                              row.value,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                  ],
                );
                if (constraints.maxWidth < 360) {
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 360),
                      child: table,
                    ),
                  );
                }
                return table;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _rankChart(String title, List<ReportRankItem> items) {
    final filtered = _filteredRank(items).take(8).toList();
    final max = filtered.fold<int>(1, (m, e) => e.count > m ? e.count : m);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AntdTokens.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            if (filtered.isEmpty)
              Text(
                'No chart data.',
                style: TextStyle(color: Colors.grey.shade600),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final labelWidth =
                      constraints.maxWidth < 420 ? 96.0 : 160.0;
                  return Column(
                    children: [
                      for (final item in filtered)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              SizedBox(
                                width: labelWidth,
                                child: Text(
                                  item.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(999),
                                  child: LinearProgressIndicator(
                                    minHeight: 10,
                                    value: item.count / max,
                                    backgroundColor: Colors.grey.shade200,
                                    color: AntdTokens.blue,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 36,
                                child: Text(
                                  '${item.count}',
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final periodLabel =
        _annualMode
            ? 'Year $_selectedYear'
            : '${_selectedMonth.month.toString().padLeft(2, '0')} / ${_selectedMonth.year}';

    return AppScaffold(
      showSearch: false,
      child: AntdPage(
        title: 'Reports',
        subtitle: "Macrina's Kitchen and Catering — operations reports.",
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        actions: [
          AntdPrimaryButton(
            label: 'Preview / Print PDF',
            icon: Icons.picture_as_pdf,
            loading: _exportingPdf,
            onPressed: _exportingPdf || data == null ? null : _previewPdf,
          ),
          AntdSecondaryButton(
            label: 'Refresh',
            icon: Icons.refresh,
            onPressed: _isLoading ? null : _load,
          ),
        ],
        child: LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 720;
            final selectWidth = narrow ? 140.0 : 180.0;
            final searchWidth = narrow
                ? constraints.maxWidth.clamp(180.0, 320.0)
                : 280.0;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AntdToolbar(
                  padding: EdgeInsets.symmetric(
                    horizontal: narrow ? 10 : 12,
                    vertical: 12,
                  ),
                  children: [
                    ChoiceChip(
                      label: const Text('Monthly'),
                      selected: !_annualMode,
                      onSelected: (_) {
                        setState(() => _annualMode = false);
                        _load();
                      },
                    ),
                    ChoiceChip(
                      label: const Text('Annual'),
                      selected: _annualMode,
                      onSelected: (_) {
                        setState(() => _annualMode = true);
                        _load();
                      },
                    ),
                    if (_annualMode)
                      AntdSelect<int>(
                        label: 'Year',
                        width: selectWidth,
                        value: _selectedYear,
                        items: List.generate(6, (i) {
                          final y = DateTime.now().year - i;
                          return DropdownMenuItem(value: y, child: Text('$y'));
                        }),
                        onChanged: (y) {
                          if (y == null) return;
                          setState(() => _selectedYear = y);
                          _load();
                        },
                      )
                    else ...[
                      AntdSelect<int>(
                        label: 'Year',
                        width: selectWidth,
                        value: _selectedMonth.year,
                        items: List.generate(6, (i) {
                          final y = DateTime.now().year - i;
                          return DropdownMenuItem(value: y, child: Text('$y'));
                        }),
                        onChanged: (y) {
                          if (y == null) return;
                          setState(() {
                            _selectedMonth =
                                DateTime(y, _selectedMonth.month, 1);
                          });
                          _load();
                        },
                      ),
                      AntdSelect<int>(
                        label: 'Month',
                        width: narrow ? 110.0 : 140.0,
                        value: _selectedMonth.month,
                        items: List.generate(12, (i) {
                          final m = i + 1;
                          return DropdownMenuItem(
                            value: m,
                            child: Text(m.toString().padLeft(2, '0')),
                          );
                        }),
                        onChanged: (m) {
                          if (m == null) return;
                          setState(() {
                            _selectedMonth =
                                DateTime(_selectedMonth.year, m, 1);
                          });
                          _load();
                        },
                      ),
                    ],
                    AntdSelect<_ReportScope>(
                      label: 'Scope',
                      width: narrow ? 160.0 : 200.0,
                      value: _scope,
                      items: const [
                        DropdownMenuItem(
                          value: _ReportScope.combined,
                          child: Text('All'),
                        ),
                        DropdownMenuItem(
                          value: _ReportScope.catering,
                          child: Text('Catering'),
                        ),
                        DropdownMenuItem(
                          value: _ReportScope.cateringEvents,
                          child: Text('Catering + Events'),
                        ),
                        DropdownMenuItem(
                          value: _ReportScope.restaurant,
                          child: Text('Restaurant'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => _scope = v);
                      },
                    ),
                    AntdSearchInput(
                      controller: _searchController,
                      width: searchWidth,
                      hintText: 'Search report tables',
                      onChanged:
                          (v) => setState(
                            () => _searchQuery = v.trim().toLowerCase(),
                          ),
                      onClear: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    ),
                    AntdStatusTag(label: periodLabel, color: AntdTokens.blue),
                  ],
                ),
                const SizedBox(height: 16),
                if (_isLoading)
                  const Expanded(
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_errorMessage != null)
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _errorMessage!,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            AntdPrimaryButton(label: 'Retry', onPressed: _load),
                          ],
                        ),
                      ),
                    ),
                  )
                else if (data == null)
                  const Expanded(
                    child: Center(child: Text('No report data.')),
                  )
                else
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.only(bottom: narrow ? 8 : 16),
                      children: [
                        if (_scope == _ReportScope.combined ||
                            _scope == _ReportScope.catering) ...[
                          const Text(
                            'Catering',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _summaryTable('Catering Summary', [
                            _DetailRow(
                              'Completed orders',
                              '${data.catering.orderCount}',
                            ),
                            _DetailRow(
                              'Total sales',
                              formatPhp(data.catering.totalSales),
                            ),
                            _DetailRow(
                              'Average guest count',
                              data.catering.averageGuestCount
                                  .toStringAsFixed(1),
                            ),
                            _DetailRow(
                              'Catering feedback complaints',
                              '${data.catering.feedback.complaintCount}',
                            ),
                            _DetailRow(
                              'Orders with complaints',
                              '${data.catering.feedback.count}',
                            ),
                          ]),
                          _rankChart(
                            'Top requested dishes chart',
                            data.catering.topDishes,
                          ),
                          _rankTable(
                            'Top requested dishes',
                            data.catering.topDishes,
                          ),
                        ],
                        if (_scope == _ReportScope.combined ||
                            _scope == _ReportScope.cateringEvents) ...[
                          const SizedBox(height: 8),
                          const Text(
                            'Catering + Events',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _summaryTable('Catering + Events Summary', [
                            _DetailRow(
                              'Completed orders',
                              '${data.cateringEvents.orderCount}',
                            ),
                            _DetailRow(
                              'Total sales',
                              formatPhp(data.cateringEvents.totalSales),
                            ),
                            _DetailRow(
                              'Average guest count',
                              data.cateringEvents.averageGuestCount
                                  .toStringAsFixed(1),
                            ),
                            _DetailRow(
                              'Feedback complaints',
                              '${data.cateringEvents.feedback.complaintCount}',
                            ),
                            _DetailRow(
                              'Events with complaints',
                              '${data.cateringEvents.feedback.count}',
                            ),
                          ]),
                          _rankChart(
                            'Event type chart',
                            data.cateringEvents.topEventTypes,
                          ),
                          _rankTable(
                            'Most frequent event type',
                            data.cateringEvents.topEventTypes,
                          ),
                          _rankChart(
                            'Top requested dishes chart',
                            data.cateringEvents.topDishes,
                          ),
                          _rankTable(
                            'Top requested dishes',
                            data.cateringEvents.topDishes,
                          ),
                        ],
                        if (_scope == _ReportScope.combined ||
                            _scope == _ReportScope.restaurant) ...[
                          const SizedBox(height: 8),
                          const Text(
                            'Restaurant',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _summaryTable('Restaurant Summary', [
                            _DetailRow(
                              'Orders',
                              '${data.restaurant.orderCount}',
                            ),
                            _DetailRow(
                              'Total sales',
                              formatPhp(data.restaurant.totalSales),
                            ),
                            _DetailRow(
                              'Avg. orders per day',
                              data.restaurant.averageOrdersPerDay
                                  .toStringAsFixed(2),
                            ),
                            _DetailRow(
                              'Web page views',
                              '${data.restaurant.webPageViews}',
                            ),
                            _DetailRow(
                              'Mobile page views',
                              '${data.restaurant.mobilePageViews}',
                            ),
                            _DetailRow(
                              'Customer accounts (web)',
                              '${data.restaurant.customerAccountsWeb}',
                            ),
                            _DetailRow(
                              'Customer accounts (mobile)',
                              '${data.restaurant.customerAccountsMobile}',
                            ),
                            _DetailRow(
                              'Feedback submissions',
                              '${data.restaurant.feedback.count}',
                            ),
                            _DetailRow(
                              'Average feedback rating',
                              '${data.restaurant.feedback.averageStars.toStringAsFixed(1)} / 5',
                            ),
                            _DetailRow(
                              'Positive / Neutral / Negative',
                              '${data.restaurant.feedback.positiveCount} / ${data.restaurant.feedback.neutralCount} / ${data.restaurant.feedback.negativeCount}',
                            ),
                          ]),
                          _rankChart(
                            'Most ordered dishes chart',
                            data.restaurant.topDishes,
                          ),
                          _rankTable(
                            'Most ordered dishes',
                            data.restaurant.topDishes,
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
