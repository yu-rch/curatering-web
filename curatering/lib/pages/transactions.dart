import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../auth/auth_session.dart';
import '../auth/roles.dart';
import '../config.dart';
import '../models/event_order.dart';
import '../services/events_api.dart';
import '../utils/order_calculations.dart';
import '../utils/order_display_utils.dart';
import '../utils/order_type_utils.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/antd_buttons.dart';
import '../widgets/antd_staff.dart';
import '../widgets/antd_tokens.dart';
import '../widgets/paginated_data_table.dart';

class _HistoryRow {
  final String orderNo;
  final String customerId;
  final String customerName;
  final String eventTitle;
  final String serviceType;
  final String eventType;
  final String fulfilmentDateTime;
  final String totalCost;
  final double totalAmount;
  final String loyaltyRewards;
  final DateTime? fulfilmentDate;

  const _HistoryRow({
    required this.orderNo,
    required this.customerId,
    required this.customerName,
    required this.eventTitle,
    required this.serviceType,
    required this.eventType,
    required this.fulfilmentDateTime,
    required this.totalCost,
    required this.totalAmount,
    required this.loyaltyRewards,
    required this.fulfilmentDate,
  });
}

class Transactions extends StatefulWidget {
  const Transactions({super.key});

  @override
  State<Transactions> createState() => _TransactionsState();
}

