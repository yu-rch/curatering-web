import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import '../utils/order_display_utils.dart';
import '../services/customer_orders_cache.dart';
import '../widgets/customer_order_feedback_dialog.dart';
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
  bool _gridView = false;
  final Set<String> _sendingFollowUps = {};
  final _searchCtrl = TextEditingController();
  String _statusFilter = 'all';
  static const Duration _requestTimeout = Duration(seconds: 45);
  static const Duration _followUpCooldown = Duration(minutes: 20);

  String get _apiBaseUrl {
    return apiBaseUrl;
  }

  @override
  void initState() {
    super.initState();
    _loadOrders();
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
    return _orders
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .where((order) {
          final status = _normalizeStatus('${order['status'] ?? ''}');
          if (_statusFilter != 'all' && status != _statusFilter) return false;
          if (q.isEmpty) return true;
          final orderNo =
              _shortOrderId(order['id'], order['order_no']).toLowerCase();
          final items = _normalizeOrderItems(order['items'])
              .map((i) => '${i['name'] ?? i['dishName'] ?? ''}'.toLowerCase())
              .join(' ');
          return orderNo.contains(q) || items.contains(q);
        })
        .toList();
  }

  Future<void> _loadOrders({bool force = false}) async {
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
              _orders = cached;
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
      final parsedOrders =
          rawOrders.whereType<Map>().map((entry) {
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
          }).toList();
      CustomerOrdersCache.instance.setRestaurantOrders(parsedOrders);
      if (mounted) {
        setState(() {
          _orders = parsedOrders;
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

  static const Duration _historyAfterClose = Duration(hours: 24);

  ({List<Map<String, dynamic>> active, List<Map<String, dynamic>> history})
  _splitOrders(List<Map<String, dynamic>> orders) {
    final active = <Map<String, dynamic>>[];
    final history = <Map<String, dynamic>>[];
    final now = DateTime.now();
    for (final o in orders) {
      final st = o['status']?.toString() ?? '';
      final closed = st == 'delivered' || st == 'cancelled';
      final t =
          DateTime.tryParse(o['updated_at']?.toString() ?? '') ??
          DateTime.tryParse(o['created_at']?.toString() ?? '');
      if (closed && t != null && now.difference(t) >= _historyAfterClose) {
        history.add(o);
      } else {
        active.add(o);
      }
    }
    return (active: active, history: history);
  }

  String _formatHeaderDate(String? iso) {
    if (iso == null) return '—';
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    const m = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${m[d.month - 1]} ${d.day.toString().padLeft(2, '0')}, ${d.year}';
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final items = _normalizeOrderItems(order['items']);
    final status = order['status'] ?? 'pending';
    final paymentStatus = order['payment_status'] ?? 'pending';
    final orderKey = _orderKey(order);
    final cooldownUntil = _followUpCooldownUntil(order);
    final canFollowUp =
        _isActiveOrder(status) &&
        orderKey.isNotEmpty &&
        (cooldownUntil == null || !cooldownUntil.isAfter(DateTime.now()));
    final canReview = _canReviewRestaurantOrder(order);
    final feedbackSubmitted = _hasFeedbackSubmitted(order);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.grey.shade100,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Purchase date',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      Text(
                        _formatHeaderDate(order['created_at']?.toString()),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order ID',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      Text(
                        _shortOrderId(order['id'], order['order_no']),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Total paid',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      Text(
                        '₱${order['total_amount'] ?? '0.00'}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...items.map((item) {
                  final name =
                      item['name'] ?? item['dishName'] ?? 'Unknown item';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.restaurant,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(
                                    status,
                                  ).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: _getStatusColor(status),
                                  ),
                                ),
                                child: Text(
                                  _formatStatus(status),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: _getStatusColor(status),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '₱${item['price'] ?? '0'}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                const Divider(height: 28),
                Chip(
                  label: Text(
                    'Payment: ${_formatPaymentStatus(paymentStatus)}',
                    style: const TextStyle(fontSize: 10, color: Colors.white),
                  ),
                  backgroundColor: _getPaymentStatusColor(paymentStatus),
                  padding: EdgeInsets.zero,
                ),
                if (_isActiveOrder(status)) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      onPressed:
                          canFollowUp && !_sendingFollowUps.contains(orderKey)
                              ? () => _sendFollowUp(order)
                              : null,
                      icon:
                          _sendingFollowUps.contains(orderKey)
                              ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : const Icon(Icons.notifications_active_outlined),
                      label: Text(
                        cooldownUntil != null &&
                                cooldownUntil.isAfter(DateTime.now())
                            ? 'Follow up available ${_formatCooldown(cooldownUntil)}'
                            : 'Follow up order',
                      ),
                    ),
                  ),
                ],
                if (canReview || feedbackSubmitted) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child:
                        feedbackSubmitted
                            ? Chip(
                              avatar: const Icon(
                                Icons.check_circle,
                                size: 18,
                                color: Colors.white,
                              ),
                              label: const Text(
                                'Feedback submitted',
                                style: TextStyle(color: Colors.white),
                              ),
                              backgroundColor: Colors.green,
                            )
                            : OutlinedButton.icon(
                              onPressed: () => _submitRestaurantFeedback(order),
                              icon: const Icon(Icons.rate_review_outlined),
                              label: const Text('Leave feedback'),
                            ),
                  ),
                ],
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
                          '${order['delivery_address']}',
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
        ],
      ),
    );
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

  String _shortOrderId(dynamic rawId, dynamic orderNo) {
    return formatRestaurantOrderNo({'order_no': orderNo, 'id': rawId});
  }

  bool _isActiveOrder(dynamic status) {
    final s = status.toString().toLowerCase();
    return s != 'delivered' && s != 'cancelled';
  }

  bool _hasFeedbackSubmitted(Map<String, dynamic> order) {
    return order['feedback_submitted'] == true ||
        order['feedbackSubmitted'] == true ||
        order['feedback_stars'] != null ||
        order['feedbackStars'] != null ||
        order['feedback_submitted_at'] != null ||
        order['feedbackSubmittedAt'] != null;
  }

  bool _canReviewRestaurantOrder(Map<String, dynamic> order) {
    final status =
        (order['status'] ?? order['order_status'] ?? '')
            .toString()
            .toLowerCase();
    return status == 'delivered' && !_hasFeedbackSubmitted(order);
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
        _orders =
            _orders.map((entry) {
              if (entry is! Map) return entry;
              final existing = Map<String, dynamic>.from(entry);
              return _orderKey(existing) == updatedKey ? updated : existing;
            }).toList();
      });
      CustomerOrdersCache.instance.setRestaurantOrders(
        _orders
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(),
      );
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

  Future<void> _submitRestaurantFeedback(Map<String, dynamic> order) async {
    final orderKey = _orderKey(order);
    if (orderKey.isEmpty) return;
    final result = await showCustomerOrderFeedbackDialog(
      context,
      title: 'Feedback · ${_shortOrderId(order['id'], order['order_no'])}',
      question: 'How was this restaurant order?',
    );
    if (result == null || !mounted) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('customer_token');
      if (token == null || token.isEmpty) {
        throw Exception('Please log in again');
      }
      final response = await http
          .post(
            Uri.parse(
              '$_apiBaseUrl/api/restaurant/orders/${Uri.encodeComponent(orderKey)}/feedback',
            ),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'stars': result.stars,
              'remarks': result.remarks,
            }),
          )
          .timeout(_requestTimeout);
      final data = response.body.isNotEmpty ? jsonDecode(response.body) : {};
      if (response.statusCode != 200) {
        throw Exception(
          data is Map
              ? data['error'] ?? 'Failed to submit feedback'
              : 'Failed to submit feedback',
        );
      }
      final updated = Map<String, dynamic>.from(data['order'] as Map? ?? {});
      final updatedKey = _orderKey(updated);
      setState(() {
        _orders =
            _orders.map((entry) {
              if (entry is! Map) return entry;
              final existing = Map<String, dynamic>.from(entry);
              if (_orderKey(existing) != orderKey) return existing;
              return updatedKey.isNotEmpty
                  ? updated
                  : {
                    ...existing,
                    'feedback_stars': result.stars,
                    'feedback_remarks': result.remarks,
                    'feedback_submitted': true,
                  };
            }).toList();
      });
      CustomerOrdersCache.instance.setRestaurantOrders(
        _orders
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thank you for your feedback.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Order History',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
            ),
            Text(
              'Easily view and manage all your previous orders.',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: Colors.white70,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_gridView ? Icons.view_list : Icons.grid_view),
            tooltip: _gridView ? 'List view' : 'Grid view',
            onPressed: () => setState(() => _gridView = !_gridView),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadOrders(force: true),
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
                            onPressed: () => _loadOrders(force: true),
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
                            onPressed: () => _loadOrders(force: true),
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
                    : Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          child: TextField(
                            controller: _searchCtrl,
                            decoration: InputDecoration(
                              hintText: 'Search order no, items',
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
                                      'No orders match your filters',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  )
                                  : LayoutBuilder(
                                    builder: (context, c) {
                                      final parts = _splitOrders(
                                        _filteredOrders,
                                      );
                                      final grid = _gridView;
                                      final cardW =
                                          grid
                                              ? (c.maxWidth - 44) / 2
                                              : c.maxWidth - 32;
                                      final segs = <Widget>[];

                                      Widget header(String t) => Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          4,
                                          4,
                                          4,
                                          8,
                                        ),
                                        child: Text(
                                          t,
                                          style: GoogleFonts.poppins(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      );

                                      if (parts.active.isNotEmpty) {
                                        segs.add(header('Active orders'));
                                        if (grid) {
                                          segs.add(
                                            Wrap(
                                              spacing: 12,
                                              runSpacing: 12,
                                              children:
                                                  parts.active.map((o) {
                                                    return SizedBox(
                                                      width: cardW,
                                                      child: _buildOrderCard(o),
                                                    );
                                                  }).toList(),
                                            ),
                                          );
                                        } else {
                                          for (final o in parts.active) {
                                            segs.add(_buildOrderCard(o));
                                          }
                                        }
                                      }
                                      if (parts.history.isNotEmpty) {
                                        segs.add(
                                          Padding(
                                            padding: const EdgeInsets.fromLTRB(
                                              4,
                                              16,
                                              4,
                                              8,
                                            ),
                                            child: Text(
                                              'Order history',
                                              style: GoogleFonts.poppins(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        );
                                        if (grid) {
                                          segs.add(
                                            Wrap(
                                              spacing: 12,
                                              runSpacing: 12,
                                              children:
                                                  parts.history.map((o) {
                                                    return SizedBox(
                                                      width: cardW,
                                                      child: _buildOrderCard(o),
                                                    );
                                                  }).toList(),
                                            ),
                                          );
                                        } else {
                                          for (final o in parts.history) {
                                            segs.add(_buildOrderCard(o));
                                          }
                                        }
                                      }
                                      return ListView(
                                        padding: const EdgeInsets.fromLTRB(
                                          16,
                                          12,
                                          16,
                                          24,
                                        ),
                                        children: segs,
                                      );
                                    },
                                  ),
                        ),
                      ],
                    ),
          ),
        ],
      ),
    );
  }
}
