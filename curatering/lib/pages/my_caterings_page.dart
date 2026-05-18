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
import '../services/set_menu_store.dart';
import '../widgets/app_snackbar.dart';
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
  static const Duration _requestTimeout = Duration(seconds: 45);

  String get _apiBaseUrl {
    return apiBaseUrl;
  }

  @override
  void initState() {
    super.initState();
    _loadCaterings();
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
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: const Text('Session Expired'),
            content: const Text(
              'Your session has expired. Please log in again.',
            ),
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

  bool _isEditableInquiryStatus(String? status) =>
      status == 'online_inquiries' || status == 'new_event';

  bool _canEditVenueAndGuests(String? status) =>
      status == 'online_inquiries' ||
      status == 'new_event' ||
      status == 'for_down_payment' ||
      status == 'on_going' ||
      status == 'for_processing' ||
      status == 'for_post_analysis';

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
              Icon(Icons.price_change_outlined, color: Colors.green.shade800, size: 20),
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
          Text(message, style: TextStyle(fontSize: 12, color: Colors.green.shade900)),
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
    if ((themeDesign['macrinaColorPalette'] ?? '').toString().trim().isNotEmpty) {
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
    if ((themeDesign['customInstructions'] ?? '').toString().trim().isNotEmpty) {
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
      builder: (ctx) => Dialog(
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
    final url = (themeDesign['generatedImageUrl'] ?? '').toString().trim();
    if (url.isNotEmpty) {
      final img = Image.network(
        url,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          height: height,
          color: Colors.grey.shade200,
          child: const Center(child: Icon(Icons.broken_image_outlined)),
        ),
      );
      return InkWell(
        onTap: () => _openThemeImageZoom(
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
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
      final mem = Image.memory(bytes, height: height, width: double.infinity, fit: BoxFit.cover);
      return InkWell(
        onTap: () => _openThemeImageZoom(
          context,
          Image.memory(bytes, fit: BoxFit.contain),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: mem,
        ),
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
        if (!venueOnly) ...{
          'scheduleSlots': scheduleSlots,
          'menu': menu,
        },
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
        showAppSnackBar(
          context,
          'This order can no longer be edited.',
        );
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
      await showDialog<void>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: const Text('Update venue & guests'),
            content: SizedBox(
              width: 420,
              child: Column(
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
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
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
                    Navigator.of(ctx).pop();
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
                child: const Text('Save'),
              ),
            ],
          );
        },
      );
      guestCtrl.dispose();
      venueCtrl.dispose();
      return;
    }

    await MenuStore.instance.loadDishes();
    await SetMenuStore.instance.loadSetMenus();

    List<Map<String, dynamic>> buildPresetMenusList() {
      final dishById = {
        for (final d in MenuStore.instance.allDishes) d.id: d,
      };
      final fromApi =
          SetMenuStore.instance.activeSetMenus.map((sm) {
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
          }).where((m) => (m['dishes'] as List).isNotEmpty).toList();
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

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              title: const Text('Edit Catering Inquiry'),
              content: SizedBox(
                width: 760,
                child: SingleChildScrollView(
                  child: Column(
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
                                  firstDate: now.subtract(
                                    const Duration(days: 1),
                                  ),
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
                                    (m) =>
                                        m['id'].toString() ==
                                        selectedPresetMenuId,
                                    orElse: () => presetMenus.first,
                                  );
                                  editableDishes
                                    ..clear()
                                    ..addAll(
                                      (selectedPreset['dishes']
                                              as List<dynamic>)
                                          .map((e) => e.toString()),
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
                                  (selectedPreset['dishes'] as List<dynamic>)
                                      .map((e) => e.toString()),
                                );
                            });
                          },
                        ),
                      ],
                      const SizedBox(height: 8),
                      if (menuSelectionType == 'custom') ...[
                        Text(
                          'Tap dishes from your catering menu to include them.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
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
                                    final sel = editableDishes.contains(
                                      d.name,
                                    );
                                    return FilterChip(
                                      label: Text(
                                        d.name,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      selected: sel,
                                      onSelected: (on) {
                                        setLocalState(() {
                                          if (on) {
                                            if (!editableDishes.contains(
                                              d.name,
                                            )) {
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
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
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
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      isSubmitting ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
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
                              Navigator.of(context).pop();
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E1E1E),
                    foregroundColor: Colors.white,
                  ),
                  child:
                      isSubmitting
                          ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                          : const Text('Save Changes'),
                ),
              ],
            );
          },
        );
      },
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

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setSt) {
            return AlertDialog(
              title: const Text('Edit seat labels'),
              content: SizedBox(
                width: 760,
                child: SingleChildScrollView(
                  child: SeatingPlanInteractive(
                    plan: plan,
                    editable: true,
                    layoutEditable: false,
                    onChanged: (p) => setSt(() => plan = p),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
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
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                      }
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Seating layout saved.'),
                            backgroundColor: Color(0xFF1DB954),
                          ),
                        );
                      }
                    } catch (e) {
                      if (dialogContext.mounted) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(
                            content: Text('Save failed: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showCateringDetailsDialog(Map<String, dynamic> catering) async {
    final status = (catering['status'] ?? '').toString();
    final isInquiry = _isEditableInquiryStatus(status);
    final themeDesign = _parseThemeDesign(
      catering['themeDesign'] ?? catering['theme_design'],
    );
    final menuList = _parseDynamicList(catering['menu']);
    final slots = _parseDynamicList(
      catering['scheduleSlots'] ?? catering['schedule_slots'],
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

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            catering['event_title'] ??
                catering['eventTitle'] ??
                'Catering Details',
          ),
          content: SizedBox(
            width: 720,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Status: ${_formatStatus(status)}'),
                  const SizedBox(height: 8),
                  Text(
                    'Total Cost: ${_formatPeso(catering['total_cost'] ?? catering['totalCost'])}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFF4511E),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Event Type: ${_getEventTypeDisplay(catering['event_type'] ?? catering['eventType'])}',
                  ),
                  Text(
                    'Guests: ${(catering['guest_count'] ?? catering['guestCount'] ?? 'N/A')}',
                  ),
                  Text(
                    'Created: ${_formatDate(catering['created_at'] ?? catering['createdAt'])}',
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Schedule',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  if (slots.isEmpty)
                    const Text('- No schedule provided')
                  else
                    ...slots.map((slot) {
                      final s =
                          slot is Map
                              ? Map<String, dynamic>.from(slot)
                              : <String, dynamic>{};
                      final date = (s['date'] ?? '').toString();
                      final start =
                          (s['startTime'] ?? s['start_time'] ?? '').toString();
                      final end =
                          (s['endTime'] ?? s['end_time'] ?? '').toString();
                      return Text('- $date  $start - $end');
                    }),
                  const SizedBox(height: 12),
                  const Text(
                    'Menu',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  if (menuList.isEmpty)
                    const Text('- No menu provided')
                  else
                    ...menuList.map((item) {
                      final m =
                          item is Map
                              ? Map<String, dynamic>.from(item)
                              : <String, dynamic>{};
                      final dish =
                          (m['dishName'] ?? m['dish_name'] ?? 'Dish')
                              .toString();
                      final pax =
                          (m['paxOption'] ?? m['pax_option'] ?? '').toString();
                      final price = _formatPeso(m['price']);
                      return Text(
                        '- $dish ${pax.isEmpty ? '' : '($pax)'}  $price',
                      );
                    }),
                  ..._buildEventThemeDesignSection(context, themeDesign),
                  const SizedBox(height: 12),
                  const Text(
                    'Cost Breakdown',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Builder(
                    builder: (_) {
                      final breakdown = themeDesign['costBreakdown'];
                      if (breakdown is! Map)
                        return const Text('- No breakdown available');
                      final b = Map<String, dynamic>.from(breakdown);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('- Dish Cost: ${_formatPeso(b['dishCost'])}'),
                          Text('- Labor Cost: ${_formatPeso(b['laborCost'])}'),
                          Text(
                            '- Travel Cost: ${_formatPeso(b['travelCost'])}',
                          ),
                        ],
                      );
                    },
                  ),
                  if (_buildEstimateUpdateBanner(themeDesign) != null)
                    _buildEstimateUpdateBanner(themeDesign)!,
                  if (themeDesign['managerUpdateNotice'] is Map &&
                      !_hasManagerEstimateUpdate(themeDesign)) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Manager Notes',
                      style: TextStyle(fontWeight: FontWeight.w700),
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
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    if (seatingPlan.isEffectivelyEmpty)
                      Text(
                        'No seating layout has been set yet.',
                        style: TextStyle(color: Colors.grey.shade600),
                      )
                    else
                      SeatingPlanInteractive(
                        plan: seatingPlan,
                        editable: false,
                      ),
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
            ),
          ),
          actions: [
            if (isInquiry)
              OutlinedButton.icon(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await _showEditCateringDialog(catering);
                },
                icon: const Icon(Icons.edit),
                label: const Text('Edit Inquiry'),
              ),
            if (isInquiry)
              TextButton(
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
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Cancel failed: $e')),
                    );
                  }
                },
                child: const Text('Cancel Inquiry'),
              ),
            if (isInquiry)
              ElevatedButton(
                onPressed: () async {
                  try {
                    await _respondToInquiry(
                      orderId: catering['id'].toString(),
                      action: 'confirm_inquiry',
                    );
                    if (!mounted) return;
                    Navigator.of(context).pop();
                    await _loadCaterings(force: true);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Order confirmed.')),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Confirm failed: $e')),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1DB954),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Confirm Order'),
              ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
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
              if (catering['total_cost'] != null ||
                  catering['totalCost'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '₱${catering['total_cost'] ?? catering['totalCost']}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFF4511E),
                    ),
                  ),
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
      body: Column(
        children: [
          CustomerPagesTopBar(
            currentTab: CustomerPageTab.caterings,
            onTabSelected: _navigateFromTopBar,
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
                            onPressed: () => _loadCaterings(force: true),
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
                    : _gridView
                    ? LayoutBuilder(
                      builder: (context, c) {
                        final cross =
                            c.maxWidth >= 900
                                ? 3
                                : c.maxWidth >= 520
                                ? 2
                                : 1;
                        return GridView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: cross,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                childAspectRatio: cross == 1 ? 1.4 : 0.95,
                              ),
                          itemCount: _caterings.length,
                          itemBuilder: (context, index) {
                            final raw = _caterings[index];
                            if (raw is! Map) return const SizedBox.shrink();
                            return _buildCateringGridTile(
                              Map<String, dynamic>.from(raw),
                            );
                          },
                        );
                      },
                    )
                    : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      itemCount: _caterings.length,
                      itemBuilder: (context, index) {
                        final catering = _caterings[index];
                        final status = catering['status'] ?? 'online_inquiries';
                        final isCurrent =
                            status != 'completed' && status != 'cancelled';
                        final themeDesign = _parseThemeDesign(
                          catering['themeDesign'] ?? catering['theme_design'],
                        );
                        final managerNotice =
                            themeDesign['managerUpdateNotice'];
                        final hasPreferenceChangeNotice =
                            managerNotice is Map &&
                            (managerNotice['preferencesChanged'] == true ||
                                managerNotice['estimateUpdated'] == true ||
                                (managerNotice['action'] ?? '').toString() ==
                                    'post_changes');

                        return InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => _showCateringDetailsDialog(catering),
                          child: Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(
                                color: Colors.black.withOpacity(0.08),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          catering['event_title'] ??
                                              catering['eventTitle'] ??
                                              'Untitled Event',
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
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
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
                                              _managerUpdateMessage(themeDesign) ??
                                              'Macrina posted updates. Please review your latest estimate in My Caterings.',
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
                                        _getEventTypeDisplay(
                                          catering['event_type'] ??
                                              catering['eventType'],
                                        ),
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
                                        _formatDate(
                                          catering['created_at'] ??
                                              catering['createdAt'],
                                        ),
                                        style: TextStyle(
                                          color: Colors.grey.shade700,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (catering['guest_count'] != null ||
                                      catering['guestCount'] != null) ...[
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
                                  if (_hasEventThemeDesign(themeDesign)) ...[
                                    const SizedBox(height: 12),
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (_buildThemeImagePreview(
                                              context,
                                              themeDesign,
                                              height: 72,
                                            ) !=
                                            null) ...[
                                          SizedBox(
                                            width: 96,
                                            child: _buildThemeImagePreview(
                                              context,
                                              themeDesign,
                                              height: 72,
                                            )!,
                                          ),
                                          const SizedBox(width: 12),
                                        ],
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Event theme design',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.grey.shade800,
                                                  fontSize: 13,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                _eventDesignSourceLabel(
                                                  themeDesign,
                                                ),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                              if ((themeDesign['style'] ?? '')
                                                  .toString()
                                                  .isNotEmpty)
                                                Text(
                                                  'Style: ${themeDesign['style']}',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  const Divider(height: 24),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Chip(
                                        label: Text(
                                          _formatStatus(status),
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: Colors.white,
                                          ),
                                        ),
                                        backgroundColor: _getStatusColor(
                                          status,
                                        ),
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
                                  if (_buildEstimateUpdateBanner(themeDesign) != null)
                                    _buildEstimateUpdateBanner(themeDesign)!,
                                  if (status == 'online_inquiries' &&
                                      !_hasManagerEstimateUpdate(themeDesign)) ...[
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
                                      child: const Text(
                                        'Your inquiry is being reviewed. You will see labor, travel, and total estimates here when Macrina posts them.',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF0D47A1),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
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
