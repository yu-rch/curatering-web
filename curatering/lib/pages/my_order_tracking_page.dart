import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import '../utils/order_display_utils.dart';
import '../services/customer_orders_cache.dart';
import '../widgets/customer_pages_top_bar.dart';
import 'customer_website.dart';
import 'my_caterings_page.dart';
import 'my_orders_page.dart';
import 'my_profile_page.dart';

class MyOrderTrackingPage extends StatefulWidget {
  const MyOrderTrackingPage({super.key});

  @override
  State<MyOrderTrackingPage> createState() => _MyOrderTrackingPageState();
}

class _MyOrderTrackingPageState extends State<MyOrderTrackingPage> {
  List<dynamic> _activeOrders = [];
  bool _isLoading = true;
  String? _error;
  static const Duration _requestTimeout = Duration(seconds: 45);

  String get _apiBaseUrl {
    return apiBaseUrl;
  }

  @override
  void initState() {
    super.initState();
    _loadActiveOrders();
  }

  Future<void> _loadActiveOrders({bool force = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('customer_token');

      if (token == null || token.isEmpty) {
        if (mounted) {
          Navigator.of(context).pop('login_required');
        }
        return;
      }

      if (!force) {
        final cached = CustomerOrdersCache.instance.peekRestaurantOrders();
        if (cached != null) {
          final activeOrders =
              cached.where((order) {
                final status = order['status'] ?? 'pending';
                return status != 'delivered' && status != 'cancelled';
              }).toList();
          if (mounted) {
            setState(() {
              _activeOrders = activeOrders;
              _isLoading = false;
              _error = null;
            });
          }
          return;
        }
      }

      if (mounted) {
        setState(() {
          _isLoading = true;
          _error = null;
        });
      }

      final response = await http
          .get(
            Uri.parse('$_apiBaseUrl/api/restaurant/orders'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          )
          .timeout(_requestTimeout);

      if (response.statusCode == 401) {
        await prefs.remove('customer_token');
        await prefs.remove('customer_data');
        if (mounted) {
          _showSessionExpiredDialog();
        }
        return;
      }

      if (response.statusCode != 200) {
        throw Exception('Failed to load orders: ${response.statusCode}');
      }

      final data = jsonDecode(response.body);
      final allOrders =
          (data['orders'] as List<dynamic>? ?? const [])
              .whereType<Map>()
              .map(
                (entry) => CustomerOrdersCache.normalizeRestaurantOrder(
                  Map<String, dynamic>.from(entry),
                ),
              )
              .toList();
      CustomerOrdersCache.instance.setRestaurantOrders(allOrders);

      // Filter only active orders (not delivered or cancelled)
      final activeOrders =
          allOrders.where((order) {
            final status = order['status'] ?? 'pending';
            return status != 'delivered' && status != 'cancelled';
          }).toList();

      if (mounted) {
        setState(() {
          _activeOrders = activeOrders;
          _isLoading = false;
        });
      }
    } on TimeoutException {
      if (mounted) {
        setState(() {
          _error =
              'Request timed out. Please check your connection and try again.';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error loading orders: $e';
          _isLoading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> _normalizeOrderItems(dynamic rawItems) {
    if (rawItems is! List) return const <Map<String, dynamic>>[];
    return rawItems
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  void _showSessionExpiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: const Text('Session Expired'),
            content: const Text(
              'Your session has expired. Please log in again.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop('login_required');
                },
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'Order Placed';
      case 'confirmed':
        return 'Order Confirmed';
      case 'preparing':
        return 'Preparing Your Order';
      case 'out_for_delivery':
        return 'Out for Delivery';
      default:
        return status.replaceAll('_', ' ').toUpperCase();
    }
  }

  String _getPaymentStatusText(String paymentStatus) {
    switch (paymentStatus) {
      case 'pending':
        return 'Awaiting Payment Confirmation';
      case 'paid':
        return 'Payment Confirmed - Order Received';
      case 'failed':
        return 'Payment Failed';
      default:
        return 'Awaiting Payment Confirmation';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'preparing':
        return Colors.amber;
      case 'out_for_delivery':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  int _getStatusStep(String status) {
    switch (status) {
      case 'pending':
        return 0;
      case 'confirmed':
        return 1;
      case 'preparing':
        return 2;
      case 'out_for_delivery':
        return 3;
      default:
        return 0;
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'N/A';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.month}/${date.day}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateStr;
    }
  }

  String _shortOrderId(dynamic rawId, dynamic orderNo) {
    return formatRestaurantOrderNo({
      'order_no': orderNo,
      'id': rawId,
    });
  }

  void _navigateFromTopBar(CustomerPageTab tab) {
    if (tab == CustomerPageTab.tracking) return;
    final route = switch (tab) {
      CustomerPageTab.home => const CustomerWebsiteScreen(),
      CustomerPageTab.profile => const MyProfilePage(),
      CustomerPageTab.orders => const MyOrdersPage(),
      CustomerPageTab.caterings => const MyCateringsPage(),
      CustomerPageTab.tracking => const MyOrderTrackingPage(),
    };
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => route));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'Order Tracking',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadActiveOrders(force: true),
            tooltip: 'Refresh tracking',
          ),
        ],
      ),
      body: Column(
        children: [
          CustomerPagesTopBar(
            currentTab: CustomerPageTab.tracking,
            onTabSelected: _navigateFromTopBar,
          ),
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _error!,
                            style: const TextStyle(color: Colors.red),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => _loadActiveOrders(force: true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E1E1E),
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                    : _activeOrders.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.local_shipping_outlined,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No active orders',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Your active orders will appear here for tracking',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => _loadActiveOrders(force: true),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Refresh'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E1E1E),
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    )
                    : RefreshIndicator(
                      onRefresh: () => _loadActiveOrders(force: true),
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                        itemCount: _activeOrders.length,
                        itemBuilder: (context, index) {
                          final order = _activeOrders[index];
                          final status = order['status'] ?? 'pending';
                          final paymentStatus =
                              order['payment_status'] ?? 'pending';
                          final currentStep = _getStatusStep(status);
                          final items = _normalizeOrderItems(order['items']);

                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(
                                color: Colors.black.withOpacity(0.08),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Order Header
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Order #${_shortOrderId(order['id'], order['order_no'])}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _getStatusColor(status),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: Text(
                                          status.toUpperCase(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Ordered on ${_formatDate(order['created_at'])}',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const Divider(height: 24),

                                  // Progress Tracker
                                  _buildProgressTracker(currentStep),
                                  const SizedBox(height: 24),

                                  // Current Status Message
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(
                                        status,
                                      ).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: _getStatusColor(
                                          status,
                                        ).withOpacity(0.3),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _getStatusText(status),
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: _getStatusColor(status),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Payment Status: ${_getPaymentStatusText(paymentStatus)}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color:
                                                paymentStatus == 'paid'
                                                    ? Colors.green.shade600
                                                    : Colors.orange.shade600,
                                            fontWeight:
                                                paymentStatus == 'paid'
                                                    ? FontWeight.w600
                                                    : FontWeight.normal,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  // Order Items
                                  const Text(
                                    'Order Items',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ...items.map((item) {
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              '• ${item['name'] ?? item['dishName'] ?? 'Unknown Item'}',
                                              style: const TextStyle(
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            '₱${item['price'] ?? '0'}',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                  const Divider(height: 24),

                                  // Delivery Info
                                  if (order['delivery_address'] != null) ...[
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.location_on,
                                          size: 18,
                                          color: Colors.grey.shade600,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            order['delivery_address'],
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                  ],

                                  // Total
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Total Amount',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        '₱${order['total_amount'] ?? '0.00'}',
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFFF4511E),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressTracker(int currentStep) {
    final steps = [
      'Order Placed',
      'Confirmed',
      'Preparing',
      'Out for Delivery',
    ];

    return Column(
      children: [
        // Progress Line
        Row(
          children: List.generate(steps.length * 2 - 1, (index) {
            if (index.isOdd) {
              // Line
              final lineIndex = index ~/ 2;
              final isActive = lineIndex < currentStep;
              return Expanded(
                child: Container(
                  height: 3,
                  color: isActive ? Colors.green : Colors.grey.shade300,
                ),
              );
            } else {
              // Dot
              final stepIndex = index ~/ 2;
              final isActive = stepIndex <= currentStep;
              final isCurrent = stepIndex == currentStep;
              return Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive ? Colors.green : Colors.grey.shade300,
                  border:
                      isCurrent
                          ? Border.all(color: Colors.green, width: 3)
                          : null,
                ),
                child:
                    isActive
                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                        : null,
              );
            }
          }),
        ),
        const SizedBox(height: 8),
        // Step Labels
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children:
              steps.map((step) {
                final stepIndex = steps.indexOf(step);
                final isActive = stepIndex <= currentStep;
                return Text(
                  step,
                  style: TextStyle(
                    fontSize: 10,
                    color: isActive ? Colors.black87 : Colors.grey.shade500,
                    fontWeight: isActive ? FontWeight.w500 : FontWeight.normal,
                  ),
                );
              }).toList(),
        ),
      ],
    );
  }
}
