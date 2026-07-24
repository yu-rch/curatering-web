import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../models/menu_dish.dart';
import '../services/menu_store.dart';
import '../services/public_events_api.dart';
import '../services/runpod_service.dart';
import '../services/set_menu_store.dart';
import '../services/website_content_store.dart';
import '../widgets/antd_buttons.dart';
import '../widgets/antd_form_field.dart';
import '../widgets/antd_message.dart';
import '../widgets/antd_tokens.dart';
import '../widgets/centered_viewport_scroll.dart';
import '../widgets/customer_website_topbar.dart';
import '../widgets/allergen_selector_field.dart';
import '../widgets/inquiry_menu_selection_dialog.dart';
import '../widgets/map_picker.dart';
import '../widgets/venue_autocomplete_field.dart';
import '../widgets/event_venue_map_preview.dart';
import '../utils/inquiry_pricing.dart';
import '../widgets/antd_dialog.dart';
import '../utils/image_download.dart';
import 'customer_login.dart';
import 'my_caterings_page.dart';

const String _primaryFont = 'Inter';

const _kInquiryWizardStepLabels = <String>[
  'Catering Packages',
  'Enter number of guests',
  'Fill Inquiry Form',
  'Completed',
];

const _kInquiryWizardStepIcons = <IconData>[
  Icons.menu_book_outlined,
  Icons.groups_outlined,
  Icons.edit_note_outlined,
  Icons.check_circle_outline,
];
bool isMobile(BuildContext context) => MediaQuery.of(context).size.width < 700;

bool isTablet(BuildContext context) =>
    MediaQuery.of(context).size.width >= 700 &&
    MediaQuery.of(context).size.width < 1100;

bool isDesktop(BuildContext context) =>
    MediaQuery.of(context).size.width >= 1100;

EdgeInsets websitePagePadding(BuildContext context, {double vertical = 24}) {
  final horizontal =
      isDesktop(context)
          ? 40.0
          : isTablet(context)
          ? 24.0
          : 16.0;
  return EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical);
}

class InquirePage extends StatefulWidget {
  const InquirePage({
    super.key,
    this.contentEditable = false,
    this.showStaffChrome = true,
  });

  final bool contentEditable;
  final bool showStaffChrome;

  @override
  State<InquirePage> createState() => _InquirePageState();
}

class _InquirePageState extends State<InquirePage> {
  // Event Information Controllers
  final _eventTitle = TextEditingController();
  final _customer = TextEditingController();
  final _contactPerson = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  double? _addressLat;
  double? _addressLng;
  final _guests = TextEditingController();
  final _landingPax = TextEditingController();
  final _paxBuffer = TextEditingController();
  final _dateController = TextEditingController();
  final _timeController = TextEditingController();
  final _endTimeController = TextEditingController();
  final _notesController = TextEditingController();
  final _eventCityController = TextEditingController();
  final _foodTastingDateController = TextEditingController();
  final _foodTastingTimeController = TextEditingController();
  final List<Map<String, String>> _extraScheduleSlots = [];

  // State
  String _eventType = 'Birthday';
  String _formality = 'casual';
  String _eventSetting = 'open';
  bool _foodTastingRequested = false;
  bool _suggestMenu = false;
  bool _customerSameAsContact = false;
  String? _submittedCateringId;
  bool _submitting = false;
  bool _generatingDesign = false;
  String? _generatedImageUrl;
  String? _generatedDesignPrompt;
  final List<String> _generatedImageHistory = [];
  int _scheduleConflictCount = 0;
  Timer? _scheduleConflictDebounce;

  String _generatedImageDisplayUrl(String url) {
    return RunPodService.proxyImageUrlIfNeeded(url);
  }

  // Service Type Selection — set from landing pax / form sync
  String _serviceType = 'catering'; // 'catering' or 'catering+event'
  String _serviceIncluded = 'no'; // event styling yes/no for catering-only

  // Menu preferences: 0 = custom dishes, 1 = set menu (exclusive)
  int _menuPrefTabIndex = 0;
  final List<String> _selectedDishIds = [];
  final List<Map<String, dynamic>> _menuSelections = [];
  String _allergensSerialized = '';

  /// Wizard: 0 packages, 1 guests landing, 2 form (+ design substeps), 3 completed.
  int _wizardStep = 0;
  /// Within wizard step 2: 0 = main form, 1 = design path, 2 = design fields.
  int _formPhase = 0;
  String? _eventDesignMode; // 'macrina' | 'customer'
  final _macrinaPalette = TextEditingController();
  final _macrinaTheme = TextEditingController();
  final Map<String, String?> _fieldErrors = {};
  String? _venueFieldError;
  String? _genAiError;

  // Event Design - Prompt Based GenAI
  bool _wantsCustomDesign = false;
  String? _selectedEventType;
  String? _selectedStyle;
  String? _selectedMood;
  final List<String> _selectedColors = [];
  final List<String> _selectedDecor = [];
  final _designPromptController = TextEditingController();
  final _inquiryEventTypeOtherController = TextEditingController();
  final _eventTypeOtherController = TextEditingController();
  final _styleOtherController = TextEditingController();
  final _moodOtherController = TextEditingController();
  final _colorOtherController = TextEditingController();
  final _decorOtherController = TextEditingController();
  String? _venuePhotoBase64;

  final _eventTypes = [
    "Birthday",
    "Wedding",
    "Debut",
    "Baptism",
    "Corporate",
    "Sports",
    "Government",
    "Show",
    "Educational",
    "Reunion",
    "Gala",
    "Dinner",
    "Other",
  ];
  final _styles = [
    "Elegant",
    "Rustic",
    "Modern",
    "Garden",
    "Minimalist",
    "Vintage",
    "Bohemian",
    "Other",
  ];
  final _moods = [
    "Romantic",
    "Bright",
    "Dramatic",
    "Cozy",
    "Luxurious",
    "Fun",
    "Other",
  ];
  final _colorPalettes = [
    "White & Gold",
    "Pastel Pink",
    "Earthy Green",
    "Navy & Silver",
    "Peach & Cream",
    "Black & White",
    "Other",
  ];
  final _decorOptions = [
    "Floral Centerpieces",
    "Fairy Lights",
    "Stage Backdrop",
    "Balloon Setup",
    "Drapery & Curtains",
    "Table Runners",
    "Photo Booth",
    "Chandeliers",
    "Other",
  ];

  @override
  void initState() {
    super.initState();
    if (!_inquiryEventTypes.contains(_eventType)) {
      _eventType = _inquiryEventTypes.first;
    }
    MenuStore.instance.loadDishes();
    SetMenuStore.instance.loadSetMenus();
    WebsiteContentStore.instance.ensureLoaded().then((_) {
      if (mounted) setState(() {});
    });
    _prefillFromCustomerProfile();
  }

