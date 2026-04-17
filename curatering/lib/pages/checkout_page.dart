import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/cart_store.dart';
import '../config.dart';
import 'customer_login.dart';
import 'payment_page.dart';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();
  
  double? _deliveryLat;
  double? _deliveryLng;
  bool _isLoading = false;
  Map<String, dynamic>? _customerData;

  @override
  void initState() {
    super.initState();
    _loadCustomerData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomerData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final customerData = prefs.getString('customer_data');
      if (customerData != null) {
        setState(() {
          _customerData = jsonDecode(customerData);
          // Initialize controllers with customer data
          _nameController.text = _customerData?['fullName'] ?? '';
          _phoneController.text = _customerData?['phone'] ?? '';
        });
      }
    } catch (e) {
      debugPrint('Error loading customer data: $e');
    }
  }

  Future<void> _handlePlaceOrder() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name')),
      );
      return;
    }

    if (_phoneController.text.isEmpty || _phoneController.text.length != 11 || !RegExp(r'^\d{11}$').hasMatch(_phoneController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 11-digit contact number')),
      );
      return;
    }

    if (_addressController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a delivery address')),
      );
      return;
    }

    if (_customerData == null) {
      final result = await Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const CustomerLoginPage()),
      );
      if (result != null) {
        await _loadCustomerData();
      } else {
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('customer_token');
      
      final items = CartStore.instance.items.map((item) => {
        'dishId': item.dish.id,
        'name': item.dish.name,
        'price': item.dish.price,
        'quantity': item.quantity,
      }).toList();

      final response = await http.post(
        Uri.parse('$apiBaseUrl/api/restaurant/orders'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'items': items,
          'fullName': _nameController.text,
          'phone': _phoneController.text,
          'deliveryAddress': _addressController.text,
          'deliveryLat': _deliveryLat,
          'deliveryLng': _deliveryLng,
          'deliveryNotes': _notesController.text.trim(),
          'totalAmount': CartStore.instance.totalAmount,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        CartStore.instance.clearCart();
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => PaymentPage(orderData: data['order']),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['error'] ?? 'Failed to place order')),
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
    final cartItems = CartStore.instance.items;
    final totalAmount = CartStore.instance.totalAmount;

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
                // Checkout title
                Center(
                  child: Text(
                    'Checkout',
                    style: GoogleFonts.dancingScript(
                      fontSize: 42,
                      color: Colors.red.shade400,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Continue ordering button
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.amber.shade400),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('< CONTINUE ORDERING'),
                ),
                const SizedBox(height: 32),
                // Three columns layout
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // YOUR TRAY
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
                                'YOUR TRAY',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                            Divider(color: Colors.grey.shade200, height: 1),
                            Container(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: cartItems.map((item) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: Row(
                                      children: [
                                        if (item.dish.imageBase64 != null)
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(4),
                                            child: Image.memory(
                                              base64Decode(item.dish.imageBase64!),
                                              width: 50,
                                              height: 50,
                                              fit: BoxFit.cover,
                                            ),
                                          )
                                        else
                                          Container(
                                            width: 50,
                                            height: 50,
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade200,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Icon(Icons.fastfood, size: 20),
                                          ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item.dish.name.toUpperCase(),
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              if (item.dish.sauces.isNotEmpty)
                                                Text(
                                                  item.dish.sauces.first.toUpperCase(),
                                                  style: TextStyle(
                                                    fontSize: 9,
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
                                              'x${item.quantity}',
                                              style: const TextStyle(fontSize: 10),
                                            ),
                                            Text(
                                              '₱${(double.tryParse(item.dish.price) ?? 0) * item.quantity}',
                                              style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Divider(color: Colors.grey.shade200, height: 1),
                            Container(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'TOTAL',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                  Text(
                                    '₱${totalAmount.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 12,
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
                    // DELIVERY INFORMATION
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
                                  // Name
                                  _buildLabelAndField('NAME', '', controller: _nameController),
                                  const SizedBox(height: 16),
                                  // Contact Number
                                  _buildLabelAndField(
                                    'CONTACT NUMBER',
                                    '',
                                    controller: _phoneController,
                                    keyboardType: TextInputType.number,
                                    maxLength: 11,
                                    digitsOnly: true,
                                  ),
                                  const SizedBox(height: 16),
                                  // Delivery Address
                                  _buildLabelAndField('DELIVERY ADDRESS', '', controller: _addressController, maxLines: 3),
                                  const SizedBox(height: 24),
                                  // Time of delivery
                                  _buildLabelAndDropdown('TIME OF DELIVERY', 'NOW', ['NOW', 'LATER']),
                                  const SizedBox(height: 16),
                                  // Mode of payment
                                  _buildLabelAndDropdown('MODE OF PAYMENT', 'GCASH ONLY', ['GCASH ONLY']),
                                  const SizedBox(height: 32),
                                  // Proceed button
                                  Center(
                                    child: ElevatedButton(
                                      onPressed: _isLoading ? null : _handlePlaceOrder,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFFFC024),
                                        foregroundColor: Colors.black,
                                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
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
                                              'PROCEED TO PAYMENT',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
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

  Widget _buildLabelAndField(
    String label,
    String value, {
    TextEditingController? controller,
    int maxLines = 1,
    TextInputType? keyboardType,
    int? maxLength,
    bool digitsOnly = false,
  }) {
    return Row(
      crossAxisAlignment: maxLines > 1 ? CrossAxisAlignment.start : CrossAxisAlignment.center,
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
          child: controller != null
              ? TextField(
                  controller: controller,
                  maxLines: maxLines,
                  keyboardType: keyboardType,
                  maxLength: maxLength,
                  inputFormatters: digitsOnly
                      ? [FilteringTextInputFormatter.digitsOnly]
                      : null,
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
                )
              : Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    value.isEmpty ? '' : value,
                    style: TextStyle(
                      fontSize: 12,
                      color: value.isEmpty ? Colors.grey.shade400 : Colors.black,
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildLabelAndDropdown(String label, String value, List<String> options) {
    return Row(
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: const TextStyle(fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
