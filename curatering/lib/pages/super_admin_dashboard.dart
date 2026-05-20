import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../services/super_admin_api.dart';
import '../utils/order_calculations.dart';
import '../widgets/antd_buttons.dart';
import '../widgets/antd_message.dart';
import '../widgets/antd_staff.dart';
import '../widgets/antd_tokens.dart';
import '../widgets/app_scaffold.dart';

class SuperAdminDashboardPage extends StatefulWidget {
  const SuperAdminDashboardPage({super.key});

  @override
  State<SuperAdminDashboardPage> createState() =>
      _SuperAdminDashboardPageState();
}

class _SuperAdminDashboardPageState extends State<SuperAdminDashboardPage> {
  final _searchController = TextEditingController();
  final _todoTitleController = TextEditingController();
  final _todoNotesController = TextEditingController();
  SuperAdminDashboardSummary? _summary;
  List<SuperAdminTodoDto> _todos = const [];
  bool _loading = true;
  bool _savingTodo = false;
  bool _printingPdf = false;
  String? _error;
  String _dashboardSearch = '';
  String _rangeFilter = '30d';
  String _sectionFilter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _todoTitleController.dispose();
    _todoNotesController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        SuperAdminApi.instance.getDashboardSummary(range: _rangeFilter),
        SuperAdminApi.instance.listTodos(),
      ]);
      if (!mounted) return;
      setState(() {
        _summary = results[0] as SuperAdminDashboardSummary;
        _todos = results[1] as List<SuperAdminTodoDto>;
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'Failed to load dashboard: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addTodo() async {
    final title = _todoTitleController.text.trim();
    if (title.isEmpty) return;
    setState(() => _savingTodo = true);
    try {
      final todo = await SuperAdminApi.instance.createTodo(
        title: title,
        notes: _todoNotesController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _todos = [todo, ..._todos];
        _todoTitleController.clear();
        _todoNotesController.clear();
      });
    } catch (e) {
      if (mounted) {
        showAntdMessage(
          context,
          'Failed to add to-do.',
          type: AntdMessageType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _savingTodo = false);
    }
  }

  Future<void> _toggleTodo(SuperAdminTodoDto todo, bool completed) async {
    try {
      final updated = await SuperAdminApi.instance.updateTodo(
        todoId: todo.id,
        completed: completed,
      );
      if (!mounted) return;
      setState(() {
        _todos =
            _todos
                .map((item) => item.id == updated.id ? updated : item)
                .toList();
      });
    } catch (_) {
      if (mounted) {
        showAntdMessage(
          context,
          'Failed to update to-do.',
          type: AntdMessageType.error,
        );
      }
    }
  }

  Future<void> _deleteTodo(SuperAdminTodoDto todo) async {
    try {
      await SuperAdminApi.instance.deleteTodo(todoId: todo.id);
      if (!mounted) return;
      setState(
        () => _todos = _todos.where((item) => item.id != todo.id).toList(),
      );
    } catch (_) {
      if (mounted) {
        showAntdMessage(
          context,
          'Failed to delete to-do.',
          type: AntdMessageType.error,
        );
      }
    }
  }

  Future<void> _printDashboardPdf() async {
    final summary = _summary;
    if (summary == null || _printingPdf) return;
    setState(() => _printingPdf = true);
    try {
      final doc = pw.Document(title: 'Super Admin Dashboard');
      final generatedAt = DateTime.now();
      pw.Widget metric(String label, String value) {
        return pw.Container(
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(label, style: const pw.TextStyle(fontSize: 8)),
              pw.SizedBox(height: 3),
              pw.Text(
                value,
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      }

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
              (_) => [
                pw.Text(
                  'Super Admin Dashboard',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Generated ${generatedAt.toLocal()} · Range: $_rangeLabel',
                  style: const pw.TextStyle(fontSize: 9),
                ),
                pw.SizedBox(height: 14),
                pw.Text(
                  'Analytics section',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 8),
                pw.GridView(
                  crossAxisCount: 4,
                  childAspectRatio: 3.4,
                  children: [
                    metric(
                      'Website views',
                      '${summary.analytics.website.totalViews}',
                    ),
                    metric(
                      'Views in range',
                      '${summary.analytics.website.last30Views}',
                    ),
                    metric(
                      'Average feedback',
                      summary.analytics.feedback.averageStars == null
                          ? 'n/a'
                          : summary.analytics.feedback.averageStars!
                              .toStringAsFixed(1),
                    ),
                    metric(
                      'Open help requests',
                      '${summary.analytics.helpRequests.unresolved}',
                    ),
                  ],
                ),
                pw.SizedBox(height: 14),
                pw.Text(
                  'User Management section',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 8),
                pw.GridView(
                  crossAxisCount: 4,
                  childAspectRatio: 3.4,
                  children: [
                    metric(
                      'Staff accounts',
                      '${summary.userManagement.staff.total}',
                    ),
                    metric(
                      'Active staff',
                      '${summary.userManagement.staff.active}',
                    ),
                    metric(
                      'Archived staff',
                      '${summary.userManagement.staff.archived}',
                    ),
                    metric(
                      'Customer accounts',
                      '${summary.userManagement.customers.total}',
                    ),
                  ],
                ),
                pw.SizedBox(height: 14),
                pw.Text(
                  'Sales section',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 8),
                pw.GridView(
                  crossAxisCount: 4,
                  childAspectRatio: 3.4,
                  children: [
                    metric(
                      'Combined total',
                      formatPesos(summary.sales.combined.totalSales),
                    ),
                    metric(
                      'This month',
                      formatPesos(summary.sales.combined.monthSales),
                    ),
                    metric('Total orders', '${summary.sales.combined.orders}'),
                    metric(
                      'Pending / active',
                      '${summary.sales.combined.pending}',
                    ),
                  ],
                ),
              ],
        ),
      );

      await Printing.layoutPdf(
        onLayout: (_) => doc.save(),
        name: 'super_admin_dashboard.pdf',
      );
    } finally {
      if (mounted) setState(() => _printingPdf = false);
    }
  }

  String _fmtDate(DateTime? value) {
    if (value == null) return 'n/a';
    final local = value.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
  }

  Widget _metricCard(
    String label,
    String value, {
    IconData icon = Icons.insights,
    Color color = AntdTokens.blue,
  }) {
    return AntdCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AntdTokens.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: AntdTokens.valueDark,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricGrid(List<Widget> cards) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final itemWidth =
            width >= 1100
                ? (width - 36) / 4
                : width >= 760
                ? (width - 24) / 3
                : width >= 520
                ? (width - 12) / 2
                : width;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children:
              cards
                  .map((card) => SizedBox(width: itemWidth, child: card))
                  .toList(),
        );
      },
    );
  }

  Widget _section(String title, String subtitle, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AntdPageHeader(title: title, subtitle: subtitle),
        const SizedBox(height: 12),
        ...children,
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _barList({
    required String title,
    required List<Map<String, dynamic>> items,
    required String labelKey,
    required String valueKey,
  }) {
    final max = items.fold<int>(
      1,
      (current, item) =>
          (_num(item[valueKey]) > current) ? _num(item[valueKey]) : current,
    );
    return AntdCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          if (items.isEmpty)
            const Text(
              'No data yet.',
              style: TextStyle(color: AntdTokens.labelMuted),
            )
          else
            for (final item in items.take(8))
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    SizedBox(
                      width: 140,
                      child: Text(
                        '${item[labelKey] ?? ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: (_num(item[valueKey]) / max).clamp(0, 1),
                          minHeight: 8,
                          backgroundColor: AntdTokens.fillTertiary,
                          color: AntdTokens.brandPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 54,
                      child: Text(
                        '${_num(item[valueKey])}',
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  int _num(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }

  String get _rangeLabel {
    return switch (_rangeFilter) {
      'today' => 'Today',
      '7d' => 'Last 7 days',
      '30d' => 'Last 30 days',
      '90d' => 'Last 90 days',
      'year' => 'This year',
      'all' => 'All time',
      _ => 'Last 30 days',
    };
  }

  bool _matchesDashboardSearch(String text) {
    final q = _dashboardSearch.trim().toLowerCase();
    return q.isEmpty || text.toLowerCase().contains(q);
  }

  bool _showSection(String section, String keywords) {
    final allowed = _sectionFilter == 'all' || _sectionFilter == section;
    return allowed && _matchesDashboardSearch(keywords);
  }

  List<Map<String, dynamic>> _filteredMapItems(
    List<Map<String, dynamic>> items,
  ) {
    final q = _dashboardSearch.trim().toLowerCase();
    if (q.isEmpty) return items;
    return items.where((item) {
      return item.values.any((value) => '$value'.toLowerCase().contains(q));
    }).toList();
  }

  List<SuperAdminActivityItem> _filteredActivities(
    List<SuperAdminActivityItem> items,
  ) {
    final q = _dashboardSearch.trim().toLowerCase();
    if (q.isEmpty) return items;
    return items.where((item) {
      return [
        item.userName,
        item.feature,
        item.action,
        item.problem,
        item.status,
      ].any((value) => value.toLowerCase().contains(q));
    }).toList();
  }

  List<SuperAdminTodoDto> get _filteredTodos {
    final q = _dashboardSearch.trim().toLowerCase();
    if (q.isEmpty) return _todos;
    return _todos.where((todo) {
      return '${todo.title} ${todo.notes}'.toLowerCase().contains(q);
    }).toList();
  }

  Widget _filterToolbar() {
    return AntdToolbar(
      children: [
        AntdSelect<String>(
          label: 'Dashboard range',
          value: _rangeFilter,
          items: const [
            DropdownMenuItem(value: 'today', child: Text('Today')),
            DropdownMenuItem(value: '7d', child: Text('Last 7 days')),
            DropdownMenuItem(value: '30d', child: Text('Last 30 days')),
            DropdownMenuItem(value: '90d', child: Text('Last 90 days')),
            DropdownMenuItem(value: 'year', child: Text('This year')),
            DropdownMenuItem(value: 'all', child: Text('All time')),
          ],
          onChanged: (value) {
            if (value == null) return;
            setState(() => _rangeFilter = value);
            _load();
          },
        ),
        AntdSelect<String>(
          label: 'Section',
          value: _sectionFilter,
          items: const [
            DropdownMenuItem(value: 'all', child: Text('All sections')),
            DropdownMenuItem(value: 'analytics', child: Text('Analytics')),
            DropdownMenuItem(value: 'users', child: Text('User Management')),
            DropdownMenuItem(value: 'sales', child: Text('Sales')),
            DropdownMenuItem(value: 'todos', child: Text('To-do list')),
          ],
          onChanged: (value) {
            if (value == null) return;
            setState(() => _sectionFilter = value);
          },
        ),
        AntdStatusTag(label: _rangeLabel, color: AntdTokens.blue),
        if (_dashboardSearch.isNotEmpty || _sectionFilter != 'all')
          AntdSecondaryButton(
            label: 'Clear filters',
            icon: Icons.filter_alt_off,
            onPressed: () {
              _searchController.clear();
              setState(() {
                _dashboardSearch = '';
                _sectionFilter = 'all';
              });
            },
          ),
      ],
    );
  }

  Widget _activityList(String title, List<SuperAdminActivityItem> items) {
    return AntdCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          if (items.isEmpty)
            const Text('No recent activity.')
          else
            for (final item in items.take(6))
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  item.action.isNotEmpty ? item.action : item.problem,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${item.userName} · ${item.feature.isEmpty ? item.status : item.feature}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Text(
                  _fmtDate(item.createdAt),
                  style: const TextStyle(
                    color: AntdTokens.labelMuted,
                    fontSize: 11,
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _todoCard() {
    final todos = _filteredTodos;
    final open = todos.where((todo) => !todo.completed).length;
    return AntdCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Custom To-do List',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
              AntdStatusTag(label: '$open open', color: AntdTokens.warning),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              AntdSearchInput(
                controller: _todoTitleController,
                hintText: 'New to-do title',
                width: 260,
                onChanged: (_) => setState(() {}),
                onClear: () {
                  _todoTitleController.clear();
                  setState(() {});
                },
              ),
              SizedBox(
                width: 280,
                child: TextField(
                  controller: _todoNotesController,
                  decoration: const InputDecoration(
                    hintText: 'Notes (optional)',
                    isDense: true,
                  ),
                ),
              ),
              AntdPrimaryButton(
                label: 'Add',
                icon: Icons.add,
                loading: _savingTodo,
                onPressed:
                    _todoTitleController.text.trim().isEmpty ? null : _addTodo,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (todos.isEmpty)
            const AntdEmptyState(message: 'No to-dos yet.')
          else
            for (final todo in todos)
              CheckboxListTile(
                value: todo.completed,
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(
                  todo.title,
                  style: TextStyle(
                    decoration:
                        todo.completed ? TextDecoration.lineThrough : null,
                  ),
                ),
                subtitle: todo.notes.isEmpty ? null : Text(todo.notes),
                secondary: IconButton(
                  tooltip: 'Delete',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _deleteTodo(todo),
                ),
                onChanged: (value) => _toggleTodo(todo, value == true),
              ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;
    final showAnalytics = _showSection(
      'analytics',
      'analytics website views platform paths feedback help requests activity action logs',
    );
    final showUsers = _showSection(
      'users',
      'user management staff customers accounts role active archived help requests',
    );
    final showSales = _showSection(
      'sales',
      'sales revenue restaurant catering events orders completed pending financial',
    );
    final showTodos = _showSection(
      'todos',
      'todo to-do tasks custom list completed open notes',
    );
    return AppScaffold(
      showSearch: true,
      searchController: _searchController,
      searchHint: 'Search super admin dashboard',
      onSearchChanged:
          (value) =>
              setState(() => _dashboardSearch = value.trim().toLowerCase()),
      child: AntdPage(
        title: 'Super Admin Dashboard',
        subtitle: 'Analytics, user operations, sales health, and admin tasks.',
        actions: [
          AntdSecondaryButton(
            label: 'Refresh',
            icon: Icons.refresh,
            onPressed: _loading ? null : _load,
          ),
          AntdSecondaryButton(
            label: _printingPdf ? 'Preparing PDF' : 'Print PDF',
            icon: Icons.picture_as_pdf,
            onPressed:
                _summary == null || _printingPdf ? null : _printDashboardPdf,
          ),
        ],
        child:
            _loading
                ? const AntdLoadingState(
                  message: 'Loading super admin dashboard...',
                )
                : _error != null
                ? AntdEmptyState(message: _error!)
                : summary == null
                ? const AntdEmptyState(message: 'No dashboard data found.')
                : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _filterToolbar(),
                      const SizedBox(height: 16),
                      if (!showAnalytics &&
                          !showUsers &&
                          !showSales &&
                          !showTodos)
                        const AntdEmptyState(
                          message:
                              'No dashboard sections match the current filters.',
                        ),
                      if (showAnalytics)
                        _section(
                          'Analytics section',
                          'Website, feedback, help request, and activity analytics.',
                          [
                            _metricGrid([
                              _metricCard(
                                'Website views',
                                '${summary.analytics.website.totalViews}',
                                icon: Icons.public,
                              ),
                              _metricCard(
                                'Views in range',
                                '${summary.analytics.website.last30Views}',
                                icon: Icons.trending_up,
                                color: AntdTokens.success,
                              ),
                              _metricCard(
                                'Average feedback',
                                summary.analytics.feedback.averageStars == null
                                    ? 'n/a'
                                    : summary.analytics.feedback.averageStars!
                                        .toStringAsFixed(1),
                                icon: Icons.star,
                                color: AntdTokens.warning,
                              ),
                              _metricCard(
                                'Open help requests',
                                '${summary.analytics.helpRequests.unresolved}',
                                icon: Icons.help_outline,
                                color:
                                    summary.analytics.helpRequests.unresolved >
                                            0
                                        ? AntdTokens.error
                                        : AntdTokens.success,
                              ),
                            ]),
                            const SizedBox(height: 12),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final wide = constraints.maxWidth >= 900;
                                final width =
                                    wide
                                        ? (constraints.maxWidth - 12) / 2
                                        : constraints.maxWidth;
                                return Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: [
                                    SizedBox(
                                      width: width,
                                      child: _barList(
                                        title: 'Top website paths',
                                        items: _filteredMapItems(
                                          summary.analytics.website.topPaths,
                                        ),
                                        labelKey: 'path',
                                        valueKey: 'views',
                                      ),
                                    ),
                                    SizedBox(
                                      width: width,
                                      child: _activityList(
                                        'Recent action logs',
                                        _filteredActivities(
                                          summary.analytics.recentActions,
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      if (showUsers)
                        _section(
                          'User Management section',
                          'Staff and customer account status at a glance.',
                          [
                            _metricGrid([
                              _metricCard(
                                'Staff accounts',
                                '${summary.userManagement.staff.total}',
                                icon: Icons.badge_outlined,
                              ),
                              _metricCard(
                                'Active staff',
                                '${summary.userManagement.staff.active}',
                                icon: Icons.verified_user_outlined,
                                color: AntdTokens.success,
                              ),
                              _metricCard(
                                'Archived staff',
                                '${summary.userManagement.staff.archived}',
                                icon: Icons.archive_outlined,
                                color: AntdTokens.warning,
                              ),
                              _metricCard(
                                'Customer accounts',
                                '${summary.userManagement.customers.total}',
                                icon: Icons.people_outline,
                              ),
                            ]),
                            const SizedBox(height: 12),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final wide = constraints.maxWidth >= 900;
                                final width =
                                    wide
                                        ? (constraints.maxWidth - 12) / 2
                                        : constraints.maxWidth;
                                final roleItems =
                                    summary
                                        .userManagement
                                        .staff
                                        .roleCounts
                                        .entries
                                        .map(
                                          (entry) => {
                                            'role': entry.key,
                                            'count': entry.value,
                                          },
                                        )
                                        .toList();
                                return Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: [
                                    SizedBox(
                                      width: width,
                                      child: _barList(
                                        title: 'Staff by role',
                                        items: _filteredMapItems(roleItems),
                                        labelKey: 'role',
                                        valueKey: 'count',
                                      ),
                                    ),
                                    SizedBox(
                                      width: width,
                                      child: _activityList(
                                        'Recent help requests',
                                        _filteredActivities(
                                          summary.analytics.recentHelpRequests,
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      if (showSales)
                        _section(
                          'Sales section',
                          'Restaurant, catering, event, and combined financial figures.',
                          [
                            _metricGrid([
                              _metricCard(
                                'Combined total',
                                formatPesos(summary.sales.combined.totalSales),
                                icon: Icons.payments_outlined,
                                color: AntdTokens.success,
                              ),
                              _metricCard(
                                'This month',
                                formatPesos(summary.sales.combined.monthSales),
                                icon: Icons.calendar_month,
                              ),
                              _metricCard(
                                'Restaurant sales',
                                formatPesos(
                                  summary.sales.restaurant.totalSales,
                                ),
                                icon: Icons.restaurant,
                              ),
                              _metricCard(
                                'Catering + events',
                                formatPesos(
                                  summary.sales.catering.totalSales +
                                      summary.sales.events.totalSales,
                                ),
                                icon: Icons.event_available,
                              ),
                            ]),
                            const SizedBox(height: 12),
                            _metricGrid([
                              _metricCard(
                                'Total orders',
                                '${summary.sales.combined.orders}',
                                icon: Icons.receipt_long,
                              ),
                              _metricCard(
                                'Completed',
                                '${summary.sales.combined.completed}',
                                icon: Icons.check_circle_outline,
                                color: AntdTokens.success,
                              ),
                              _metricCard(
                                'Pending / active',
                                '${summary.sales.combined.pending}',
                                icon: Icons.pending_actions,
                                color: AntdTokens.warning,
                              ),
                              _metricCard(
                                'Year sales',
                                formatPesos(summary.sales.combined.yearSales),
                                icon: Icons.show_chart,
                              ),
                            ]),
                          ],
                        ),
                      if (showTodos) _todoCard(),
                    ],
                  ),
                ),
      ),
    );
  }
}