class _TransactionsState extends State<Transactions> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _serviceTypeFilter = '';
  String _eventTypeFilter = '';
  int? _completionYearFilter;
  int? _completionMonthFilter;
  int? _completionDayFilter;

  bool _isLoading = false;
  String? _errorMessage;

  List<_HistoryRow> _allRows = const <_HistoryRow>[];
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

  String _displayOrderNo(EventOrderDto o) {
    final id = o.cateringId.trim();
    if (id.isNotEmpty) return id;
    return o.id.length > 8 ? o.id.substring(o.id.length - 8) : o.id;
  }

  Future<void> _loadCompletedOrders() async {
    final role = AuthSession.instance.currentRole;
    final roleType = role == Role.supervisor ? 'supervisor' : 'manager';

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final cateringFuture = EventsApi.instance.listOrders(
        status: 'completed',
        roleType: roleType,
        compact: true,
      );
      final restaurantFuture = _loadRestaurantHistory();

      final orders = await cateringFuture;
      final restaurantOrders = await restaurantFuture;

      final completedOnly =
          orders
              .where(
                (o) => o.status == 'completed' && o.finalStatus != 'cancelled',
              )
              .toList();

      final rows = <_HistoryRow>[];

      for (final o in completedOnly) {
        final totalCost = computeOrderTotalCost(o);
        final points =
            o.totalCost > 0
                ? computeLoyaltyPointsFromCost(
                  o.totalCost,
                  orderType: 'catering',
                )
                : computeLoyaltyPointsFromCost(
                  totalCost,
                  orderType: 'catering',
                );
        rows.add(
          _HistoryRow(
            orderNo: _displayOrderNo(o),
            customerId: o.customerId.trim().isEmpty ? '—' : o.customerId.trim(),
            customerName: o.customerName,
            eventTitle: o.eventTitle.trim().isEmpty ? '—' : o.eventTitle,
            serviceType: serviceTypeDisplayLabel(
              o.orderType,
              eventTitle: o.eventTitle,
            ),
            eventType: historyEventTypeColumnValue(
              serviceKind: 'catering',
              orderType: o.orderType,
              eventType: o.eventType,
            ),
            fulfilmentDateTime: formatFulfilmentDateTimeFromEvent(o),
            totalCost: formatPesos(o.totalCost > 0 ? o.totalCost : totalCost),
            totalAmount: o.totalCost > 0 ? o.totalCost : totalCost,
            loyaltyRewards: '+$points pts',
            fulfilmentDate: fulfilmentDateOnlyFromEvent(o),
          ),
        );
      }

      for (final o in restaurantOrders) {
        final total = _parseAmount(o['total_amount']);
        final pointsEarned = o['points_earned'];
        final points =
            pointsEarned is num && pointsEarned > 0
                ? pointsEarned.round()
                : computeLoyaltyPointsFromCost(
                  total,
                  orderType: 'restaurant',
                );
        rows.add(
          _HistoryRow(
            orderNo: formatRestaurantOrderNo(o),
            customerId:
                (o['customer_id'] ?? '').toString().trim().isEmpty
                    ? '—'
                    : (o['customer_id'] ?? '').toString().trim(),
            customerName:
                (o['full_name'] ?? o['guest_contact_email'] ?? '—').toString(),
            eventTitle: '—',
            serviceType: serviceTypeDisplayLabel('restaurant'),
            eventType: historyEventTypeColumnValue(
              serviceKind: 'restaurant',
              orderType: 'restaurant',
              eventType: '',
            ),
            fulfilmentDateTime: formatFulfilmentDateTimeFromRestaurant(o),
            totalCost: formatPesos(total),
            totalAmount: total,
            loyaltyRewards: '+$points pts',
            fulfilmentDate: fulfilmentDateOnlyFromRestaurant(o),
          ),
        );
      }

      rows.sort((a, b) {
        final ad = a.fulfilmentDate;
        final bd = b.fulfilmentDate;
        if (ad == null && bd == null) return 0;
        if (ad == null) return 1;
        if (bd == null) return -1;
        return bd.compareTo(ad);
      });

      setState(() {
        _allRows = rows;
      });
    } catch (e) {
      setState(() => _errorMessage = 'Failed to load orders: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<List<Map<String, dynamic>>> _loadRestaurantHistory() async {
    if (!AuthSession.instance.hasToken) return const [];

    final token = AuthSession.instance.token;
    if (token == null || token.isEmpty) return const [];

    final response = await http.get(
      Uri.parse(
        '$apiBaseUrl/api/manager/restaurant/orders?status=delivered&limit=200',
      ),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode != 200) return const [];

    final data = jsonDecode(response.body);
    final raw = data is Map ? data['orders'] : data;
    if (raw is! List) return const [];

    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .where(
          (o) => (o['status'] ?? '').toString().toLowerCase() == 'delivered',
        )
        .toList();
  }

  double _parseAmount(dynamic amount) {
    if (amount == null) return 0.0;
    if (amount is num) return amount.toDouble();
    if (amount is String) return double.tryParse(amount) ?? 0.0;
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    var filteredRows = _allRows.toList();

    if (_serviceTypeFilter.isNotEmpty) {
      filteredRows =
          filteredRows
              .where(
                (r) =>
                    r.serviceType.trim().toLowerCase() ==
                    _serviceTypeFilter.toLowerCase(),
              )
              .toList();
    }
    if (_eventTypeFilter.isNotEmpty) {
      filteredRows =
          filteredRows
              .where(
                (r) =>
                    r.eventType.trim().toLowerCase() ==
                    _eventTypeFilter.toLowerCase(),
              )
              .toList();
    }
    if (_completionYearFilter != null ||
        _completionMonthFilter != null ||
        _completionDayFilter != null) {
      filteredRows =
          filteredRows.where((r) {
            final d = r.fulfilmentDate;
            if (d == null) return false;
            if (_completionYearFilter != null &&
                d.year != _completionYearFilter) {
              return false;
            }
            if (_completionMonthFilter != null &&
                d.month != _completionMonthFilter) {
              return false;
            }
            if (_completionDayFilter != null && d.day != _completionDayFilter) {
              return false;
            }
            return true;
          }).toList();
    }
    if (_searchQuery.isNotEmpty) {
      filteredRows =
          filteredRows.where((r) {
            final haystack =
                '${r.orderNo} ${r.customerId} ${r.eventTitle} ${r.customerName} ${r.serviceType} ${r.eventType} ${r.fulfilmentDateTime}'
                    .toLowerCase();
            return haystack.contains(_searchQuery);
          }).toList();
    }

    final completionYears =
        {
            for (final r in _allRows)
              if (r.fulfilmentDate != null) r.fulfilmentDate!.year,
          }.toList()
          ..sort((a, b) => b.compareTo(a));
    final completionMonths =
        {
            for (final r in _allRows)
              if (r.fulfilmentDate != null &&
                  (_completionYearFilter == null ||
                      r.fulfilmentDate!.year == _completionYearFilter))
                r.fulfilmentDate!.month,
          }.toList()
          ..sort();
    final completionDays =
        {
            for (final r in _allRows)
              if (r.fulfilmentDate != null &&
                  (_completionYearFilter == null ||
                      r.fulfilmentDate!.year == _completionYearFilter) &&
                  (_completionMonthFilter == null ||
                      r.fulfilmentDate!.month == _completionMonthFilter))
                r.fulfilmentDate!.day,
          }.toList()
          ..sort();

    return AppScaffold(
      showSearch: true,
      searchController: _searchController,
      onSearchChanged:
          (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
      child: AntdPage(
        title: 'Order History',
        subtitle: 'Completed catering, event, and restaurant orders.',
        actions: [
          AntdSecondaryButton(
            label: 'Refresh',
            icon: Icons.refresh,
            onPressed: _loadCompletedOrders,
          ),
        ],
        filters: AntdToolbar(
          elevated: false,
          padding: EdgeInsets.zero,
          children: [
            AntdSelect<String>(
              label: 'Service type',
              width: 200,
              value: _serviceTypeFilter,
              items: [
                const DropdownMenuItem(
                  value: '',
                  child: Text('All service types'),
                ),
                ...{for (final r in _allRows) r.serviceType.trim()}
                    .where((t) => t.isNotEmpty)
                    .map((t) => DropdownMenuItem(value: t, child: Text(t))),
              ],
              onChanged: (v) => setState(() => _serviceTypeFilter = v ?? ''),
            ),
            AntdSelect<String>(
              label: 'Event type',
              width: 200,
              value: _eventTypeFilter,
              items: [
                const DropdownMenuItem(
                  value: '',
                  child: Text('All event types'),
                ),
                ...{
                  for (final r in _allRows)
                    if (r.eventType.trim().isNotEmpty &&
                        r.eventType != 'N/A' &&
                        r.eventType != '—')
                      r.eventType.trim(),
                }.map((t) => DropdownMenuItem(value: t, child: Text(t))),
              ],
              onChanged: (v) => setState(() => _eventTypeFilter = v ?? ''),
            ),
            AntdSelect<int?>(
              label: 'Completion year',
              width: 160,
              value: _completionYearFilter,
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('All years'),
                ),
                ...completionYears.map(
                  (y) => DropdownMenuItem<int?>(value: y, child: Text('$y')),
                ),
              ],
              onChanged:
                  (v) => setState(() {
                    _completionYearFilter = v;
                    _completionMonthFilter = null;
                    _completionDayFilter = null;
                  }),
            ),
            AntdSelect<int?>(
              label: 'Completion month',
              width: 160,
              value: _completionMonthFilter,
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('All months'),
                ),
                ...completionMonths.map(
                  (m) => DropdownMenuItem<int?>(
                    value: m,
                    child: Text(m.toString().padLeft(2, '0')),
                  ),
                ),
              ],
              onChanged:
                  (v) => setState(() {
                    _completionMonthFilter = v;
                    _completionDayFilter = null;
                  }),
            ),
            AntdSelect<int?>(
              label: 'Completion day',
              width: 150,
              value: _completionDayFilter,
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('All days'),
                ),
                ...completionDays.map(
                  (d) => DropdownMenuItem<int?>(
                    value: d,
                    child: Text(d.toString().padLeft(2, '0')),
                  ),
                ),
              ],
              onChanged: (v) => setState(() => _completionDayFilter = v),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Card(
                elevation: 0,
                color: AntdTokens.cardBg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: AntdTokens.borderSubtle),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Orders',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_isLoading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (filteredRows.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Center(
                            child: _errorMessage != null
                                ? Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _errorMessage!,
                                      style: TextStyle(
                                        color: AntdTokens.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    OutlinedButton.icon(
                                      onPressed: _loadCompletedOrders,
                                      icon: const Icon(Icons.refresh),
                                      label: const Text('Reload'),
                                    ),
                                  ],
                                )
                                : Text(
                                  'No orders match the selected filters.',
                                  style: TextStyle(
                                    color: AntdTokens.textSecondary,
                                  ),
                                ),
                          ),
                        )
                      else
                        Expanded(
                          child: PagedDataTable(
                            title: 'Completed Order History',
                            fullWidth: true,
                            forceVerticalScroll: true,
                            minTableWidth: 1200,
                            columns: const [
                              DataColumn(label: Text('Order No.')),
                              DataColumn(label: Text('Customer ID')),
                              DataColumn(label: Text('Customer')),
                              DataColumn(label: Text('Event')),
                              DataColumn(label: Text('Service type')),
                              DataColumn(label: Text('Event type')),
                              DataColumn(label: Text('Fulfilment date & time')),
                              DataColumn(label: Text('Total')),
                              DataColumn(label: Text('Loyalty')),
                            ],
                            rows:
                                filteredRows.map((tx) {
                                  return DataRow(
                                    cells: [
                                      DataCell(Text(tx.orderNo)),
                                      DataCell(Text(tx.customerId)),
                                      DataCell(Text(tx.customerName)),
                                      DataCell(Text(tx.eventTitle)),
                                      DataCell(Text(tx.serviceType)),
                                      DataCell(Text(tx.eventType)),
                                      DataCell(Text(tx.fulfilmentDateTime)),
                                      DataCell(Text(tx.totalCost)),
                                      DataCell(Text(tx.loyaltyRewards)),
                                    ],
                                  );
                                }).toList(),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
