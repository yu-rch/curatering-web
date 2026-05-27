import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../auth/auth_session.dart';
import '../services/dashboard_api.dart';
import '../utils/order_calculations.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/antd_tokens.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  static const bool _showAiHealthPanel = false;
  static const bool _showDishTrendsPanel = false;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _insightPromptController = TextEditingController(
    text:
        'Analyze current restaurant and catering feedback, identify urgent issues, explain trends, and recommend specific actions for management.',
  );
  bool _isLoading = false;
  bool _isPrintingPdf = false;
  Timer? _autoRefreshTimer;
  DateTime? _lastRefreshAt;
  String? _errorMessage;
  String? _insightError;
  String? _dishTrendError;
  String? _healthError;
  DashboardSummary? _summary;
  DashboardAiAnalysis? _insight;
  DishTrendsResult? _dishTrends;
  AiHealthStatus? _aiHealth;
  AiTaskState _insightState = AiTaskState.idle;
  AiTaskState _dishTrendState = AiTaskState.idle;
  AiTaskState _healthState = AiTaskState.idle;
  String _range = '30d';
  String _orderSource = 'ALL';
  String _businessSide = 'ALL';
  String _cateringStyle = 'ALL';
  String _dashboardSearch = '';

  @override
  void initState() {
    super.initState();
    _load();
    _loadInsight();
    if (_showDishTrendsPanel) _loadDishTrends();
    if (_showAiHealthPanel) _loadAiHealth();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _searchController.dispose();
    _insightPromptController.dispose();
    super.dispose();
  }

  bool _isAiBusy(AiTaskState state) =>
      state == AiTaskState.queued || state == AiTaskState.processing;

  void _startAutoRefresh() {
    _autoRefreshTimer = Timer.periodic(
      const Duration(minutes: 10),
      (_) => _refreshDashboard(),
    );
  }

  Future<void> _refreshDashboard({bool force = false}) async {
    final now = DateTime.now();
    if (!force &&
        _lastRefreshAt != null &&
        now.difference(_lastRefreshAt!) < const Duration(seconds: 30)) {
      return;
    }
    _lastRefreshAt = now;
    await Future.wait([
      _load(forceRefresh: true),
      _loadInsight(),
      if (_showDishTrendsPanel) _loadDishTrends(),
      if (_showAiHealthPanel) _loadAiHealth(),
    ]);
  }

  Future<void> _load({bool forceRefresh = false}) async {
    if (!AuthSession.instance.hasToken) {
      if (mounted) {
        setState(() => _errorMessage = 'Please log in to view the dashboard.');
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final summary = await DashboardApi.instance.loadSummary(
        filters: _dashboardFilters,
      );
      if (mounted) setState(() => _summary = summary);
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage = 'Failed to load dashboard data.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String get _insightRange {
    switch (_range) {
      case '7d':
        return '7d';
      case '30d':
        return '30d';
      case '90d':
        return '90d';
      case 'year':
      case 'all':
      default:
        return _range == 'year' || _range == 'all' ? '90d' : _range;
    }
  }

  Future<void> _loadInsight() async {
    if (!AuthSession.instance.hasToken) return;
    setState(() {
      _insightState = AiTaskState.processing;
      _insightError = null;
    });
    try {
      final insight = await DashboardApi.instance.loadLatestInsight(
        range: _insightRange,
        filters: _dashboardFilters,
      );
      if (mounted) setState(() => _insight = insight);
    } catch (_) {
      if (mounted) {
        setState(() => _insightError = 'Failed to load AI insights.');
      }
    } finally {
      if (mounted) setState(() => _insightState = AiTaskState.idle);
    }
  }

  Future<void> _generateInsight() async {
    if (!AuthSession.instance.hasToken || _isAiBusy(_insightState)) return;
    setState(() {
      _insightState = AiTaskState.processing;
      _insightError = null;
    });
    try {
      final insight = await DashboardApi.instance.analyzeDashboard(
        range: _insightRange,
        prompt: _insightPromptController.text,
        dashboardData: _summary,
        filters: _dashboardFilters,
        onStateChanged:
            (state) => mounted ? setState(() => _insightState = state) : null,
      );
      if (mounted) {
        setState(() {
          _insight = insight;
          _insightState = AiTaskState.completed;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _insightState = AiTaskState.failed;
          _insightError =
              _insight == null
                  ? 'AI unavailable. No cached analysis is available yet.'
                  : 'AI unavailable. Showing the latest cached analysis.';
        });
      }
    }
  }

  Future<void> _loadDishTrends() async {
    if (!AuthSession.instance.hasToken || _isAiBusy(_dishTrendState)) return;
    setState(() {
      _dishTrendState = AiTaskState.processing;
      _dishTrendError = null;
    });
    try {
      final trends = await DashboardApi.instance.loadDishTrends(
        onStateChanged:
            (state) => mounted ? setState(() => _dishTrendState = state) : null,
      );
      if (mounted) {
        setState(() {
          _dishTrends = trends;
          _dishTrendState = AiTaskState.completed;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _dishTrendState = AiTaskState.failed;
          _dishTrendError = 'Failed to load dish trends.';
        });
      }
    }
  }

  Future<void> _loadAiHealth() async {
    if (!AuthSession.instance.hasToken || _isAiBusy(_healthState)) return;
    setState(() {
      _healthState = AiTaskState.processing;
      _healthError = null;
    });
    try {
      final health = await DashboardApi.instance.loadAiHealth(
        onStateChanged:
            (state) => mounted ? setState(() => _healthState = state) : null,
      );
      if (mounted) {
        setState(() {
          _aiHealth = health;
          _healthState = AiTaskState.completed;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _healthState = AiTaskState.failed;
          _healthError = 'Failed to load AI health.';
        });
      }
    }
  }

  DashboardFilters get _dashboardFilters {
    final now = DateTime.now();
    DateTime? start;
    DateTime? end;
    if (_range == '7d') {
      start = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(const Duration(days: 6));
      end = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    } else if (_range == '30d') {
      start = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(const Duration(days: 29));
      end = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    } else if (_range == '90d') {
      start = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(const Duration(days: 89));
      end = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    } else if (_range == 'year') {
      start = DateTime(now.year);
      end = DateTime(now.year + 1);
    }
    return DashboardFilters(
      start: start,
      end: end,
      aiRange: _insightRange,
      orderSource: _orderSource,
      businessSide: _businessSide,
      cateringStyle: _cateringStyle,
    );
  }

  Widget _filterBar() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _filterDropdown(
          value: _range,
          label: 'Range',
          items: const {
            '7d': 'Last 7 days',
            '30d': 'Last 30 days',
            '90d': 'Last 90 days',
            'year': 'This year',
            'all': 'All time',
          },
          onChanged: (v) {
            setState(() => _range = v);
            _refreshDashboard(force: true);
          },
        ),
        _filterDropdown(
          value: _businessSide,
          label: 'Business side',
          items: const {
            'ALL': 'All',
            'RESTAURANT': 'Restaurant only',
            'CATERING': 'Catering only',
            'CATERING_WITH_EVENT': 'Event packages only',
          },
          onChanged: (v) {
            setState(() => _businessSide = v);
            _refreshDashboard(force: true);
          },
        ),
        _filterDropdown(
          value: _cateringStyle,
          label: 'Catering style',
          items: const {
            'ALL': 'All catering',
            'CATERING_ONLY': 'Catering only',
            'CATERING_WITH_EVENT': 'Catering + event styling',
          },
          onChanged: (v) {
            setState(() => _cateringStyle = v);
            _refreshDashboard(force: true);
          },
        ),
        _filterDropdown(
          value: _orderSource,
          label: 'Source',
          items: const {
            'ALL': 'All sources',
            'ONLINE': 'Online only',
            'WALK_IN': 'Walk-in only',
            'WEB_APP': 'Web',
            'MOBILE_APP': 'Mobile',
            'POS_WEB': 'POS web',
          },
          onChanged: (v) {
            setState(() => _orderSource = v);
            _refreshDashboard(force: true);
          },
        ),
      ],
    );
  }

  Widget _filterDropdown({
    required String value,
    required String label,
    required Map<String, String> items,
    required ValueChanged<String> onChanged,
  }) {
    return SizedBox(
      width: 190,
      child: DropdownButtonFormField<String>(
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
        items: [
          for (final entry in items.entries)
            DropdownMenuItem(value: entry.key, child: Text(entry.value)),
        ],
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }

  Widget _metricCard(
    String title,
    String value,
    Color color, {
    String? subtitle,
    List<_DetailRow> details = const [],
    IconData? icon,
    String? routeName,
  }) {
    final hasDetails = details.isNotEmpty || subtitle != null;
    return SizedBox(
      width: 236,
      child: Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AntdTokens.borderSubtle),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap:
              routeName != null
                  ? () => Navigator.of(context).pushNamed(routeName)
                  : hasDetails
                  ? () => _showDashboardDetails(
                    title: title,
                    subtitle: subtitle,
                    details: details,
                  )
                  : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              height: 106,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          icon ?? Icons.analytics_outlined,
                          color: color,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      if (hasDetails)
                        Icon(
                          Icons.info_outline,
                          color: Colors.grey.shade500,
                          size: 16,
                        ),
                    ],
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      color: color,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (subtitle != null && subtitle.trim().isNotEmpty)
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AntdTokens.labelMuted,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Text(
        text,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _businessSection({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accent,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AntdTokens.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AntdTokens.valueDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: AntdTokens.labelMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _metricsRow(children),
          ],
        ),
      ),
    );
  }

  Widget _websiteAnalyticsCard() {
    return _dashboardCard(
      title: 'Website Analytics',
      subtitle: 'Vercel Analytics tracking status',
      details: const [
        _DetailRow('Provider', 'Vercel Analytics'),
        _DetailRow('Tracked surface', 'Customer website and public pages'),
        _DetailRow('Metric source', 'Vercel project dashboard'),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AntdTokens.blue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.query_stats, color: AntdTokens.blue),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tracking enabled',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AntdTokens.valueDark,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Visits and page views are collected by Vercel after deployment.',
                      style: TextStyle(
                        color: AntdTokens.labelMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _AnalyticsPill(label: 'Page views'),
              _AnalyticsPill(label: 'Visitors'),
              _AnalyticsPill(label: 'Referrers'),
              _AnalyticsPill(label: 'Top pages'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricsRow(List<Widget> children) {
    return Wrap(spacing: 12, runSpacing: 12, children: children);
  }

  int _percent(int value, int total) =>
      total <= 0 ? 0 : ((value / total) * 100).round();

  bool _matchesDashboardSearch(String text) {
    final q = _dashboardSearch.trim().toLowerCase();
    return q.isEmpty || text.toLowerCase().contains(q);
  }

  bool _showRestaurantSection() {
    return _businessSide != 'CATERING' &&
        _matchesDashboardSearch(
          'restaurant orders kitchen cashier delivery ratings sales feedback pending delivered cancelled',
        );
  }

  bool _showCateringSection() {
    return _businessSide != 'RESTAURANT' &&
        _matchesDashboardSearch(
          'catering orders events inquiries bookings payment completed complaints sales feedback',
        );
  }

  bool _showBusinessOverview() {
    return _matchesDashboardSearch(
      'business overview order outcomes performance mix financial data monthly sales revenue channel',
    );
  }

  List<MonthlyDashboardSales> _monthlySeries(DashboardSummary s) {
    if (s.monthlySales.length == 12) return s.monthlySales;
    final byMonth = {for (final m in s.monthlySales) m.month: m};
    return List.generate(
      12,
      (idx) =>
          byMonth[idx + 1] ??
          MonthlyDashboardSales(
            month: idx + 1,
            restaurantSales: 0,
            cateringSales: 0,
            totalSales: 0,
            restaurantOrders: 0,
            cateringOrders: 0,
            totalOrders: 0,
          ),
    );
  }

  void _showDashboardDetails({
    required String title,
    String? subtitle,
    required List<_DetailRow> details,
    Widget? visual,
  }) {
    showDialog<void>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(title),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (subtitle != null && subtitle.trim().isNotEmpty) ...[
                      Text(
                        subtitle,
                        style: const TextStyle(color: AntdTokens.labelMuted),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (visual != null) ...[
                      SizedBox(height: 300, child: visual),
                      const SizedBox(height: 16),
                    ],
                    for (final row in details) _detailLine(row),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  Future<void> _printDashboardPdf(DashboardSummary summary) async {
    if (_isPrintingPdf) return;
    setState(() => _isPrintingPdf = true);
    try {
      final generatedAt = DateTime.now();
      final doc = pw.Document(title: 'Manager Dashboard');
      final monthly = _monthlySeries(summary);
      final visibleRows = <List<String>>[
        if (_businessSide != 'CATERING') ...[
          ['Restaurant pending', '${summary.restaurant.pendingConfirmations}'],
          ['Restaurant delivered', '${summary.restaurant.delivered}'],
          ['Restaurant cancelled', '${summary.restaurant.cancelled}'],
          ['Restaurant sales today', formatPhp(summary.restaurant.salesToday)],
          [
            'Restaurant feedback',
            '${summary.restaurant.feedback.count} responses · ${summary.restaurant.feedback.averageStars.toStringAsFixed(1)} / 5',
          ],
        ],
        if (_businessSide != 'RESTAURANT') ...[
          ['Catering inquiries', '${summary.catering.inquiriesThisMonth}'],
          ['Catering accepted', '${summary.catering.acceptedTransactions}'],
          ['Catering completed', '${summary.catering.completed}'],
          ['Catering sales today', formatPhp(summary.catering.salesToday)],
          [
            'Catering complaints',
            '${summary.catering.feedback.complaintCount}',
          ],
        ],
        ['Year-to-date total', formatPhp(summary.salesThisYear.all)],
      ];

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
                  'Manager Dashboard',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text("Macrina's Kitchen and Catering"),
                pw.SizedBox(height: 4),
                pw.Text(
                  'As of ${_formatInsightDate(generatedAt)} · Business side: $_businessSide · Source: $_orderSource',
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey700,
                  ),
                ),
                pw.SizedBox(height: 12),
                pw.Text(
                  'Dashboard Summary',
                  style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.TableHelper.fromTextArray(
                  headers: const ['Metric', 'Value'],
                  data: visibleRows,
                  headerDecoration: const pw.BoxDecoration(
                    color: PdfColors.grey200,
                  ),
                  headerStyle: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 9,
                  ),
                  cellStyle: const pw.TextStyle(fontSize: 8),
                  cellAlignment: pw.Alignment.centerLeft,
                  headerAlignment: pw.Alignment.centerLeft,
                ),
                pw.SizedBox(height: 16),
                pw.Text(
                  'Monthly Sales and Order Volume',
                  style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.TableHelper.fromTextArray(
                  headers: const [
                    'Month',
                    'Restaurant Sales',
                    'Catering Sales',
                    'Total Sales',
                    'Restaurant Orders',
                    'Catering Orders',
                    'Total Orders',
                  ],
                  data: [
                    for (final m in monthly)
                      [
                        _monthLabel(m.month),
                        formatPhp(m.restaurantSales),
                        formatPhp(m.cateringSales),
                        formatPhp(m.totalSales),
                        '${m.restaurantOrders}',
                        '${m.cateringOrders}',
                        '${m.totalOrders}',
                      ],
                  ],
                  headerDecoration: const pw.BoxDecoration(
                    color: PdfColors.grey200,
                  ),
                  headerStyle: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 8,
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
        name: 'manager-dashboard.pdf',
      );
    } finally {
      if (mounted) setState(() => _isPrintingPdf = false);
    }
  }

  Widget _detailLine(_DetailRow row) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              row.label,
              style: const TextStyle(color: AntdTokens.labelMuted),
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              row.value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: AntdTokens.valueDark,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dashboardCard({
    required String title,
    String? subtitle,
    required Widget child,
    List<_DetailRow> details = const [],
  }) {
    final hasDetails = details.isNotEmpty;
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: AntdTokens.borderSubtle),
        borderRadius: BorderRadius.circular(18),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap:
            hasDetails
                ? () => _showDashboardDetails(
                  title: title,
                  subtitle: subtitle,
                  details: details,
                  visual: child,
                )
                : null,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AntdTokens.valueDark,
                      ),
                    ),
                  ),
                  if (hasDetails)
                    const Icon(
                      Icons.open_in_full,
                      color: AntdTokens.labelMuted,
                      size: 16,
                    ),
                ],
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AntdTokens.labelMuted,
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              child,
            ],
          ),
        ),
      ),
    );
  }

  Widget _chartGrid(List<Widget> children) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 900;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children:
              children
                  .map(
                    (child) => SizedBox(
                      width:
                          narrow
                              ? constraints.maxWidth
                              : (constraints.maxWidth - 16) / 2,
                      child: child,
                    ),
                  )
                  .toList(),
        );
      },
    );
  }

  String _aiActionLabel(AiTaskState state, String idleLabel) {
    switch (state) {
      case AiTaskState.queued:
        return 'Queued...';
      case AiTaskState.processing:
        return 'Generating...';
      case AiTaskState.failed:
        return 'Retry';
      case AiTaskState.completed:
      case AiTaskState.idle:
        return idleLabel;
    }
  }

  Widget _aiStatusPill(AiTaskState state) {
    final color = switch (state) {
      AiTaskState.queued => Colors.orange.shade700,
      AiTaskState.processing => AntdTokens.blue,
      AiTaskState.completed => AntdTokens.success,
      AiTaskState.failed => AntdTokens.error,
      AiTaskState.idle => AntdTokens.labelMuted,
    };
    final label = switch (state) {
      AiTaskState.queued => 'Queued',
      AiTaskState.processing => 'Generating',
      AiTaskState.completed => 'Ready',
      AiTaskState.failed => 'Failed',
      AiTaskState.idle => 'Idle',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _aiInsightsPanel() {
    final insight = _insight;
    final busy = _isAiBusy(_insightState);
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: AntdTokens.borderSubtle),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, color: AntdTokens.blue),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'AI Dashboard Analyst',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AntdTokens.valueDark,
                    ),
                  ),
                ),
                _aiStatusPill(_insightState),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: busy ? null : _generateInsight,
                  icon:
                      busy
                          ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.psychology_alt_outlined),
                  label: Text(
                    _aiActionLabel(_insightState, 'Generate AI analysis'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Range: $_insightRange'
              '${insight?.createdAt != null ? ' · Generated ${_formatInsightDate(insight!.createdAt!)}' : ''}',
              style: const TextStyle(
                color: AntdTokens.labelMuted,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _insightPromptController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'AI analysis prompt',
                hintText:
                    'Tell the AI what to focus on, such as complaints, sales risks, operations, or next actions.',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            if (_insightError != null) ...[
              const SizedBox(height: 12),
              _errorBanner(_insightError!, onRetry: _generateInsight),
            ],
            const SizedBox(height: 14),
            if (insight == null)
              const Text(
                'No stored AI analysis yet. Generate one to summarize recent feedback, alerts, and recommended actions.',
                style: TextStyle(color: AntdTokens.labelMuted),
              )
            else
              _aiSectionGrid([
                _aiSectionCard(
                  title: 'Dashboard Summary',
                  subtitle: 'AI executive summary',
                  icon: Icons.summarize_outlined,
                  color: AntdTokens.blue,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        insight.summary.isEmpty
                            ? 'No summary returned.'
                            : insight.summary,
                        style: const TextStyle(
                          color: AntdTokens.valueDark,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (insight.explainability.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        const Text(
                          'AI detected:',
                          style: TextStyle(
                            color: AntdTokens.valueDark,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _insightList(insight.explainability),
                      ],
                      if (insight.insights.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _insightList(insight.insights),
                      ],
                    ],
                  ),
                ),
                _aiSectionCard(
                  title: 'Trends',
                  subtitle: 'Sales, ordering, and event trends',
                  icon: Icons.trending_up,
                  color: Colors.indigo.shade500,
                  child: _insightList(insight.trends),
                ),
                _aiSectionCard(
                  title: 'Problems',
                  subtitle:
                      'Operational issues, customer complaints, and low stock risks',
                  icon: Icons.report_problem_outlined,
                  color: AntdTokens.warning,
                  child: _insightList(insight.problems),
                ),
                _aiSectionCard(
                  title: 'Recommendations',
                  subtitle: 'Actionable suggestions',
                  icon: Icons.task_alt,
                  color: AntdTokens.success,
                  child: _insightList(insight.recommendations),
                ),
                _aiSectionCard(
                  title: 'Alerts',
                  subtitle: 'Severity cards',
                  icon: Icons.notifications_active_outlined,
                  color: AntdTokens.error,
                  child:
                      insight.alerts.isEmpty
                          ? const Text(
                            'No alerts.',
                            style: TextStyle(color: AntdTokens.labelMuted),
                          )
                          : Column(
                            children: insight.alerts.map(_alertCard).toList(),
                          ),
                ),
              ]),
          ],
        ),
      ),
    );
  }

  Widget _aiSectionGrid(List<Widget> children) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 900;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children:
              children
                  .map(
                    (child) => SizedBox(
                      width:
                          narrow
                              ? constraints.maxWidth
                              : (constraints.maxWidth - 12) / 2,
                      child: child,
                    ),
                  )
                  .toList(),
        );
      },
    );
  }

  Widget _aiSectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AntdTokens.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AntdTokens.valueDark,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AntdTokens.labelMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _insightList(List<String> items) {
    if (items.isEmpty) {
      return const Text(
        'No items.',
        style: TextStyle(color: AntdTokens.labelMuted),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [const Text('• '), Expanded(child: Text(item))],
            ),
          ),
      ],
    );
  }

  Widget _alertCard(DashboardInsightAlert alert) {
    final color = _severityColor(alert.severity);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_outlined, color: color, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  alert.message,
                  style: TextStyle(color: color, fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                alert.severity.toUpperCase(),
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          if (alert.explanation.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              alert.explanation,
              style: const TextStyle(color: AntdTokens.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Color _severityColor(String severity) {
    switch (severity.trim().toLowerCase()) {
      case 'high':
        return Colors.red.shade700;
      case 'medium':
        return Colors.orange.shade700;
      case 'info':
      default:
        return AntdTokens.blue;
    }
  }

  Widget _errorBanner(String message, {VoidCallback? onRetry}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(message, style: TextStyle(color: Colors.red.shade800)),
          ),
          if (onRetry != null)
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry'),
            ),
        ],
      ),
    );
  }

  Widget _aiHealthPanel() {
    final health = _aiHealth;
    final busy = _isAiBusy(_healthState);
    return _dashboardCard(
      title: 'AI Health Monitoring',
      subtitle: 'GPU, NLP, SDXL, queue, and latency status',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _aiStatusPill(_healthState),
              const Spacer(),
              TextButton.icon(
                onPressed: busy ? null : _loadAiHealth,
                icon:
                    busy
                        ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.refresh),
                label: Text(_aiActionLabel(_healthState, 'Refresh health')),
              ),
            ],
          ),
          if (_healthError != null) ...[
            const SizedBox(height: 10),
            _errorBanner(_healthError!, onRetry: _loadAiHealth),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _healthTile('GPU', health?.gpuOnline, health?.gpuName),
              _healthTile('NLP', health?.nlpOnline, health?.model),
              _healthTile('SDXL', health?.sdxlOnline, null),
              _healthMetricTile(
                'Queue size',
                health?.queueSize?.toString() ?? 'Unknown',
              ),
              _healthMetricTile(
                'Last latency',
                health?.lastInferenceLatencyMs == null
                    ? 'Unknown'
                    : '${health!.lastInferenceLatencyMs!.toStringAsFixed(0)} ms',
              ),
            ],
          ),
          if (health?.message.isNotEmpty == true) ...[
            const SizedBox(height: 10),
            Text(
              health!.message,
              style: const TextStyle(color: AntdTokens.labelMuted),
            ),
          ],
        ],
      ),
    );
  }

  Widget _healthTile(String label, bool? online, String? detail) {
    final color =
        online == true
            ? AntdTokens.success
            : online == false
            ? AntdTokens.error
            : AntdTokens.labelMuted;
    final value =
        online == true
            ? 'Online'
            : online == false
            ? 'Offline'
            : 'Unknown';
    return _healthMetricTile(label, value, detail: detail, color: color);
  }

  Widget _healthMetricTile(
    String label,
    String value, {
    String? detail,
    Color color = AntdTokens.valueDark,
  }) {
    return Container(
      width: 170,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AntdTokens.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AntdTokens.labelMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.w800),
          ),
          if (detail != null && detail.trim().isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              detail,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AntdTokens.labelMuted,
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _dishTrendsPanel() {
    final trends = _dishTrends;
    final busy = _isAiBusy(_dishTrendState);
    final top = trends?.topDishes ?? const <DishTrend>[];
    final revenue = trends?.revenueLeaders ?? const <DishTrend>[];
    final maxOrders = top.fold<double>(
      0,
      (max, item) => math.max(max, item.orders),
    );
    final maxRevenue = revenue.fold<double>(
      0,
      (max, item) => math.max(max, item.revenue),
    );
    return _dashboardCard(
      title: 'Dish Trend AI',
      subtitle: 'Top dishes, revenue leaders, and trending dishes',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _aiStatusPill(_dishTrendState),
              const Spacer(),
              TextButton.icon(
                onPressed: busy ? null : _loadDishTrends,
                icon:
                    busy
                        ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.refresh),
                label: Text(_aiActionLabel(_dishTrendState, 'Refresh trends')),
              ),
            ],
          ),
          if (_dishTrendError != null) ...[
            const SizedBox(height: 10),
            _errorBanner(_dishTrendError!, onRetry: _loadDishTrends),
          ],
          if (trends?.summary.isNotEmpty == true) ...[
            const SizedBox(height: 10),
            Text(
              trends!.summary,
              style: const TextStyle(
                color: AntdTokens.valueDark,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (trends == null || trends.isEmpty)
            const Text(
              'No dish trend data returned yet.',
              style: TextStyle(color: AntdTokens.labelMuted),
            )
          else
            _aiSectionGrid([
              _dishRankingCard(
                title: 'Top dishes',
                items: top,
                maxValue: maxOrders,
                color: AntdTokens.blue,
                valueBuilder:
                    (item) => '${item.orders.toStringAsFixed(0)} orders',
              ),
              _dishRankingCard(
                title: 'Revenue leaders',
                items: revenue,
                maxValue: maxRevenue,
                color: AntdTokens.success,
                valueBuilder: (item) => formatPhp(item.revenue),
              ),
              _aiSectionCard(
                title: 'Trending dishes',
                subtitle: 'AI trend badges',
                icon: Icons.local_fire_department_outlined,
                color: Colors.deepOrange.shade500,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final dish in trends.trendingDishes)
                      Chip(
                        label: Text(dish),
                        avatar: const Icon(Icons.trending_up, size: 16),
                        backgroundColor: Colors.deepOrange.shade50,
                        side: BorderSide(color: Colors.deepOrange.shade100),
                      ),
                  ],
                ),
              ),
            ]),
          if (trends?.recommendations.isNotEmpty == true) ...[
            const SizedBox(height: 12),
            _aiSectionCard(
              title: 'Dish recommendations',
              subtitle: 'Menu and stocking suggestions',
              icon: Icons.tips_and_updates_outlined,
              color: Colors.purple.shade500,
              child: _insightList(trends!.recommendations),
            ),
          ],
        ],
      ),
    );
  }

  Widget _dishRankingCard({
    required String title,
    required List<DishTrend> items,
    required double maxValue,
    required Color color,
    required String Function(DishTrend item) valueBuilder,
  }) {
    return _aiSectionCard(
      title: title,
      subtitle: 'Horizontal ranking cards',
      icon: Icons.bar_chart,
      color: color,
      child:
          items.isEmpty
              ? const Text(
                'No dishes returned.',
                style: TextStyle(color: AntdTokens.labelMuted),
              )
              : Column(
                children: [
                  for (var i = 0; i < math.min(5, items.length); i++)
                    _dishRankingRow(
                      rank: i + 1,
                      trend: items[i],
                      value: valueBuilder(items[i]),
                      maxValue: maxValue,
                      color: color,
                    ),
                ],
              ),
    );
  }

  Widget _dishRankingRow({
    required int rank,
    required DishTrend trend,
    required String value,
    required double maxValue,
    required Color color,
  }) {
    final amount = value.startsWith('₱') ? trend.revenue : trend.orders;
    final factor = maxValue <= 0 ? 0.0 : (amount / maxValue).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '#$rank',
                style: const TextStyle(
                  color: AntdTokens.labelMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  trend.dish,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 8),
              Text(value, style: TextStyle(color: color)),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: factor,
              minHeight: 8,
              backgroundColor: color.withValues(alpha: 0.10),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = _summary;

    return AppScaffold(
      showSearch: true,
      searchController: _searchController,
      searchHint: 'Search manager dashboard',
      onSearchChanged:
          (value) =>
              setState(() => _dashboardSearch = value.trim().toLowerCase()),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            elevation: 1,
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Manager Dashboard',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed:
                            _isPrintingPdf || s == null
                                ? null
                                : () => _printDashboardPdf(s),
                        icon:
                            _isPrintingPdf
                                ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                                : const Icon(Icons.picture_as_pdf),
                        label: Text(
                          _isPrintingPdf ? 'Preparing PDF' : 'Preview / Print',
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Refresh',
                        onPressed:
                            _isLoading
                                ? null
                                : () => _refreshDashboard(force: true),
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _filterBar(),
                ],
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_errorMessage != null)
                    Card(
                      color: Colors.red.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red.shade800),
                        ),
                      ),
                    ),
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.all(48),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (s != null) ...[
                    _aiInsightsPanel(),
                    if (_showAiHealthPanel) ...[
                      const SizedBox(height: 16),
                      _aiHealthPanel(),
                    ],
                    if (_showDishTrendsPanel) ...[
                      const SizedBox(height: 16),
                      _dishTrendsPanel(),
                    ],
                    const SizedBox(height: 16),
                    if (_showRestaurantSection()) ...[
                      _businessSection(
                        title: 'Restaurant Orders',
                        subtitle:
                            'Kitchen order flow, cashier confirmation, delivery, and customer ratings.',
                        icon: Icons.restaurant_menu,
                        accent: AntdTokens.blue,
                        children: [
                          _metricCard(
                            'Pending confirmations',
                            '${s.restaurant.pendingConfirmations}',
                            Colors.orange.shade600,
                            icon: Icons.pending_actions,
                            routeName: '/restaurant-orders',
                            subtitle: 'Needs cashier review',
                            details: [
                              _DetailRow(
                                'Pending restaurant confirmations',
                                '${s.restaurant.pendingConfirmations}',
                              ),
                              _DetailRow(
                                'Action',
                                'Review in Restaurant Orders',
                              ),
                            ],
                          ),
                          _metricCard(
                            'Delivered orders',
                            '${s.restaurant.delivered}',
                            AntdTokens.success,
                            icon: Icons.delivery_dining,
                            routeName: '/restaurant-orders',
                            subtitle: 'Completed restaurant service',
                            details: [
                              _DetailRow(
                                'Delivered',
                                '${s.restaurant.delivered}',
                              ),
                              _DetailRow(
                                'Cancelled',
                                '${s.restaurant.cancelled}',
                              ),
                            ],
                          ),
                          _metricCard(
                            'Cancelled orders',
                            '${s.restaurant.cancelled}',
                            AntdTokens.error,
                            icon: Icons.cancel_outlined,
                            routeName: '/restaurant-orders',
                            subtitle: 'Restaurant cancellations',
                            details: [
                              _DetailRow(
                                'Cancelled',
                                '${s.restaurant.cancelled}',
                              ),
                              _DetailRow(
                                'Total restaurant outcomes',
                                '${s.restaurant.delivered + s.restaurant.cancelled}',
                              ),
                            ],
                          ),
                          _metricCard(
                            'Restaurant sales today',
                            formatPhp(s.restaurant.salesToday),
                            Colors.blue.shade700,
                            icon: Icons.payments_outlined,
                            routeName: '/reports',
                            subtitle: 'Revenue excluding cancelled orders',
                            details: [
                              _DetailRow(
                                'Today',
                                formatPhp(s.restaurant.salesToday),
                              ),
                              _DetailRow(
                                'Year to date',
                                formatPhp(s.salesThisYear.restaurant),
                              ),
                            ],
                          ),
                          _metricCard(
                            'Restaurant feedback',
                            '${s.restaurant.feedback.count}',
                            Colors.indigo.shade500,
                            icon: Icons.star_rate,
                            routeName: '/customer-feedback',
                            subtitle:
                                'Average ${s.restaurant.feedback.averageStars.toStringAsFixed(1)} / 5',
                            details: [
                              _DetailRow(
                                'Average stars',
                                s.restaurant.feedback.averageStars
                                    .toStringAsFixed(1),
                              ),
                              _DetailRow(
                                'Positive',
                                '${s.restaurant.feedback.positiveCount}',
                              ),
                              _DetailRow(
                                'Neutral',
                                '${s.restaurant.feedback.neutralCount}',
                              ),
                              _DetailRow(
                                'Negative',
                                '${s.restaurant.feedback.negativeCount}',
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (_showCateringSection()) ...[
                      _businessSection(
                        title: 'Catering Orders',
                        subtitle:
                            'Event inquiries, booking pipeline, payment milestones, completion, and post-event feedback.',
                        icon: Icons.celebration,
                        accent: Colors.deepPurple.shade500,
                        children: [
                          _metricCard(
                            'Inquiries this month',
                            '${s.catering.inquiriesThisMonth}',
                            Colors.deepPurple.shade400,
                            icon: Icons.contact_mail_outlined,
                            routeName: '/manage-events',
                            subtitle: 'New event leads',
                            details: [
                              _DetailRow(
                                'This month',
                                '${s.catering.inquiriesThisMonth}',
                              ),
                              _DetailRow(
                                'Accepted transactions',
                                '${s.catering.acceptedTransactions}',
                              ),
                            ],
                          ),
                          _metricCard(
                            'Accepted bookings',
                            '${s.catering.acceptedTransactions}',
                            Colors.indigo.shade500,
                            icon: Icons.event_available,
                            routeName: '/manage-events',
                            subtitle: 'Moved beyond inquiry',
                            details: [
                              _DetailRow(
                                'Accepted transactions',
                                '${s.catering.acceptedTransactions}',
                              ),
                              _DetailRow('Ongoing', '${s.catering.ongoing}'),
                            ],
                          ),
                          _metricCard(
                            'Payment follow-ups',
                            '${s.catering.forDownPayment + s.catering.forFullPayment}',
                            Colors.amber.shade800,
                            icon: Icons.request_quote_outlined,
                            routeName: '/manage-events',
                            subtitle: 'Down payment and balance queues',
                            details: [
                              _DetailRow(
                                'For down payment',
                                '${s.catering.forDownPayment}',
                              ),
                              _DetailRow(
                                'For full payment',
                                '${s.catering.forFullPayment}',
                              ),
                            ],
                          ),
                          _metricCard(
                            'Completed events',
                            '${s.catering.completed}',
                            AntdTokens.success,
                            icon: Icons.task_alt,
                            routeName: '/manage-events',
                            subtitle: 'Finished catering services',
                            details: [
                              _DetailRow(
                                'Completed',
                                '${s.catering.completed}',
                              ),
                              _DetailRow(
                                'Cancelled',
                                '${s.catering.cancelled}',
                              ),
                            ],
                          ),
                          _metricCard(
                            'Catering sales today',
                            formatPhp(s.catering.salesToday),
                            Colors.teal.shade600,
                            icon: Icons.point_of_sale,
                            routeName: '/reports',
                            subtitle: 'Completed event revenue',
                            details: [
                              _DetailRow(
                                'Today',
                                formatPhp(s.catering.salesToday),
                              ),
                              _DetailRow(
                                'Year to date',
                                formatPhp(s.salesThisYear.catering),
                              ),
                            ],
                          ),
                          _metricCard(
                            'Catering complaints',
                            '${s.catering.feedback.complaintCount}',
                            Colors.deepPurple.shade400,
                            icon: Icons.feedback_outlined,
                            routeName: '/reports',
                            subtitle: 'Post-event analysis flags',
                            details: [
                              _DetailRow(
                                'Events with complaints',
                                '${s.catering.feedback.count}',
                              ),
                              _DetailRow(
                                'Total complaints',
                                '${s.catering.feedback.complaintCount}',
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (_showBusinessOverview()) ...[
                      _chartGrid([_websiteAnalyticsCard()]),
                      const SizedBox(height: 20),
                      _sectionTitle('Business Overview'),
                      _chartGrid([
                        _dashboardCard(
                          title: 'Order Outcomes',
                          subtitle: 'Restaurant and catering results',
                          details: [
                            _DetailRow(
                              'Pending confirmations',
                              '${s.restaurant.pendingConfirmations}',
                            ),
                            _DetailRow(
                              'Restaurant delivered',
                              '${s.restaurant.delivered}',
                            ),
                            _DetailRow(
                              'Catering completed',
                              '${s.catering.completed}',
                            ),
                            _DetailRow(
                              'Cancelled total',
                              '${s.restaurant.cancelled + s.catering.cancelled}',
                            ),
                          ],
                          child: SizedBox(
                            height: 260,
                            child: _DashboardBarChart(
                              valueFormatter: (v) => v.toInt().toString(),
                              points: [
                                _ChartPoint(
                                  'Pending',
                                  s.restaurant.pendingConfirmations.toDouble(),
                                  Colors.orange.shade400,
                                ),
                                _ChartPoint(
                                  'Delivered',
                                  s.restaurant.delivered.toDouble(),
                                  AntdTokens.success,
                                ),
                                _ChartPoint(
                                  'Completed',
                                  s.catering.completed.toDouble(),
                                  Colors.teal.shade500,
                                ),
                                _ChartPoint(
                                  'Cancelled',
                                  (s.restaurant.cancelled +
                                          s.catering.cancelled)
                                      .toDouble(),
                                  AntdTokens.error,
                                ),
                              ],
                            ),
                          ),
                        ),
                        _dashboardCard(
                          title: 'Performance Mix',
                          subtitle: 'Success vs. open/cancelled work',
                          details: [
                            _DetailRow(
                              'Success rate',
                              '${_percent(s.restaurant.delivered + s.catering.completed, s.restaurant.pendingConfirmations + s.restaurant.delivered + s.restaurant.cancelled + s.catering.completed + s.catering.cancelled)}%',
                            ),
                            _DetailRow(
                              'Successful',
                              '${s.restaurant.delivered + s.catering.completed}',
                            ),
                            _DetailRow(
                              'Open',
                              '${s.restaurant.pendingConfirmations + s.catering.acceptedTransactions}',
                            ),
                            _DetailRow(
                              'Cancelled',
                              '${s.restaurant.cancelled + s.catering.cancelled}',
                            ),
                          ],
                          child: SizedBox(
                            height: 260,
                            child: _DashboardDonutChart(
                              centerLabel:
                                  '${_percent(s.restaurant.delivered + s.catering.completed, s.restaurant.pendingConfirmations + s.restaurant.delivered + s.restaurant.cancelled + s.catering.completed + s.catering.cancelled)}%',
                              centerCaption: 'success',
                              points: [
                                _ChartPoint(
                                  'Successful',
                                  (s.restaurant.delivered +
                                          s.catering.completed)
                                      .toDouble(),
                                  AntdTokens.success,
                                ),
                                _ChartPoint(
                                  'Open',
                                  (s.restaurant.pendingConfirmations +
                                          s.catering.acceptedTransactions)
                                      .toDouble(),
                                  AntdTokens.warning,
                                ),
                                _ChartPoint(
                                  'Cancelled',
                                  (s.restaurant.cancelled +
                                          s.catering.cancelled)
                                      .toDouble(),
                                  AntdTokens.error,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 20),
                      _sectionTitle('Financial Data'),
                      _metricsRow([
                        _metricCard(
                          'Restaurant sales today',
                          formatPhp(s.restaurant.salesToday),
                          Colors.blue.shade700,
                          subtitle:
                              'Restaurant revenue recorded today, excluding cancelled orders.',
                          details: [
                            _DetailRow(
                              'Today',
                              formatPhp(s.restaurant.salesToday),
                            ),
                            _DetailRow(
                              'Year to date',
                              formatPhp(s.salesThisYear.restaurant),
                            ),
                          ],
                        ),
                        _metricCard(
                          'Catering sales today',
                          formatPhp(s.catering.salesToday),
                          Colors.blueGrey.shade600,
                          subtitle:
                              'Completed catering/event revenue recorded today.',
                          details: [
                            _DetailRow(
                              'Today',
                              formatPhp(s.catering.salesToday),
                            ),
                            _DetailRow(
                              'Year to date',
                              formatPhp(s.salesThisYear.catering),
                            ),
                          ],
                        ),
                        _metricCard(
                          'Sales this year',
                          formatPhp(s.salesThisYear.all),
                          const Color(0xFF2E7D32),
                          subtitle:
                              'Combined restaurant and catering revenue this year.',
                          details: [
                            _DetailRow(
                              'Restaurant',
                              formatPhp(s.salesThisYear.restaurant),
                            ),
                            _DetailRow(
                              'Catering / Events',
                              formatPhp(s.salesThisYear.catering),
                            ),
                            _DetailRow(
                              'All sales',
                              formatPhp(s.salesThisYear.all),
                            ),
                          ],
                        ),
                        _metricCard(
                          'Restaurant share',
                          '${_percent(s.salesThisYear.restaurant.round(), s.salesThisYear.all.round())}%',
                          const Color(0xFF1E1E1E),
                          subtitle:
                              'Restaurant portion of total year-to-date sales.',
                          details: [
                            _DetailRow(
                              'Restaurant',
                              formatPhp(s.salesThisYear.restaurant),
                            ),
                            _DetailRow(
                              'All sales',
                              formatPhp(s.salesThisYear.all),
                            ),
                            _DetailRow(
                              'Share',
                              '${_percent(s.salesThisYear.restaurant.round(), s.salesThisYear.all.round())}%',
                            ),
                          ],
                        ),
                      ]),
                      const SizedBox(height: 16),
                      _chartGrid([
                        _dashboardCard(
                          title: 'Monthly Sales Trend',
                          subtitle:
                              'Restaurant + catering revenue for this year',
                          details: [
                            _DetailRow(
                              'Year-to-date total',
                              formatPhp(s.salesThisYear.all),
                            ),
                            _DetailRow(
                              'Restaurant',
                              formatPhp(s.salesThisYear.restaurant),
                            ),
                            _DetailRow(
                              'Catering / Events',
                              formatPhp(s.salesThisYear.catering),
                            ),
                            _DetailRow(
                              'Best month',
                              _bestMonthLabel(
                                _monthlySeries(s),
                                (m) => m.totalSales,
                                formatPhp,
                              ),
                            ),
                          ],
                          child: SizedBox(
                            height: 260,
                            child: _DashboardLineChart(
                              points:
                                  _monthlySeries(s)
                                      .map(
                                        (m) => _ChartPoint(
                                          _monthLabel(m.month),
                                          m.totalSales,
                                          AntdTokens.blue,
                                        ),
                                      )
                                      .toList(),
                              valueFormatter: formatPhp,
                            ),
                          ),
                        ),
                        _dashboardCard(
                          title: 'Revenue by Channel',
                          subtitle: 'Year-to-date sales split',
                          details: [
                            _DetailRow(
                              'Restaurant',
                              formatPhp(s.salesThisYear.restaurant),
                            ),
                            _DetailRow(
                              'Catering / Events',
                              formatPhp(s.salesThisYear.catering),
                            ),
                            _DetailRow('Total', formatPhp(s.salesThisYear.all)),
                            _DetailRow(
                              'Restaurant share',
                              '${_percent(s.salesThisYear.restaurant.round(), s.salesThisYear.all.round())}%',
                            ),
                          ],
                          child: SizedBox(
                            height: 260,
                            child: _DashboardBarChart(
                              valueFormatter: formatPhp,
                              points: [
                                _ChartPoint(
                                  'Restaurant',
                                  s.salesThisYear.restaurant,
                                  AntdTokens.blue,
                                ),
                                _ChartPoint(
                                  'Catering',
                                  s.salesThisYear.catering,
                                  Colors.deepPurple.shade400,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 20),
                      _sectionTitle('Operational Insights'),
                      _metricsRow([
                        _metricCard(
                          'Inquiries this month',
                          '${s.catering.inquiriesThisMonth}',
                          Colors.deepPurple.shade300,
                          subtitle:
                              'New online catering/event inquiries this month.',
                          details: [
                            _DetailRow(
                              'This month',
                              '${s.catering.inquiriesThisMonth}',
                            ),
                            _DetailRow(
                              'Accepted transactions',
                              '${s.catering.acceptedTransactions}',
                            ),
                          ],
                        ),
                        _metricCard(
                          'For down payment',
                          '${s.catering.forDownPayment}',
                          Colors.amber.shade700,
                          subtitle:
                              'Accepted events still waiting for down payment.',
                          details: [
                            _DetailRow(
                              'For down payment',
                              '${s.catering.forDownPayment}',
                            ),
                            _DetailRow(
                              'Accepted transactions',
                              '${s.catering.acceptedTransactions}',
                            ),
                          ],
                        ),
                        _metricCard(
                          'Ongoing',
                          '${s.catering.ongoing}',
                          Colors.teal.shade600,
                          subtitle:
                              'Paid down-payment jobs currently being processed.',
                          details: [
                            _DetailRow('Ongoing', '${s.catering.ongoing}'),
                            _DetailRow(
                              'For full payment',
                              '${s.catering.forFullPayment}',
                            ),
                          ],
                        ),
                        _metricCard(
                          'For full payment',
                          '${s.catering.forFullPayment}',
                          Colors.cyan.shade700,
                          subtitle:
                              'Events waiting for remaining balance or final payment.',
                          details: [
                            _DetailRow(
                              'For full payment',
                              '${s.catering.forFullPayment}',
                            ),
                            _DetailRow('Completed', '${s.catering.completed}'),
                          ],
                        ),
                      ]),
                      const SizedBox(height: 16),
                      _chartGrid([
                        _dashboardCard(
                          title: 'Catering Pipeline',
                          subtitle: 'Event operations by current status',
                          details: [
                            _DetailRow(
                              'Inquiries this month',
                              '${s.catering.inquiriesThisMonth}',
                            ),
                            _DetailRow(
                              'Accepted transactions',
                              '${s.catering.acceptedTransactions}',
                            ),
                            _DetailRow(
                              'For down payment',
                              '${s.catering.forDownPayment}',
                            ),
                            _DetailRow('Ongoing', '${s.catering.ongoing}'),
                            _DetailRow(
                              'For full payment',
                              '${s.catering.forFullPayment}',
                            ),
                          ],
                          child: SizedBox(
                            height: 260,
                            child: _DashboardBarChart(
                              valueFormatter: (v) => v.toInt().toString(),
                              points: [
                                _ChartPoint(
                                  'Inquiries',
                                  s.catering.inquiriesThisMonth.toDouble(),
                                  Colors.deepPurple.shade300,
                                ),
                                _ChartPoint(
                                  'Accepted',
                                  s.catering.acceptedTransactions.toDouble(),
                                  Colors.indigo.shade400,
                                ),
                                _ChartPoint(
                                  'Down pay',
                                  s.catering.forDownPayment.toDouble(),
                                  Colors.amber.shade700,
                                ),
                                _ChartPoint(
                                  'Ongoing',
                                  s.catering.ongoing.toDouble(),
                                  Colors.teal.shade600,
                                ),
                                _ChartPoint(
                                  'Full pay',
                                  s.catering.forFullPayment.toDouble(),
                                  Colors.cyan.shade700,
                                ),
                              ],
                            ),
                          ),
                        ),
                        _dashboardCard(
                          title: 'Monthly Order Volume',
                          subtitle:
                              'Restaurant + catering orders created this year',
                          details: [
                            _DetailRow(
                              'Total orders this year',
                              '${_monthlySeries(s).fold<int>(0, (sum, m) => sum + m.totalOrders)}',
                            ),
                            _DetailRow(
                              'Restaurant orders',
                              '${_monthlySeries(s).fold<int>(0, (sum, m) => sum + m.restaurantOrders)}',
                            ),
                            _DetailRow(
                              'Catering/Event orders',
                              '${_monthlySeries(s).fold<int>(0, (sum, m) => sum + m.cateringOrders)}',
                            ),
                            _DetailRow(
                              'Busiest month',
                              _bestMonthLabel(
                                _monthlySeries(s),
                                (m) => m.totalOrders.toDouble(),
                                (v) => v.toInt().toString(),
                              ),
                            ),
                          ],
                          child: SizedBox(
                            height: 260,
                            child: _DashboardLineChart(
                              points:
                                  _monthlySeries(s)
                                      .map(
                                        (m) => _ChartPoint(
                                          _monthLabel(m.month),
                                          m.totalOrders.toDouble(),
                                          Colors.teal.shade500,
                                        ),
                                      )
                                      .toList(),
                              valueFormatter: (v) => v.toInt().toString(),
                            ),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed:
                              () => Navigator.of(
                                context,
                              ).pushNamed('/restaurant-orders'),
                          icon: const Icon(Icons.receipt_long),
                          label: const Text('Restaurant orders'),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _monthLabel(int month) {
  const labels = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  if (month < 1 || month > 12) return '';
  return labels[month - 1];
}

String _formatInsightDate(DateTime value) {
  final local = value.toLocal();
  final date =
      '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  final time =
      '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  return '$date $time';
}

String _bestMonthLabel(
  List<MonthlyDashboardSales> months,
  double Function(MonthlyDashboardSales month) valueOf,
  String Function(double value) formatter,
) {
  if (months.isEmpty) return 'No data';
  final best = months.reduce((a, b) => valueOf(a) >= valueOf(b) ? a : b);
  final value = valueOf(best);
  if (value <= 0) return 'No data';
  return '${_monthLabel(best.month)} · ${formatter(value)}';
}

class _ChartPoint {
  const _ChartPoint(this.label, this.value, this.color);

  final String label;
  final double value;
  final Color color;
}

class _DetailRow {
  const _DetailRow(this.label, this.value);

  final String label;
  final String value;
}

class _AnalyticsPill extends StatelessWidget {
  const _AnalyticsPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AntdTokens.borderSubtle),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AntdTokens.valueDark,
        ),
      ),
    );
  }
}

class _DashboardBarChart extends StatelessWidget {
  const _DashboardBarChart({
    required this.points,
    required this.valueFormatter,
  });

  final List<_ChartPoint> points;
  final String Function(double value) valueFormatter;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BarChartPainter(points, valueFormatter),
      child: const SizedBox.expand(),
    );
  }
}

class _DashboardLineChart extends StatelessWidget {
  const _DashboardLineChart({
    required this.points,
    required this.valueFormatter,
  });

  final List<_ChartPoint> points;
  final String Function(double value) valueFormatter;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _LineChartPainter(points, valueFormatter),
      child: const SizedBox.expand(),
    );
  }
}

class _DashboardDonutChart extends StatelessWidget {
  const _DashboardDonutChart({
    required this.points,
    required this.centerLabel,
    required this.centerCaption,
  });

  final List<_ChartPoint> points;
  final String centerLabel;
  final String centerCaption;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DonutChartPainter(points, centerLabel, centerCaption),
      child: const SizedBox.expand(),
    );
  }
}

class _BarChartPainter extends CustomPainter {
  const _BarChartPainter(this.points, this.valueFormatter);

  final List<_ChartPoint> points;
  final String Function(double value) valueFormatter;

  @override
  void paint(Canvas canvas, Size size) {
    final area = Rect.fromLTWH(8, 20, size.width - 16, size.height - 58);
    final axisPaint =
        Paint()
          ..color = AntdTokens.borderSubtle
          ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = area.bottom - (area.height * i / 4);
      canvas.drawLine(Offset(area.left, y), Offset(area.right, y), axisPaint);
    }

    final maxValue = math.max(
      1,
      points.fold<double>(0, (max, p) => math.max(max, p.value)),
    );
    final slot = area.width / math.max(1, points.length);
    final barWidth = math.min(56.0, slot * 0.52);
    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      final x = area.left + slot * i + (slot - barWidth) / 2;
      final h = (p.value / maxValue) * area.height;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, area.bottom - h, barWidth, h),
        const Radius.circular(8),
      );
      canvas.drawRRect(rect, Paint()..color = p.color);
      _drawText(
        canvas,
        valueFormatter(p.value),
        Offset(x + barWidth / 2, area.bottom - h - 18),
        fontSize: 11,
        fontWeight: FontWeight.w700,
        align: TextAlign.center,
      );
      _drawText(
        canvas,
        p.label,
        Offset(x + barWidth / 2, area.bottom + 12),
        fontSize: 11,
        color: AntdTokens.labelMuted,
        align: TextAlign.center,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter oldDelegate) =>
      oldDelegate.points != points;
}

class _LineChartPainter extends CustomPainter {
  const _LineChartPainter(this.points, this.valueFormatter);

  final List<_ChartPoint> points;
  final String Function(double value) valueFormatter;

  @override
  void paint(Canvas canvas, Size size) {
    final area = Rect.fromLTWH(8, 20, size.width - 16, size.height - 58);
    final gridPaint =
        Paint()
          ..color = AntdTokens.borderSubtle
          ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = area.bottom - (area.height * i / 4);
      canvas.drawLine(Offset(area.left, y), Offset(area.right, y), gridPaint);
    }

    if (points.isEmpty) return;
    final maxValue = math.max(
      1,
      points.fold<double>(0, (max, p) => math.max(max, p.value)),
    );
    final path = Path();
    final fillPath = Path();
    for (var i = 0; i < points.length; i++) {
      final x =
          points.length == 1
              ? area.center.dx
              : area.left + (area.width * i / (points.length - 1));
      final y = area.bottom - (points[i].value / maxValue) * area.height;
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, area.bottom);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
      canvas.drawCircle(Offset(x, y), 4, Paint()..color = points[i].color);
    }
    fillPath.lineTo(area.right, area.bottom);
    fillPath.close();
    canvas.drawPath(
      fillPath,
      Paint()..color = points.first.color.withValues(alpha: 0.10),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = points.first.color
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    final peak = points.reduce((a, b) => a.value >= b.value ? a : b);
    _drawText(
      canvas,
      'Peak ${valueFormatter(peak.value)}',
      Offset(area.left + 4, 2),
      fontSize: 11,
      fontWeight: FontWeight.w700,
    );
    for (final idx in const [0, 3, 6, 9, 11]) {
      if (idx >= points.length) continue;
      final x =
          area.left +
          (points.length == 1
              ? area.width / 2
              : area.width * idx / (points.length - 1));
      _drawText(
        canvas,
        points[idx].label,
        Offset(x, area.bottom + 12),
        fontSize: 10,
        color: AntdTokens.labelMuted,
        align: TextAlign.center,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) =>
      oldDelegate.points != points;
}

class _DonutChartPainter extends CustomPainter {
  const _DonutChartPainter(this.points, this.centerLabel, this.centerCaption);

  final List<_ChartPoint> points;
  final String centerLabel;
  final String centerCaption;

  @override
  void paint(Canvas canvas, Size size) {
    final total = points.fold<double>(0, (sum, p) => sum + p.value);
    final center = Offset(size.width * 0.35, size.height * 0.45);
    final radius = math.min(size.width, size.height) * 0.28;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final strokeWidth = radius * 0.34;
    var start = -math.pi / 2;
    final bgPaint =
        Paint()
          ..color = AntdTokens.borderSubtle
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, bgPaint);

    if (total > 0) {
      for (final p in points) {
        final sweep = (p.value / total) * math.pi * 2;
        canvas.drawArc(
          rect,
          start,
          sweep,
          false,
          Paint()
            ..color = p.color
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeWidth
            ..strokeCap = StrokeCap.round,
        );
        start += sweep;
      }
    }
    _drawText(
      canvas,
      centerLabel,
      center.translate(0, -10),
      fontSize: 24,
      fontWeight: FontWeight.w800,
      align: TextAlign.center,
    );
    _drawText(
      canvas,
      centerCaption,
      center.translate(0, 18),
      fontSize: 11,
      color: AntdTokens.labelMuted,
      align: TextAlign.center,
    );

    var y = 42.0;
    for (final p in points) {
      final x = size.width * 0.68;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y + 3, 10, 10),
          const Radius.circular(3),
        ),
        Paint()..color = p.color,
      );
      _drawText(
        canvas,
        '${p.label} (${p.value.toInt()})',
        Offset(x + 18, y),
        fontSize: 12,
        color: AntdTokens.valueDark,
      );
      y += 28;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.centerLabel != centerLabel ||
      oldDelegate.centerCaption != centerCaption;
}

void _drawText(
  Canvas canvas,
  String text,
  Offset offset, {
  double fontSize = 12,
  Color color = AntdTokens.valueDark,
  FontWeight fontWeight = FontWeight.w500,
  TextAlign align = TextAlign.left,
}) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: fontWeight,
      ),
    ),
    textDirection: TextDirection.ltr,
    textAlign: align,
    maxLines: 1,
    ellipsis: '…',
  )..layout(maxWidth: 110);
  final dx =
      align == TextAlign.center ? offset.dx - painter.width / 2 : offset.dx;
  painter.paint(canvas, Offset(dx, offset.dy));
}
