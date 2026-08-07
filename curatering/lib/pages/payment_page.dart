import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/website_header_font.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config.dart';
import 'order_tracking_page.dart';
import 'guest_order_tracking_page.dart';
import '../utils/order_display_utils.dart';
import '../utils/responsive_layout.dart';

class PaymentPage extends StatefulWidget {
  final Map<String, dynamic> orderData;
  const PaymentPage({super.key, required this.orderData});

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  final _referenceController = TextEditingController();
  bool _isLoading = false;
  bool _showValidation = false;

  @override
  void dispose() {
    _referenceController.dispose();
    super.dispose();
  }

  Future<void> _handleConfirmPayment() async {
    setState(() => _showValidation = true);
    if (_referenceError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid payment reference')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('customer_token');

      final orderKey =
          widget.orderData['order_id']?.toString() ??
          widget.orderData['id']?.toString() ??
          '';
      if (orderKey.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Order reference missing. Please place the order again.',
              ),
            ),
          );
        }
        return;
      }

      final body = <String, dynamic>{
        'paymentReference': _referenceController.text.trim(),
      };
      final guestEmail =
          widget.orderData['user_email']?.toString().trim() ??
          widget.orderData['userEmail']?.toString().trim() ??
          widget.orderData['guest_contact_email']?.toString().trim();
      if (guestEmail != null && guestEmail.isNotEmpty) {
        body['userEmail'] = guestEmail;
      }

      final headers = <String, String>{'Content-Type': 'application/json'};
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http.post(
        Uri.parse('${apiBaseUrl}/api/restaurant/orders/$orderKey/payment'),
        headers: headers,
        body: jsonEncode(body),
      );

      Map<String, dynamic> data = {};
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          data = decoded;
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Server error (${response.statusCode}). Please try again.',
              ),
            ),
          );
        }
        return;
      }

      final ok = response.statusCode == 200 || response.statusCode == 201;
      if (ok) {
        final rawOrder = data['order'];
        final orderMap =
            rawOrder is Map
                  ? Map<String, dynamic>.from(rawOrder)
                  : Map<String, dynamic>.from(widget.orderData)
              ..['payment_reference'] = _referenceController.text.trim()
              ..['payment_reference_initial'] = _referenceController.text.trim()
              ..['status'] = 'PENDING_CASHIER'
              ..['order_status'] = 'PENDING_CASHIER'
              ..['payment_uploaded_initial'] = true;

        if (mounted) {
          final isGuest = token == null || token.isEmpty;
          if (isGuest) {
            await _showGuestPaymentConfirmation(context, orderMap);
          } else {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => OrderTrackingPage(orderData: orderMap),
              ),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['error'] ?? 'Failed to confirm payment'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showGuestPaymentConfirmation(
    BuildContext context,
    Map<String, dynamic> orderMap,
  ) async {
    final orderNo = formatRestaurantOrderNo(orderMap);
    final guestEmail =
        orderMap['user_email']?.toString().trim() ??
        orderMap['userEmail']?.toString().trim() ??
        orderMap['guest_contact_email']?.toString().trim() ??
        '';

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return _GuestPaymentCountdownDialog(
          orderNo: orderNo,
          onComplete: () {
            Navigator.of(ctx).pop();
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder:
                    (_) => GuestOrderTrackingPage(
                      initialOrderNo: orderNo != 'N/A' ? orderNo : null,
                      initialEmail:
                          guestEmail.isNotEmpty ? guestEmail : null,
                      autoLookup:
                          orderNo != 'N/A' && guestEmail.isNotEmpty,
                    ),
              ),
            );
          },
        );
      },
    );
  }

  String? get _referenceError {
    final value = _referenceController.text.trim();
    if (value.isEmpty) return 'Reference number is required';
    if (!RegExp(r'^\d{13}$').hasMatch(value)) {
      return 'Reference number must be exactly 13 digits';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final totalAmount =
        widget.orderData['total_cost'] ??
        widget.orderData['total_amount'] ??
        '0.00';
    final displayOrderNo = formatRestaurantOrderNo(widget.orderData);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(''),
      ),
      body: SingleChildScrollView(
        padding: appPagePadding(context),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: appContentMaxWidth(context)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Payment title
                Center(
                  child: Text(
                    'Payment',
                    style: websiteHeaderStyle(
                      fontSize: 42,
                      color: Colors.red.shade400,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Order No badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFFFC024)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'ORDER NO. $displayOrderNo',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                // Three columns layout
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // DELIVERY INFORMATION
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              child: const Text(
                                'DELIVERY INFORMATION',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                            Divider(color: Colors.grey.shade200, height: 1),
                            Container(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildLabelAndValue(
                                    'NAME',
                                    widget.orderData['full_name'] ??
                                        widget.orderData['fullName'] ??
                                        '',
                                  ),
                                  const SizedBox(height: 16),
                                  _buildLabelAndValue(
                                    'CONTACT NUMBER',
                                    widget.orderData['contact_number'] ??
                                        widget.orderData['phone'] ??
                                        '',
                                  ),
                                  const SizedBox(height: 16),
                                  _buildLabelAndValue(
                                    'DELIVERY ADDRESS',
                                    widget.orderData['delivery_address'] ?? '',
                                  ),
                                  const SizedBox(height: 24),
                                  _buildLabelAndValue(
                                    'TIME OF DELIVERY',
                                    'NOW',
                                  ),
                                  const SizedBox(height: 16),
                                  _buildLabelAndValue(
                                    'MODE OF PAYMENT',
                                    'GCASH ONLY',
                                  ),
                                  const SizedBox(height: 32),
                                  // YOUR ORDER section
                                  const Center(
                                    child: Text(
                                      'YOUR ORDER',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  // Order items
                                  if ((widget.orderData['tray_items'] ??
                                          widget.orderData['items']) !=
                                      null)
                                    ...((widget.orderData['tray_items'] ??
                                                widget.orderData['items'])
                                            as List)
                                        .map((item) {
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 12,
                                            ),
                                            child: Row(
                                              children: [
                                                Container(
                                                  width: 40,
                                                  height: 40,
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey.shade200,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          4,
                                                        ),
                                                  ),
                                                  child: const Icon(
                                                    Icons.fastfood,
                                                    size: 16,
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        item['name']
                                                                ?.toString()
                                                                .toUpperCase() ??
                                                            '',
                                                        style: const TextStyle(
                                                          fontSize: 10,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                      if (item['sauces'] !=
                                                              null &&
                                                          (item['sauces']
                                                                  as List)
                                                              .isNotEmpty)
                                                        Text(
                                                          (item['sauces']
                                                                  as List)
                                                              .first
                                                              .toString()
                                                              .toUpperCase(),
                                                          style: TextStyle(
                                                            fontSize: 8,
                                                            color:
                                                                Colors
                                                                    .grey
                                                                    .shade600,
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                                Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.end,
                                                  children: [
                                                    Text(
                                                      'x${item['quantity'] ?? 1}',
                                                      style: const TextStyle(
                                                        fontSize: 9,
                                                      ),
                                                    ),
                                                    Text(
                                                      '₱${item['price'] ?? 0}',
                                                      style: const TextStyle(
                                                        fontSize: 9,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          );
                                        })
                                        .toList(),
                                  const SizedBox(height: 16),
                                  Divider(color: Colors.grey.shade200),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'TOTAL',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        '₱${totalAmount.toString()}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '₱${totalAmount.toString()}',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.amber.shade800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // PAYMENT
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              child: const Text(
                                'PAYMENT',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                            Divider(color: Colors.grey.shade200, height: 1),
                            Container(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                children: [
                                  Text(
                                    'PLEASE SCAN THIS QR CODE TO PAY.',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Image.asset(
                                      'lib/assets/gcash_qr.jpg',
                                      width: 200,
                                      height: 280,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                  const SizedBox(height: 32),
                                  Text(
                                    'ONCE PAID, PLEASE TYPE THE REFERENCE NUMBER BELOW:',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      SizedBox(
                                        width: 60,
                                        child: Text(
                                          'REF NO.',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: TextField(
                                          controller: _referenceController,
                                          keyboardType: TextInputType.number,
                                          maxLength: 13,
                                          inputFormatters: [
                                            FilteringTextInputFormatter
                                                .digitsOnly,
                                          ],
                                          style: const TextStyle(fontSize: 12),
                                          onChanged: (_) {
                                            if (_showValidation)
                                              setState(() {});
                                          },
                                          decoration: InputDecoration(
                                            isDense: true,
                                            errorText:
                                                _showValidation
                                                    ? _referenceError
                                                    : null,
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              borderSide: BorderSide(
                                                color: Colors.grey.shade300,
                                              ),
                                            ),
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 8,
                                                ),
                                            counterText: '',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 40),
                                  ElevatedButton(
                                    onPressed:
                                        _isLoading
                                            ? null
                                            : _handleConfirmPayment,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFFFC024),
                                      foregroundColor: Colors.black,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 48,
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                    ),
                                    child:
                                        _isLoading
                                            ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                            : const Text(
                                              'CONFIRM',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
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
                    // NOTES
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.only(left: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              child: const Text(
                                'NOTES',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                            Divider(color: Colors.grey.shade200, height: 1),
                            Container(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'PLEASE PREPARE YOUR GCASH APP TO SCAN OUR QR CODE FOR PAYMENT.',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade700,
                                      height: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'PLEASE SEND THE EXACT AMOUNT OF YOUR TOTAL COST ONLY.',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade700,
                                      height: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'ORDERS WITH INSUFFICIENT PAYMENT WILL NOT BE CONFIRMED.',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade700,
                                      height: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'ONCE ORDER IS PAID, PLEASE WAIT FOR YOUR ORDER TO BE PROCESSED AND DELIVERED.',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade700,
                                      height: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'THANK YOU!',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade700,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabelAndValue(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              value.isEmpty ? '' : value,
              style: TextStyle(
                fontSize: 11,
                color: value.isEmpty ? Colors.grey.shade400 : Colors.black,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GuestPaymentCountdownDialog extends StatefulWidget {
  const _GuestPaymentCountdownDialog({
    required this.orderNo,
    required this.onComplete,
  });

  final String orderNo;
  final VoidCallback onComplete;

  @override
  State<_GuestPaymentCountdownDialog> createState() =>
      _GuestPaymentCountdownDialogState();
}

class _GuestPaymentCountdownDialogState
    extends State<_GuestPaymentCountdownDialog> {
  static const _totalSeconds = 5;
  late int _secondsLeft;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _secondsLeft = _totalSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft <= 1) {
        timer.cancel();
        widget.onComplete();
        return;
      }
      if (mounted) setState(() => _secondsLeft--);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Payment confirmed'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.orderNo != 'N/A'
                ? 'Thank you! Order ${widget.orderNo} is being processed.'
                : 'Thank you! Your order is being processed.',
          ),
          const SizedBox(height: 12),
          Text(
            'Redirecting to order tracking in $_secondsLeft…',
            style: TextStyle(color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }
}
