import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../widgets/app_scaffold.dart';
import '../widgets/antd_staff.dart';
import '../widgets/paginated_data_table.dart';
import '../services/loyalty_rewards_store.dart';
import '../utils/responsive_layout.dart';
import '../auth/auth_session.dart';
import '../config.dart';

String get _apiBaseUrl => apiBaseUrl;

// Customer with loyalty points separated by order type
class LoyaltyCustomer {
  String id;
  String name;
  String email;
  int restaurantPoints;
  int cateringPoints;
  int totalPoints;

  LoyaltyCustomer({
    required this.id,
    required this.name,
    required this.email,
    this.restaurantPoints = 0,
    this.cateringPoints = 0,
    this.totalPoints = 0,
  });
}

// Customer Transaction
class CustomerTransaction {
  String orderNo;
  String eventTitle;
  String dateTime;
  DateTime? occurredAt;
  double totalCost;
  int loyaltyPointsObtained;
  int totalLoyaltyPoints;
  String reward;
  String orderType; // 'restaurant' or 'catering'

  CustomerTransaction({
    required this.orderNo,
    required this.eventTitle,
    required this.dateTime,
    this.occurredAt,
    required this.totalCost,
    required this.loyaltyPointsObtained,
    required this.totalLoyaltyPoints,
    required this.reward,
    this.orderType = 'restaurant',
  });
}

class ManageLoyaltyRewards extends StatefulWidget {
  const ManageLoyaltyRewards({Key? key}) : super(key: key);

  @override
  State<ManageLoyaltyRewards> createState() => _ManageLoyaltyRewardsState();
}

class _ManageLoyaltyRewardsState extends State<ManageLoyaltyRewards> {
  bool _showCustomersTab = true;
  String? _selectedCustomerId;
  String _pointsTab = 'all'; // 'all', 'restaurant', 'catering'
  String _customerSearchQuery = '';
  final TextEditingController _orderSearchController = TextEditingController();
  String _orderSearchQuery = '';
  String _orderDateFilter = 'all';
  double? _minCostFilter;
  double? _maxCostFilter;

  List<LoyaltyCustomer> _customers = [];
  List<CustomerTransaction> _orders = [];
  bool _isLoadingCustomers = true;
  bool _isLoadingOrders = true;
  String? _error;

  // Get conditions from store
  List<PointsCondition> get _pointsConditions =>
      LoyaltyRewardsStore.instance.pointsConditions;
  List<RewardsCondition> get _rewardsConditions =>
      LoyaltyRewardsStore.instance.rewardsConditions;

