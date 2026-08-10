import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../config/site_routes.dart';
import '../utils/order_display_utils.dart';
import '../utils/responsive_layout.dart';
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

class _GuestOrderTrackingPageState extends State<GuestOrderTrackingPage> {
  final _formKey = GlobalKey<FormState>();
  final _orderNoCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  bool _loading = false;
  bool _loggedIn = false;
  String? _error;
  Map<String, dynamic>? _order;

  @override
  void initState() {
    super.initState();
    _hydrateFromQuery();
    _refreshAuth();
  }

  @override
  void dispose() {
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

  Future<void> _lookup() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
      _order = null;
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
      if (decoded is! Map || decoded['order'] is! Map) {
        throw Exception('Invalid response from server');
      }
      if (!mounted) return;
      setState(() {
        _order = Map<String, dynamic>.from(decoded['order'] as Map);
      });
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

  @override
  Widget build(BuildContext context) {
    final mobile = isMobileWidth(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          const CustomerWebsiteTopBar(),
          Expanded(
            child: SingleChildScrollView(
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
                        'Enter the email or phone used at checkout. Order number is optional.',
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
                      if (_order != null) ...[
                        const SizedBox(height: 24),
                        _GuestOrderResultCard(
                          order: _order!,
                          loggedIn: _loggedIn,
                          onSignUp: _openSignup,
                        ),
                      ],
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
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
              'Provide email or phone used at checkout. Order number is optional.',
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
    final address = '${order['delivery_address'] ?? order['deliveryAddress'] ?? '—'}';
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
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => OrderTrackingPage(orderData: order),
                ),
              );
            },
            icon: const Icon(Icons.open_in_new, size: 18),
            label: const Text('View full order details'),
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
    final s = status.toLowerCase();
    if (s.contains('cancel')) return -1;
    if (s.contains('deliver') || s.contains('complete')) return 3;
    if (s.contains('out_for') || s.contains('out for')) return 2;
    if (s.contains('prepar') ||
        s.contains('confirm') ||
        s.contains('in_preparation')) {
      return 1;
    }
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
