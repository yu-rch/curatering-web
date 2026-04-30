import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import '../widgets/customer_pages_top_bar.dart';
import 'customer_website.dart';
import 'my_caterings_page.dart';
import 'my_order_tracking_page.dart';
import 'my_profile_page.dart';

class MyOrdersPage extends StatefulWidget {
  const MyOrdersPage({super.key});

  @override
  State<MyOrdersPage> createState() => _MyOrdersPageState();
}

class _MyOrdersPageState extends State<MyOrdersPage> {
  List<dynamic> _orders = [];
  bool _isLoading = true;
  String? _error;
  static const Duration _requestTimeout = Duration(seconds: 20);

  String get _apiBaseUrl {
    return apiBaseUrl;
  }

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('customer_token');

      if (token == null || token.isEmpty) {
        if (mounted) {
          Navigator.of(context).pop('login_required');
        }
        return;
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
        // Token expired, clear and redirect to login
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
      final rawOrders = (data['orders'] as List<dynamic>? ?? const []);
      final parsedOrders = rawOrders
          .whereType<Map>()
          .map((entry) {
            final order = Map<String, dynamic>.from(entry);
            final rawItems = order['items'];
            if (rawItems is String) {
              try {
                order['items'] = jsonDecode(rawItems);
              } catch (_) {
                order['items'] = <dynamic>[];
              }
            }
            if (order['items'] is! List) {
              order['items'] = <dynamic>[];
            }
            return order;
          })
          .toList();
      if (mounted) {
        setState(() {
          _orders = parsedOrders;
          _isLoading = false;
        });
      }
    } on TimeoutException {
      if (mounted) {
        setState(() {
          _error = 'Request timed out. Please check your connection and try again.';
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
      builder: (context) => AlertDialog(
        title: const Text('Session Expired'),
        content: const Text('Your session has expired. Please log in again.'),
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

  String _formatStatus(String status) {
    return status.replaceAll('_', ' ').toUpperCase();
  }

  String _formatPaymentStatus(String status) {
    // Show as pending until cashier/manager confirms
    if (status == 'pending') {
      return 'PENDING CONFIRMATION';
    }
    return status.toUpperCase();
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
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _getPaymentStatusColor(String status) {
    switch (status) {
      case 'paid':
        return Colors.green;
      case 'failed':
        return Colors.red;
      default:
        return Colors.orange;
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

  String _shortOrderId(dynamic rawId) {
    final value = (rawId ?? '').toString();
    if (value.isEmpty) return 'N/A';
    return value.length <= 8 ? value : value.substring(0, 8);
  }

  void _navigateFromTopBar(CustomerPageTab tab) {
    if (tab == CustomerPageTab.orders) return;
    final route = switch (tab) {
      CustomerPageTab.home => const CustomerWebsiteScreen(),
      CustomerPageTab.profile => const MyProfilePage(),
      CustomerPageTab.caterings => const MyCateringsPage(),
      CustomerPageTab.tracking => const MyOrderTrackingPage(),
      CustomerPageTab.orders => const MyOrdersPage(),
    };
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => route),
    );
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
          'My Orders',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadOrders,
            tooltip: 'Refresh orders',
          ),
        ],
      ),
      body: Column(
        children: [
          CustomerPagesTopBar(
            currentTab: CustomerPageTab.orders,
            onTabSelected: _navigateFromTopBar,
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadOrders,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E1E1E),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
                    : _orders.isEmpty
                        ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.receipt_long_outlined,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No orders yet',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Your restaurant orders will appear here',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _loadOrders,
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
                        : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      itemCount: _orders.length,
                      itemBuilder: (context, index) {
                        final order = _orders[index];
                        final items = _normalizeOrderItems(order['items']);
                        final status = order['status'] ?? 'pending';
                        final paymentStatus = order['payment_status'] ?? 'pending';

                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(color: Colors.black.withOpacity(0.08)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Order #${_shortOrderId(order['id'])}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      _formatDate(order['created_at']),
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 24),
                                // Order Items
                                ...items.map((item) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            item['name'] ?? item['dishName'] ?? 'Unknown Item',
                                            style: const TextStyle(fontSize: 14),
                                          ),
                                        ),
                                        Text(
                                          '₱${item['price'] ?? '0'}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                const Divider(height: 24),
                                // Total and Status
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Chip(
                                          label: Text(
                                            _formatStatus(status),
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: Colors.white,
                                            ),
                                          ),
                                          backgroundColor: _getStatusColor(status),
                                          padding: EdgeInsets.zero,
                                        ),
                                        const SizedBox(height: 4),
                                        Chip(
                                          label: Text(
                                            'Payment: ${_formatPaymentStatus(paymentStatus)}',
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: Colors.white,
                                            ),
                                          ),
                                          backgroundColor: _getPaymentStatusColor(paymentStatus),
                                          padding: EdgeInsets.zero,
                                        ),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        const Text(
                                          'Total Amount',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                        Text(
                                          '₱${order['total_amount'] ?? '0.00'}',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFFF4511E),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                if (order['delivery_address'] != null) ...[
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.location_on,
                                        size: 16,
                                        color: Colors.grey.shade600,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          order['delivery_address'],
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
