import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../auth/auth_session.dart';
import '../config.dart';

// Runtime fallback for dev mode (String.fromEnvironment defaultValue doesn't work in JIT mode)
String get _apiBaseUrl => apiBaseUrl.isEmpty ? 'http://localhost:3000' : apiBaseUrl;

class CustomerManagementPage extends StatefulWidget {
  const CustomerManagementPage({super.key});

  @override
  State<CustomerManagementPage> createState() => _CustomerManagementPageState();
}

class _CustomerManagementPageState extends State<CustomerManagementPage> {
  List<dynamic> _customers = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await http.get(
        Uri.parse('$_apiBaseUrl/api/admin/customers'),
        headers: {
          'Authorization': 'Bearer ${AuthSession.instance.token}',
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        setState(() {
          _customers = data['customers'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = data['error'] ?? 'Failed to load customers';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  void _showCustomerDetails(String customerId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CustomerDetailsPage(customerId: customerId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Management'),
        backgroundColor: const Color(0xFF1E1E1E),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCustomers,
          ),
        ],
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
                        onPressed: _loadCustomers,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _customers.isEmpty
                  ? const Center(child: Text('No customers found'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _customers.length,
                      itemBuilder: (context, index) {
                        final customer = _customers[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: customer['is_verified'] == true
                                  ? Colors.green
                                  : Colors.orange,
                              child: Icon(
                                customer['is_verified'] == true
                                    ? Icons.check
                                    : Icons.pending,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              customer['full_name'] ?? 'Unknown',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(customer['email'] ?? ''),
                                if (customer['phone'] != null)
                                  Text(customer['phone']),
                              ],
                            ),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                            onTap: () => _showCustomerDetails(customer['id']),
                          ),
                        );
                      },
                    ),
    );
  }
}

class CustomerDetailsPage extends StatefulWidget {
  final String customerId;
  const CustomerDetailsPage({super.key, required this.customerId});

  @override
  State<CustomerDetailsPage> createState() => _CustomerDetailsPageState();
}

class _CustomerDetailsPageState extends State<CustomerDetailsPage> {
  Map<String, dynamic>? _customerData;
  List<dynamic> _orders = [];
  int _loyaltyPoints = 0;
  double _totalSpent = 0;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCustomerDetails();
  }

  Future<void> _loadCustomerDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await http.get(
        Uri.parse('/api/admin/customers/${widget.customerId}'),
        headers: {
          'Authorization': 'Bearer ${AuthSession.instance.token}',
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        setState(() {
          _customerData = data['customer'];
          _orders = data['orders'] ?? [];
          _loyaltyPoints = data['loyaltyPoints'] ?? 0;
          _totalSpent = data['totalSpent']?.toDouble() ?? 0.0;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = data['error'] ?? 'Failed to load customer details';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _archiveCustomer(bool archived) async {
    try {
      final response = await http.put(
        Uri.parse('/api/admin/customers/${widget.customerId}/archive'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${AuthSession.instance.token}',
        },
        body: jsonEncode({'archived': archived}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(archived ? 'Customer archived' : 'Customer restored')),
        );
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['error'] ?? 'Failed to update customer')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Details'),
        backgroundColor: const Color(0xFF1E1E1E),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCustomerDetails,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Customer Info Card
                      Card(
                        elevation: 4,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 40,
                                    backgroundColor: _customerData?['is_verified'] == true
                                        ? Colors.green
                                        : Colors.orange,
                                    child: const Icon(Icons.person, size: 40, color: Colors.white),
                                  ),
                                  const SizedBox(width: 20),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _customerData?['full_name'] ?? 'Unknown',
                                          style: const TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _customerData?['email'] ?? '',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        if (_customerData?['phone'] != null) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            _customerData!['phone'],
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              const Divider(),
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildInfoCard(
                                      'Loyalty Points',
                                      _loyaltyPoints.toString(),
                                      Icons.star,
                                      Colors.amber,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _buildInfoCard(
                                      'Total Spent',
                                      '₱${_totalSpent.toStringAsFixed(2)}',
                                      Icons.account_balance_wallet,
                                      Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildInfoCard(
                                      'Orders',
                                      _orders.length.toString(),
                                      Icons.shopping_bag,
                                      Colors.blue,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _buildInfoCard(
                                      'Status',
                                      _customerData?['is_verified'] == true
                                          ? 'Verified'
                                          : 'Pending',
                                      _customerData?['is_verified'] == true
                                          ? Icons.verified
                                          : Icons.pending,
                                      _customerData?['is_verified'] == true
                                          ? Colors.green
                                          : Colors.orange,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Orders Section
                      const Text(
                        'Order History',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      if (_orders.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: Center(child: Text('No orders yet')),
                          ),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _orders.length,
                          itemBuilder: (context, index) {
                            final order = _orders[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                title: Text('Order #${order['id'].toString().substring(0, 8)}'),
                                subtitle: Text(
                                  'Status: ${order['status']}\n${_formatDate(order['created_at'])}',
                                ),
                                trailing: Text(
                                  '₱${order['total_amount'].toString()}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                isThreeLine: true,
                              ),
                            );
                          },
                        ),
                      const SizedBox(height: 24),

                      // Archive Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Archive Customer?'),
                                content: const Text(
                                  'Are you sure you want to archive this customer? They will no longer be able to log in.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                      _archiveCustomer(true);
                                    },
                                    child: const Text('Archive', style: TextStyle(color: Colors.red)),
                                  ),
                                ],
                              ),
                            );
                          },
                          icon: const Icon(Icons.archive),
                          label: const Text('Archive Customer'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade100,
                            foregroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildInfoCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return '';
    }
  }
}
