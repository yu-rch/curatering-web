import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../auth/auth_session.dart';
import '../auth/roles.dart';
import '../config.dart';
import '../widgets/app_scaffold.dart';

String get _apiBaseUrl => apiBaseUrl;

class CustomerManagementPage extends StatefulWidget {
  const CustomerManagementPage({super.key});

  @override
  State<CustomerManagementPage> createState() => _CustomerManagementPageState();
}

class _CustomerManagementPageState extends State<CustomerManagementPage> {
  List<dynamic> _customers = [];
  bool _isLoading = true;
  String? _error;
  bool _includeArchived = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _statusFilter = 'all'; // all | verified | pending | archived

  bool get _isSuperAdmin =>
      AuthSession.instance.currentRole == Role.superAdmin;

  List<dynamic> get _filteredCustomers {
    final q = _searchQuery.trim().toLowerCase();
    return _customers.where((customer) {
      final isArchived = customer['archived'] == true;
      final isVerified = customer['is_verified'] == true;
      switch (_statusFilter) {
        case 'verified':
          if (isArchived || !isVerified) return false;
          break;
        case 'pending':
          if (isArchived || isVerified) return false;
          break;
        case 'archived':
          if (!isArchived) return false;
          break;
        case 'all':
        default:
          break;
      }
      if (q.isEmpty) return true;
      final name = '${customer['full_name'] ?? ''}'.toLowerCase();
      final email = '${customer['email'] ?? ''}'.toLowerCase();
      final phone = '${customer['phone'] ?? ''}'.toLowerCase();
      return name.contains(q) || email.contains(q) || phone.contains(q);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final uri = Uri.parse('$_apiBaseUrl/api/admin/customers').replace(
        queryParameters:
            _includeArchived ? {'includeArchived': 'true'} : null,
      );
      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer ${AuthSession.instance.token}'},
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

  Future<void> _archiveCustomer(String customerId, {required bool archived}) async {
    try {
      final response = await http.put(
        Uri.parse('$_apiBaseUrl/api/admin/customers/$customerId/archive'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${AuthSession.instance.token}',
        },
        body: jsonEncode({'archived': archived}),
      );
      final data = jsonDecode(response.body);
      if (!mounted) return;
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(archived ? 'Customer archived' : 'Customer restored'),
          ),
        );
        await _loadCustomers();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['error'] ?? 'Failed to update customer')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _confirmArchiveFromList(
    String customerId,
    String name,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Archive customer'),
        content: Text(
          'Archive $name? They will no longer be able to log in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _archiveCustomer(customerId, archived: true);
    }
  }

  void _showCustomerDetails(Map<String, dynamic> customer) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (context) => CustomerDetailsPage(
              customerId: customer['id'] as String,
              initialArchived: customer['archived'] == true,
            ),
      ),
    ).then((_) => _loadCustomers());
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Customer Management',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                if (_isSuperAdmin) ...[
                  FilterChip(
                    label: const Text('Show archived'),
                    selected: _includeArchived,
                    onSelected: (v) {
                      setState(() => _includeArchived = v);
                      _loadCustomers();
                    },
                  ),
                  const SizedBox(width: 8),
                ],
                ElevatedButton.icon(
                  onPressed: _loadCustomers,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E1E1E),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Review customer accounts, loyalty stats, and order activity.',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Search by name, email, or phone',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (value) => setState(() => _searchQuery = value),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<String>(
                    value: _statusFilter,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: 'all',
                        child: Text('All'),
                      ),
                      const DropdownMenuItem(
                        value: 'verified',
                        child: Text('Verified'),
                      ),
                      const DropdownMenuItem(
                        value: 'pending',
                        child: Text('Pending'),
                      ),
                      if (_isSuperAdmin)
                        const DropdownMenuItem(
                          value: 'archived',
                          child: Text('Archived'),
                        ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _statusFilter = value;
                        if (value == 'archived' && !_includeArchived) {
                          _includeArchived = true;
                          _loadCustomers();
                        }
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
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
                              onPressed: _loadCustomers,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                      : _filteredCustomers.isEmpty
                      ? const Center(child: Text('No customers found'))
                      : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
                        itemCount: _filteredCustomers.length,
                        itemBuilder: (context, index) {
                          final customer = _filteredCustomers[index];
                          final isArchived = customer['archived'] == true;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(
                                color: Colors.black.withValues(alpha: 0.08),
                              ),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor:
                                    isArchived
                                        ? Colors.grey
                                        : customer['is_verified'] == true
                                        ? Colors.green
                                        : Colors.orange,
                                child: Icon(
                                  isArchived
                                      ? Icons.archive
                                      : customer['is_verified'] == true
                                      ? Icons.check
                                      : Icons.pending,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      customer['full_name'] ?? 'Unknown',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  if (isArchived)
                                    Container(
                                      margin: const EdgeInsets.only(left: 8),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade300,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        'Archived',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(customer['email'] ?? ''),
                                  if (customer['phone'] != null)
                                    Text(customer['phone']),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      // Restaurant Points Chip
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.shade100,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.restaurant,
                                              size: 12,
                                              color: Colors.orange.shade700,
                                            ),
                                            const SizedBox(width: 2),
                                            Text(
                                              '${customer['restaurant_loyalty_points'] ?? 0}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.orange.shade700,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      // Catering Points Chip
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.purple.shade100,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.event,
                                              size: 12,
                                              color: Colors.purple.shade700,
                                            ),
                                            const SizedBox(width: 2),
                                            Text(
                                              '${customer['catering_loyalty_points'] ?? 0}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.purple.shade700,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_isSuperAdmin && !isArchived)
                                    IconButton(
                                      tooltip: 'Archive customer',
                                      icon: Icon(
                                        Icons.archive_outlined,
                                        color: Colors.red.shade700,
                                      ),
                                      onPressed: () => _confirmArchiveFromList(
                                        customer['id'] as String,
                                        customer['full_name']?.toString() ??
                                            'this customer',
                                      ),
                                    ),
                                  if (_isSuperAdmin && isArchived)
                                    IconButton(
                                      tooltip: 'Restore customer',
                                      icon: Icon(
                                        Icons.unarchive_outlined,
                                        color: Colors.green.shade700,
                                      ),
                                      onPressed:
                                          () => _archiveCustomer(
                                            customer['id'] as String,
                                            archived: false,
                                          ),
                                    ),
                                  const Icon(
                                    Icons.arrow_forward_ios,
                                    size: 16,
                                  ),
                                ],
                              ),
                              onTap: () => _showCustomerDetails(
                                customer as Map<String, dynamic>,
                              ),
                            ),
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }
}

