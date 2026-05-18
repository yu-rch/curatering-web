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

class _HistoryRow {
  final String orderNo;
  final String customerName;
  final String eventTitle;
  final String serviceType;
  final String eventType;
  final String fulfilmentDateTime;
  final String totalCost;
  final String loyaltyRewards;
  final DateTime? fulfilmentDate;

  const _HistoryRow({
    required this.orderNo,
    required this.customerName,
    required this.eventTitle,
    required this.serviceType,
    required this.eventType,
    required this.fulfilmentDateTime,
    required this.totalCost,
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

  bool _isLoading = false;
  String? _errorMessage;

  List<_HistoryRow> _allRows = const <_HistoryRow>[];
  List<DateTime> _availableDates = const <DateTime>[];
  DateTime _selectedDate = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );

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
    final id = o.inquiryId.trim();
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

      final completedOnly = orders
          .where((o) => o.status == 'completed' && o.finalStatus != 'cancelled')
          .toList();

      final rows = <_HistoryRow>[];

      for (final o in completedOnly) {
        final totalCost = computeOrderTotalCost(o);
        final points = o.totalCost > 0
            ? computeLoyaltyPointsFromCost(o.totalCost)
            : computeLoyaltyPointsFromCost(totalCost);
        rows.add(
          _HistoryRow(
            orderNo: _displayOrderNo(o),
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
            totalCost: formatPesos(
              o.totalCost > 0 ? o.totalCost : totalCost,
            ),
            loyaltyRewards: '+$points pts',
            fulfilmentDate: fulfilmentDateOnlyFromEvent(o),
          ),
        );
      }

      for (final o in restaurantOrders) {
        final total = _parseAmount(o['total_amount']);
        final pointsEarned = o['points_earned'];
        final points = pointsEarned is num && pointsEarned > 0
            ? pointsEarned.round()
            : computeLoyaltyPointsFromCost(total);
        rows.add(
          _HistoryRow(
            orderNo: formatRestaurantOrderNo(o),
            customerName: (o['full_name'] ?? o['guest_contact_email'] ?? '—')
                .toString(),
            eventTitle: '—',
            serviceType: serviceTypeDisplayLabel('restaurant'),
            eventType: historyEventTypeColumnValue(
              serviceKind: 'restaurant',
              orderType: 'restaurant',
              eventType: '',
            ),
            fulfilmentDateTime: formatFulfilmentDateTimeFromRestaurant(o),
            totalCost: formatPesos(total),
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
        if (sortedDates.isNotEmpty) {
          _selectedDate = sortedDates.first;
        }
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
        .where((o) => (o['status'] ?? '').toString().toLowerCase() == 'delivered')
        .toList();
  }

  double _parseAmount(dynamic amount) {
    if (amount == null) return 0.0;
    if (amount is num) return amount.toDouble();
    if (amount is String) return double.tryParse(amount) ?? 0.0;
    return 0.0;
  }

  Widget _dateTile(DateTime date) {
    final isSelected = date == _selectedDate;
    return GestureDetector(
      onTap: () => setState(() => _selectedDate = date),
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
    final selectedKey = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );

    var filteredRows = _allRows.where((r) {
      final d = r.fulfilmentDate;
      if (d == null) return false;
      return DateTime(d.year, d.month, d.day) == selectedKey;
    }).toList();

    if (_serviceTypeFilter.isNotEmpty) {
      filteredRows = filteredRows
          .where(
            (r) =>
                r.serviceType.trim().toLowerCase() ==
                _serviceTypeFilter.toLowerCase(),
          )
          .toList();
    }
    if (_eventTypeFilter.isNotEmpty) {
      filteredRows = filteredRows
          .where(
            (r) =>
                r.eventType.trim().toLowerCase() ==
                _eventTypeFilter.toLowerCase(),
          )
          .toList();
    }
    if (_searchQuery.isNotEmpty) {
      filteredRows = filteredRows.where((r) {
        final haystack =
            '${r.orderNo} ${r.eventTitle} ${r.customerName} ${r.serviceType} ${r.eventType} ${r.fulfilmentDateTime}'
                .toLowerCase();
        return haystack.contains(_searchQuery);
      }).toList();
    }

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
            const Text(
              'Order History',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  'Completed catering, event, and restaurant orders.',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _loadCompletedOrders,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E1E1E),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String>(
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
                      ...{
                        for (final r in _allRows) r.serviceType.trim(),
                      }.where((t) => t.isNotEmpty).map(
                        (t) => DropdownMenuItem(value: t, child: Text(t)),
                      ),
                    ],
                    onChanged: (v) =>
                        setState(() => _serviceTypeFilter = v ?? ''),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String>(
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
                      }.map(
                        (t) => DropdownMenuItem(value: t, child: Text(t)),
                      ),
                    ],
                    onChanged: (v) =>
                        setState(() => _eventTypeFilter = v ?? ''),
                  ),
                ),
                if (_serviceTypeFilter.isNotEmpty ||
                    _eventTypeFilter.isNotEmpty ||
                    _searchQuery.isNotEmpty)
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _serviceTypeFilter = '';
                        _eventTypeFilter = '';
                        _searchQuery = '';
                        _searchController.clear();
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
                                    'No orders for this date.',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ),
                              )
                            else
                              Expanded(
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: DataTable(
                                    columns: const [
                                      DataColumn(label: Text('Order No.')),
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
                                    rows: filteredRows.map((tx) {
                                      return DataRow(
                                        cells: [
                                          DataCell(Text(tx.orderNo)),
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
