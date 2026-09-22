import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../config/site_routes.dart';
import '../services/menu_store.dart';
import '../utils/order_display_utils.dart';
import '../utils/responsive_layout.dart';
import '../widgets/customer_account_shell.dart';
import '../widgets/customer_pages_top_bar.dart';
import '../widgets/customer_website_topbar.dart';
import 'customer_login.dart';
import 'order_tracking_page.dart';

/// Public order tracking for guests (no login required).
/// Lookup by email or phone (order number optional).
class GuestOrderTrackingPage extends StatefulWidget {
  const GuestOrderTrackingPage({
    super.key,
    this.initialOrderNo,
    this.initialEmail,
    this.initialPhone,
    this.autoLookup = false,
  });

  final String? initialOrderNo;
  final String? initialEmail;
  final String? initialPhone;
  final bool autoLookup;

  @override
  State<GuestOrderTrackingPage> createState() => _GuestOrderTrackingPageState();
}

class _GuestOrderTrackingPageState extends State<GuestOrderTrackingPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _orderNoCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  bool _loading = false;
  bool _loggedIn = false;
  String? _error;
  List<Map<String, dynamic>> _restaurantOrders = [];
  List<Map<String, dynamic>> _inquiries = [];
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted && !_tabController.indexIsChanging) setState(() {});
    });
    _hydrateFromQuery();
    _refreshAuth();
    unawaited(MenuStore.instance.loadDishesWithImages(silent: true));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _orderNoCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _hydrateFromQuery() {
    final q = Uri.base.queryParameters;
    final orderNo =
        widget.initialOrderNo?.trim().isNotEmpty == true
            ? widget.initialOrderNo!.trim()
            : (q['order'] ?? q['orderNo'] ?? q['order_no'] ?? '').trim();
    final email =
        widget.initialEmail?.trim().isNotEmpty == true
            ? widget.initialEmail!.trim()
            : (q['email'] ?? '').trim();
    final phone =
        widget.initialPhone?.trim().isNotEmpty == true
            ? widget.initialPhone!.trim()
            : (q['phone'] ?? '').trim();
    if (orderNo.isNotEmpty) _orderNoCtrl.text = orderNo;
    if (email.isNotEmpty) _emailCtrl.text = email;
    if (phone.isNotEmpty) _phoneCtrl.text = phone;
    // Order number is optional; email or phone is enough to look up.
    final shouldLookup =
        widget.autoLookup || (email.isNotEmpty || phone.isNotEmpty);
    if (shouldLookup) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_lookup());
      });
    } else {
      unawaited(_hydrateFromCache());
    }
  }

  Future<void> _hydrateFromCache() async {
    if (_orderNoCtrl.text.trim().isNotEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final orderNo = prefs.getString('guest_track_order_no')?.trim() ?? '';
    final email = prefs.getString('guest_track_email')?.trim() ?? '';
    final phone = prefs.getString('guest_track_phone')?.trim() ?? '';
    if (!mounted) return;
    if (orderNo.isNotEmpty) _orderNoCtrl.text = orderNo;
    if (email.isNotEmpty && _emailCtrl.text.isEmpty) _emailCtrl.text = email;
    if (phone.isNotEmpty && _phoneCtrl.text.isEmpty) _phoneCtrl.text = phone;
    if (email.isNotEmpty || phone.isNotEmpty) {
      unawaited(_lookup());
    }
  }

  Future<void> _refreshAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('customer_token');
    if (!mounted) return;
    setState(() => _loggedIn = token != null && token.isNotEmpty);
  }

  Future<void> _openSignup() async {
    await showDialog<void>(
      context: context,
      builder: (context) => const CustomerLoginPage(),
    );
    await _refreshAuth();
  }

  List<Map<String, dynamic>> _asMapList(dynamic raw) {
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  void _selectDefaultTab() {
    if (_inquiries.isNotEmpty && _restaurantOrders.isEmpty) {
      _tabController.index = 0;
    } else if (_restaurantOrders.isNotEmpty && _inquiries.isEmpty) {
      _tabController.index = 1;
    } else if (_inquiries.isNotEmpty) {
      _tabController.index = 0;
    } else {
      _tabController.index = 1;
    }
  }

  Future<void> _lookup() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
      _restaurantOrders = [];
      _inquiries = [];
    });
    try {
      final body = <String, dynamic>{};
      final orderNo = _orderNoCtrl.text.trim();
      final email = _emailCtrl.text.trim();
      final phone = _phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
      if (orderNo.isNotEmpty) body['orderNo'] = orderNo;
      if (email.isNotEmpty) body['email'] = email;
      if (phone.isNotEmpty) body['phone'] = phone;

      final response = await http
          .post(
            Uri.parse('$apiBaseUrl/api/restaurant/orders/guest-track'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));

      final decoded = jsonDecode(response.body);
      if (response.statusCode != 200) {
        final msg =
            decoded is Map
                ? (decoded['error'] ?? decoded['message'] ?? 'Order not found')
                : 'Order not found';
        throw Exception(msg);
      }
      if (decoded is! Map) {
        throw Exception('Invalid response from server');
      }

      var restaurant = _asMapList(decoded['restaurantOrders']);
      var inquiries = _asMapList(decoded['inquiries']);

      // Backward compat: single `order` payload.
      if (restaurant.isEmpty &&
          decoded['order'] is Map &&
          inquiries.isEmpty) {
        restaurant = [Map<String, dynamic>.from(decoded['order'] as Map)];
      }

      if (!mounted) return;
      setState(() {
        _restaurantOrders = restaurant;
        _inquiries = inquiries;
      });
      _selectDefaultTab();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('guest_track_order_no', orderNo);
      if (email.isNotEmpty) {
        await prefs.setString('guest_track_email', email);
      }
      if (phone.isNotEmpty) {
        await prefs.setString('guest_track_phone', phone);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _hasResults =>
      _restaurantOrders.isNotEmpty || _inquiries.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final mobile = isMobileWidth(context);
    final body = SingleChildScrollView(
      padding: appPagePadding(context),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: mobile ? double.infinity : 920,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Track your order',
                style: TextStyle(
                  fontSize: mobile ? 28 : 36,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1E1E1E),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter the email or phone used at checkout. Order number is optional — without it, we list all matching ongoing orders.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),
              if (!_loggedIn) ...[
                const SizedBox(height: 16),
                _SignupRewardsBanner(onSignUp: _openSignup),
              ],
              const SizedBox(height: 20),
              _buildLookupCard(mobile),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(
                    _error!,
                    style: TextStyle(color: Colors.red.shade800),
                  ),
                ),
              ],
              if (_hasResults) ...[
                const SizedBox(height: 24),
                _buildResultsTabs(),
              ],
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          const CustomerWebsiteTopBar(),
          Expanded(
            child: CustomerAccountShell(
              currentTab: CustomerPageTab.tracking,
              trackingRoute: '/track-order',
              guestTrackingMode: !_loggedIn,
              guestTrackingSection:
                  _tabController.index == 0
                      ? GuestTrackingSection.inquiries
                      : GuestTrackingSection.restaurant,
              onGuestTrackingSection: (section) {
                final index =
                    section == GuestTrackingSection.inquiries ? 0 : 1;
                if (_tabController.index != index) {
                  _tabController.animateTo(index);
                }
                setState(() {});
              },
              body: body,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsTabs() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF1E1E1E),
            unselectedLabelColor: Colors.grey.shade600,
            indicatorColor: const Color(0xFFFFC024),
            indicatorWeight: 3,
            tabs: [
              Tab(text: 'Inquiries (${_inquiries.length})'),
              Tab(text: 'Restaurant (${_restaurantOrders.length})'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AnimatedBuilder(
          animation: _tabController,
          builder: (context, _) {
            final isInquiries = _tabController.index == 0;
            final items = isInquiries ? _inquiries : _restaurantOrders;
            if (items.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Text(
                  isInquiries
                      ? 'No ongoing catering inquiries found for this contact.'
                      : 'No ongoing restaurant orders found for this contact.',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              );
            }
            return Column(
              children: [
                for (final item in items) ...[
                  if (isInquiries)
                    _GuestInquiryResultCard(
                      inquiry: item,
                      loggedIn: _loggedIn,
                      onSignUp: _openSignup,
                    )
                  else
                    _GuestOrderResultCard(
                      order: item,
                      loggedIn: _loggedIn,
                      onSignUp: _openSignup,
                    ),
                  const SizedBox(height: 12),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildLookupCard(bool mobile) {
    return Container(
      padding: EdgeInsets.all(mobile ? 16 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _orderNoCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Order number (optional)',
                hintText: 'e.g. ORD-000123',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              validator: (v) => null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email used at checkout',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              maxLength: 11,
              decoration: const InputDecoration(
                labelText: 'Phone (optional if email provided)',
                hintText: '09123456789',
                border: OutlineInputBorder(),
                isDense: true,
                counterText: '',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Provide email or phone used at checkout. Leave order number blank to see all ongoing matches.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 46,
              child: ElevatedButton(
                onPressed: _loading
                    ? null
                    : () {
                        final email = _emailCtrl.text.trim();
                        final phone =
                            _phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
                        if (email.isEmpty && phone.isEmpty) {
                          setState(
                            () => _error =
                                'Enter the email or phone number used for this order.',
                          );
                          return;
                        }
                        _lookup();
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFC024),
                  foregroundColor: const Color(0xFF1E1E1E),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'Track order',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignupRewardsBanner extends StatelessWidget {
  const _SignupRewardsBanner({required this.onSignUp});

  final VoidCallback onSignUp;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFC024)),
      ),
      child: Row(
        children: [
          const Icon(Icons.card_giftcard, color: Color(0xFF1E1E1E)),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Sign up to redeem rewards.',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: Color(0xFF1E1E1E),
              ),
            ),
          ),
          TextButton(
            onPressed: onSignUp,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF1E1E1E),
              backgroundColor: const Color(0xFFFFC024),
            ),
            child: const Text(
              'Sign up',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuestInquiryResultCard extends StatelessWidget {
  const _GuestInquiryResultCard({
    required this.inquiry,
    required this.loggedIn,
    required this.onSignUp,
  });

  final Map<String, dynamic> inquiry;
  final bool loggedIn;
  final VoidCallback onSignUp;

  @override
  Widget build(BuildContext context) {
    final id =
        '${inquiry['cateringId'] ?? inquiry['catering_id'] ?? inquiry['id'] ?? '—'}';
    final title =
        '${inquiry['eventTitle'] ?? inquiry['event_title'] ?? 'Catering inquiry'}';
    final status = '${inquiry['status'] ?? '—'}';
    final address = '${inquiry['address'] ?? '—'}';
    final total = inquiry['totalCost'] ?? inquiry['total_cost'] ?? 0;
    final orderType = '${inquiry['orderType'] ?? inquiry['order_type'] ?? ''}';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'REF. $id${orderType.isNotEmpty ? ' · ${orderType.toUpperCase()}' : ''}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 12),
          _infoRow('Status', status.replaceAll('_', ' ').toUpperCase()),
          _infoRow('Venue / address', address),
          _infoRow('Total', 'PHP ${NumberFormatHelper.pesos(total)}'),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () {
              showDialog<void>(
                context: context,
                builder: (ctx) => Dialog(
                  insetPadding: const EdgeInsets.all(16),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 720,
                      maxHeight: 720,
                    ),
                    child: _InquiryDetailsPopup(inquiry: inquiry),
                  ),
                ),
              );
            },
            icon: const Icon(Icons.open_in_new, size: 18),
            label: const Text('See order details'),
          ),
          if (!loggedIn) ...[
            const SizedBox(height: 12),
            _SignupRewardsBanner(onSignUp: onSignUp),
          ],
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              Navigator.of(context).pushNamedAndRemoveUntil(
                customerRoute('/'),
                (_) => false,
              );
            },
            child: const Text('Back to home'),
          ),
        ],
      ),
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
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuestOrderResultCard extends StatelessWidget {
  const _GuestOrderResultCard({
    required this.order,
    required this.loggedIn,
    required this.onSignUp,
  });

  final Map<String, dynamic> order;
  final bool loggedIn;
  final VoidCallback onSignUp;

  String get _status {
    final raw =
        '${order['order_status'] ?? order['status'] ?? order['fulfillment_stage'] ?? ''}';
    return raw.trim().isEmpty ? 'pending_cashier' : raw;
  }

  @override
  Widget build(BuildContext context) {
    final orderNo = formatRestaurantOrderNo(order);
    final status = _status.toLowerCase();
    final trackingUrl =
        '${order['delivery_tracking_url'] ?? order['deliveryTrackingUrl'] ?? ''}'
            .trim();
    final address =
        '${order['delivery_address'] ?? order['deliveryAddress'] ?? '—'}';
    final total =
        order['total_cost'] ?? order['total_amount'] ?? order['totalAmount'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'ORDER NO. $orderNo',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 12),
          _StatusTimeline(status: status),
          const SizedBox(height: 16),
          _info('Delivery address', address),
          _info('Total', 'PHP ${NumberFormatHelper.pesos(total)}'),
          if (trackingUrl.isNotEmpty) ...[
            const SizedBox(height: 8),
            SelectableText(
              'Courier tracking: $trackingUrl',
              style: const TextStyle(fontSize: 13, color: Colors.blue),
            ),
          ],
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () {
              showDialog<void>(
                context: context,
                builder: (ctx) => Dialog(
                  insetPadding: const EdgeInsets.all(16),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720, maxHeight: 640),
                    child: OrderTrackingPage(orderData: order),
                  ),
                ),
              );
            },
            icon: const Icon(Icons.open_in_new, size: 18),
            label: const Text('See order details'),
          ),
          if (!loggedIn) ...[
            const SizedBox(height: 12),
            _SignupRewardsBanner(onSignUp: onSignUp),
          ],
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              Navigator.of(context).pushNamedAndRemoveUntil(
                customerRoute('/'),
                (_) => false,
              );
            },
            child: const Text('Back to home'),
          ),
        ],
      ),
    );
  }

  Widget _info(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class NumberFormatHelper {
  static String pesos(dynamic value) {
    final n = value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
    return n.toStringAsFixed(2);
  }
}

class _StatusTimeline extends StatelessWidget {
  const _StatusTimeline({required this.status});

  final String status;

  static const _steps = [
    ('pending_cashier', 'Payment review'),
    ('in_preparation', 'Preparing'),
    ('out_for_delivery', 'Out for delivery'),
    ('delivered', 'Delivered'),
  ];

  int get _activeIndex {
    final s = status.toLowerCase().trim().replaceAll(' ', '_');
    if (s.contains('cancel')) return -1;
    // 'out_for_delivery' also contains 'deliver', so the dispatched stage has
    // to be matched before the delivered stage or it reads as delivered.
    if (s.contains('out_for')) return 2;
    if (s.contains('deliver') || s.contains('complete')) return 3;
    if (s.contains('prepar') || s.contains('confirm')) return 1;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    if (status.toLowerCase().contains('cancel')) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'This order was cancelled.',
          style: TextStyle(
            color: Colors.red.shade800,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    final active = _activeIndex;
    return Column(
      children: [
        for (var i = 0; i < _steps.length; i++) ...[
          Row(
            children: [
              Icon(
                i <= active ? Icons.check_circle : Icons.radio_button_unchecked,
                color: i <= active
                    ? const Color(0xFF1DB954)
                    : Colors.grey.shade400,
                size: 22,
              ),
              const SizedBox(width: 10),
              Text(
                _steps[i].$2,
                style: TextStyle(
                  fontWeight: i == active ? FontWeight.w800 : FontWeight.w500,
                  color: i <= active
                      ? const Color(0xFF1E1E1E)
                      : Colors.grey.shade600,
                ),
              ),
            ],
          ),
          if (i < _steps.length - 1)
            Padding(
              padding: const EdgeInsets.only(left: 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: 2,
                  height: 14,
                  color: i < active
                      ? const Color(0xFF1DB954)
                      : Colors.grey.shade300,
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _InquiryDetailsPopup extends StatelessWidget {
  const _InquiryDetailsPopup({required this.inquiry});

  final Map<String, dynamic> inquiry;

  String _formatStatus(String? status) {
    if (status == null || status.trim().isEmpty) return '—';
    return status.replaceAll('_', ' ').toUpperCase();
  }

  String _formatSchedule(dynamic raw) {
    final slots = <dynamic>[];
    if (raw is List) {
      slots.addAll(raw);
    } else if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) slots.addAll(decoded);
      } catch (_) {}
    }
    if (slots.isEmpty) return '—';
    return slots
        .map((slot) {
          if (slot is! Map) return '';
          final date = '${slot['date'] ?? ''}'.trim();
          final start = '${slot['startTime'] ?? slot['start_time'] ?? ''}'.trim();
          final end = '${slot['endTime'] ?? slot['end_time'] ?? ''}'.trim();
          if (date.isEmpty) return '';
          if (start.isEmpty && end.isEmpty) return date;
          return '$date $start–$end'.trim();
        })
        .where((s) => s.isNotEmpty)
        .join('\n');
  }

  List<String> _menuLines() {
    final menuRaw = inquiry['menu'] ?? inquiry['menuItems'] ?? inquiry['dishes'];
    final menu = <String>[];
    if (menuRaw is List) {
      for (final item in menuRaw) {
        if (item is String && item.trim().isNotEmpty) {
          menu.add(item.trim());
        } else if (item is Map) {
          final name =
              '${item['dishName'] ?? item['dish_name'] ?? item['name'] ?? ''}'
                  .trim();
          final price = '${item['price'] ?? ''}'.trim();
          if (name.isNotEmpty) {
            menu.add(price.isNotEmpty ? '$name · PHP $price' : name);
          }
        }
      }
    }
    return menu;
  }

  Map<String, dynamic> _themeMap() {
    final raw = inquiry['themeDesign'] ?? inquiry['theme_design'];
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return {};
  }

  List<MapEntry<String, String>> _themePreferenceRows(Map<String, dynamic> td) {
    final rows = <MapEntry<String, String>>[];
    void add(String label, dynamic value) {
      if (value == null) return;
      if (value is List) {
        final joined = value
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .join(', ');
        if (joined.isNotEmpty) rows.add(MapEntry(label, joined));
        return;
      }
      final text = value.toString().trim();
      if (text.isNotEmpty) rows.add(MapEntry(label, text));
    }

    add('Style', td['style'] ?? td['macrinaTheme']);
    add('Mood & lighting', td['mood']);
    add('Color palette', td['colorPalette'] ?? td['macrinaColorPalette']);
    add('Decor', td['decorElements'] ?? td['decor']);
    add(
      'Notes',
      td['customerNote'] ?? td['note'] ?? td['customInstructions'],
    );
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final title =
        '${inquiry['eventTitle'] ?? inquiry['event_title'] ?? 'Catering inquiry'}';
    final menu = _menuLines();
    final theme = _themeMap();
    final themePrefs = _themePreferenceRows(theme);
    final wide = MediaQuery.sizeOf(context).width >= 700;

    return Material(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: const Color(0xFF1E1E1E),
            child: ListTile(
              title: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Wrap(
                  spacing: 24,
                  runSpacing: 8,
                  children: [
                    SizedBox(
                      width: wide ? 220 : double.infinity,
                      child: _row(
                        'Status',
                        _formatStatus('${inquiry['status'] ?? ''}'),
                      ),
                    ),
                    SizedBox(
                      width: wide ? 220 : double.infinity,
                      child: _row(
                        'Total cost',
                        'PHP ${NumberFormatHelper.pesos(inquiry['totalCost'] ?? inquiry['total_cost'] ?? 0)}',
                      ),
                    ),
                    SizedBox(
                      width: wide ? 220 : double.infinity,
                      child: _row(
                        'Event type',
                        '${inquiry['eventType'] ?? inquiry['event_type'] ?? '—'}',
                      ),
                    ),
                    SizedBox(
                      width: wide ? 220 : double.infinity,
                      child: _row(
                        'Guests',
                        '${inquiry['guestCount'] ?? inquiry['guest_count'] ?? '—'}',
                      ),
                    ),
                    SizedBox(
                      width: wide ? 220 : double.infinity,
                      child: _row(
                        'Formality',
                        '${inquiry['formalityLevel'] ?? inquiry['formality_level'] ?? '—'}',
                      ),
                    ),
                    SizedBox(
                      width: wide ? 220 : double.infinity,
                      child: _row(
                        'Created',
                        '${inquiry['createdAt'] ?? inquiry['created_at'] ?? '—'}'
                            .toString()
                            .split('T')
                            .first,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _row(
                  'Type',
                  '${inquiry['orderType'] ?? inquiry['order_type'] ?? '—'}',
                ),
                _row(
                  'Venue',
                  '${inquiry['address'] ?? inquiry['venue'] ?? '—'}',
                ),
                _row(
                  'Schedule',
                  _formatSchedule(
                    inquiry['scheduleSlots'] ?? inquiry['schedule_slots'],
                  ),
                ),
                _row(
                  'Allergens',
                  (() {
                    final a = '${inquiry['allergens'] ?? ''}'.trim();
                    return a.isEmpty ? '—' : a;
                  })(),
                ),
                if (menu.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Menu',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  ...menu.map(
                    (name) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• '),
                          Expanded(child: Text(name)),
                        ],
                      ),
                    ),
                  ),
                ],
                if (themePrefs.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Event theme design',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  ...themePrefs.map(
                    (row) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: _row(row.key, row.value),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  'Sign in to My Caterings to follow up or manage this inquiry. Guests can view details only.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