class CustomerDetailsPage extends StatefulWidget {
  const CustomerDetailsPage({
    super.key,
    required this.customerId,
    this.initialArchived = false,
  });

  final String customerId;
  final bool initialArchived;

  @override
  State<CustomerDetailsPage> createState() => _CustomerDetailsPageState();
}

class _CustomerDetailsPageState extends State<CustomerDetailsPage> {
  bool get _isSuperAdmin =>
      AuthSession.instance.currentRole == Role.superAdmin;
  Map<String, dynamic>? _customerData;
  List<dynamic> _orders = [];
  int _loyaltyPoints = 0;
  int _restaurantLoyaltyPoints = 0;
  int _cateringLoyaltyPoints = 0;
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
        Uri.parse('$_apiBaseUrl/api/admin/customers/${widget.customerId}'),
        headers: {'Authorization': 'Bearer ${AuthSession.instance.token}'},
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        setState(() {
          _customerData = data['customer'];
          _orders = data['orders'] ?? [];
          _loyaltyPoints = data['loyaltyPoints'] ?? 0;
          _restaurantLoyaltyPoints = data['restaurantLoyaltyPoints'] ?? 0;
          _cateringLoyaltyPoints = data['cateringLoyaltyPoints'] ?? 0;
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
        Uri.parse(
          '$_apiBaseUrl/api/admin/customers/${widget.customerId}/archive',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${AuthSession.instance.token}',
        },
        body: jsonEncode({'archived': archived}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(archived ? 'Customer archived' : 'Customer restored'),
          ),
        );
        if (mounted) Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['error'] ?? 'Failed to update customer')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Back to customers',
                ),
                const SizedBox(width: 6),
                const Text(
                  'Customer Details',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _loadCustomerDetails,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E1E1E),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'View profile details, totals, and account status.',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 16),
            Expanded(
              child:
                  _isLoading
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
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: BorderSide(
                                  color: Colors.black.withValues(alpha: 0.08),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 40,
                                          backgroundColor:
                                              _customerData?['is_verified'] ==
                                                      true
                                                  ? Colors.green
                                                  : Colors.orange,
                                          child: const Icon(
                                            Icons.person,
                                            size: 40,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(width: 20),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                _customerData?['full_name'] ??
                                                    'Unknown',
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
                                              if (_customerData?['phone'] !=
                                                  null) ...[
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
                                            'Total Points',
                                            _loyaltyPoints.toString(),
                                            Icons.star,
                                            Colors.amber,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: _buildInfoCard(
                                            'Restaurant Points',
                                            _restaurantLoyaltyPoints.toString(),
                                            Icons.restaurant,
                                            Colors.orange,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildInfoCard(
                                            'Catering Points',
                                            _cateringLoyaltyPoints.toString(),
                                            Icons.event,
                                            Colors.purple,
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
                                            _customerData?['archived'] == true
                                                ? 'Archived'
                                                : _customerData?['is_verified'] ==
                                                    true
                                                ? 'Verified'
                                                : 'Pending',
                                            _customerData?['archived'] == true
                                                ? Icons.archive
                                                : _customerData?['is_verified'] ==
                                                    true
                                                ? Icons.verified
                                                : Icons.pending,
                                            _customerData?['archived'] == true
                                                ? Colors.grey
                                                : _customerData?['is_verified'] ==
                                                    true
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
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
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
                                      onTap: () => _showOrderDetails(order),
                                      title: Text(
                                        'Order #${order['order_no'] ?? order['id'].toString().substring(0, 8)}',
                                      ),
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

                            if (_isSuperAdmin) ...[
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    final isArchived =
                                        _customerData?['archived'] == true;
                                    if (isArchived) {
                                      await _archiveCustomer(false);
                                      return;
                                    }
                                    final ok = await showDialog<bool>(
                                      context: context,
                                      builder:
                                          (ctx) => AlertDialog(
                                            title: const Text('Archive customer'),
                                            content: const Text(
                                              'This customer will no longer be able to log in. You can restore them later from the archived list.',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed:
                                                    () => Navigator.pop(ctx, false),
                                                child: const Text('Cancel'),
                                              ),
                                              FilledButton(
                                                onPressed:
                                                    () => Navigator.pop(ctx, true),
                                                style: FilledButton.styleFrom(
                                                  backgroundColor: Colors.red,
                                                ),
                                                child: const Text('Archive'),
                                              ),
                                            ],
                                          ),
                                    );
                                    if (ok == true) {
                                      await _archiveCustomer(true);
                                    }
                                  },
                                  icon: Icon(
                                    _customerData?['archived'] == true
                                        ? Icons.unarchive
                                        : Icons.archive,
                                  ),
                                  label: Text(
                                    _customerData?['archived'] == true
                                        ? 'Restore Customer'
                                        : 'Archive Customer',
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        _customerData?['archived'] == true
                                            ? Colors.green.shade50
                                            : Colors.red.shade100,
                                    foregroundColor:
                                        _customerData?['archived'] == true
                                            ? Colors.green.shade800
                                            : Colors.red,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
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
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  void _showOrderDetails(Map<String, dynamic> order) {
    final customer = _customerData ?? <String, dynamic>{};
    final entries = order.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(
            'Order #${order['order_no'] ?? order['id'] ?? ''}',
          ),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Customer',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  const SizedBox(height: 8),
                  _kv('Full name', '${customer['full_name'] ?? '—'}'),
                  _kv('Email', '${customer['email'] ?? '—'}'),
                  _kv('Phone', '${customer['phone'] ?? customer['contact_number'] ?? '—'}'),
                  _kv(
                    'Status',
                    customer['archived'] == true
                        ? 'Archived'
                        : customer['is_verified'] == true
                            ? 'Verified'
                            : 'Pending',
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Order',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  const SizedBox(height: 8),
                  ...entries.map((e) {
                    final value = e.value;
                    final text =
                        value == null
                            ? '—'
                            : value is Map || value is List
                                ? value.toString()
                                : '$value';
                    return _kv(e.key, text);
                  }),
                ],
              ),
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _kv(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(value, style: const TextStyle(fontSize: 13)),
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