  // Get filtered customers based on search query
  List<LoyaltyCustomer> get _filteredCustomers {
    if (_customerSearchQuery.isEmpty) {
      return _customers;
    }
    return _customers.where((customer) {
      return customer.name.toLowerCase().contains(_customerSearchQuery) ||
          customer.email.toLowerCase().contains(_customerSearchQuery);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    LoyaltyRewardsStore.instance.ensureLoaded();
    LoyaltyRewardsStore.instance.addListener(_onStoreChanged);
    _loadCustomers();
  }

  @override
  void dispose() {
    _orderSearchController.dispose();
    LoyaltyRewardsStore.instance.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _onStoreChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadCustomers() async {
    setState(() {
      _isLoadingCustomers = true;
      _error = null;
    });

    try {
      final response = await http.get(
        Uri.parse('$_apiBaseUrl/api/loyalty/customers'),
        headers: {'Authorization': 'Bearer ${AuthSession.instance.token}'},
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final customersData = data['customers'] as List<dynamic>? ?? [];
        final customers = <LoyaltyCustomer>[];

        for (final customerData in customersData) {
          final customerId = customerData['id'] as String?;
          if (customerId == null) continue;

          final restaurantPoints =
              (customerData['restaurant_loyalty_points'] as num?)?.toInt() ?? 0;
          final cateringPoints =
              (customerData['catering_loyalty_points'] as num?)?.toInt() ?? 0;

          customers.add(
            LoyaltyCustomer(
              id: customerId,
              name: customerData['full_name'] as String? ?? 'Unknown',
              email: customerData['email'] as String? ?? '',
              restaurantPoints: restaurantPoints,
              cateringPoints: cateringPoints,
              totalPoints: restaurantPoints + cateringPoints,
            ),
          );
        }

        setState(() {
          _customers = customers;
          _isLoadingCustomers = false;
        });
      } else {
        setState(() {
          _error = data['error'] ?? 'Failed to load customers';
          _isLoadingCustomers = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
        _isLoadingCustomers = false;
      });
    }
  }

  String _determineOrderType(Map<String, dynamic> order) {
    final orderType =
        (order['order_type'] ?? order['orderType'] ?? '')
            .toString()
            .toLowerCase();
    if (orderType.contains('restaurant')) return 'restaurant';
    if (orderType.contains('catering')) return 'catering';
    // Check if order has catering-specific fields
    if (order['event_title'] != null || order['event_date'] != null) {
      return 'catering';
    }
    return 'restaurant';
  }

  Future<void> _loadCustomerOrders(String customerId) async {
    setState(() {
      _isLoadingOrders = true;
      _error = null;
    });

    try {
      final response = await http.get(
        Uri.parse('$_apiBaseUrl/api/admin/customers/$customerId/orders'),
        headers: {'Authorization': 'Bearer ${AuthSession.instance.token}'},
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final ordersData = data['orders'] as List<dynamic>? ?? [];
        final transactions = <CustomerTransaction>[];

        for (final order in ordersData) {
          final status =
              (order['status'] ?? order['order_status'] ?? '')
                  .toString()
                  .toLowerCase();
          if (status != 'completed' && status != 'delivered') continue;

          final totalCost = _toDouble(
            order['total_amount'] ?? order['total_cost'],
          );
          final orderType = _determineOrderType(order);
          final storedPoints =
              (order['loyalty_points_obtained'] as num?)?.toInt() ?? 0;
          final pointsEarned =
              storedPoints > 0
                  ? storedPoints
                  : LoyaltyRewardsStore.instance.getPointsForOrder(
                    totalCost,
                    orderType: orderType,
                  );
          final createdAt =
              order['created_at'] ?? order['createdAt'] ?? order['dateTime'];
          final occurredAt = _parseDate(createdAt?.toString());

          transactions.add(
            CustomerTransaction(
              orderNo:
                  (order['order_no'] ??
                          order['order_id'] ??
                          order['catering_id'] ??
                          order['id'] ??
                          '')
                      .toString(),
              eventTitle: order['event_title'] as String? ?? 'Order',
              dateTime: _formatDateTime(occurredAt),
              occurredAt: occurredAt,
              totalCost: totalCost,
              loyaltyPointsObtained: pointsEarned,
              totalLoyaltyPoints: pointsEarned, // Simplified for now
              reward: 'Points earned',
              orderType: orderType,
            ),
          );
        }

        setState(() {
          _orders = transactions;
          _isLoadingOrders = false;
        });
      } else {
        setState(() {
          _error = data['error'] ?? 'Failed to load orders';
          _isLoadingOrders = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
        _isLoadingOrders = false;
      });
    }
  }

  DateTime? _parseDate(String? dateStr) {
    if (dateStr == null || dateStr.trim().isEmpty) return null;
    try {
      return DateTime.parse(dateStr).toLocal();
    } catch (_) {
      return null;
    }
  }

  String _formatDateTime(DateTime? date) {
    if (date == null) return '—';
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final suffix = date.hour >= 12 ? 'PM' : 'AM';
    return '${date.month}/${date.day}/${date.year} $hour:$minute $suffix';
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  bool _matchesOrderDateFilter(CustomerTransaction order) {
    if (_orderDateFilter == 'all') return true;
    final date = order.occurredAt;
    if (date == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    return switch (_orderDateFilter) {
      'today' => day == today,
      '7d' => !day.isBefore(today.subtract(const Duration(days: 6))),
      '30d' => !day.isBefore(today.subtract(const Duration(days: 29))),
      'year' => date.year == now.year,
      _ => true,
    };
  }

  List<CustomerTransaction> get _filteredCustomerOrders {
    Iterable<CustomerTransaction> orders = _orders;
    if (_pointsTab == 'restaurant') {
      orders = orders.where((o) => o.orderType == 'restaurant');
    } else if (_pointsTab == 'catering') {
      orders = orders.where((o) => o.orderType == 'catering');
    }
    orders = orders.where(_matchesOrderDateFilter);
    if (_minCostFilter != null) {
      orders = orders.where((o) => o.totalCost >= _minCostFilter!);
    }
    if (_maxCostFilter != null) {
      orders = orders.where((o) => o.totalCost <= _maxCostFilter!);
    }
    if (_orderSearchQuery.isNotEmpty) {
      orders = orders.where((order) {
        final haystack =
            '${order.orderNo} ${order.eventTitle} ${order.dateTime} ${order.orderType} ${order.totalCost} ${order.loyaltyPointsObtained}'
                .toLowerCase();
        return haystack.contains(_orderSearchQuery);
      });
    }
    return orders.toList();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      showSearch: true,
      child: Row(
        children: [
          // Left sidebar - Manage Points and Rewards
          Container(
            width: 250,
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.grey.shade100,
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MANAGE POINTS AND',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'REWARDS',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                // Tab buttons
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _showCustomersTab = true;
                              _selectedCustomerId = null;
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                _showCustomersTab
                                    ? const Color(0xFFFFC107)
                                    : Colors.grey.shade200,
                            foregroundColor: Colors.black,
                            elevation: 0,
                          ),
                          child: const Text('CUSTOMERS'),
                        ),
                      ),
                    ],
                  ),
                ),
                // ALL header
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'ALL',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                // Search field for customers
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search customers by name or email...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _customerSearchQuery = value.toLowerCase();
                      });
                    },
                  ),
                ),
                // Customer list
                Expanded(
                  child: ListView.builder(
                    itemCount: _filteredCustomers.length,
                    itemBuilder: (context, index) {
                      final customer = _filteredCustomers[index];
                      final isSelected = _selectedCustomerId == customer.id;
                      return ListTile(
                        selected: isSelected,
                        selectedTileColor: Colors.grey.shade200,
                        title: Text(
                          customer.name,
                          style: const TextStyle(fontSize: 14),
                        ),
                        trailing: Text(
                          '${customer.totalPoints} pts',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        onTap: () {
                          setState(() {
                            _selectedCustomerId = customer.id;
                            _showCustomersTab = true;
                            _loadCustomerOrders(customer.id);
                          });
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          // Main content area
          Expanded(
            child:
                _showCustomersTab && _selectedCustomerId != null
                    ? _buildCustomerTransactionsView()
                    : _buildPointsAndRewardsView(),
          ),
        ],
      ),
    );
  }

  Widget _buildPointsAndRewardsView() {
    return SingleChildScrollView(
      padding: appPagePadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLoyaltyAnalyticsCard(),
          const SizedBox(height: 24),
          _buildSectionHeader(
            'POINTS EARNING',
            () => _showAddPointsConditionDialog(),
          ),
          const SizedBox(height: 16),
          _buildPointsTable(),
          const SizedBox(height: 32),
          _buildSectionHeader(
            'RESTAURANT REWARDS',
            () => _showAddRewardsConditionDialog(orderType: 'restaurant'),
          ),
          const SizedBox(height: 16),
          _buildRewardsTable(orderType: 'restaurant'),
          const SizedBox(height: 32),
          _buildSectionHeader(
            'CATERING REWARDS',
            () => _showAddRewardsConditionDialog(orderType: 'catering'),
          ),
          const SizedBox(height: 16),
          _buildRewardsTable(orderType: 'catering'),
        ],
      ),
    );
  }

