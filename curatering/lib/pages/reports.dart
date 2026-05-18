import 'package:flutter/material.dart';

import '../auth/auth_session.dart';
import '../auth/roles.dart';
import '../services/reports_api.dart';
import '../services/reports_pdf_service.dart';
import '../utils/order_calculations.dart';
import '../widgets/antd_buttons.dart';
import '../widgets/antd_message.dart';
import '../widgets/antd_tokens.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/paginated_data_table.dart';

enum _ReportScope { catering, restaurant, combined }

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

  Future<void> _downloadPdf() async {
    final data = _data;
    if (data == null) return;

    setState(() => _exportingPdf = true);
    try {
      final scopeLabel = switch (_scope) {
        _ReportScope.catering => 'catering',
        _ReportScope.restaurant => 'restaurant',
        _ => 'combined',
      };
      await downloadOperationsReportPdf(
        data: data,
        scope: scopeLabel,
        annual: _annualMode,
        year: _annualMode ? _selectedYear : _selectedMonth.year,
        month: _annualMode ? null : _selectedMonth.month,
      );
      if (!mounted) return;
      showAntdMessage(
        context,
        'PDF download started.',
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

  Widget _summaryLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: const TextStyle(color: AntdTokens.labelMuted)),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final periodLabel = _annualMode
        ? 'Year $_selectedYear'
        : '${_selectedMonth.month.toString().padLeft(2, '0')} / ${_selectedMonth.year}';

    return AppScaffold(
      showSearch: true,
      searchController: _searchController,
      onSearchChanged: (v) =>
          setState(() => _searchQuery = v.trim().toLowerCase()),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reports',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "Macrina's Kitchen and Catering — operations reports.",
                        style: TextStyle(color: AntdTokens.labelMuted),
                      ),
                    ],
                  ),
                ),
                AntdPrimaryButton(
                  label: 'Download PDF',
                  loading: _exportingPdf,
                  onPressed: _exportingPdf || data == null ? null : _downloadPdf,
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: _isLoading ? null : _load,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilterChip(
                  label: const Text('Monthly'),
                  selected: !_annualMode,
                  onSelected: (_) => setState(() => _annualMode = false),
                ),
                FilterChip(
                  label: const Text('Annual'),
                  selected: _annualMode,
                  onSelected: (_) => setState(() => _annualMode = true),
                ),
                if (_annualMode)
                  DropdownButton<int>(
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
                else
                  DropdownButton<int>(
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
                        _selectedMonth = DateTime(
                          _selectedMonth.year,
                          m,
                          1,
                        );
                      });
                      _load();
                    },
                  ),
                DropdownButton<_ReportScope>(
                  value: _scope,
                  items: const [
                    DropdownMenuItem(
                      value: _ReportScope.combined,
                      child: Text('All'),
                    ),
                    DropdownMenuItem(
                      value: _ReportScope.catering,
                      child: Text('Catering / Events'),
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
                Text(
                  periodLabel,
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_errorMessage != null)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_errorMessage!),
                      const SizedBox(height: 12),
                      AntdPrimaryButton(label: 'Retry', onPressed: _load),
                    ],
                  ),
                ),
              )
            else if (data == null)
              const Expanded(child: Center(child: Text('No report data.')))
            else
              Expanded(
                child: ListView(
                  children: [
                    if (_scope != _ReportScope.restaurant) ...[
                      const Text(
                        'Catering / Events',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Summary',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 8),
                              _summaryLine(
                                'Completed orders',
                                '${data.catering.orderCount}',
                              ),
                              _summaryLine(
                                'Total sales',
                                formatPhp(data.catering.totalSales),
                              ),
                              _summaryLine(
                                'Average guest count',
                                data.catering.averageGuestCount
                                    .toStringAsFixed(1),
                              ),
                            ],
                          ),
                        ),
                      ),
                      _rankTable(
                        'Top requested dishes',
                        data.catering.topDishes,
                      ),
                      _rankTable(
                        'Most frequent event type',
                        data.catering.topEventTypes,
                      ),
                    ],
                    if (_scope != _ReportScope.catering) ...[
                      const Text(
                        'Restaurant',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Summary',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 8),
                              _summaryLine(
                                'Orders',
                                '${data.restaurant.orderCount}',
                              ),
                              _summaryLine(
                                'Total sales',
                                formatPhp(data.restaurant.totalSales),
                              ),
                              _summaryLine(
                                'Avg. orders per day',
                                data.restaurant.averageOrdersPerDay
                                    .toStringAsFixed(2),
                              ),
                              _summaryLine(
                                'Web page views',
                                '${data.restaurant.webPageViews}',
                              ),
                              _summaryLine(
                                'Mobile page views',
                                '${data.restaurant.mobilePageViews}',
                              ),
                              _summaryLine(
                                'Customer accounts (web)',
                                '${data.restaurant.customerAccountsWeb}',
                              ),
                              _summaryLine(
                                'Customer accounts (mobile)',
                                '${data.restaurant.customerAccountsMobile}',
                              ),
                            ],
                          ),
                        ),
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
        ),
      ),
    );
  }
}
