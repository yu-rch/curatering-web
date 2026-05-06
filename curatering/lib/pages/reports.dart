import 'package:flutter/material.dart';
import '../auth/auth_session.dart';
import '../auth/roles.dart';
import '../models/event_order.dart';
import '../services/events_api.dart';
import '../widgets/app_scaffold.dart';
import '../utils/order_calculations.dart';

class Reports extends StatefulWidget {
  const Reports({super.key});

  @override
  State<Reports> createState() => _ReportsState();
}

class _ReportsState extends State<Reports> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  List<EventOrderDto> _completedOrders = const <EventOrderDto>[];
  List<DateTime> _availableMonths = const <DateTime>[];

  bool _isLoading = false;
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

      final sortedMonths = months.toList()
        ..sort((a, b) => b.compareTo(a));

      // If there are no orders yet, show a reasonable default range.
      final fallback = List<DateTime>.generate(6, (i) {
        final m = DateTime(DateTime.now().year, DateTime.now().month - i, 1);
        return DateTime(m.year, m.month, 1);
      });

      setState(() {
        _completedOrders = orders;
        _availableMonths =
            sortedMonths.isEmpty ? fallback : sortedMonths;
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

  Widget _monthTile(DateTime month) {
    final isSelected = month.year == _selectedMonth.year && month.month == _selectedMonth.month;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedMonth = month;
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
              '${month.month.toString().padLeft(2, '0')} / ${month.year}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Monthly reports',
              style: TextStyle(color: isSelected ? Colors.white70 : Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(color: Colors.grey.shade700)),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderChart(String title, String valueText) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Text(' ', style: TextStyle(color: Colors.grey)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              valueText,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String title, String value, String dateLabel) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
            const SizedBox(height: 14),
            Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(
              dateLabel,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final monthOrders = _completedOrders.where((o) {
      if (o.scheduleSlots.isEmpty) return false;
      final d = DateTime.tryParse(o.scheduleSlots.first.date);
      if (d == null) return false;
      return d.year == _selectedMonth.year && d.month == _selectedMonth.month;
    }).toList();

    final filteredOrders = _searchQuery.isEmpty
        ? monthOrders
        : monthOrders.where((o) {
            final haystack = '${o.eventTitle} ${o.customerName} ${o.eventType}'.toLowerCase();
            return haystack.contains(_searchQuery);
          }).toList();

    final totalSales = filteredOrders.fold<double>(
      0.0,
      (sum, o) => sum + computeOrderTotalCost(o),
    );

    final dishCounts = <String, int>{};
    final eventTypeCounts = <String, int>{};
    for (final o in filteredOrders) {
      eventTypeCounts[o.eventType] = (eventTypeCounts[o.eventType] ?? 0) + 1;
      for (final item in o.menu) {
        dishCounts[item.dishName] = (dishCounts[item.dishName] ?? 0) + 1;
      }
    }
    final popularDish = dishCounts.entries.isEmpty
        ? 'N/A'
        : dishCounts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    final mostFrequentEventType = eventTypeCounts.entries.isEmpty
        ? 'N/A'
        : eventTypeCounts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;

    final topDishes = dishCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top5RequestedDish = topDishes.isEmpty
        ? 'N/A'
        : topDishes.take(5).map((e) => e.key).join(', ');

    return AppScaffold(
      showSearch: true,
      searchController: _searchController,
      onSearchChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Reports',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  'Monthly sales and event performance insights.',
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
            const SizedBox(height: 16),
            if (_isLoading)
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_errorMessage != null)
              Expanded(
                child: Center(
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              )
            else
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        children: [
                          for (final m in _availableMonths.take(4))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _monthTile(m),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      flex: 6,
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatCard(
                                  'Total Catering and Events',
                                  '${filteredOrders.length}',
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildStatCard(
                                  'Total Sales',
                                  formatPesos(totalSales),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Expanded(
                            child: _buildPlaceholderChart(
                              'Most Popular Dish',
                              popularDish,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Expanded(
                            child: _buildPlaceholderChart(
                              'Most Frequent Event Type',
                              mostFrequentEventType,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      flex: 2,
                      child: Column(
                        children: [
                          _buildInfoCard(
                            'Top Requested Dish',
                            top5RequestedDish,
                            '${_selectedMonth.month.toString().padLeft(2, '0')} ${_selectedMonth.year}',
                          ),
                          const SizedBox(height: 12),
                          _buildInfoCard(
                            'Most Popular Dish',
                            popularDish,
                            '${_selectedMonth.month.toString().padLeft(2, '0')} ${_selectedMonth.year}',
                          ),
                          const SizedBox(height: 12),
                          _buildInfoCard(
                            'Most Frequent Event Type',
                            mostFrequentEventType,
                            '${_selectedMonth.month.toString().padLeft(2, '0')} ${_selectedMonth.year}',
                          ),
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
