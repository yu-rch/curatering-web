import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/customer_pages_top_bar.dart';
import 'my_order_tracking_page.dart';
import 'my_orders_page.dart';
import 'my_profile_page.dart';

class MyCateringsPage extends StatefulWidget {
  const MyCateringsPage({super.key});

  @override
  State<MyCateringsPage> createState() => _MyCateringsPageState();
}

class _MyCateringsPageState extends State<MyCateringsPage> {
  List<dynamic> _caterings = [];
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _customerData;

  String get _apiBaseUrl {
    const url = String.fromEnvironment('API_BASE_URL');
    return url.isEmpty ? 'https://ffgifzwwqdjeyyedaciu.supabase.co/rest/v1/' : url;
  }

  @override
  void initState() {
    super.initState();
    _loadCaterings();
  }

  Future<void> _loadCaterings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('customer_token');
      final customerData = prefs.getString('customer_data');

      if (token == null || token.isEmpty) {
        if (mounted) {
          Navigator.of(context).pop('login_required');
        }
        return;
      }

      if (customerData != null) {
        _customerData = jsonDecode(customerData);
      }

      // Get customer ID from stored data
      final customerId = _customerData?['id'];
      if (customerId == null) {
        throw Exception('Customer ID not found');
      }

      // Fetch event orders for this customer
      final response = await http.get(
        Uri.parse('$_apiBaseUrl/api/customer/events/orders?customerId=$customerId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 401) {
        await prefs.remove('customer_token');
        await prefs.remove('customer_data');
        if (mounted) {
          _showSessionExpiredDialog();
        }
        return;
      }

      if (response.statusCode == 404) {
        // API endpoint not found - might need to use a different approach
        // For now, show empty state
        if (mounted) {
          setState(() {
            _caterings = [];
            _isLoading = false;
          });
        }
        return;
      }

      if (response.statusCode != 200) {
        throw Exception('Failed to load caterings: ${response.statusCode}');
      }

      final data = jsonDecode(response.body);
      if (mounted) {
        setState(() {
          _caterings = data['orders'] ?? data['caterings'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error loading caterings: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _showSessionExpiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Session Expired'),
        content: const Text('Your session has expired. Please log in again.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop('login_required');
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _formatStatus(String? status) {
    if (status == null) return 'UNKNOWN';
    return status.replaceAll('_', ' ').toUpperCase();
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'online_inquiries':
        return Colors.blue;
      case 'for_processing':
        return Colors.orange;
      case 'for_post_analysis':
        return Colors.purple;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'N/A';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.month}/${date.day}/${date.year}';
    } catch (_) {
      return dateStr;
    }
  }

  String _getEventTypeDisplay(String? eventType) {
    if (eventType == null) return 'Catering';
    switch (eventType) {
      case 'birthday':
        return 'Birthday Party';
      case 'wedding':
        return 'Wedding';
      case 'corporate':
        return 'Corporate Event';
      case 'debut':
        return 'Debut';
      case 'baptismal':
        return 'Baptismal';
      case 'other':
        return 'Other Event';
      default:
        return eventType;
    }
  }

  Map<String, dynamic> _parseThemeDesign(dynamic rawThemeDesign) {
    if (rawThemeDesign is Map<String, dynamic>) return rawThemeDesign;
    if (rawThemeDesign is String && rawThemeDesign.isNotEmpty) {
      try {
        final parsed = jsonDecode(rawThemeDesign);
        if (parsed is Map<String, dynamic>) return parsed;
      } catch (_) {}
    }
    return {};
  }

  void _navigateFromTopBar(CustomerPageTab tab) {
    if (tab == CustomerPageTab.caterings) return;
    final route = switch (tab) {
      CustomerPageTab.profile => const MyProfilePage(),
      CustomerPageTab.orders => const MyOrdersPage(),
      CustomerPageTab.tracking => const MyOrderTrackingPage(),
      CustomerPageTab.caterings => const MyCateringsPage(),
    };
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => route),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'My Caterings',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCaterings,
            tooltip: 'Refresh caterings',
          ),
        ],
      ),
      body: Column(
        children: [
          CustomerPagesTopBar(
            currentTab: CustomerPageTab.caterings,
            onTabSelected: _navigateFromTopBar,
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadCaterings,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E1E1E),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
                    : _caterings.isEmpty
                        ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.event_outlined,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No caterings yet',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Your booked caterings will appear here',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _loadCaterings,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Refresh'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E1E1E),
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    )
                        : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      itemCount: _caterings.length,
                      itemBuilder: (context, index) {
                        final catering = _caterings[index];
                        final status = catering['status'] ?? 'online_inquiries';
                        final isCurrent = status != 'completed' && status != 'cancelled';
                        final themeDesign = _parseThemeDesign(
                          catering['themeDesign'] ?? catering['theme_design'],
                        );
                        final managerNotice = themeDesign['managerUpdateNotice'];
                        final hasPreferenceChangeNotice =
                            managerNotice is Map &&
                            managerNotice['preferencesChanged'] == true;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(color: Colors.black.withOpacity(0.08)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        catering['event_title'] ?? catering['eventTitle'] ?? 'Untitled Event',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (isCurrent)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green.shade100,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          'ACTIVE',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green.shade700,
                                          ),
                                        ),
                                      ),
                                    if (hasPreferenceChangeNotice) ...[
                                      const SizedBox(width: 8),
                                      Tooltip(
                                        message:
                                            'Macrina\'s posted updates to your preferences. Please review your latest estimate.',
                                        child: const Icon(
                                          Icons.info_outline,
                                          color: Color(0xFF1976D2),
                                          size: 20,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.event,
                                      size: 16,
                                      color: Colors.grey.shade600,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _getEventTypeDisplay(catering['event_type'] ?? catering['eventType']),
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_today,
                                      size: 16,
                                      color: Colors.grey.shade600,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _formatDate(catering['created_at'] ?? catering['createdAt']),
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                                if (catering['guest_count'] != null || catering['guestCount'] != null) ...[
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.people,
                                        size: 16,
                                        color: Colors.grey.shade600,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${catering['guest_count'] ?? catering['guestCount']} guests',
                                        style: TextStyle(
                                          color: Colors.grey.shade700,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                const Divider(height: 24),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Chip(
                                      label: Text(
                                        _formatStatus(status),
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.white,
                                        ),
                                      ),
                                      backgroundColor: _getStatusColor(status),
                                      padding: EdgeInsets.zero,
                                    ),
                                    if (catering['total_cost'] != null ||
                                        catering['totalCost'] != null)
                                      Text(
                                        '₱${catering['total_cost'] ?? catering['totalCost']}',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFFF4511E),
                                        ),
                                      ),
                                  ],
                                ),
                                if (status == 'online_inquiries') ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE3F2FD),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: const Color(0xFF90CAF9),
                                      ),
                                    ),
                                    child: Text(
                                      'Review your latest cost estimate above. Once you approve, your inquiry can be confirmed for processing.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.blue.shade900,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
