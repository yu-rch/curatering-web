import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/website_header_font.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../services/cart_store.dart';
import '../services/customer_orders_cache.dart';
import '../services/loyalty_rewards_store.dart';
import '../config.dart';
import '../utils/order_display_utils.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../widgets/map_picker.dart';
import 'payment_page.dart';
import '../utils/responsive_layout.dart';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _guestEmailController = TextEditingController();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();

  double? _deliveryLat;
  double? _deliveryLng;
  bool _isLoading = false;
  bool _saveAddress = false;
  bool _showValidation = false;
  Map<String, dynamic>? _customerData;
  int _currentPoints = 0; // User's current points - in production from API

  // Delivery time selection
  // - ASAP (internal 'NOW'): send no delivery_time
  // - LATER: send a concrete timestamp (resolved to today/tomorrow)
  String _deliveryTimeMode = 'NOW';
  TimeOfDay _selectedDeliveryTime = TimeOfDay.now();

  @override
  void initState() {
    super.initState();
    _loadCustomerData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _guestEmailController.dispose();
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

      // Load saved address from profile
      await _loadSavedAddress();
    } catch (e) {
      debugPrint('Error loading customer data: $e');
    }
  }

  double? _parseCoord(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.trim());
    return null;
  }

  Future<void> _loadSavedAddress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('customer_token');

      if (token == null || token.isEmpty) return;

      final response = await http.get(
        Uri.parse('${apiBaseUrl}/api/customer/profile'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['deliveryAddress'] != null &&
            data['deliveryAddress'].isNotEmpty) {
          setState(() {
            _addressController.text = data['deliveryAddress'];
            _deliveryLat =
                _parseCoord(data['deliveryLat']) ??
                _parseCoord(data['delivery_lat']);
            _deliveryLng =
                _parseCoord(data['deliveryLng']) ??
                _parseCoord(data['delivery_lng']);
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading saved address: $e');
    }
  }

  Future<void> _saveAddressToProfile() async {
    if (!_saveAddress) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('customer_token');

      if (token == null || token.isEmpty) return;

      await http.put(
        Uri.parse('${apiBaseUrl}/api/customer/profile'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'deliveryAddress': _addressController.text,
          'deliveryLat': _deliveryLat,
          'deliveryLng': _deliveryLng,
        }),
      );
    } catch (e) {
      debugPrint('Error saving address: $e');
    }
  }

  Future<void> _showMapPicker() async {
    final result = await showMapPicker(
      context: context,
      initialLatitude: _deliveryLat,
      initialLongitude: _deliveryLng,
      initialAddress:
          _addressController.text.isNotEmpty ? _addressController.text : null,
    );

    if (result != null) {
      setState(() {
        _addressController.text = result.address;
        _deliveryLat = result.latitude;
        _deliveryLng = result.longitude;
      });
    }
  }

  Future<void> _handlePlaceOrder() async {
    setState(() => _showValidation = true);
    // Prevent checkout when the cart is empty (even if user navigates here directly).
    if (CartStore.instance.items.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Your cart is empty')));
      }
      return;
    }

    if (!_isCheckoutValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fix the highlighted fields')),
      );
      return;
    }

    final isGuest = _customerData == null;
    final phoneDigits = _phoneController.text.replaceAll(RegExp(r'\D'), '');

    if (_deliveryLat == null || _deliveryLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please pin your delivery location on the map.'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('customer_token');

      final items =
          CartStore.instance.items
              .map(
                (item) => {
                  'dishId': item.dish.id,
                  'name': item.dish.name,
                  'price': item.dish.price,
                  'quantity': item.quantity,
                },
              )
              .toList();

      final orderData = <String, dynamic>{
        'tray_items': items,
        'items': items,
        'fullName': _nameController.text,
        'contactNumber': phoneDigits,
        'deliveryAddress': _addressController.text,
        'deliveryLat': _deliveryLat,
        'deliveryLng': _deliveryLng,
        'deliveryNotes': _notesController.text.trim(),
        'deliveryTime':
            _deliveryTimeMode == 'NOW'
                ? 'NOW'
                : _resolveDeliveryTime()?.toIso8601String(),
        'totalCost': CartStore.instance.totalAmount,
        'orderSource': 'WEB_APP',
      };
      if (isGuest) {
        orderData['userEmail'] = _guestEmailController.text.trim();
      }

      final headers = <String, String>{'Content-Type': 'application/json'};
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http.post(
        Uri.parse('${apiBaseUrl}/api/restaurant/orders'),
        headers: headers,
        body: jsonEncode(orderData),
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

      if (response.statusCode == 201) {
        final rawOrder = data['order'];
        if (rawOrder is! Map) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Order created but response was invalid. Contact support.',
                ),
              ),
            );
          }
          return;
        }
        final orderMap = Map<String, dynamic>.from(rawOrder);
        final orderNo = formatRestaurantOrderNo(orderMap);
        CartStore.instance.clearCart();
        CustomerOrdersCache.instance.invalidateRestaurant();
        // Save address to profile if checkbox is checked
        await _saveAddressToProfile();
        if (mounted) {
          if (orderNo != 'N/A') {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Order $orderNo created. Complete payment to confirm.',
                ),
              ),
            );
          }
          Navigator.of(context, rootNavigator: true).pushReplacement(
            MaterialPageRoute(
              builder: (context) => PaymentPage(orderData: orderMap),
            ),
          );
        }
      } else if (response.statusCode == 401) {
        // Token expired or invalid - clear and redirect to login
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('customer_token');
        await prefs.remove('customer_data');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Session expired. Please log in again.'),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['error'] ?? 'Failed to create order')),
        );
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

  bool get _isCheckoutValid {
    return _nameError == null &&
        _phoneError == null &&
        (_customerData != null || _guestEmailError == null) &&
        _addressError == null &&
        _deliveryPinError == null;
  }

  String? get _nameError {
    final value = _nameController.text.trim();
    if (value.isEmpty) return 'Name is required';
    if (value.length < 2) return 'Enter at least 2 characters';
    return null;
  }

  String? get _phoneError {
    final digits = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return 'Contact number is required';
    if (digits.length != 11 || !digits.startsWith('09')) {
      return 'Use an 11-digit PH mobile number, e.g. 09123456789';
    }
    return null;
  }

  String? get _guestEmailError {
    final value = _guestEmailController.text.trim();
    if (value.isEmpty) return 'Email is required for guest checkout';
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
    return ok ? null : 'Enter a valid email address';
  }

  String? get _addressError {
    return _addressController.text.trim().isEmpty
        ? 'Delivery address is required'
        : null;
  }

  String? get _deliveryPinError {
    if (_deliveryLat == null || _deliveryLng == null) {
      return 'Pin your delivery location on the map';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final cartItems = CartStore.instance.items;
    final totalAmount = CartStore.instance.totalAmount;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SingleChildScrollView(
        padding: appPagePadding(context),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: appContentMaxWidth(context)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Checkout title
                Center(
                  child: Text(
                    'Checkout',
                    style: websiteHeaderStyle(
                      fontSize: 42,
                      color: Colors.red.shade400,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Continue ordering button
                OutlinedButton(
                  onPressed:
                      () => Navigator.of(context, rootNavigator: true).pop(),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.amber.shade400),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
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
                                children:
                                    cartItems.map((item) {
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 16,
                                        ),
                                        child: Row(
                                          children: [
                                            if (item.dish.imageBase64 != null)
                                              ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                                child: Image.memory(
                                                  base64Decode(
                                                    item.dish.imageBase64!,
                                                  ),
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
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: const Icon(
                                                  Icons.fastfood,
                                                  size: 20,
                                                ),
                                              ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    item.dish.name
                                                        .toUpperCase(),
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                  if (item.selectedSauce !=
                                                      null)
                                                    Text(
                                                      item.selectedSauce!
                                                          .toUpperCase(),
                                                      style: TextStyle(
                                                        fontSize: 9,
                                                        color:
                                                            Colors
                                                                .grey
                                                                .shade600,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                            // Quantity Controls (+ amount -)
                                            Row(
                                              children: [
                                                IconButton(
                                                  onPressed: () {
                                                    if (item.quantity > 1) {
                                                      setState(() {
                                                        CartStore.instance
                                                            .updateQuantity(
                                                              item.dish.id,
                                                              item.quantity - 1,
                                                            );
                                                      });
                                                    } else {
                                                      // Remove item if quantity becomes 0
                                                      setState(() {
                                                        CartStore.instance
                                                            .removeItem(
                                                              item.dish.id,
                                                            );
                                                      });
                                                    }
                                                  },
                                                  icon: Icon(
                                                    Icons.remove_circle_outline,
                                                    size: 20,
                                                    color: Colors.red.shade400,
                                                  ),
                                                  padding: EdgeInsets.zero,
                                                  constraints:
                                                      const BoxConstraints(),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  '${item.quantity}',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                IconButton(
                                                  onPressed: () {
                                                    setState(() {
                                                      CartStore.instance
                                                          .updateQuantity(
                                                            item.dish.id,
                                                            item.quantity + 1,
                                                          );
                                                    });
                                                  },
                                                  icon: Icon(
                                                    Icons.add_circle_outline,
                                                    size: 20,
                                                    color:
                                                        Colors.green.shade400,
                                                  ),
                                                  padding: EdgeInsets.zero,
                                                  constraints:
                                                      const BoxConstraints(),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(width: 12),
                                            Text(
                                              '₱${((double.tryParse(item.dish.price) ?? 0) * item.quantity).toStringAsFixed(0)}',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                              ),
                            ),
                            // Redeem/Loyalty Banner
                            _buildRedeemBanner(),
                            const SizedBox(height: 16),
                            Divider(color: Colors.grey.shade200, height: 1),
                            Container(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'TOTAL',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
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
                                  _buildLabelAndField(
                                    'NAME',
                                    '',
                                    controller: _nameController,
                                    errorText:
                                        _showValidation ? _nameError : null,
                                  ),
                                  const SizedBox(height: 16),
                                  // Contact Number
                                  _buildLabelAndField(
                                    'CONTACT NUMBER',
                                    '',
                                    controller: _phoneController,
                                    keyboardType: TextInputType.number,
                                    maxLength: 11,
                                    digitsOnly: true,
                                    hintText: '09123456789',
                                    errorText:
                                        _showValidation ? _phoneError : null,
                                  ),
                                  if (_customerData == null) ...[
                                    const SizedBox(height: 16),
                                    _buildLabelAndField(
                                      'EMAIL ADDRESS',
                                      'Required for order updates',
                                      controller: _guestEmailController,
                                      keyboardType: TextInputType.emailAddress,
                                      errorText:
                                          _showValidation
                                              ? _guestEmailError
                                              : null,
                                    ),
                                  ],
                                  const SizedBox(height: 16),
                                  // Delivery Address with Map Picker
                                  _buildAddressFieldWithMap(),
                                  const SizedBox(height: 16),
                                  _buildLabelAndField(
                                    'DELIVERY NOTES (OPTIONAL)',
                                    '',
                                    controller: _notesController,
                                    maxLines: 3,
                                  ),
                                  const SizedBox(height: 8),
                                  // Save Address Checkbox
                                  Row(
                                    children: [
                                      Checkbox(
                                        value: _saveAddress,
                                        onChanged: (value) {
                                          setState(() {
                                            _saveAddress = value ?? false;
                                          });
                                        },
                                        activeColor: const Color(0xFFF4511E),
                                      ),
                                      const Text(
                                        'Save this address to my profile',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  // Time of delivery (ASAP / LATER)
                                  _buildDeliveryTimePicker(),
                                  const SizedBox(height: 16),
                                  // Mode of payment
                                  _buildLabelAndDropdown(
                                    'MODE OF PAYMENT',
                                    'GCASH ONLY',
                                    ['GCASH ONLY'],
                                  ),
                                  const SizedBox(height: 32),
                                  // Proceed button
                                  Center(
                                    child: ElevatedButton(
                                      onPressed:
                                          (_isLoading || cartItems.isEmpty)
                                              ? null
                                              : _handlePlaceOrder,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFFFFC024,
                                        ),
                                        foregroundColor: Colors.black,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 32,
                                          vertical: 12,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                      ),
                                      child:
                                          _isLoading
                                              ? const SizedBox(
                                                width: 20,
                                                height: 20,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
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

  Widget _buildAddressFieldWithMap() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 100,
              child: Text(
                'DELIVERY ADDRESS',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(
              child: TextField(
                controller: _addressController,
                maxLines: 3,
                style: const TextStyle(fontSize: 12),
                onChanged: (_) {
                  if (_showValidation) setState(() {});
                },
                decoration: InputDecoration(
                  isDense: true,
                  errorText:
                      _showValidation
                          ? (_addressError ?? _deliveryPinError)
                          : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.map, size: 20),
                    onPressed: _showMapPicker,
                    tooltip: 'Pick from map',
                  ),
                ),
              ),
            ),
          ],
        ),
        if (_deliveryLat != null && _deliveryLng != null) ...[
          const SizedBox(height: 12),
          _buildCheckoutMapEmbed(),
        ] else ...[
          const SizedBox(height: 8),
          Text(
            'Use the map icon to drop a pin so we can find your location.',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ],
      ],
    );
  }

  Widget _buildCheckoutMapEmbed() {
    final lat = _deliveryLat!;
    final lng = _deliveryLng!;
    final pos = LatLng(lat, lng);
    final addressPreview = _addressController.text.trim();
    return Material(
      elevation: 1,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _showMapPicker,
        child: SizedBox(
          height: 180,
          width: double.infinity,
          child: Stack(
            children: [
              FlutterMap(
                key: ValueKey('checkout_map_${lat}_$lng'),
                options: MapOptions(
                  initialCenter: pos,
                  initialZoom: 17,
                  onTap: (_, __) => _showMapPicker(),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.curatering.web',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: pos,
                        width: 36,
                        height: 36,
                        child: const Icon(
                          Icons.location_pin,
                          color: Colors.red,
                          size: 36,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (addressPreview.isNotEmpty)
                Positioned(
                  left: 8,
                  right: 8,
                  top: 8,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      child: Text(
                        addressPreview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned(
                right: 8,
                bottom: 8,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text(
                      'Tap map to adjust pin',
                      style: TextStyle(fontSize: 10),
                    ),
                  ),
                ),
              ),
            ],
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
    String? hintText,
    String? errorText,
  }) {
    return Row(
      crossAxisAlignment:
          maxLines > 1 ? CrossAxisAlignment.start : CrossAxisAlignment.center,
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
          child:
              controller != null
                  ? TextField(
                    controller: controller,
                    maxLines: maxLines,
                    keyboardType: keyboardType,
                    maxLength: maxLength,
                    inputFormatters:
                        digitsOnly
                            ? [
                              FilteringTextInputFormatter.digitsOnly,
                              if (maxLength != null)
                                LengthLimitingTextInputFormatter(maxLength),
                            ]
                            : null,
                    style: const TextStyle(fontSize: 12),
                    onChanged: (_) {
                      if (_showValidation) setState(() {});
                    },
                    decoration: InputDecoration(
                      isDense: true,
                      errorText: errorText,
                      hintText: hintText,
                      hintStyle: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade400,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      counterText: '',
                    ),
                  )
                  : Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      value.isEmpty ? '' : value,
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            value.isEmpty ? Colors.grey.shade400 : Colors.black,
                      ),
                    ),
                  ),
        ),
      ],
    );
  }

  Widget _buildLabelAndDropdown(
    String label,
    String value,
    List<String> options,
  ) {
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
              children: [Text(value, style: const TextStyle(fontSize: 11))],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickDeliveryTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedDeliveryTime,
      helpText: 'Select delivery time',
    );
    if (picked == null) return;
    setState(() => _selectedDeliveryTime = picked);
  }

  String _formatTimeOfDay(TimeOfDay t) {
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  DateTime? _resolveDeliveryTime() {
    if (_deliveryTimeMode != 'LATER') return null;

    final now = DateTime.now();
    final candidate = DateTime(
      now.year,
      now.month,
      now.day,
      _selectedDeliveryTime.hour,
      _selectedDeliveryTime.minute,
    );

    // If user picks a time earlier than "now", schedule for tomorrow.
    return candidate.isBefore(now)
        ? candidate.add(const Duration(days: 1))
        : candidate;
  }

  Widget _buildDeliveryTimePicker() {
    final isNow = _deliveryTimeMode == 'NOW';
    final isLater = _deliveryTimeMode == 'LATER';

    return Row(
      children: [
        const SizedBox(
          width: 100,
          child: Text(
            'TIME OF DELIVERY',
            style: TextStyle(
              fontSize: 10,
              color: Colors.black54,
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ToggleButtons(
                  borderRadius: BorderRadius.circular(6),
                  constraints: const BoxConstraints(minHeight: 36),
                  isSelected: [isNow, isLater],
                  onPressed: (index) async {
                    if (index == 0) {
                      setState(() => _deliveryTimeMode = 'NOW');
                      return;
                    }

                    setState(() => _deliveryTimeMode = 'LATER');
                    await _pickDeliveryTime();
                  },
                  children: const [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('ASAP'),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('LATER'),
                    ),
                  ],
                ),
                if (isLater) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.access_time_rounded, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Scheduled: ${_formatTimeOfDay(_selectedDeliveryTime)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _pickDeliveryTime,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Change'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Redeem/Loyalty Banner - shows points and rewards
  Widget _buildRedeemBanner() {
    // Get values from store (with defaults)
    final double minimumOrderForPoints = LoyaltyRewardsStore.instance
        .minimumOrderForPoints(orderType: 'restaurant');
    final int pointsEarned = LoyaltyRewardsStore.instance.pointsEarned(
      orderType: 'restaurant',
    );
    // Ensure store is loaded
    LoyaltyRewardsStore.instance.ensureLoaded();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.shade400, Colors.red.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.stars, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Loyalty Rewards',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'You have $_currentPoints points',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$pointsEarned pts',
                    style: TextStyle(
                      color: Colors.red.shade400,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Progress bar for next reward
          Container(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Spend ₱$minimumOrderForPoints to earn $pointsEarned points',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value:
                        CartStore.instance.totalAmount / minimumOrderForPoints,
                    backgroundColor: Colors.white.withOpacity(0.3),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.white,
                    ),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
          // Redeem Button
          Container(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showRewardDialog(_currentPoints),
              icon: const Icon(Icons.redeem, color: Colors.orange, size: 18),
              label: const Text(
                'Redeem Rewards',
                style: TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.orange,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showRewardDialog(int currentPoints) {
    // Get rewards from store
    final availableRewards = LoyaltyRewardsStore.instance.rewardsConditions;

    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Close button
                  Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
                      onPressed:
                          () =>
                              Navigator.of(context, rootNavigator: true).pop(),
                      icon: const Icon(Icons.close, color: Colors.black),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Title
                  const Row(
                    children: [
                      Icon(Icons.card_giftcard, color: Colors.orange),
                      SizedBox(width: 8),
                      Text(
                        'REDEEM REWARDS',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Your Points: $currentPoints',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...availableRewards.map((reward) {
                    final canRedeem = currentPoints >= reward.minimumPoints;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              canRedeem ? Colors.green : Colors.grey.shade300,
                          child: Icon(
                            canRedeem ? Icons.check : Icons.lock,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        title: Text(reward.reward),
                        subtitle: Text(reward.description),
                        trailing: Chip(
                          label: Text('${reward.minimumPoints} pts'),
                          backgroundColor:
                              canRedeem
                                  ? Colors.green.shade100
                                  : Colors.grey.shade200,
                          labelStyle: TextStyle(
                            color:
                                canRedeem
                                    ? Colors.green.shade800
                                    : Colors.grey.shade600,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        onTap:
                            canRedeem
                                ? () {
                                  Navigator.of(
                                    context,
                                    rootNavigator: true,
                                  ).pop();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        '${reward.reward} redeemed successfully!',
                                      ),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                                : null,
                      ),
                    );
                  }).toList(),
                  const SizedBox(height: 24),
                  // Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed:
                          () =>
                              Navigator.of(context, rootNavigator: true).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFC024),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'CLOSE',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }
}