  Widget _buildLoyaltyAnalyticsCard() {
    return _LoyaltyRewardCalculatorCard(
      pointsConditions: _pointsConditions,
      rewardsConditions: _rewardsConditions,
    );
  }

  Widget _buildCustomerTransactionsView() {
    final selectedCustomer = _customers.firstWhere(
      (c) => c.id == _selectedCustomerId,
      orElse: () => LoyaltyCustomer(id: '', name: '', email: ''),
    );

    return Padding(
      padding: appPagePadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Customer info header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFC107),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selectedCustomer.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  selectedCustomer.email,
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildPointsChip(
                      'Restaurant',
                      selectedCustomer.restaurantPoints,
                      Colors.blue,
                    ),
                    _buildPointsChip(
                      'Catering',
                      selectedCustomer.cateringPoints,
                      const Color.fromARGB(255, 117, 83, 33),
                    ),
                    _buildPointsChip(
                      'Total',
                      selectedCustomer.totalPoints,
                      Colors.green,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Points type tabs
          Row(
            children: [
              _buildPointsTab('All', 'all'),
              const SizedBox(width: 8),
              _buildPointsTab('Restaurant', 'restaurant'),
              const SizedBox(width: 8),
              _buildPointsTab('Catering', 'catering'),
            ],
          ),
          const SizedBox(height: 16),
          _buildCustomerOrdersToolbar(),
          const SizedBox(height: 16),
          Expanded(
            child:
                _isLoadingOrders
                    ? const Center(child: CircularProgressIndicator())
                    : _buildCustomerTransactionsTable(),
          ),
        ],
      ),
    );
  }

  Widget _buildPointsChip(String label, int points, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color),
      ),
      child: Text(
        '$label: $points pts',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildPointsTab(String label, String tabValue) {
    final isSelected = _pointsTab == tabValue;
    return Flexible(
      child: ElevatedButton(
        onPressed: () {
          setState(() {
            _pointsTab = tabValue;
          });
        },
        style: ElevatedButton.styleFrom(
          backgroundColor:
              isSelected ? const Color(0xFFFFC107) : Colors.grey.shade200,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        child: Text(label),
      ),
    );
  }

  Widget _buildCustomerOrdersToolbar() {
    final maxCost =
        _orders.isEmpty
            ? 1000.0
            : _orders
                .map((o) => o.totalCost)
                .fold<double>(0, (max, value) => value > max ? value : max);
    final sliderMax =
        (((maxCost <= 0 ? 1000 : maxCost) / 500).ceil() * 500).toDouble();
    final range = RangeValues(
      (_minCostFilter ?? 0).clamp(0, sliderMax).toDouble(),
      (_maxCostFilter ?? sliderMax).clamp(0, sliderMax).toDouble(),
    );

    return AntdToolbar(
      children: [
        AntdSearchInput(
          controller: _orderSearchController,
          hintText: 'Search customer orders',
          width: 260,
          onChanged:
              (value) => setState(
                () => _orderSearchQuery = value.trim().toLowerCase(),
              ),
          onClear: () {
            _orderSearchController.clear();
            setState(() => _orderSearchQuery = '');
          },
        ),
        AntdSelect<String>(
          label: 'Datetime',
          width: 180,
          value: _orderDateFilter,
          items: const [
            DropdownMenuItem(value: 'all', child: Text('All dates')),
            DropdownMenuItem(value: 'today', child: Text('Today')),
            DropdownMenuItem(value: '7d', child: Text('Last 7 days')),
            DropdownMenuItem(value: '30d', child: Text('Last 30 days')),
            DropdownMenuItem(value: 'year', child: Text('This year')),
          ],
          onChanged:
              (value) => setState(() => _orderDateFilter = value ?? 'all'),
        ),
        SizedBox(
          width: 320,
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Cost range',
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '₱${range.start.toStringAsFixed(2)} - ₱${range.end.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 12),
                ),
                RangeSlider(
                  values: range,
                  min: 0,
                  max: sliderMax,
                  divisions: (sliderMax / 500).round().clamp(1, 200),
                  labels: RangeLabels(
                    '₱${range.start.toStringAsFixed(0)}',
                    '₱${range.end.toStringAsFixed(0)}',
                  ),
                  onChanged:
                      (next) => setState(() {
                        _minCostFilter = next.start <= 0 ? null : next.start;
                        _maxCostFilter =
                            next.end >= sliderMax ? null : next.end;
                      }),
                ),
              ],
            ),
          ),
        ),
        TextButton.icon(
          onPressed:
              (_orderSearchQuery.isEmpty &&
                      _orderDateFilter == 'all' &&
                      _minCostFilter == null &&
                      _maxCostFilter == null)
                  ? null
                  : () {
                    setState(() {
                      _orderSearchQuery = '';
                      _orderDateFilter = 'all';
                      _minCostFilter = null;
                      _maxCostFilter = null;
                      _orderSearchController.clear();
                    });
                  },
          icon: const Icon(Icons.filter_alt_off, size: 18),
          label: const Text('Clear filters'),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, VoidCallback onAddPressed) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFC107),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        ElevatedButton.icon(
          onPressed: onAddPressed,
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Add Condition'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4CAF50),
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildPointsTable() {
    return Card(
      elevation: 2,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: const Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    'Order Type',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Minimum Cost',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Points Application',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'Actions',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          // Rows
          ..._pointsConditions.map((condition) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(condition.orderType.toUpperCase()),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text('₱${condition.minimumCost.toStringAsFixed(2)}'),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text('${condition.pointsApplication} pts'),
                  ),
                  Expanded(
                    flex: 1,
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.edit,
                            color: Colors.red,
                            size: 20,
                          ),
                          onPressed:
                              () => _showEditPointsConditionDialog(condition),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.archive,
                            color: Colors.orange,
                            size: 20,
                          ),
                          onPressed: () => _showArchivePointsDialog(condition),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildRewardsTable({required String orderType}) {
    final conditions =
        _rewardsConditions.where((c) => c.orderType == orderType).toList();
    if (conditions.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No ${orderType == 'catering' ? 'catering' : 'restaurant'} rewards configured yet.',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ),
      );
    }
    return Card(
      elevation: 2,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: const Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    'Minimum Points',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Maximum Points',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Reward',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'Size',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'Actions',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          // Rows
          ...conditions.map((condition) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text('${condition.minimumPoints} pts'),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text('${condition.maximumPoints} pts'),
                  ),
                  Expanded(flex: 2, child: Text(condition.reward)),
                  Expanded(flex: 1, child: Text(condition.size)),
                  Expanded(
                    flex: 1,
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.edit,
                            color: Colors.red,
                            size: 20,
                          ),
                          onPressed:
                              () => _showEditRewardsConditionDialog(condition),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.archive,
                            color: Colors.orange,
                            size: 20,
                          ),
                          onPressed: () => _showArchiveRewardsDialog(condition),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildCustomerTransactionsTable() {
    final filteredOrders = _filteredCustomerOrders;
    return PagedDataTable(
      title: 'Customer Loyalty Orders',
      enableSearch: false,
      fullWidth: true,
      maxTableHeight: MediaQuery.sizeOf(context).height,
      columns: const [
        DataColumn(label: Text('Order No.')),
        DataColumn(label: Text('Event Title')),
        DataColumn(label: Text('Date & Time')),
        DataColumn(label: Text('Type')),
        DataColumn(label: Text('Total Cost')),
        DataColumn(label: Text('Points Earned')),
      ],
      rows:
          filteredOrders.map((order) {
            return DataRow(
              cells: [
                DataCell(Text(order.orderNo)),
                DataCell(Text(order.eventTitle)),
                DataCell(Text(order.dateTime)),
                DataCell(Text(order.orderType.toUpperCase())),
                DataCell(Text('₱${order.totalCost.toStringAsFixed(2)}')),
                DataCell(Text('+${order.loyaltyPointsObtained} pts')),
              ],
            );
          }).toList(),
    );
  }

  // Dialogs
  void _showAddPointsConditionDialog() {
    final minimumCostController = TextEditingController(text: '2000.00');
    final pointsController = TextEditingController(text: '50');
    String selectedOrderType = 'restaurant';
    String? errorMessage;

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => Dialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 420),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Close button
                        Align(
                          alignment: Alignment.topRight,
                          child: IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close, color: Colors.black),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Title
                        const Text(
                          'POINTS - ADD CONDITION',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Error message
                        if (errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: Colors.red.shade700,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    errorMessage!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.red.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Form fields
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                const SizedBox(
                                  width: 100,
                                  child: Text(
                                    'ORDER TYPE',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                ),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: selectedOrderType,
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      border: OutlineInputBorder(),
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                        value: 'restaurant',
                                        child: Text('Restaurant'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'catering',
                                        child: Text('Catering'),
                                      ),
                                    ],
                                    onChanged: (value) {
                                      setDialogState(
                                        () => selectedOrderType = value!,
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const SizedBox(
                                  width: 100,
                                  child: Text(
                                    'MINIMUM COST',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                ),
                                Expanded(
                                  child: TextField(
                                    controller: minimumCostController,
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      prefixText: '₱',
                                      border: OutlineInputBorder(),
                                    ),
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const SizedBox(
                                  width: 100,
                                  child: Text(
                                    'POINTS APPLICATION',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                ),
                                Expanded(
                                  child: TextField(
                                    controller: pointsController,
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      suffixText: 'pts',
                                      border: OutlineInputBorder(),
                                    ),
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // Submit button
                        ElevatedButton(
                          onPressed: () {
                            final minCost = double.tryParse(
                              minimumCostController.text,
                            );
                            final points = int.tryParse(pointsController.text);

                            if (minCost == null || minCost <= 0) {
                              setDialogState(
                                () =>
                                    errorMessage =
                                        'Please enter a valid minimum cost',
                              );
                              return;
                            }
                            if (points == null || points <= 0) {
                              setDialogState(
                                () =>
                                    errorMessage = 'Please enter valid points',
                              );
                              return;
                            }

                            LoyaltyRewardsStore.instance.addPointsCondition(
                              minimumCost: minCost,
                              pointsApplication: points,
                              orderType: selectedOrderType,
                            );
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFC024),
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(
                              vertical: 10,
                              horizontal: 32,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'ADD',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ),
    );
  }

  void _showEditPointsConditionDialog(PointsCondition condition) {
    final minimumCostController = TextEditingController(
      text: condition.minimumCost.toStringAsFixed(2),
    );
    final pointsController = TextEditingController(
      text: condition.pointsApplication.toString(),
    );
    String? errorMessage;

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => Dialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 420),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Close button
                        Align(
                          alignment: Alignment.topRight,
                          child: IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close, color: Colors.black),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Title
                        const Text(
                          'POINTS - EDIT CONDITION',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Error message
                        if (errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: Colors.red.shade700,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    errorMessage!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.red.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Form fields
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                const SizedBox(
                                  width: 100,
                                  child: Text(
                                    'MINIMUM COST',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                ),
                                Expanded(
                                  child: TextField(
                                    controller: minimumCostController,
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      prefixText: '₱',
                                      border: OutlineInputBorder(),
                                    ),
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const SizedBox(
                                  width: 100,
                                  child: Text(
                                    'POINTS APPLICATION',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                ),
                                Expanded(
                                  child: TextField(
                                    controller: pointsController,
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      suffixText: 'pts',
                                      border: OutlineInputBorder(),
                                    ),
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // Submit button
                        ElevatedButton(
                          onPressed: () {
                            final minCost = double.tryParse(
                              minimumCostController.text,
                            );
                            final points = int.tryParse(pointsController.text);

                            if (minCost == null || minCost <= 0) {
                              setDialogState(
                                () =>
                                    errorMessage =
                                        'Please enter a valid minimum cost',
                              );
                              return;
                            }
                            if (points == null || points <= 0) {
                              setDialogState(
                                () =>
                                    errorMessage = 'Please enter valid points',
                              );
                              return;
                            }

                            condition.minimumCost = minCost;
                            condition.pointsApplication = points;
                            LoyaltyRewardsStore.instance.updatePointsCondition(
                              condition,
                            );
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFC024),
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(
                              vertical: 10,
                              horizontal: 32,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'SAVE',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ),
    );
  }

  void _showArchivePointsDialog(PointsCondition condition) {
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Close button
                  Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.black),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Title
                  const Text(
                    'ARCHIVE CONDITION',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Are you sure you want to archive this condition?',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  // Details
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const SizedBox(
                            width: 100,
                            child: Text(
                              'MINIMUM COST',
                              style: TextStyle(fontSize: 11),
                            ),
                          ),
                          Text(
                            '₱${condition.minimumCost.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const SizedBox(
                            width: 100,
                            child: Text(
                              'POINTS',
                              style: TextStyle(fontSize: 11),
                            ),
                          ),
                          Text(
                            '${condition.pointsApplication} pts',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            LoyaltyRewardsStore.instance.archivePointsCondition(
                              condition.id,
                            );
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFC024),
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'YES',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey.shade300,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'CANCEL',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
    );
  }

  void _showAddRewardsConditionDialog({String orderType = 'restaurant'}) {
    final minPointsController = TextEditingController(text: '1000');
    final maxPointsController = TextEditingController(text: '1500');
    final rewardController = TextEditingController(text: 'Shrimp Tempura');
    final sizeController = TextEditingController(text: '50 pcs');
    final selectedOrderType = orderType;
    String? errorMessage;

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => Dialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 420),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Close button
                        Align(
                          alignment: Alignment.topRight,
                          child: IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close, color: Colors.black),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Title
                        const Text(
                          'REWARDS - ADD CONDITION',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Error message
                        if (errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: Colors.red.shade700,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    errorMessage!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.red.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Form fields
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                const SizedBox(
                                  width: 100,
                                  child: Text(
                                    'MINIMUM POINTS',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                ),
                                Expanded(
                                  child: TextField(
                                    controller: minPointsController,
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      suffixText: 'pts',
                                      border: OutlineInputBorder(),
                                    ),
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const SizedBox(
                                  width: 100,
                                  child: Text(
                                    'MAXIMUM POINTS',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                ),
                                Expanded(
                                  child: TextField(
                                    controller: maxPointsController,
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      suffixText: 'pts',
                                      border: OutlineInputBorder(),
                                    ),
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const SizedBox(
                                  width: 100,
                                  child: Text(
                                    'REWARD',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                ),
                                Expanded(
                                  child: TextField(
                                    controller: rewardController,
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const SizedBox(
                                  width: 100,
                                  child: Text(
                                    'SIZE',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                ),
                                Expanded(
                                  child: TextField(
                                    controller: sizeController,
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // Submit button
                        ElevatedButton(
                          onPressed: () {
                            final minPoints = int.tryParse(
                              minPointsController.text,
                            );
                            final maxPoints = int.tryParse(
                              maxPointsController.text,
                            );

                            if (minPoints == null || minPoints <= 0) {
                              setDialogState(
                                () =>
                                    errorMessage =
                                        'Please enter valid minimum points',
                              );
                              return;
                            }
                            if (maxPoints == null || maxPoints <= 0) {
                              setDialogState(
                                () =>
                                    errorMessage =
                                        'Please enter valid maximum points',
                              );
                              return;
                            }
                            if (rewardController.text.isEmpty) {
                              setDialogState(
                                () => errorMessage = 'Please enter a reward',
                              );
                              return;
                            }

                            LoyaltyRewardsStore.instance.addRewardsCondition(
                              minimumPoints: minPoints,
                              maximumPoints: maxPoints,
                              reward: rewardController.text,
                              size: sizeController.text,
                              orderType: selectedOrderType,
                            );
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFC024),
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(
                              vertical: 10,
                              horizontal: 32,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'ADD',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ),
    );
  }

  void _showEditRewardsConditionDialog(RewardsCondition condition) {
    final minPointsController = TextEditingController(
      text: condition.minimumPoints.toString(),
    );
    final maxPointsController = TextEditingController(
      text: condition.maximumPoints.toString(),
    );
    final rewardController = TextEditingController(text: condition.reward);
    final sizeController = TextEditingController(text: condition.size);
    String? errorMessage;

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => Dialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 420),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Close button
                        Align(
                          alignment: Alignment.topRight,
                          child: IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close, color: Colors.black),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Title
                        const Text(
                          'REWARDS - EDIT CONDITION',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Error message
                        if (errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: Colors.red.shade700,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    errorMessage!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.red.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Form fields
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                const SizedBox(
                                  width: 100,
                                  child: Text(
                                    'MINIMUM POINTS',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                ),
                                Expanded(
                                  child: TextField(
                                    controller: minPointsController,
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      suffixText: 'pts',
                                      border: OutlineInputBorder(),
                                    ),
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const SizedBox(
                                  width: 100,
                                  child: Text(
                                    'MAXIMUM POINTS',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                ),
                                Expanded(
                                  child: TextField(
                                    controller: maxPointsController,
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      suffixText: 'pts',
                                      border: OutlineInputBorder(),
                                    ),
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const SizedBox(
                                  width: 100,
                                  child: Text(
                                    'REWARD',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                ),
                                Expanded(
                                  child: TextField(
                                    controller: rewardController,
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const SizedBox(
                                  width: 100,
                                  child: Text(
                                    'SIZE',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                ),
                                Expanded(
                                  child: TextField(
                                    controller: sizeController,
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // Submit button
                        ElevatedButton(
                          onPressed: () {
                            final minPoints = int.tryParse(
                              minPointsController.text,
                            );
                            final maxPoints = int.tryParse(
                              maxPointsController.text,
                            );

                            if (minPoints == null || minPoints <= 0) {
                              setDialogState(
                                () =>
                                    errorMessage =
                                        'Please enter valid minimum points',
                              );
                              return;
                            }
                            if (maxPoints == null || maxPoints <= 0) {
                              setDialogState(
                                () =>
                                    errorMessage =
                                        'Please enter valid maximum points',
                              );
                              return;
                            }
                            if (rewardController.text.isEmpty) {
                              setDialogState(
                                () => errorMessage = 'Please enter a reward',
                              );
                              return;
                            }

                            condition.minimumPoints = minPoints;
                            condition.maximumPoints = maxPoints;
                            condition.reward = rewardController.text;
                            condition.size = sizeController.text;
                            LoyaltyRewardsStore.instance.updateRewardsCondition(
                              condition,
                            );
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFC024),
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(
                              vertical: 10,
                              horizontal: 32,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'SAVE',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ),
    );
  }

  void _showArchiveRewardsDialog(RewardsCondition condition) {
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Close button
                  Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.black),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Title
                  const Text(
                    'ARCHIVE CONDITION',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Are you sure you want to archive this condition?',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  // Details
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const SizedBox(
                            width: 100,
                            child: Text(
                              'MINIMUM POINTS',
                              style: TextStyle(fontSize: 11),
                            ),
                          ),
                          Text(
                            '${condition.minimumPoints} pts',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const SizedBox(
                            width: 100,
                            child: Text(
                              'MAXIMUM POINTS',
                              style: TextStyle(fontSize: 11),
                            ),
                          ),
                          Text(
                            '${condition.maximumPoints} pts',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const SizedBox(
                            width: 100,
                            child: Text(
                              'REWARD',
                              style: TextStyle(fontSize: 11),
                            ),
                          ),
                          Text(
                            condition.reward,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const SizedBox(
                            width: 100,
                            child: Text('SIZE', style: TextStyle(fontSize: 11)),
                          ),
                          Text(
                            condition.size,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            LoyaltyRewardsStore.instance
                                .archiveRewardsCondition(condition.id);
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFC024),
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'YES',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey.shade300,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'CANCEL',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
    );
  }
}

/// Built-in calculator to estimate whether loyalty rewards are sustainable.
class _LoyaltyRewardCalculatorCard extends StatefulWidget {
  const _LoyaltyRewardCalculatorCard({
    required this.pointsConditions,
    required this.rewardsConditions,
  });

  final List<PointsCondition> pointsConditions;
  final List<RewardsCondition> rewardsConditions;

  @override
  State<_LoyaltyRewardCalculatorCard> createState() =>
      _LoyaltyRewardCalculatorCardState();
}

class _LoyaltyRewardCalculatorCardState
    extends State<_LoyaltyRewardCalculatorCard> {
  final _avgOrderController = TextEditingController(text: '2500');
  final _ordersPerMonthController = TextEditingController(text: '40');
  final _rewardCostController = TextEditingController(text: '800');
  final _pointsToRedeemController = TextEditingController(text: '1000');
  String _channel = 'restaurant';

  @override
  void dispose() {
    _avgOrderController.dispose();
    _ordersPerMonthController.dispose();
    _rewardCostController.dispose();
    _pointsToRedeemController.dispose();
    super.dispose();
  }

  PointsCondition? _pointsRule() {
    for (final c in widget.pointsConditions) {
      if (!c.isActive) continue;
      if (c.orderType == _channel) return c;
    }
    return null;
  }

  RewardsCondition? _rewardRule() {
    final pts = int.tryParse(_pointsToRedeemController.text) ?? 0;
    for (final r in widget.rewardsConditions) {
      if (!r.isActive || r.orderType != _channel) continue;
      if (pts >= r.minimumPoints && pts <= r.maximumPoints) return r;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final avgOrder = double.tryParse(_avgOrderController.text) ?? 0;
    final ordersPerMonth = int.tryParse(_ordersPerMonthController.text) ?? 0;
    final rewardCost = double.tryParse(_rewardCostController.text) ?? 0;
    final pointsToRedeem = int.tryParse(_pointsToRedeemController.text) ?? 0;

    final rule = _pointsRule();
    final ptsPerOrder =
        rule != null && avgOrder >= rule.minimumCost
            ? rule.pointsApplication
            : 0;
    final monthlyPoints = ptsPerOrder * ordersPerMonth;
    final ordersToRedeem =
        ptsPerOrder > 0 ? (pointsToRedeem / ptsPerOrder).ceil() : 0;
    final revenueToRedeem = ordersToRedeem * avgOrder;
    final marginAtRisk = revenueToRedeem > 0 ? rewardCost / revenueToRedeem : 0;
    final reward = _rewardRule();

    final riskColor =
        marginAtRisk > 0.15
            ? Colors.red.shade700
            : marginAtRisk > 0.08
            ? Colors.orange.shade800
            : Colors.green.shade700;
    final riskLabel =
        marginAtRisk > 0.15
            ? 'High risk — reward may be too easy to earn'
            : marginAtRisk > 0.08
            ? 'Moderate — review reward cost or points required'
            : 'Looks sustainable at these assumptions';

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'LOYALTY ANALYTICS',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              'Estimate whether customers can redeem rewards faster than you earn margin.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'restaurant', label: Text('Restaurant')),
                ButtonSegment(value: 'catering', label: Text('Catering')),
              ],
              selected: {_channel},
              onSelectionChanged: (s) => setState(() => _channel = s.first),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 160,
                  child: TextField(
                    controller: _avgOrderController,
                    decoration: const InputDecoration(
                      labelText: 'Avg order (PHP)',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                SizedBox(
                  width: 160,
                  child: TextField(
                    controller: _ordersPerMonthController,
                    decoration: const InputDecoration(
                      labelText: 'Orders / month',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                SizedBox(
                  width: 160,
                  child: TextField(
                    controller: _rewardCostController,
                    decoration: const InputDecoration(
                      labelText: 'Reward cost (PHP)',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                SizedBox(
                  width: 160,
                  child: TextField(
                    controller: _pointsToRedeemController,
                    decoration: const InputDecoration(
                      labelText: 'Points to redeem',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (rule == null)
              Text(
                'No active points rule for $_channel — add one under Points Earning.',
                style: TextStyle(color: Colors.orange.shade800, fontSize: 12),
              )
            else ...[
              Text(
                'Earns $ptsPerOrder pts per order (min PHP ${rule.minimumCost.toStringAsFixed(0)})',
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 8),
              Text(
                '~$monthlyPoints pts/month at $ordersPerMonth orders',
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 8),
              Text(
                'Redeem $pointsToRedeem pts ≈ $ordersToRedeem orders (PHP ${revenueToRedeem.toStringAsFixed(0)} revenue) for PHP ${rewardCost.toStringAsFixed(0)} reward',
                style: const TextStyle(fontSize: 12),
              ),
              if (reward != null)
                Text(
                  'Matches tier: ${reward.reward} (${reward.size})',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              const SizedBox(height: 8),
              Text(
                'Reward cost ≈ ${(marginAtRisk * 100).toStringAsFixed(1)}% of revenue to redeem — $riskLabel',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: riskColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
