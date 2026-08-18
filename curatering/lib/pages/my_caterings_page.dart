import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import '../models/seating_plan.dart';
import '../services/customer_orders_cache.dart';
import '../services/menu_store.dart';
import '../services/runpod_service.dart';
import '../services/set_menu_store.dart';
import '../widgets/antd_buttons.dart';
import '../widgets/antd_descriptions.dart';
import '../widgets/antd_dialog.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/customer_order_feedback_dialog.dart';
import '../widgets/customer_account_shell.dart';
import '../widgets/customer_pages_top_bar.dart';
import '../utils/order_type_utils.dart';
import '../widgets/seating_plan_canvas.dart';
import 'customer_website.dart';
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
  bool _gridView = false;
  /// 0 waiting · 1 responded · 2 completed · 3 cancelled
  int _statusChipIndex = 0;
  final _searchCtrl = TextEditingController();
  String _typeFilter = 'all'; // all | catering_only | event_only
  DateTime? _dateFrom;
  DateTime? _dateTo;
  static const Duration _requestTimeout = Duration(seconds: 45);

  String get _apiBaseUrl {
    return apiBaseUrl;
  }

  @override
  void initState() {
    super.initState();
    _loadCaterings();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _statusOf(Map<String, dynamic> catering) =>
      (catering['status'] ?? '').toString().trim().toLowerCase();

  bool _isWaitingStatus(String status) {
    const waiting = {
      'submitted',
      'pending',
      'online_inquiries',
      'online_inquiry',
      'new_event',
    };
    return waiting.contains(status);
  }

  bool _isCompletedStatus(String status) => status == 'completed';

  bool _isCancelledStatus(String status) => status == 'cancelled';

  bool _isRespondedStatus(String status) =>
      !_isWaitingStatus(status) &&
      !_isCompletedStatus(status) &&
      !_isCancelledStatus(status);

  bool _matchesTypeFilter(Map<String, dynamic> catering) {
    if (_typeFilter == 'all') return true;
    final type =
        (catering['inquiryType'] ??
                catering['inquiry_type'] ??
                catering['orderType'] ??
                catering['order_type'] ??
                '')
            .toString()
            .toUpperCase();
    final isEvent =
        type.contains('EVENT') ||
        type.contains('STYLING') ||
        type == 'CATERING_EVENT' ||
        type == 'CATERING+EVENT';
    if (_typeFilter == 'event_only') return isEvent;
    return !isEvent;
  }

  bool _matchesSearch(Map<String, dynamic> catering) {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return true;
    final hay =
        [
          catering['catering_id'],
          catering['cateringId'],
          catering['id'],
          catering['inquiryType'],
          catering['inquiry_type'],
          catering['event_title'],
          catering['eventTitle'],
          catering['status'],
        ].map((e) => (e ?? '').toString().toLowerCase()).join(' ');
    return hay.contains(q);
  }

  DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  String _formatDateYyyyMmDd(DateTime date) {
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    return '${date.year}-$mm-$dd';
  }

  DateTime? _cateringFilterDate(Map<String, dynamic> catering) {
    final slots = _parseDynamicList(
      catering['scheduleSlots'] ?? catering['schedule_slots'],
    );
    if (slots.isNotEmpty) {
      final first = slots.first;
      if (first is Map) {
        final dt = DateTime.tryParse((first['date'] ?? '').toString());
        if (dt != null) return _dateOnly(dt);
      }
    }
    for (final key in ['event_date', 'eventDate', 'date_of_event']) {
      final raw = (catering[key] ?? '').toString();
      if (raw.isEmpty) continue;
      final dt = DateTime.tryParse(raw);
      if (dt != null) return _dateOnly(dt);
    }
    final createdRaw =
        (catering['created_at'] ?? catering['createdAt'] ?? '').toString();
    final created = DateTime.tryParse(createdRaw);
    if (created != null) return _dateOnly(created);
    return null;
  }

  bool _matchesDateRange(Map<String, dynamic> catering) {
    if (_dateFrom == null && _dateTo == null) return true;
    final dt = _cateringFilterDate(catering);
    if (dt == null) return false;
    if (_dateFrom != null && dt.isBefore(_dateFrom!)) return false;
    if (_dateTo != null && dt.isAfter(_dateTo!)) return false;
    return true;
  }

  Future<void> _pickFilterDate({required bool isFrom}) async {
    final initial =
        (isFrom ? _dateFrom : _dateTo) ??
        _dateFrom ??
        _dateTo ??
        DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (selected == null || !mounted) return;
    final picked = _dateOnly(selected);
    setState(() {
      if (isFrom) {
        _dateFrom = picked;
        if (_dateTo != null && picked.isAfter(_dateTo!)) {
          _dateTo = picked;
        }
      } else {
        _dateTo = picked;
        if (_dateFrom != null && picked.isBefore(_dateFrom!)) {
          _dateFrom = picked;
        }
      }
    });
  }

  Widget _buildDateFilterChip({
    required String label,
    required DateTime? value,
    required VoidCallback onPick,
    required VoidCallback onClear,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        OutlinedButton(
          onPressed: onPick,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            visualDensity: VisualDensity.compact,
            side: BorderSide(color: Colors.grey.shade400),
          ),
          child: Text(
            value == null ? label : _formatDateYyyyMmDd(value),
            style: TextStyle(
              fontSize: 13,
              color: value == null ? Colors.grey.shade600 : null,
            ),
          ),
        ),
        if (value != null)
          IconButton(
            onPressed: onClear,
            icon: Icon(Icons.close, size: 16, color: Colors.grey.shade600),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            tooltip: 'Clear $label',
          ),
      ],
    );
  }

  bool _inPast30Days(Map<String, dynamic> catering) {
    final raw =
        (catering['updated_at'] ??
                catering['updatedAt'] ??
                catering['completed_at'] ??
                catering['created_at'] ??
                catering['createdAt'] ??
                '')
            .toString();
    final dt = DateTime.tryParse(raw);
    if (dt == null) return true;
    return dt.isAfter(DateTime.now().subtract(const Duration(days: 30)));
  }

  List<Map<String, dynamic>> _filteredForTab(int tabIndex) {
    final maps =
        _caterings
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .where(_matchesSearch)
            .where(_matchesTypeFilter)
            .where(_matchesDateRange)
            .toList();
    switch (tabIndex) {
      case 0:
        return maps.where((c) => _isWaitingStatus(_statusOf(c))).toList();
      case 1:
        return maps.where((c) => _isRespondedStatus(_statusOf(c))).toList();
      case 2:
        return maps
            .where((c) => _isCompletedStatus(_statusOf(c)) && _inPast30Days(c))
            .toList();
      case 3:
        return maps.where((c) => _isCancelledStatus(_statusOf(c))).toList();
      default:
        return maps;
    }
  }

  Future<void> _submitFollowUp(Map<String, dynamic> catering) async {
    final noteCtrl = TextEditingController();
    final ok = await showAntdModal<bool>(
      context: context,
      title: 'Follow up',
      body: TextField(
        controller: noteCtrl,
        maxLines: 4,
        decoration: const InputDecoration(
          hintText: 'Tell us how we can help with this inquiry',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        AntdCancelButton(
          label: 'Cancel',
          onPressed: () => Navigator.pop(context, false),
        ),
        AntdPrimaryButton(
          label: 'Send',
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    );
    final note = noteCtrl.text.trim();
    noteCtrl.dispose();
    if (ok != true || note.isEmpty || !mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('customer_data');
    String email = '';
    String name = '';
    try {
      if (raw != null) {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        email = (data['email'] ?? '').toString();
        name = (data['fullName'] ?? data['full_name'] ?? '').toString();
      }
    } catch (_) {}

    final ref =
        (catering['catering_id'] ??
                catering['cateringId'] ??
                catering['id'] ??
                '')
            .toString();
    try {
      final res = await http
          .post(
            Uri.parse('$_apiBaseUrl/api/public/help-requests'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'name': name.isEmpty ? 'Customer' : name,
              'email': email.isEmpty ? 'customer@unknown' : email,
              'message': 'Inquiry follow-up ($ref)\n\n$note',
            }),
          )
          .timeout(_requestTimeout);
      if (!mounted) return;
      if (res.statusCode >= 200 && res.statusCode < 300) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Follow-up sent to our team.')),
        );
      } else {
        throw Exception('HTTP ${res.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not send follow-up: $e')));
    }
  }

  Future<void> _loadCaterings({bool force = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('customer_token');

      if (token == null || token.isEmpty) {
        if (mounted) {
          Navigator.of(context).pop('login_required');
        }
        return;
      }

      if (!force) {
        final cached = CustomerOrdersCache.instance.peekEventOrders();
        if (cached != null) {
          if (mounted) {
            setState(() {
              _caterings = cached;
              _isLoading = false;
              _error = null;
            });
          }
          return;
        }
      }

      if (mounted) {
        setState(() {
          _isLoading = true;
          _error = null;
        });
      }

      // Fetch event orders for this customer (auth uses bearer token)
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
        CustomerOrdersCache.instance.setEventOrders([]);
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
      final list = data['orders'] ?? data['caterings'] ?? [];
      final asList = list is List ? List<dynamic>.from(list) : <dynamic>[];
      CustomerOrdersCache.instance.setEventOrders(asList);
      if (mounted) {
        setState(() {
          _caterings = asList;
          _isLoading = false;
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
          _error = 'Error loading caterings: $e';
          _isLoading = false;
        });
      }
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

  String _formatMenuForDisplay(List<dynamic> menuList) {
    if (menuList.isEmpty) return '—';
    final lines = <String>[];
    for (final item in menuList) {
      if (item is! Map) continue;
      final m = Map<String, dynamic>.from(item);
      final setName =
          (m['setMenuName'] ?? m['set_menu_name'] ?? '').toString().trim();
      final dish =
          (m['dishName'] ?? m['dish_name'] ?? m['name'] ?? 'Dish').toString();
      final pax = (m['paxOption'] ?? m['pax_option'] ?? '').toString();
      final price = _formatPeso(m['price']);
      final dishAllergens =
          (m['dishAllergens'] ?? m['dish_allergens'] ?? '').toString().trim();
      if (setName.isNotEmpty) lines.add('Set: $setName');
      var line = '  • $dish';
      if (pax.isNotEmpty) line += ' ($pax)';
      if (price != '—' && price != '₱0.00') line += ' $price';
      if (dishAllergens.isNotEmpty) line += ' · allergens: $dishAllergens';
      lines.add(line);
      final names = m['dishNames'] ?? m['dish_names'];
      if (names is List) {
        for (final n in names) {
          final name = n.toString().trim();
          if (name.isNotEmpty) lines.add('  • $name');
        }
      }
    }
    return lines.isEmpty ? '—' : lines.join('\n');
  }

  String _formatScheduleForDisplay(List<dynamic> slots) {
    if (slots.isEmpty) return '—';
    return slots
        .map((slot) {
          if (slot is! Map) return '';
          final s = Map<String, dynamic>.from(slot);
          final date = (s['date'] ?? '').toString();
          final start = (s['startTime'] ?? s['start_time'] ?? '').toString();
          final end = (s['endTime'] ?? s['end_time'] ?? '').toString();
          return '$date  $start–$end'.trim();
        })
        .where((s) => s.isNotEmpty)
        .join('\n');
  }

  List<AntdDescriptionItem> _cateringDescriptionItems(
    Map<String, dynamic> catering,
    String status,
  ) {
    final menuList = _parseDynamicList(catering['menu']);
    final slots = _parseDynamicList(
      catering['scheduleSlots'] ?? catering['schedule_slots'],
    );
    final w = MediaQuery.sizeOf(context).width;
    final cols = w < 700 ? 1 : 2;
    return [
      AntdDescriptionItem(label: 'Status', value: _formatStatus(status)),
      AntdDescriptionItem(
        label: 'Total cost',
        value: _displayTotalCost(catering),
      ),
      AntdDescriptionItem(
        label: 'Event type',
        value: _getEventTypeDisplay(
          catering['event_type'] ?? catering['eventType'],
        ),
      ),
      AntdDescriptionItem(
        label: 'Guests',
        value: '${catering['guest_count'] ?? catering['guestCount'] ?? '—'}',
      ),
      AntdDescriptionItem(
        label: 'Created',
        value: _formatDate(catering['created_at'] ?? catering['createdAt']),
      ),
      AntdDescriptionItem(
        label: 'Schedule',
        value: _formatScheduleForDisplay(slots),
        span: cols,
      ),
      AntdDescriptionItem(
        label: 'Menu',
        value: _formatMenuForDisplay(menuList),
        span: cols,
      ),
      AntdDescriptionItem(
        label: 'Allergens',
        value:
            (catering['allergens'] ?? '').toString().trim().isEmpty
                ? '—'
                : (catering['allergens'] ?? '').toString(),
        span: cols,
      ),
    ];
  }

  String _formatStatus(String? status) {
    if (status == null) return 'UNKNOWN';
    return status.replaceAll('_', ' ').toUpperCase();
  }

  bool _isEditableInquiryStatus(String? status) =>
      status == 'online_inquiries' ||
      status == 'new_event' ||
      status == 'online_inquiry';

  bool _canCancelInquiry(String? status) =>
      _isEditableInquiryStatus(status) ||
      status == 'for_down_payment' ||
      status == 'for_processing';

  bool _canEditVenueAndGuests(String? status) =>
      status == 'online_inquiries' ||
      status == 'new_event' ||
      status == 'online_inquiry' ||
      status == 'for_down_payment' ||
      status == 'on_going' ||
      status == 'for_processing' ||
      status == 'for_post_analysis';

  String _displayTotalCost(Map<String, dynamic> catering) {
    final total = catering['total_cost'] ?? catering['totalCost'];
    final estimated =
        catering['estimated_total'] ??
        catering['estimatedTotal'] ??
        catering['estimated_cost'] ??
        catering['estimatedCost'];
    final totalNum = total is num ? total.toDouble() : double.tryParse('$total');
    if (totalNum != null && totalNum > 0) return _formatPeso(totalNum);
    final estNum =
        estimated is num
            ? estimated.toDouble()
            : double.tryParse('$estimated');
    if (estNum != null && estNum > 0) return _formatPeso(estNum);
    return _formatPeso(total ?? estimated);
  }

  Widget _buildCostBreakdownView(Map<String, dynamic> themeDesign) {
    final breakdown =
        themeDesign['costBreakdown'] ?? themeDesign['cost_breakdown'];
    if (breakdown is Map) {
      final b = Map<String, dynamic>.from(breakdown);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Dish: ${_formatPeso(b['dishCost'] ?? b['dish_cost'])}'),
          Text('Labor: ${_formatPeso(b['laborCost'] ?? b['labor_cost'])}'),
          Text('Travel: ${_formatPeso(b['travelCost'] ?? b['travel_cost'])}'),
        ],
      );
    }
    if (breakdown is List && breakdown.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final raw in breakdown)
            if (raw is Map)
              Text(
                '${raw['label'] ?? 'Item'}: ${_formatPeso(raw['amount'])}'
                '${raw['detail'] != null ? ' (${raw['detail']})' : ''}',
              ),
        ],
      );
    }
    return Text('—', style: TextStyle(color: Colors.grey.shade700));
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'online_inquiries':
      case 'new_event':
        return Colors.blue;
      case 'for_down_payment':
        return Colors.amber;
      case 'on_going':
      case 'for_processing':
        return Colors.orange;
      case 'for_full_payment':
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

  bool _hasFeedbackSubmitted(Map<String, dynamic> catering) {
    return catering['feedback_submitted'] == true ||
        catering['feedbackSubmitted'] == true ||
        catering['feedback_stars'] != null;
  }

  bool _canReviewCatering(Map<String, dynamic> catering) {
    final status = (catering['status'] ?? '').toString().toLowerCase();
    return status == 'completed' && !_hasFeedbackSubmitted(catering);
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
    if (rawThemeDesign is Map) return Map<String, dynamic>.from(rawThemeDesign);
    if (rawThemeDesign is String && rawThemeDesign.isNotEmpty) {
      try {
        final parsed = jsonDecode(rawThemeDesign);
        if (parsed is Map<String, dynamic>) return parsed;
        if (parsed is Map) return Map<String, dynamic>.from(parsed);
      } catch (_) {}
    }
    return {};
  }

  bool _hasManagerEstimateUpdate(Map<String, dynamic> themeDesign) {
    final notice = themeDesign['managerUpdateNotice'];
    if (notice is! Map) return false;
    final m = Map<String, dynamic>.from(notice);
    if (m['estimateUpdated'] == true) return true;
    if ((m['action'] ?? '').toString() == 'post_changes') return true;
    return false;
  }

  String? _managerUpdateMessage(Map<String, dynamic> themeDesign) {
    final notice = themeDesign['managerUpdateNotice'];
    if (notice is! Map) return null;
    final msg = (notice['message'] ?? '').toString().trim();
    if (msg.isNotEmpty) return msg;
    if (_hasManagerEstimateUpdate(themeDesign)) {
      return 'Macrina posted an updated cost estimate. Open this inquiry to review labor, travel, and total.';
    }
    return null;
  }

  Widget? _buildEstimateUpdateBanner(Map<String, dynamic> themeDesign) {
    if (!_hasManagerEstimateUpdate(themeDesign)) return null;
    final message =
        _managerUpdateMessage(themeDesign) ??
        'Macrina posted an updated cost estimate. Review the breakdown below.';
    final breakdown = themeDesign['costBreakdown'];
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF81C784)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.price_change_outlined,
                color: Colors.green.shade800,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Updated cost estimate',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: TextStyle(fontSize: 12, color: Colors.green.shade900),
          ),
          if (breakdown is Map) ...[
            const SizedBox(height: 8),
            Text(
              'Labor: ${_formatPeso(breakdown['laborCost'])} · Travel: ${_formatPeso(breakdown['travelCost'])}',
              style: TextStyle(fontSize: 12, color: Colors.green.shade800),
            ),
          ],
        ],
      ),
    );
  }

  bool _hasEventThemeDesign(Map<String, dynamic> themeDesign) {
    if (themeDesign.isEmpty) return false;
    if (themeDesign['serviceType'] == 'catering' &&
        themeDesign['eventDesignSource'] == null) {
      return false;
    }
    final src = (themeDesign['eventDesignSource'] ?? '').toString();
    if (src == 'macrina' || src == 'customer_ai') return true;
    if (themeDesign['wantsCustomDesign'] == true) return true;
    if ((themeDesign['generatedImageUrl'] ?? '').toString().trim().isNotEmpty) {
      return true;
    }
    if ((themeDesign['venuePhotoBase64'] ?? '').toString().trim().isNotEmpty) {
      return true;
    }
    if ((themeDesign['macrinaColorPalette'] ?? '')
        .toString()
        .trim()
        .isNotEmpty) {
      return true;
    }
    if ((themeDesign['macrinaTheme'] ?? '').toString().trim().isNotEmpty) {
      return true;
    }
    if ((themeDesign['style'] ?? '').toString().trim().isNotEmpty) return true;
    if ((themeDesign['mood'] ?? '').toString().trim().isNotEmpty) return true;
    final colors = themeDesign['colorPalette'];
    if (colors is List && colors.isNotEmpty) return true;
    final decor = themeDesign['decorElements'];
    if (decor is List && decor.isNotEmpty) return true;
    if ((themeDesign['customInstructions'] ?? '')
        .toString()
        .trim()
        .isNotEmpty) {
      return true;
    }
    return false;
  }

  String _eventDesignSourceLabel(Map<String, dynamic> themeDesign) {
    final src = (themeDesign['eventDesignSource'] ?? '').toString();
    if (src == 'macrina') return 'Macrina\'s will design your event';
    if (src == 'customer_ai') return 'Your AI event design';
    if (themeDesign['wantsCustomDesign'] == true) return 'Custom event design';
    return 'Event theme design';
  }

  void _openThemeImageZoom(BuildContext context, Widget image) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder:
          (ctx) => Dialog(
            insetPadding: const EdgeInsets.all(16),
            backgroundColor: Colors.black,
            child: Stack(
              children: [
                Positioned.fill(
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 5,
                    child: Center(child: image),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  Widget? _buildThemeImagePreview(
    BuildContext context,
    Map<String, dynamic> themeDesign, {
    double height = 160,
  }) {
    final url = RunPodService.proxyImageUrlIfNeeded(
      (themeDesign['generatedImageUrl'] ?? '').toString(),
    );
    if (url.isNotEmpty) {
      final img = Image.network(
        url,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder:
            (_, __, ___) => Container(
              height: height,
              color: Colors.grey.shade200,
              child: const Center(child: Icon(Icons.broken_image_outlined)),
            ),
      );
      return InkWell(
        onTap:
            () => _openThemeImageZoom(
              context,
              Image.network(url, fit: BoxFit.contain),
            ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            children: [
              img,
              Positioned(
                right: 8,
                bottom: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.zoom_in, color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      Text(
                        'Tap to zoom',
                        style: TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final venueB64 = (themeDesign['venuePhotoBase64'] ?? '').toString().trim();
    if (venueB64.isEmpty) return null;
    try {
      final bytes = base64Decode(
        venueB64.startsWith('data:') ? venueB64.split(',').last : venueB64,
      );
      final mem = Image.memory(
        bytes,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
      );
      return InkWell(
        onTap:
            () => _openThemeImageZoom(
              context,
              Image.memory(bytes, fit: BoxFit.contain),
            ),
        child: ClipRRect(borderRadius: BorderRadius.circular(8), child: mem),
      );
    } catch (_) {
      return null;
    }
  }

  List<Widget> _buildEventThemeDesignSection(
    BuildContext context,
    Map<String, dynamic> themeDesign,
  ) {
    if (!_hasEventThemeDesign(themeDesign)) return const [];

    final lines = <String>[];
    void add(String label, dynamic value) {
      if (value == null) return;
      if (value is List) {
        if (value.isEmpty) return;
        lines.add('$label: ${value.join(', ')}');
        return;
      }
      final s = value.toString().trim();
      if (s.isNotEmpty) lines.add('$label: $s');
    }

    add('Design type', _eventDesignSourceLabel(themeDesign));
    add('Event type', themeDesign['eventDesignEventType']);
    add('Style', themeDesign['style']);
    add('Mood', themeDesign['mood']);
    add('Colors', themeDesign['colorPalette']);
    add('Decor', themeDesign['decorElements']);
    add('Macrina palette', themeDesign['macrinaColorPalette']);
    add('Macrina theme', themeDesign['macrinaTheme']);
    add('Notes', themeDesign['customInstructions']);

    return [
      const SizedBox(height: 12),
      const Text(
        'Event theme design',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 6),
      if (lines.isNotEmpty) ...lines.map((l) => Text('- $l')),
      if (_buildThemeImagePreview(context, themeDesign) != null) ...[
        const SizedBox(height: 10),
        _buildThemeImagePreview(context, themeDesign)!,
      ],
      if ((themeDesign['generatedImageUrl'] ?? '').toString().trim().isEmpty &&
          (themeDesign['venuePhotoBase64'] ?? '').toString().trim().isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            'Venue reference photo from your inquiry',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ),
    ];
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

  String _formatPeso(dynamic value) {
    final n = num.tryParse((value ?? '').toString()) ?? 0;
    return 'PHP ${n.toStringAsFixed(2)}';
  }

  Future<void> _respondToInquiry({
    required String orderId,
    required String action, // confirm_inquiry | cancel_inquiry
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('customer_token');
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
      throw Exception('Failed to update inquiry (${response.statusCode})');
    }
  }

  Future<void> _editInquiry({
    required String orderId,
    required int guestCount,
    required String address,
    List<Map<String, dynamic>>? scheduleSlots,
    List<Map<String, dynamic>>? menu,
    bool venueOnly = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('customer_token');
    if (token == null || token.isEmpty) return;

    final response = await http.patch(
      Uri.parse('$_apiBaseUrl/api/customer/events/orders/$orderId/edit'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'guestCount': guestCount,
        'address': address,
        if (venueOnly) 'venueOnly': true,
        if (!venueOnly) ...{'scheduleSlots': scheduleSlots, 'menu': menu},
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to edit inquiry (${response.statusCode})');
    }
  }

  Map<String, String> _extractPrimarySlot(List<dynamic> slots) {
    if (slots.isEmpty) {
      return {'date': '', 'startTime': '', 'endTime': ''};
    }
    final first = slots.first;
    if (first is! Map) {
      return {'date': '', 'startTime': '', 'endTime': ''};
    }
    final s = Map<String, dynamic>.from(first);
    return {
      'date': (s['date'] ?? '').toString(),
      'startTime': (s['startTime'] ?? s['start_time'] ?? '').toString(),
      'endTime': (s['endTime'] ?? s['end_time'] ?? '').toString(),
    };
  }

  Future<void> _showEditCateringDialog(Map<String, dynamic> catering) async {
    final status = (catering['status'] ?? '').toString();
    if (!_canEditVenueAndGuests(status)) {
      if (mounted) {
        showAppSnackBar(context, 'This order can no longer be edited.');
      }
      return;
    }

    final venueGuestsOnly = !_isEditableInquiryStatus(status);

    if (venueGuestsOnly) {
      final guestCtrl = TextEditingController(
        text: '${catering['guest_count'] ?? catering['guestCount'] ?? ''}',
      );
      final venueCtrl = TextEditingController(
        text: (catering['address'] ?? '').toString(),
      );
      await showAntdModal<void>(
        context: context,
        title: 'Update venue & guests',
        maxWidth: 480,
        body: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: guestCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Number of guests',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: venueCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Event venue / address',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          AntdCancelButton(
            label: 'Cancel',
            onPressed: () => Navigator.of(context).pop(),
          ),
          AntdPrimaryButton(
            label: 'Save',
            onPressed: () async {
              final guestCount = int.tryParse(guestCtrl.text.trim()) ?? 0;
              final venue = venueCtrl.text.trim();
              if (guestCount <= 0 || venue.isEmpty) return;
              try {
                await _editInquiry(
                  orderId: catering['id'].toString(),
                  guestCount: guestCount,
                  address: venue,
                  venueOnly: true,
                );
                if (!mounted) return;
                Navigator.of(context).pop();
                await _loadCaterings(force: true);
                if (!mounted) return;
                showAppSnackBar(
                  context,
                  'Event details updated.',
                  icon: Icons.check_circle_outline,
                );
              } catch (e) {
                if (!mounted) return;
                showAppSnackBar(context, 'Update failed: $e', error: true);
              }
            },
          ),
        ],
      );
      guestCtrl.dispose();
      venueCtrl.dispose();
      return;
    }

    await MenuStore.instance.loadDishes();
    await SetMenuStore.instance.loadSetMenus();

    List<Map<String, dynamic>> buildPresetMenusList() {
      final dishById = {for (final d in MenuStore.instance.allDishes) d.id: d};
      final fromApi =
          SetMenuStore.instance.activeSetMenus
              .map((sm) {
                final names =
                    sm.dishIds
                        .map((id) => dishById[id]?.name ?? '')
                        .where((n) => n.isNotEmpty)
                        .toList();
                return <String, dynamic>{
                  'id': sm.id,
                  'name': sm.name,
                  'dishes': names,
                };
              })
              .where((m) => (m['dishes'] as List).isNotEmpty)
              .toList();
      if (fromApi.isNotEmpty) return fromApi;
      return [
        {
          'id': 'filipino_feast',
          'name': 'Filipino Feast',
          'dishes': ['Bistek', 'Sinigang', 'Lechon Kawali', 'Kare-Kare'],
        },
        {
          'id': 'classic_party',
          'name': 'Classic Party Set',
          'dishes': ['Bistek', 'Sinigang', 'Lechon Kawali'],
        },
        {
          'id': 'light_refreshments',
          'name': 'Light Refreshments',
          'dishes': ['Vegetable Salad', 'Shrimp Croquette', 'Lemon Iced Tea'],
        },
      ];
    }

    final presetMenus = buildPresetMenusList();

    final slots = _parseDynamicList(
      catering['scheduleSlots'] ?? catering['schedule_slots'],
    );
    final primarySlot = _extractPrimarySlot(slots);
    final menuList = _parseDynamicList(catering['menu']);
    final initialDishNames =
        menuList
            .map((item) {
              if (item is! Map) return '';
              final m = Map<String, dynamic>.from(item);
              return (m['dishName'] ?? m['dish_name'] ?? m['name'] ?? '')
                  .toString()
                  .trim();
            })
            .where((name) => name.isNotEmpty)
            .toList();

    final guestCtrl = TextEditingController(
      text:
          (catering['guestCount'] ?? catering['guest_count'] ?? '').toString(),
    );
    final venueCtrl = TextEditingController(
      text: (catering['address'] ?? '').toString(),
    );
    final dateCtrl = TextEditingController(text: primarySlot['date'] ?? '');
    final startCtrl = TextEditingController(
      text: primarySlot['startTime'] ?? '',
    );
    final endCtrl = TextEditingController(text: primarySlot['endTime'] ?? '');
    final editableDishes = List<String>.from(initialDishNames);
    String menuSelectionType = 'custom';
    String? selectedPresetMenuId;
    for (final preset in presetMenus) {
      final dishes =
          (preset['dishes'] as List<dynamic>)
              .map((e) => e.toString().toLowerCase())
              .toSet();
      final existing = editableDishes.map((e) => e.toLowerCase()).toSet();
      if (existing.isNotEmpty &&
          dishes.length == existing.length &&
          dishes.difference(existing).isEmpty) {
        menuSelectionType = 'preset';
        selectedPresetMenuId = preset['id'].toString();
        break;
      }
    }
    bool isSubmitting = false;

    TimeOfDay? parseTime(String value) {
      final parts = value.split(':');
      if (parts.length < 2) return null;
      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      if (hour == null || minute == null) return null;
      if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
      return TimeOfDay(hour: hour, minute: minute);
    }

    String formatTime(TimeOfDay time) {
      final h = time.hour.toString().padLeft(2, '0');
      final m = time.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }

    final cateringPickDishes =
        MenuStore.instance.activeDishes
            .where((d) => d.category.trim().toLowerCase() == 'catering')
            .toList()
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );

    await showAntdModal<void>(
      context: context,
      title: 'Edit catering inquiry',
      maxWidth: 760,
      body: StatefulBuilder(
        builder: (dialogContext, setLocalState) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: guestCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Guest Count',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: venueCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Venue / Address',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: dateCtrl,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Event Date',
                        border: OutlineInputBorder(),
                      ),
                      onTap: () async {
                        final now = DateTime.now();
                        final selected = await showDatePicker(
                          context: context,
                          initialDate: now,
                          firstDate: now.subtract(const Duration(days: 1)),
                          lastDate: now.add(const Duration(days: 3650)),
                        );
                        if (selected != null) {
                          dateCtrl.text =
                              '${selected.year}-${selected.month.toString().padLeft(2, '0')}-${selected.day.toString().padLeft(2, '0')}';
                          setLocalState(() {});
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: startCtrl,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Start Time',
                        border: OutlineInputBorder(),
                      ),
                      onTap: () async {
                        final initial =
                            parseTime(startCtrl.text) ??
                            const TimeOfDay(hour: 9, minute: 0);
                        final selected = await showTimePicker(
                          context: context,
                          initialTime: initial,
                        );
                        if (selected != null) {
                          startCtrl.text = formatTime(selected);
                          setLocalState(() {});
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: endCtrl,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'End Time',
                        border: OutlineInputBorder(),
                      ),
                      onTap: () async {
                        final initial =
                            parseTime(endCtrl.text) ??
                            const TimeOfDay(hour: 12, minute: 0);
                        final selected = await showTimePicker(
                          context: context,
                          initialTime: initial,
                        );
                        if (selected != null) {
                          endCtrl.text = formatTime(selected);
                          setLocalState(() {});
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'Requested Dishes',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Custom Menu'),
                    selected: menuSelectionType == 'custom',
                    onSelected: (_) {
                      setLocalState(() {
                        menuSelectionType = 'custom';
                      });
                    },
                  ),
                  ChoiceChip(
                    label: const Text('Catering Set Menu'),
                    selected: menuSelectionType == 'preset',
                    onSelected: (_) {
                      setLocalState(() {
                        menuSelectionType = 'preset';
                        selectedPresetMenuId ??=
                            presetMenus.isNotEmpty
                                ? presetMenus.first['id'].toString()
                                : null;
                        if (selectedPresetMenuId != null) {
                          final selectedPreset = presetMenus.firstWhere(
                            (m) => m['id'].toString() == selectedPresetMenuId,
                            orElse: () => presetMenus.first,
                          );
                          editableDishes
                            ..clear()
                            ..addAll(
                              (selectedPreset['dishes'] as List<dynamic>).map(
                                (e) => e.toString(),
                              ),
                            );
                        }
                      });
                    },
                  ),
                ],
              ),
              if (menuSelectionType == 'preset') ...[
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: selectedPresetMenuId,
                  decoration: const InputDecoration(
                    labelText: 'Select Catering Menu',
                    border: OutlineInputBorder(),
                  ),
                  items:
                      presetMenus
                          .map(
                            (menu) => DropdownMenuItem<String>(
                              value: menu['id'].toString(),
                              child: Text(menu['name'].toString()),
                            ),
                          )
                          .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setLocalState(() {
                      selectedPresetMenuId = value;
                      final selectedPreset = presetMenus.firstWhere(
                        (m) => m['id'].toString() == value,
                        orElse: () => presetMenus.first,
                      );
                      editableDishes
                        ..clear()
                        ..addAll(
                          (selectedPreset['dishes'] as List<dynamic>).map(
                            (e) => e.toString(),
                          ),
                        );
                    });
                  },
                ),
              ],
              const SizedBox(height: 8),
              if (menuSelectionType == 'custom') ...[
                Text(
                  'Tap dishes from your catering menu to include them.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 240),
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children:
                          cateringPickDishes.map((d) {
                            final sel = editableDishes.contains(d.name);
                            return FilterChip(
                              label: Text(
                                d.name,
                                style: const TextStyle(fontSize: 12),
                              ),
                              selected: sel,
                              onSelected: (on) {
                                setLocalState(() {
                                  if (on) {
                                    if (!editableDishes.contains(d.name)) {
                                      editableDishes.add(d.name);
                                    }
                                  } else {
                                    editableDishes.remove(d.name);
                                  }
                                });
                              },
                            );
                          }).toList(),
                    ),
                  ),
                ),
              ] else ...[
                Text(
                  'Choose a set menu below; dishes match your inquiry page catalog.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ],
              const SizedBox(height: 10),
              if (editableDishes.isEmpty)
                Text(
                  'No dishes yet. Add at least one dish.',
                  style: TextStyle(color: Colors.grey.shade600),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(editableDishes.length, (i) {
                    return Chip(
                      label: Text(editableDishes[i]),
                      onDeleted: () {
                        setLocalState(() {
                          editableDishes.removeAt(i);
                        });
                      },
                    );
                  }),
                ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  AntdCancelButton(
                    label: 'Cancel',
                    onPressed:
                        isSubmitting
                            ? null
                            : () => Navigator.of(dialogContext).pop(),
                  ),
                  AntdPrimaryButton(
                    label: 'Save changes',
                    loading: isSubmitting,
                    onPressed:
                        isSubmitting
                            ? null
                            : () async {
                              final guestCount =
                                  int.tryParse(guestCtrl.text.trim()) ?? 0;
                              final venue = venueCtrl.text.trim();
                              final date = dateCtrl.text.trim();
                              final start = startCtrl.text.trim();
                              final end = endCtrl.text.trim();
                              if (guestCount <= 0 ||
                                  venue.isEmpty ||
                                  date.isEmpty ||
                                  start.isEmpty ||
                                  end.isEmpty ||
                                  editableDishes.isEmpty) {
                                showAppSnackBar(
                                  context,
                                  'Please complete all required fields.',
                                  error: true,
                                  icon: Icons.warning_amber_rounded,
                                );
                                return;
                              }

                              setLocalState(() => isSubmitting = true);
                              try {
                                await _editInquiry(
                                  orderId: catering['id'].toString(),
                                  guestCount: guestCount,
                                  address: venue,
                                  scheduleSlots: [
                                    {
                                      'date': date,
                                      'startTime': start,
                                      'endTime': end,
                                    },
                                  ],
                                  menu:
                                      editableDishes
                                          .map((dish) => {'dishName': dish})
                                          .toList(),
                                );
                                if (!mounted) return;
                                Navigator.of(dialogContext).pop();
                                await _loadCaterings(force: true);
                                if (!mounted) return;
                                showAppSnackBar(
                                  context,
                                  'Inquiry updated successfully.',
                                  icon: Icons.check_circle_outline,
                                );
                              } catch (e) {
                                if (!mounted) return;
                                setLocalState(() => isSubmitting = false);
                                showAppSnackBar(
                                  context,
                                  'Update failed: $e',
                                  error: true,
                                );
                              }
                            },
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    guestCtrl.dispose();
    venueCtrl.dispose();
    dateCtrl.dispose();
    startCtrl.dispose();
    endCtrl.dispose();
  }

  Future<void> _showCustomerSeatingEditor(
    String orderId,
    SeatingPlanData initial,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('customer_token');
    if (token == null || token.isEmpty) return;

    var plan = initial;

    await showAntdModal<void>(
      context: context,
      title: 'Edit seat labels',
      maxWidth: 800,
      barrierDismissible: false,
      body: StatefulBuilder(
        builder: (modalContext, setSt) {
          return SeatingPlanInteractive(
            plan: plan,
            editable: true,
            layoutEditable: false,
            onChanged: (p) => setSt(() => plan = p),
          );
        },
      ),
      actions: [
        AntdCancelButton(
          label: 'Cancel',
          onPressed: () => Navigator.of(context).pop(),
        ),
        AntdPrimaryButton(
          label: 'Save',
          onPressed: () async {
            try {
              final uri = Uri.parse(
                '$_apiBaseUrl/api/customer/events/orders/$orderId/seating',
              );
              var res = await http.post(
                uri,
                headers: {
                  'Authorization': 'Bearer $token',
                  'Content-Type': 'application/json',
                },
                body: jsonEncode({'seatingPlan': plan.toJson()}),
              );
              if (res.statusCode == 404 || res.statusCode == 405) {
                res = await http.put(
                  uri,
                  headers: {
                    'Authorization': 'Bearer $token',
                    'Content-Type': 'application/json',
                  },
                  body: jsonEncode({'seatingPlan': plan.toJson()}),
                );
              }
              if (res.statusCode != 200) {
                throw Exception(
                  res.body.isNotEmpty ? res.body : 'HTTP ${res.statusCode}',
                );
              }
              if (!context.mounted) return;
              Navigator.of(context).pop();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Seating layout saved.'),
                    backgroundColor: Color(0xFF1DB954),
                  ),
                );
              }
            } catch (e) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Save failed: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
        ),
      ],
    );
  }

  Future<void> _showCateringDetailsDialog(Map<String, dynamic> catering) async {
    final status = (catering['status'] ?? '').toString();
    final isInquiry = _isEditableInquiryStatus(status);
    final themeDesign = _parseThemeDesign(
      catering['themeDesign'] ?? catering['theme_design'],
    );
    final orderType =
        (catering['order_type'] ?? catering['orderType'] ?? '').toString();
    final eventTitle =
        (catering['event_title'] ?? catering['eventTitle'] ?? '').toString();
    final isEventOrder = isCateringPlusEventOrderType(
      orderType,
      eventTitle: eventTitle,
    );
    final seatingPlan = SeatingPlanData.fromJson(
      catering['seatingPlan'] ?? catering['seating_plan'],
    );
    final showSeatingBlock =
        isEventOrder &&
        (status == 'for_processing' ||
            status == 'for_post_analysis' ||
            status == 'ongoing');

    final title =
        (catering['event_title'] ?? catering['eventTitle'] ?? 'Catering')
            .toString();
    final w = MediaQuery.sizeOf(context).width;

    await showAntdModal<void>(
      context: context,
      title: title,
      maxWidth: 800,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AntdDescriptions(
            column: w < 700 ? 1 : 2,
            labelColor: Colors.grey.shade600,
            valueColor: Colors.black87,
            items: _cateringDescriptionItems(catering, status),
          ),
          ..._buildEventThemeDesignSection(context, themeDesign),
          const SizedBox(height: 12),
          const Text(
            'Cost breakdown',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          const SizedBox(height: 6),
          _buildCostBreakdownView(themeDesign),
          if ((themeDesign['customerNote'] ?? themeDesign['note'] ?? '')
              .toString()
              .trim()
              .isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Notes',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 6),
            Text(
              (themeDesign['customerNote'] ?? themeDesign['note']).toString(),
            ),
          ],
          if (_buildEstimateUpdateBanner(themeDesign) != null)
            _buildEstimateUpdateBanner(themeDesign)!,
          if (themeDesign['managerUpdateNotice'] is Map &&
              !_hasManagerEstimateUpdate(themeDesign)) ...[
            const SizedBox(height: 12),
            const Text(
              'Manager notes',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 6),
            Text(
              (themeDesign['managerUpdateNotice']['message'] ??
                      'Your inquiry was updated.')
                  .toString(),
            ),
          ],
          if (showSeatingBlock) ...[
            const SizedBox(height: 16),
            const Text(
              'Seating layout',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 8),
            if (seatingPlan.isEffectivelyEmpty)
              Text(
                'No seating layout has been set yet.',
                style: TextStyle(color: Colors.grey.shade600),
              )
            else
              SeatingPlanInteractive(plan: seatingPlan, editable: false),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () async {
                Navigator.of(context).pop();
                await _showCustomerSeatingEditor(
                  catering['id'].toString(),
                  seatingPlan,
                );
                if (mounted) await _loadCaterings(force: true);
              },
              icon: const Icon(Icons.edit_location_alt_outlined, size: 18),
              label: const Text('Edit seating layout'),
            ),
          ],
        ],
      ),
      actions: [
        if (_hasFeedbackSubmitted(catering))
          OutlinedButton.icon(
            onPressed: null,
            icon: const Icon(Icons.check_circle_outline, size: 18),
            label: const Text('Feedback submitted'),
          ),
        if (_canReviewCatering(catering))
          OutlinedButton.icon(
            onPressed: () async {
              Navigator.of(context).pop();
              await _submitCateringFeedback(catering);
            },
            icon: const Icon(Icons.rate_review_outlined, size: 18),
            label: const Text('Leave feedback'),
          ),
        if (isInquiry)
          OutlinedButton.icon(
            onPressed: () async {
              Navigator.of(context).pop();
              await _submitFollowUp(catering);
            },
            icon: const Icon(Icons.support_agent_outlined, size: 18),
            label: const Text('Follow up'),
          ),
        if (isInquiry)
          OutlinedButton.icon(
            onPressed: () async {
              Navigator.of(context).pop();
              await _showEditCateringDialog(catering);
            },
            icon: const Icon(Icons.edit, size: 18),
            label: const Text('Edit inquiry'),
          ),
        if (_canCancelInquiry(status))
          AntdCancelButton(
            label: 'Cancel inquiry',
            onPressed: () async {
              try {
                await _respondToInquiry(
                  orderId: catering['id'].toString(),
                  action: 'cancel_inquiry',
                );
                if (!mounted) return;
                Navigator.of(context).pop();
                await _loadCaterings(force: true);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Inquiry cancelled.')),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Cancel failed: $e')));
              }
            },
          ),
        AntdCancelButton(
          label: 'Close',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Future<void> _submitCateringFeedback(Map<String, dynamic> catering) async {
    final orderId = catering['id']?.toString();
    if (orderId == null || orderId.isEmpty) return;
    final title =
        (catering['event_title'] ?? catering['eventTitle'] ?? 'Catering')
            .toString();
    final result = await showCustomerOrderFeedbackDialog(
      context,
      title: 'Feedback · $title',
      question: 'How was this catering experience?',
    );
    if (result == null || !mounted) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('customer_token');
      if (token == null || token.isEmpty) {
        throw Exception('Please log in again');
      }
      final response = await http
          .post(
            Uri.parse(
              '$_apiBaseUrl/api/customer/events/orders/${Uri.encodeComponent(orderId)}/feedback',
            ),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'stars': result.stars,
              'remarks': result.remarks,
            }),
          )
          .timeout(_requestTimeout);
      final data = response.body.isNotEmpty ? jsonDecode(response.body) : {};
      if (response.statusCode != 200) {
        throw Exception(
          data is Map
              ? data['error'] ?? 'Failed to submit feedback'
              : 'Failed to submit feedback',
        );
      }
      final updated = data is Map ? data['order'] : null;
      setState(() {
        _caterings =
            _caterings.map((entry) {
              if (entry is! Map) return entry;
              final current = Map<String, dynamic>.from(entry);
              if (current['id']?.toString() != orderId) return entry;
              return updated is Map
                  ? Map<String, dynamic>.from(updated)
                  : {
                    ...current,
                    'feedback_stars': result.stars,
                    'feedback_remarks': result.remarks,
                    'feedback_submitted': true,
                  };
            }).toList();
      });
      CustomerOrdersCache.instance.setEventOrders(_caterings);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thank you for your feedback.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  Widget _buildCateringGridTile(Map<String, dynamic> catering) {
    final status = (catering['status'] ?? 'online_inquiries').toString();
    final title =
        catering['event_title'] ?? catering['eventTitle'] ?? 'Catering';
    final themeDesign = _parseThemeDesign(
      catering['themeDesign'] ?? catering['theme_design'],
    );
    final designPreview = _buildThemeImagePreview(
      context,
      themeDesign,
      height: 100,
    );
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _showCateringDetailsDialog(catering),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (designPreview != null) ...[
                designPreview,
                const SizedBox(height: 8),
              ],
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                orderTypeDisplayLabel(
                  (catering['order_type'] ?? catering['orderType'] ?? '')
                      .toString(),
                  eventTitle: title.toString(),
                ),
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
              if (_hasEventThemeDesign(themeDesign)) ...[
                const SizedBox(height: 4),
                Text(
                  _eventDesignSourceLabel(themeDesign),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
              const Spacer(),
              Text(
                _formatStatus(status),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _getStatusColor(status),
                ),
              ),
              if (_hasFeedbackSubmitted(catering)) ...[
                const SizedBox(height: 6),
                const Text(
                  'Feedback submitted',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1B5E20),
                  ),
                ),
              ] else if (_canReviewCatering(catering)) ...[
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => _submitCateringFeedback(catering),
                    icon: const Icon(Icons.rate_review_outlined, size: 16),
                    label: const Text('Leave feedback'),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
              ],
              Builder(
                builder: (_) {
                  final display = _displayTotalCost(catering);
                  if (display == '—' || display == '₱0.00') {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      display,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFF4511E),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateFromTopBar(CustomerPageTab tab) {
    if (tab == CustomerPageTab.caterings) return;
    final route = switch (tab) {
      CustomerPageTab.home => const CustomerWebsiteScreen(),
      CustomerPageTab.profile => const MyProfilePage(),
      CustomerPageTab.orders => const MyOrdersPage(),
      CustomerPageTab.tracking => const MyOrderTrackingPage(),
      CustomerPageTab.caterings => const MyCateringsPage(),
    };
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => route));
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
            icon: Icon(_gridView ? Icons.view_list : Icons.grid_view),
            tooltip: _gridView ? 'List view' : 'Grid view',
            onPressed: () => setState(() => _gridView = !_gridView),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadCaterings(force: true),
            tooltip: 'Refresh caterings',
          ),
        ],
      ),
      body: CustomerAccountShell(
        currentTab: CustomerPageTab.caterings,
        body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final entry in const [
                      (0, 'WAITING'),
                      (1, 'RESPONDED'),
                      (2, 'COMPLETED'),
                      (3, 'CANCELLED'),
                    ])
                      FilterChip(
                        label: Text(entry.$2),
                        selected: _statusChipIndex == entry.$1,
                        onSelected: (_) =>
                            setState(() => _statusChipIndex = entry.$1),
                        selectedColor: const Color(0xFFFFC024),
                        checkmarkColor: const Color(0xFF1E1E1E),
                        labelStyle: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _statusChipIndex == entry.$1
                              ? const Color(0xFF1E1E1E)
                              : Colors.grey.shade800,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Search by ref, type, title, status',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: _typeFilter,
                      items: const [
                        DropdownMenuItem(
                          value: 'all',
                          child: Text('All types'),
                        ),
                        DropdownMenuItem(
                          value: 'catering_only',
                          child: Text('Catering'),
                        ),
                        DropdownMenuItem(
                          value: 'event_only',
                          child: Text('Event styling'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => _typeFilter = v);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _buildDateFilterChip(
                      label: 'From',
                      value: _dateFrom,
                      onPick: () => _pickFilterDate(isFrom: true),
                      onClear: () => setState(() => _dateFrom = null),
                    ),
                    _buildDateFilterChip(
                      label: 'To',
                      value: _dateTo,
                      onPick: () => _pickFilterDate(isFrom: false),
                      onClear: () => setState(() => _dateTo = null),
                    ),
                    if (_dateFrom != null || _dateTo != null)
                      TextButton(
                        onPressed:
                            () => setState(() {
                              _dateFrom = null;
                              _dateTo = null;
                            }),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        child: const Text('Clear dates'),
                      ),
                  ],
                ),
              ],
            ),
          ),
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
                            onPressed: () => _loadCaterings(force: true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E1E1E),
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                    : Builder(
                      builder: (context) {
                        final items = _filteredForTab(_statusChipIndex);
                        if (items.isEmpty) {
                          return Center(
                            child: Text(
                              _statusChipIndex == 2
                                  ? 'No completed caterings in the past 30 days'
                                  : 'No caterings for this status',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          );
                        }
                        if (_gridView) {
                          return LayoutBuilder(
                            builder: (context, c) {
                              final cross =
                                  c.maxWidth >= 900
                                      ? 3
                                      : c.maxWidth >= 520
                                      ? 2
                                      : 1;
                              return GridView.builder(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  12,
                                  16,
                                  16,
                                ),
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: cross,
                                      mainAxisSpacing: 12,
                                      crossAxisSpacing: 12,
                                      childAspectRatio:
                                          cross == 1 ? 1.4 : 0.95,
                                    ),
                                itemCount: items.length,
                                itemBuilder: (context, index) {
                                  return _buildCateringGridTile(items[index]);
                                },
                              );
                            },
                          );
                        }
                        return ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            return _buildInquiryListTile(items[index]);
                          },
                        );
                      },
                    ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildInquiryListTile(Map<String, dynamic> catering) {
    final status = _statusOf(catering);
    final title =
        (catering['event_title'] ?? catering['eventTitle'] ?? 'Catering')
            .toString();
    final ref =
        (catering['catering_id'] ??
                catering['cateringId'] ??
                catering['id'] ??
                '')
            .toString();
    final waiting = _isWaitingStatus(status);
    final completed = _isCompletedStatus(status);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: () => _showCateringDetailsDialog(catering),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
          [
            if (ref.isNotEmpty) 'Ref: $ref',
            _formatStatus(status),
            orderTypeDisplayLabel(
              (catering['order_type'] ?? catering['orderType'] ?? '').toString(),
              eventTitle: title,
            ),
          ].join(' \u00b7 '),
        ),
        trailing: Wrap(
          spacing: 4,
          children: [
            if (waiting)
              IconButton(
                tooltip: 'Follow up',
                icon: const Icon(Icons.support_agent_outlined),
                onPressed: () => _submitFollowUp(catering),
              ),
            if (completed && !_hasFeedbackSubmitted(catering))
              IconButton(
                tooltip: 'Leave feedback',
                icon: const Icon(Icons.rate_review_outlined),
                onPressed: () => _submitCateringFeedback(catering),
              ),
            Icon(Icons.chevron_right, color: _getStatusColor(status)),
          ],
        ),
      ),
    );
  }
}
