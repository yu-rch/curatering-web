import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../widgets/app_scaffold.dart';
import '../services/loyalty_rewards_store.dart';
import '../utils/responsive_layout.dart';
import '../auth/auth_session.dart';
import '../config.dart';

// Runtime fallback for dev mode
String get _apiBaseUrl =>
    apiBaseUrl.isEmpty
        ? 'https://ffgifzwwqdjeyyedaciu.supabase.co/rest/v1/'
        : apiBaseUrl;

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
  double totalCost;
  int loyaltyPointsObtained;
  int totalLoyaltyPoints;
  String reward;
  String orderType; // 'restaurant' or 'catering'

  CustomerTransaction({
    required this.orderNo,
    required this.eventTitle,
    required this.dateTime,
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
        Uri.parse('$_apiBaseUrl/api/admin/customers'),
        headers: {'Authorization': 'Bearer ${AuthSession.instance.token}'},
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final customersData = data['customers'] as List<dynamic>? ?? [];
        final customers = <LoyaltyCustomer>[];

        for (final customerData in customersData) {
          final customerId = customerData['id'] as String?;
          if (customerId == null) continue;

          final loyaltyPoints =
              (customerData['loyalty_points'] as num?)?.toInt() ?? 0;

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
          if (order['status'] != 'completed') continue;

          final totalCost = (order['total_amount'] as num?)?.toDouble() ?? 0.0;
          final orderType = _determineOrderType(order);
          final pointsEarned = LoyaltyRewardsStore.instance.getPointsForOrder(
            totalCost,
            orderType: orderType,
          );

          transactions.add(
            CustomerTransaction(
              orderNo:
                  order['order_no'] as String? ?? order['id'] as String? ?? '',
              eventTitle: order['event_title'] as String? ?? 'Order',
              dateTime: _formatDate(order['created_at'] as String?),
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

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return '';
    }
  }

  Future<void> _recalculateLoyaltyPoints() async {
    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/api/admin/recalculate-loyalty-points'),
        headers: {'Authorization': 'Bearer ${AuthSession.instance.token}'},
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Recalculated points for ${data['updatedCount']} customers',
            ),
            backgroundColor: Colors.green,
          ),
        );
        _loadCustomers(); // Reload customers with updated points
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to recalculate points: ${response.statusCode}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
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
          // REWARDS Section (now includes order type dropdown)
          _buildSectionHeader(
            'REWARDS',
            () => _showAddRewardsConditionDialog(),
            showRecalculate: true,
          ),
          const SizedBox(height: 16),
          _buildRewardsTable(),
        ],
      ),
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
        color: color.withOpacity(0.2),
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

  Widget _buildSectionHeader(
    String title,
    VoidCallback onAddPressed, {
    bool showRecalculate = false,
  }) {
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
        if (showRecalculate)
          ElevatedButton.icon(
            onPressed: _recalculateLoyaltyPoints,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Recalculate Points'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2196F3),
              foregroundColor: Colors.white,
            ),
          ),
        if (showRecalculate) const SizedBox(width: 8),
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

  Widget _buildRewardsTable() {
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
          ..._rewardsConditions.map((condition) {
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
    // Filter orders based on selected tab
    List<CustomerTransaction> filteredOrders;
    if (_pointsTab == 'restaurant') {
      filteredOrders =
          _orders.where((o) => o.orderType == 'restaurant').toList();
    } else if (_pointsTab == 'catering') {
      filteredOrders = _orders.where((o) => o.orderType == 'catering').toList();
    } else {
      filteredOrders = _orders;
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
                    'Order No.',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Event Title',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Date & Time',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'Type',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'Total Cost',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'Points\nEarned',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          // Rows
          ...filteredOrders.map((order) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  Expanded(flex: 2, child: Text(order.orderNo)),
                  Expanded(flex: 2, child: Text(order.eventTitle)),
                  Expanded(flex: 2, child: Text(order.dateTime)),
                  Expanded(
                    flex: 1,
                    child: Text(
                      order.orderType.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        color:
                            order.orderType == 'restaurant'
                                ? Colors.blue
                                : Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text('₱${order.totalCost.toStringAsFixed(2)}'),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text('+${order.loyaltyPointsObtained} pts'),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
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
                                    initialValue: selectedOrderType,
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

  void _showAddRewardsConditionDialog() {
    final minPointsController = TextEditingController(text: '1000');
    final maxPointsController = TextEditingController(text: '1500');
    final rewardController = TextEditingController(text: 'Shrimp Tempura');
    final sizeController = TextEditingController(text: '50 pcs');
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
