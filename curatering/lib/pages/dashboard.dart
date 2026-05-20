import 'dart:math' as math;

import 'package:flutter/material.dart';

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
  bool _isLoading = false;
  String? _errorMessage;
  DashboardSummary? _summary;
  String _range = 'year';
  String _orderSource = 'ALL';
  String _orderStatus = 'ALL';

  @override
  void initState() {
    super.initState();
    _load();
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

  DashboardFilters get _dashboardFilters {
    final now = DateTime.now();
    DateTime? start;
    DateTime? end;
    if (_range == 'today') {
      start = DateTime(now.year, now.month, now.day);
      end = start.add(const Duration(days: 1));
    } else if (_range == 'month') {
      start = DateTime(now.year, now.month);
      end = DateTime(now.year, now.month + 1);
    } else if (_range == 'year') {
      start = DateTime(now.year);
      end = DateTime(now.year + 1);
    }
    return DashboardFilters(
      start: start,
      end: end,
      orderSource: _orderSource,
      orderStatus: _orderStatus,
    );
  }

  Widget _filterBar() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AntdTokens.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text(
              'Filters',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            _filterDropdown(
              value: _range,
              label: 'Range',
              items: const {
                'today': 'Today',
                'month': 'This month',
                'year': 'This year',
                'all': 'All time',
              },
              onChanged: (v) {
                setState(() => _range = v);
                _load(forceRefresh: true);
              },
            ),
            _filterDropdown(
              value: _orderSource,
              label: 'Source',
              items: const {
                'ALL': 'All sources',
                'WEB_APP': 'Web',
                'MOBILE_APP': 'Mobile',
                'POS_WEB': 'POS web',
                'POS_MOBILE': 'POS mobile',
              },
              onChanged: (v) {
                setState(() => _orderSource = v);
                _load(forceRefresh: true);
              },
            ),
            _filterDropdown(
              value: _orderStatus,
              label: 'Restaurant status',
              items: const {
                'ALL': 'All statuses',
                'PENDING_CASHIER': 'Pending cashier',
                'IN_PREPARATION': 'In preparation',
                'OUT_FOR_DELIVERY': 'Out for delivery',
                'DELIVERED': 'Delivered',
                'CANCELLED': 'Cancelled',
              },
              onChanged: (v) {
                setState(() => _orderStatus = v);
                _load(forceRefresh: true);
              },
            ),
          ],
        ),
      ),
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
        value: value,
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
  }) {
    final hasDetails = details.isNotEmpty || subtitle != null;
    return SizedBox(
      width: 220,
      child: Card(
        elevation: 0,
        color: color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap:
              hasDetails
                  ? () => _showDashboardDetails(
                    title: title,
                    subtitle: subtitle,
                    details: details,
                  )
                  : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              height: 82,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      if (hasDetails)
                        const Icon(
                          Icons.info_outline,
                          color: Colors.white70,
                          size: 16,
                        ),
                    ],
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
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

  Widget _metricsRow(List<Widget> children) {
    return Wrap(spacing: 12, runSpacing: 12, children: children);
  }

  int _percent(int value, int total) =>
      total <= 0 ? 0 : ((value / total) * 100).round();

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

  @override
  Widget build(BuildContext context) {
    final s = _summary;

    return AppScaffold(
      showSearch: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Manager Dashboard',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Refresh',
                  onPressed:
                      _isLoading ? null : () => _load(forceRefresh: true),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _filterBar(),
            const SizedBox(height: 16),
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
              _sectionTitle('Performance Metrics'),
              _metricsRow([
                _metricCard(
                  'Pending confirmations',
                  '${s.restaurant.pendingConfirmations}',
                  Colors.orange.shade400,
                  subtitle: 'Restaurant orders waiting for confirmation.',
                  details: [
                    _DetailRow(
                      'Pending restaurant confirmations',
                      '${s.restaurant.pendingConfirmations}',
                    ),
                    _DetailRow('Action', 'Review in Restaurant Orders'),
                  ],
                ),
                _metricCard(
                  'Successful orders',
                  '${s.restaurant.delivered + s.catering.completed}',
                  Colors.green.shade600,
                  subtitle:
                      'Delivered restaurant orders plus completed catering events.',
                  details: [
                    _DetailRow(
                      'Restaurant delivered',
                      '${s.restaurant.delivered}',
                    ),
                    _DetailRow('Catering completed', '${s.catering.completed}'),
                    _DetailRow(
                      'Total successful',
                      '${s.restaurant.delivered + s.catering.completed}',
                    ),
                  ],
                ),
                _metricCard(
                  'Cancelled orders',
                  '${s.restaurant.cancelled + s.catering.cancelled}',
                  Colors.red.shade400,
                  subtitle: 'Cancelled work across restaurant and catering.',
                  details: [
                    _DetailRow(
                      'Restaurant cancelled',
                      '${s.restaurant.cancelled}',
                    ),
                    _DetailRow('Catering cancelled', '${s.catering.cancelled}'),
                    _DetailRow(
                      'Total cancelled',
                      '${s.restaurant.cancelled + s.catering.cancelled}',
                    ),
                  ],
                ),
                _metricCard(
                  'Catering accepted',
                  '${s.catering.acceptedTransactions}',
                  Colors.indigo.shade500,
                  subtitle: 'Catering/events that moved beyond inquiry.',
                  details: [
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
                ),
                _metricCard(
                  'Restaurant feedback',
                  '${s.restaurant.feedback.count}',
                  AntdTokens.blue,
                  subtitle:
                      'Average rating ${s.restaurant.feedback.averageStars.toStringAsFixed(1)} / 5.',
                  details: [
                    _DetailRow(
                      'Average stars',
                      s.restaurant.feedback.averageStars.toStringAsFixed(1),
                    ),
                    _DetailRow('Positive', '${s.restaurant.feedback.positiveCount}'),
                    _DetailRow('Neutral', '${s.restaurant.feedback.neutralCount}'),
                    _DetailRow('Negative', '${s.restaurant.feedback.negativeCount}'),
                  ],
                ),
                _metricCard(
                  'Catering feedback',
                  '${s.catering.feedback.complaintCount}',
                  Colors.deepPurple.shade400,
                  subtitle: 'Complaint count recorded in post-event analysis.',
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
              ]),
              const SizedBox(height: 16),
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
                    _DetailRow('Catering completed', '${s.catering.completed}'),
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
                          (s.restaurant.cancelled + s.catering.cancelled)
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
                          (s.restaurant.delivered + s.catering.completed)
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
                          (s.restaurant.cancelled + s.catering.cancelled)
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
                    _DetailRow('Today', formatPhp(s.restaurant.salesToday)),
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
                  subtitle: 'Completed catering/event revenue recorded today.',
                  details: [
                    _DetailRow('Today', formatPhp(s.catering.salesToday)),
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
                    _DetailRow('All sales', formatPhp(s.salesThisYear.all)),
                  ],
                ),
                _metricCard(
                  'Restaurant share',
                  '${_percent(s.salesThisYear.restaurant.round(), s.salesThisYear.all.round())}%',
                  const Color(0xFF1E1E1E),
                  subtitle: 'Restaurant portion of total year-to-date sales.',
                  details: [
                    _DetailRow(
                      'Restaurant',
                      formatPhp(s.salesThisYear.restaurant),
                    ),
                    _DetailRow('All sales', formatPhp(s.salesThisYear.all)),
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
                  subtitle: 'Restaurant + catering revenue for this year',
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
                  subtitle: 'New online catering/event inquiries this month.',
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
                  subtitle: 'Accepted events still waiting for down payment.',
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
                  subtitle: 'Paid down-payment jobs currently being processed.',
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
                  subtitle: 'Restaurant + catering orders created this year',
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
                      () =>
                          Navigator.of(context).pushNamed('/restaurant-orders'),
                  icon: const Icon(Icons.receipt_long),
                  label: const Text('Restaurant orders'),
                ),
              ),
            ],
          ],
        ),
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
