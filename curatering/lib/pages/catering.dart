import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth/auth_session.dart';
import '../auth/roles.dart';
import '../models/event_order.dart';
import '../models/menu_dish.dart';
import '../services/events_api.dart';
import '../services/menu_store.dart';
import '../widgets/app_scaffold.dart';
import '../utils/order_calculations.dart';
import '../utils/web_html.dart' as html;

// SAM Integration imports (would be added when SAM is integrated)
// import 'package:segment_anything/segment_anything.dart';

// Data structures for SAM integration
class SegmentedObject {
  final String id;
  final Uint8List mask;
  final String label;
  final Rect boundingBox;
  final Color? currentColor;

  SegmentedObject({
    required this.id,
    required this.mask,
    required this.label,
    required this.boundingBox,
    this.currentColor,
  });
}

class SamSegmentationResult {
  final List<SegmentedObject> objects;
  final Uint8List originalImage;

  SamSegmentationResult({required this.objects, required this.originalImage});
}

class ChecklistItem {
  ChecklistItem({
    required this.item,
    required this.description,
    required this.quantity,
    required this.cost,
    this.isCompleted = false,
  });

  final String item;
  final String description;
  final int quantity;
  final double cost;
  bool isCompleted;
}

enum EventStatus {
  newEvent,
  onlineInquiries,
  forProcessing,
  forPostAnalysis,
  completed,
}

enum PaymentConfirmationMode { downpayment, fullPayment }

class MenuItem {
  final MenuDish dish;
  final String paxOption;

  MenuItem({required this.dish, required this.paxOption});
}

class ManageEvents extends StatefulWidget {
  const ManageEvents({super.key});

  @override
  State<ManageEvents> createState() => _ManageEventsState();
}

class ProcessingOrder {
  final String company;
  final String contactName;
  final String contactNumber;
  final DateTime date;
  final String time;

  ProcessingOrder({
    required this.company,
    required this.contactName,
    required this.contactNumber,
    required this.date,
    required this.time,
  });
}

enum EventFormalityLevel { casual, semiFormal, formal }

extension EventFormalityLevelX on EventFormalityLevel {
  String get displayName {
    return switch (this) {
      EventFormalityLevel.casual => 'Casual',
      EventFormalityLevel.semiFormal => 'Semi-formal',
      EventFormalityLevel.formal => 'Formal',
    };
  }
}

class EventScheduleSlot {
  final DateTime date;
  final TimeOfDay startTime;
  final TimeOfDay endTime;

  const EventScheduleSlot({
    required this.date,
    required this.startTime,
    required this.endTime,
  });

  String label(BuildContext context) {
    String pad2(int n) => n.toString().padLeft(2, '0');
    final start = '${pad2(startTime.hour)}:${pad2(startTime.minute)}';
    final end = '${pad2(endTime.hour)}:${pad2(endTime.minute)}';
    return '${date.month}/${date.day}/${date.year} ($start - $end)';
  }
}

class _ThemeTemplate {
  final String id;
  final String label;
  final List<String> eventTypes;
  final Uint8List imageBytes;

  const _ThemeTemplate({
    required this.id,
    required this.label,
    required this.eventTypes,
    required this.imageBytes,
  });
}

