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
  final TextEditingController _orderNoController = TextEditingController();
  final TextEditingController _customerIdController = TextEditingController();
  final TextEditingController _minPriceController = TextEditingController();
  final TextEditingController _maxPriceController = TextEditingController();
  String _searchQuery = '';
  String _serviceTypeFilter = '';
  String _eventTypeFilter = '';
  String _orderNoFilter = '';
  String _customerIdFilter = '';
  double? _minPriceFilter;
  double? _maxPriceFilter;
  int? _completionYearFilter;
  int? _completionMonthFilter;
  int? _completionDayFilter;

  bool _isLoading = false;
  String? _errorMessage;

  List<_HistoryRow> _allRows = const <_HistoryRow>[];
  List<DateTime> _availableDates = const <DateTime>[];

  @override
  void initState() {
    super.initState();
    _loadCompletedOrders();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _orderNoController.dispose();
    _customerIdController.dispose();
    _minPriceController.dispose();
    _maxPriceController.dispose();
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
                ? computeLoyaltyPointsFromCost(o.totalCost)
                : computeLoyaltyPointsFromCost(totalCost);
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
                : computeLoyaltyPointsFromCost(total);
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

      final dates = <DateTime>{};
      for (final r in rows) {
        final d = r.fulfilmentDate;
        if (d == null) continue;
        dates.add(DateTime(d.year, d.month, d.day));
      }
      final sortedDates = dates.toList()..sort((a, b) => b.compareTo(a));

      setState(() {
        _allRows = rows;
        _availableDates = sortedDates;
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

  Widget _dateTile(DateTime date) {
    final isSelected =
        _completionYearFilter == date.year &&
        _completionMonthFilter == date.month &&
        _completionDayFilter == date.day;
    return GestureDetector(
      onTap:
          () => setState(() {
            _completionYearFilter = date.year;
            _completionMonthFilter = date.month;
            _completionDayFilter = date.day;
          }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? Colors.orange.shade400 : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${date.month.toString().padLeft(2, '0')} ${date.day}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              [
                'Sunday',
                'Monday',
                'Tuesday',
                'Wednesday',
                'Thursday',
                'Friday',
                'Saturday',
              ][date.weekday % 7],
              style: TextStyle(
                color: isSelected ? Colors.white70 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
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
    if (_orderNoFilter.isNotEmpty) {
      filteredRows =
          filteredRows
              .where((r) => r.orderNo.toLowerCase().contains(_orderNoFilter))
              .toList();
    }
    if (_customerIdFilter.isNotEmpty) {
      filteredRows =
          filteredRows
              .where(
                (r) => r.customerId.toLowerCase().contains(_customerIdFilter),
              )
              .toList();
    }
    if (_minPriceFilter != null) {
      filteredRows =
          filteredRows.where((r) => r.totalAmount >= _minPriceFilter!).toList();
    }
    if (_maxPriceFilter != null) {
      filteredRows =
          filteredRows.where((r) => r.totalAmount <= _maxPriceFilter!).toList();
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('service_$_serviceTypeFilter'),
                    value: _serviceTypeFilter,
                    decoration: const InputDecoration(
                      labelText: 'Service type',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('All service types'),
                      ),
                      ...{for (final r in _allRows) r.serviceType.trim()}
                          .where((t) => t.isNotEmpty)
                          .map(
                            (t) => DropdownMenuItem(value: t, child: Text(t)),
                          ),
                    ],
                    onChanged:
                        (v) => setState(() => _serviceTypeFilter = v ?? ''),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('event_$_eventTypeFilter'),
                    value: _eventTypeFilter,
                    decoration: const InputDecoration(
                      labelText: 'Event type',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
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
                    onChanged:
                        (v) => setState(() => _eventTypeFilter = v ?? ''),
                  ),
                ),
                SizedBox(
                  width: 150,
                  child: DropdownButtonFormField<int?>(
                    key: ValueKey('year_$_completionYearFilter'),
                    value: _completionYearFilter,
                    decoration: const InputDecoration(
                      labelText: 'Completion year',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('All years'),
                      ),
                      ...completionYears.map(
                        (y) =>
                            DropdownMenuItem<int?>(value: y, child: Text('$y')),
                      ),
                    ],
                    onChanged:
                        (v) => setState(() {
                          _completionYearFilter = v;
                          _completionMonthFilter = null;
                          _completionDayFilter = null;
                        }),
                  ),
                ),
                SizedBox(
                  width: 150,
                  child: DropdownButtonFormField<int?>(
                    key: ValueKey('month_$_completionMonthFilter'),
                    value: _completionMonthFilter,
                    decoration: const InputDecoration(
                      labelText: 'Completion month',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
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
                ),
                SizedBox(
                  width: 140,
                  child: DropdownButtonFormField<int?>(
                    key: ValueKey('day_$_completionDayFilter'),
                    value: _completionDayFilter,
                    decoration: const InputDecoration(
                      labelText: 'Completion day',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
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
                ),
                SizedBox(
                  width: 170,
                  child: TextField(
                    controller: _orderNoController,
                    decoration: const InputDecoration(
                      labelText: 'Order No.',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged:
                        (v) => setState(
                          () => _orderNoFilter = v.trim().toLowerCase(),
                        ),
                  ),
                ),
                SizedBox(
                  width: 170,
                  child: TextField(
                    controller: _customerIdController,
                    decoration: const InputDecoration(
                      labelText: 'Customer ID',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged:
                        (v) => setState(
                          () => _customerIdFilter = v.trim().toLowerCase(),
                        ),
                  ),
                ),
                SizedBox(
                  width: 140,
                  child: TextField(
                    controller: _minPriceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Min price',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged:
                        (v) => setState(
                          () => _minPriceFilter = double.tryParse(v.trim()),
                        ),
                  ),
                ),
                SizedBox(
                  width: 140,
                  child: TextField(
                    controller: _maxPriceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Max price',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged:
                        (v) => setState(
                          () => _maxPriceFilter = double.tryParse(v.trim()),
                        ),
                  ),
                ),
                if (_serviceTypeFilter.isNotEmpty ||
                    _eventTypeFilter.isNotEmpty ||
                    _completionYearFilter != null ||
                    _completionMonthFilter != null ||
                    _completionDayFilter != null ||
                    _orderNoFilter.isNotEmpty ||
                    _customerIdFilter.isNotEmpty ||
                    _minPriceFilter != null ||
                    _maxPriceFilter != null ||
                    _searchQuery.isNotEmpty)
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _serviceTypeFilter = '';
                        _eventTypeFilter = '';
                        _completionYearFilter = null;
                        _completionMonthFilter = null;
                        _completionDayFilter = null;
                        _orderNoFilter = '';
                        _customerIdFilter = '';
                        _minPriceFilter = null;
                        _maxPriceFilter = null;
                        _searchQuery = '';
                        _searchController.clear();
                        _orderNoController.clear();
                        _customerIdController.clear();
                        _minPriceController.clear();
                        _maxPriceController.clear();
                      });
                    },
                    icon: const Icon(Icons.filter_alt_off, size: 18),
                    label: const Text('Clear filters'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      children: [
                        if (_availableDates.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: OutlinedButton.icon(
                              onPressed:
                                  () => setState(() {
                                    _completionYearFilter = null;
                                    _completionMonthFilter = null;
                                    _completionDayFilter = null;
                                  }),
                              icon: const Icon(Icons.calendar_month, size: 18),
                              label: const Text('All dates'),
                            ),
                          ),
                        if (_availableDates.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            child: Center(
                              child: Text(
                                _isLoading
                                    ? 'Loading...'
                                    : (_errorMessage ?? 'No orders yet.'),
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            ),
                          )
                        else
                          for (final d in _availableDates.take(8))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _dateTile(d),
                            ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    flex: 6,
                    child: Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: Colors.black.withValues(alpha: 0.08),
                        ),
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
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            else if (filteredRows.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 40,
                                ),
                                child: Center(
                                  child: Text(
                                    'No orders match the selected filters.',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ),
                              )
                            else
                              Expanded(
                                child: PagedDataTable(
                                  title: 'Completed Order History',
                                  fullWidth: true,
                                  columns: const [
                                    DataColumn(label: Text('Order No.')),
                                    DataColumn(label: Text('Customer ID')),
                                    DataColumn(label: Text('Customer')),
                                    DataColumn(label: Text('Event')),
                                    DataColumn(label: Text('Service type')),
                                    DataColumn(label: Text('Event type')),
                                    DataColumn(
                                      label: Text('Fulfilment date & time'),
                                    ),
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
                                            DataCell(
                                              Text(tx.fulfilmentDateTime),
                                            ),
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
          ],
        ),
      ),
    );
  }
}
