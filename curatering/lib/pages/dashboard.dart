import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../auth/auth_session.dart';
import '../config.dart';
import '../widgets/app_scaffold.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _orders = const [];
  DateTime? _lastFetchedAt;

  @override
  void initState() {
    super.initState();
    _loadRestaurantOrders();
  }

  Future<void> _loadRestaurantOrders({bool forceRefresh = false}) async {
    if (!AuthSession.instance.hasToken) {
      if (mounted) {
        setState(() => _errorMessage = 'Please log in to view the dashboard.');
      }
      return;
    }

    // Small guard to avoid hammering the API.
    if (!forceRefresh &&
        _lastFetchedAt != null &&
        DateTime.now().difference(_lastFetchedAt!) < const Duration(minutes: 2)) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = AuthSession.instance.token!;
      final response = await http.get(
        Uri.parse('$apiBaseUrl/api/manager/restaurant/orders?limit=50'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        throw Exception(
          'Failed to load orders (status: ${response.statusCode})',
        );
      }

      final decoded = jsonDecode(response.body);
      final rawOrders = decoded['orders'] ?? decoded['data'];
      if (rawOrders is! List) {
        throw Exception('Invalid dashboard payload');
      }

      final parsedOrders = rawOrders
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      if (mounted) {
        setState(() {
          _orders = parsedOrders;
          _lastFetchedAt = DateTime.now();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Failed to load dashboard data.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  double _parseAmount(dynamic amount) {
    if (amount == null) return 0.0;
    if (amount is num) return amount.toDouble();
    if (amount is String) return double.tryParse(amount) ?? 0.0;
    return 0.0;
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  DateTime? _tryParseDateTime(dynamic value) {
    if (value == null) return null;
    final s = value.toString().trim();
    if (s.isEmpty || s == 'null') return null;
    return DateTime.tryParse(s);
  }

  String _formatDateTimeCell(dynamic raw) {
    final dt = _tryParseDateTime(raw);
    if (dt == null) return 'N/A';
    final local = dt.toLocal();
    final two = (int v) => v.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
  }

  List<Map<String, dynamic>> get _pendingOrders =>
      _orders.where((o) => (o['status'] as String?) == 'pending').toList();

  List<Map<String, dynamic>> get _processingOrders =>
      _orders.where((o) {
        final s = (o['status'] as String?) ?? '';
        return s == 'confirmed' || s == 'preparing' || s == 'out_for_delivery';
      }).toList();

  double _totalSalesToday() {
    final now = DateTime.now();
    return _orders
        .where((o) {
          final dt = _tryParseDateTime(o['created_at']);
          return dt != null && _sameDay(dt, now);
        })
        .fold<double>(0.0, (sum, o) => sum + _parseAmount(o['total_amount']));
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
      case 'preparing':
        return Colors.blue;
      case 'out_for_delivery':
        return Colors.purple;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Card(
        color: color,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pending = _pendingOrders;
    final processing = _processingOrders;
    final salesToday = _totalSalesToday();

    final content = SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Manager Dashboard',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Refresh',
                onPressed: _isLoading ? null : () => _loadRestaurantOrders(forceRefresh: true),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_errorMessage != null) ...[
            Card(
              color: Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Colors.red.shade800),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          Row(
            children: [
              _buildStatCard(
                title: 'Pending confirmations',
                value: '${pending.length}',
                color: Colors.orange.shade400,
              ),
              const SizedBox(width: 16),
              _buildStatCard(
                title: 'Processing',
                value: '${processing.length}',
                color: Colors.blue.shade600,
              ),
              const SizedBox(width: 16),
              _buildStatCard(
                title: 'Sales today',
                value: '₱${salesToday.toStringAsFixed(2)}',
                color: Colors.green.shade600,
              ),
            ],
          ),

          const SizedBox(height: 20),

          Text(
            'Recent pending orders',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 10),

          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (pending.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'No pending confirmations right now.',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'When customers place an order, it will appear here for confirmation.',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.of(context).pushNamed('/restaurant-orders'),
                      icon: const Icon(Icons.receipt_long),
                      label: const Text('Go to Restaurant Orders'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E1E1E),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Column(
              children: pending.take(6).map((o) {
                final status = (o['status'] as String?) ?? 'pending';
                final customer = (o['full_name'] as String?) ?? 'N/A';
                final amount = _parseAmount(o['total_amount']);
                final delivery = o['delivery_time'] ?? o['created_at'];

                final id = (o['id'] ?? '').toString();
                final shortId =
                    id.length >= 8 ? id.substring(id.length - 8) : id;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: _statusColor(status).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _statusColor(status).withOpacity(0.35),
                            ),
                          ),
                          child: Icon(
                            Icons.receipt_long,
                            color: _statusColor(status),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Order #${shortId.toUpperCase()}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                customer,
                                style: TextStyle(
                                  color: Colors.grey.shade800,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '₱${amount.toStringAsFixed(2)} • Delivery: ${_formatDateTimeCell(delivery)}',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _statusColor(status).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: _statusColor(status).withOpacity(0.35),
                            ),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              color: _statusColor(status),
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () =>
                  Navigator.of(context).pushNamed('/restaurant-orders'),
              icon: const Icon(Icons.chevron_right),
              label: const Text('View all'),
            ),
          ),
        ],
      ),
    );

    return AppScaffold(showSearch: true, child: content);
  }
}
