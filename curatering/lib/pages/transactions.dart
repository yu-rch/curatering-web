import 'package:flutter/material.dart';
import '../auth/auth_session.dart';
import '../auth/roles.dart';
import '../models/event_order.dart';
import '../services/events_api.dart';
import '../widgets/app_scaffold.dart';
import '../utils/order_calculations.dart';

class TransactionItem {
  final String orderNo;
  final String customerName;
  final String eventTitle;
  final String eventType;
  final String totalCost;
  final String loyaltyRewards;

  TransactionItem({
    required this.orderNo,
    required this.customerName,
    required this.eventTitle,
    required this.eventType,
    required this.totalCost,
    required this.loyaltyRewards,
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

  bool _isLoading = false;
  String? _errorMessage;

  List<EventOrderDto> _completedOrders = const <EventOrderDto>[];
  List<DateTime> _availableDates = const <DateTime>[];
  late DateTime _selectedDate;

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
      final orders =
          await EventsApi.instance.listOrders(status: 'completed', roleType: roleType);

      final dates = <DateTime>{};
      for (final o in orders) {
        if (o.scheduleSlots.isEmpty) continue;
        final d = DateTime.parse(o.scheduleSlots.first.date);
        dates.add(DateTime(d.year, d.month, d.day));
      }
      final sortedDates = dates.toList()..sort((a, b) => b.compareTo(a));

      setState(() {
        _completedOrders = orders;
        _availableDates = sortedDates;
        if (sortedDates.isNotEmpty) {
          _selectedDate = sortedDates.first;
        } else {
          _selectedDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
        }
      });
    } catch (e) {
      setState(() => _errorMessage = 'Failed to load orders.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _dateTile(DateTime date) {
    final isSelected = date == _selectedDate;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedDate = date;
        });
      },
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
              ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'][date.weekday % 7],
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

    final ordersForSelectedDate = _completedOrders.where((o) {
      if (o.scheduleSlots.isEmpty) return false;
      final d = DateTime.parse(o.scheduleSlots.first.date);
      final key = DateTime(d.year, d.month, d.day);
      return key == selectedKey;
    }).toList();

    final filteredOrders = _searchQuery.isEmpty
        ? ordersForSelectedDate
        : ordersForSelectedDate.where((o) {
            final haystack =
                '${o.eventTitle} ${o.customerName} ${o.eventType}'.toLowerCase();
            return haystack.contains(_searchQuery);
          }).toList();

    final orders = filteredOrders.map((o) {
      final totalCost = computeOrderTotalCost(o);
      final points = computeLoyaltyPointsFromCost(totalCost);
      return TransactionItem(
        orderNo: o.id,
        customerName: o.customerName,
        eventTitle: o.eventTitle,
        eventType: o.eventType,
        totalCost: formatPesos(totalCost),
        loyaltyRewards: '+$points pts',
      );
    }).toList();

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
              'Orders',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
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
                          for (final d in _availableDates.take(4))
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Orders',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 16),
                            if (_isLoading)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 40),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            else if (orders.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 40),
                                child: Center(
                                  child: Text(
                                    'No orders available for this date.',
                                    style: TextStyle(color: Colors.grey.shade600),
                                  ),
                                ),
                              )
                            else
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  columns: const [
                                    DataColumn(label: Text('Order No.')),
                                    DataColumn(label: Text('Customer Name')),
                                    DataColumn(label: Text('Event Title')),
                                    DataColumn(label: Text('Event Type')),
                                    DataColumn(label: Text('Total Cost')),
                                    DataColumn(label: Text('Loyalty Rewards')),
                                  ],
                                  rows: orders.map((tx) {
                                    return DataRow(cells: [
                                      DataCell(Text(tx.orderNo)),
                                      DataCell(Text(tx.customerName)),
                                      DataCell(Text(tx.eventTitle)),
                                      DataCell(Text(tx.eventType)),
                                      DataCell(Text(tx.totalCost)),
                                      DataCell(Text(tx.loyaltyRewards)),
                                    ]);
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
