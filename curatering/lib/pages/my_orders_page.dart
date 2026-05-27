import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config.dart';
import '../utils/order_display_utils.dart';
import '../services/customer_orders_cache.dart';
import '../services/menu_store.dart';
import '../widgets/restaurant_order_feedback_dialog.dart';

class MyOrdersPage extends StatefulWidget {
  const MyOrdersPage({super.key});

  @override
  State<MyOrdersPage> createState() => _MyOrdersPageState();
}

class _MyOrdersPageState extends State<MyOrdersPage>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _selectedOrder;
  final Set<String> _sendingFollowUps = {};
  final Set<String> _cancellingOrders = {};
  bool _submittingPayment = false;

  static const Duration _requestTimeout = Duration(seconds: 45);
  static const Duration _followUpCooldown = Duration(minutes: 20);
  static const _accent = Color(0xFFFFC024);

  late final TabController _tabController;

  static const _tabs = [
    'pending',
    'confirmed',
    'out_for_delivery',
    'delivered',
    'cancelled',
  ];
  static const _tabLabels = {
    'pending': 'Pending',
    'confirmed': 'Confirmed',
    'out_for_delivery': 'Out for Delivery',
    'delivered': 'Delivered',
    'cancelled': 'Cancelled',
  };

  String get _apiBaseUrl => apiBaseUrl;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    CustomerOrdersCache.instance.invalidateRestaurant();
    _loadOrders(force: true);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Data helpers
  // ---------------------------------------------------------------------------

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('customer_token');
  }

  Map<String, String> _authHeaders(String token) => {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

  Future<void> _loadOrders({bool force = false}) async {
    try {
      final token = await _getToken();
      if (token == null || token.isEmpty) {
        if (mounted) Navigator.of(context).pop('login_required');
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

      if (mounted) setState(() { _isLoading = true; _error = null; });

      final response = await http
          .get(
            Uri.parse('$_apiBaseUrl/api/restaurant/orders'),
            headers: _authHeaders(token),
          )
          .timeout(_requestTimeout);

      if (response.statusCode == 401) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('customer_token');
        await prefs.remove('customer_data');
        if (mounted) _showSessionExpiredDialog();
        return;
      }
      if (response.statusCode != 200) {
        throw Exception('Failed to load orders: ${response.statusCode}');
      }

      final data = jsonDecode(response.body);
      final parsed = (data['orders'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((e) {
        final o = Map<String, dynamic>.from(e);
        final raw = o['items'];
        if (raw is String) {
          try {
            o['items'] = jsonDecode(raw);
          } catch (_) {
            o['items'] = <dynamic>[];
          }
        }
        if (o['items'] is! List) o['items'] = <dynamic>[];
        return o;
      }).toList();

      CustomerOrdersCache.instance.setRestaurantOrders(parsed);
      if (mounted) {
        setState(() {
          _orders = parsed;
          _isLoading = false;
          if (_selectedOrder != null) {
            final key = _orderKey(_selectedOrder!);
            final updated = parsed.where((o) => _orderKey(o) == key).firstOrNull;
            _selectedOrder = updated;
          }
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
        setState(() { _error = 'Error loading orders: $e'; _isLoading = false; });
      }
    }
  }

  String _statusUpper(Map<String, dynamic> order) =>
      (order['order_status'] ?? order['status'] ?? '').toString().toUpperCase();

  String _fulfillmentUpper(Map<String, dynamic> order) =>
      (order['fulfillment_stage'] ?? '').toString().toUpperCase();

  double _effectiveAmountPaid(Map<String, dynamic> order) {
    final cashierInitial = _parseDouble(order['cashier_amount_received_initial']);
    final cashierBalance = _parseDouble(order['cashier_amount_received_balance']);
    final cashierCombined = _parseDouble(order['cashier_amount_received']);
    if (cashierInitial > 0 || cashierBalance > 0) {
      return cashierInitial + cashierBalance;
    }
    if (cashierCombined > 0) return cashierCombined;
    return _parseDouble(
      order['amount_paid'] ??
          order['amount_received'] ??
          order['amountReceived'],
    );
  }

  double _balanceDueFor(Map<String, dynamic> order) {
    var balanceDue = _parseDouble(
      order['balance_due'] ??
          order['balance_amount'] ??
          order['remaining_balance'] ??
          order['remainingBalance'] ??
          order['short_amount'] ??
          order['shortAmount'] ??
          order['unpaid_balance'] ??
          order['unpaidBalance'],
    );
    final total = _parseDouble(order['total_amount'] ?? order['total_cost']);
    final paid = _effectiveAmountPaid(order);
    if (balanceDue <= 0 && total > 0 && paid + 0.009 < total) {
      balanceDue = (total - paid).clamp(0, double.infinity);
    }
    return balanceDue;
  }

  bool _isInsufficientPayment(Map<String, dynamic> order) {
    final u = _statusUpper(order);
    final stage =
        (order['fulfillment_stage'] ?? order['fulfillmentStage'] ?? '')
            .toString()
            .toUpperCase();
    final paymentStatus =
        (order['payment_status'] ?? order['paymentStatus'] ?? '')
            .toString()
            .toUpperCase();
    final paymentReview =
        (order['balance_proof_pending_review'] ?? false) == true;
    final balanceDue = _parseDouble(
      order['balance_due'] ??
          order['balance_amount'] ??
          order['remaining_balance'] ??
          order['remainingBalance'] ??
          order['short_amount'] ??
          order['shortAmount'] ??
          order['unpaid_balance'] ??
          order['unpaidBalance'],
    );
    return u.contains('INSUFFICIENT') ||
        u.contains('PAYMENT_INSUFFICIENT') ||
        u.contains('WAIT_BALANCE') ||
        u.contains('BALANCE_REVIEW') ||
        u.contains('PAYMENT INSUFFICIENT') ||
        stage.contains('WAIT_BALANCE') ||
        stage.contains('BALANCE_REVIEW') ||
        paymentStatus.contains('INSUFFICIENT') ||
        paymentStatus.contains('PAYMENT_INSUFFICIENT') ||
        paymentStatus.contains('WAIT_BALANCE') ||
        paymentStatus.contains('BALANCE') ||
        paymentReview ||
        balanceDue > 0 ||
        _balanceDueFor(order) > 0;
  }

  bool _isOverpayment(Map<String, dynamic> order) {
    return _statusUpper(order).contains('OVERPAYMENT');
  }

  List<Map<String, dynamic>> _ordersForTab(String tab) {
    return _orders.where((o) {
      final u = _statusUpper(o);
      final stage = _fulfillmentUpper(o);
      if (u.contains('CANCEL')) {
        return tab == 'cancelled';
      }
      switch (tab) {
        case 'pending':
          return u.contains('PENDING') ||
              u.contains('WAITING FOR PAYMENT') ||
              u.contains('WAITING FOR ORDER') ||
              u.contains('BALANCE PAYMENT') ||
              _isInsufficientPayment(o);
        case 'confirmed':
          if (u.contains('DELIVERED') || stage == 'DELIVERED') return false;
          if (u.contains('OUT FOR DELIVERY') || stage == 'OUT_FOR_DELIVERY') {
            return false;
          }
          return u.contains('ORDER CONFIRMED') ||
              u.contains('CONFIRMED') ||
              u.contains('PREPARING') ||
              stage == 'IN_PREPARATION' ||
              _isOverpayment(o);
        case 'out_for_delivery':
          return u.contains('OUT FOR DELIVERY') || stage == 'OUT_FOR_DELIVERY';
        case 'delivered':
          return u.contains('DELIVERED') || stage == 'DELIVERED';
        case 'cancelled':
          return false;
        default:
          return false;
      }
    }).toList();
  }

  Future<void> _openTrackingLink(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return;
    final uri = Uri.tryParse(trimmed);
    if (uri == null) return;
    if (!uri.hasScheme && trimmed.startsWith('/')) {
      if (!mounted) return;
      Navigator.of(context).pushNamed(trimmed);
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String _orderKey(Map<String, dynamic> order) {
    for (final k in const ['id', 'order_id', 'order_no']) {
      final v = order[k]?.toString().trim();
      if (v != null && v.isNotEmpty) return v;
    }
    return '';
  }

  String _shortOrderId(Map<String, dynamic> order) {
    return formatRestaurantOrderNo(order);
  }

  bool _isActiveOrder(String status) {
    final s = status.toLowerCase();
    return s != 'delivered' && s != 'cancelled' && s != 'completed';
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

  List<Map<String, dynamic>> _normalizeItems(dynamic raw) {
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((e) {
      final item = Map<String, dynamic>.from(e);
      final dishId = (item['dish_id'] ??
              item['dishId'] ??
              item['menu_dish_id'] ??
              item['id'] ??
              '')
          .toString();
      var name = (item['name'] ??
              item['dishName'] ??
              item['dish_name'] ??
              item['item_name'] ??
              '')
          .toString()
          .trim();
      final looksUnknown =
          name.isEmpty || name.toLowerCase().contains('unknown');
      if (looksUnknown && dishId.isNotEmpty) {
        final dish = MenuStore.instance.findDishById(dishId);
        if (dish != null) {
          name = dish.name;
          item['name'] = name;
          item['dishName'] = name;
          if (item['image_base64'] == null && item['imageBase64'] == null) {
            item['image_base64'] = dish.imageBase64;
          }
        }
      }
      if (name.isEmpty) name = 'Item';
      item['name'] = name;
      return item;
    }).toList();
  }

  Widget _buildFeedbackPrompt({
    required VoidCallback onPressed,
    bool submitted = false,
  }) {
    if (submitted) {
      return Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green.shade400, size: 20),
          const SizedBox(width: 8),
          Text(
            'Thank you for your feedback!',
            style: TextStyle(color: Colors.green.shade700, fontSize: 12),
          ),
        ],
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFC024).withOpacity(0.22),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFFC024).withOpacity(0.5)),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Rate this order',
            onPressed: onPressed,
            icon: const Icon(Icons.rate_review_outlined, color: Color(0xFF1E1E1E)),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          Expanded(
            child: Text(
              'How was your order? Your feedback will help us improve!',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1E1E1E),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? iso) {
    if (iso == null) return '—';
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[d.month - 1]} ${d.day.toString().padLeft(2, '0')}, ${d.year}';
  }

  String _formatDateTime(String? iso) {
    if (iso == null) return '—';
    final d = DateTime.tryParse(iso)?.toLocal();
    if (d == null) return iso;
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final ampm = d.hour >= 12 ? 'PM' : 'AM';
    final min = d.minute.toString().padLeft(2, '0');
    return '${_formatDate(iso)} $h:$min $ampm';
  }

  double _parseDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _sendFollowUp(Map<String, dynamic> order) async {
    final key = _orderKey(order);
    if (key.isEmpty || _sendingFollowUps.contains(key)) return;

    final confirmed = await _showConfirmationDialog(
      title: 'Send Follow-Up',
      message: 'Send a follow-up notification to the team about this order?',
      confirmLabel: 'Send',
    );
    if (confirmed != true) return;

    setState(() => _sendingFollowUps.add(key));
    try {
      final token = await _getToken();
      if (token == null) throw Exception('Please log in again');
      final response = await http
          .post(
            Uri.parse('$_apiBaseUrl/api/restaurant/orders/${Uri.encodeComponent(key)}/follow-up'),
            headers: _authHeaders(token),
          )
          .timeout(_requestTimeout);
      final data = response.body.isNotEmpty ? jsonDecode(response.body) : {};
      if (response.statusCode != 200) {
        throw Exception(data is Map ? data['error'] ?? 'Failed to send follow-up' : 'Failed');
      }
      _applyUpdatedOrder(data['order']);
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
      if (mounted) setState(() => _sendingFollowUps.remove(key));
    }
  }

  Future<void> _cancelOrder(Map<String, dynamic> order) async {
    final key = _orderKey(order);
    if (key.isEmpty || _cancellingOrders.contains(key)) return;

    final confirmed = await _showConfirmationDialog(
      title: 'Cancel Order',
      message: 'Are you sure you want to cancel this order? This action cannot be undone.',
      confirmLabel: 'Cancel Order',
      isDestructive: true,
    );
    if (confirmed != true) return;

    setState(() => _cancellingOrders.add(key));
    try {
      final token = await _getToken();
      if (token == null) throw Exception('Please log in again');
      final response = await http
          .post(
            Uri.parse('$_apiBaseUrl/api/restaurant/orders/${Uri.encodeComponent(key)}/cancel'),
            headers: _authHeaders(token),
          )
          .timeout(_requestTimeout);
      final data = response.body.isNotEmpty ? jsonDecode(response.body) : {};
      if (response.statusCode != 200) {
        throw Exception(data is Map ? data['error'] ?? 'Failed to cancel order' : 'Failed');
      }
      _applyUpdatedOrder(data['order']);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order cancelled successfully.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _cancellingOrders.remove(key));
    }
  }

  Future<void> _submitBalancePayment(Map<String, dynamic> order, String base64Img, String refNumber) async {
    final key = _orderKey(order);
    if (key.isEmpty) return;

    setState(() => _submittingPayment = true);
    try {
      final token = await _getToken();
      if (token == null) throw Exception('Please log in again');
      final response = await http
          .post(
            Uri.parse('$_apiBaseUrl/api/restaurant/orders/${Uri.encodeComponent(key)}/payment'),
            headers: _authHeaders(token),
            body: jsonEncode({
              'paymentProof': base64Img,
              'paymentReference': refNumber,
              'type': 'balance',
            }),
          )
          .timeout(_requestTimeout);
      final data = response.body.isNotEmpty ? jsonDecode(response.body) : {};
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception(data is Map ? data['error'] ?? 'Failed to submit payment' : 'Failed');
      }
      _applyUpdatedOrder(data['order']);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Balance payment submitted successfully.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _submittingPayment = false);
    }
  }

  void _applyUpdatedOrder(dynamic rawUpdated) {
    if (rawUpdated is! Map) return;
    final updated = Map<String, dynamic>.from(rawUpdated);
    final updatedKey = _orderKey(updated);
    setState(() {
      _orders = _orders.map((o) {
        return _orderKey(o) == updatedKey ? updated : o;
      }).toList();
      if (_selectedOrder != null && _orderKey(_selectedOrder!) == updatedKey) {
        _selectedOrder = updated;
      }
    });
    CustomerOrdersCache.instance.setRestaurantOrders(
      _orders.map((e) => Map<String, dynamic>.from(e)).toList(),
    );
  }

  // ---------------------------------------------------------------------------
  // Dialogs
  // ---------------------------------------------------------------------------

  Future<bool?> _showConfirmationDialog({
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    bool isDestructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isDestructive ? Colors.red : _accent,
              foregroundColor: isDestructive ? Colors.white : Colors.black,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  void _showSessionExpiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Session Expired'),
        content: const Text('Your session has expired. Please log in again.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop('login_required');
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Status helpers
  // ---------------------------------------------------------------------------

  String _formatStatus(String status) {
    return status.replaceAll('_', ' ').toUpperCase();
  }

  String _displayStatusFor(Map<String, dynamic> order) {
    if (_isInsufficientPayment(order)) {
      return 'insufficient_payment';
    }
    return (order['order_status'] ?? order['status'] ?? 'pending')
        .toString()
        .toLowerCase();
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
      case 'pending_cashier':
        return Colors.orange;
      case 'insufficient_payment':
        return Colors.red.shade700;
      case 'confirmed':
        return Colors.blue;
      case 'preparing':
        return Colors.amber.shade700;
      case 'out_for_delivery':
      case 'out for delivery':
        return Colors.purple;
      case 'delivered':
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildStatusBadge(String status) {
    final color = _getStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        _formatStatus(status),
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }

  Widget _buildProofImage(String proof) {
    final bytes = _decodeMaybeBase64Image(proof);

    if (bytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(bytes, height: 160, fit: BoxFit.contain),
      );
    }

    final uri = Uri.tryParse(proof);
    if (uri != null && uri.hasScheme) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(proof, height: 160, fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Text('Could not load image')),
      );
    }
    return const SizedBox.shrink();
  }

  Uint8List? _decodeMaybeBase64Image(String raw) {
    final proof = raw.trim();
    if (proof.isEmpty) return null;
    String payload = proof;
    if (proof.startsWith('data:')) {
      final idx = proof.indexOf(',');
      if (idx == -1) return null;
      payload = proof.substring(idx + 1);
    }
    payload = payload.replaceAll(RegExp(r'\s+'), '');
    if (payload.isEmpty || payload.length < 40) return null;
    try {
      return base64Decode(payload);
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Navigation
  // ---------------------------------------------------------------------------


  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text('My Orders', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadOrders(force: true),
            tooltip: 'Refresh orders',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(46),
          child: Container(
            color: const Color(0xFF1E1E1E),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorColor: _accent,
              indicatorWeight: 3,
              labelColor: _accent,
              unselectedLabelColor: Colors.white60,
              labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
              unselectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w400, fontSize: 13),
              tabAlignment: TabAlignment.start,
              tabs: _tabs.map((t) {
                final count = _ordersForTab(t).length;
                return Tab(text: '${_tabLabels[t]} ($count)');
              }).toList(),
            ),
          ),
        ),
      ),
      body: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(_error!, style: const TextStyle(color: Colors.red)),
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
                    : TabBarView(
                        controller: _tabController,
                        children: _tabs.map((tab) => _buildSplitView(tab)).toList(),
                      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Split POS layout
  // ---------------------------------------------------------------------------

  Widget _buildSplitView(String tab) {
    final orders = _ordersForTab(tab);

    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No ${_tabLabels[tab]?.toLowerCase()} orders',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              'Orders with this status will appear here',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        // LEFT: Order list
        SizedBox(
          width: 380,
          child: _buildOrderList(orders),
        ),
        const VerticalDivider(width: 1, thickness: 1),
        // RIGHT: Order detail
        Expanded(
          child: _selectedOrder != null && orders.any((o) => _orderKey(o) == _orderKey(_selectedOrder!))
              ? _buildOrderDetail(_selectedOrder!)
              : _buildEmptyDetail(),
        ),
      ],
    );
  }

  Widget _buildOrderList(List<Map<String, dynamic>> orders) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: orders.length,
      itemBuilder: (context, i) {
        final order = orders[i];
        final key = _orderKey(order);
        final isSelected = _selectedOrder != null && _orderKey(_selectedOrder!) == key;
        final status = _displayStatusFor(order);
        final customerName = order['full_name'] ??
            order['customer_name'] ??
            order['customerName'] ??
            '';
        final paymentMethod =
            order['payment_method'] ?? order['payment_mode'] ?? '';
        final total = _parseDouble(order['total_amount'] ?? order['total_cost']);

        return Material(
          color: isSelected ? _accent.withOpacity(0.10) : Colors.transparent,
          child: InkWell(
            onTap: () => setState(() => _selectedOrder = order),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade200),
                  left: isSelected
                      ? const BorderSide(color: _accent, width: 4)
                      : BorderSide.none,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '#${_shortOrderId(order)}',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '₱${total.toStringAsFixed(2)}',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _formatDate(order['created_at']?.toString()),
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ),
                      _buildStatusBadge(status),
                    ],
                  ),
                  if (customerName.toString().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      customerName.toString(),
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (paymentMethod.toString().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      paymentMethod.toString(),
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (_isInsufficientPayment(order))
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Insufficient payment',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ),
                  if (_isOverpayment(order))
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Overpayment',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange.shade800,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyDetail() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.touch_app_outlined, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            'Select an order to view details',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Order detail panel (RIGHT side)
  // ---------------------------------------------------------------------------

  Widget _buildOrderDetail(Map<String, dynamic> order) {
    final items = _normalizeItems(order['tray_items'] ?? order['items']);
    final status = _displayStatusFor(order);
    final customerName = order['full_name'] ??
        order['customer_name'] ??
        order['customerName'] ??
        '—';
    final customerPhone =
        order['contact_number'] ?? order['customer_phone'] ?? order['phone'] ?? '';
    final deliveryAddress = order['delivery_address'] ?? '';
    final paymentMethod =
        order['payment_method'] ?? order['payment_mode'] ?? order['paymentMethod'] ?? '—';
    final feedbackStars = order['feedback_stars'];
    final canSubmitFeedback = status == 'delivered' ||
        _statusUpper(order).contains('DELIVERED');
    final amountPaid = _effectiveAmountPaid(order);
    final trackingUrl = order['delivery_tracking_url']?.toString();
    final paymentProof = order['payment_proof']?.toString();
    final paymentProofInitial = order['payment_proof_initial']?.toString();
    final balanceDue = _balanceDueFor(order);
    final isActive = _isActiveOrder(status);
    final isInsufficient = _isInsufficientPayment(order);
    final isPending =
        status == 'pending' ||
        status == 'pending_cashier' ||
        status == 'insufficient_payment' ||
        isInsufficient;
    final key = _orderKey(order);
    final cooldownUntil = _followUpCooldownUntil(order);
    final canFollowUp = isActive &&
        key.isNotEmpty &&
        (cooldownUntil == null || !cooldownUntil.isAfter(DateTime.now()));

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // Detail header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order #${_shortOrderId(order)}',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatDateTime(order['created_at']?.toString()),
                        style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                _buildStatusBadge(status),
              ],
            ),
          ),
          // Detail body
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (canSubmitFeedback)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _buildFeedbackPrompt(
                        submitted: feedbackStars != null,
                        onPressed: () async {
                          final submitted = await showRestaurantOrderFeedbackDialog(
                            context,
                            orderId: key,
                            orderLabel: _shortOrderId(order),
                            getToken: _getToken,
                          );
                          if (submitted) _loadOrders(force: true);
                        },
                      ),
                    ),
                  if (_isInsufficientPayment(order))
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Text(
                        'Insufficient payment — please submit balance payment proof and GCash reference below.',
                        style: TextStyle(
                          color: Colors.red.shade800,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  // Customer info
                  _sectionTitle('Customer Information'),
                  const SizedBox(height: 8),
                  _infoRow('Name', customerName.toString()),
                  if (customerPhone.toString().isNotEmpty)
                    _infoRow('Phone', customerPhone.toString()),
                  if (deliveryAddress.toString().isNotEmpty)
                    _infoRow('Delivery Address', deliveryAddress.toString()),
                  const SizedBox(height: 20),

                  // Payment info
                  _sectionTitle('Payment'),
                  const SizedBox(height: 8),
                  _infoRow('Method', paymentMethod.toString()),
                  _infoRow('Amount Paid', '₱${amountPaid.toStringAsFixed(2)}'),
                  const SizedBox(height: 20),

                  // Tracking URL
                  if (trackingUrl != null && trackingUrl.isNotEmpty) ...[
                    _sectionTitle('Delivery Tracking'),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () => _openTrackingLink(trackingUrl),
                      child: Row(
                        children: [
                          Icon(Icons.local_shipping, size: 16, color: Colors.blue.shade700),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              trackingUrl,
                              style: TextStyle(
                                color: Colors.blue.shade700,
                                decoration: TextDecoration.underline,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Items
                  _sectionTitle('Items (${items.length})'),
                  const SizedBox(height: 8),
                  ...items.map((item) {
                    final name = item['name'] ?? item['dishName'] ?? 'Item';
                    final qty = item['quantity'] ?? item['qty'] ?? 1;
                    final price = _parseDouble(item['price'] ?? item['dishPrice']);
                    final imgB64 = (item['image_base64'] ?? item['imageBase64'])?.toString();
                    Widget thumb;
                    if (imgB64 != null && imgB64.isNotEmpty) {
                      final decoded = _decodeMaybeBase64Image(imgB64);
                      if (decoded != null) {
                        thumb = ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            decoded,
                            width: 36,
                            height: 36,
                            fit: BoxFit.cover,
                          ),
                        );
                      } else if (Uri.tryParse(imgB64)?.hasScheme == true) {
                        thumb = ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            imgB64,
                            width: 36,
                            height: 36,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _itemPlaceholderThumb(),
                          ),
                        );
                      } else {
                        thumb = _itemPlaceholderThumb();
                      }
                    } else {
                      thumb = _itemPlaceholderThumb();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          thumb,
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '$name  x$qty',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ),
                          Text(
                            '₱${price.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ],
                      ),
                    );
                  }),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15)),
                      Text(
                        '₱${_parseDouble(order['total_amount'] ?? order['total_cost']).toStringAsFixed(2)}',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 17),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Payment proof images
                  if (paymentProofInitial != null && paymentProofInitial.isNotEmpty) ...[
                    _sectionTitle('Payment Proof'),
                    const SizedBox(height: 8),
                    _buildProofImage(paymentProofInitial),
                    const SizedBox(height: 12),
                  ],
                  if (paymentProof != null &&
                      paymentProof.isNotEmpty &&
                      paymentProof != paymentProofInitial) ...[
                    _sectionTitle('Balance Payment Proof'),
                    const SizedBox(height: 8),
                    _buildProofImage(paymentProof),
                    const SizedBox(height: 12),
                  ],

                  // Balance payment section
                  if ((_isInsufficientPayment(order) || balanceDue > 0) &&
                      (isActive || isPending)) ...[
                    const SizedBox(height: 8),
                    _buildBalancePaymentSection(order, balanceDue),
                    const SizedBox(height: 20),
                  ],

                  // Action buttons
                  if (isActive || isPending) ...[
                    const Divider(height: 32),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        if (isActive)
                          ElevatedButton.icon(
                            onPressed: canFollowUp && !_sendingFollowUps.contains(key)
                                ? () => _sendFollowUp(order)
                                : null,
                            icon: _sendingFollowUps.contains(key)
                                ? const SizedBox(
                                    width: 16, height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.notifications_active_outlined, size: 18),
                            label: Text(
                              cooldownUntil != null && cooldownUntil.isAfter(DateTime.now())
                                  ? 'Follow up ${_formatCooldown(cooldownUntil)}'
                                  : 'Follow Up',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _accent,
                              foregroundColor: Colors.black,
                            ),
                          ),
                        if (isPending)
                          OutlinedButton.icon(
                            onPressed: !_cancellingOrders.contains(key)
                                ? () => _cancelOrder(order)
                                : null,
                            icon: _cancellingOrders.contains(key)
                                ? const SizedBox(
                                    width: 16, height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.cancel_outlined, size: 18, color: Colors.red),
                            label: const Text('Cancel Order', style: TextStyle(color: Colors.red)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.red),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Balance payment section
  // ---------------------------------------------------------------------------

  Widget _buildBalancePaymentSection(Map<String, dynamic> order, double balanceDue) {
    return _BalancePaymentWidget(
      balanceDue: balanceDue,
      isSubmitting: _submittingPayment,
      onSubmit: (base64Img, refNumber) => _submitBalancePayment(order, base64Img, refNumber),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
    );
  }

  Widget _itemPlaceholderThumb() {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.restaurant, color: Colors.grey.shade500, size: 18),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Balance Payment Widget (stateful for file picker + reference input)
// =============================================================================

class _BalancePaymentWidget extends StatefulWidget {
  const _BalancePaymentWidget({
    required this.balanceDue,
    required this.isSubmitting,
    required this.onSubmit,
  });

  final double balanceDue;
  final bool isSubmitting;
  final Future<void> Function(String base64Img, String refNumber) onSubmit;

  @override
  State<_BalancePaymentWidget> createState() => _BalancePaymentWidgetState();
}

class _BalancePaymentWidgetState extends State<_BalancePaymentWidget> {
  final _refController = TextEditingController();
  String? _pickedFileName;
  String? _pickedBase64;
  static const _accent = Color(0xFFFFC024);

  @override
  void dispose() {
    _refController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      if (file.bytes != null) {
        setState(() {
          _pickedFileName = file.name;
          _pickedBase64 = base64Encode(file.bytes!);
        });
      }
    }
  }

  Future<void> _handleSubmit() async {
    if (_pickedBase64 == null || _pickedBase64!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload a proof of payment image.')),
      );
      return;
    }
    final ref = _refController.text.trim();
    if (ref.length != 13 || !RegExp(r'^\d{13}$').hasMatch(ref)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reference number must be exactly 13 digits.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Confirm Payment'),
        content: Text('Submit balance payment of ₱${widget.balanceDue.toStringAsFixed(2)} with reference $ref?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _accent, foregroundColor: Colors.black),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await widget.onSubmit(_pickedBase64!, ref);
    if (mounted) {
      setState(() {
        _pickedFileName = null;
        _pickedBase64 = null;
        _refController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                'Balance Due: ₱${widget.balanceDue.toStringAsFixed(2)}',
                style: TextStyle(fontWeight: FontWeight.w700, color: Colors.orange.shade900, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _pickFile,
            icon: const Icon(Icons.upload_file, size: 18),
            label: Text(_pickedFileName ?? 'Upload Proof of Payment'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.black87,
              side: BorderSide(color: Colors.grey.shade400),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _refController,
            keyboardType: TextInputType.number,
            maxLength: 13,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: 'GCash Reference Number',
              hintText: '13-digit reference',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              counterText: '',
              isDense: true,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: widget.isSubmitting ? null : _handleSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: widget.isSubmitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Submit Balance Payment', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}