  Future<void> _prefillFromCustomerProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('customer_token');
    final raw = prefs.getString('customer_data');
    if (token == null || token.isEmpty || raw == null) return;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        final name = data['fullName']?.toString().trim() ?? '';
        if (name.isNotEmpty) {
          _customer.text = name;
          if (_contactPerson.text.trim().isEmpty) {
            _contactPerson.text = name;
          }
        }
        final phone = data['phone']?.toString().trim() ?? '';
        if (phone.isNotEmpty) _phone.text = phone;
        final email = data['email']?.toString().trim() ?? '';
        if (email.isNotEmpty) _email.text = email;
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _eventTitle.dispose();
    _customer.dispose();
    _contactPerson.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    _guests.dispose();
    _landingPax.dispose();
    _paxBuffer.dispose();
    _dateController.dispose();
    _timeController.dispose();
    _endTimeController.dispose();
    _notesController.dispose();
    _eventCityController.dispose();
    _foodTastingDateController.dispose();
    _foodTastingTimeController.dispose();
    _designPromptController.dispose();
    _inquiryEventTypeOtherController.dispose();
    _macrinaPalette.dispose();
    _macrinaTheme.dispose();
    _eventTypeOtherController.dispose();
    _styleOtherController.dispose();
    _moodOtherController.dispose();
    _colorOtherController.dispose();
    _decorOtherController.dispose();
    _scheduleConflictDebounce?.cancel();
    super.dispose();
  }

  String? _resolvedCategory(String? selected, TextEditingController other) {
    if (selected == null || selected.isEmpty) return null;
    if (selected == 'Other') {
      final t = other.text.trim();
      return t.isEmpty ? 'Other' : t;
    }
    return selected;
  }

  static const Map<String, List<String>> _eventThemeDecorMap = {
    'cinderella': [
      'princess figure wearing royal blue dress',
      'royal blue drapery',
      'glass slipper centerpiece',
      'castle arch backdrop',
      'crystal chandeliers',
    ],
    'rustic': ['wooden tables', 'warm string lights', 'greenery centerpieces'],
    'modern luxury': [
      'gold accents',
      'marble decor',
      'minimalist floral arrangements',
    ],
    'luxury': [
      'crystal chandeliers',
      'white floral centerpieces',
      'gold accents',
      'cream drapery',
    ],
  };

  List<String> _eventThemeDecorFor(String? value) {
    final lookup = (value ?? '').toLowerCase();
    return [
      for (final entry in _eventThemeDecorMap.entries)
        if (lookup.contains(entry.key)) ...entry.value,
    ];
  }

  List<String> _resolvedMultiSelectWithOther(
    List<String> selected,
    TextEditingController other,
  ) {
    final values = selected.where((value) => value != 'Other').toList();
    if (selected.contains('Other')) {
      final custom = other.text.trim();
      if (custom.isNotEmpty) values.add(custom);
    }
    return values;
  }

  String get _resolvedInquiryEventType {
    if (_eventType != 'Other') return _eventType;
    final custom = _inquiryEventTypeOtherController.text.trim();
    return custom.isEmpty ? 'Other' : custom;
  }

  bool get _isCateringWithEventStyling {
    return isInquiryCateringWithEventStyling(_inquiryTypeLabel) ||
        _serviceType == 'catering+event';
  }

  String get _inquiryTypeLabel {
    if (_serviceType == 'catering+event') {
      return kInquiryTypeCateringWithEventStyling;
    }
    return inquiryTypeForLandingPax(int.tryParse(_guests.text.trim()) ?? 0);
  }

  int get _paxBufferValue {
    final n = int.tryParse(_paxBuffer.text.trim()) ?? 0;
    return n < 0 ? 0 : n;
  }

  /// Guest count used for per-pax add-on charges (matches handoff billable guests).
  int get _billableGuestCountForPricing {
    final g = int.tryParse(_guests.text.trim()) ?? 0;
    return g <= 0 ? 0 : g;
  }

  void _syncInquiryPackageFromGuestCount() {
    final pax = int.tryParse(_guests.text.trim()) ?? 0;
    if (pax >= kInquiryLandingEventStylingMinPax) {
      _serviceType = 'catering+event';
      _serviceIncluded = 'yes';
    } else if (pax > 0) {
      // Below 50: catering-only package; styling is an opt-in surcharge.
      _serviceType = 'catering';
    }
  }

  int? _parseTimeOfDayMinutes(String raw) {
    final t = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (t.isEmpty) return null;
    try {
      final dt = DateFormat('h:mm a').parse(t.replaceAllMapped(
        RegExp(r'^(\d{1,2}:\d{2})(AM|PM)$', caseSensitive: false),
        (m) => '${m[1]} ${m[2]}',
      ));
      return dt.hour * 60 + dt.minute;
    } catch (_) {}
    final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(t);
    if (m == null) return null;
    final hh = int.tryParse(m.group(1)!);
    final mm = int.tryParse(m.group(2)!);
    if (hh == null || mm == null || hh > 23 || mm > 59) return null;
    return hh * 60 + mm;
  }

  bool _isDateTimePast(String dateYmd, String timeRaw) {
    final mins = _parseTimeOfDayMinutes(timeRaw);
    if (mins == null) return false;
    final parts = dateYmd.split('-');
    if (parts.length != 3) return false;
    final y = int.tryParse(parts[0]);
    final mo = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || mo == null || d == null) return false;
    final dt = DateTime(y, mo, d, mins ~/ 60, mins % 60);
    return dt.isBefore(DateTime.now());
  }

  void _scheduleConflictRefresh() {
    _scheduleConflictDebounce?.cancel();
    _scheduleConflictDebounce = Timer(const Duration(milliseconds: 450), () async {
      final slots = _buildScheduleSlotsForApi();
      final windows =
          slots
              .where(
                (s) =>
                    '${s['date']}'.trim().isNotEmpty &&
                    '${s['startTime']}'.trim().isNotEmpty &&
                    '${s['endTime']}'.trim().isNotEmpty,
              )
              .map(
                (s) => {
                  'date': '${s['date']}'.trim(),
                  'from': '${s['startTime']}'.trim(),
                  'to': '${s['endTime']}'.trim(),
                },
              )
              .toList();
      if (!mounted) return;
      if (windows.isEmpty) {
        setState(() => _scheduleConflictCount = 0);
        return;
      }
      final n = await PublicEventsApi.instance.countCateringScheduleConflicts(
        windows,
      );
      if (mounted) setState(() => _scheduleConflictCount = n);
    });
  }

  List<Map<String, dynamic>> _buildScheduleSlotsForApi() {
    final slots = <Map<String, dynamic>>[
      {
        'date': _dateController.text.trim(),
        'startTime': _timeController.text.trim(),
        'endTime': _endTimeController.text.trim(),
      },
    ];
    for (final slot in _extraScheduleSlots) {
      slots.add({
        'date': (slot['date'] ?? '').trim(),
        'startTime': (slot['startTime'] ?? '').trim(),
        'endTime': (slot['endTime'] ?? '').trim(),
      });
    }
    return slots
        .where(
          (slot) =>
              '${slot['date']}'.trim().isNotEmpty ||
              '${slot['startTime']}'.trim().isNotEmpty ||
              '${slot['endTime']}'.trim().isNotEmpty,
        )
        .toList();
  }

  List<Map<String, dynamic>> _buildInquiryCostBreakdown() {
    final guestCount = int.tryParse(_guests.text.trim()) ?? 0;
    return buildInquiryCostBreakdownLines(
      guestCount: guestCount,
      paxBuffer: _paxBufferValue,
      menuModificationsExtra: _menuAdditionalChargeTotal(),
      inquiryType: _inquiryTypeLabel,
      serviceIncluded: _isCateringWithEventStyling ? 'yes' : _serviceIncluded,
    );
  }

  Map<String, MenuDish> get _activeDishById => {
    for (final dish in MenuStore.instance.activeDishes) dish.id: dish,
  };

  List<Map<String, dynamic>> _setMenuAdditionalChargeRows() {
    if (_menuSelections.isEmpty) return const [];
    final block = _menuSelections.first;
    if ((block['kind'] as String? ?? 'custom') != 'set') return const [];
    final selectedIds =
        (block['dishIds'] as List<dynamic>? ?? const [])
            .map((id) => id.toString())
            .where((id) => id.isNotEmpty)
            .toList();
    final originalIds =
        (block['originalDishIds'] as List<dynamic>? ?? const [])
            .map((id) => id.toString())
            .where((id) => id.isNotEmpty)
            .toSet();
    final originalCount =
        (block['originalDishCount'] as num?)?.toInt() ?? originalIds.length;
    final overage = selectedIds.length - originalCount;
    if (overage <= 0) return const [];
    final dishById = _activeDishById;
    final addedIds = selectedIds
        .where((id) => !originalIds.contains(id))
        .take(overage);
    return addedIds.map((id) {
      final dish = dishById[id];
      final amount = dish?.additionalChargeAmount ?? 0;
      return {'dishId': id, 'dishName': dish?.name ?? id, 'amount': amount};
    }).toList();
  }

  double _menuAdditionalChargeTotal() {
    final guests = _billableGuestCountForPricing;
    if (guests <= 0) return 0;
    final perPax = _setMenuAdditionalChargeRows().fold<double>(
      0,
      (sum, row) => sum + ((row['amount'] as num?)?.toDouble() ?? 0),
    );
    return perPax * guests;
  }

  double _estimateMenuCost() {
    return sumInquiryCostBreakdown(_buildInquiryCostBreakdown());
  }

  Future<void> _showOrderSummaryAndConfirm() async {
    final guestCount = int.tryParse(_guests.text.trim()) ?? 0;
    final estimated = _estimateMenuCost();
    final breakdown = _buildInquiryCostBreakdown();

    final confirmed = await showAntdModal<bool>(
      context: context,
      title: 'Confirm your inquiry',
      maxWidth: 520,
      barrierDismissible: false,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Package: ${inquiryTypeDisplayLabel(_inquiryTypeLabel)}'),
          Text('Event: ${_eventTitle.text.trim().isEmpty ? _customer.text.trim() : _eventTitle.text.trim()}'),
          Text('Customer: ${_customer.text.trim()}'),
          Text('Guests: $guestCount'),
          if (_paxBufferValue > 0) Text('Pax buffer: $_paxBufferValue'),
          const SizedBox(height: 12),
          const Text(
            'Estimate (final quote may differ):',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          for (final line in breakdown)
            Text(
              '${line['label']}: ₱${((line['amount'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}'
              '${line['detail'] != null ? ' (${line['detail']})' : ''}',
            ),
          const SizedBox(height: 8),
          Text(
            'Estimated total: ₱${estimated.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Text(
            'By confirming, you submit this inquiry to our team for review.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
        ],
      ),
      actions: [
        AntdCancelButton(
          label: 'Go back',
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AntdPrimaryButton(
          label: 'Confirm & submit',
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );

    if (confirmed == true) {
      await _submitInquiry();
    }
  }

  Future<void> _submitInquiry() async {
    if (!_validateAllForSubmit()) return;
    if (!mounted) return;

    setState(() => _submitting = true);

    try {
      final guestCount = int.tryParse(_guests.text.trim()) ?? 0;
      final scheduleSlots = _buildScheduleSlotsForApi();
      final costBreakdown = _buildInquiryCostBreakdown();

      final payload = <String, dynamic>{
        'orderType':
            _isCateringWithEventStyling ? 'catering_event' : 'catering',
        'inquiryType': _inquiryTypeLabel,
        'serviceIncluded':
            _isCateringWithEventStyling ? 'yes' : _serviceIncluded,
        'eventTitle':
            !_isCateringWithEventStyling
                ? _customer.text.trim()
                : _eventTitle.text.trim(),
        'eventType': _resolvedInquiryEventType,
        'formalityLevel': _formality,
        'eventSetting': _eventSetting,
        'eventCity': _eventCityController.text.trim(),
        'customerName': _customer.text.trim(),
        'contactPerson': _contactPerson.text.trim(),
        'contactNumber': _phone.text.trim(),
        'emailAddress': _email.text.trim(),
        'address': _address.text.trim(),
        if (_addressLat != null) 'addressLat': _addressLat,
        if (_addressLng != null) 'addressLng': _addressLng,
        'guestCount': guestCount,
        'paxBuffer': _paxBufferValue,
        'scheduleSlots': scheduleSlots,
        'menu': _buildMenuForApi(),
        'curateOwnMenu': !_suggestMenu,
        'menuSuggestionNote': _suggestMenu ? 'Suggest me a menu instead' : '',
        'selectedSetMenu':
            _menuSelections.isNotEmpty
                ? (_menuSelections.first['setMenuName'] ?? '').toString()
                : '',
        'menuModifications':
            _menuSelections.isNotEmpty
                ? (_menuSelections.first['additionalChargeRows'] ??
                    _setMenuAdditionalChargeRows())
                : const [],
        'estimatedTotal': _estimateMenuCost(),
        'costBreakdown': costBreakdown,
        'foodTastingRequested': _foodTastingRequested,
        if (_foodTastingRequested) ...{
          'foodTastingDate': _foodTastingDateController.text.trim(),
          'foodTastingTime': _foodTastingTimeController.text.trim(),
        },
        'allergens': _allergensSerialized.trim(),
        'guestAllergens': _allergensSerialized.trim(),
        'note': _notesController.text.trim(),
        'source': 'web',
      };
      final themeDesign = _buildThemeDesignForApi();
      if (themeDesign != null) {
        payload['themeDesign'] = themeDesign;
      }

      final submitted = await PublicEventsApi.instance.submitOnlineInquiry(
        payload: payload,
      );

      if (mounted) {
        showAntdMessage(
          context,
          'Inquiry submitted successfully! We\'ll contact you soon.',
        );
        final submittedId =
            (submitted['cateringId'] ?? submitted['catering_id'] ?? '')
                .toString();
        _clearForm();
        setState(() {
          _submittedCateringId = submittedId.isEmpty ? null : submittedId;
          _wizardStep = 3;
          _formPhase = 0;
        });
      }
    } catch (e) {
      if (mounted) {
        showAntdMessage(
          context,
          'Failed to submit inquiry: $e',
          type: AntdMessageType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  bool _validatePhase0MainForm() {
    setState(() {
      _fieldErrors.clear();
      _venueFieldError = null;
    });
    void err(String k, String m) => _fieldErrors[k] = m;

    if (_isCateringWithEventStyling && _eventTitle.text.trim().isEmpty) {
      err('eventTitle', 'Please enter an event title');
    }
    if (_eventType == 'Other' &&
        _inquiryEventTypeOtherController.text.trim().isEmpty) {
      err('eventTypeOther', 'Please specify the event type');
    }
    if (_customer.text.trim().isEmpty)
      err('customer', 'Please enter your name');
    if (_contactPerson.text.trim().isEmpty)
      err('contactPerson', 'Please enter a contact person');
    if (_phone.text.trim().isEmpty) err('phone', 'Please enter a phone number');
    if (_email.text.trim().isEmpty) {
      err('email', 'Please enter an email address');
    } else if (!_email.text.contains('@')) {
      err('email', 'Enter a valid email address');
    }
    final guestCount = int.tryParse(_guests.text.trim()) ?? 0;
    if (guestCount < kMinCateringOnlyPax) {
      err(
        'guests',
        'Enter at least $kMinCateringOnlyPax guests',
      );
    }
    if (_address.text.trim().isEmpty) {
      err('address', 'Please enter the event address');
    }
    if (_dateController.text.trim().isEmpty)
      err('date', 'Please select an event date');
    if (_timeController.text.trim().isEmpty) {
      err('time', 'Please select an event start time');
    }
    if (_endTimeController.text.trim().isEmpty) {
      err('endTime', 'Please select an event end time');
    } else {
      final startMins = _parseTimeOfDayMinutes(_timeController.text);
      final endMins = _parseTimeOfDayMinutes(_endTimeController.text);
      if (startMins != null && endMins != null && endMins <= startMins) {
        err('endTime', 'End time must be after start time');
      }
    }
    final dateYmd = _dateController.text.trim();
    if (dateYmd.isNotEmpty &&
        _timeController.text.trim().isNotEmpty &&
        _isDateTimePast(dateYmd, _timeController.text)) {
      err('time', 'Start time cannot be in the past');
    }
    if (dateYmd.isNotEmpty &&
        _endTimeController.text.trim().isNotEmpty &&
        _isDateTimePast(dateYmd, _endTimeController.text) &&
        _fieldErrors['endTime'] == null) {
      err('endTime', 'End time cannot be in the past');
    }
    if (!_suggestMenu && _menuSelections.isEmpty) {
      err('menu', 'Choose your menu using the options below');
    } else if (!_suggestMenu) {
      final block = _menuSelections.first;
      final kind = block['kind'] as String? ?? 'custom';
      if (kind == 'custom') {
        final n = (block['dishIds'] as List<dynamic>?)?.length ?? 0;
        if (n < 4 || n > 8) {
          err('menu', 'Select between 4 and 8 dishes for your custom menu');
        }
      }
    }
    if (_foodTastingRequested) {
      if (_foodTastingDateController.text.trim().isEmpty) {
        err('foodTasting', 'Choose a food tasting date');
      } else if (_foodTastingTimeController.text.trim().isEmpty) {
        err('foodTasting', 'Choose a food tasting time');
      }
    }
    if (_serviceType == 'catering') {
      final guests = int.tryParse(_guests.text.trim()) ?? 0;
      if (guests > 0 &&
          guests < kInquiryLandingEventStylingMinPax &&
          _serviceIncluded != 'yes' &&
          _serviceIncluded != 'no') {
        err(
          'cateringService',
          'Please choose whether to include event styling',
        );
      }
    }

    setState(() {});
    return !_fieldErrors.values.any((e) => e != null && e.trim().isNotEmpty);
  }

  bool _validateMacrinaStep() {
    setState(() {
      _fieldErrors.remove('macrinaPalette');
      _fieldErrors.remove('macrinaTheme');
    });
    var ok = true;
    if (_macrinaPalette.text.trim().isEmpty) {
      _fieldErrors['macrinaPalette'] = 'Describe your color palette';
      ok = false;
    }
    if (_macrinaTheme.text.trim().isEmpty) {
      _fieldErrors['macrinaTheme'] = 'Describe your theme';
      ok = false;
    }
    setState(() {});
    return ok;
  }

  bool _validateAllForSubmit() {
    if (!_validatePhase0MainForm()) return false;
    if (!_isCateringWithEventStyling) return true;
    if (_eventDesignMode == 'macrina') {
      return _validateMacrinaStep();
    }
    return true;
  }

  void _goNextFromMainForm() {
    if (!_validatePhase0MainForm()) return;
    if (_isCateringWithEventStyling) {
      setState(() => _formPhase = 1);
    } else {
      _showOrderSummaryAndConfirm();
    }
  }

  void _goNextFromDesignChoice() {
    if (_eventDesignMode == null) {
      setState(
        () =>
            _fieldErrors['eventDesignMode'] =
                'Please choose who will design your event',
      );
      return;
    }
    setState(() {
      _fieldErrors.remove('eventDesignMode');
      _formPhase = 2;
      if (_eventDesignMode == 'customer') {
        _wantsCustomDesign = true;
        _selectedEventType =
            _selectedEventType ?? _mapInquiryEventTypeToDesign(_eventType);
      } else {
        _wantsCustomDesign = false;
        _clearGeneratedDesignOutputs();
      }
    });
  }

  /// Event design payload for staff "view details" (AI image vs Macrina text inspiration).
  Map<String, dynamic>? _buildThemeDesignForApi() {
    final note = _notesController.text.trim();
    Map<String, dynamic>? base;
    if (_isCateringWithEventStyling) {
      if (_eventDesignMode == 'macrina') {
        base = {
          'eventDesignSource': 'macrina',
          'macrinaColorPalette': _macrinaPalette.text.trim(),
          'macrinaTheme': _macrinaTheme.text.trim(),
          'serviceType':
              _isCateringWithEventStyling ? 'catering+event' : _serviceType,
          'eventSetting': _eventSetting,
          'event_setting': _eventSetting,
        };
      } else if (_eventDesignMode == 'customer') {
        final style =
            _resolvedCategory(_selectedStyle, _styleOtherController) ?? '';
        final mood =
            _resolvedCategory(_selectedMood, _moodOtherController) ?? '';
        final eventType =
            _resolvedCategory(_selectedEventType, _eventTypeOtherController) ??
            '';
        final colors = _resolvedMultiSelectWithOther(
          _selectedColors,
          _colorOtherController,
        );
        final decor = _resolvedMultiSelectWithOther(
          _selectedDecor,
          _decorOtherController,
        );
        base = {
          'eventDesignSource': 'customer_ai',
          'wantsCustomDesign': _wantsCustomDesign,
          'serviceType':
              _isCateringWithEventStyling ? 'catering+event' : _serviceType,
          'eventSetting': _eventSetting,
          'event_setting': _eventSetting,
          if (_generatedImageUrl != null &&
              _generatedImageUrl!.trim().isNotEmpty)
            'generatedImageUrl': _generatedImageDisplayUrl(_generatedImageUrl!),
          if (_generatedDesignPrompt != null &&
              _generatedDesignPrompt!.trim().isNotEmpty)
            'generatedPrompt': _generatedDesignPrompt!.trim(),
          if (eventType.isNotEmpty) 'eventDesignEventType': eventType,
          if (style.isNotEmpty) 'style': style,
          if (mood.isNotEmpty) 'mood': mood,
          if (colors.isNotEmpty) 'colorPalette': colors,
          if (decor.isNotEmpty) 'decorElements': decor,
          if (_designPromptController.text.trim().isNotEmpty)
            'customInstructions': _designPromptController.text.trim(),
        };
      }
    }
    if (note.isEmpty) return base;
    return {...?base, 'customerNote': note, 'note': note};
  }

  /// API `/api/online-inquiries` menu: inquiry blocks (set name + dish names) or flat rows.
  List<Map<String, dynamic>> _buildMenuForApi() {
    if (_suggestMenu) {
      return [
        {
          'kind': 'suggest',
          'dishName': 'Suggest me a menu instead',
          'dishNames': ['Suggest me a menu instead'],
        },
      ];
    }
    if (_menuSelections.isEmpty) {
      return [
        {'dishName': 'Customer will confirm menu details with coordinator'},
      ];
    }
    final additionalRows = _setMenuAdditionalChargeRows();
    final additionalTotal = _menuAdditionalChargeTotal();
    return _menuSelections.map((block) {
      final out = Map<String, dynamic>.from(block);
      if ((out['kind'] as String? ?? '') == 'set') {
        out['additionalChargeRows'] = additionalRows;
        out['additionalChargeTotal'] = additionalTotal;
      }
      return out;
    }).toList();
  }

  void _clearForm() {
    setState(() {
      _eventTitle.clear();
      _customer.clear();
      _contactPerson.clear();
      _phone.clear();
      _email.clear();
      _address.clear();
      _addressLat = null;
      _addressLng = null;
      _guests.clear();
      _landingPax.clear();
      _paxBuffer.clear();
      _dateController.clear();
      _timeController.clear();
      _endTimeController.clear();
      _notesController.clear();
      _eventCityController.clear();
      _eventSetting = 'open';
      _foodTastingRequested = false;
      _foodTastingDateController.clear();
      _foodTastingTimeController.clear();
      _extraScheduleSlots.clear();
      _suggestMenu = false;
      _customerSameAsContact = false;
      _eventType = 'Birthday';
      _inquiryEventTypeOtherController.clear();
      _formality = 'casual';
      _serviceType = 'catering';
      _serviceIncluded = 'no';
      _wizardStep = 0;
      _formPhase = 0;
      _eventDesignMode = null;
      _macrinaPalette.clear();
      _macrinaTheme.clear();
      _fieldErrors.clear();
      _venueFieldError = null;
      _genAiError = null;
      _scheduleConflictCount = 0;
      _menuPrefTabIndex = 0;
      _selectedDishIds.clear();
      _menuSelections.clear();
      // Reset event design
      _wantsCustomDesign = false;
      _selectedEventType = null;
      _selectedStyle = null;
      _selectedMood = null;
      _selectedColors.clear();
      _selectedDecor.clear();
      _colorOtherController.clear();
      _decorOtherController.clear();
      _designPromptController.clear();
      _venuePhotoBase64 = null;
      _clearGeneratedDesignOutputs();
    });
  }

  /// Clears AI outputs so a new venue reference starts a fresh generation set.
  void _clearGeneratedDesignOutputs() {
    _generatedImageUrl = null;
    _generatedDesignPrompt = null;
    _generatedImageHistory.clear();
    _genAiError = null;
  }

  void _applyMenuSelections(List<Map<String, dynamic>> blocks) {
    final ids = <String>{};
    for (final b in blocks) {
      final list = b['dishIds'] as List<dynamic>? ?? const [];
      for (final id in list) {
        if (id is String && id.isNotEmpty) ids.add(id);
      }
    }
    setState(() {
      _menuSelections
        ..clear()
        ..addAll(blocks.map((e) => Map<String, dynamic>.from(e)));
      _selectedDishIds
        ..clear()
        ..addAll(ids);
    });
  }

  Set<String> _selectedAllergenLabels() {
    return _allergensSerialized
        .split(',')
        .map((s) => s.trim().toLowerCase())
        .where((s) => s.isNotEmpty)
        .toSet();
  }

  bool _dishConflictsSelectedAllergens(MenuDish dish, Set<String> allergens) {
    if (allergens.isEmpty || dish.allergens.trim().isEmpty) return false;
    return dish.allergens
        .split(',')
        .map((s) => s.trim().toLowerCase())
        .where((s) => s.isNotEmpty)
        .any(allergens.contains);
  }

  void _pruneMenuSelectionsForCurrentAllergens() {
    final allowedDishes = _inquiryCateringDishes();
    final allowedIds = allowedDishes.map((d) => d.id).toSet();
    final dishNameById = {for (final d in allowedDishes) d.id: d.name};
    final pruned = <Map<String, dynamic>>[];
    final selectedIds = <String>{};

    for (final block in _menuSelections) {
      final ids =
          (block['dishIds'] as List<dynamic>? ?? const [])
              .map((id) => id.toString())
              .where((id) => allowedIds.contains(id))
              .toList();
      if (ids.isEmpty) continue;

      selectedIds.addAll(ids);
      pruned.add({
        ...Map<String, dynamic>.from(block),
        'dishIds': ids,
        'dishNames': ids.map((id) => dishNameById[id] ?? id).toList(),
      });
    }

    _menuSelections
      ..clear()
      ..addAll(pruned);
    _selectedDishIds
      ..clear()
      ..addAll(selectedIds);
  }

  void _switchMenuPrefTab(int index) {
    setState(() {
      _menuPrefTabIndex = index;
      _menuSelections.clear();
      _selectedDishIds.clear();
      _fieldErrors.remove('menu');
    });
  }

  List<MenuDish> _inquiryCateringDishes() {
    final selectedAllergens = _selectedAllergenLabels();
    return MenuStore.instance.activeDishes
        .where(
          (d) =>
              d.category.toLowerCase().trim() == 'catering' &&
              !d.archived &&
              d.available &&
              !_dishConflictsSelectedAllergens(d, selectedAllergens),
        )
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  void _onInlineMenuSelectionChanged(List<Map<String, dynamic>> blocks) {
    _applyMenuSelections(blocks);
    if (_fieldErrors.containsKey('menu')) {
      setState(() => _fieldErrors.remove('menu'));
    }
  }

  static const List<String> _inquiryEventTypes = [
    "Birthday",
    "Wedding",
    "Debut",
    "Baptism",
    "Corporate",
    "Sports",
    "Government",
    "Show",
    "Educational",
    "Reunion",
    "Gala",
    "Dinner",
    "Other",
  ];

  Widget _inquirySectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        title,
        style: GoogleFonts.getFont(
          _primaryFont,
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF1E1E1E),
        ),
      ),
    );
  }

  Widget _responsiveTwoCol(BuildContext context, Widget left, Widget right) {
    if (isMobile(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [left, const SizedBox(height: 16), right],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: 16),
        Expanded(child: right),
      ],
    );
  }

  Widget _responsiveThreeCol(
    BuildContext context,
    Widget first,
    Widget second,
    Widget third,
  ) {
    if (isMobile(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          first,
          const SizedBox(height: 16),
          second,
          const SizedBox(height: 16),
          third,
        ],
      );
    }
    if (isTablet(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: first),
              const SizedBox(width: 16),
              Expanded(child: second),
            ],
          ),
          const SizedBox(height: 16),
          third,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: first),
        const SizedBox(width: 16),
        Expanded(child: second),
        const SizedBox(width: 16),
        Expanded(child: third),
      ],
    );
  }

  String _mapInquiryEventTypeToDesign(String t) {
    if (t == 'Corporate Event') return 'Corporate';
    if (t == 'Anniversary' || t == 'Graduation') return 'Other';
    if (_eventTypes.contains(t)) return t;
    return 'Other';
  }

  Future<void> _pickEventAddressOnMap() async {
    final res = await showMapPicker(
      context: context,
      initialLatitude: _addressLat,
      initialLongitude: _addressLng,
      initialAddress: _address.text.isNotEmpty ? _address.text : null,
    );
    if (res == null || !mounted) return;
    setState(() {
      _address.text = res.address;
      _addressLat = res.latitude;
      _addressLng = res.longitude;
      _fieldErrors.remove('address');
    });
  }

  List<Widget> _buildPhase0Content(BuildContext context) {
    void onFieldChanged(String key) {
      if (_fieldErrors.containsKey(key)) {
        setState(() => _fieldErrors.remove(key));
      }
    }

    final eventTypeValue =
        _inquiryEventTypes.contains(_eventType)
            ? _eventType
            : _inquiryEventTypes.first;
    final isEventStyling = _isCateringWithEventStyling;
    final guestsNow = int.tryParse(_guests.text.trim()) ?? 0;
    final canPickEventPackage =
        guestsNow >= kInquiryLandingEventStylingMinPax;

    return [
      _inquirySectionTitle('Event Information'),
      const SizedBox(height: 12),
      const Text(
        'Service type',
        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: RadioListTile<String>(
              title: const Text(
                'Catering Only',
                style: TextStyle(fontSize: 14),
              ),
              value: 'catering',
              groupValue: _serviceType,
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _serviceType = value;
                    _formPhase = 0;
                    _eventDesignMode = null;
                    _fieldErrors.remove('eventTitle');
                  });
                }
              },
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            ),
          ),
          Expanded(
            child: RadioListTile<String>(
              title: Text(
                canPickEventPackage
                    ? 'Catering + Event Design'
                    : 'Event Design (50+ guests)',
                style: TextStyle(
                  fontSize: 14,
                  color: canPickEventPackage ? null : Colors.grey.shade500,
                ),
              ),
              value: 'catering+event',
              groupValue: _serviceType,
              onChanged:
                  canPickEventPackage
                      ? (value) {
                        if (value != null) {
                          setState(() {
                            _serviceType = value;
                            _selectedEventType = _mapInquiryEventTypeToDesign(
                              _eventType,
                            );
                          });
                        }
                      }
                      : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            ),
          ),
        ],
      ),
      if (!canPickEventPackage && guestsNow > 0) ...[
        const SizedBox(height: 4),
        Text(
          'Below $kInquiryLandingEventStylingMinPax guests, use Event styling (with surcharge) instead of the full event package.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
        ),
      ],
      const SizedBox(height: 20),
      _responsiveThreeCol(
        context,
        AntdFieldShell(
          label: 'Event Title',
          required: _serviceType != 'catering',
          errorText: _fieldErrors['eventTitle'],
          child: AntdOutlineInput(
            controller: _eventTitle,
            hintText:
                !isEventStyling
                    ? 'Not required for catering only'
                    : 'Enter event title',
            readOnly: !isEventStyling,
            onChanged: (_) => onFieldChanged('eventTitle'),
          ),
        ),
        AntdFieldShell(
          label: 'Event Type',
          required: true,
          child: DropdownButtonFormField<String>(
            value: eventTypeValue,
            isExpanded: true,
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            ),
            items:
                _inquiryEventTypes
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _eventType = value;
                _fieldErrors.remove('eventTypeOther');
                if (_serviceType == 'catering+event') {
                  _selectedEventType = _mapInquiryEventTypeToDesign(value);
                }
              });
            },
          ),
        ),
        AntdFieldShell(
          label: 'Formality',
          required: true,
          child: DropdownButtonFormField<String>(
            value: _formality,
            isExpanded: true,
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            ),
            items:
                ['casual', 'semi-formal', 'formal']
                    .map(
                      (l) => DropdownMenuItem(
                        value: l,
                        child: Text(l.toUpperCase()),
                      ),
                    )
                    .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _formality = v);
            },
          ),
        ),
      ),
      if (_eventType == 'Other') ...[
        const SizedBox(height: 16),
        AntdFieldShell(
          label: 'Custom Event Type',
          required: true,
          errorText: _fieldErrors['eventTypeOther'],
          child: AntdOutlineInput(
            controller: _inquiryEventTypeOtherController,
            hintText: 'Enter custom event type',
            onChanged: (_) => onFieldChanged('eventTypeOther'),
          ),
        ),
      ],
      const SizedBox(height: 32),
      _inquirySectionTitle('Contact Information'),
      const SizedBox(height: 8),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        value: _customerSameAsContact,
        title: const Text('Customer same as contact person'),
        onChanged: (value) {
          setState(() {
            _customerSameAsContact = value == true;
            if (_customerSameAsContact) {
              _customer.text = _contactPerson.text;
              _fieldErrors.remove('customer');
            }
          });
        },
      ),
      const SizedBox(height: 8),
      _responsiveThreeCol(
        context,
        AntdFieldShell(
          label: 'Customer Name',
          required: true,
          errorText: _fieldErrors['customer'],
          child: AntdOutlineInput(
            controller: _customer,
            hintText: 'Enter your name',
            readOnly: _customerSameAsContact,
            onChanged: (_) => onFieldChanged('customer'),
          ),
        ),
        AntdFieldShell(
          label: 'Contact Person',
          required: true,
          errorText: _fieldErrors['contactPerson'],
          child: AntdOutlineInput(
            controller: _contactPerson,
            hintText: 'Contact person name',
            onChanged: (v) {
              onFieldChanged('contactPerson');
              if (_customerSameAsContact) {
                setState(() => _customer.text = v);
              }
            },
          ),
        ),
        AntdFieldShell(
          label: 'Phone Number',
          required: true,
          errorText: _fieldErrors['phone'],
          child: AntdOutlineInput(
            controller: _phone,
            hintText: '09123456789',
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(11),
            ],
            onChanged: (_) => onFieldChanged('phone'),
          ),
        ),
      ),
      const SizedBox(height: 16),
      _responsiveThreeCol(
        context,
        AntdFieldShell(
          label: 'Email Address',
          required: true,
          errorText: _fieldErrors['email'],
          child: AntdOutlineInput(
            controller: _email,
            hintText: 'example@example.com',
            keyboardType: TextInputType.emailAddress,
            onChanged: (_) => onFieldChanged('email'),
          ),
        ),
        AntdFieldShell(
          label: 'Event Address',
          required: true,
          errorText: _fieldErrors['address'],
          child: VenueAutocompleteField(
            controller: _address,
            label: 'Venue name, street, city',
            onSelected: (_) => onFieldChanged('address'),
            onMapPickerPressed: _pickEventAddressOnMap,
          ),
        ),
        AntdFieldShell(
          label: 'Number of Guests',
          required: true,
          errorText: _fieldErrors['guests'],
          child: AntdOutlineInput(
            controller: _guests,
            hintText: 'Min $kMinCateringOnlyPax',
            keyboardType: TextInputType.number,
            onChanged: (_) {
              setState(() {
                _fieldErrors.remove('guests');
                _fieldErrors.remove('cateringService');
                _syncInquiryPackageFromGuestCount();
              });
            },
          ),
        ),
      ),
      const SizedBox(height: 16),
      AntdFieldShell(
        label: 'Pax buffer (optional)',
        child: AntdOutlineInput(
          controller: _paxBuffer,
          hintText: 'Extra pax on estimate only',
          keyboardType: TextInputType.number,
          onChanged: (_) => setState(() {}),
        ),
      ),
      if (_address.text.trim().isNotEmpty) ...[
        const SizedBox(height: 12),
        EventVenueMapPreview(address: _address.text.trim()),
      ],
      const SizedBox(height: 32),
      _inquirySectionTitle('Event Details'),
      const SizedBox(height: 16),
      _responsiveThreeCol(
        context,
        AntdFieldShell(
          label: 'Event Date',
          required: true,
          errorText: _fieldErrors['date'],
          child: AntdPickerInput(
            value: _dateController.text,
            hintText: 'YYYY-MM-DD',
            icon: Icons.calendar_today_outlined,
            onTap: () async {
              final now = DateTime.now();
              final pickedDate = await showDatePicker(
                context: context,
                initialDate: DateTime.tryParse(_dateController.text) ?? now,
                firstDate: now,
                lastDate: now.add(const Duration(days: 365 * 2)),
              );
              if (pickedDate != null) {
                setState(() {
                  _dateController.text = DateFormat(
                    'yyyy-MM-dd',
                  ).format(pickedDate);
                  _fieldErrors.remove('date');
                });
                _scheduleConflictRefresh();
              }
            },
          ),
        ),
        AntdFieldShell(
          label: 'Event Time',
          required: true,
          errorText: _fieldErrors['time'],
          child: AntdPickerInput(
            value: _timeController.text,
            hintText: 'e.g. 6:00 PM',
            icon: Icons.access_time,
            onTap: () async {
              TimeOfDay initialTime = const TimeOfDay(hour: 10, minute: 0);
              if (_timeController.text.trim().isNotEmpty) {
                try {
                  initialTime = TimeOfDay.fromDateTime(
                    DateFormat('h:mm a').parse(_timeController.text),
                  );
                } catch (_) {}
              }
              final pickedTime = await showTimePicker(
                context: context,
                initialTime: initialTime,
              );
              if (pickedTime != null) {
                setState(() {
                  _timeController.text = pickedTime
                      .format(context)
                      .replaceAll(' ', '');
                  _fieldErrors.remove('time');
                });
                _scheduleConflictRefresh();
              }
            },
          ),
        ),
        AntdFieldShell(
          label: 'End Time',
          required: true,
          errorText: _fieldErrors['endTime'],
          child: AntdPickerInput(
            value: _endTimeController.text,
            hintText: 'e.g. 10:00 PM',
            icon: Icons.access_time,
            onTap: () async {
              TimeOfDay initialTime = const TimeOfDay(hour: 14, minute: 0);
              if (_endTimeController.text.trim().isNotEmpty) {
                try {
                  initialTime = TimeOfDay.fromDateTime(
                    DateFormat('h:mm a').parse(_endTimeController.text),
                  );
                } catch (_) {}
              }
              final pickedTime = await showTimePicker(
                context: context,
                initialTime: initialTime,
              );
              if (pickedTime != null) {
                setState(() {
                  _endTimeController.text = pickedTime
                      .format(context)
                      .replaceAll(' ', '');
                  _fieldErrors.remove('endTime');
                });
                _scheduleConflictRefresh();
              }
            },
          ),
        ),
      ),
      const SizedBox(height: 12),
      AntdFieldShell(
        label: 'Notes (optional)',
        child: AntdOutlineInput(
          controller: _notesController,
          hintText: 'Special requests, dietary notes, or other details',
          maxLines: 3,
        ),
      ),
      const SizedBox(height: 12),
      Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          onPressed:
              () => setState(
                () => _extraScheduleSlots.add({
                  'date': '',
                  'startTime': '',
                  'endTime': '',
                }),
              ),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add another day / schedule'),
        ),
      ),
      for (var i = 0; i < _extraScheduleSlots.length; i++) ...[
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextFormField(
                initialValue: _extraScheduleSlots[i]['date'],
                decoration: const InputDecoration(
                  labelText: 'Date (YYYY-MM-DD)',
                  border: OutlineInputBorder(),
                ),
                onChanged:
                    (value) => _extraScheduleSlots[i]['date'] = value.trim(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                initialValue: _extraScheduleSlots[i]['startTime'],
                decoration: const InputDecoration(
                  labelText: 'Start time',
                  border: OutlineInputBorder(),
                ),
                onChanged:
                    (value) =>
                        _extraScheduleSlots[i]['startTime'] = value.trim(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                initialValue: _extraScheduleSlots[i]['endTime'],
                decoration: const InputDecoration(
                  labelText: 'End time',
                  border: OutlineInputBorder(),
                ),
                onChanged:
                    (value) => _extraScheduleSlots[i]['endTime'] = value.trim(),
              ),
            ),
            IconButton(
              tooltip: 'Remove schedule',
              onPressed: () => setState(() => _extraScheduleSlots.removeAt(i)),
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ],
      const SizedBox(height: 16),
      _responsiveTwoCol(
        context,
        AntdFieldShell(
          label: 'Event City',
          child: AntdOutlineInput(
            controller: _eventCityController,
            hintText: 'City / municipality',
          ),
        ),
        AntdFieldShell(
          label: 'Event Setting',
          child: DropdownButtonFormField<String>(
            value:
                (_eventSetting == 'open' ||
                        _eventSetting == 'closed' ||
                        _eventSetting == 'mixed')
                    ? _eventSetting
                    : 'open',
            isExpanded: true,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'open', child: Text('Open')),
              DropdownMenuItem(value: 'closed', child: Text('Closed')),
              DropdownMenuItem(value: 'mixed', child: Text('Mixed')),
            ],
            onChanged:
                (value) => setState(() => _eventSetting = value ?? 'open'),
          ),
        ),
      ),
      if (_scheduleConflictCount > 0) ...[
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.amber.shade300),
          ),
          child: Text(
            'Schedule advisory: $_scheduleConflictCount overlapping window(s) with events already in processing. You can still submit — our team will confirm availability.',
            style: TextStyle(
              color: Colors.amber.shade900,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
      const SizedBox(height: 16),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        value: _foodTastingRequested,
        title: const Text('Request food tasting'),
        subtitle: const Text(
          'Optional: choose your preferred tasting date and time.',
        ),
        onChanged:
            (value) => setState(() => _foodTastingRequested = value == true),
      ),
      if (_foodTastingRequested) ...[
        const SizedBox(height: 8),
        _responsiveTwoCol(
          context,
          AntdFieldShell(
            label: 'Food tasting date',
            errorText: _fieldErrors['foodTasting'],
            child: AntdOutlineInput(
              controller: _foodTastingDateController,
              hintText: 'YYYY-MM-DD',
              onChanged: (_) => onFieldChanged('foodTasting'),
            ),
          ),
          AntdFieldShell(
            label: 'Food tasting time',
            child: AntdOutlineInput(
              controller: _foodTastingTimeController,
              hintText: 'e.g. 2:00PM',
              onChanged: (_) => onFieldChanged('foodTasting'),
            ),
          ),
        ),
      ],
      if (_serviceType == 'catering') ...[
        Builder(
          builder: (context) {
            final guests = int.tryParse(_guests.text.trim()) ?? 0;
            if (guests <= 0 || guests >= kInquiryLandingEventStylingMinPax) {
              return const SizedBox.shrink();
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    border: Border.all(color: Colors.orange.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.warning_amber,
                        color: Colors.orange.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Below $kInquiryLandingEventStylingMinPax guests, event styling adds ₱${kEventStylingSurchargePerPaxBelow50.toStringAsFixed(0)} per guest.',
                          style: TextStyle(
                            color: Colors.orange.shade800,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _inquirySectionTitle('Event styling'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text(
                          'Without',
                          style: TextStyle(fontSize: 14),
                        ),
                        value: 'no',
                        groupValue: _serviceIncluded,
                        onChanged: (v) {
                          setState(() {
                            _serviceIncluded = v ?? 'no';
                            _fieldErrors.remove('cateringService');
                          });
                        },
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text(
                          'With',
                          style: TextStyle(fontSize: 14),
                        ),
                        value: 'yes',
                        groupValue: _serviceIncluded,
                        onChanged: (v) {
                          setState(() {
                            _serviceIncluded = v ?? 'yes';
                            _fieldErrors.remove('cateringService');
                          });
                        },
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
                if (_serviceIncluded == 'yes')
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 8),
                    child: Text(
                      'Styling surcharge: ₱${(guests * kEventStylingSurchargePerPaxBelow50).toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: AntdTokens.warning,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                if (_fieldErrors['cateringService'] != null &&
                    _fieldErrors['cateringService']!.isNotEmpty)
                  Text(
                    _fieldErrors['cateringService']!,
                    style: const TextStyle(
                      color: Color(0xFFFF4D4F),
                      fontSize: 12,
                    ),
                  ),
                const SizedBox(height: 16),
              ],
            );
          },
        ),
      ],
      const SizedBox(height: 32),
      LayoutBuilder(
        builder: (context, constraints) {
          final useTwoColumns = constraints.maxWidth >= 820;
          final menuSelection = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _inquirySectionTitle('Menu preferences'),
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _suggestMenu,
                title: const Text('Suggest me a menu instead'),
                subtitle: const Text(
                  'Macrina\'s team can recommend dishes based on your event and allergens.',
                ),
                onChanged:
                    (value) => setState(() {
                      _suggestMenu = value == true;
                      if (_suggestMenu) {
                        _menuSelections.clear();
                        _selectedDishIds.clear();
                        _fieldErrors.remove('menu');
                      }
                    }),
              ),
              if (!_suggestMenu) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('I want to make my own menu'),
                      selected: _menuPrefTabIndex == 0,
                      selectedColor: AntdTokens.brandPrimary,
                      labelStyle: TextStyle(
                        color:
                            _menuPrefTabIndex == 0
                                ? AntdTokens.brandOnPrimary
                                : Colors.black87,
                        fontWeight:
                            _menuPrefTabIndex == 0
                                ? FontWeight.w700
                                : FontWeight.normal,
                      ),
                      onSelected: (_) => _switchMenuPrefTab(0),
                    ),
                    ChoiceChip(
                      label: const Text('Choose from Set Menu'),
                      selected: _menuPrefTabIndex == 1,
                      selectedColor: AntdTokens.brandPrimary,
                      labelStyle: TextStyle(
                        color:
                            _menuPrefTabIndex == 1
                                ? AntdTokens.brandOnPrimary
                                : Colors.black87,
                        fontWeight:
                            _menuPrefTabIndex == 1
                                ? FontWeight.w700
                                : FontWeight.normal,
                      ),
                      onSelected: (_) => _switchMenuPrefTab(1),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ListenableBuilder(
                  listenable: Listenable.merge([
                    MenuStore.instance,
                    SetMenuStore.instance,
                  ]),
                  builder: (context, _) {
                    final loading =
                        MenuStore.instance.isLoading ||
                        SetMenuStore.instance.isLoading;
                    if (loading &&
                        _inquiryCateringDishes().isEmpty &&
                        SetMenuStore.instance.activeSetMenus.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final additionalTotal = _menuAdditionalChargeTotal();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        InquiryMenuPicker(
                          key: ValueKey<int>(_menuPrefTabIndex),
                          embedded: true,
                          tabIndex: _menuPrefTabIndex,
                          cateringDishes: _inquiryCateringDishes(),
                          setMenus: SetMenuStore.instance.activeSetMenus,
                          initialSelections: List<Map<String, dynamic>>.from(
                            _menuSelections,
                          ),
                          mode: InquiryMenuPickerMode.inquiryExclusive,
                          minCustomDishes: 4,
                          maxCustomDishes: 8,
                          externalError: _fieldErrors['menu'],
                          onSelectionChanged: _onInlineMenuSelectionChanged,
                        ),
                        if (additionalTotal > 0) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Extra set-menu dish fees: ₱${additionalTotal.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: AntdTokens.warning,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ],
            ],
          );
          final allergenSelection = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _inquirySectionTitle('Allergens'),
              const SizedBox(height: 8),
              AntdFieldShell(
                label: 'Food allergens to avoid',
                child: AllergenSelectorField(
                  initialSerialized: _allergensSerialized,
                  onChanged: (s) {
                    setState(() {
                      _allergensSerialized = s;
                      _pruneMenuSelectionsForCurrentAllergens();
                      _fieldErrors.remove('menu');
                    });
                  },
                ),
              ),
            ],
          );

          if (!useTwoColumns) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                menuSelection,
                const SizedBox(height: 16),
                allergenSelection,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: menuSelection),
              const SizedBox(width: 24),
              Expanded(flex: 2, child: allergenSelection),
            ],
          );
        },
      ),
      const SizedBox(height: 24),
      ..._buildPhase0Footer(),
    ];
  }

  List<Widget> _buildPhase0Footer() {
    return [
      SizedBox(
        width: double.infinity,
        child: AntdPrimaryButton(
          label: _serviceType == 'catering+event' ? 'NEXT' : 'SUBMIT INQUIRY',
          loading: _submitting && _serviceType == 'catering',
          onPressed: _submitting ? null : _goNextFromMainForm,
        ),
      ),
    ];
  }

  void _openZoomableImage({required Widget image}) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) {
        return Dialog(
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
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(ctx).pop(),
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                ),
              ),
              const Positioned(
                left: 0,
                right: 0,
                bottom: 12,
                child: Text(
                  'Pinch or scroll to zoom',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTappableImagePreview({
    required Widget child,
    required VoidCallback onTap,
    String? hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              children: [
                child,
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
                        Icon(Icons.zoom_in, color: Colors.white, size: 16),
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
        ),
        if (hint != null) ...[
          const SizedBox(height: 4),
          Text(
            hint,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ],
    );
  }

  Widget _buildEventDesignModeCard({
    required String value,
    required String title,
    required String subtitle,
    required IconData icon,
    bool expand = true,
  }) {
    final selected = _eventDesignMode == value;
    final card = InkWell(
      onTap: () {
        setState(() {
          _eventDesignMode = value;
          _fieldErrors.remove('eventDesignMode');
        });
      },
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:
              selected
                  ? AntdTokens.brandPrimary.withValues(alpha: 0.12)
                  : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AntdTokens.brandPrimary : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color:
                      selected
                          ? AntdTokens.brandOnPrimary
                          : Colors.grey.shade700,
                ),
                const Spacer(),
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color:
                      selected ? AntdTokens.brandPrimary : Colors.grey.shade500,
                  size: 22,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: AntdTokens.brandOnPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
    return expand ? Expanded(child: card) : card;
  }

  List<Widget> _buildPhase1Content() {
    final modeRow = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildEventDesignModeCard(
          value: 'macrina',
          title: 'Have Macrina\'s design my event',
          subtitle:
              'Share your palette and theme; our team will propose a look.',
          icon: Icons.palette_outlined,
        ),
        const SizedBox(width: 12),
        _buildEventDesignModeCard(
          value: 'customer',
          title: 'I want to design my event',
          subtitle: 'Use AI to explore styles, then submit with your inquiry.',
          icon: Icons.auto_awesome_outlined,
        ),
      ],
    );

    return [
      _inquirySectionTitle('Event design'),
      const SizedBox(height: 8),
      Text(
        'Before we submit, tell us how you want to approach your event look and feel.',
        style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
      ),
      const SizedBox(height: 20),
      if (isMobile(context))
        Column(
          children: [
            _buildEventDesignModeCard(
              value: 'macrina',
              title: 'Have Macrina\'s design my event',
              subtitle:
                  'Share your palette and theme; our team will propose a look.',
              icon: Icons.palette_outlined,
              expand: false,
            ),
            const SizedBox(height: 12),
            _buildEventDesignModeCard(
              value: 'customer',
              title: 'I want to design my event',
              subtitle:
                  'Use AI to explore styles, then submit with your inquiry.',
              icon: Icons.auto_awesome_outlined,
              expand: false,
            ),
          ],
        )
      else
        modeRow,
      if (_fieldErrors['eventDesignMode'] != null &&
          _fieldErrors['eventDesignMode']!.isNotEmpty) ...[
        const SizedBox(height: 4),
        Text(
          _fieldErrors['eventDesignMode']!,
          style: const TextStyle(color: Color(0xFFFF4D4F), fontSize: 12),
        ),
      ],
      const SizedBox(height: 24),
      Row(
        children: [
          TextButton(
            onPressed:
                _submitting
                    ? null
                    : () => setState(() {
                      _formPhase = 0;
                      _fieldErrors.remove('eventDesignMode');
                    }),
            child: const Text('BACK'),
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: _submitting ? null : _goNextFromDesignChoice,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E1E1E),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
            child: const Text('NEXT'),
          ),
        ],
      ),
    ];
  }

  Widget _buildAiDesignPreviewPanel({double minHeight = 280}) {
    final hasGenerated = _generatedImageUrl != null;
    final generatedDisplayUrl =
        _generatedImageUrl == null
            ? null
            : _generatedImageDisplayUrl(_generatedImageUrl!);
    final hasVenue = _venuePhotoBase64 != null;

    Widget previewBox({
      required double height,
      required Widget child,
      VoidCallback? onTap,
    }) {
      final framed = Container(
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
          color: Colors.grey.shade50,
        ),
        child: ClipRRect(borderRadius: BorderRadius.circular(8), child: child),
      );
      if (onTap == null) return framed;
      return _buildTappableImagePreview(
        onTap: onTap,
        hint: null,
        child: framed,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          hasGenerated ? 'Preview' : 'Design preview',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E1E1E),
          ),
        ),
        const SizedBox(height: 8),
        if (hasGenerated) ...[
          previewBox(
            height: minHeight,
            onTap:
                () => _openZoomableImage(
                  image: Image.network(
                    generatedDisplayUrl,
                    fit: BoxFit.contain,
                  ),
                ),
            child: Image.network(
              generatedDisplayUrl!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) {
                return Container(
                  color: Colors.grey.shade200,
                  child: const Center(
                    child: Icon(Icons.error, color: Colors.grey),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _downloadGeneratedImage(generatedDisplayUrl),
                icon: const Icon(Icons.download, size: 18),
                label: const Text('Download design'),
              ),
              if (hasVenue)
                OutlinedButton.icon(
                  onPressed: _downloadVenuePhoto,
                  icon: const Icon(Icons.download, size: 18),
                  label: const Text('Download venue photo'),
                ),
            ],
          ),
          if (_generatedImageHistory.length > 1) ...[
            const SizedBox(height: 12),
            const Text(
              'Other generated images',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _generatedImageHistory.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final url = _generatedImageHistory[i];
                  final displayUrl = _generatedImageDisplayUrl(url);
                  final selected = displayUrl == generatedDisplayUrl;
                  return GestureDetector(
                    onTap:
                        () => setState(() => _generatedImageUrl = displayUrl),
                    child: Container(
                      width: 72,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color:
                              selected
                                  ? const Color(0xFFFFC024)
                                  : Colors.grey.shade300,
                          width: selected ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.network(displayUrl, fit: BoxFit.cover),
                    ),
                  );
                },
              ),
            ),
          ],
        ] else
          Container(
            height: minHeight,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey.shade50,
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.image_outlined,
                    size: 48,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Your AI concept will appear here after you generate.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ),
        if (hasGenerated) ...[
          const SizedBox(height: 8),
          const Text(
            'Your custom event design is ready!',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E1E1E),
            ),
          ),
        ],
        if (hasVenue) ...[
          const SizedBox(height: 16),
          const Text(
            'Venue reference',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E1E1E),
            ),
          ),
          const SizedBox(height: 6),
          previewBox(
            height: 160,
            onTap:
                () => _openZoomableImage(
                  image: Image.memory(
                    base64Decode(_venuePhotoBase64!),
                    fit: BoxFit.contain,
                  ),
                ),
            child: Image.memory(
              base64Decode(_venuePhotoBase64!),
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Required for AI design — your photo is sent to the server as the base image.',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ],
      ],
    );
  }

  Widget _buildAiDesignForm(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _responsiveTwoCol(
          context,
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSectionTitle('Event Type'),
              _buildDropdown(
                _eventTypes,
                _selectedEventType,
                (val) => setState(() => _selectedEventType = val),
              ),
              if (_selectedEventType == 'Other') ...[
                const SizedBox(height: 8),
                AntdOutlineInput(
                  controller: _eventTypeOtherController,
                  hintText: 'Describe your event type',
                ),
              ],
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSectionTitle('Style'),
              _buildDropdown(
                _styles,
                _selectedStyle,
                (val) => setState(() => _selectedStyle = val),
              ),
              if (_selectedStyle == 'Other') ...[
                const SizedBox(height: 8),
                AntdOutlineInput(
                  controller: _styleOtherController,
                  hintText: 'Describe your style',
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildSectionTitle('Mood / Lighting'),
        _buildDropdown(
          _moods,
          _selectedMood,
          (val) => setState(() => _selectedMood = val),
        ),
        if (_selectedMood == 'Other') ...[
          const SizedBox(height: 8),
          AntdOutlineInput(
            controller: _moodOtherController,
            hintText: 'Describe mood / lighting',
          ),
        ],
        const SizedBox(height: 16),
        _responsiveTwoCol(
          context,
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSectionTitle('Color Palette'),
              _buildMultiSelect(_colorPalettes, _selectedColors),
              if (_selectedColors.contains('Other')) ...[
                const SizedBox(height: 8),
                AntdOutlineInput(
                  controller: _colorOtherController,
                  hintText: 'Describe your color palette',
                ),
              ],
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSectionTitle('Decor Elements'),
              _buildMultiSelect(_decorOptions, _selectedDecor),
              if (_selectedDecor.contains('Other')) ...[
                const SizedBox(height: 8),
                AntdOutlineInput(
                  controller: _decorOtherController,
                  hintText: 'Describe decor elements',
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildSectionTitle('Additional Instructions'),
        AntdFieldShell(
          label: 'Notes',
          errorText: _fieldErrors['designNotes'],
          child: AntdOutlineInput(
            controller: _designPromptController,
            hintText: 'e.g., simple wedding setup with garden theme',
            maxLines: 3,
            onChanged: (_) {
              if (_fieldErrors.containsKey('designNotes')) {
                setState(() => _fieldErrors.remove('designNotes'));
              }
            },
          ),
        ),
        const SizedBox(height: 16),
        _buildSectionTitle('Venue Photo'),
        Tooltip(
          message: 'Upload a photo of the venue',
          child: OutlinedButton.icon(
            onPressed: _pickVenuePhoto,
            icon: const Icon(Icons.upload_file),
            label: Text(
              _venuePhotoBase64 != null
                  ? 'Change venue reference photo'
                  : 'Upload venue reference photo',
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              side: BorderSide(
                color:
                    _venueFieldError != null
                        ? const Color(0xFFFF4D4F)
                        : _venuePhotoBase64 != null
                        ? Colors.green
                        : Colors.grey.shade400,
              ),
              foregroundColor:
                  _venuePhotoBase64 != null
                      ? Colors.green
                      : const Color(0xFF1E1E1E),
            ),
          ),
        ),
        if (_venueFieldError != null && _venueFieldError!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            _venueFieldError!,
            style: const TextStyle(color: Color(0xFFFF4D4F), fontSize: 12),
          ),
        ],
        if (_venuePhotoBase64 != null && isMobile(context)) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed:
                () => setState(() {
                  _venuePhotoBase64 = null;
                  _clearGeneratedDesignOutputs();
                }),
            icon: const Icon(Icons.delete, color: Colors.red),
            label: const Text(
              'Remove Photo',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
        const SizedBox(height: 16),
        if (_genAiError != null && _genAiError!.isNotEmpty) ...[
          Text(
            _genAiError!,
            style: const TextStyle(color: Color(0xFFFF4D4F), fontSize: 12),
          ),
          const SizedBox(height: 12),
        ],
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed:
                (_submitting || _generatingDesign)
                    ? null
                    : _generateDesignPrompt,
            icon:
                _generatingDesign
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.auto_fix_high),
            label: Text(
              _generatingDesign ? 'GENERATING…' : 'GENERATE EVENT DESIGN',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFC024),
              foregroundColor: const Color(0xFF1E1E1E),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildPhase2CustomerAi(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 900;
    final title =
        _generatedImageUrl != null
            ? 'Generated event design'
            : 'Event design (AI)';

    final layout =
        wide
            ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: _buildAiDesignForm(context)),
                const SizedBox(width: 24),
                Expanded(
                  flex: 2,
                  child: _buildAiDesignPreviewPanel(minHeight: 360),
                ),
              ],
            )
            : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_generatedImageUrl != null ||
                    _venuePhotoBase64 != null) ...[
                  _buildAiDesignPreviewPanel(minHeight: 220),
                  const SizedBox(height: 20),
                ],
                _buildAiDesignForm(context),
                if (_generatedImageUrl == null &&
                    _venuePhotoBase64 == null) ...[
                  const SizedBox(height: 20),
                  _buildAiDesignPreviewPanel(minHeight: 160),
                ],
              ],
            );

    return [
      _inquirySectionTitle(title),
      const SizedBox(height: 8),
      Text(
        'Choose your preferences, optionally upload a venue photo, then generate an AI concept.',
        style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
      ),
      const SizedBox(height: 20),
      layout,
      const SizedBox(height: 32),
    ];
  }

  List<Widget> _buildPhase2Content(BuildContext context) {
    if (_eventDesignMode == 'macrina') {
      return [
        _inquirySectionTitle('Tell Macrina\'s what you envision'),
        const SizedBox(height: 8),
        Text(
          'Share your color palette and theme. Our team will follow up with a tailored proposal.',
          style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 20),
        AntdFieldShell(
          label: 'Color palette',
          required: true,
          errorText: _fieldErrors['macrinaPalette'],
          child: AntdOutlineInput(
            controller: _macrinaPalette,
            hintText: 'e.g., blush pink, ivory, gold accents',
            maxLines: 2,
            onChanged: (_) {
              if (_fieldErrors.containsKey('macrinaPalette')) {
                setState(() => _fieldErrors.remove('macrinaPalette'));
              }
            },
          ),
        ),
        const SizedBox(height: 16),
        AntdFieldShell(
          label: 'Theme',
          required: true,
          errorText: _fieldErrors['macrinaTheme'],
          child: AntdOutlineInput(
            controller: _macrinaTheme,
            hintText: 'e.g., garden party, art deco, minimalist modern',
            maxLines: 2,
            onChanged: (_) {
              if (_fieldErrors.containsKey('macrinaTheme')) {
                setState(() => _fieldErrors.remove('macrinaTheme'));
              }
            },
          ),
        ),
        const SizedBox(height: 32),
        ..._buildPhase2Footer(),
      ];
    }
    return [..._buildPhase2CustomerAi(context), ..._buildPhase2Footer()];
  }

  List<Widget> _buildPhase2Footer() {
    return [
      Row(
        children: [
          TextButton(
            onPressed:
                _submitting
                    ? null
                    : () => setState(() {
                      _formPhase = 1;
                      _genAiError = null;
                    }),
            child: const Text('BACK'),
          ),
          const Spacer(),
          SizedBox(
            width: 200,
            child: ElevatedButton(
              onPressed: _submitting ? null : _showOrderSummaryAndConfirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E1E1E),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child:
                  _submitting
                      ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                      : const Text(
                        'SUBMIT INQUIRY',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
            ),
          ),
        ],
      ),
    ];
  }

  List<Widget> _buildCompletedContent() {
    return [
      Center(
        child: Icon(
          Icons.check_circle_outline,
          size: 56,
          color: Colors.green.shade600,
        ),
      ),
      const SizedBox(height: 16),
      Center(
        child: Text(
          'Inquiry submitted',
          style: GoogleFonts.getFont(
            _primaryFont,
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1E1E1E),
          ),
        ),
      ),
      const SizedBox(height: 8),
      Center(
        child: Text(
          _submittedCateringId == null
              ? 'Our team will review your inquiry and contact you soon.'
              : 'Reference: $_submittedCateringId',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade700),
        ),
      ),
      const SizedBox(height: 24),
      Center(
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: [
            FilledButton(
              onPressed: () => _openMyCaterings(),
              child: const Text('View My Caterings'),
            ),
            OutlinedButton(
              onPressed:
                  () => setState(() {
                    _submittedCateringId = null;
                    _wizardStep = 0;
                    _formPhase = 0;
                  }),
              child: const Text('Submit another inquiry'),
            ),
          ],
        ),
      ),
    ];
  }

  Future<void> _openMyCaterings() async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString('customer_token');
    if (!mounted) return;
    if (token == null || token.isEmpty) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const CustomerLoginPage()),
      );
      if (!mounted) return;
      token = (await SharedPreferences.getInstance()).getString('customer_token');
      if (token == null || token.isEmpty) return;
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const MyCateringsPage()),
    );
  }

  Widget _buildWizardProgressBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(_kInquiryWizardStepLabels.length, (i) {
          final done = i < _wizardStep;
          final active = i == _wizardStep;
          final reached = i <= _wizardStep;
          return Expanded(
            child: Column(
              children: [
                CircleAvatar(
                  radius: active ? 16 : 14,
                  backgroundColor:
                      reached ? const Color(0xFFFFC024) : Colors.grey.shade300,
                  child: Icon(
                    done ? Icons.check : _kInquiryWizardStepIcons[i],
                    size: active ? 18 : 16,
                    color: reached ? const Color(0xFF1E1E1E) : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _kInquiryWizardStepLabels[i],
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  style: TextStyle(
                    fontSize: 10,
                    height: 1.2,
                    fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                    color: reached ? Colors.black87 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _packageCopyBlock({
    required String title,
    required List<String> bullets,
    required String note,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        for (final b in bullets) Text(b),
        const SizedBox(height: 6),
        Text(
          note,
          style: TextStyle(
            fontSize: 12,
            height: 1.35,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }

  List<Widget> _buildPackagesStep() {
    return [
      const Text(
        'Catering Packages',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 12),
      DefaultTabController(
        length: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const TabBar(
              labelColor: Color(0xFF1E1E1E),
              tabs: [
                Tab(text: 'Within Taguig'),
                Tab(text: 'Outside Taguig'),
              ],
            ),
            SizedBox(
              height: 320,
              child: TabBarView(
                children: [
                  SingleChildScrollView(
                    padding: const EdgeInsets.only(top: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _packageCopyBlock(
                          title: 'Catering',
                          bullets: const [
                            '1) Php 500 per pax',
                            '2) Setup: staff and buffet service',
                          ],
                          note:
                              'For requests such as event styling, menu modifications, tables and chairs, etc., please include in your notes upon inquiry submission.',
                        ),
                        const SizedBox(height: 16),
                        _packageCopyBlock(
                          title: 'Catering with Event Styling',
                          bullets: const [
                            '1) Php 500 per pax',
                            '2) Minimal Design: tables and chairs with linen and centerpiece',
                            '3) Setup: staff and buffet service',
                          ],
                          note:
                              'For extensive event styling and other requests, please include in your notes upon inquiry submission.',
                        ),
                      ],
                    ),
                  ),
                  SingleChildScrollView(
                    padding: const EdgeInsets.only(top: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _packageCopyBlock(
                          title: 'Catering',
                          bullets: const [
                            '1) Php 500 per pax',
                            '2) Setup: staff and buffet service',
                          ],
                          note:
                              'Travel / logistics may apply outside Taguig. Include details in your notes.',
                        ),
                        const SizedBox(height: 16),
                        _packageCopyBlock(
                          title: 'Catering with Event Styling',
                          bullets: const [
                            '1) Php 500 per pax',
                            '2) Minimal Design: tables and chairs with linen and centerpiece',
                            '3) Setup: staff and buffet service',
                          ],
                          note:
                              'Travel / logistics may apply outside Taguig. Include details in your notes.',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      Align(
        alignment: Alignment.centerRight,
        child: FilledButton(
          onPressed: () => setState(() => _wizardStep = 1),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF1E1E1E),
          ),
          child: const Text('NEXT'),
        ),
      ),
    ];
  }

  List<Widget> _buildGuestsLandingStep() {
    final pax = int.tryParse(_landingPax.text.trim());
    final estimate =
        pax != null && pax > 0 ? estimateInquiryCateringTotal(pax) : 0.0;
    final packageLabel =
        (pax ?? 0) >= kInquiryLandingEventStylingMinPax
            ? 'Catering with Event Styling'
            : 'Catering';
    return [
      const Text(
        'How many guests?',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 8),
      Text(
        'Enter your guest count. At $kInquiryLandingEventStylingMinPax or more guests, we use Catering with Event Styling.',
        style: TextStyle(color: Colors.grey.shade700),
      ),
      const SizedBox(height: 20),
      Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 280),
          child: AntdOutlineInput(
            controller: _landingPax,
            hintText: 'Number of guests',
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
          ),
        ),
      ),
      const SizedBox(height: 16),
      if (pax != null && pax > 0) ...[
        Center(
          child: Text(
            'Package: $packageLabel',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            'Base estimate: ₱${estimate.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.amber.shade900,
            ),
          ),
        ),
      ],
      const SizedBox(height: 24),
      Row(
        children: [
          OutlinedButton(
            onPressed: () => setState(() => _wizardStep = 0),
            child: const Text('BACK'),
          ),
          const Spacer(),
          FilledButton(
            onPressed: _proceedFromLanding,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1E1E1E),
            ),
            child: const Text('NEXT'),
          ),
        ],
      ),
    ];
  }

  void _proceedFromLanding() {
    final pax = int.tryParse(_landingPax.text.trim());
    if (pax == null || pax < 1) {
      showAntdMessage(
        context,
        'Enter how many guests you will have.',
        type: AntdMessageType.error,
      );
      return;
    }
    _guests.text = '$pax';
    if (pax >= kInquiryLandingEventStylingMinPax) {
      _serviceType = 'catering+event';
      _serviceIncluded = 'yes';
    } else {
      _serviceType = 'catering';
      _serviceIncluded = 'no';
    }
    setState(() {
      _wizardStep = 2;
      _formPhase = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final content = WebsiteContentStore.instance;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CustomerWebsiteTopBar(
            showCartAndCustomerAuth: !widget.contentEditable,
          ),
          Expanded(
            child: CenteredViewportScroll(
              padding: websitePagePadding(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  Text(
                    content.inquiryPageTitle,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.getFont(
                      _primaryFont,
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E1E1E),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFC024),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        content.inquiryPageSubtitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E1E1E),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildWizardProgressBar(),
                          if (_wizardStep == 0) ..._buildPackagesStep(),
                          if (_wizardStep == 1) ..._buildGuestsLandingStep(),
                          if (_wizardStep == 2 && _formPhase == 0)
                            ..._buildPhase0Content(context),
                          if (_wizardStep == 2 &&
                              _formPhase == 1 &&
                              _isCateringWithEventStyling)
                            ..._buildPhase1Content(),
                          if (_wizardStep == 2 &&
                              _formPhase == 2 &&
                              _isCateringWithEventStyling)
                            ..._buildPhase2Content(context),
                          if (_wizardStep == 3) ..._buildCompletedContent(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- EVENT DESIGN UI COMPONENTS ----------

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1E1E1E),
        ),
      ),
    );
  }

  Widget _buildDropdown(
    List<String> items,
    String? value,
    Function(String?) onChanged,
  ) {
    return DropdownButtonFormField<String>(
      value: value != null && items.contains(value) ? value : null,
      items:
          items.map((item) {
            return DropdownMenuItem(value: item, child: Text(item));
          }).toList(),
      onChanged: onChanged,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      hint: const Text('Select an option'),
    );
  }

  Widget _buildMultiSelect(List<String> items, List<String> selectedList) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children:
          items.map((item) {
            final isSelected = selectedList.contains(item);
            return FilterChip(
              label: Text(item),
              selected: isSelected,
              onSelected: (val) {
                setState(() {
                  if (val) {
                    selectedList.add(item);
                  } else {
                    selectedList.remove(item);
                  }
                });
              },
              selectedColor: const Color(0xFFFFC024),
              backgroundColor: Colors.grey.shade200,
              labelStyle: TextStyle(
                color: isSelected ? const Color(0xFF1E1E1E) : Colors.black87,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            );
          }).toList(),
    );
  }

  // ---------- EVENT DESIGN LOGIC ----------

  /// Resize/compress venue photo so it reliably fits the RunPod request body.
  Future<String?> _encodeVenueForRunpod(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 768);
      final frame = await codec.getNextFrame();
      final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      frame.image.dispose();
      if (data == null) return base64Encode(bytes);
      return base64Encode(data.buffer.asUint8List());
    } catch (_) {
      return base64Encode(bytes);
    }
  }

  Future<void> _pickVenuePhoto() async {
    setState(() => _venueFieldError = null);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;

        if (file.bytes != null && file.bytes!.length > 5 * 1024 * 1024) {
          if (mounted) {
            setState(
              () => _venueFieldError = 'Image size should be less than 5MB',
            );
          }
          return;
        }

        if (file.bytes != null) {
          final base64String = await _encodeVenueForRunpod(file.bytes!);
          if (mounted && base64String != null) {
            setState(() {
              final shouldResetGenerated =
                  _venuePhotoBase64 != null ||
                  _generatedImageUrl != null ||
                  _generatedImageHistory.isNotEmpty;
              _venuePhotoBase64 = base64String;
              _venueFieldError = null;
              // New/changed reference photo invalidates prior AI generations.
              if (shouldResetGenerated) {
                _clearGeneratedDesignOutputs();
              }
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _venueFieldError = 'Failed to upload photo: $e');
      }
    }
  }

  Future<String?> _resolveRunpodUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('customer_data');
    if (raw == null) return null;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final id = data['id']?.toString().trim();
      if (id != null && id.isNotEmpty) return id;
    } catch (_) {}
    return null;
  }

  String _composeEventDesignPrompt() {
    final eventType = _resolvedCategory(
      _selectedEventType,
      _eventTypeOtherController,
    );
    final style = _resolvedCategory(_selectedStyle, _styleOtherController);
    final mood = _resolvedCategory(_selectedMood, _moodOtherController);
    final colors = _resolvedMultiSelectWithOther(
      _selectedColors,
      _colorOtherController,
    );
    final decor = _resolvedMultiSelectWithOther(
      _selectedDecor,
      _decorOtherController,
    );
    final notes = _designPromptController.text.trim();
    final mappedDecor = _eventThemeDecorFor(style);
    final decorValues = [...mappedDecor, ...decor];
    String decorPhrase(String value) {
      final text = value.trim();
      if (text.isEmpty) return '';
      return text.toLowerCase().contains('decor') ? text : '$text decor';
    }

    final visualPrompt = <String>[
      'use this venue image to make these edits: ${eventType ?? 'event'} party event',
      if (style != null && style.isNotEmpty) '$style style',
      if (mood != null && mood.isNotEmpty) '$mood mood/lighting',
      if (colors.isNotEmpty) '${colors.join(', ')} color palette',
      for (final item in decorValues)
        if (decorPhrase(item).isNotEmpty) decorPhrase(item),
      if (notes.isNotEmpty) notes,
      'add chairs and tables',
    ].join(', ');

    return visualPrompt;
  }

  String _eventDesignNegativePrompt() {
    return [
      'warped architecture',
      'distorted room',
      'melted surfaces',
      'duplicate objects',
      'blurry',
      'low quality',
      'cartoon',
      'CGI',
      'fisheye',
    ].join(', ');
  }

  Map<String, dynamic> _eventDesignConfig() {
    final eventType = _resolvedCategory(
      _selectedEventType,
      _eventTypeOtherController,
    );
    final style = _resolvedCategory(_selectedStyle, _styleOtherController);
    final mood = _resolvedCategory(_selectedMood, _moodOtherController);
    final colors = _resolvedMultiSelectWithOther(
      _selectedColors,
      _colorOtherController,
    );
    final decor = _resolvedMultiSelectWithOther(
      _selectedDecor,
      _decorOtherController,
    );
    final notes = _designPromptController.text.trim();

    return {
      'task_type': 'event_prompt_expansion',
      if (eventType != null && eventType.isNotEmpty)
        'event_type': eventType.trim().toLowerCase(),
      if (style != null && style.isNotEmpty) ...{
        'theme': style.trim(),
        'style': style.trim(),
      },
      if (mood != null && mood.isNotEmpty) 'mood': mood.trim(),
      if (colors.isNotEmpty) ...{'colors': colors, 'color_palette': colors},
      if (decor.isNotEmpty) ...{'decor': decor, 'decor_elements': decor},
      if (notes.isNotEmpty) ...{'notes': notes, 'custom_instructions': notes},
      'formality': _formality,
      if (_address.text.trim().isNotEmpty) 'venue': _address.text.trim(),
      if (_guests.text.trim().isNotEmpty) 'guest_count': _guests.text.trim(),
    };
  }

  double _eventDesignControlnetForDenoise(double denoise) {
    if (denoise < 0.8) return 0.85;
    if (denoise < 0.86) return 0.65;
    return 0.55;
  }

  Map<String, dynamic> _eventDesignRunpodMeta({
    EventPromptExpansion? expansion,
  }) {
    final config = _eventDesignConfig();
    final denoise = expansion?.recommendedStrength ?? 0.85;
    final controlnet = _eventDesignControlnetForDenoise(denoise);
    return {
      ...config,
      'task_type': 'nano_event_design',
      'use_nlp_prompt_expansion': false,
      if (expansion != null) ...expansion.toSdxlMeta(),
      'negative_prompt': _eventDesignNegativePrompt(),
      'guidance_scale': 7,
      'controlnet': {
        'enabled': expansion?.controlnet?['enabled'] ?? true,
        'preprocessor': expansion?.controlnet?['preprocessor'] ?? 'depth',
        'preserve_venue': true,
        'conditioning_scale':
            expansion?.controlnet?['conditioning_scale'] ?? controlnet,
      },
      'controlnet_conditioning_scale':
          expansion?.controlnet?['conditioning_scale'] ?? controlnet,
    };
  }

  Future<void> _downloadVenuePhoto() async {
    final b64 = _venuePhotoBase64;
    if (b64 == null) return;
    try {
      await downloadImageBytes(base64Decode(b64), 'venue-reference.png');
    } catch (e) {
      if (mounted) {
        showAntdMessage(
          context,
          'Download failed: $e',
          type: AntdMessageType.error,
        );
      }
    }
  }

  Future<void> _downloadGeneratedImage(String url) async {
    try {
      final res = await http.get(Uri.parse(_generatedImageDisplayUrl(url)));
      if (res.statusCode == 200) {
        await downloadImageBytes(
          Uint8List.fromList(res.bodyBytes),
          'event-design.png',
        );
      }
    } catch (e) {
      if (mounted) {
        showAntdMessage(
          context,
          'Download failed: $e',
          type: AntdMessageType.error,
        );
      }
    }
  }

  String _normalizeVenueB64ForRunpod(String raw) {
    var s = raw.trim();
    if (s.startsWith('data:')) {
      final comma = s.indexOf(',');
      s = comma >= 0 ? s.substring(comma + 1) : s;
    }
    return s.replaceAll(RegExp(r'\s+'), '');
  }

  Future<void> _generateDesignPrompt() async {
    if (_selectedEventType == null &&
        _selectedStyle == null &&
        _selectedMood == null &&
        _selectedColors.isEmpty &&
        _selectedDecor.isEmpty &&
        _designPromptController.text.isEmpty) {
      setState(
        () =>
            _genAiError =
                'Please select at least one option or add instructions in the notes field.',
      );
      return;
    }

    final venueRaw = _venuePhotoBase64?.trim();
    if (venueRaw == null || venueRaw.isEmpty) {
      setState(
        () =>
            _genAiError =
                'Upload a venue photo first — the AI uses it as the base image for your design.',
      );
      return;
    }

    setState(() {
      _generatingDesign = true;
      _genAiError = null;
    });

    try {
      final prompt = _composeEventDesignPrompt();
      final venueB64 = _normalizeVenueB64ForRunpod(venueRaw);
      const denoise = 0.85;
      if (kDebugMode) {
        debugPrint(
          'RunPod: POST ${apiBaseUrl}/api/public/runpod/run '
          '(venue b64 ${venueB64.length} chars, prompt ${prompt.length} chars)',
        );
      }

      final runpodUserId = await _resolveRunpodUserId();

      final imageUrl = await RunPodService.generateImageWithPolling(
        prompt,
        user_id: runpodUserId,
        initImageBase64: venueB64,
        strength: denoise,
        numInferenceSteps: 30,
        guidanceScale: 7,
        designMeta: _eventDesignRunpodMeta(),
      );

      if (imageUrl != null) {
        final displayUrl = _generatedImageDisplayUrl(imageUrl);
        setState(() {
          _wantsCustomDesign = true;
          _generatedImageUrl = displayUrl;
          _generatedDesignPrompt = prompt;
          if (!_generatedImageHistory.contains(displayUrl)) {
            _generatedImageHistory.add(displayUrl);
          }
          _genAiError = null;
        });
      } else {
        setState(
          () => _genAiError = 'Failed to generate design. Please try again.',
        );
      }
    } catch (e) {
      final raw = e.toString();
      final msg =
          raw.contains('Exception:')
              ? raw.split('Exception:').last.trim()
              : raw;
      setState(() => _genAiError = msg);
    } finally {
      if (mounted) {
        setState(() => _generatingDesign = false);
      }
    }
  }
}
