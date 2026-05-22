import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config.dart';
import '../auth/auth_session.dart';
import '../utils/responsive_layout.dart';
import '../utils/order_display_utils.dart';

class RestaurantTransactionsPage extends StatefulWidget {
  const RestaurantTransactionsPage({super.key});

  @override
  State<RestaurantTransactionsPage> createState() =>
      _RestaurantTransactionsPageState();
}

class _RestaurantTransactionsPageState extends State<RestaurantTransactionsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  List<Map<String, dynamic>> _confirmationOrders = [];
  List<Map<String, dynamic>> _processingOrders = [];
  List<Map<String, dynamic>> _completedOrders = [];

  // Performance optimization: Cache last fetch time
  DateTime? _lastFetchTime;
  static const Duration _cacheValidity = Duration(minutes: 2);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadOrders();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders({bool forceRefresh = false}) async {
    if (_isLoading) return; // Prevent multiple simultaneous loads

    // Check if user is authenticated
    if (!AuthSession.instance.hasToken) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please log in to view restaurant orders'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    // Check cache validity
    if (!forceRefresh && _lastFetchTime != null) {
      final timeSinceLastFetch = DateTime.now().difference(_lastFetchTime!);
      if (timeSinceLastFetch < _cacheValidity) {
        return; // Use cached data
      }
    }

    final stopwatch = Stopwatch()..start();
    setState(() => _isLoading = true);

    try {
      final token = await _getAuthToken();
      print(
        'Debug: Using token for restaurant orders: ${token.substring(0, 20)}...',
      );

      final parseTime = Stopwatch()..start();
      final buckets = await Future.wait([
        _fetchManagerOrders(token, statuses: const ['PENDING_CASHIER']),
        _fetchManagerOrders(
          token,
          statuses: const ['IN_PREPARATION', 'OUT_FOR_DELIVERY'],
        ),
        _fetchManagerOrders(token, statuses: const ['DELIVERED', 'CANCELLED']),
      ]);
      final allOrders = [...buckets[0], ...buckets[1], ...buckets[2]];
      parseTime.stop();

      // Optimized filtering with pre-allocated lists. Keep this classification
      // as a second pass so rows with legacy status labels still land correctly.
      final confirmationOrders = <Map<String, dynamic>>[];
      final processingOrders = <Map<String, dynamic>>[];
      final completedOrders = <Map<String, dynamic>>[];

      for (final order in allOrders) {
        final status = _normalizedStatus(order['status']);
        if (_isPendingStatus(status)) {
          confirmationOrders.add(order);
        } else if (_isCompletedStatus(status) || _isCancelledStatus(status)) {
          completedOrders.add(order);
        } else if (_isProcessingStatus(status)) {
          processingOrders.add(order);
        } else {
          processingOrders.add(order);
        }
      }

      setState(() {
        _confirmationOrders = confirmationOrders;
        _processingOrders = processingOrders;
        _completedOrders = completedOrders;
        _lastFetchTime = DateTime.now();
      });

      stopwatch.stop();
      print(
        'Performance: Load took ${stopwatch.elapsedMilliseconds}ms, Parse took ${parseTime.elapsedMilliseconds}ms',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading orders: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<List<Map<String, dynamic>>> _fetchManagerOrders(
    String token, {
    required List<String> statuses,
    int limit = 200,
  }) async {
    final query = <String, String>{
      'limit': '$limit',
      if (statuses.isNotEmpty) 'status': statuses.join(','),
    };
    final uri = Uri.parse(
      '$apiBaseUrl/api/manager/restaurant/orders',
    ).replace(queryParameters: query);
    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      final errorMessage =
          response.statusCode == 401
              ? 'Authentication failed. Please log in again.'
              : response.statusCode == 403
              ? 'Access denied. You need manager permissions to view orders.'
              : 'Failed to load orders (Status: ${response.statusCode})';
      throw Exception(errorMessage);
    }

    return _parseResponse(response.body)
        .whereType<Map>()
        .map((order) => Map<String, dynamic>.from(order))
        .toList();
  }

  void _refreshOrders() {
    _loadOrders(forceRefresh: true);
  }

  Future<String> _getAuthToken() async {
    final token = AuthSession.instance.token;
    if (token == null || token.isEmpty) {
      throw Exception('No authentication token found. Please log in again.');
    }
    return token;
  }

  // Helper method to safely parse amount from database (string or num)
  double _parseAmount(dynamic amount) {
    if (amount == null) return 0.0;
    if (amount is num) return amount.toDouble();
    if (amount is String) {
      return double.tryParse(amount) ?? 0.0;
    }
    return 0.0;
  }

  String _managerOrderId(Map<String, dynamic> order) {
    for (final key in const [
      'id',
      'order_id',
      'order_no',
      'orderId',
      'orderNo',
      'order_number',
      'orderNumber',
      'restaurant_order_id',
      'restaurantOrderId',
      'public_order_id',
      'publicOrderId',
    ]) {
      final value = order[key]?.toString().trim();
      if (value != null && value.isNotEmpty && value.toLowerCase() != 'null') {
        return value;
      }
    }
    return '';
  }

  bool _hasOrderIdValue(dynamic value) {
    final s = value?.toString().trim();
    return s != null && s.isNotEmpty && s.toLowerCase() != 'null';
  }

  Map<String, dynamic> _normalizeManagerOrderMap(Map<String, dynamic> order) {
    final normalized = Map<String, dynamic>.from(order);
    final managerId = _managerOrderId(normalized);
    if (managerId.isNotEmpty) {
      normalized['manager_order_id'] = managerId;
      if (!_hasOrderIdValue(normalized['order_id'])) {
        normalized['order_id'] = managerId;
      }
      if (!_hasOrderIdValue(normalized['order_no'])) {
        normalized['order_no'] = managerId;
      }
    }
    return normalized;
  }

  String _responseErrorMessage(http.Response response) {
    final body = response.body.trim();
    if (body.startsWith('<!DOCTYPE') || body.startsWith('<html')) {
      return 'Server returned an HTML error page (${response.statusCode}). Please refresh and try again.';
    }
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        return (decoded['error'] ?? decoded['message'] ?? body).toString();
      }
    } catch (_) {}
    return body.isEmpty ? 'Request failed (${response.statusCode})' : body;
  }

  String _normalizedStatus(dynamic raw) {
    final value = (raw ?? '').toString().trim().toLowerCase();
    return value.replaceAll(' ', '_');
  }

  bool _isPendingStatus(String status) =>
      status == 'pending_cashier' ||
      status == 'pending' ||
      status == 'waiting_for_order_confirmation' ||
      status == 'waiting_for_payment_confirmation';

  bool _isProcessingStatus(String status) =>
      status == 'in_preparation' ||
      status == 'confirmed' ||
      status == 'preparing' ||
      status == 'out_for_delivery' ||
      status == 'order_confirmed';

  bool _isCompletedStatus(String status) =>
      status == 'delivered' || status == 'completed';

  bool _isCancelledStatus(String status) => status == 'cancelled';

  String _formatDateTimeCell(dynamic raw) {
    if (raw == null) return 'N/A';
    final s = raw.toString().trim();
    if (s.isEmpty || s == 'null') return 'N/A';

    final dt = DateTime.tryParse(s);
    if (dt == null) return s;

    final local = dt.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
  }

  List<dynamic> _parseResponse(String responseBody) {
    try {
      final parsed = jsonDecode(responseBody);
      if (parsed is Map<String, dynamic> && parsed.containsKey('orders')) {
        final orders = parsed['orders'] as List<dynamic>;
        // Pre-process the data to avoid repeated parsing
        return orders.map((order) {
          if (order is Map<String, dynamic>) {
            // Ensure items is already parsed
            final items = order['items'];
            if (items is String) {
              try {
                order['items'] = jsonDecode(items);
              } catch (e) {
                order['items'] = [];
              }
            }
            return _normalizeManagerOrderMap(order);
          }
          return order;
        }).toList();
      }
      return parsed as List<dynamic>;
    } catch (e) {
      return [];
    }
  }

  Future<void> _updateOrderStatus(
    String orderId,
    String newStatus, {
    String? deliveryUrl,
  }) async {
    if (orderId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot update order: order id is missing.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Optimistic update: Update UI immediately
    final originalOrder = _findOrderById(orderId);
    if (originalOrder != null) {
      _optimisticallyUpdateOrder(originalOrder, newStatus, deliveryUrl);
    }

    try {
      final token = await _getAuthToken();
      final updateData = {'status': newStatus};
      if (deliveryUrl != null) {
        updateData['delivery_tracking_url'] = deliveryUrl;
      }

      final response = await http.put(
        Uri.parse(
          '$apiBaseUrl/api/manager/restaurant/orders/${Uri.encodeComponent(orderId)}',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(updateData),
      );

      if (response.statusCode != 200) {
        // Revert optimistic update on failure
        if (originalOrder != null) {
          _revertOrderUpdate(orderId, originalOrder);
        }
        throw Exception('Failed to update order');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Order status updated to $newStatus')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating order: $e')));
      }
    }
  }

  Map<String, dynamic>? _findOrderById(String orderId) {
    for (final orderList in [
      _confirmationOrders,
      _processingOrders,
      _completedOrders,
    ]) {
      try {
        final order = orderList.firstWhere(
          (order) => _managerOrderId(order) == orderId,
        );
        return Map<String, dynamic>.from(order);
      } catch (e) {
        // Continue searching
      }
    }
    return null;
  }

  void _optimisticallyUpdateOrder(
    Map<String, dynamic> originalOrder,
    String newStatus,
    String? deliveryUrl,
  ) {
    setState(() {
      // Remove from current list
      _removeOrderFromAllLists(originalOrder['id']?.toString() ?? '');

      // Add to appropriate new list with updated status
      final updatedOrder = Map<String, dynamic>.from(originalOrder);
      updatedOrder['status'] = newStatus;
      if (deliveryUrl != null) {
        updatedOrder['delivery_tracking_url'] = deliveryUrl;
      }

      final s = _normalizedStatus(newStatus);
      if (_isPendingStatus(s)) {
        _confirmationOrders.add(updatedOrder);
      } else if (_isCompletedStatus(s) || _isCancelledStatus(s)) {
        _completedOrders.add(updatedOrder);
      } else {
        _processingOrders.add(updatedOrder);
      }
    });
  }

  void _revertOrderUpdate(String orderId, Map<String, dynamic> originalOrder) {
    setState(() {
      _removeOrderFromAllLists(orderId);

      final status = _normalizedStatus(originalOrder['status']);
      if (_isPendingStatus(status)) {
        _confirmationOrders.add(originalOrder);
      } else if (_isCompletedStatus(status) || _isCancelledStatus(status)) {
        _completedOrders.add(originalOrder);
      } else {
        _processingOrders.add(originalOrder);
      }
    });
  }

  void _removeOrderFromAllLists(String orderId) {
    _confirmationOrders.removeWhere(
      (order) => _managerOrderId(order) == orderId,
    );
    _processingOrders.removeWhere((order) => _managerOrderId(order) == orderId);
    _completedOrders.removeWhere((order) => _managerOrderId(order) == orderId);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey.shade50,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: Colors.white,
            elevation: 1,
            child: Row(
              children: [
                Expanded(
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: const Color(0xFFFFC024),
                    labelColor: const Color(0xFFFFC024),
                    unselectedLabelColor: Colors.grey.shade600,
                    labelStyle: const TextStyle(fontWeight: FontWeight.w600),
                    tabs: [
                      Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.pending_actions, size: 20),
                            const SizedBox(width: 8),
                            Text('Pending (${_confirmationOrders.length})'),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.local_shipping, size: 20),
                            const SizedBox(width: 8),
                            Text('Processing (${_processingOrders.length})'),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle, size: 20),
                            const SizedBox(width: 8),
                            Text('Completed (${_completedOrders.length})'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _refreshOrders,
                  tooltip: 'Refresh Orders',
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
            child: Text(
              'Track confirmations, delivery progress, and completed orders.',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ),
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : TabBarView(
                      controller: _tabController,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _buildConfirmationTab(),
                        _buildProcessingTab(),
                        _buildCompletedTab(),
                      ],
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmationTab() {
    if (_confirmationOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No orders awaiting payment confirmation',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: appPagePadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary Cards
          Row(
            children: [
              _buildSummaryCard(
                'Total Orders',
                '${_confirmationOrders.length}',
                Icons.receipt_long,
                Colors.blue,
              ),
              const SizedBox(width: 16),
              _buildSummaryCard(
                'Pending Revenue',
                '$_currencySymbol${_confirmationOrders.fold<num>(0, (sum, order) => sum + _parseAmount(order['total_amount'])).toStringAsFixed(2)}',
                Icons.attach_money,
                Colors.green,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Orders Table
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade200,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Table Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(flex: 1, child: _buildTableHeader('Order ID')),
                      Expanded(flex: 2, child: _buildTableHeader('Customer')),
                      Expanded(flex: 1, child: _buildTableHeader('Phone')),
                      Expanded(flex: 1, child: _buildTableHeader('Items')),
                      Expanded(flex: 1, child: _buildTableHeader('Total')),
                      Expanded(flex: 1, child: _buildTableHeader('Date')),
                      Expanded(flex: 2, child: _buildTableHeader('Actions')),
                    ],
                  ),
                ),
                // Table Rows
                ..._confirmationOrders.asMap().entries.map((entry) {
                  final index = entry.key;
                  final order = entry.value;
                  return _buildOrderTableRow(order, index);
                }).toList(),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildProcessingTab() {
    if (_processingOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_shipping, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No orders in processing',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: appPagePadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary Cards
          Row(
            children: [
              _buildSummaryCard(
                'Processing Orders',
                '${_processingOrders.length}',
                Icons.local_shipping,
                Colors.orange,
              ),
              const SizedBox(width: 16),
              _buildSummaryCard(
                'Processing Revenue',
                '$_currencySymbol${_processingOrders.fold<num>(0, (sum, order) => sum + _parseAmount(order['total_amount'])).toStringAsFixed(2)}',
                Icons.attach_money,
                Colors.green,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Orders Table
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade200,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Table Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(flex: 1, child: _buildTableHeader('Order ID')),
                      Expanded(flex: 2, child: _buildTableHeader('Customer')),
                      Expanded(flex: 1, child: _buildTableHeader('Status')),
                      Expanded(flex: 1, child: _buildTableHeader('Items')),
                      Expanded(flex: 1, child: _buildTableHeader('Total')),
                      Expanded(flex: 1, child: _buildTableHeader('Date')),
                      Expanded(flex: 2, child: _buildTableHeader('Actions')),
                    ],
                  ),
                ),
                // Table Rows
                ..._processingOrders.asMap().entries.map((entry) {
                  final index = entry.key;
                  final order = entry.value;
                  return _buildProcessingOrderTableRow(order, index);
                }).toList(),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildCompletedTab() {
    if (_completedOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No completed orders yet',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: appPagePadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary Cards
          Row(
            children: [
              _buildSummaryCard(
                'Completed Orders',
                '${_completedOrders.where((o) => _isCompletedStatus(_normalizedStatus(o['status']))).length}',
                Icons.check_circle,
                Colors.green,
              ),
              const SizedBox(width: 16),
              _buildSummaryCard(
                'Cancelled Orders',
                '${_completedOrders.where((o) => _isCancelledStatus(_normalizedStatus(o['status']))).length}',
                Icons.cancel,
                Colors.red,
              ),
              const SizedBox(width: 16),
              _buildSummaryCard(
                'Total Revenue',
                '$_currencySymbol${_completedOrders.where((o) => _isCompletedStatus(_normalizedStatus(o['status']))).fold<num>(0, (sum, order) => sum + _parseAmount(order['total_amount'])).toStringAsFixed(2)}',
                Icons.attach_money,
                Colors.green,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Orders Table
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade200,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Table Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(flex: 1, child: _buildTableHeader('Order ID')),
                      Expanded(flex: 2, child: _buildTableHeader('Customer')),
                      Expanded(flex: 1, child: _buildTableHeader('Status')),
                      Expanded(flex: 1, child: _buildTableHeader('Items')),
                      Expanded(flex: 1, child: _buildTableHeader('Total')),
                      Expanded(flex: 1, child: _buildTableHeader('Date')),
                      Expanded(
                        flex: 2,
                        child: _buildTableHeader('Payment Status'),
                      ),
                    ],
                  ),
                ),
                // Table Rows
                ..._completedOrders.asMap().entries.map((entry) {
                  final index = entry.key;
                  final order = entry.value;
                  return _buildCompletedOrderTableRow(order, index);
                }).toList(),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _itemsForDialog(Map<String, dynamic> order) {
    final directItems = order['items'] ?? order['tray_items'];
    final items = _coerceOrderItems(directItems);
    if (items.isNotEmpty) return items;

    final fallbackNames = _extractDishNames(order);
    if (fallbackNames.isEmpty) return const [];

    final total =
        order['total_cost'] ?? order['total_amount'] ?? order['price'];
    return fallbackNames
        .map(
          (name) => <String, dynamic>{
            'name': name,
            'quantity': 1,
            if (fallbackNames.length == 1 && total != null) 'price': total,
          },
        )
        .toList();
  }

  List<Map<String, dynamic>> _coerceOrderItems(dynamic raw) {
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        return _coerceOrderItems(decoded);
      } catch (_) {
        return const [];
      }
    }
    return const [];
  }

  List<String> _extractDishNames(Map<String, dynamic> order) {
    final names = <String>[];
    void addName(dynamic value) {
      final text = value?.toString().trim() ?? '';
      if (text.isEmpty) return;
      if (!names.any(
        (existing) => existing.toLowerCase() == text.toLowerCase(),
      )) {
        names.add(text);
      }
    }

    for (final key in const [
      'dishName',
      'dish_name',
      'dishNames',
      'dish_names',
      'itemName',
      'item_name',
      'itemNames',
      'item_names',
      'menu_item',
      'menu_items',
    ]) {
      final value = order[key];
      if (value is List) {
        for (final item in value) addName(item);
      } else if (value is String && value.contains(',')) {
        for (final item in value.split(',')) addName(item);
      } else {
        addName(value);
      }
    }

    final menu = order['menu'];
    if (menu is List) {
      for (final item in menu.whereType<Map>()) {
        addName(item['dishName'] ?? item['dish_name'] ?? item['name']);
      }
    }
    return names;
  }

  void _showOrderItemsDialog(Map<String, dynamic> order) {
    final items = _itemsForDialog(order);
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              'Order #${order['order_no'] ?? order['id']?.toString().substring(0, 8).toUpperCase() ?? 'N/A'}',
            ),
            content: SizedBox(
              width: 420,
              child:
                  items.isEmpty
                      ? const Text('No dishes found for this order.')
                      : ListView.separated(
                        shrinkWrap: true,
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const Divider(height: 12),
                        itemBuilder: (context, i) {
                          final item = items[i];
                          final name =
                              item['name'] ??
                              item['dishName'] ??
                              item['dish_name'] ??
                              item['itemName'] ??
                              item['item_name'] ??
                              'Unknown dish';
                          final desc =
                              (item['description'] ??
                                      item['public_description'] ??
                                      item['publicDescription'] ??
                                      item['category'] ??
                                      '')
                                  .toString()
                                  .trim();
                          final qty = item['quantity'] ?? 1;
                          final price = item['price'] ?? '0';
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '$name x$qty',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Text('$_currencySymbol$price'),
                                ],
                              ),
                              if (desc.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    desc,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
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

  Color _getStatusColor(String status) {
    switch (_normalizedStatus(status)) {
      case 'pending_cashier':
      case 'pending':
        return Colors.orange;
      case 'in_preparation':
      case 'confirmed':
      case 'preparing':
        return Colors.blue;
      case 'out_for_delivery':
        return Colors.purple;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  static const String _currencySymbol = '₱';

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader(String text) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.grey.shade700,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }

  String _shortOrderId(dynamic rawId, dynamic orderNo) {
    return formatRestaurantOrderNo({
      'order_no': orderNo,
      'order_id': orderNo,
      'id': rawId,
    });
  }

  Widget _buildOrderTableRow(Map<String, dynamic> order, int index) {
    final items = (order['items'] as List<dynamic>?) ?? [];
    final isEven = index % 2 == 0;

    return InkWell(
      onTap: () => _showOrderItemsDialog(order),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isEven ? Colors.white : Colors.grey.shade50,
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade200, width: 0.5),
          ),
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Expanded(
                flex: 1,
                child: _buildTableCell(
                  _shortOrderId(order['id'], order['order_no']),
                ),
              ),
              Expanded(
                flex: 2,
                child: _buildTableCell(order['full_name'] ?? 'N/A'),
              ),
              Expanded(
                flex: 1,
                child: _buildTableCell(order['phone'] ?? 'N/A'),
              ),
              Expanded(flex: 1, child: _buildTableCell('${items.length}')),
              Expanded(
                flex: 1,
                child: _buildTableCell(
                  '$_currencySymbol${_parseAmount(order['total_amount']).toStringAsFixed(2)}',
                ),
              ),
              Expanded(
                flex: 1,
                child: _buildTableCell(
                  _formatDateTimeCell(
                    order['delivery_time'] ?? order['created_at'],
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    GestureDetector(
                      onTap: () => _showOrderItemsDialog(order),
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade600,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.visibility,
                                color: Colors.white,
                                size: 16,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'View Dishes',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildPaymentStatusBadge(
                      order['payment_status'] as String? ?? 'pending',
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _showConfirmPaymentDialog(order),
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check, color: Colors.white, size: 16),
                              SizedBox(width: 4),
                              Text(
                                'Confirm payment',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _cancelOrder(_managerOrderId(order)),
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.close, color: Colors.white, size: 16),
                              SizedBox(width: 4),
                              Text(
                                'Cancel',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
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
      ),
    );
  }

  Widget _buildTableCell(String text) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.grey.shade800,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildStatusBadge(String status, Color? statusColor) {
    final color = statusColor ?? _getStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildProcessingOrderTableRow(Map<String, dynamic> order, int index) {
    final items = (order['items'] as List<dynamic>?) ?? [];
    final status = order['status'] as String? ?? 'processing';
    final normalizedStatus = _normalizedStatus(status);
    final isEven = index % 2 == 0;

    return InkWell(
      onTap: () => _showOrderItemsDialog(order),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isEven ? Colors.white : Colors.grey.shade50,
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade200, width: 0.5),
          ),
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Expanded(
                flex: 1,
                child: _buildTableCell(
                  _shortOrderId(order['id'], order['order_no']),
                ),
              ),
              Expanded(
                flex: 2,
                child: _buildTableCell(order['full_name'] ?? 'N/A'),
              ),
              Expanded(flex: 1, child: _buildStatusBadge(status, null)),
              Expanded(flex: 1, child: _buildTableCell('${items.length}')),
              Expanded(
                flex: 1,
                child: _buildTableCell(
                  '$_currencySymbol${_parseAmount(order['total_amount']).toStringAsFixed(2)}',
                ),
              ),
              Expanded(
                flex: 1,
                child: _buildTableCell(
                  _formatDateTimeCell(
                    order['delivery_time'] ?? order['created_at'],
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    GestureDetector(
                      onTap: () => _showOrderItemsDialog(order),
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade600,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.visibility,
                                color: Colors.white,
                                size: 16,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'View Dishes',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildPaymentStatusBadge(
                      order['payment_status'] as String? ?? 'pending',
                    ),
                    const SizedBox(width: 8),
                    if (normalizedStatus == 'in_preparation') ...[
                      GestureDetector(
                        onTap:
                            () =>
                                _showDeliveryUrlDialog(_managerOrderId(order)),
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.local_shipping,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'For Delivery',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (normalizedStatus == 'out_for_delivery') ...[
                      GestureDetector(
                        onTap: () => _markDelivered(_managerOrderId(order)),
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Delivered',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompletedOrderTableRow(Map<String, dynamic> order, int index) {
    final items = (order['items'] as List<dynamic>?) ?? [];
    final status = order['status'] as String? ?? 'completed';
    final paymentStatus = order['payment_status'] as String? ?? 'pending';
    final isEven = index % 2 == 0;

    return InkWell(
      onTap: () => _showOrderItemsDialog(order),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isEven ? Colors.white : Colors.grey.shade50,
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade200, width: 0.5),
          ),
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Expanded(
                flex: 1,
                child: _buildTableCell(
                  _shortOrderId(order['id'], order['order_no']),
                ),
              ),
              Expanded(
                flex: 2,
                child: _buildTableCell(order['full_name'] ?? 'N/A'),
              ),
              Expanded(flex: 1, child: _buildStatusBadge(status, null)),
              Expanded(flex: 1, child: _buildTableCell('${items.length}')),
              Expanded(
                flex: 1,
                child: _buildTableCell(
                  '$_currencySymbol${_parseAmount(order['total_amount']).toStringAsFixed(2)}',
                ),
              ),
              Expanded(
                flex: 1,
                child: _buildTableCell(
                  _formatDateTimeCell(
                    order['delivery_time'] ?? order['created_at'],
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    GestureDetector(
                      onTap: () => _showOrderItemsDialog(order),
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade600,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.visibility,
                                color: Colors.white,
                                size: 16,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'View Dishes',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildPaymentStatusBadge(paymentStatus),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentStatusBadge(String paymentStatus) {
    Color color;
    String text;

    switch (paymentStatus) {
      case 'paid':
        color = Colors.green;
        text = 'PAID';
        break;
      case 'failed':
        color = Colors.red;
        text = 'FAILED';
        break;
      default:
        color = Colors.orange;
        text = 'PENDING';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }

  bool _isMobileRestaurantOrder(Map<String, dynamic> order) {
    final proof =
        (order['payment_proof_initial'] ?? order['payment_proof'] ?? '')
            .toString()
            .trim();
    return proof.isNotEmpty;
  }

  String _webPaymentReference(Map<String, dynamic> order) {
    return (order['payment_reference_initial'] ??
            order['payment_references_initial'] ??
            order['payment_reference'] ??
            '')
        .toString()
        .trim();
  }

  String? _paymentProofRaw(dynamic proof) {
    if (proof == null) return null;
    final s = proof.toString().trim();
    if (s.isEmpty) return null;
    return s;
  }

  bool _looksLikeBase64Image(String s) {
    final value = s.trim().replaceAll(RegExp(r'\s+'), '');
    if (value.startsWith('/9j/') || value.startsWith('iVBORw0KGgo')) {
      return true;
    }
    return value.length > 80 &&
        RegExp(r'^[A-Za-z0-9+/]+={0,2}$').hasMatch(value);
  }

  Widget _paymentProofImage(dynamic proof) {
    final raw = _paymentProofRaw(proof);
    if (raw == null) return const SizedBox.shrink();

    String? base64Payload;
    if (raw.startsWith('data:')) {
      final comma = raw.indexOf(',');
      if (comma > -1) base64Payload = raw.substring(comma + 1);
    } else if (_looksLikeBase64Image(raw)) {
      base64Payload = raw;
    }

    if (base64Payload != null) {
      try {
        return Image.memory(
          base64Decode(base64Payload.replaceAll(RegExp(r'\s+'), '')),
          height: 180,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Text('Unable to load image'),
        );
      } catch (_) {
        return const Text('Unable to load image');
      }
    }

    final url =
        raw.startsWith('http://') || raw.startsWith('https://')
            ? raw
            : raw.startsWith('/')
            ? '$apiBaseUrl$raw'
            : '$apiBaseUrl/$raw';
    return Image.network(
      url,
      height: 180,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const Text('Unable to load image'),
    );
  }

  Future<void> _showConfirmPaymentDialog(Map<String, dynamic> order) async {
    final orderId = _managerOrderId(order);
    if (orderId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot confirm payment: order id is missing.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    final total = _parseAmount(order['total_amount']);
    final isMobile = _isMobileRestaurantOrder(order);
    final paymentRef = isMobile ? '' : _webPaymentReference(order);
    final proof =
        isMobile
            ? order['payment_proof_initial'] ?? order['payment_proof']
            : null;
    final amountController = TextEditingController(
      text: total > 0 ? total.toStringAsFixed(2) : '',
    );
    String? errorText;
    bool submitting = false;

    await showDialog<void>(
      context: context,
      builder:
          (dialogContext) => StatefulBuilder(
            builder: (context, setDialogState) {
              final paid = double.tryParse(amountController.text.trim()) ?? 0;
              final change = paid - total;

              return Dialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 480),
                  padding: const EdgeInsets.all(24),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'CONFIRM PAYMENT',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                            IconButton(
                              onPressed:
                                  submitting
                                      ? null
                                      : () => Navigator.of(dialogContext).pop(),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Order ${formatRestaurantOrderNo(order)}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Order total: $_currencySymbol${total.toStringAsFixed(2)}',
                        ),
                        if (paymentRef.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text('Reference: $paymentRef'),
                        ],
                        if (proof != null) ...[
                          const SizedBox(height: 12),
                          const Text(
                            'Payment proof',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: _paymentProofImage(proof),
                          ),
                        ],
                        const SizedBox(height: 16),
                        TextField(
                          controller: amountController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Amount paid by customer',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged:
                              (_) => setDialogState(() => errorText = null),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Change: $_currencySymbol${change >= 0 ? change.toStringAsFixed(2) : '0.00'}',
                          style: TextStyle(
                            color:
                                change >= 0
                                    ? Colors.green.shade700
                                    : Colors.red.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (errorText != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            errorText!,
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed:
                                    submitting
                                        ? null
                                        : () async {
                                          if (paid < total) {
                                            setDialogState(() {
                                              errorText =
                                                  'Payment is insufficient. Notify the customer or collect the correct amount.';
                                            });
                                            return;
                                          }
                                          setDialogState(
                                            () => submitting = true,
                                          );
                                          try {
                                            final token = await _getAuthToken();
                                            final response = await http.post(
                                              Uri.parse(
                                                '$apiBaseUrl/api/manager/restaurant/orders/${Uri.encodeComponent(orderId)}/confirm-payment',
                                              ),
                                              headers: {
                                                'Authorization':
                                                    'Bearer $token',
                                                'Content-Type':
                                                    'application/json',
                                              },
                                              body: jsonEncode({
                                                'amountPaid': paid,
                                              }),
                                            );
                                            if (response.statusCode == 200) {
                                              if (dialogContext.mounted) {
                                                Navigator.of(
                                                  dialogContext,
                                                ).pop();
                                              }
                                              await _loadOrders(
                                                forceRefresh: true,
                                              );
                                              if (mounted) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'Payment confirmed — order in preparation',
                                                    ),
                                                  ),
                                                );
                                              }
                                            } else if (response.statusCode ==
                                                400) {
                                              setDialogState(() {
                                                errorText =
                                                    'Insufficient payment amount';
                                                submitting = false;
                                              });
                                            } else {
                                              throw Exception(
                                                _responseErrorMessage(response),
                                              );
                                            }
                                          } catch (e) {
                                            setDialogState(() {
                                              errorText = e.toString();
                                              submitting = false;
                                            });
                                          }
                                        },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFFC024),
                                  foregroundColor: Colors.black,
                                ),
                                child:
                                    submitting
                                        ? const SizedBox(
                                          height: 18,
                                          width: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                        : const Text('CONFIRM & START PREP'),
                              ),
                            ),
                          ],
                        ),
                        if (paid < total && paid > 0) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed:
                                  submitting
                                      ? null
                                      : () async {
                                        try {
                                          final token = await _getAuthToken();
                                          await http.post(
                                            Uri.parse(
                                              '$apiBaseUrl/api/manager/restaurant/orders/${Uri.encodeComponent(orderId)}/notify-insufficient-payment',
                                            ),
                                            headers: {
                                              'Authorization': 'Bearer $token',
                                              'Content-Type':
                                                  'application/json',
                                            },
                                            body: jsonEncode({
                                              'amountPaid': paid,
                                            }),
                                          );
                                          if (mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Customer notified about insufficient payment',
                                                ),
                                              ),
                                            );
                                          }
                                        } catch (e) {
                                          if (mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Failed to notify: $e',
                                                ),
                                              ),
                                            );
                                          }
                                        }
                                      },
                              child: const Text(
                                'EMAIL CUSTOMER (INSUFFICIENT PAYMENT)',
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
    );

    amountController.dispose();
  }

  Future<void> _cancelOrder(String orderId) async {
    if (orderId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot cancel order: order id is missing.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
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
                      onPressed: () => Navigator.of(context).pop(false),
                      icon: const Icon(Icons.close, color: Colors.black),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Title
                  const Text(
                    'CANCEL ORDER',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Are you sure you want to cancel this order?',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 24),
                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'YES, CANCEL',
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
                          onPressed: () => Navigator.of(context).pop(false),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey.shade300,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'NO',
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

    if (confirmed == true) {
      try {
        final token = await _getAuthToken();
        final response = await http.post(
          Uri.parse(
            '$apiBaseUrl/api/manager/restaurant/orders/${Uri.encodeComponent(orderId)}/cancel',
          ),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        );
        if (response.statusCode == 200) {
          await _loadOrders(forceRefresh: true);
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Order cancelled')));
          }
        } else {
          throw Exception(response.body);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Cancel failed: $e')));
        }
      }
    }
  }

  Future<void> _showDeliveryUrlDialog(String orderId) async {
    final urlController = TextEditingController();
    String? errorMessage;

    final result = await showDialog<String>(
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
                          'ADD DELIVERY URL',
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

                        // Form field
                        const Text(
                          'Please enter the delivery tracking URL:',
                          style: TextStyle(fontSize: 13),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: urlController,
                          decoration: const InputDecoration(
                            isDense: true,
                            hintText: 'https://...',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Submit button
                        ElevatedButton(
                          onPressed: () {
                            if (urlController.text.trim().isEmpty) {
                              setDialogState(
                                () =>
                                    errorMessage =
                                        'Please enter a delivery URL',
                              );
                              return;
                            }
                            Navigator.of(
                              context,
                            ).pop(urlController.text.trim());
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
                            'SUBMIT',
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

    if (result != null && result.isNotEmpty) {
      await _updateOrderStatus(
        orderId,
        'out_for_delivery',
        deliveryUrl: result,
      );
    }
  }

  Future<void> _markDelivered(String orderId) async {
    final confirmed = await showDialog<bool>(
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
                      onPressed: () => Navigator.of(context).pop(false),
                      icon: const Icon(Icons.close, color: Colors.black),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Title
                  const Text(
                    'MARK AS DELIVERED',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Confirm that this order has been delivered?',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 24),
                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFC024),
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'YES, DELIVERED',
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
                          onPressed: () => Navigator.of(context).pop(false),
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

    if (confirmed == true) {
      await _updateOrderStatus(orderId, 'delivered');
    }
  }
}
