import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';

class OrderTrackingPage extends StatefulWidget {
  final Map<String, dynamic> orderData;
  const OrderTrackingPage({super.key, required this.orderData});

  @override
  State<OrderTrackingPage> createState() => _OrderTrackingPageState();
}

class _OrderTrackingPageState extends State<OrderTrackingPage> {
  final _trackingUrlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.orderData['delivery_tracking_url'] != null) {
      _trackingUrlController.text = widget.orderData['delivery_tracking_url'];
    }
  }

  @override
  void dispose() {
    _trackingUrlController.dispose();
    super.dispose();
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'Order Placed';
      case 'confirmed':
        return 'Order Confirmed';
      case 'preparing':
        return 'Preparing';
      case 'out_for_delivery':
        return 'Out for Delivery';
      case 'delivered':
        return 'Delivered';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  String _getPaymentStatusText(String paymentStatus) {
    switch (paymentStatus) {
      case 'pending':
        return 'Payment Pending';
      case 'paid':
        return 'Payment Confirmed';
      case 'failed':
        return 'Payment Failed';
      default:
        return 'Payment Pending';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'preparing':
        return Colors.purple;
      case 'out_for_delivery':
        return Colors.teal;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<void> _openTrackingUrl() async {
    final url = _trackingUrlController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a tracking URL')),
      );
      return;
    }

    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not launch URL')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.orderData['status'] ?? 'pending';
    final items = widget.orderData['items'] as List<dynamic>? ?? [];
    final totalAmount = widget.orderData['total_amount'] ?? '0.00';
    final orderId = widget.orderData['id']?.toString() ?? '000000';
    final shortOrderId = orderId.length > 6 ? orderId.substring(orderId.length - 6) : orderId;
    final fullName = widget.orderData['full_name'] ?? '';
    final phone = widget.orderData['phone'] ?? '';
    final deliveryAddress = widget.orderData['delivery_address'] ?? 'N/A';
    final paymentReference = widget.orderData['payment_reference'] ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Track Order'),
        backgroundColor: const Color(0xFF1E1E1E),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              children: [
                // Payment Title
                Text(
                  'Payment',
                  style: GoogleFonts.dancingScript(
                    fontSize: 36,
                    color: Colors.red.shade400,
                  ),
                ),
                const SizedBox(height: 24),

                // Order Number Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFFFC024), width: 1.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'ORDER NO. $shortOrderId',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Three Column Layout
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isDesktop = constraints.maxWidth > 900;
                    
                    if (isDesktop) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left Column - Delivery Information
                          Expanded(
                            flex: 3,
                            child: _buildDeliveryInfoColumn(
                              fullName: fullName,
                              phone: phone,
                              deliveryAddress: deliveryAddress,
                              items: items,
                              totalAmount: totalAmount,
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Middle Column - Payment Confirmed
                          Expanded(
                            flex: 3,
                            child: _buildPaymentConfirmedColumn(
                              paymentReference: paymentReference,
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Right Column - Order Status
                          Expanded(
                            flex: 3,
                            child: _buildOrderStatusColumn(status),
                          ),
                        ],
                      );
                    } else {
                      return Column(
                        children: [
                          _buildDeliveryInfoColumn(
                            fullName: fullName,
                            phone: phone,
                            deliveryAddress: deliveryAddress,
                            items: items,
                            totalAmount: totalAmount,
                          ),
                          const SizedBox(height: 16),
                          _buildPaymentConfirmedColumn(
                            paymentReference: paymentReference,
                          ),
                          const SizedBox(height: 16),
                          _buildOrderStatusColumn(status),
                        ],
                      );
                    }
                  },
                ),
                const SizedBox(height: 32),

                // Back to Home Button
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E1E1E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Back to Home',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeliveryInfoColumn({
    required String fullName,
    required String phone,
    required String deliveryAddress,
    required List<dynamic> items,
    required String totalAmount,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // DELIVERY INFORMATION Title
          Center(
            child: Text(
              'DELIVERY INFORMATION',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Name
          _buildInfoRow('NAME', fullName),
          const SizedBox(height: 12),

          // Contact Number
          _buildInfoRow('CONTACT NUMBER', phone),
          const SizedBox(height: 12),

          // Delivery Address
          _buildInfoRow('DELIVERY ADDRESS', deliveryAddress, maxLines: 2),
          const SizedBox(height: 12),

          // Time of Delivery
          _buildInfoRow('TIME OF DELIVERY', 'NOW'),
          const SizedBox(height: 12),

          // Mode of Payment
          _buildInfoRow('MODE OF PAYMENT', 'GCASH ONLY'),
          const SizedBox(height: 24),

          const Divider(),
          const SizedBox(height: 16),

          // YOUR ORDER Title
          Center(
            child: Text(
              'YOUR ORDER',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Order Items
          ...items.map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Item image placeholder
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(Icons.fastfood, size: 20, color: Colors.grey),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (item['name'] ?? 'Unknown Item').toUpperCase(),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (item['description'] != null)
                          Text(
                            item['description'],
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
                        'x${item['quantity'] ?? 1}',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        '₱${item['price'] ?? '0.00'}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),

          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),

          // Total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'TOTAL',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '₱$totalAmount',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {int maxLines = 1}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: Colors.grey.shade600,
            ),
          ),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              value.isEmpty ? '' : value,
              style: TextStyle(
                fontSize: 10,
                color: value.isEmpty ? Colors.grey.shade400 : Colors.black,
              ),
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentConfirmedColumn({required String paymentReference}) {
    final paymentStatus = widget.orderData['payment_status'] ?? 'pending';
    final isPaymentConfirmed = paymentStatus == 'paid';
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 20),

          // PAYMENT STATUS
          Text(
            isPaymentConfirmed ? 'PAYMENT CONFIRMED!' : 'PAYMENT PENDING',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isPaymentConfirmed ? Colors.green.shade600 : Colors.orange.shade600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 24),

          // Message
          Text(
            isPaymentConfirmed 
                ? 'PLEASE WAIT FOR YOUR ORDER CONFIRMATION VIA TEXT.'
                : 'AWAITING PAYMENT CONFIRMATION FROM MANAGER.',
            style: TextStyle(
              fontSize: 9,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // REF NO
          Row(
            children: [
              SizedBox(
                width: 60,
                child: Text(
                  'REF NO.',
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    paymentReference.isEmpty ? '' : paymentReference,
                    style: TextStyle(
                      fontSize: 10,
                      color: paymentReference.isEmpty ? Colors.grey.shade400 : Colors.black,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),

          // Thank you message
          Text(
            'THANK YOU FOR CHOOSING\nMACRINA\'S KITCHEN AND CATERING!',
            style: TextStyle(
              fontSize: 9,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildOrderStatusColumn(String status) {
    final statuses = [
      {'label': 'WAITING FOR ORDER CONFIRMATION', 'value': 'pending'},
      {'label': 'ORDER CONFIRMED', 'value': 'confirmed'},
      {'label': 'PREPARING YOUR FOOD', 'value': 'preparing'},
      {'label': 'LOOKING FOR A RIDER', 'value': 'out_for_delivery'},
      {'label': 'RIDER IS ON THE WAY', 'value': 'delivered'},
    ];

    final currentStatus = status.toLowerCase();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ORDER STATUS Title
          Text(
            'ORDER STATUS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 20),

          // Status Buttons
          ...statuses.map((s) {
            final isActive = currentStatus == s['value'];
            final isCompleted = _isStatusCompleted(currentStatus, s['value']!);

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                decoration: BoxDecoration(
                  color: isActive ? const Color(0xFFFFC024) : Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isActive ? const Color(0xFFFFC024) : Colors.grey.shade300,
                  ),
                ),
                child: Text(
                  s['label']!,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: isActive || isCompleted ? FontWeight.w600 : FontWeight.normal,
                    color: isActive || isCompleted ? Colors.black : Colors.grey.shade500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }).toList(),

          const SizedBox(height: 8),

          // Tracking Link Placeholder
          Text(
            '(INSERT TRACKING LINK HERE)',
            style: TextStyle(
              fontSize: 8,
              color: Colors.grey.shade400,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  bool _isStatusCompleted(String currentStatus, String checkStatus) {
    final statusOrder = ['pending', 'confirmed', 'preparing', 'out_for_delivery', 'delivered'];
    final currentIndex = statusOrder.indexOf(currentStatus);
    final checkIndex = statusOrder.indexOf(checkStatus);
    return checkIndex < currentIndex;
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusProgress(String status) {
    final statuses = ['pending', 'confirmed', 'preparing', 'out_for_delivery', 'delivered'];
    final currentIndex = statuses.indexOf(status);
    
    return Column(
      children: [
        Row(
          children: List.generate(statuses.length, (index) {
            final isActive = index <= currentIndex;
            return Expanded(
              child: Container(
                height: 4,
                color: isActive ? _getStatusColor(status) : Colors.grey.shade300,
                margin: EdgeInsets.only(right: index < statuses.length - 1 ? 4 : 0),
              ),
            );
          }),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildStatusLabel('Placed', currentIndex >= 0),
            _buildStatusLabel('Paid', currentIndex >= 1),
            _buildStatusLabel('Preparing', currentIndex >= 2),
            _buildStatusLabel('On Way', currentIndex >= 3),
            _buildStatusLabel('Delivered', currentIndex >= 4),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusLabel(String label, bool isActive) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 10,
        color: isActive ? Colors.black : Colors.grey.shade400,
        fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }
}