class _ManageEventsState extends State<ManageEvents>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  final TextEditingController _eventSearchController = TextEditingController();
  final TextEditingController _inquirySearchController =
      TextEditingController();
  final TextEditingController _foodSearchController = TextEditingController();
  final TextEditingController _eventTitleController = TextEditingController();
  final TextEditingController _customerController = TextEditingController();
  final TextEditingController _contactPersonController =
      TextEditingController();
  final TextEditingController _contactNumberController =
      TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _eventAddressController = TextEditingController();
  final TextEditingController _guestCountController = TextEditingController();

  final TextEditingController _postCardsController = TextEditingController();
  final TextEditingController _postInquiriesController =
      TextEditingController();
  final TextEditingController _postComplaintsController =
      TextEditingController();

  bool _postAnalysisSaving = false;

  EventStatus _selectedStatus = EventStatus.newEvent;
  String? _eventType;
  EventFormalityLevel? _formalityLevel;
  final List<EventScheduleSlot> _eventScheduleSlots = [];

  bool _ordersLoading = false;
  List<EventOrderDto> _onlineInquiryOrders = const <EventOrderDto>[];
  List<EventOrderDto> _processingOrdersDto = const <EventOrderDto>[];
  List<EventOrderDto> _postAnalysisOrdersDto = const <EventOrderDto>[];
  List<EventOrderDto> _completedOrdersDto = const <EventOrderDto>[];
  List<EventOrderDto> _newEventOrdersDto = const <EventOrderDto>[];
  EventOrderDto? _selectedOnlineInquiryOrder;

  @override
  void initState() {
    super.initState();
    // Keep the food browser in sync with the shared in-memory menu.
    _allDishes = MenuStore.instance.activeDishes;
    MenuStore.instance.addListener(_onMenuStoreChanged);
    _tabController =
        TabController(
          length: EventStatus.values.length,
          vsync: this,
          initialIndex: _selectedStatus.index,
        )..addListener(() {
          if (!_tabController.indexIsChanging) return;
          final newStatus = EventStatus.values[_tabController.index];
          setState(() {
            _selectedStatus = newStatus;
            if (newStatus != EventStatus.forProcessing) {
              _selectedProcessingOrderDto = null;
            }
            if (newStatus != EventStatus.forPostAnalysis) {
              _selectedPostAnalysisOrderDto = null;
            }
            if (newStatus != EventStatus.completed) {
              _selectedCompletedOrderDto = null;
            }
          });
        });

    _loadThemeTemplates();
    _refreshOrders();
  }

  @override
  void dispose() {
    _tabController.dispose();
    MenuStore.instance.removeListener(_onMenuStoreChanged);
    _eventSearchController.dispose();
    _inquirySearchController.dispose();
    _foodSearchController.dispose();
    _eventTitleController.dispose();
    _customerController.dispose();
    _contactPersonController.dispose();
    _contactNumberController.dispose();
    _emailController.dispose();
    _eventAddressController.dispose();
    _guestCountController.dispose();
    _postCardsController.dispose();
    _postInquiriesController.dispose();
    _postComplaintsController.dispose();
    _themeColorPromptController.dispose();
    _paymentReferenceController.dispose();
    super.dispose();
  }

  void _onMenuStoreChanged() {
    if (!mounted) return;
    setState(() {
      _allDishes = MenuStore.instance.activeDishes;
    });
  }

  EventOrderDto? _selectedProcessingOrderDto;

  EventOrderDto? _selectedPostAnalysisOrderDto;

  EventOrderDto? _selectedCompletedOrderDto;

  final List<Uint8List> _themeDesignImages = [];
  List<_ThemeTemplate> _themeTemplates = const [];
  final List<Uint8List> _themePicks = [];
  final Set<int> _themePickHashes = <int>{};
  List<Uint8List> _collageOrder = const [];
  bool _themeTintEnabled = false;
  Color _themeTintColor = const Color(0xFFF4511E);
  bool _isAiProcessingTheme = false;
  final TextEditingController _themeColorPromptController =
      TextEditingController();
  final TextEditingController _paymentReferenceController =
      TextEditingController();
  bool _paymentDialogLoading = false;
  PaymentConfirmationMode _selectedPaymentMode =
      PaymentConfirmationMode.downpayment;

  // SAM Integration variables
  SamSegmentationResult? _currentSegmentationResult;
  final Set<String> _selectedObjectIds = <String>{};
  bool _isSegmenting = false;
  bool _showSegmentationOverlay = false;
  bool _segmentationSuccess = false;

  final List<MenuItem> _menuItems = [];
  final Map<String, String> _selectedPaxPerDish = {};
  List<MenuDish> _allDishes = MenuStore.instance.activeDishes;

  static const _eventTypes = [
    'Wedding',
    'Birthday',
    'Corporate',
    'Private Party',
    'Other',
  ];

  List<MenuDish> get _filteredDishes {
    final query = _foodSearchController.text.trim().toLowerCase();
    if (query.isEmpty) return _allDishes;
    return _allDishes
        .where((d) => d.name.toLowerCase().contains(query))
        .toList();
  }

  void _resetForm() {
    setState(() {
      _eventTitleController.clear();
      _customerController.clear();
      _contactPersonController.clear();
      _contactNumberController.clear();
      _emailController.clear();
      _eventAddressController.clear();
      _guestCountController.clear();
      _eventType = null;
      _formalityLevel = null;
      _eventScheduleSlots.clear();
      _menuItems.clear();
      _selectedPaxPerDish.clear();
      _selectedProcessingOrderDto = null;
      _selectedPostAnalysisOrderDto = null;
      _selectedCompletedOrderDto = null;
      _themeDesignImages.clear();
      _themePicks.clear();
      _themePickHashes.clear();
      _collageOrder = const [];
      _themeTintEnabled = false;
      _themeTintColor = const Color(0xFFF4511E);
      _themeColorPromptController.clear();
      _selectedStatus = EventStatus.newEvent;
      _eventSearchController.clear();
      _foodSearchController.clear();
    });
  }

  void _addToMenu(MenuDish dish) {
    final selectedPax = _selectedPaxPerDish[dish.name] ?? dish.paxOptions.first;
    final existingIndex = _menuItems.indexWhere(
      (item) => item.dish.name == dish.name && item.paxOption == selectedPax,
    );
    if (existingIndex != -1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This item is already in your menu.')),
      );
      return;
    }

    setState(() {
      _menuItems.add(MenuItem(dish: dish, paxOption: selectedPax));
    });
  }

  void _removeFromMenu(MenuItem item) {
    setState(() {
      _menuItems.remove(item);
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 2)),
    );
    if (pickedDate == null) return;
    if (!mounted) return;

    final start = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
    );
    if (start == null) return;
    if (!mounted) return;

    final end = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: min(start.hour + 2, 23),
        minute: start.minute,
      ),
    );
    if (end == null) return;

    setState(() {
      _eventScheduleSlots.add(
        EventScheduleSlot(date: pickedDate, startTime: start, endTime: end),
      );
    });
  }

  Future<void> _loadThemeTemplates() async {
    // Prototype templates (replace with real “company theme” assets later).
    final raw = <_ThemeTemplate>[
      _ThemeTemplate(
        id: 'tpl_wedding',
        label: 'Wedding Night',
        eventTypes: const ['Wedding'],
        imageBytes: Uint8List(0), // replaced below
      ),
      _ThemeTemplate(
        id: 'tpl_birthday',
        label: 'Birthday Glow',
        eventTypes: const ['Birthday'],
        imageBytes: Uint8List(0), // replaced below
      ),
      _ThemeTemplate(
        id: 'tpl_corporate',
        label: 'Corporate Elegance',
        eventTypes: const ['Corporate', 'Private Party'],
        imageBytes: Uint8List(0), // replaced below
      ),
      _ThemeTemplate(
        id: 'tpl_private',
        label: 'Private Celebration',
        eventTypes: const ['Private Party', 'Other'],
        imageBytes: Uint8List(0), // replaced below
      ),
    ];

    final loadMap = <String, String>{
      'tpl_wedding': 'lib/assets/login-1.png',
      'tpl_birthday': 'lib/assets/login-2.png',
      'tpl_corporate': 'lib/assets/main.png',
      'tpl_private': 'lib/assets/main-2.png',
    };

    final templates = <_ThemeTemplate>[];
    for (final t in raw) {
      final assetPath = loadMap[t.id];
      if (assetPath == null) continue;
      final bytes = (await rootBundle.load(assetPath)).buffer.asUint8List();
      templates.add(
        _ThemeTemplate(
          id: t.id,
          label: t.label,
          eventTypes: t.eventTypes,
          imageBytes: bytes,
        ),
      );
    }

    if (!mounted) return;
    setState(() => _themeTemplates = templates);
  }

  Future<void> _refreshOrders() async {
    if (_ordersLoading) return;
    setState(() {
      _ordersLoading = true;
    });

    try {
      final role = AuthSession.instance.currentRole;
      if (role == null) {
        _onlineInquiryOrders = const <EventOrderDto>[];
        _processingOrdersDto = const <EventOrderDto>[];
        _postAnalysisOrdersDto = const <EventOrderDto>[];
        _completedOrdersDto = const <EventOrderDto>[];
        _newEventOrdersDto = const <EventOrderDto>[];
        _selectedOnlineInquiryOrder = null;
        return;
      }

      if (role == Role.supervisor) {
        _processingOrdersDto = await EventsApi.instance.listOrders(
          status: 'for_processing',
          roleType: 'supervisor',
        );
        _newEventOrdersDto = await EventsApi.instance.listOrders(
          status: 'new_event',
          roleType: 'supervisor',
        );
        // Add new events to processing orders
        _processingOrdersDto = [..._processingOrdersDto, ..._newEventOrdersDto];
        _onlineInquiryOrders = const <EventOrderDto>[];
        _selectedOnlineInquiryOrder = null;

        _postAnalysisOrdersDto = await EventsApi.instance.listOrders(
          status: 'for_post_analysis',
          roleType: 'supervisor',
        );
        _completedOrdersDto = await EventsApi.instance.listOrders(
          status: 'completed',
          roleType: 'supervisor',
        );
        _newEventOrdersDto = await EventsApi.instance.listOrders(
          status: 'new_event',
          roleType: 'supervisor',
        );
      } else if (role == Role.manager || role == Role.admin) {
        _onlineInquiryOrders = await EventsApi.instance.listOrders(
          status: 'online_inquiries',
          roleType: 'manager',
        );
        _processingOrdersDto = await EventsApi.instance.listOrders(
          status: 'for_processing',
          roleType: 'manager',
        );
        _newEventOrdersDto = await EventsApi.instance.listOrders(
          status: 'new_event',
          roleType: 'manager',
        );
        // Add new events to processing orders
        _processingOrdersDto = [..._processingOrdersDto, ..._newEventOrdersDto];

        _postAnalysisOrdersDto = await EventsApi.instance.listOrders(
          status: 'for_post_analysis',
          roleType: 'manager',
        );
        _completedOrdersDto = await EventsApi.instance.listOrders(
          status: 'completed',
          roleType: 'manager',
        );
        _newEventOrdersDto = await EventsApi.instance.listOrders(
          status: 'new_event',
          roleType: 'manager',
        );
      } else {
        _onlineInquiryOrders = const <EventOrderDto>[];
        _processingOrdersDto = const <EventOrderDto>[];
        _postAnalysisOrdersDto = const <EventOrderDto>[];
        _completedOrdersDto = const <EventOrderDto>[];
        _newEventOrdersDto = const <EventOrderDto>[];
        _selectedOnlineInquiryOrder = null;
      }
    } catch (e) {
      _onlineInquiryOrders = const <EventOrderDto>[];
      _processingOrdersDto = const <EventOrderDto>[];
      _postAnalysisOrdersDto = const <EventOrderDto>[];
      _completedOrdersDto = const <EventOrderDto>[];
      _newEventOrdersDto = const <EventOrderDto>[];
      _selectedOnlineInquiryOrder = null;
    } finally {
      if (mounted) {
        setState(() => _ordersLoading = false);
      }
    }
  }

  String _hhmmFromTimeOfDay(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  TimeOfDay _timeOfDayFromHhmm(String raw) {
    final parts = raw.split(':');
    if (parts.length != 2) return const TimeOfDay(hour: 0, minute: 0);
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    return TimeOfDay(hour: h.clamp(0, 23), minute: m.clamp(0, 59));
  }

  EventFormalityLevel? _formalityFromString(String raw) {
    final v = raw.trim().toLowerCase();
    if (v == 'casual') return EventFormalityLevel.casual;
    if (v == 'semi_formal' || v == 'semi-formal' || v == 'semiformal') {
      return EventFormalityLevel.semiFormal;
    }
    if (v == 'formal') return EventFormalityLevel.formal;
    return null;
  }

  String _formalityToString(EventFormalityLevel level) {
    return switch (level) {
      EventFormalityLevel.casual => 'casual',
      EventFormalityLevel.semiFormal => 'semi_formal',
      EventFormalityLevel.formal => 'formal',
    };
  }

  String _themeTintColorHex(Color c) {
    final rgb = c.value & 0xFFFFFF;
    return '#${rgb.toRadixString(16).padLeft(6, '0')}';
  }

  ProcessingOrder _orderToProcessingOrderSummary(EventOrderDto order) {
    final firstSlot = order.scheduleSlots.isNotEmpty
        ? order.scheduleSlots.first
        : null;
    final date = firstSlot == null
        ? DateTime.now()
        : DateTime.parse(firstSlot.date);
    final timeLabel = firstSlot == null
        ? ''
        : '${firstSlot.startTime} - ${firstSlot.endTime}';
    return ProcessingOrder(
      company: order.customerName,
      contactName: order.contactPerson,
      contactNumber: order.contactNumber,
      date: date,
      time: timeLabel,
    );
  }

  void _syncPostAnalysisFields(EventOrderDto? dto) {
    if (dto == null) {
      _postCardsController.clear();
      _postInquiriesController.clear();
      _postComplaintsController.clear();
      return;
    }
    final pa = dto.postAnalysis;
    _postCardsController.text = pa == null
        ? ''
        : '${pa.businessCardsGivenAway}';
    _postInquiriesController.text = pa == null
        ? ''
        : '${pa.onTheSpotInquiries}';
    _postComplaintsController.text = pa == null ? '' : '${pa.complaints}';
  }

  List<EventOrderDto> _filterEventOrdersBySearch(List<EventOrderDto> orders) {
    final q = _eventSearchController.text.trim().toLowerCase();
    if (q.isEmpty) return orders;
    return orders.where((o) {
      final hay =
          '${o.customerName} ${o.contactPerson} ${o.contactNumber} ${o.eventTitle}'
              .toLowerCase();
      return hay.contains(q);
    }).toList();
  }

  void _applyOrderToForm(EventOrderDto order) {
    setState(() {
      _eventTitleController.text = order.eventTitle;
      _eventType = order.eventType;
      _formalityLevel = _formalityFromString(order.formalityLevel);

      _customerController.text = order.customerName;
      _contactPersonController.text = order.contactPerson;
      _contactNumberController.text = order.contactNumber;
      _emailController.text = order.emailAddress;

      _eventScheduleSlots
        ..clear()
        ..addAll(
          order.scheduleSlots.map((s) {
            return EventScheduleSlot(
              date: DateTime.parse(s.date),
              startTime: _timeOfDayFromHhmm(s.startTime),
              endTime: _timeOfDayFromHhmm(s.endTime),
            );
          }),
        );

      _eventAddressController.text = order.address;
      _guestCountController.text = order.guestCount.toString();

      _menuItems
        ..clear()
        ..addAll(
          order.menu.map((m) {
            final paxOptions = [m.paxOption];
            final dish = MenuDish(
              id: 'import_${m.dishName}',
              name: m.dishName,
              price: m.price,
              paxOptions: paxOptions,
              archived: false,
            );
            return MenuItem(dish: dish, paxOption: m.paxOption);
          }),
        );

      _themePicks
        ..clear()
        ..addAll(order.themeDesign.picksBase64.map((b64) => base64Decode(b64)));
      _themePickHashes
        ..clear()
        ..addAll(_themePicks.map((bytes) => _themeImageKey(bytes)));

      _themeTintEnabled = order.themeDesign.tintEnabled;
      _themeTintColor = order.themeDesign.tintColorHex == null
          ? _themeTintColor
          : Color(
              int.parse(
                    order.themeDesign.tintColorHex!.replaceAll('#', ''),
                    radix: 16,
                  ) +
                  0xFF000000,
            );
      _themeColorPromptController.text = order.themeDesign.colorPrompt ?? '';
      _collageOrder = _themePicks.toList();
    });
  }

  Map<String, dynamic> _buildPayloadFromForm() {
    final guestCount = int.tryParse(_guestCountController.text.trim());
    return {
      'eventTitle': _eventTitleController.text.trim(),
      'eventType': _eventType,
      'formalityLevel': _formalityLevel == null
          ? null
          : _formalityToString(_formalityLevel!),
      'customerName': _customerController.text.trim(),
      'contactPerson': _contactPersonController.text.trim(),
      'contactNumber': _contactNumberController.text.trim(),
      'emailAddress': _emailController.text.trim(),
      'scheduleSlots': _eventScheduleSlots.map((slot) {
        return {
          'date':
              '${slot.date.year.toString().padLeft(4, '0')}-${slot.date.month.toString().padLeft(2, '0')}-${slot.date.day.toString().padLeft(2, '0')}',
          'startTime': _hhmmFromTimeOfDay(slot.startTime),
          'endTime': _hhmmFromTimeOfDay(slot.endTime),
        };
      }).toList(),
      'address': _eventAddressController.text.trim(),
      'guestCount': guestCount,
      'menu': _menuItems.map((i) {
        return {
          'dishName': i.dish.name,
          'paxOption': i.paxOption,
          'price': i.dish.price,
        };
      }).toList(),
      'themeDesign': {
        'picksBase64': _themePicks.map((b) => base64Encode(b)).toList(),
        'tintEnabled': _themeTintEnabled,
        'tintColorHex': _themeTintEnabled
            ? _themeTintColorHex(_themeTintColor)
            : null,
        'colorPrompt': _themeColorPromptController.text.trim(),
      },
    };
  }

  Future<void> _openFinalizeOnlineInquiryDialog(EventOrderDto order) async {
    _applyOrderToForm(order);

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Text('Finalize Online Inquiry'),
          content: SizedBox(
            width: 980,
            height: 640,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildEventForm(),
                  const SizedBox(height: 16),
                  _buildMenuSection(),
                  const SizedBox(height: 16),
                  Text(
                    'Menu editing is simplified in this prototype.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade400,
                          ),
                          child: const Text('CANCEL'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            try {
                              final payload = _buildPayloadFromForm();
                              await EventsApi.instance
                                  .managerFinalizeOnlineInquiry(
                                    orderId: order.id,
                                    payload: payload,
                                  );
                              if (!mounted) return;
                              Navigator.of(context).pop();
                              await _refreshOrders();
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Order moved to For Processing.',
                                  ),
                                ),
                              );
                            } catch (e) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Failed to finalize order.'),
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1DB954),
                          ),
                          child: const Text('FINALIZE & SUBMIT'),
                        ),
                      ),
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

  // Theme Design Image Pick
  int _themeImageKey(Uint8List bytes) {
    var hash = 0;
    for (final b in bytes) {
      hash = ((hash * 31) + b) & 0x7fffffff;
    }
    return hash;
  }

  void _toggleThemePick(Uint8List bytes) {
    final key = _themeImageKey(bytes);
    setState(() {
      if (_themePickHashes.contains(key)) {
        _themePickHashes.remove(key);
        _themePicks.removeWhere((p) => _themeImageKey(p) == key);
      } else {
        _themePickHashes.add(key);
        _themePicks.add(bytes);
      }
    });
  }

  void _autoCollage() {
    if (_themePicks.isEmpty) return;
    final order = _themePicks.toList()..shuffle(Random());
    setState(() => _collageOrder = order);
  }

  Color _colorFromThemePrompt(String rawPrompt) {
    final p = rawPrompt.trim().toLowerCase();
    final hex = RegExp(r'^\s*#?([0-9a-f]{6})\s*$').firstMatch(rawPrompt);
    if (hex != null) {
      final hexValue = hex.group(1)!;
      return Color(int.parse(hexValue, radix: 16) + 0xFF000000);
    }

    if (p.contains('orange')) return const Color(0xFFF4511E);
    if (p.contains('green')) return const Color(0xFF1DB954);
    if (p.contains('blue')) return const Color(0xFF1976D2);
    if (p.contains('pink')) return const Color(0xFFE91E63);
    if (p.contains('purple')) return const Color(0xFF6A1B9A);
    if (p.contains('yellow')) return const Color(0xFFFFC024);
    return _themeTintColor;
  }

  Future<void> _swapThemeColorsAi() async {
    final prompt = _themeColorPromptController.text;
    final nextColor = _colorFromThemePrompt(prompt);

    setState(() {
      _isAiProcessingTheme = true;
      _themeTintEnabled = true;
      _themeTintColor = nextColor;
    });

    // Stub: plug AI API here
    await Future<void>.delayed(const Duration(seconds: 1));

    if (!mounted) return;
    setState(() {
      _isAiProcessingTheme = false;
    });
  }

  // SAM Integration Methods
  Future<void> _segmentImageWithSAM(Uint8List imageBytes) async {
    if (_themePicks.isEmpty) return;

    setState(() {
      _isSegmenting = true;
      _showSegmentationOverlay = true;
      _segmentationSuccess = false;
    });

    try {
      // Simulate a faster segmentation response for UI responsiveness.
      await Future.delayed(const Duration(milliseconds: 900));

      // Mock segmentation result (replace with actual SAM integration)
      final mockObjects = <SegmentedObject>[
        SegmentedObject(
          id: 'obj_1',
          mask: Uint8List(100),
          label: 'Background',
          boundingBox: const Rect.fromLTWH(0, 0, 100, 100),
        ),
        SegmentedObject(
          id: 'obj_2',
          mask: Uint8List(100),
          label: 'Main Object',
          boundingBox: const Rect.fromLTWH(50, 50, 100, 100),
        ),
      ];

      setState(() {
        _currentSegmentationResult = SamSegmentationResult(
          objects: mockObjects,
          originalImage: imageBytes,
        );
        _isSegmenting = false;
        _segmentationSuccess = true;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_segmentationSuccess ? 'Segmentation completed successfully!' : 'Segmentation failed'),
            backgroundColor: _segmentationSuccess ? Colors.green : Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isSegmenting = false;
        _showSegmentationOverlay = false;
        _segmentationSuccess = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Segmentation failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _toggleObjectSelection(String objectId) {
    setState(() {
      if (_selectedObjectIds.contains(objectId)) {
        _selectedObjectIds.remove(objectId);
      } else {
        _selectedObjectIds.add(objectId);
      }
    });
  }

  Future<void> _applyColorToSelectedObjects() async {
    if (_currentSegmentationResult == null || _selectedObjectIds.isEmpty)
      return;

    final prompt = _themeColorPromptController.text;
    final targetColor = _colorFromThemePrompt(prompt);

    setState(() {
      _isAiProcessingTheme = true;
      _themeTintEnabled = true;
      _themeTintColor = targetColor;
    });

    try {
      // In a real implementation, this would apply the color to selected objects
      // For now, we'll simulate the color application
      await Future.delayed(const Duration(seconds: 1));

      // Update the currentColor for selected objects
      final updatedObjects = _currentSegmentationResult!.objects.map((obj) {
        if (_selectedObjectIds.contains(obj.id)) {
          return SegmentedObject(
            id: obj.id,
            mask: obj.mask,
            label: obj.label,
            boundingBox: obj.boundingBox,
            currentColor: targetColor,
          );
        }
        return obj;
      }).toList();

      setState(() {
        _currentSegmentationResult = SamSegmentationResult(
          objects: updatedObjects,
          originalImage: _currentSegmentationResult!.originalImage,
        );
        _isAiProcessingTheme = false;
        _selectedObjectIds.clear();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Colors applied to selected objects'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isAiProcessingTheme = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to apply colors: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _closeSegmentationOverlay() {
    setState(() {
      _showSegmentationOverlay = false;
      _currentSegmentationResult = null;
      _selectedObjectIds.clear();
    });
  }

  // Widget for SAM segmentation overlay
  Widget _buildSegmentationOverlay() {
    if (!_showSegmentationOverlay || _currentSegmentationResult == null) {
      return const SizedBox.shrink();
    }

    return Dialog(
      child: Container(
        width: 800,
        height: 600,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Object Selection',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  onPressed: _closeSegmentationOverlay,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Image with segmentation overlay
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Stack(
                  children: [
                    // Original image
                    Image.memory(
                      _currentSegmentationResult!.originalImage,
                      fit: BoxFit.contain,
                    ),

                    // Segmentation overlays
                    if (_isSegmenting)
                      const Center(child: CircularProgressIndicator())
                    else
                      ..._currentSegmentationResult!.objects.map((obj) {
                        final isSelected = _selectedObjectIds.contains(obj.id);
                        return Positioned(
                          left: obj.boundingBox.left,
                          top: obj.boundingBox.top,
                          width: obj.boundingBox.width,
                          height: obj.boundingBox.height,
                          child: GestureDetector(
                            onTap: () => _toggleObjectSelection(obj.id),
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: isSelected ? Colors.blue : Colors.red,
                                  width: 2,
                                ),
                                color: isSelected
                                    ? Colors.blue.withOpacity(0.2)
                                    : Colors.transparent,
                              ),
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.blue
                                        : Colors.red,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    obj.label,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Object list
            Container(
              height: 120,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Detected Objects:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: _currentSegmentationResult!.objects.map((obj) {
                        final isSelected = _selectedObjectIds.contains(obj.id);
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(obj.label),
                            selected: isSelected,
                            onSelected: (selected) =>
                                _toggleObjectSelection(obj.id),
                            backgroundColor: Colors.grey.shade200,
                            selectedColor: Colors.blue.withOpacity(0.3),
                            checkmarkColor: Colors.blue,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _selectedObjectIds.isEmpty
                        ? null
                        : _applyColorToSelectedObjects,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1DB954),
                    ),
                    child: _isAiProcessingTheme
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Text('Apply Colors to Selected'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _closeSegmentationOverlay,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade400,
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _statusLabel(EventStatus status) {
    switch (status) {
      case EventStatus.onlineInquiries:
        return 'Online Inquiries';
      case EventStatus.forProcessing:
        return 'For Processing';
      case EventStatus.forPostAnalysis:
        return 'For Post-Analysis';
      case EventStatus.completed:
        return 'Completed';
      case EventStatus.newEvent:
        return 'New Event';
    }
  }

  //Online Inquiries View
  Widget _buildOnlineInquiriesView(bool isNarrow) {
    final query = _inquirySearchController.text.trim().toLowerCase();
    final filteredOrders = _onlineInquiryOrders.where((o) {
      if (query.isEmpty) return true;
      return [
        o.customerName,
        o.contactPerson,
        o.contactNumber,
        o.emailAddress,
        o.eventType,
        o.eventTitle,
      ].any((v) => v.toLowerCase().contains(query));
    }).toList();

    final inquiryList = filteredOrders.map((order) {
      final firstSlot = order.scheduleSlots.isNotEmpty
          ? order.scheduleSlots.first
          : null;
      final dateLabel = firstSlot == null
          ? ''
          : DateTime.parse(firstSlot.date).toString().split(' ')[0];
      final timeLabel = firstSlot == null
          ? ''
          : '${firstSlot.startTime} - ${firstSlot.endTime}';

      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Inquiry from ${order.customerName}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text('Contact Person: ${order.contactPerson}'),
              Text('Contact Number: ${order.contactNumber}'),
              Text('Email: ${order.emailAddress}'),
              Text('Event Type: ${order.eventType}'),
              if (dateLabel.isNotEmpty) Text('Event Date: $dateLabel'),
              if (timeLabel.isNotEmpty) Text('Event Time: $timeLabel'),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() => _selectedOnlineInquiryOrder = order);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF4511E),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('View Details'),
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();

    final listSection = Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Online Inquiries',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _inquirySearchController,
              decoration: InputDecoration(
                hintText: 'Search inquiries',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            if (inquiryList.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text(
                    'No online inquiries to show yet.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              )
            else
              Column(children: inquiryList),
          ],
        ),
      ),
    );

    final detailsSection = Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Inquiry Details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (_selectedOnlineInquiryOrder == null) ...[
              Text(
                'Select an inquiry to view details.',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ] else ...[
              Text(
                'Event: ${_selectedOnlineInquiryOrder!.eventTitle}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text('Customer: ${_selectedOnlineInquiryOrder!.customerName}'),
              Text('Contact: ${_selectedOnlineInquiryOrder!.contactPerson}'),
              Text('Email: ${_selectedOnlineInquiryOrder!.emailAddress}'),
              const SizedBox(height: 12),
              Text('Event Type: ${_selectedOnlineInquiryOrder!.eventType}'),
              Text('Formality: ${_selectedOnlineInquiryOrder!.formalityLevel}'),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _openFinalizeOnlineInquiryDialog(
                    _selectedOnlineInquiryOrder!,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF4511E),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Modify & Finalize'),
                ),
              ),
            ],
          ],
        ),
      ),
    );

    if (isNarrow) {
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [listSection, const SizedBox(height: 20), detailsSection],
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 3, child: SingleChildScrollView(child: listSection)),
        const SizedBox(width: 20),
        Expanded(flex: 2, child: SingleChildScrollView(child: detailsSection)),
      ],
    );
  }

  Widget _buildSelectableOrderCard(
    EventOrderDto dto,
    bool isSelected,
    void Function(EventOrderDto) onSelect,
  ) {
    final order = _orderToProcessingOrderSummary(dto);
    final bgColor = isSelected ? Colors.blue.shade50 : Colors.white;
    final borderColor = isSelected
        ? const Color(0xFF1976D2)
        : Colors.grey.shade300;

    return InkWell(
      onTap: () {
        setState(() {
          onSelect(dto);
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.company,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    order.contactName,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    order.contactNumber,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${order.date.month}/${order.date.day}/${order.date.year}',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 4),
                Text(
                  order.time,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                if (dto.status == EventStatus.forProcessing)
                  ElevatedButton(
                    onPressed: () => _acceptOrder(dto),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1DB954),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                    child: const Text(
                      'Accept Order',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForProcessingView(bool isNarrow) {
    final orderDtos = _filterEventOrdersBySearch(_processingOrdersDto);

    if (isNarrow) {
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Orders List Section
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('ORDERS FOR PROCESSING'),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _eventSearchController,
                      decoration: InputDecoration(
                        hintText: 'Search orders',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    if (orderDtos.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: Text(
                            'No orders are ready for processing.',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ),
                      )
                    else
                      Column(
                        children: orderDtos.map((dto) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildSelectableOrderCard(
                              dto,
                              _selectedProcessingOrderDto?.id == dto.id,
                              (d) => setState(() {
                                _selectedProcessingOrderDto = d;
                              }),
                            ),
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Event Information Section
            if (_selectedProcessingOrderDto != null) ...[
              _buildEventInformationSection(),
              const SizedBox(height: 20),
            ],

            // Menu Section
            if (_selectedProcessingOrderDto != null) ...[
              _buildProcessingMenuSection(),
              const SizedBox(height: 20),
            ],

            // Food Browser Section
            _buildFoodBrowser(),
          ],
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left: Orders List
        Expanded(
          flex: 2,
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('ORDERS FOR PROCESSING'),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _eventSearchController,
                    decoration: InputDecoration(
                      hintText: 'Search orders',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 16),
                  if (orderDtos.isEmpty)
                    Expanded(
                      child: Center(
                        child: Text(
                          'No orders are ready for processing.',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView(
                        children: orderDtos.map((dto) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildSelectableOrderCard(
                              dto,
                              _selectedProcessingOrderDto?.id == dto.id,
                              (d) => setState(() {
                                _selectedProcessingOrderDto = d;
                              }),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 20),

        // Middle: Event Information and Menu
        Expanded(
          flex: 2,
          child: SingleChildScrollView(
            child: Column(
              children: [
                if (_selectedProcessingOrderDto != null) ...[
                  _buildEventInformationSection(),
                  const SizedBox(height: 20),
                  _buildProcessingMenuSection(),
                ] else ...[
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Center(
                        child: Text(
                          'Select an order to view details.',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(width: 20),

        // Right: Food Browser
        Expanded(flex: 2, child: _buildFoodBrowser()),
      ],
    );
  }

  Widget _buildEventInformationSection() {
    final selectedOrder = _selectedProcessingOrderDto!;
    final totalCost = computeOrderTotalCost(selectedOrder);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionTitle('EVENT INFORMATION'),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'in progress',
                    style: TextStyle(
                      color: Colors.orange.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildEventInfoRow('EVENT TITLE', selectedOrder.eventTitle),
            _buildEventInfoRow('EVENT TYPE', selectedOrder.eventType),
            _buildEventInfoRow('CUSTOMER', selectedOrder.customerName),
            _buildEventInfoRow('CONTACT PERSON', selectedOrder.contactPerson),
            _buildEventInfoRow('CONTACT NUMBER', selectedOrder.contactNumber),
            _buildEventInfoRow('EMAIL ADDRESS', selectedOrder.emailAddress),
            if (selectedOrder.scheduleSlots.isNotEmpty)
              _buildEventInfoRow(
                'DATE OF EVENT',
                selectedOrder.scheduleSlots.first.date,
              ),
            _buildEventInfoRow(
              'TRANSACTION NO',
              _transactionNumberForOrder(selectedOrder),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _showThemeDesignDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF4511E),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('VIEW EVENTS THEME DESIGN'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _showChecklistDialog(selectedOrder),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1DB954),
                      side: const BorderSide(color: Color(0xFF1DB954)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('VIEW CHECKLIST'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Downpayment'),
                    selected:
                        _selectedPaymentMode ==
                        PaymentConfirmationMode.downpayment,
                    onSelected: (_) {
                      setState(() {
                        _selectedPaymentMode =
                            PaymentConfirmationMode.downpayment;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Full Payment'),
                    selected:
                        _selectedPaymentMode ==
                        PaymentConfirmationMode.fullPayment,
                    onSelected: (_) {
                      setState(() {
                        _selectedPaymentMode =
                            PaymentConfirmationMode.fullPayment;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildCostBlock(
              'COST ESTIMATION',
              formatPesos(totalCost),
              Colors.orange,
            ),
            const SizedBox(height: 8),
            _buildCostBlock(
              'Downpayment',
              formatPesos(
                _selectedPaymentMode == PaymentConfirmationMode.downpayment
                    ? totalCost / 2
                    : totalCost,
              ),
              Colors.blue,
            ),
            const SizedBox(height: 8),
            _buildCostBlock('Total Cost', formatPesos(totalCost), Colors.green),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _cancelProcessingOrder(selectedOrder),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('CANCEL ORDER'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _showPaymentConfirmationDialog(
                      selectedOrder,
                      _selectedPaymentMode,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1DB954),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('CONFIRM PAYMENT'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProcessingMenuSection() {
    final selectedOrder = _selectedProcessingOrderDto!;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('MENU'),
            const SizedBox(height: 16),
            if (selectedOrder.menu.isEmpty)
              Text(
                'No menu items available.',
                style: TextStyle(color: Colors.grey.shade600),
              )
            else
              Column(
                children: selectedOrder.menu.map((m) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.fastfood, color: Colors.grey),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                m.dishName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${m.price} ${m.paxOption}',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  String _transactionNumberForOrder(EventOrderDto order) {
    try {
      final txn =
          (order as dynamic).transactionNumber ??
          (order as dynamic).transactionNo ??
          (order as dynamic).transactionId;
      if (txn is String && txn.trim().isNotEmpty) return txn;
      if (txn is int) return txn.toString();
    } catch (_) {}
    return 'N/A';
  }

  bool _isValidPaymentReference(String raw) {
    return RegExp(r'^\d{10}$').hasMatch(raw.trim());
  }

  Future<bool> _confirmOrderPayment(
    EventOrderDto order,
    PaymentConfirmationMode mode,
    String reference,
  ) async {
    if (!_isValidPaymentReference(reference)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'A valid 10-digit payment reference number is required.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }

    try {
      setState(() => _paymentDialogLoading = true);
      await EventsApi.instance.acceptOrder(orderId: order.id);
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            mode == PaymentConfirmationMode.fullPayment
                ? 'Full payment confirmed. Order moved to Post-Analysis.'
                : 'Downpayment confirmed. Order moved to Post-Analysis.',
          ),
          backgroundColor: const Color(0xFF1DB954),
        ),
      );
      await _refreshOrders();
      setState(() {
        _selectedProcessingOrderDto = null;
      });
      _tabController.animateTo(EventStatus.forPostAnalysis.index);
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to confirm payment.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    } finally {
      if (mounted) {
        setState(() => _paymentDialogLoading = false);
      }
    }
  }

  Future<void> _showPaymentConfirmationDialog(
    EventOrderDto order,
    PaymentConfirmationMode mode,
  ) async {
    _paymentReferenceController.clear();
    var referenceText = '';
    final title = mode == PaymentConfirmationMode.downpayment
        ? 'Enter Downpayment'
        : 'Confirm Full Payment';
    final subtitle = mode == PaymentConfirmationMode.downpayment
        ? 'Downpayment Amount Due (50%)'
        : 'Total Amount Due';
    final amount = mode == PaymentConfirmationMode.downpayment
        ? computeOrderTotalCost(order) / 2
        : computeOrderTotalCost(order);

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, dialogSetState) {
            final isReferenceValid = _isValidPaymentReference(referenceText);
            return AlertDialog(
              title: Text(title),
              content: SizedBox(
                width: 780,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(subtitle),
                    const SizedBox(height: 12),
                    Text(
                      formatPesos(amount),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFF4511E),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _paymentReferenceController,
                      decoration: InputDecoration(
                        labelText: 'Payment Reference Number',
                        hintText: '10 digit reference number',
                        errorText: referenceText.isNotEmpty && !isReferenceValid
                            ? 'Reference must be exactly 10 digits'
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      maxLength: 10,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (value) {
                        dialogSetState(() {
                          referenceText = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: TextButton(
                        onPressed: () => _showOrderSummaryDialog(order),
                        child: const Text('view order summary'),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _paymentDialogLoading
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text('cancel'),
                ),
                ElevatedButton(
                  onPressed: !isReferenceValid || _paymentDialogLoading
                      ? null
                      : () async {
                          final confirmed = await _confirmOrderPayment(
                            order,
                            mode,
                            referenceText,
                          );
                          if (confirmed && mounted) {
                            Navigator.of(context).pop();
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1DB954),
                  ),
                  child: _paymentDialogLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text('confirm'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showOrderSummaryDialog(EventOrderDto order) async {
    final orderTotal = computeOrderTotalCost(order);
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Order Summary'),
          content: SizedBox(
            width: 900,
            height: 520,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: DataTable(
                      headingRowColor: MaterialStateProperty.all(
                        Colors.grey.shade200,
                      ),
                      columns: const [
                        DataColumn(label: Text('Item')),
                        DataColumn(label: Text('Qty')),
                        DataColumn(label: Text('Unit Cost')),
                        DataColumn(label: Text('Total')),
                      ],
                      rows: order.menu.map((m) {
                        final item = m as dynamic;
                        final dishName = item.dishName ?? 'Item';
                        final qty = item.paxOption ?? '1 pax';
                        final price = item.price is num
                            ? (item.price as num).toDouble()
                            : 0.0;
                        return DataRow(
                          cells: [
                            DataCell(Text(dishName)),
                            DataCell(Text('$qty')),
                            DataCell(Text(formatPesos(price))),
                            DataCell(Text(formatPesos(price))),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildCostBlock(
                  'Cost Estimation',
                  formatPesos(orderTotal),
                  Colors.orange,
                ),
                const SizedBox(height: 8),
                _buildCostBlock(
                  'Downpayment',
                  formatPesos(orderTotal / 2),
                  Colors.blue,
                ),
                const SizedBox(height: 8),
                _buildCostBlock(
                  'Total Cost',
                  formatPesos(orderTotal),
                  Colors.green,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showChecklistDialog(EventOrderDto order) async {
    final items = order.menu.map((m) {
      final item = m as dynamic;
      return ChecklistItem(
        item: item.dishName ?? 'Item',
        description: item.paxOption ?? '1 pax',
        quantity: 1,
        cost: item.price is num ? (item.price as num).toDouble() : 0.0,
      );
    }).toList();

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, dialogSetState) {
            return AlertDialog(
              title: Text('Checklist for ${order.eventTitle}'),
              content: SizedBox(
                width: 900,
                height: 520,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        child: DataTable(
                          headingRowColor: MaterialStateProperty.all(
                            Colors.grey.shade200,
                          ),
                          columns: const [
                            DataColumn(label: Text('Item')),
                            DataColumn(label: Text('Description')),
                            DataColumn(label: Text('Quantity')),
                            DataColumn(label: Text('Cost')),
                            DataColumn(label: Text('Status')),
                          ],
                          rows: items.map((item) {
                            return DataRow(
                              cells: [
                                DataCell(Text(item.item)),
                                DataCell(Text(item.description)),
                                DataCell(Text('${item.quantity}')),
                                DataCell(Text(formatPesos(item.cost))),
                                DataCell(
                                  Text(
                                    item.isCompleted ? 'completed' : 'not done',
                                    style: TextStyle(
                                      color: item.isCompleted
                                          ? Colors.green
                                          : Colors.red,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Checklist exported as PDF.'),
                              ),
                            );
                          },
                          child: const Text('generate PDF'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Checklist saved.')),
                            );
                          },
                          child: const Text('save'),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('cancel'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _cancelProcessingOrder(EventOrderDto order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Order'),
        content: Text(
          'Are you sure you want to cancel the order for ${order.customerName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Call API to cancel order
      await EventsApi.instance.cancelOrder(orderId: order.id);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order cancelled successfully.'),
          backgroundColor: Colors.orange,
        ),
      );

      // Refresh orders
      await _refreshOrders();
      setState(() {
        _selectedProcessingOrderDto = null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to cancel order.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _acceptOrder(EventOrderDto order) async {
    try {
      await EventsApi.instance.acceptOrder(orderId: order.id);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order accepted successfully.'),
          backgroundColor: Color(0xFF1DB954),
        ),
      );

      // Refresh orders and move to post-analysis
      await _refreshOrders();
      setState(() {
        _selectedProcessingOrderDto = null;
      });
      _tabController.animateTo(EventStatus.forPostAnalysis.index);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to accept order.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showThemeDesignDialog() async {
    final picksBefore = _themePicks.toList();
    final pickHashesBefore = _themePickHashes.toSet();
    final collageBefore = _collageOrder.toList();
    final tintEnabledBefore = _themeTintEnabled;
    final tintColorBefore = _themeTintColor;
    final promptBefore = _themeColorPromptController.text;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final filteredTemplates = _themeTemplates.where((t) {
              if (_eventType == null || _eventType!.trim().isEmpty) return true;
              return t.eventTypes.contains(_eventType);
            }).toList();

            final designGridImages = <Uint8List>[
              ...filteredTemplates.map((t) => t.imageBytes),
              ..._themeDesignImages,
            ];

            final collageImages = _collageOrder.isNotEmpty
                ? _collageOrder
                : _themePicks;

            Widget imageTile(Uint8List bytes) {
              final key = _themeImageKey(bytes);
              final selected = _themePickHashes.contains(key);

              return ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Image.memory(bytes, fit: BoxFit.cover),
                    ),
                    Positioned(
                      left: 8,
                      bottom: 8,
                      right: 8,
                      child: ElevatedButton(
                        onPressed: () {
                          _toggleThemePick(bytes);
                          setStateDialog(() {});
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: selected
                              ? Colors.black54
                              : const Color(0xCC000000),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          selected ? 'Selected' : 'Add to picks',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            Widget picksPreview() {
              if (_themePicks.isEmpty) {
                return Center(
                  child: Text(
                    'Select images into your picks.',
                    style: TextStyle(color: Colors.grey.shade600),
                    textAlign: TextAlign.center,
                  ),
                );
              }

              return PageView.builder(
                itemCount: _themePicks.length,
                controller: PageController(viewportFraction: 0.92),
                itemBuilder: (context, index) {
                  final bytes = _themePicks[index];
                  final image = Image.memory(bytes, fit: BoxFit.cover);
                  final display = !_themeTintEnabled
                      ? image
                      : ColorFiltered(
                          colorFilter: ColorFilter.mode(
                            _themeTintColor,
                            BlendMode.modulate,
                          ),
                          child: image,
                        );
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: display,
                      ),
                    ),
                  );
                },
              );
            }

            return AlertDialog(
              title: const Text('Events Theme Design'),
              content: SizedBox(
                width: 900,
                height: 520,
                child: Row(
                  children: [
                    // Left: template board + uploads
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'DESIGN BOARD',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: designGridImages.isEmpty
                                ? Center(
                                    child: Text(
                                      'No theme images available yet.',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  )
                                : GridView.count(
                                    crossAxisCount: 3,
                                    mainAxisSpacing: 12,
                                    crossAxisSpacing: 12,
                                    children: designGridImages.map((b) {
                                      return Container(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: Colors.grey.shade300,
                                          ),
                                        ),
                                        child: imageTile(b),
                                      );
                                    }).toList(),
                                  ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () async {
                                if (!kIsWeb) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Image upload is only supported on web.',
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                final uploadInput =
                                    html.FileUploadInputElement();
                                uploadInput.accept = 'image/*';
                                uploadInput.multiple = true;
                                uploadInput.click();

                                uploadInput.onChange.listen((event) {
                                  final files = uploadInput.files;
                                  if (files == null || files.isEmpty) return;

                                  for (final file in files) {
                                    final reader = html.FileReader();
                                    reader.readAsArrayBuffer(file);
                                    reader.onLoad.listen((event) {
                                      final data = reader.result;
                                      if (data is Uint8List) {
                                        setStateDialog(() {
                                          _themeDesignImages.add(data);
                                        });
                                      } else if (data is ByteBuffer) {
                                        setStateDialog(() {
                                          _themeDesignImages.add(
                                            data.asUint8List(),
                                          );
                                        });
                                      }
                                    });
                                  }
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFF4511E),
                              ),
                              child: const Text('UPLOAD IMAGES'),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 20),

                    // Right: picks + collage preview
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'YOUR PICKS',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                padding: const EdgeInsets.all(12),
                                child: picksPreview(),
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),
                          TextField(
                            controller: _themeColorPromptController,
                            decoration: InputDecoration(
                              labelText: 'What colors would like to have?',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              suffixIcon: _isAiProcessingTheme
                                  ? const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 8),

                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed:
                                      _themePicks.isEmpty ||
                                          _isAiProcessingTheme
                                      ? null
                                      : () async {
                                          await _swapThemeColorsAi();
                                          setStateDialog(() {});
                                        },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1DB954),
                                  ),
                                  child: const Text('SWAP COLORS'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed:
                                      _themePicks.isEmpty ||
                                          _isAiProcessingTheme ||
                                          _isSegmenting
                                      ? null
                                      : () async {
                                          if (_themePicks.isNotEmpty) {
                                            await _segmentImageWithSAM(
                                              _themePicks.first,
                                            );
                                          }
                                        },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                  ),
                                  child: _isSegmenting
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  Colors.white,
                                                ),
                                          ),
                                        )
                                      : const Text('SEGMENT OBJECTS'),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 8),

                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _themePicks.length <= 1
                                      ? null
                                      : () {
                                          _autoCollage();
                                          setStateDialog(() {});
                                        },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _themePicks.length <= 1 
                                        ? Colors.grey.shade400 
                                        : const Color(0xFF1DB954),
                                  ),
                                  child: Text(
                                    _themePicks.length <= 1 
                                        ? 'AUTO COLLAGE (Need 2+ photos)'
                                        : 'AUTO COLLAGE',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _currentSegmentationResult != null
                                      ? () {
                                          Navigator.of(context).pop();
                                          showDialog(
                                            context: context,
                                            builder: (context) =>
                                                _buildSegmentationOverlay(),
                                          );
                                        }
                                      : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange,
                                  ),
                                  child: const Text('EDIT OBJECTS'),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1DB954),
                                  ),
                                  child: const Text('SAVE'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {
                                    setState(() {
                                      _themePicks
                                        ..clear()
                                        ..addAll(picksBefore);
                                      _themePickHashes
                                        ..clear()
                                        ..addAll(pickHashesBefore);
                                      _collageOrder = collageBefore;
                                      _themeTintEnabled = tintEnabledBefore;
                                      _themeTintColor = tintColorBefore;
                                      _themeColorPromptController.text =
                                          promptBefore;
                                    });
                                    Navigator.of(context).pop();
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red.shade400,
                                  ),
                                  child: const Text('CANCEL'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPostAnalysisView(bool isNarrow) {
    final orderDtos = _filterEventOrdersBySearch(_postAnalysisOrdersDto);

    final listSection = Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Orders for Post-Event Analysis',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _eventSearchController,
              decoration: InputDecoration(
                hintText: 'Search',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            if (orderDtos.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text(
                    'No orders available for analysis.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              )
            else
              Column(
                children: orderDtos
                    .map(
                      (dto) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildSelectableOrderCard(
                          dto,
                          _selectedPostAnalysisOrderDto?.id == dto.id,
                          (d) => setState(() {
                            _selectedPostAnalysisOrderDto = d;
                            _syncPostAnalysisFields(d);
                          }),
                        ),
                      ),
                    )
                    .toList(),
              ),
          ],
        ),
      ),
    );

    final menuSection = Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'MENU',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (_selectedPostAnalysisOrderDto == null)
              Text(
                'Select an order to view the menu.',
                style: TextStyle(color: Colors.grey.shade600),
              )
            else
              Column(
                children: _selectedPostAnalysisOrderDto!.menu.map((m) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.fastfood, color: Colors.grey),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                m.dishName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${m.price} · ${m.paxOption}',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );

    final selPost = _selectedPostAnalysisOrderDto;
    final postTotal = selPost == null ? 0.0 : computeOrderTotalCost(selPost);
    final postDown = postTotal > 0 ? postTotal / 2 : 0.0;

    final infoSection = Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Other Info',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (selPost == null)
              Text(
                'Select an order to enter post-event details.',
                style: TextStyle(color: Colors.grey.shade600),
              )
            else ...[
              TextField(
                controller: _postCardsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Business cards given away',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _postInquiriesController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'On-the-spot inquiries',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _postComplaintsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'No. of Complaints',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _postAnalysisSaving
                      ? null
                      : () async {
                          setState(() => _postAnalysisSaving = true);
                          try {
                            await EventsApi.instance.completePostAnalysis(
                              orderId: selPost.id,
                              businessCardsGivenAway:
                                  int.tryParse(
                                    _postCardsController.text.trim(),
                                  ) ??
                                  0,
                              onTheSpotInquiries:
                                  int.tryParse(
                                    _postInquiriesController.text.trim(),
                                  ) ??
                                  0,
                              complaints:
                                  int.tryParse(
                                    _postComplaintsController.text.trim(),
                                  ) ??
                                  0,
                            );
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Post-event analysis saved. Event moved to Completed.',
                                ),
                              ),
                            );
                            setState(() {
                              _selectedPostAnalysisOrderDto = null;
                              _syncPostAnalysisFields(null);
                            });
                            await _refreshOrders();
                          } catch (_) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Could not save post-event analysis.',
                                ),
                              ),
                            );
                          } finally {
                            if (mounted) {
                              setState(() => _postAnalysisSaving = false);
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1DB954),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _postAnalysisSaving
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Done'),
                ),
              ),
            ],
            const SizedBox(height: 16),
            _buildCostBlock(
              'Cost Estimation',
              selPost == null ? 'N/A' : formatPesos(postTotal),
              Colors.orange,
            ),
            const SizedBox(height: 8),
            _buildCostBlock(
              'Downpayment',
              selPost == null ? 'N/A' : formatPesos(postDown),
              Colors.blue,
            ),
            const SizedBox(height: 8),
            _buildCostBlock(
              'Total Cost',
              selPost == null ? 'N/A' : formatPesos(postTotal),
              Colors.green,
            ),
          ],
        ),
      ),
    );

    if (isNarrow) {
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            listSection,
            const SizedBox(height: 20),
            menuSection,
            const SizedBox(height: 20),
            infoSection,
          ],
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 3, child: SingleChildScrollView(child: listSection)),
        const SizedBox(width: 20),
        Expanded(flex: 3, child: SingleChildScrollView(child: menuSection)),
        const SizedBox(width: 20),
        Expanded(flex: 4, child: SingleChildScrollView(child: infoSection)),
      ],
    );
  }

  Widget _buildCompletedEventsView(bool isNarrow) {
    final orderDtos = _completedOrdersDto;

    final listSection = Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'COMPLETED EVENTS',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (orderDtos.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text(
                    'No completed events yet.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              )
            else
              Column(
                children: orderDtos
                    .map(
                      (dto) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildSelectableOrderCard(
                          dto,
                          _selectedCompletedOrderDto?.id == dto.id,
                          (d) => setState(() {
                            _selectedCompletedOrderDto = d;
                          }),
                        ),
                      ),
                    )
                    .toList(),
              ),
          ],
        ),
      ),
    );

    final menuSection = Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'MENU',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (_selectedCompletedOrderDto == null)
              Text(
                'Select an event to view the menu.',
                style: TextStyle(color: Colors.grey.shade600),
              )
            else
              Column(
                children: _selectedCompletedOrderDto!.menu.map((m) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.fastfood, color: Colors.grey),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                m.dishName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${m.price} · ${m.paxOption}',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );

    final selCompleted = _selectedCompletedOrderDto;
    final pa = selCompleted?.postAnalysis;
    final compTotal = selCompleted == null
        ? 0.0
        : computeOrderTotalCost(selCompleted);
    final compDown = compTotal > 0 ? compTotal / 2 : 0.0;

    final infoSection = Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'OTHER INFO',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              'Business cards given away',
              pa == null ? '—' : '${pa.businessCardsGivenAway}',
            ),
            _buildInfoRow(
              'On-the-spot inquiries',
              pa == null ? '—' : '${pa.onTheSpotInquiries}',
            ),
            _buildInfoRow(
              'No. of Complaints',
              pa == null ? '—' : '${pa.complaints}',
            ),
            const SizedBox(height: 16),
            _buildCostBlock(
              'Cost Estimation',
              selCompleted == null ? 'N/A' : formatPesos(compTotal),
              Colors.orange,
            ),
            const SizedBox(height: 8),
            _buildCostBlock(
              'Downpayment',
              selCompleted == null ? 'N/A' : formatPesos(compDown),
              Colors.blue,
            ),
            const SizedBox(height: 8),
            _buildCostBlock(
              'Total Cost',
              selCompleted == null ? 'N/A' : formatPesos(compTotal),
              Colors.green,
            ),
          ],
        ),
      ),
    );

    if (isNarrow) {
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            listSection,
            const SizedBox(height: 20),
            menuSection,
            const SizedBox(height: 20),
            infoSection,
          ],
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 3, child: SingleChildScrollView(child: listSection)),
        const SizedBox(width: 20),
        Expanded(flex: 3, child: SingleChildScrollView(child: menuSection)),
        const SizedBox(width: 20),
        Expanded(flex: 4, child: SingleChildScrollView(child: infoSection)),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade700)),
          Text(value, style: TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Color(0xFF2E2E2E),
      ),
    );
  }

  Widget _buildEventInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCostBlock(String title, String value, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.w600)),
          Text(value, style: TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildBodyContent(EventStatus status, bool isNarrow) {
    switch (status) {
      case EventStatus.onlineInquiries:
        return _buildOnlineInquiriesView(isNarrow);
      case EventStatus.forProcessing:
        return _buildForProcessingView(isNarrow);
      case EventStatus.forPostAnalysis:
        return _buildPostAnalysisView(isNarrow);
      case EventStatus.completed:
        return _buildCompletedEventsView(isNarrow);
      case EventStatus.newEvent:
        return isNarrow
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildEventForm(),
                  const SizedBox(height: 20),
                  _buildMenuSection(),
                  const SizedBox(height: 20),
                  _buildFoodBrowser(),
                  const SizedBox(height: 20),
                  _buildNewEventSubmissionBar(),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildEventForm(),
                          const SizedBox(height: 20),
                          _buildMenuSection(),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    flex: 4,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildFoodBrowser(),
                          const SizedBox(height: 20),
                          _buildNewEventSubmissionBar(),
                        ],
                      ),
                    ),
                  ),
                ],
              );
    }
  }

  Widget _buildNewEventSubmissionBar() {
    final themePicksCount = _themePicks.length;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Theme picks: $themePicksCount',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 12),

            /// SAVE DRAFT
            ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Saved draft.')));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFA726),
                foregroundColor: Colors.black,
              ),
              child: const Text('SAVE DRAFT'),
            ),

            const SizedBox(width: 12),

            /// SUBMIT
            ElevatedButton(
              onPressed: () async {
                final missing = <String>[];

                if (_eventTitleController.text.trim().isEmpty) {
                  missing.add('Event title');
                }
                if (_eventType == null) missing.add('Event type');
                if (_formalityLevel == null) missing.add('Formality level');
                if (_customerController.text.trim().isEmpty) {
                  missing.add('Customer name');
                }
                if (_contactPersonController.text.trim().isEmpty) {
                  missing.add('Contact person');
                }
                if (_contactNumberController.text.trim().isEmpty) {
                  missing.add('Contact number');
                }
                if (_emailController.text.trim().isEmpty) {
                  missing.add('Email address');
                }
                if (_eventScheduleSlots.isEmpty) {
                  missing.add('Date & time');
                }
                if (_eventAddressController.text.trim().isEmpty) {
                  missing.add('Event address');
                }

                final guestCount = int.tryParse(
                  _guestCountController.text.trim(),
                );

                if (_guestCountController.text.trim().isEmpty) {
                  missing.add('No. of guests');
                } else if (guestCount == null || guestCount <= 0) {
                  missing.add('No. of guests (valid)');
                }

                if (_menuItems.isEmpty) missing.add('Menu');
                if (_themePicks.isEmpty) missing.add('Theme picks');

                if (missing.isNotEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Please complete: ${missing.join(', ')}'),
                    ),
                  );
                  return;
                }

                try {
                  final payload = _buildPayloadFromForm();

                  // backend commit
                  await EventsApi.instance.managerSubmitNewEventToProcessing(
                    payload: payload,
                  );

                  // refresh orders
                  await _refreshOrders();

                  // success indicator
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Order submitted successfully.'),
                    ),
                  );

                  // reset form if success
                  _resetForm();

                  // switch tab
                  _tabController.animateTo(EventStatus.forProcessing.index);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to submit order.')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1DB954),
              ),
              child: const Text('SUBMIT'),
            ),
          ],
        ),
      ),
    );
  }

  // Event Management Page
  Widget _buildEventForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _resetForm,
                icon: const Icon(Icons.clear),
                label: const Text('Clear Form'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFED8845),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _eventSearchController,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  hintText: 'Search',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (_) {
                  setState(() {});
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          'Event Information',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F7F9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            children: [
              TextField(
                controller: _eventTitleController,
                decoration: InputDecoration(
                  labelText: 'Event Title',
                  labelStyle: const TextStyle(fontSize: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _eventType,
                      items: _eventTypes
                          .map(
                            (type) => DropdownMenuItem(
                              value: type,
                              child: Text(type),
                            ),
                          )
                          .toList(),
                      decoration: InputDecoration(
                        labelText: 'Event Type',
                        labelStyle: const TextStyle(fontSize: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _eventType = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _customerController,
                      decoration: InputDecoration(
                        labelText: 'Customer',
                        labelStyle: const TextStyle(fontSize: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<EventFormalityLevel>(
                value: _formalityLevel,
                items: EventFormalityLevel.values
                    .map(
                      (level) => DropdownMenuItem(
                        value: level,
                        child: Text(level.displayName),
                      ),
                    )
                    .toList(),
                decoration: InputDecoration(
                  labelText: 'Formality Level',
                  labelStyle: const TextStyle(fontSize: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onChanged: (value) {
                  setState(() => _formalityLevel = value);
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _contactPersonController,
                      decoration: InputDecoration(
                        labelText: 'Contact Person',
                        labelStyle: const TextStyle(fontSize: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _contactNumberController,
                      decoration: InputDecoration(
                        labelText: 'Contact Number',
                        labelStyle: const TextStyle(fontSize: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: 'Email Address',
                        labelStyle: const TextStyle(fontSize: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Date & Time',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _pickDate,
                            icon: const Icon(Icons.add),
                            label: const Text('Add slot'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFF4511E),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (_eventScheduleSlots.isEmpty)
                          Text(
                            'No schedules yet.',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                          )
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _eventScheduleSlots.asMap().entries.map((
                              e,
                            ) {
                              final index = e.key;
                              final slot = e.value;
                              return InputChip(
                                label: Text(slot.label(context)),
                                onDeleted: () {
                                  setState(() {
                                    _eventScheduleSlots.removeAt(index);
                                  });
                                },
                              );
                            }).toList(),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _eventAddressController,
                      decoration: InputDecoration(
                        labelText: 'Address of Event',
                        labelStyle: const TextStyle(fontSize: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _guestCountController,
                      decoration: InputDecoration(
                        labelText: 'No. of Guests',
                        labelStyle: const TextStyle(fontSize: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Menu View
  Widget _buildMenuSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Menu',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: _menuItems.isEmpty
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: const [
                    Text('You don’t have anything on the menu right now...'),
                    SizedBox(height: 20),
                    SizedBox(height: 30),
                  ],
                )
              : Column(
                  children: _menuItems.map((item) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${item.dish.name} • ${item.paxOption}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            item.dish.price,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            onPressed: () => _removeFromMenu(item),
                            icon: const Icon(Icons.close, size: 20),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _showThemeDesignDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1DB954),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('EVENTS THEME DESIGN'),
          ),
        ),
      ],
    );
  }

  // Selected Dish View
  Widget _buildDishCard(MenuDish dish) {
    final selectedPax = _selectedPaxPerDish[dish.name] ?? dish.paxOptions.first;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.fastfood,
                    size: 21,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dish.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dish.price,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => _addToMenu(dish),
                  child: const Text('Add to menu'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: dish.paxOptions.map((option) {
                final isSelected = selectedPax == option;
                return ChoiceChip(
                  label: Text(option),
                  selected: isSelected,
                  onSelected: (_) {
                    setState(() {
                      _selectedPaxPerDish[dish.name] = option;
                    });
                  },
                  selectedColor: const Color(0xFF1976D2),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      showSearch: true,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 1100;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Manage Events',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TabBar(
                  padding: EdgeInsets.zero,
                  controller: _tabController,
                  isScrollable: true,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.black87,
                  indicator: BoxDecoration(
                    color: const Color(0xFFED8845),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  tabs: EventStatus.values
                      .map((status) => Tab(text: _statusLabel(status)))
                      .toList(),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: EventStatus.values
                        .map((status) => _buildBodyContent(status, isNarrow))
                        .toList(),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildFoodBrowser() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Food',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _foodSearchController,
                  decoration: InputDecoration(
                    hintText: 'Search dish',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),
                if (_filteredDishes.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Text(
                        'No dishes match your search.',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ),
                  )
                else
                  SizedBox(
                    height:
                        400, // Fixed height to prevent overflow, or use Expanded if possible
                    child: ListView(
                      children: _filteredDishes
                          .map(
                            (dish) => Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: _buildDishCard(dish),
                            ),
                          )
                          .toList(),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
