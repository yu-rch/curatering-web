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
  List<Map<String, dynamic>> _allOrders = [];
  bool _isLoading = true;
  String? _error;
  final Set<String> _sendingFollowUps = {};
  final _searchCtrl = TextEditingController();
  String _statusFilter =
      'all'; // all | pending_cashier | in_preparation | out_for_delivery | delivered | cancelled
  static const Duration _requestTimeout = Duration(seconds: 45);
  static const Duration _followUpCooldown = Duration(minutes: 20);

  String get _apiBaseUrl {
    return apiBaseUrl;
  }

  @override
  void initState() {
    super.initState();
    _loadActiveOrders();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _normalizeStatus(String status) {
    final s = status.toLowerCase().trim();
    switch (s) {
      case 'pending':
      case 'pending_cashier':
        return 'pending_cashier';
      case 'confirmed':
      case 'preparing':
      case 'in_preparation':
      case 'order_confirmed':
        return 'in_preparation';
      case 'out_for_delivery':
        return 'out_for_delivery';
      case 'delivered':
      case 'completed':
        return 'delivered';
      case 'cancelled':
        return 'cancelled';
      default:
        return s.isEmpty ? 'pending_cashier' : s;
    }
  }

  List<Map<String, dynamic>> get _filteredOrders {
    final q = _searchCtrl.text.trim().toLowerCase();
    return _allOrders.where((order) {
      final status = _normalizeStatus('${order['status'] ?? ''}');
      if (_statusFilter != 'all' && status != _statusFilter) return false;
      if (q.isEmpty) return true;
      final orderNo =
          _shortOrderId(order['id'], order['order_no']).toLowerCase();
      final addr = '${order['delivery_address'] ?? ''}'.toLowerCase();
      final items = _normalizeOrderItems(order['items'])
          .map((i) => '${i['name'] ?? i['dishName'] ?? ''}'.toLowerCase())
          .join(' ');
      return orderNo.contains(q) ||
          addr.contains(q) ||
          items.contains(q) ||
          status.contains(q);
    }).toList();
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
          if (mounted) {
            setState(() {
              _allOrders =
                  cached.map((e) => Map<String, dynamic>.from(e)).toList();
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

      if (mounted) {
        setState(() {
          _allOrders = allOrders;
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
    switch (_normalizeStatus(status)) {
      case 'pending_cashier':
        return 'Payment Under Review';
      case 'in_preparation':
        return 'Confirmed & Preparing Your Food';
      case 'out_for_delivery':
        return 'Out for Delivery';
      case 'delivered':
        return 'Delivered';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status.replaceAll('_', ' ').toUpperCase();
    }
  }

  String _getPaymentStatusText(String paymentStatus, String orderStatus) {
    final paid =
        paymentStatus == 'paid' ||
        paymentStatus == 'confirmed' ||
        _normalizeStatus(orderStatus) != 'pending_cashier';
    if (paymentStatus == 'failed') return 'Payment Failed';
    if (paid) return 'Payment Confirmed — Order In Preparation';
    return 'Awaiting Payment Confirmation';
  }

  Color _getStatusColor(String status) {
    switch (_normalizeStatus(status)) {
      case 'pending_cashier':
        return Colors.orange;
      case 'in_preparation':
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

  int _getStatusStep(String status) {
    switch (_normalizeStatus(status)) {
      case 'pending_cashier':
        return 0;
      case 'in_preparation':
        return 1;
      case 'out_for_delivery':
        return 2;
      case 'delivered':
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
    return formatRestaurantOrderNo({'order_no': orderNo, 'id': rawId});
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
                    : Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          child: TextField(
                            controller: _searchCtrl,
                            decoration: InputDecoration(
                              hintText: 'Search order no, items, address',
                              prefixIcon: const Icon(Icons.search),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              isDense: true,
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              for (final entry in const [
                                ('all', 'All'),
                                ('pending_cashier', 'Payment review'),
                                ('in_preparation', 'Preparing'),
                                ('out_for_delivery', 'Out for delivery'),
                                ('delivered', 'Delivered'),
                                ('cancelled', 'Cancelled'),
                              ])
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: FilterChip(
                                    label: Text(entry.$2),
                                    selected: _statusFilter == entry.$1,
                                    onSelected:
                                        (_) => setState(
                                          () => _statusFilter = entry.$1,
                                        ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Expanded(
                          child:
                              _filteredOrders.isEmpty
                                  ? Center(
                                    child: Text(
                                      _allOrders.isEmpty
                                          ? 'No orders to track yet'
                                          : 'No orders match your filters',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  )
                                  : RefreshIndicator(
                                    onRefresh:
                                        () => _loadActiveOrders(force: true),
                                    child: ListView.builder(
                                      padding: const EdgeInsets.fromLTRB(
                                        16,
                                        12,
                                        16,
                                        16,
                                      ),
                                      itemCount: _filteredOrders.length,
                                      itemBuilder: (context, index) {
                                        final order = _filteredOrders[index];
                                        final status = _normalizeStatus(
                                          '${order['status'] ?? ''}',
                                        );
                                        final paymentStatus =
                                            order['payment_status'] ??
                                            'pending';
                                        final currentStep = _getStatusStep(
                                          status,
                                        );
                                        final items = _normalizeOrderItems(
                                          order['items'],
                                        );
                                        final orderKey = _orderKey(order);
                                        final cooldownUntil =
                                            _followUpCooldownUntil(order);
                                        final canFollowUp =
                                            orderKey.isNotEmpty &&
                                            (cooldownUntil == null ||
                                                !cooldownUntil.isAfter(
                                                  DateTime.now(),
                                                ));

                                        return Card(
                                          margin: const EdgeInsets.only(
                                            bottom: 16,
                                          ),
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            side: BorderSide(
                                              color: Colors.black.withValues(
                                                alpha: 0.08,
                                              ),
                                            ),
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.all(16),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Text(
                                                      'Order #${_shortOrderId(order['id'], order['order_no'])}',
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 18,
                                                      ),
                                                    ),
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 12,
                                                            vertical: 6,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: _getStatusColor(
                                                          status,
                                                        ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              20,
                                                            ),
                                                      ),
                                                      child: Text(
                                                        _getStatusText(status),
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.bold,
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
                                                _buildProgressTracker(
                                                  currentStep,
                                                ),
                                                const SizedBox(height: 24),
                                                Container(
                                                  width: double.infinity,
                                                  padding: const EdgeInsets.all(
                                                    16,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: _getStatusColor(
                                                      status,
                                                    ).withValues(alpha: 0.1),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                    border: Border.all(
                                                      color: _getStatusColor(
                                                        status,
                                                      ).withValues(alpha: 0.3),
                                                    ),
                                                  ),
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        _getStatusText(status),
                                                        style: TextStyle(
                                                          fontSize: 16,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color:
                                                              _getStatusColor(
                                                                status,
                                                              ),
                                                        ),
                                                      ),
                                                      const SizedBox(height: 8),
                                                      Text(
                                                        'Payment Status: ${_getPaymentStatusText('$paymentStatus', status)}',
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          color:
                                                              paymentStatus ==
                                                                          'paid' ||
                                                                      status !=
                                                                          'pending_cashier'
                                                                  ? Colors
                                                                      .green
                                                                      .shade600
                                                                  : Colors
                                                                      .orange
                                                                      .shade600,
                                                          fontWeight:
                                                              paymentStatus ==
                                                                          'paid' ||
                                                                      status !=
                                                                          'pending_cashier'
                                                                  ? FontWeight
                                                                      .w600
                                                                  : FontWeight
                                                                      .normal,
                                                        ),
                                                      ),
                                                      if (status ==
                                                              'out_for_delivery' &&
                                                          (order['delivery_tracking_url']
                                                                  ?.toString()
                                                                  .trim()
                                                                  .isNotEmpty ??
                                                              false)) ...[
                                                        const SizedBox(
                                                          height: 8,
                                                        ),
                                                        SelectableText(
                                                          'Tracking: ${order['delivery_tracking_url']}',
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 13,
                                                              ),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(height: 16),
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
                                                    padding:
                                                        const EdgeInsets.only(
                                                          bottom: 4,
                                                        ),
                                                    child: Row(
                                                      children: [
                                                        Expanded(
                                                          child: Text(
                                                            '• ${item['name'] ?? item['dishName'] ?? 'Unknown Item'}',
                                                            style:
                                                                const TextStyle(
                                                                  fontSize: 13,
                                                                ),
                                                          ),
                                                        ),
                                                        Text(
                                                          '₱${item['price'] ?? '0'}',
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 13,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500,
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                }),
                                                const Divider(height: 24),
                                                if (order['delivery_address'] !=
                                                    null) ...[
                                                  Row(
                                                    children: [
                                                      Icon(
                                                        Icons.location_on,
                                                        size: 18,
                                                        color:
                                                            Colors
                                                                .grey
                                                                .shade600,
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Expanded(
                                                        child: Text(
                                                          order['delivery_address'],
                                                          style: TextStyle(
                                                            fontSize: 13,
                                                            color:
                                                                Colors
                                                                    .grey
                                                                    .shade700,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 16),
                                                ],
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    const Text(
                                                      'Total Amount',
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                    Text(
                                                      '₱${order['total_amount'] ?? '0.00'}',
                                                      style: const TextStyle(
                                                        fontSize: 20,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Color(
                                                          0xFFF4511E,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 16),
                                                Align(
                                                  alignment:
                                                      Alignment.centerRight,
                                                  child: OutlinedButton.icon(
                                                    onPressed:
                                                        canFollowUp &&
                                                                !_sendingFollowUps
                                                                    .contains(
                                                                      orderKey,
                                                                    )
                                                            ? () =>
                                                                _sendFollowUp(
                                                                  order,
                                                                )
                                                            : null,
                                                    icon:
                                                        _sendingFollowUps
                                                                .contains(
                                                                  orderKey,
                                                                )
                                                            ? const SizedBox(
                                                              width: 16,
                                                              height: 16,
                                                              child:
                                                                  CircularProgressIndicator(
                                                                    strokeWidth:
                                                                        2,
                                                                  ),
                                                            )
                                                            : const Icon(
                                                              Icons
                                                                  .notifications_active_outlined,
                                                            ),
                                                    label: Text(
                                                      cooldownUntil != null &&
                                                              cooldownUntil
                                                                  .isAfter(
                                                                    DateTime.now(),
                                                                  )
                                                          ? 'Follow up available ${_formatCooldown(cooldownUntil)}'
                                                          : 'Follow up order',
                                                    ),
                                                  ),
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
          ),
        ],
      ),
    );
  }

  Widget _buildProgressTracker(int currentStep) {
    final steps = [
      currentStep > 0 ? 'Payment confirmed' : 'Payment review',
      'In preparation',
      'Out for delivery',
      'Delivered',
    ];

    return Column(
      children: [
        Row(
          children: List.generate(steps.length * 2 - 1, (index) {
            if (index.isOdd) {
              final lineIndex = index ~/ 2;
              final isActive = lineIndex < currentStep;
              return Expanded(
                child: Container(
                  height: 3,
                  color: isActive ? Colors.green : Colors.grey.shade300,
                ),
              );
            } else {
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children:
              steps.asMap().entries.map((e) {
                final isActive = e.key <= currentStep;
                return Flexible(
                  child: Text(
                    e.value,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 9,
                      color: isActive ? Colors.black87 : Colors.grey.shade500,
                      fontWeight:
                          isActive ? FontWeight.w500 : FontWeight.normal,
                    ),
                  ),
                );
              }).toList(),
        ),
      ],
    );
  }

  String _orderKey(Map<String, dynamic> order) {
    for (final key in const ['id', 'order_id', 'order_no']) {
      final value = order[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return '';
  }

  DateTime? _followUpCooldownUntil(Map<String, dynamic> order) {
    final raw = order['last_customer_followup_at']?.toString();
    if (raw == null || raw.isEmpty) return null;
    final last = DateTime.tryParse(raw);
    if (last == null) return null;
    return last.add(_followUpCooldown);
  }

  String _formatCooldown(DateTime until) {
    final remaining = until.difference(DateTime.now());
    if (remaining.inMinutes <= 0) return 'now';
    return 'in ${remaining.inMinutes + 1}m';
  }

  Future<void> _sendFollowUp(Map<String, dynamic> order) async {
    final orderKey = _orderKey(order);
    if (orderKey.isEmpty || _sendingFollowUps.contains(orderKey)) return;
    setState(() => _sendingFollowUps.add(orderKey));
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('customer_token');
      if (token == null || token.isEmpty)
        throw Exception('Please log in again');
      final response = await http
          .post(
            Uri.parse(
              '$_apiBaseUrl/api/restaurant/orders/${Uri.encodeComponent(orderKey)}/follow-up',
            ),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          )
          .timeout(_requestTimeout);
      final data = response.body.isNotEmpty ? jsonDecode(response.body) : {};
      if (response.statusCode != 200) {
        throw Exception(
          data is Map
              ? data['error'] ?? 'Failed to send follow-up'
              : 'Failed to send follow-up',
        );
      }
      final updated = Map<String, dynamic>.from(data['order'] as Map? ?? {});
      final updatedKey = _orderKey(updated);
      setState(() {
        _allOrders =
            _allOrders.map((entry) {
              final existing = Map<String, dynamic>.from(entry);
              return _orderKey(existing) == updatedKey ? updated : existing;
            }).toList();
      });
      CustomerOrdersCache.instance.invalidateRestaurant();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Follow-up sent to the team.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _sendingFollowUps.remove(orderKey));
    }
  }
}
