import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import '../widgets/antd_buttons.dart';
import '../widgets/antd_dialog.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/customer_order_feedback_dialog.dart';

class MyInquiriesPage extends StatefulWidget {
  const MyInquiriesPage({super.key});

  @override
  State<MyInquiriesPage> createState() => _MyInquiriesPageState();
}

class _MyInquiriesPageState extends State<MyInquiriesPage>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _inquiries = [];
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _selectedInquiry;

  late final TabController _tabController;
  static const Duration _requestTimeout = Duration(seconds: 45);
  static const _accent = Color(0xFFFFC024);

  static const _tabs = ['waiting', 'responded', 'completed', 'cancelled'];
  static const _tabLabels = {
    'waiting': 'Waiting for Response',
    'responded': 'Responded',
    'completed': 'Completed',
    'cancelled': 'Cancelled',
  };

  String get _apiBaseUrl => apiBaseUrl;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _selectedInquiry = null);
      }
    });
    _loadInquiries();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _tabCategory(String status) {
    switch (status) {
      case 'online_inquiries':
        return 'waiting';
      case 'for_down_payment':
      case 'on_going':
      case 'for_full_payment':
        return 'responded';
      case 'completed':
        return 'completed';
      case 'cancelled':
        return 'cancelled';
      default:
        return 'waiting';
    }
  }

  List<Map<String, dynamic>> _inquiriesForTab(String tab) {
    return _inquiries.where((i) {
      final status = (i['status'] ?? '').toString();
      return _tabCategory(status) == tab;
    }).toList();
  }

  String _transactionNo(Map<String, dynamic> inquiry) {
    final orderType =
        (inquiry['order_type'] ?? inquiry['orderType'] ?? 'catering')
            .toString()
            .toLowerCase();
    if (orderType == 'event') {
      return (inquiry['eventId'] ??
              inquiry['event_id'] ??
              inquiry['cateringId'] ??
              inquiry['catering_id'] ??
              '')
          .toString();
    }
    return (inquiry['catering_id'] ??
            inquiry['cateringId'] ??
            inquiry['id'] ??
            '')
        .toString();
  }

  Future<String?> _token() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('customer_token');
  }

  Future<void> _loadInquiries({bool force = false}) async {
    try {
      final token = await _token();
      if (token == null || token.isEmpty) {
        if (mounted) Navigator.of(context).pop('login_required');
        return;
      }

      if (mounted) setState(() { _isLoading = true; _error = null; });

      final response = await http
          .get(
            Uri.parse('$_apiBaseUrl/api/customer/events/orders'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          )
          .timeout(_requestTimeout);

      if (response.statusCode == 401) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('customer_token');
        await prefs.remove('customer_data');
        if (mounted) _showSessionExpiredDialog();
        return;
      }

      if (response.statusCode == 404) {
        if (mounted) setState(() { _inquiries = []; _isLoading = false; });
        return;
      }

      if (response.statusCode != 200) {
        throw Exception('Failed to load inquiries: ${response.statusCode}');
      }

      final data = jsonDecode(response.body);
      final list = data['orders'] ?? data['caterings'] ?? [];
      final asList = (list is List ? list : const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      if (mounted) {
        setState(() {
          _inquiries = asList;
          _isLoading = false;
          if (_selectedInquiry != null) {
            final selId = _selectedInquiry!['id']?.toString();
            final updated = asList.where((i) => i['id']?.toString() == selId);
            _selectedInquiry = updated.isNotEmpty ? updated.first : null;
          }
        });
      }
    } on TimeoutException {
      if (mounted) {
        setState(() {
          _error =
              'Request timed out. Please check your connection and try again.';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error loading inquiries: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _respondToInquiry({
    required String orderId,
    required String action,
  }) async {
    final token = await _token();
    if (token == null || token.isEmpty) return;

    final response = await http.post(
      Uri.parse('$_apiBaseUrl/api/customer/events/orders/$orderId/respond'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'action': action}),
    );

    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(body['error'] ?? 'Failed (${response.statusCode})');
    }
  }

  Future<void> _sendFollowUp(String orderId) async {
    final token = await _token();
    if (token == null || token.isEmpty) return;

    final response = await http.post(
      Uri.parse('$_apiBaseUrl/api/customer/events/orders/$orderId/follow-up'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(body['error'] ?? 'Failed (${response.statusCode})');
    }
  }

  void _showSessionExpiredDialog() {
    showAntdModal<void>(
      context: context,
      title: 'Session expired',
      barrierDismissible: false,
      maxWidth: 420,
      body: const Text('Your session has expired. Please log in again.'),
      actions: [
        AntdPrimaryButton(
          label: 'Log in',
          onPressed: () {
            Navigator.of(context).pop();
            Navigator.of(context).pop('login_required');
          },
        ),
      ],
    );
  }

  Future<void> _confirmCancel(Map<String, dynamic> inquiry) async {
    final id = inquiry['id']?.toString() ?? '';
    final txNo = _transactionNo(inquiry);

    final confirmed = await showAntdModal<bool>(
      context: context,
      title: 'Cancel inquiry',
      maxWidth: 420,
      body: Text(
        'Are you sure you want to cancel inquiry $txNo? This cannot be undone.',
      ),
      actions: [
        AntdCancelButton(
          label: 'No, keep it',
          onPressed: () => Navigator.of(context).pop(false),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: const Text('Cancel inquiry'),
        ),
      ],
    );

    if (confirmed != true || !mounted) return;

    try {
      await _respondToInquiry(orderId: id, action: 'cancel_inquiry');
      if (!mounted) return;
      showAppSnackBar(context, 'Inquiry cancelled.',
          icon: Icons.check_circle_outline);
      _loadInquiries(force: true);
    } catch (e) {
      if (mounted) showAppSnackBar(context, 'Cancel failed: $e', error: true);
    }
  }

  Future<void> _confirmFollowUp(Map<String, dynamic> inquiry) async {
    final id = inquiry['id']?.toString() ?? '';
    final txNo = _transactionNo(inquiry);

    final confirmed = await showAntdModal<bool>(
      context: context,
      title: 'Send follow-up',
      maxWidth: 420,
      body: Text(
        'Send a follow-up notification to the catering team about inquiry $txNo?',
      ),
      actions: [
        AntdCancelButton(
          label: 'Not now',
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AntdPrimaryButton(
          label: 'Send follow-up',
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );

    if (confirmed != true || !mounted) return;

    try {
      await _sendFollowUp(id);
      if (!mounted) return;
      showAppSnackBar(context, 'Follow-up sent successfully.',
          icon: Icons.check_circle_outline);
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, 'Follow-up failed: $e', error: true);
      }
    }
  }

  static const _statusMeta = <String, ({String label, Color color})>{
    'online_inquiries': (label: 'Waiting for Response', color: Colors.blue),
    'for_down_payment': (label: 'For Down Payment', color: Colors.purple),
    'on_going': (label: 'Ongoing', color: Colors.teal),
    'for_full_payment': (label: 'For Full Payment', color: Colors.indigo),
    'completed': (label: 'Completed', color: Colors.green),
    'cancelled': (label: 'Cancelled', color: Colors.red),
  };

  String _statusLabel(String status) =>
      _statusMeta[status]?.label ?? status.replaceAll('_', ' ').toUpperCase();

  Color _statusColor(String status) =>
      _statusMeta[status]?.color ?? Colors.grey;

  bool _canCancel(String status) => status == 'online_inquiries';

  bool _canFollowUp(String status) {
    final cat = _tabCategory(status);
    return cat == 'waiting' || cat == 'responded';
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '—';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      return '${months[date.month - 1]} ${date.day.toString().padLeft(2, '0')}, ${date.year}';
    } catch (_) {
      return dateStr;
    }
  }

  String _formatDateTime(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    final d = DateTime.tryParse(iso)?.toLocal();
    if (d == null) return iso;
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final ampm = d.hour >= 12 ? 'PM' : 'AM';
    final min = d.minute.toString().padLeft(2, '0');
    return '${_formatDate(iso)} $h:$min $ampm';
  }

  double _parseDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  String _formatPesos(dynamic v) {
    final n = _parseDouble(v);
    return '₱${n.toStringAsFixed(2)}';
  }

  String _eventTypeDisplay(dynamic eventType) {
    if (eventType == null) return 'Catering';
    switch (eventType.toString()) {
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
      case 'catering':
        return 'Catering';
      default:
        return eventType.toString();
    }
  }

  List<dynamic> _parseDynamicList(dynamic raw) {
    if (raw is List) return raw;
    if (raw is String && raw.isNotEmpty) {
      try {
        final parsed = jsonDecode(raw);
        if (parsed is List) return parsed;
      } catch (_) {}
    }
    return const [];
  }

  String _formatSchedule(List<dynamic> slots) {
    if (slots.isEmpty) return '—';
    return slots.map((slot) {
      if (slot is! Map) return '';
      final s = Map<String, dynamic>.from(slot);
      final date = (s['date'] ?? '').toString();
      final start = (s['startTime'] ?? s['start_time'] ?? '').toString();
      final end = (s['endTime'] ?? s['end_time'] ?? '').toString();
      return '$date  $start–$end'.trim();
    }).where((s) => s.isNotEmpty).join('\n');
  }

  String _formatMenu(List<dynamic> menuList) {
    if (menuList.isEmpty) return '—';
    final lines = <String>[];
    for (final item in menuList) {
      if (item is! Map) continue;
      final m = Map<String, dynamic>.from(item);
      final dish =
          (m['dishName'] ?? m['dish_name'] ?? m['name'] ?? 'Dish').toString();
      final pax = (m['paxOption'] ?? m['pax_option'] ?? '').toString();
      var line = '• $dish';
      if (pax.isNotEmpty) line += ' ($pax)';
      lines.add(line);
    }
    return lines.isEmpty ? '—' : lines.join('\n');
  }

  String _primaryDateStr(Map<String, dynamic> inquiry) {
    final slots =
        _parseDynamicList(inquiry['scheduleSlots'] ?? inquiry['schedule_slots']);
    if (slots.isEmpty) return '';
    final first = slots.first;
    if (first is! Map) return '';
    return (first['date'] ?? '').toString();
  }

  Widget _buildFeedbackPrompt({
    required VoidCallback onPressed,
    bool submitted = false,
  }) {
    if (submitted) {
      return Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green.shade400, size: 20),
          const SizedBox(width: 8),
          Text(
            'Thank you for your feedback!',
            style: TextStyle(color: Colors.green.shade700, fontSize: 12),
          ),
        ],
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFC024).withOpacity(0.22),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFFC024).withOpacity(0.5)),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Rate this inquiry',
            onPressed: onPressed,
            icon: const Icon(Icons.rate_review_outlined, color: Color(0xFF1E1E1E)),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          Expanded(
            child: Text(
              'How was your order? Your feedback will help us improve!',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1E1E1E),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontWeight: FontWeight.w700,
        fontSize: 14,
        color: const Color(0xFF1E1E1E),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            child: Text(
              value.trim().isEmpty ? '—' : value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        _statusLabel(status).toUpperCase(),
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
      ),
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
          'My Inquiries',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadInquiries(force: true),
            tooltip: 'Refresh inquiries',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(46),
          child: Container(
            color: const Color(0xFF1E1E1E),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorColor: _accent,
              indicatorWeight: 3,
              labelColor: _accent,
              unselectedLabelColor: Colors.white60,
              labelStyle:
                  GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
              unselectedLabelStyle:
                  GoogleFonts.poppins(fontWeight: FontWeight.w400, fontSize: 13),
              tabAlignment: TabAlignment.start,
              tabs: _tabs.map((t) {
                final count = _inquiriesForTab(t).length;
                return Tab(text: '${_tabLabels[t]} ($count)');
              }).toList(),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _accent))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => _loadInquiries(force: true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E1E1E),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: _tabs.map(_buildSplitView).toList(),
                ),
    );
  }

  Widget _buildSplitView(String tab) {
    final items = _inquiriesForTab(tab);

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No ${_tabLabels[tab]?.toLowerCase()} inquiries',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        SizedBox(width: 380, child: _buildInquiryList(items)),
        const VerticalDivider(width: 1, thickness: 1),
        Expanded(
          child: _selectedInquiry != null &&
                  items.any((i) => i['id']?.toString() == _selectedInquiry!['id']?.toString())
              ? _buildInquiryDetail(_selectedInquiry!)
              : _buildEmptyDetail(),
        ),
      ],
    );
  }

  Widget _buildInquiryList(List<Map<String, dynamic>> items) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final inquiry = items[i];
        final id = inquiry['id']?.toString() ?? '';
        final isSelected =
            _selectedInquiry != null && _selectedInquiry!['id']?.toString() == id;
        final status = (inquiry['status'] ?? '').toString();
        final title = (inquiry['eventTitle'] ??
                inquiry['event_title'] ??
                'Catering inquiry')
            .toString();
        final txNo = _transactionNo(inquiry);
        final total = _parseDouble(
          inquiry['totalCost'] ?? inquiry['total_cost'] ?? inquiry['estimatedTotal'],
        );

        return Material(
          color: isSelected ? _accent.withOpacity(0.10) : Colors.transparent,
          child: InkWell(
            onTap: () => setState(() => _selectedInquiry = inquiry),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade200),
                  left: isSelected
                      ? const BorderSide(color: _accent, width: 4)
                      : BorderSide.none,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (total > 0)
                        Text(
                          _formatPesos(total),
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    txNo.isNotEmpty ? '#$txNo' : '—',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _formatDate(inquiry['createdAt']?.toString()),
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ),
                      _buildStatusBadge(status),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyDetail() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.touch_app_outlined, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            'Select an inquiry to view details',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildInquiryDetail(Map<String, dynamic> inquiry) {
    final status = (inquiry['status'] ?? '').toString();
    final txNo = _transactionNo(inquiry);
    final title = (inquiry['eventTitle'] ??
            inquiry['event_title'] ??
            'Catering inquiry')
        .toString();
    final slots =
        _parseDynamicList(inquiry['scheduleSlots'] ?? inquiry['schedule_slots']);
    final menuList = _parseDynamicList(inquiry['menu']);
    final address = (inquiry['address'] ?? inquiry['venue'] ?? '').toString();
    final feedbackSubmitted = inquiry['feedbackSubmitted'] == true;
    final canFeedback = status == 'completed' && !feedbackSubmitted;

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        txNo.isNotEmpty ? 'Transaction #$txNo' : '—',
                        style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatDateTime(inquiry['createdAt']?.toString()),
                        style: GoogleFonts.poppins(color: Colors.white60, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                _buildStatusBadge(status),
              ],
            ),
          ),
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (canFeedback)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _buildFeedbackPrompt(
                          submitted: feedbackSubmitted,
                          onPressed: () async {
                            final ref = (inquiry['id'] ?? '').toString();
                            if (ref.isEmpty) return;
                            final submitted = await showCustomerOrderFeedbackDialog(
                              context,
                              kind: 'catering_inquiry',
                              reference: ref,
                              label: txNo.isNotEmpty ? txNo : ref,
                              getToken: _token,
                            );
                            if (submitted) _loadInquiries(force: true);
                          },
                        ),
                      ),
                    _sectionTitle('Contact'),
                    const SizedBox(height: 8),
                    _infoRow('Name', '${inquiry['customerName'] ?? inquiry['customer_name'] ?? ''}'),
                    _infoRow('Contact person', '${inquiry['contactPerson'] ?? inquiry['contact_person'] ?? ''}'),
                    _infoRow('Phone', '${inquiry['contactNumber'] ?? inquiry['contact_number'] ?? ''}'),
                    _infoRow('Email', '${inquiry['emailAddress'] ?? inquiry['email_address'] ?? ''}'),
                    const SizedBox(height: 20),
                    _sectionTitle('Event'),
                    const SizedBox(height: 8),
                    _infoRow('Service type', _eventTypeDisplay(inquiry['eventType'] ?? inquiry['event_type'])),
                    _infoRow('Formality', '${inquiry['formalityLevel'] ?? inquiry['formality_level'] ?? '—'}'),
                    _infoRow('Setting', '${inquiry['eventSetting'] ?? inquiry['event_setting'] ?? '—'}'),
                    _infoRow('Guests', '${inquiry['guestCount'] ?? inquiry['guest_count'] ?? '—'}'),
                    _infoRow('Schedule', _formatSchedule(slots)),
                    if (address.isNotEmpty) _infoRow('Venue / address', address),
                    _infoRow('Allergens', '${inquiry['allergens'] ?? '—'}'),
                    _infoRow('Set menu', '${inquiry['selectedSetMenu'] ?? inquiry['selected_set_menu'] ?? '—'}'),
                    _infoRow('Service included', '${inquiry['serviceIncluded'] ?? inquiry['service_included'] ?? '—'}'),
                    if (inquiry['foodTastingRequested'] == true ||
                        inquiry['food_tasting_requested'] == true) ...[
                      _infoRow('Food tasting', '${inquiry['foodTastingDate'] ?? inquiry['food_tasting_date'] ?? ''} ${inquiry['foodTastingTime'] ?? inquiry['food_tasting_time'] ?? ''}'),
                    ],
                    const SizedBox(height: 20),
                    _sectionTitle('Payment'),
                    const SizedBox(height: 8),
                    _infoRow('Method', '${inquiry['paymentMethod'] ?? inquiry['payment_method'] ?? '—'}'),
                    _infoRow('Total cost', _formatPesos(inquiry['totalCost'] ?? inquiry['total_cost'])),
                    _infoRow('Down payment', '${_formatPesos(inquiry['downPaymentAmount'] ?? inquiry['down_payment_amount'])} (${inquiry['downPaymentStatus'] ?? inquiry['down_payment_status'] ?? 'pending'})'),
                    _infoRow('Full payment', '${_formatPesos(inquiry['fullPaymentAmount'] ?? inquiry['full_payment_amount'])} (${inquiry['fullPaymentStatus'] ?? inquiry['full_payment_status'] ?? 'pending'})'),
                    if ((inquiry['downPaymentReference'] ?? inquiry['down_payment_reference'] ?? '').toString().isNotEmpty)
                      _infoRow('Down payment ref', '${inquiry['downPaymentReference'] ?? inquiry['down_payment_reference']}'),
                    if ((inquiry['fullPaymentReference'] ?? inquiry['full_payment_reference'] ?? '').toString().isNotEmpty)
                      _infoRow('Full payment ref', '${inquiry['fullPaymentReference'] ?? inquiry['full_payment_reference']}'),
                    const SizedBox(height: 20),
                    _sectionTitle('Menu'),
                    const SizedBox(height: 8),
                    Text(_formatMenu(menuList), style: const TextStyle(fontSize: 13)),
                    const SizedBox(height: 20),
                    if (_canFollowUp(status) || _canCancel(status)) ...[
                      const Divider(height: 32),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          if (_canFollowUp(status))
                            ElevatedButton.icon(
                              onPressed: () => _confirmFollowUp(inquiry),
                              icon: const Icon(Icons.mark_email_read_outlined, size: 18),
                              label: const Text('Send Follow-up'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1E1E1E),
                                foregroundColor: Colors.white,
                              ),
                            ),
                          if (_canCancel(status))
                            OutlinedButton.icon(
                              onPressed: () => _confirmCancel(inquiry),
                              icon: Icon(Icons.cancel_outlined, size: 18, color: Colors.red.shade600),
                              label: Text('Cancel Inquiry', style: TextStyle(color: Colors.red.shade600)),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.red.shade300),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
