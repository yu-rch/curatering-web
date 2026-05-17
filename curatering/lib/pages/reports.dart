import 'package:flutter/material.dart';

import '../auth/auth_session.dart';
import '../auth/roles.dart';
import '../models/event_order.dart';
import '../services/events_api.dart';
import '../services/reports_pdf_service.dart';
import '../utils/order_calculations.dart';
import '../widgets/antd_buttons.dart';
import '../widgets/antd_message.dart';
import '../widgets/antd_tokens.dart';
import '../widgets/app_scaffold.dart';

class Reports extends StatefulWidget {
  const Reports({super.key});

  @override
  State<Reports> createState() => _ReportsState();
}

class _ReportsState extends State<Reports> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  DateTime _selectedMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );
  List<EventOrderDto> _completedOrders = const <EventOrderDto>[];
  List<DateTime> _availableMonths = const <DateTime>[];

  bool _isLoading = false;
  bool _exportingPdf = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadCompletedOrders();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCompletedOrders() async {
    final role = AuthSession.instance.currentRole;
    final roleType = role == Role.supervisor ? 'supervisor' : 'manager';

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final orders = await EventsApi.instance.listOrders(
        status: 'completed',
        roleType: roleType,
        compact: true,
      );
      final months = <DateTime>{};
      for (final o in orders) {
        if (o.scheduleSlots.isEmpty) continue;
        final d = DateTime.tryParse(o.scheduleSlots.first.date);
        if (d == null) continue;
        months.add(DateTime(d.year, d.month, 1));
      }

      final sortedMonths = months.toList()..sort((a, b) => b.compareTo(a));

      final fallback = List<DateTime>.generate(6, (i) {
        final m = DateTime(DateTime.now().year, DateTime.now().month - i, 1);
        return DateTime(m.year, m.month, 1);
      });

      setState(() {
        _completedOrders = orders;
        _availableMonths = sortedMonths.isEmpty ? fallback : sortedMonths;
        if (!_availableMonths.contains(_selectedMonth) &&
            _availableMonths.isNotEmpty) {
          _selectedMonth = _availableMonths.first;
        }
      });
    } catch (e) {
      setState(() => _errorMessage = 'Failed to load reports.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<EventOrderDto> _ordersForSelectedMonth() {
    return _completedOrders.where((o) {
      if (o.scheduleSlots.isEmpty) return false;
      final d = DateTime.tryParse(o.scheduleSlots.first.date);
      if (d == null) return false;
      return d.year == _selectedMonth.year && d.month == _selectedMonth.month;
    }).toList();
  }

  List<EventOrderDto> _filteredOrders(List<EventOrderDto> monthOrders) {
    if (_searchQuery.isEmpty) return monthOrders;
    return monthOrders.where((o) {
      final haystack =
          '${o.eventTitle} ${o.customerName} ${o.eventType} ${o.orderType}'
              .toLowerCase();
      return haystack.contains(_searchQuery);
    }).toList();
  }

  MonthlyReportSnapshot _snapshotFor(List<EventOrderDto> orders) {
    return buildMonthlyReportSnapshot(month: _selectedMonth, orders: orders);
  }

  Future<void> _downloadPdf() async {
    final orders = _filteredOrders(_ordersForSelectedMonth());
    if (orders.isEmpty) {
      showAntdMessage(
        context,
        'No completed orders for this month to export.',
        type: AntdMessageType.warning,
      );
      return;
    }

    setState(() => _exportingPdf = true);
    try {
      await downloadMonthlyReportPdf(_snapshotFor(orders));
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

  Future<void> _previewPdf() async {
    final orders = _filteredOrders(_ordersForSelectedMonth());
    if (orders.isEmpty) {
      showAntdMessage(
        context,
        'No completed orders for this month to preview.',
        type: AntdMessageType.warning,
      );
      return;
    }

    setState(() => _exportingPdf = true);
    try {
      await previewMonthlyReportPdf(_snapshotFor(orders));
    } catch (e) {
      if (!mounted) return;
      showAntdMessage(
        context,
        'Could not open PDF preview: $e',
        type: AntdMessageType.error,
      );
    } finally {
      if (mounted) setState(() => _exportingPdf = false);
    }
  }

  Widget _monthTile(DateTime month) {
    final isSelected =
        month.year == _selectedMonth.year &&
        month.month == _selectedMonth.month;
    return GestureDetector(
      onTap: () => setState(() => _selectedMonth = month),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? AntdTokens.brandPrimary : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AntdTokens.brandPrimary : AntdTokens.borderSubtle,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${month.month.toString().padLeft(2, '0')} / ${month.year}',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isSelected ? AntdTokens.brandOnPrimary : AntdTokens.valueDark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Completed events',
              style: TextStyle(
                fontSize: 12,
                color: isSelected
                    ? AntdTokens.brandOnPrimary.withValues(alpha: 0.75)
                    : AntdTokens.labelMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AntdTokens.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: AntdTokens.labelMuted)),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AntdTokens.valueDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrdersTable(List<EventOrderDto> orders) {
    if (orders.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'No completed orders match this month or search.',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ),
      );
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AntdTokens.borderSubtle),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
          columns: const [
            DataColumn(label: Text('Date')),
            DataColumn(label: Text('Customer')),
            DataColumn(label: Text('Event')),
            DataColumn(label: Text('Type')),
            DataColumn(label: Text('Guests')),
            DataColumn(label: Text('Sales')),
          ],
          rows: [
            for (final o in orders)
              DataRow(
                cells: [
                  DataCell(Text(_formatOrderDate(o))),
                  DataCell(Text(o.customerName)),
                  DataCell(
                    Text(
                      o.eventTitle.isEmpty ? '—' : o.eventTitle,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  DataCell(Text(o.eventType.isEmpty ? o.orderType : o.eventType)),
                  DataCell(Text('${o.guestCount}')),
                  DataCell(Text(formatPesos(orderRevenue(o)))),
                ],
              ),
          ],
        ),
      ),
    );
  }

  String _formatOrderDate(EventOrderDto order) {
    if (order.scheduleSlots.isEmpty) return '—';
    final d = DateTime.tryParse(order.scheduleSlots.first.date);
    if (d == null) return order.scheduleSlots.first.date;
    return '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final monthOrders = _ordersForSelectedMonth();
    final filteredOrders = _filteredOrders(monthOrders);
    final snapshot = _snapshotFor(filteredOrders);

    return AppScaffold(
      showSearch: true,
      searchController: _searchController,
      onSearchChanged:
          (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
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
                        'Monthly sales and completed catering / event orders.',
                        style: TextStyle(color: AntdTokens.labelMuted),
                      ),
                    ],
                  ),
                ),
                AntdCancelButton(
                  label: 'Preview PDF',
                  onPressed: _exportingPdf ? null : _previewPdf,
                ),
                const SizedBox(width: 8),
                AntdPrimaryButton(
                  label: 'Download PDF',
                  loading: _exportingPdf,
                  onPressed: _exportingPdf ? null : _downloadPdf,
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: _isLoading ? null : _loadCompletedOrders,
                  icon: const Icon(Icons.refresh),
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
                      Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 12),
                      AntdPrimaryButton(
                        label: 'Retry',
                        onPressed: _loadCompletedOrders,
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 160,
                      child: ListView(
                        children: [
                          for (final m in _availableMonths)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _monthTile(m),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatCard(
                                  'Completed orders',
                                  '${filteredOrders.length}',
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildStatCard(
                                  'Total sales',
                                  formatPesos(snapshot.totalSales),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildStatCard(
                                  'Popular dish',
                                  snapshot.popularDish,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildStatCard(
                                  'Top event type',
                                  snapshot.mostFrequentEventType,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Orders — ${filteredOrders.length} record(s)',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Expanded(child: _buildOrdersTable(filteredOrders)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
