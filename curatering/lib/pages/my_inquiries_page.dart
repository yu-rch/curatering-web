import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import '../widgets/antd_buttons.dart';
import '../widgets/antd_descriptions.dart';
import '../widgets/antd_dialog.dart';
import '../widgets/app_snackbar.dart';

class MyInquiriesPage extends StatefulWidget {
  const MyInquiriesPage({super.key});

  @override
  State<MyInquiriesPage> createState() => _MyInquiriesPageState();
}

class _MyInquiriesPageState extends State<MyInquiriesPage>
    with SingleTickerProviderStateMixin {
  List<dynamic> _inquiries = [];
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _selectedInquiry;

  late final TabController _tabController;
  static const Duration _requestTimeout = Duration(seconds: 45);
  static const Color _accent = Color(0xFFFFC024);

  static const _tabs = [
    'Waiting for Response',
    'Responded',
    'Completed',
    'Cancelled',
  ];

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

  // ---------------------------------------------------------------------------
  // Tab filtering
  // ---------------------------------------------------------------------------

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

  List<Map<String, dynamic>> get _currentTabInquiries {
    const categoryByIndex = ['waiting', 'responded', 'completed', 'cancelled'];
    final target = categoryByIndex[_tabController.index];
    return _inquiries
        .whereType<Map<String, dynamic>>()
        .where((i) => _tabCategory((i['status'] ?? '').toString()) == target)
        .toList();
  }

  // ---------------------------------------------------------------------------
  // API helpers
  // ---------------------------------------------------------------------------

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

      final response = await http.get(
        Uri.parse('$_apiBaseUrl/api/customer/events/orders'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(_requestTimeout);

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
      final asList = list is List ? List<dynamic>.from(list) : <dynamic>[];
      if (mounted) {
        setState(() {
          _inquiries = asList;
          _isLoading = false;
          if (_selectedInquiry != null) {
            final selId = _selectedInquiry!['id']?.toString();
            final updated = asList.whereType<Map<String, dynamic>>().where(
              (i) => i['id']?.toString() == selId,
            );
            _selectedInquiry = updated.isNotEmpty ? updated.first : null;
          }
        });
      }
    } on TimeoutException {
      if (mounted) {
        setState(() {
          _error = 'Request timed out. Please check your connection and try again.';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() { _error = 'Error loading inquiries: $e'; _isLoading = false; });
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

  // ---------------------------------------------------------------------------
  // Dialogs
  // ---------------------------------------------------------------------------

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
    final cateringId =
        (inquiry['catering_id'] ?? inquiry['cateringId'] ?? id).toString();

    final confirmed = await showAntdModal<bool>(
      context: context,
      title: 'Cancel inquiry',
      maxWidth: 420,
      body: Text(
        'Are you sure you want to cancel inquiry $cateringId? This cannot be undone.',
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
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
          child: const Text('Cancel inquiry',
              style: TextStyle(fontWeight: FontWeight.w600)),
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
    final cateringId =
        (inquiry['catering_id'] ?? inquiry['cateringId'] ?? id).toString();

    final confirmed = await showAntdModal<bool>(
      context: context,
      title: 'Send follow-up',
      maxWidth: 420,
      body: Text(
        'Send a follow-up notification to the catering team about inquiry $cateringId?',
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

  // ---------------------------------------------------------------------------
  // Status helpers
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // Format helpers
  // ---------------------------------------------------------------------------

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '—';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.month}/${date.day}/${date.year}';
    } catch (_) {
      return dateStr;
    }
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
    final slots = _parseDynamicList(
        inquiry['scheduleSlots'] ?? inquiry['schedule_slots']);
    if (slots.isEmpty) return '';
    final first = slots.first;
    if (first is! Map) return '';
    return (first['date'] ?? '').toString();
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: _accent));
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _loadInquiries(force: true),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        _buildTabBar(),
        Expanded(child: _buildSplitLayout()),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 20, 32, 0),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'My Inquiries',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadInquiries(force: true),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        labelColor: Colors.black87,
        unselectedLabelColor: Colors.grey.shade500,
        indicatorColor: _accent,
        indicatorWeight: 3,
        labelStyle:
            const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 13),
        tabAlignment: TabAlignment.start,
        tabs: _tabs.map((t) => Tab(text: t)).toList(),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Split layout: list LEFT, detail RIGHT
  // ---------------------------------------------------------------------------

  Widget _buildSplitLayout() {
    final w = MediaQuery.sizeOf(context).width;
    final items = _currentTabInquiries;

    if (w < 800) {
      if (_selectedInquiry != null) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() => _selectedInquiry = null),
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Back to list'),
                ),
              ),
            ),
            Expanded(child: _buildDetailPanel(_selectedInquiry!)),
          ],
        );
      }
      return _buildListPanel(items);
    }

    return Row(
      children: [
        SizedBox(
          width: 380,
          child: _buildListPanel(items),
        ),
        Container(width: 1, color: Colors.grey.shade200),
        Expanded(
          child: _selectedInquiry != null
              ? _buildDetailPanel(_selectedInquiry!)
              : _buildSelectPrompt(),
        ),
      ],
    );
  }

  Widget _buildSelectPrompt() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.mail_outline, size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            'Select an inquiry to view details',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 15),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // LEFT: Inquiry list panel
  // ---------------------------------------------------------------------------

  Widget _buildListPanel(List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text(
              'No inquiries found',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'No inquiries match this tab.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      itemBuilder: (_, i) => _buildListItem(items[i]),
    );
  }

  Widget _buildListItem(Map<String, dynamic> inquiry) {
    final id = inquiry['id']?.toString() ?? '';
    final cateringId =
        (inquiry['catering_id'] ?? inquiry['cateringId'] ?? id).toString();
    final status = (inquiry['status'] ?? '').toString();
    final title =
        (inquiry['eventTitle'] ?? inquiry['event_title'] ?? 'Untitled')
            .toString();
    final eventType =
        (inquiry['eventType'] ?? inquiry['event_type'] ?? '').toString();
    final guests =
        (inquiry['guestCount'] ?? inquiry['guest_count'] ?? '').toString();
    final dateStr = _primaryDateStr(inquiry);
    final isSelected = _selectedInquiry?['id']?.toString() == id;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: isSelected ? _accent.withValues(alpha: 0.08) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isSelected ? _accent : Colors.grey.shade200,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => setState(() => _selectedInquiry = inquiry),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _statusBadge(status),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                cateringId,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  if (eventType.isNotEmpty)
                    _infoChip(Icons.celebration_outlined,
                        _eventTypeDisplay(eventType)),
                  if (dateStr.isNotEmpty)
                    _infoChip(Icons.calendar_today_outlined, dateStr),
                  if (guests.isNotEmpty && guests != '0')
                    _infoChip(Icons.people_outline, '$guests guests'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // RIGHT: Detail panel
  // ---------------------------------------------------------------------------

  Widget _buildDetailPanel(Map<String, dynamic> inquiry) {
    final status = (inquiry['status'] ?? '').toString();
    final cateringId =
        (inquiry['catering_id'] ?? inquiry['cateringId'] ?? '').toString();
    final title =
        (inquiry['eventTitle'] ?? inquiry['event_title'] ?? 'Untitled')
            .toString();
    final slots = _parseDynamicList(
        inquiry['scheduleSlots'] ?? inquiry['schedule_slots']);
    final menuList = _parseDynamicList(inquiry['menu']);
    final venue =
        (inquiry['venue'] ?? inquiry['event_venue'] ?? '').toString();
    final themeNotes =
        (inquiry['themeDesignNotes'] ?? inquiry['theme_design_notes'] ?? '')
            .toString();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      cateringId,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              _statusBadge(status),
            ],
          ),
          const SizedBox(height: 20),
          AntdDescriptions(
            column: 2,
            labelColor: Colors.grey.shade600,
            valueColor: Colors.black87,
            items: [
              AntdDescriptionItem(
                label: 'Event Type',
                value: _eventTypeDisplay(
                    inquiry['eventType'] ?? inquiry['event_type']),
              ),
              AntdDescriptionItem(
                label: 'Guest Count',
                value:
                    '${inquiry['guestCount'] ?? inquiry['guest_count'] ?? '—'}',
              ),
              AntdDescriptionItem(
                label: 'Status',
                value: _statusLabel(status),
              ),
              AntdDescriptionItem(
                label: 'Date',
                value: _formatSchedule(slots),
              ),
              if (venue.isNotEmpty)
                AntdDescriptionItem(
                  label: 'Venue',
                  value: venue,
                  span: 2,
                ),
              AntdDescriptionItem(
                label: 'Menu Items',
                value: _formatMenu(menuList),
                span: 2,
              ),
              if (themeNotes.isNotEmpty)
                AntdDescriptionItem(
                  label: 'Theme / Design Notes',
                  value: themeNotes,
                  span: 2,
                ),
            ],
          ),
          const SizedBox(height: 24),
          if (_canFollowUp(status) || _canCancel(status))
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (_canFollowUp(status))
                  ElevatedButton.icon(
                    onPressed: () => _confirmFollowUp(inquiry),
                    icon: const Icon(Icons.mark_email_read_outlined, size: 16),
                    label: const Text('Send Follow-up'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accent,
                      foregroundColor: Colors.black87,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                if (_canCancel(status))
                  OutlinedButton.icon(
                    onPressed: () => _confirmCancel(inquiry),
                    icon: Icon(Icons.cancel_outlined,
                        size: 16, color: Colors.red.shade600),
                    label: Text('Cancel Inquiry',
                        style: TextStyle(color: Colors.red.shade600)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.red.shade300),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Shared widgets
  // ---------------------------------------------------------------------------

  Widget _statusBadge(String status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
        ),
      ],
    );
  }
}
