import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RestaurantTransactionsPage extends StatefulWidget {
  const RestaurantTransactionsPage({super.key});

  @override
  State<RestaurantTransactionsPage> createState() => _RestaurantTransactionsPageState();
}

class _RestaurantTransactionsPageState extends State<RestaurantTransactionsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  List<Map<String, dynamic>> _confirmationOrders = [];
  List<Map<String, dynamic>> _processingOrders = [];
  List<Map<String, dynamic>> _completedOrders = [];

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

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;

      // Fetch orders by status
      final confirmationResponse = await supabase
          .from('restaurant_orders')
          .select()
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      final processingResponse = await supabase
          .from('restaurant_orders')
          .select()
          .inFilter('status', ['processing', 'for_delivery'])
          .order('created_at', ascending: false);

      final completedResponse = await supabase
          .from('restaurant_orders')
          .select()
          .inFilter('status', ['completed', 'cancelled'])
          .order('created_at', ascending: false);

      setState(() {
        _confirmationOrders = List<Map<String, dynamic>>.from(confirmationResponse);
        _processingOrders = List<Map<String, dynamic>>.from(processingResponse);
        _completedOrders = List<Map<String, dynamic>>.from(completedResponse);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading orders: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateOrderStatus(String orderId, String newStatus,
      {String? deliveryUrl}) async {
    try {
      final supabase = Supabase.instance.client;
      final updateData = {'status': newStatus};
      if (deliveryUrl != null) {
        updateData['delivery_url'] = deliveryUrl;
      }

      await supabase
          .from('restaurant_orders')
          .update(updateData)
          .eq('id', orderId);

      await _loadOrders();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Order status updated to $newStatus')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating order: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Restaurant Orders'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFFFC024),
          labelColor: const Color(0xFFFFC024),
          unselectedLabelColor: Colors.grey,
          tabs: [
            Tab(
              icon: Badge(
                isLabelVisible: _confirmationOrders.isNotEmpty,
                label: Text('${_confirmationOrders.length}'),
                child: const Icon(Icons.pending_actions),
              ),
              text: 'Confirmation',
            ),
            const Tab(icon: Icon(Icons.local_shipping), text: 'Processing'),
            const Tab(icon: Icon(Icons.check_circle), text: 'Completed'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildConfirmationTab(),
                _buildProcessingTab(),
                _buildCompletedTab(),
              ],
            ),
    );
  }

  Widget _buildConfirmationTab() {
    if (_confirmationOrders.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No orders awaiting confirmation',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _confirmationOrders.length,
      itemBuilder: (context, index) {
        final order = _confirmationOrders[index];
        return _buildOrderCard(
          order: order,
          actions: [
            ElevatedButton.icon(
              onPressed: () => _confirmOrder(order['id']),
              icon: const Icon(Icons.check, color: Colors.white),
              label: const Text('Confirm', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () => _cancelOrder(order['id']),
              icon: const Icon(Icons.close, color: Colors.white),
              label: const Text('Cancel', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProcessingTab() {
    if (_processingOrders.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_shipping, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No orders in processing',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _processingOrders.length,
      itemBuilder: (context, index) {
        final order = _processingOrders[index];
        final status = order['status'] as String;
        final deliveryUrl = order['delivery_url'] as String?;

        return _buildOrderCard(
          order: order,
          actions: status == 'processing'
              ? [
                  ElevatedButton.icon(
                    onPressed: () => _showDeliveryUrlDialog(order['id']),
                    icon: const Icon(Icons.local_shipping, color: Colors.white),
                    label: const Text('For Delivery', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                    ),
                  ),
                ]
              : deliveryUrl != null
                  ? [
                      ElevatedButton.icon(
                        onPressed: () => _markDelivered(order['id']),
                        icon: const Icon(Icons.check_circle, color: Colors.white),
                        label: const Text('Delivered', style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                      ),
                    ]
                  : [],
        );
      },
    );
  }

  Widget _buildCompletedTab() {
    if (_completedOrders.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No completed orders yet',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _completedOrders.length,
      itemBuilder: (context, index) {
        final order = _completedOrders[index];
        final status = order['status'] as String;

        return _buildOrderCard(
          order: order,
          statusColor: status == 'cancelled' ? Colors.red : Colors.green,
        );
      },
    );
  }

  Widget _buildOrderCard({
    required Map<String, dynamic> order,
    List<Widget>? actions,
    Color? statusColor,
  }) {
    final items = (order['items'] as List<dynamic>?) ?? [];
    final status = order['status'] as String? ?? 'pending';
    final deliveryUrl = order['delivery_url'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with Order ID and Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Order #${order['id'].toString().substring(0, 8).toUpperCase()}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: (statusColor ?? _getStatusColor(status)).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      color: statusColor ?? _getStatusColor(status),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            // Customer Information
            _buildInfoRow('Customer Name', order['full_name'] ?? 'N/A'),
            _buildInfoRow('Contact Number', order['phone'] ?? 'N/A'),
            _buildInfoRow('Delivery Address', order['delivery_address'] ?? 'N/A'),
            _buildInfoRow(
              'Date & Time',
              '${order['created_at']?.toString().substring(0, 10) ?? 'N/A'}',
            ),
            const SizedBox(height: 16),

            // Order Details
            const Text(
              'ORDER DETAILS',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            ...items.map((item) {
              final price = (item['price'] as num?) ?? 0;
              final quantity = (item['quantity'] as num?) ?? 1;
              final total = price * quantity;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(item['name'] ?? 'Unknown Item'),
                    ),
                    Expanded(
                      child: Text(
                        '₱${price.toStringAsFixed(2)}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'x$quantity',
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '₱${total.toStringAsFixed(2)}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            const Divider(height: 24),

            // Total and Payment Method
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Payment: ${order['payment_method'] ?? 'GCash'}',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                Text(
                  'Total: ₱${(order['total_amount'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),

            // Delivery URL if available
            if (deliveryUrl != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.link, color: Colors.blue.shade700, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Delivery URL: $deliveryUrl',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Action Buttons
            if (actions != null && actions.isNotEmpty) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: actions,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'processing':
        return Colors.blue;
      case 'for_delivery':
        return Colors.purple;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<void> _confirmOrder(String orderId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Order'),
        content: const Text('Are you sure you want to confirm this order?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Confirm', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _updateOrderStatus(orderId, 'processing');
    }
  }

  Future<void> _cancelOrder(String orderId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Order'),
        content: const Text('Are you sure you want to cancel this order?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Yes, Cancel', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _updateOrderStatus(orderId, 'cancelled');
    }
  }

  Future<void> _showDeliveryUrlDialog(String orderId) async {
    final urlController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Delivery URL'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please enter the delivery tracking URL:'),
            const SizedBox(height: 16),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                hintText: 'https://...',
                border: OutlineInputBorder(),
                labelText: 'Delivery URL',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (urlController.text.trim().isNotEmpty) {
                Navigator.of(context).pop(urlController.text.trim());
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      await _updateOrderStatus(orderId, 'for_delivery', deliveryUrl: result);
    }
  }

  Future<void> _markDelivered(String orderId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark as Delivered'),
        content: const Text('Confirm that this order has been delivered?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Yes, Delivered', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _updateOrderStatus(orderId, 'completed');
    }
  }
}
