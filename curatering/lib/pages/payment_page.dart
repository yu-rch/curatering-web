import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/cart_store.dart';
import '../config.dart';
import 'order_tracking_page.dart';

// Runtime fallback for dev mode (String.fromEnvironment defaultValue doesn't work in JIT mode)
String get _apiBaseUrl => apiBaseUrl.isEmpty ? 'http://localhost:3000' : apiBaseUrl;

class PaymentPage extends StatefulWidget {
  final Map<String, dynamic> orderData;
  const PaymentPage({super.key, required this.orderData});

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  final _referenceController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _referenceController.dispose();
    super.dispose();
  }

  Future<void> _handleConfirmPayment() async {
    if (_referenceController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the payment reference number')),
      );
      return;
    }
    
    if (_referenceController.text.trim().length != 13 || !RegExp(r'^\d{13}$').hasMatch(_referenceController.text.trim())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 13-digit reference number')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('customer_token');

      final response = await http.post(
        Uri.parse('$_apiBaseUrl/api/restaurant/orders/${widget.orderData['id']}/payment'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'paymentReference': _referenceController.text.trim(),
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => OrderTrackingPage(orderData: data['order']),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['error'] ?? 'Failed to confirm payment')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalAmount = widget.orderData['total_amount'] ?? '0.00';
    final orderId = widget.orderData['id']?.toString() ?? '';
    final shortOrderId = orderId.length >= 6 ? orderId.substring(orderId.length - 6) : orderId;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(''),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Payment title
                Center(
                  child: Text(
                    'Payment',
                    style: GoogleFonts.dancingScript(
                      fontSize: 42,
                      color: Colors.red.shade400,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Order No badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFFFC024)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'ORDER NO. ${shortOrderId.padLeft(6, '0')}',
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
                                  _buildLabelAndValue('NAME', widget.orderData['full_name'] ?? widget.orderData['fullName'] ?? ''),
                                  const SizedBox(height: 16),
                                  _buildLabelAndValue('CONTACT NUMBER', widget.orderData['phone'] ?? ''),
                                  const SizedBox(height: 16),
                                  _buildLabelAndValue('DELIVERY ADDRESS', widget.orderData['delivery_address'] ?? ''),
                                  const SizedBox(height: 24),
                                  _buildLabelAndValue('TIME OF DELIVERY', 'NOW'),
                                  const SizedBox(height: 16),
                                  _buildLabelAndValue('MODE OF PAYMENT', 'GCASH ONLY'),
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
                                  if (widget.orderData['items'] != null)
                                    ...(widget.orderData['items'] as List).map((item) {
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 12),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 40,
                                              height: 40,
                                              decoration: BoxDecoration(
                                                color: Colors.grey.shade200,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: const Icon(Icons.fastfood, size: 16),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    item['name']?.toString().toUpperCase() ?? '',
                                                    style: const TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                  if (item['sauces'] != null && (item['sauces'] as List).isNotEmpty)
                                                    Text(
                                                      (item['sauces'] as List).first.toString().toUpperCase(),
                                                      style: TextStyle(
                                                        fontSize: 8,
                                                        color: Colors.grey.shade600,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                Text(
                                                  'x${item['quantity'] ?? 1}',
                                                  style: const TextStyle(fontSize: 9),
                                                ),
                                                Text(
                                                  '₱${item['price'] ?? 0}',
                                                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  const SizedBox(height: 16),
                                  Divider(color: Colors.grey.shade200),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'TOTAL',
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                      ),
                                      Text(
                                        '₱${totalAmount.toString()}',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
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
                                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                          style: const TextStyle(fontSize: 12),
                                          decoration: InputDecoration(
                                            isDense: true,
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(6),
                                              borderSide: BorderSide(color: Colors.grey.shade300),
                                            ),
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            counterText: '',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 40),
                                  ElevatedButton(
                                    onPressed: _isLoading ? null : _handleConfirmPayment,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFFFC024),
                                      foregroundColor: Colors.black,
                                      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                    ),
                                    child: _isLoading
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(strokeWidth: 2),
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
