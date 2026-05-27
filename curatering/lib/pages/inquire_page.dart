import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:http/http.dart' as http;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../models/menu_dish.dart';
import '../services/menu_store.dart';
import '../services/public_events_api.dart';
import '../services/runpod_service.dart';
import '../services/set_menu_store.dart';
import '../services/website_content_store.dart';
import '../services/nominatim_service.dart';
import '../utils/geo_utils.dart';
import '../widgets/antd_buttons.dart';
import '../widgets/antd_form_field.dart';
import '../widgets/antd_message.dart';
import '../widgets/antd_tokens.dart';
import '../widgets/customer_website_topbar.dart';
import '../widgets/allergen_selector_field.dart';
import '../widgets/inquiry_menu_selection_dialog.dart';
import '../widgets/map_picker.dart';
import '../widgets/event_venue_map_preview.dart';
import '../utils/inquiry_pricing.dart';
import '../widgets/antd_dialog.dart';
import '../utils/image_download.dart';

// ---------------------------------------------------------------------------
// Layout helpers
// ---------------------------------------------------------------------------
const String _primaryFont = 'Inter';
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

// ---------------------------------------------------------------------------
// Constants matching the mobile InquiryScreen
// ---------------------------------------------------------------------------
const String kInquiryTypeCatering = 'CATERING';
const String kInquiryTypeCateringWithEventStyling =
    'CATERING WITH EVENT STYLING';
const int kMinCateringOnlyPax = 20;
const int kMinCateringEventPax = 50;
const int kInquiryLandingEventStylingMinPax = 50;
const double kPesosPerPax = kCateringInquiryPricePerGuest;

bool isInquiryCateringWithEventStyling(String type) =>
    type.trim().toUpperCase() == kInquiryTypeCateringWithEventStyling;

String inquiryTypeDisplayLabel(String type) =>
    isInquiryCateringWithEventStyling(type)
        ? 'Catering with Event Styling'
        : 'Catering';

const List<String> kEventTypeChoices = [
  'Birthday',
  'Wedding',
  'Debut',
  'Baptism',
  'Corporate',
  'Sports',
  'Government',
  'Show',
  'Educational',
  'Reunion',
  'Gala',
  'Dinner',
  'Other',
];

const Color _accentYellow = Color(0xFFFFC024);
const Color _darkHeader = Color(0xFF1E1E1E);

// ---------------------------------------------------------------------------
// Stepper steps
// ---------------------------------------------------------------------------
enum _InquiryStep { packages, guestCount, form, completed }

String _stepLabel(_InquiryStep step) {
  switch (step) {
    case _InquiryStep.packages:
      return 'Catering Packages';
    case _InquiryStep.guestCount:
      return 'Enter number of guests';
    case _InquiryStep.form:
      return 'Fill inquiry form';
    case _InquiryStep.completed:
      return 'Completed';
  }
}

int _stepNumber(_InquiryStep step) {
  switch (step) {
    case _InquiryStep.packages:
      return 1;
    case _InquiryStep.guestCount:
      return 2;
    case _InquiryStep.form:
      return 3;
    case _InquiryStep.completed:
      return 4;
  }
}

// Side-tab IDs for the 3-column layout
enum _SideTab { eventInfo, menu, themeDesign }

// ---------------------------------------------------------------------------
// Event schedule window
// ---------------------------------------------------------------------------
class _InquiryEventWindow {
  DateTime? date;
  TimeOfDay? from;
  TimeOfDay? to;
}

// ---------------------------------------------------------------------------
// InquirePage
// ---------------------------------------------------------------------------
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
  // ---- Step management ----
  _InquiryStep _currentStep = _InquiryStep.packages;
  _SideTab _activeSideTab = _SideTab.eventInfo;

  // ---- Landing / package selection ----
  final _landingPaxController = TextEditingController();
  bool _includeMinimalStyling = false;
  int _selectedPackageIndex = 0;

  // ---- Inquiry type ----
  String _inquiryType = kInquiryTypeCatering;

  // ---- Menu ----
  bool _curateOwn = false;
  bool _menuChoicePicked = false;
  bool _attemptedSubmit = false;
  static const int _minSelectedDishesRequired = 4;
  static const int _maxSelectedDishesRequired = 8;
  static const int _maxMainDishSelections = 3;
  String _menuSuggestionNote = '';
  String _selectedSetMenu = 'All Dishes';
  final Set<String> _selectedDishIds = {};
  String _allergensSerialized = '';
  final _menuSearchController = TextEditingController();

  // ---- Theme design ----
  String _themeDesignChoice = '';
  String _themeDesignSessionId =
      'inquiry-${DateTime.now().microsecondsSinceEpoch}';
  Map<String, dynamic>? _aiThemeDesignPayload;
  String _themeSuggestionNote = '';
  final _themeNotesController = TextEditingController();
  final List<String> _themeReferenceImagesB64 = [];

  // ---- Event info ----
  final _eventTitle = TextEditingController();
  final _eventTypeOther = TextEditingController();
  String _eventTypeChoice = 'Birthday';
  final _customerName = TextEditingController();
  bool _customerSameAsContact = false;
  final _contactPerson = TextEditingController();
  final _contactNumber = TextEditingController();
  final _inquiryEmail = TextEditingController();
  final _guestCount = TextEditingController();
  final _paxBuffer = TextEditingController();
  final List<_InquiryEventWindow> _eventWindows = [_InquiryEventWindow()];
  Timer? _scheduleConflictDebounce;
  int _publicScheduleConflictCount = 0;
  final _eventCity = TextEditingController();
  final List<String> _venueSuggestions = [];
  Timer? _venueDebounce;
  double? _addressLat;
  double? _addressLng;
  final _note = TextEditingController();
  String _eventSetting = 'Indoor';
  String _serviceIncluded = 'no';
  String _formalityLevel = 'casual';
  bool _foodTastingRequested = false;
  bool _suggestMenu = false;
  String? _submittedCateringId;
  bool _submitting = false;
  bool _generatingDesign = false;
  String? _generatedImageUrl;
  final List<String> _generatedImageHistory = [];

  // Service Type Selection
  String _serviceType = 'catering'; // 'catering' or 'catering+event'

  // Menu preferences: 0 = custom dishes, 1 = set menu (exclusive)
  int _menuPrefTabIndex = 0;
  bool? _includeCateringService; // catering-only, guests < 50
  final List<String> _selectedDishIds = [];
  final List<Map<String, dynamic>> _menuSelections = [];
  String _allergensSerialized = '';

  /// Phase 0 = main inquiry form; 1 = event design path choice; 2 = macrina fields OR customer AI.
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
  final _eventTypeDesignOtherController = TextEditingController();
  final _styleOtherController = TextEditingController();
  final _moodOtherController = TextEditingController();
  final _colorOtherController = TextEditingController();
  final _decorOtherController = TextEditingController();
  String? _venuePhotoBase64;
  String? _generatedImageUrl;
  final List<String> _generatedImageHistory = [];
  bool _generatingDesign = false;
  String? _genAiError;
  String? _venueFieldError;

  // ---- Service type ----
  String _serviceType = 'catering';
  bool? _includeCateringService;

  // ---- Submission ----
  bool _submitting = false;
  String? _submittedCateringId;
  bool _formSubmitted = false;

  // ---- Menu preference tab ----
  int _menuPrefTabIndex = 0;
  final List<Map<String, dynamic>> _menuSelections = [];

  final _eventTypes = [
    'Elegant', 'Rustic', 'Modern', 'Garden', 'Minimalist', 'Vintage',
    'Bohemian', 'Other',
  ];
  final _styles = [
    'Elegant', 'Rustic', 'Modern', 'Garden', 'Minimalist', 'Vintage',
    'Bohemian', 'Other',
  ];
  final _moods = [
    'Romantic', 'Bright', 'Dramatic', 'Cozy', 'Luxurious', 'Fun', 'Other',
  ];
  final _colorPalettes = [
    'White & Gold', 'Pastel Pink', 'Earthy Green', 'Navy & Silver',
    'Peach & Cream', 'Black & White', 'Other',
  ];
  final _decorOptions = [
    'Floral Centerpieces', 'Fairy Lights', 'Stage Backdrop', 'Balloon Setup',
    'Drapery & Curtains', 'Table Runners', 'Photo Booth', 'Chandeliers',
    'Other',
  ];

  // ===========================================================================
  // Lifecycle
  // ===========================================================================

  @override
  void initState() {
    super.initState();
    MenuStore.instance.loadDishes();
    SetMenuStore.instance.loadSetMenus();
    WebsiteContentStore.instance.ensureLoaded().then((_) {
      if (mounted) setState(() {});
    });
    _prefillFromCustomerProfile();
    _eventCity.addListener(_onVenueChanged);
    _contactPerson.addListener(_syncCustomerFromContact);
    _guestCount.addListener(_onGuestCountChanged);
  }

  @override
  void dispose() {
    _scheduleConflictDebounce?.cancel();
    _venueDebounce?.cancel();
    _eventCity.removeListener(_onVenueChanged);
    _contactPerson.removeListener(_syncCustomerFromContact);
    _guestCount.removeListener(_onGuestCountChanged);
    _landingPaxController.dispose();
    _guestCount.dispose();
    _paxBuffer.dispose();
    _eventTitle.dispose();
    _eventTypeOther.dispose();
    _customerName.dispose();
    _contactPerson.dispose();
    _contactNumber.dispose();
    _inquiryEmail.dispose();
    _eventCity.dispose();
    _note.dispose();
    _foodTastingDate.dispose();
    _foodTastingTime.dispose();
    _menuSearchController.dispose();
    _themeNotesController.dispose();
    _designPromptController.dispose();
    _eventTypeDesignOtherController.dispose();
    _styleOtherController.dispose();
    _moodOtherController.dispose();
    _colorOtherController.dispose();
    _decorOtherController.dispose();
    super.dispose();
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
          _customerName.text = name;
          if (_contactPerson.text.trim().isEmpty) _contactPerson.text = name;
        }
        final phone = data['phone']?.toString().trim() ?? '';
        if (phone.isNotEmpty) _contactNumber.text = phone;
        final email = data['email']?.toString().trim() ?? '';
        if (email.isNotEmpty) _inquiryEmail.text = email;
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
    _dateController.dispose();
    _timeController.dispose();
    _endTimeController.dispose();
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

  void _proceedFromPackages() {
    setState(() => _currentStep = _InquiryStep.guestCount);
  }

  void _proceedFromGuestCount() {
    final pax = _landingPaxParsed;
    if (pax == null || pax < 1) {
      showAntdMessage(context, 'Enter how many guests you will have.');
      return;
    }
    _guestCount.text = '$pax';
    _inquiryType = pax >= kInquiryLandingEventStylingMinPax
        ? kInquiryTypeCateringWithEventStyling
        : kInquiryTypeCatering;
    _serviceType = pax >= kInquiryLandingEventStylingMinPax
        ? 'catering+event'
        : 'catering';
    setState(() {
      _currentStep = _InquiryStep.form;
    });
  }

  // ===========================================================================
  // Pricing helpers
  // ===========================================================================

  int _minPaxForCurrentInquiry() =>
      isInquiryCateringWithEventStyling(_inquiryType)
          ? kMinCateringEventPax
          : kMinCateringOnlyPax;

  int _billableGuestCountForPricing() {
    final raw = _guestCount.text.trim();
    if (raw.isEmpty) return 0;
    final g = int.tryParse(raw) ?? 0;
    if (g <= 0) return 0;
    final min = _minPaxForCurrentInquiry();
    return g < min ? min : g;
  }

  int _paxBufferForPricing() {
    final raw = _paxBuffer.text.trim();
    if (raw.isEmpty) return 0;
    final n = int.tryParse(raw) ?? 0;
    return n < 0 ? 0 : n;
  }

  int _guestCountForSubmit() {
    final raw = _guestCount.text.trim();
    final min = _minPaxForCurrentInquiry();
    if (raw.isEmpty) return min;
    final g = int.tryParse(raw) ?? 0;
    if (g <= 0) return min;
    return g < min ? min : g;
  }

  double _estimatedCost() =>
      (_billableGuestCountForPricing() + _paxBufferForPricing()) * kPesosPerPax;

  Map<String, MenuDish> get _activeDishById => {
    for (final dish in MenuStore.instance.activeDishes) dish.id: dish,
  };

  List<Map<String, dynamic>> _setMenuAdditionalChargeRows() {
    if (_menuSelections.isEmpty) return const [];
    final block = _menuSelections.first;
    if ((block['kind'] as String? ?? 'custom') != 'set') return const [];
    final selectedIds = (block['dishIds'] as List<dynamic>? ?? const [])
        .map((id) => id.toString())
        .where((id) => id.isNotEmpty)
        .toList();
    final originalIds = (block['originalDishIds'] as List<dynamic>? ?? const [])
        .map((id) => id.toString())
        .where((id) => id.isNotEmpty)
        .toSet();
    final originalCount =
        (block['originalDishCount'] as num?)?.toInt() ?? originalIds.length;
    final overage = selectedIds.length - originalCount;
    if (overage <= 0) return const [];
    final dishById = _activeDishById;
    final addedIds =
        selectedIds.where((id) => !originalIds.contains(id)).take(overage);
    return addedIds.map((id) {
      final dish = dishById[id];
      final amount = dish?.additionalChargeAmount ?? 0;
      return {'dishId': id, 'dishName': dish?.name ?? id, 'amount': amount};
    }).toList();
  }

  double _menuAdditionalChargeTotal() {
    return _setMenuAdditionalChargeRows().fold<double>(
      0,
      (sum, row) => sum + ((row['amount'] as num?)?.toDouble() ?? 0),
    );
  }

  bool _isVenueInTaguig() {
    final venue = _eventCity.text.trim().toLowerCase();
    return venue.contains('taguig');
  }

  static final List<Map<String, dynamic>> _locationPackages = [
    {
      'title': 'Within Taguig City (below 50 pax) — Catering Only',
      'description': 'Food catering service within Taguig City for smaller events. Minimum $kMinCateringOnlyPax pax.',
      'type': kInquiryTypeCatering,
      'service': 'catering',
      'icon': Icons.restaurant,
    },
    {
      'title': 'Within Taguig City (50+ pax) — Catering with Event Styling',
      'description': 'Full food catering plus event design & décor within Taguig City. Minimum $kMinCateringEventPax pax.',
      'type': kInquiryTypeCateringWithEventStyling,
      'service': 'catering+event',
      'icon': Icons.celebration,
    },
    {
      'title': 'Outside Taguig City (below 50 pax) — Catering Only',
      'description': 'Food catering service for events outside Taguig City. Minimum $kMinCateringOnlyPax pax.',
      'type': kInquiryTypeCatering,
      'service': 'catering',
      'icon': Icons.restaurant,
    },
    {
      'title': 'Outside Taguig City (50+ pax) — Catering with Event Styling',
      'description': 'Full food catering plus event design & décor for events outside Taguig City. Minimum $kMinCateringEventPax pax.',
      'type': kInquiryTypeCateringWithEventStyling,
      'service': 'catering+event',
      'icon': Icons.celebration,
    },
  ];

  String get _packageDisplayName {
    if (_isEventStyling) return 'Catering with Event Styling';
    if (_isVenueInTaguig() && _billableGuestCountForPricing() > 0 && _billableGuestCountForPricing() < 50) {
      return 'Catering Only within Taguig';
    }
    return 'Catering Only';
  }

  // ===========================================================================
  // Schedule helpers
  // ===========================================================================

  String _serializedEventDates() {
    final parts = <String>[];
    for (final w in _eventWindows) {
      if (w.date == null || w.from == null || w.to == null) continue;
      final d = w.date!;
      final dateStr =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      final f =
          '${w.from!.hour.toString().padLeft(2, '0')}:${w.from!.minute.toString().padLeft(2, '0')}';
      final t =
          '${w.to!.hour.toString().padLeft(2, '0')}:${w.to!.minute.toString().padLeft(2, '0')}';
      parts.add('$dateStr from $f to $t');
    }
    return parts.join('; ');
  }

  String _scheduleSlotsJsonForSubmit() {
    final slots = <Map<String, String>>[];
    for (final w in _eventWindows) {
      if (w.date == null || w.from == null || w.to == null) continue;
      final d = w.date!;
      final dateStr =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      final f =
          '${w.from!.hour.toString().padLeft(2, '0')}:${w.from!.minute.toString().padLeft(2, '0')}';
      final t =
          '${w.to!.hour.toString().padLeft(2, '0')}:${w.to!.minute.toString().padLeft(2, '0')}';
      slots.add({
        'date': dateStr,
        'from': f,
        'to': t,
        'label': '$dateStr from $f to $t',
      });
    }
    return jsonEncode(slots);
  }

  List<Map<String, dynamic>> _buildScheduleSlotsForApi() {
    final slots = <Map<String, dynamic>>[];
    for (final w in _eventWindows) {
      if (w.date == null || w.from == null || w.to == null) continue;
      final d = w.date!;
      final dateStr =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      final f =
          '${w.from!.hour.toString().padLeft(2, '0')}:${w.from!.minute.toString().padLeft(2, '0')}';
      final t =
          '${w.to!.hour.toString().padLeft(2, '0')}:${w.to!.minute.toString().padLeft(2, '0')}';
      slots.add({'date': dateStr, 'startTime': f, 'endTime': t});
    }
    return slots;
  }

  void _scheduleConflictRefresh() {
    _scheduleConflictDebounce?.cancel();
    _scheduleConflictDebounce =
        Timer(const Duration(milliseconds: 450), () async {
      final slots = <Map<String, String>>[];
      for (final w in _eventWindows) {
        if (w.date == null || w.from == null || w.to == null) continue;
        final d = w.date!;
        final dateStr =
            '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
        slots.add({
          'date': dateStr,
          'from':
              '${w.from!.hour.toString().padLeft(2, '0')}:${w.from!.minute.toString().padLeft(2, '0')}',
          'to':
              '${w.to!.hour.toString().padLeft(2, '0')}:${w.to!.minute.toString().padLeft(2, '0')}',
        });
      }
      if (!mounted) return;
      if (slots.isEmpty) {
        setState(() => _publicScheduleConflictCount = 0);
        return;
      }
      try {
        final res = await http
            .post(
              Uri.parse('$apiBaseUrl/api/catering/schedule-conflicts'),
              headers: const {'Content-Type': 'application/json'},
              body: jsonEncode({'slots': slots}),
            )
            .timeout(const Duration(seconds: 10));
        if (!mounted || res.statusCode != 200) return;
        final body = jsonDecode(res.body);
        final n = (body is Map ? body['count'] : 0) as int? ?? 0;
        setState(() => _publicScheduleConflictCount = n);
      } catch (_) {}
    });
  }

  Future<void> _pickWindowDate(int index) async {
    final ctx = context;
    final w = _eventWindows[index];
    final base = w.date ?? DateTime.now();
    final d = await showDatePicker(
      context: ctx,
      initialDate: base,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (!ctx.mounted || d == null) return;
    setState(
      () => _eventWindows[index].date = DateTime(d.year, d.month, d.day),
    );
    _scheduleConflictRefresh();
  }

  Future<void> _pickWindowFrom(int index) async {
    final ctx = context;
    final w = _eventWindows[index];
    final t = await showTimePicker(
      context: ctx,
      initialTime: w.from ?? const TimeOfDay(hour: 12, minute: 0),
    );
    if (!ctx.mounted || t == null) return;
    setState(() => _eventWindows[index].from = t);
    _scheduleConflictRefresh();
  }

  Future<void> _pickWindowTo(int index) async {
    final ctx = context;
    final w = _eventWindows[index];
    final t = await showTimePicker(
      context: ctx,
      initialTime: w.to ?? const TimeOfDay(hour: 14, minute: 0),
    );
    if (!ctx.mounted || t == null) return;
    setState(() => _eventWindows[index].to = t);
    _scheduleConflictRefresh();
  }

  // ===========================================================================
  // Venue autocomplete
  // ===========================================================================

  void _onVenueChanged() {
    _venueDebounce?.cancel();
    final q = _eventCity.text.trim();
    if (q.length < 3) {
      if (_venueSuggestions.isNotEmpty && mounted) {
        setState(() => _venueSuggestions.clear());
      }
      return;
    }
    _venueDebounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final uri = Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(q)}&format=json&limit=5',
        );
        final res = await http
            .get(uri, headers: {'User-Agent': 'CurateringWeb/1.0'})
            .timeout(const Duration(seconds: 8));
        if (res.statusCode != 200 || !mounted) return;
        final body = jsonDecode(res.body);
        if (body is! List) return;
        final next = body
            .whereType<Map>()
            .map((e) => '${e['display_name'] ?? ''}'.trim())
            .where((s) => s.isNotEmpty)
            .take(5)
            .toList();
        if (mounted) {
          setState(() {
            _venueSuggestions
              ..clear()
              ..addAll(next);
          });
        }
      } catch (_) {}
    });
  }

  // ===========================================================================
  // Menu helpers
  // ===========================================================================

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
    final selIds = <String>{};
    for (final block in _menuSelections) {
      final ids = (block['dishIds'] as List<dynamic>? ?? const [])
          .map((id) => id.toString())
          .where((id) => allowedIds.contains(id))
          .toList();
      if (ids.isEmpty) continue;
      selIds.addAll(ids);
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
      ..addAll(selIds);
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

  void _switchMenuPrefTab(int index) {
    setState(() {
      _menuPrefTabIndex = index;
      _menuSelections.clear();
      _selectedDishIds.clear();
    });
  }

  void _onInlineMenuSelectionChanged(List<Map<String, dynamic>> blocks) {
    _applyMenuSelections(blocks);
  }

  // ===========================================================================
  // Validation
  // ===========================================================================

  bool get _isEventStyling =>
      _serviceType == 'catering+event' ||
      isInquiryCateringWithEventStyling(_inquiryType);

  bool get _contactNumberInvalid {
    final phone = _contactNumber.text.trim();
    if (phone.isEmpty) return true;
    if (phone.length > 11) return true;
    return phone.length < 7 || !RegExp(r'^[0-9+\-\s()]+$').hasMatch(phone);
  }

  bool get _emailInvalid {
    final email = _inquiryEmail.text.trim();
    if (email.isEmpty) return true;
    return !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
  }

  bool get _eventTypeOtherInvalid =>
      _eventTypeChoice == 'Other' && _eventTypeOther.text.trim().isEmpty;

  bool get _hasAnyPartialWindow =>
      _eventWindows.any((w) => w.date != null || w.from != null || w.to != null) &&
      _eventWindows.any(
        (w) => !(w.date != null && w.from != null && w.to != null),
      );

  bool get _hasNoCompleteWindow =>
      _eventWindows
          .where((w) => w.date != null && w.from != null && w.to != null)
          .isEmpty;

  bool get _hasWindowTimeRangeError => _eventWindows.any((w) {
    if (w.date == null || w.from == null || w.to == null) return false;
    final sm = w.from!.hour * 60 + w.from!.minute;
    final em = w.to!.hour * 60 + w.to!.minute;
    return em <= sm;
  });

  bool get _guestCountInvalid {
    final raw = _guestCount.text.trim();
    if (raw.isEmpty) return true;
    final gNum = int.tryParse(raw);
    if (gNum == null || gNum < 1) return true;
    return gNum < _minPaxForCurrentInquiry();
  }

  String _resolvedEventType() {
    if (_eventTypeChoice != 'Other') return _eventTypeChoice;
    return _eventTypeOther.text.trim();
  }

  String? _resolvedCategory(String? selected, TextEditingController other) {
    if (selected == null || selected.isEmpty) return null;
    if (selected == 'Other') {
      final t = other.text.trim();
      return t.isEmpty ? 'Other' : t;
    }
    return selected;
  }

  List<String> _resolvedMultiSelectWithOther(
    List<String> selected,
    TextEditingController other,
  ) {
    final values = selected.where((v) => v != 'Other').toList();
    if (selected.contains('Other')) {
      final custom = other.text.trim();
      if (custom.isNotEmpty) values.add(custom);
    }
    return values;
  }

  InputDecoration _requiredDecoration({
    required String label,
    required bool invalid,
    String? hint,
    Widget? suffixIcon,
  }) {
    final red = Colors.red.shade700;
    final bad = _attemptedSubmit && invalid;
    final borderSide = BorderSide(color: bad ? red : Colors.grey.shade400);
    return InputDecoration(
      labelText: label,
      hintText: hint,
      suffixIcon: suffixIcon,
      errorText: bad ? 'Required' : null,
      border: OutlineInputBorder(borderSide: borderSide),
      enabledBorder: OutlineInputBorder(borderSide: borderSide),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(
          color: bad ? red : AntdTokens.brandPrimary,
          width: bad ? 1.5 : 2,
        ),
      ),
    );
  }

  String? _validateInquiry() {
    if (_customerName.text.trim().isEmpty) return 'Enter customer name.';
    if (_contactPerson.text.trim().isEmpty) return 'Enter contact person.';
    final phone = _contactNumber.text.trim();
    if (phone.isEmpty) return 'Enter contact number.';
    if (phone.length > 11) {
      return 'Contact number must be at most 11 characters.';
    }
    if (phone.length < 7 || !RegExp(r'^[0-9+\-\s()]+$').hasMatch(phone)) {
      return 'Enter a valid contact number.';
    }
    final email = _inquiryEmail.text.trim();
    if (email.isEmpty) return 'Enter email address.';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'Enter a valid email address.';
    }
    if (_eventCity.text.trim().isEmpty) return 'Enter event venue.';
    for (final w in _eventWindows) {
      final any = w.date != null || w.from != null || w.to != null;
      final all = w.date != null && w.from != null && w.to != null;
      if (any && !all) {
        return 'Complete event date, start time, and end time for each row (or remove extra rows).';
      }
    }
    final completeWindows = _eventWindows
        .where((w) => w.date != null && w.from != null && w.to != null)
        .toList();
    if (completeWindows.isEmpty) {
      return 'Set at least one event day with start and end time.';
    }
    for (final w in completeWindows) {
      final sm = w.from!.hour * 60 + w.from!.minute;
      final em = w.to!.hour * 60 + w.to!.minute;
      if (em <= sm) return 'End time must be after start time for each event.';
    }
    if (!_menuChoicePicked) return 'Choose a menu preference.';
    if (_curateOwn && _selectedDishIds.length < _minSelectedDishesRequired) {
      return 'Select at least $_minSelectedDishesRequired dish(es) for the menu.';
    }
    if (_curateOwn && _selectedDishIds.length > _maxSelectedDishesRequired) {
      return 'Select at most $_maxSelectedDishesRequired dishes for the menu.';
    }
    if (!_curateOwn && _menuSelections.isEmpty && !_isSuggestMenuMode) {
      final block = _menuSelections.isNotEmpty ? _menuSelections.first : null;
      if (block == null) {
        return 'Choose your menu using the options below.';
      }
    }
    if (_isEventStyling && _themeDesignChoice.isEmpty) {
      return 'Choose an event theme design option.';
    }
    if (_isEventStyling &&
        _themeDesignChoice == 'create_own' &&
        (_aiThemeDesignPayload == null ||
            '${_aiThemeDesignPayload!['generatedImageUrl'] ?? ''}'
                .trim()
                .isEmpty)) {
      return 'Create your theme design before submitting.';
    }
    if (_isEventStyling && _eventTitle.text.trim().isEmpty) {
      return 'Enter event title.';
    }
    if (_eventTypeChoice == 'Other' && _eventTypeOther.text.trim().isEmpty) {
      return 'Describe the event type for "Other".';
    }
    if (_foodTastingRequested &&
        (_foodTastingDate.text.trim().isEmpty ||
            _foodTastingTime.text.trim().isEmpty)) {
      return 'Enter date and time for food tasting.';
    }
    final rawGuests = _guestCount.text.trim();
    if (rawGuests.isEmpty) return 'Enter number of guests.';
    final gNum = int.tryParse(rawGuests);
    if (gNum == null || gNum < 1) return 'Enter a valid number of guests.';
    final min = _minPaxForCurrentInquiry();
    if (gNum < min) return 'Minimum guests for this inquiry type is $min.';
    return null;
  }

  bool get _isSuggestMenuMode =>
      _menuChoicePicked &&
      !_curateOwn &&
      _menuSuggestionNote.isNotEmpty;

  // ===========================================================================
  // Build menu for API
  // ===========================================================================

  List<Map<String, dynamic>> _buildMenuForApi() {
    if (_isSuggestMenuMode) {
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
    final dishById = _activeDishById;
    return _menuSelections.map((block) {
      final out = Map<String, dynamic>.from(block);
      final ids = (out['dishIds'] as List<dynamic>? ?? const [])
          .map((id) => id.toString())
          .where((id) => id.isNotEmpty)
          .toList();
      out['dishRows'] = ids.map((id) {
        final dish = dishById[id];
        final addCharge = dish?.additionalChargeAmount ?? 0;
        return <String, dynamic>{
          'dishId': id,
          'dishName': dish?.name ?? id,
          'additionalChargeAmount': addCharge,
          'menu_dishes_additional_charge_amount': addCharge,
        };
      }).toList();
      if ((out['kind'] as String? ?? '') == 'set') {
        out['additionalChargeRows'] = additionalRows;
        out['additionalChargeTotal'] = additionalTotal;
      }
      return out;
    }).toList();
  }

  // ===========================================================================
  // Theme design payload for API
  // ===========================================================================

  Map<String, dynamic>? _buildThemeDesignForApi() {
    if (!_isEventStyling) return null;
    if (_themeDesignChoice == 'suggest') {
      return {
        'eventDesignSource': 'macrina',
        'note': _themeNotesController.text.trim(),
        'reference_images': _themeReferenceImagesB64,
      };
    }
    if (_themeDesignChoice == 'create_own' && _aiThemeDesignPayload != null) {
      return Map<String, dynamic>.from(_aiThemeDesignPayload!);
    }
    return null;
  }

  // ===========================================================================
  // Submit
  // ===========================================================================

  Future<void> _handleSubmit() async {
    setState(() => _attemptedSubmit = true);
    final v = _validateInquiry();
    if (v != null) {
      showAntdMessage(context, v);
      return;
    }
    final est = _estimatedCost();
    final typeLabel = _resolvedEventType();

    final ok = await showAntdModal<bool>(
      context: context,
      title: 'Submit inquiry?',
      maxWidth: 520,
      barrierDismissible: false,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Type: ${inquiryTypeDisplayLabel(_inquiryType)}'),
          if (_isEventStyling && _eventTitle.text.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Event: ${_eventTitle.text.trim()}'),
          ],
          const SizedBox(height: 6),
          Text('Event type: $typeLabel'),
          const SizedBox(height: 6),
          Text('Guests: ${_guestCount.text.trim()}'),
          if (_paxBufferForPricing() > 0) ...[
            const SizedBox(height: 6),
            Text('Pax buffer: ${_paxBufferForPricing()}'),
          ],
          const SizedBox(height: 6),
          Text('Venue: ${_eventCity.text.trim()}'),
          const SizedBox(height: 6),
          Text('When: ${_serializedEventDates()}'),
          const SizedBox(height: 6),
          Text('Estimated: ₱${est.toStringAsFixed(2)}'),
          if (_includeMinimalStyling && !_isEventStyling) ...[
            const SizedBox(height: 6),
            const Text('✓ Includes minimal event styling'),
          ],
        ],
      ),
      actions: [
        AntdCancelButton(
          label: 'Back',
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AntdPrimaryButton(
          label: 'Submit',
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );

    if (ok != true || !mounted) return;
    await _submitInquiry();
  }

  Future<void> _submitInquiry() async {
    setState(() => _submitting = true);
    try {
      final guestsSaved = _guestCountForSubmit();
      final paxBufferSaved = _paxBufferForPricing();
      final est = _estimatedCost();
      final scheduleSlots = _buildScheduleSlotsForApi();

      final payload = <String, dynamic>{
        'orderType': _isEventStyling ? 'catering_event' : 'catering',
        'inquiryType': _isEventStyling
            ? kInquiryTypeCateringWithEventStyling
            : kInquiryTypeCatering,
        'serviceIncluded': _isEventStyling
            ? 'yes'
            : (_includeCateringService == true ? 'yes' : 'no'),
        'eventTitle': !_isEventStyling
            ? _customerName.text.trim()
            : _eventTitle.text.trim(),
        'eventType': _resolvedEventType(),
        'formalityLevel': _formalityLevel,
        'eventSetting': _eventSetting,
        'eventCity': _eventCity.text.trim(),
        'customerName': _customerName.text.trim().isNotEmpty
            ? _customerName.text.trim()
            : _contactPerson.text.trim(),
        'contactPerson': _contactPerson.text.trim(),
        'contactNumber': _contactNumber.text.trim(),
        'emailAddress': _inquiryEmail.text.trim(),
        'address': _eventCity.text.trim(),
        if (_addressLat != null) 'addressLat': _addressLat,
        if (_addressLng != null) 'addressLng': _addressLng,
        'guestCount': guestsSaved,
        'paxBuffer': paxBufferSaved,
        'scheduleSlots': scheduleSlots,
        'date_of_event': _scheduleSlotsJsonForSubmit(),
        'menu': _buildMenuForApi(),
        'curateOwnMenu': _curateOwn,
        'menuSuggestionNote': _curateOwn ? '' : _menuSuggestionNote,
        'selectedSetMenu': _selectedSetMenu,
        'selectedDishes': _selectedDishIds.toList(),
        'estimatedTotal': est,
        'costBreakdown': [
          {
            'label': 'Base food cost',
            'amount': guestsSaved * kPesosPerPax,
          },
          {
            'label': 'Pax buffer',
            'amount': paxBufferSaved * kPesosPerPax,
          },
        ],
        'foodTastingRequested': _foodTastingRequested,
        if (_foodTastingRequested) ...{
          'foodTastingDate': _foodTastingDate.text.trim(),
          'foodTastingTime': _foodTastingTime.text.trim(),
        },
        'allergens': _allergensSerialized.trim(),
        'guestAllergens': _allergensSerialized.trim(),
        'event_setting': _eventSetting,
        'service_included': _serviceIncluded,
        'formality_level': _formalityLevel,
        'note': _note.text.trim(),
        'theme_suggestion_note': _themeNotesController.text.trim(),
        'includeMinimalEventStyling': _includeMinimalStyling,
        'source': 'web',
      };

      final themeDesign = _buildThemeDesignForApi();
      if (themeDesign != null) {
        payload['themeDesign'] = themeDesign;
        payload['theme_design'] = themeDesign;
        payload['include_event_theme'] = true;
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
        setState(() {
          _submittedCateringId =
              submittedId.isEmpty ? null : submittedId;
          _formSubmitted = true;
          _currentStep = _InquiryStep.completed;
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
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ===========================================================================
  // Reset form
  // ===========================================================================

  void _resetInquiryForm() {
    setState(() {
      _inquiryType = kInquiryTypeCatering;
      _currentStep = _InquiryStep.packages;
      _activeSideTab = _SideTab.eventInfo;
      _curateOwn = false;
      _menuChoicePicked = false;
      _attemptedSubmit = false;
      _themeDesignChoice = '';
      _themeDesignSessionId =
          'inquiry-${DateTime.now().microsecondsSinceEpoch}';
      _aiThemeDesignPayload = null;
      _menuSuggestionNote = '';
      _themeSuggestionNote = '';
      _selectedSetMenu = 'All Dishes';
      _selectedDishIds.clear();
      _eventTypeChoice = 'Birthday';
      _eventSetting = 'Indoor';
      _serviceIncluded = 'no';
      _formalityLevel = 'casual';
      _foodTastingRequested = false;
      _themeReferenceImagesB64.clear();
      _allergensSerialized = '';
      _serviceType = 'catering';
      _includeCateringService = null;
      _includeMinimalStyling = false;
      _menuPrefTabIndex = 0;
      _menuSelections.clear();
      _formSubmitted = false;
      _submittedCateringId = null;
      _eventWindows
        ..clear()
        ..add(_InquiryEventWindow());
      _publicScheduleConflictCount = 0;
      _wantsCustomDesign = false;
      _selectedEventType = null;
      _selectedStyle = null;
      _selectedMood = null;
      _selectedColors.clear();
      _selectedDecor.clear();
      _generatedImageUrl = null;
      _generatedImageHistory.clear();
      _genAiError = null;
      _venueFieldError = null;
      _venuePhotoBase64 = null;
      _customerSameAsContact = false;
      _addressLat = null;
      _addressLng = null;
    });
    _themeNotesController.clear();
    _landingPaxController.clear();
    _guestCount.clear();
    _paxBuffer.clear();
    _eventTitle.clear();
    _eventTypeOther.clear();
    _customerName.clear();
    _contactPerson.clear();
    _contactNumber.clear();
    _inquiryEmail.clear();
    _eventCity.clear();
    _note.clear();
    _foodTastingDate.clear();
    _foodTastingTime.clear();
    _menuSearchController.clear();
    _designPromptController.clear();
    _eventTypeDesignOtherController.clear();
    _styleOtherController.clear();
    _moodOtherController.clear();
    _colorOtherController.clear();
    _decorOtherController.clear();
    _prefillFromCustomerProfile();
  }

  // ===========================================================================
  // AI event design helpers
  // ===========================================================================

  Future<void> _pickThemeReferenceImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
        withData: true,
      );
      if (result == null || !mounted) return;
      for (final file in result.files) {
        if (file.bytes != null) {
          final b64 = base64Encode(file.bytes!);
          if (!_themeReferenceImagesB64.contains(b64)) {
            setState(() => _themeReferenceImagesB64.add(b64));
          }
        }
      }
    } catch (_) {}
  }

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
              _venuePhotoBase64 = base64String;
              _venueFieldError = null;
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
    final eventType = _resolvedEventType();
    final style = _resolvedCategory(_selectedStyle, _styleOtherController);
    final mood = _resolvedCategory(_selectedMood, _moodOtherController);
    final colors =
        _resolvedMultiSelectWithOther(_selectedColors, _colorOtherController);
    final decor =
        _resolvedMultiSelectWithOther(_selectedDecor, _decorOtherController);
    final notes = _designPromptController.text.trim();
    return <String>[
      if (eventType.isNotEmpty)
        '$eventType event venue'
      else
        'event venue',
      if (style != null && style.isNotEmpty) '$style theme',
      if (mood != null && mood.isNotEmpty) '$mood atmosphere',
      if (colors.isNotEmpty) '${colors.join(', ')} color palette',
      if (decor.isNotEmpty) '${decor.join(', ')} decorations',
      if (notes.isNotEmpty) notes,
      'photorealistic event styling',
      'luxury interior photography',
      'realistic venue decorations',
      'cinematic lighting',
      'ultra detailed',
    ].join(', ');
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
    final eventType = _resolvedEventType();
    final style = _resolvedCategory(_selectedStyle, _styleOtherController);
    final mood = _resolvedCategory(_selectedMood, _moodOtherController);
    final colors =
        _resolvedMultiSelectWithOther(_selectedColors, _colorOtherController);
    final decor =
        _resolvedMultiSelectWithOther(_selectedDecor, _decorOtherController);
    final notes = _designPromptController.text.trim();
    return {
      'task_type': 'event_prompt_expansion',
      if (eventType.isNotEmpty)
        'event_type': eventType.trim().toLowerCase(),
      if (style != null && style.isNotEmpty) ...{
        'theme': style.trim(),
        'style': style.trim(),
      },
      if (mood != null && mood.isNotEmpty) 'mood': mood.trim(),
      if (colors.isNotEmpty) ...{'colors': colors, 'color_palette': colors},
      if (decor.isNotEmpty) ...{'decor': decor, 'decor_elements': decor},
      if (notes.isNotEmpty) ...{'notes': notes, 'custom_instructions': notes},
      'formality': _formalityLevel,
      if (_eventCity.text.trim().isNotEmpty) 'venue': _eventCity.text.trim(),
      if (_guestCount.text.trim().isNotEmpty)
        'guest_count': _guestCount.text.trim(),
    };
  }

  Map<String, dynamic> _eventDesignRunpodMeta({
    EventPromptExpansion? expansion,
  }) {
    final config = _eventDesignConfig();
    return {
      ...config,
      'task_type': 'sdxl_event_design',
      'use_nlp_prompt_expansion': false,
      if (expansion != null) ...expansion.toSdxlMeta(),
      'negative_prompt': _eventDesignNegativePrompt(),
      'guidance_scale': 6.5,
      'controlnet': {
        'enabled': true,
        'preprocessor': 'canny',
        'preserve_venue': true,
        'conditioning_scale': 0.65,
      },
      'controlnet_conditioning_scale': 0.65,
    };
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
    if (_resolvedEventType().isEmpty &&
        _selectedStyle == null &&
        _selectedMood == null &&
        _selectedColors.isEmpty &&
        _selectedDecor.isEmpty &&
        _designPromptController.text.isEmpty) {
      setState(
        () => _genAiError =
            'Please select at least one option or add instructions in the notes field.',
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
        _generatedImageUrl = null;
      }
    });
  }

  /// Event design payload for staff "view details" (AI image vs Macrina text inspiration).
  Map<String, dynamic>? _buildThemeDesignForApi() {
    if (!_isCateringWithEventStyling) return null;
    if (_eventDesignMode == 'macrina') {
      return {
        'eventDesignSource': 'macrina',
        'macrinaColorPalette': _macrinaPalette.text.trim(),
        'macrinaTheme': _macrinaTheme.text.trim(),
        'serviceType':
            _isCateringWithEventStyling ? 'catering+event' : _serviceType,
        'eventSetting': _eventSetting,
        'event_setting': _eventSetting,
      };
    }
    if (_eventDesignMode == 'customer') {
      final style =
          _resolvedCategory(_selectedStyle, _styleOtherController) ?? '';
      final mood = _resolvedCategory(_selectedMood, _moodOtherController) ?? '';
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
      return {
        'eventDesignSource': 'customer_ai',
        'wantsCustomDesign': _wantsCustomDesign,
        'serviceType':
            _isCateringWithEventStyling ? 'catering+event' : _serviceType,
        'eventSetting': _eventSetting,
        'event_setting': _eventSetting,
        if (_generatedImageUrl != null && _generatedImageUrl!.trim().isNotEmpty)
          'generatedImageUrl': _generatedImageUrl!.trim(),
        if (eventType.isNotEmpty) 'eventDesignEventType': eventType,
        if (style.isNotEmpty) 'style': style,
        if (mood.isNotEmpty) 'mood': mood,
        if (colors.isNotEmpty) 'colorPalette': colors,
        if (decor.isNotEmpty) 'decorElements': decor,
        if (_designPromptController.text.trim().isNotEmpty)
          'customInstructions': _designPromptController.text.trim(),
      };
    }
    return null;
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
      _dateController.clear();
      _timeController.clear();
      _endTimeController.clear();
      _eventCityController.clear();
      _eventSetting = 'Indoor';
      _foodTastingRequested = false;
      _foodTastingDateController.clear();
      _foodTastingTimeController.clear();
      _extraScheduleSlots.clear();
      _suggestMenu = false;
      _eventType = 'Birthday';
      _inquiryEventTypeOtherController.clear();
      _formality = 'casual';
      _serviceType = 'catering';
      _formPhase = 0;
      _eventDesignMode = null;
      _macrinaPalette.clear();
      _macrinaTheme.clear();
      _fieldErrors.clear();
      _venueFieldError = null;
      _genAiError = null;
      _menuPrefTabIndex = 0;
      _includeCateringService = null;
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
    });
  }

  // ===========================================================================
  // BUILD - Step 1: Catering Packages page
  // ===========================================================================

  Widget _buildPackagesPage(BuildContext context) {
    final content = WebsiteContentStore.instance;

    return Center(
      child: SingleChildScrollView(
        padding: websitePagePadding(context),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    content.inquiryPageTitle,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.getFont(
                      _primaryFont,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: _darkHeader,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _accentYellow,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      content.inquiryPageSubtitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _darkHeader,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Our Catering Packages',
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 20),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.1,
                    children: _locationPackages.map((pkg) {
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(pkg['icon'] as IconData, size: 28, color: _darkHeader),
                            const SizedBox(height: 8),
                            Text(
                              pkg['title'] as String,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: _darkHeader),
                            ),
                            const SizedBox(height: 6),
                            Expanded(
                              child: Text(
                                pkg['description'] as String,
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade700, height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: AntdPrimaryButton(
                      label: 'NEXT',
                      onPressed: _proceedFromPackages,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // BUILD - Step 2: Enter number of guests
  // ===========================================================================

  Widget _buildGuestCountPage(BuildContext context) {
    final pax = _landingPaxParsed;
    final isCateringWithEvent =
        pax != null && pax >= kInquiryLandingEventStylingMinPax;

    return Center(
      child: SingleChildScrollView(
        padding: websitePagePadding(context),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'How many guests will you have?',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.getFont(
                      _primaryFont,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: _darkHeader,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This determines your package and pricing.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _landingPaxController,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    decoration: const InputDecoration(
                      hintText: 'Number of guests',
                      counterText: '',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  if (pax != null && pax > 0) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isCateringWithEvent
                            ? const Color(0xFFFFF8E1)
                            : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isCateringWithEvent
                              ? _accentYellow
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(
                                isCateringWithEvent
                                    ? Icons.celebration
                                    : Icons.restaurant,
                                color: _darkHeader,
                                size: 22,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  isCateringWithEvent
                                      ? 'Catering with Event Styling'
                                      : 'Catering Only',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    color: _darkHeader,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Estimated: ₱${(pax * kPesosPerPax).toStringAsFixed(0)} '
                            '(₱${kPesosPerPax.toStringAsFixed(0)} × $pax guests)',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          if (isCateringWithEvent) ...[
                            const SizedBox(height: 6),
                            Text(
                              'With $pax guests, this inquiry qualifies for Catering with Event Styling.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.green.shade800,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => setState(
                          () => _currentStep = _InquiryStep.packages,
                        ),
                        icon: const Icon(Icons.arrow_back, size: 16),
                        label: const Text('Back'),
                      ),
                      const Spacer(),
                      AntdPrimaryButton(
                        label: 'NEXT',
                        onPressed: _proceedFromGuestCount,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPackageCard({
    required String title,
    required String description,
    required bool selected,
    required bool highlighted,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: highlighted ? const Color(0xFFFFF8E1) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: highlighted ? _accentYellow : Colors.grey.shade300,
          width: highlighted ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: highlighted
                  ? _accentYellow.withOpacity(0.2)
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: highlighted ? _darkHeader : Colors.grey.shade600),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      highlighted
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      size: 18,
                      color: highlighted ? _accentYellow : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: highlighted ? _darkHeader : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // BUILD - 3-Column Layout (Steps 2+)
  // ===========================================================================

  Widget _buildThreeColumnLayout(BuildContext context) {
    if (isMobile(context)) {
      return _buildMobileLayout(context);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // LEFT: Side tabs
        SizedBox(
          width: 300,
          child: _buildSideTabNav(),
        ),
        // CENTER: Content
        Expanded(
          flex: 3,
          child: _buildCenterContent(),
        ),
        // RIGHT: Estimated cost panel
        SizedBox(
          width: 400,
          child: _buildEstimatedCostPanel(),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildMobileTabs(),
        Expanded(child: _buildCenterContent()),
        _buildEstimatedCostPanel(),
      ],
    );
  }

  Widget _buildMobileTabs() {
    final tabs = <_SideTab>[
      _SideTab.eventInfo,
      _SideTab.menu,
      if (_isEventStyling) _SideTab.themeDesign,
    ];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: tabs.map((tab) {
          final active = _activeSideTab == tab;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _activeSideTab = tab),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: active ? _accentYellow : Colors.transparent,
                      width: 3,
                    ),
                  ),
                ),
                child: Text(
                  _sideTabLabel(tab),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: active ? FontWeight.bold : FontWeight.w500,
                    color: active ? _darkHeader : Colors.grey.shade600,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ===========================================================================
  // BUILD - Side Tab Navigation
  // ===========================================================================

  String _sideTabLabel(_SideTab tab) {
    switch (tab) {
      case _SideTab.eventInfo:
        return 'Event Information';
      case _SideTab.menu:
        return 'Menu';
      case _SideTab.themeDesign:
        return 'Event Theme Design';
    }
  }

  IconData _sideTabIcon(_SideTab tab) {
    switch (tab) {
      case _SideTab.eventInfo:
        return Icons.event_note;
      case _SideTab.menu:
        return Icons.restaurant_menu;
      case _SideTab.themeDesign:
        return Icons.palette;
    }
  }

  Widget _buildSideTabNav() {
    final tabs = <_SideTab>[
      _SideTab.eventInfo,
      _SideTab.menu,
      if (_isEventStyling) _SideTab.themeDesign,
    ];
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              inquiryTypeDisplayLabel(_inquiryType),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: _darkHeader,
              ),
            ),
          ),
          const Divider(height: 1),
          ...tabs.map((tab) {
            final active = _activeSideTab == tab;
            return Material(
              color: active ? _accentYellow.withOpacity(0.15) : Colors.transparent,
              child: InkWell(
                onTap: () => setState(() => _activeSideTab = tab),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(
                        color: active ? _accentYellow : Colors.transparent,
                        width: 4,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _sideTabIcon(tab),
                        size: 20,
                        color: active ? _darkHeader : Colors.grey.shade500,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _sideTabLabel(tab),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                            color: active ? _darkHeader : Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => setState(() {
                  _currentStep = _InquiryStep.guestCount;
                  _attemptedSubmit = false;
                }),
                icon: const Icon(Icons.arrow_back, size: 16),
                label: const Text('Back to Guest Count'),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ===========================================================================
  // BUILD - Center Content
  // ===========================================================================

  Widget _buildCenterContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_activeSideTab == _SideTab.eventInfo)
            _buildEventInfoTab(),
          if (_activeSideTab == _SideTab.menu)
            _buildMenuTab(),
          if (_activeSideTab == _SideTab.themeDesign && _isEventStyling)
            _buildThemeDesignTab(),
          const SizedBox(height: 24),
          // Navigation buttons
          Row(
            children: [
              if (_activeSideTab != _SideTab.eventInfo)
                TextButton.icon(
                  onPressed: _prevSideTab,
                  icon: const Icon(Icons.arrow_back, size: 16),
                  label: const Text('Previous'),
                ),
              const Spacer(),
              if (_isLastSideTab())
                SizedBox(
                  width: 200,
                  child: AntdPrimaryButton(
                    label: 'REVIEW & SUBMIT',
                    loading: _submitting,
                    onPressed: _submitting ? null : _handleSubmit,
                  ),
                )
              else
                ElevatedButton.icon(
                  onPressed: _nextSideTab,
                  icon: const Text('Next'),
                  label: const Icon(Icons.arrow_forward, size: 16),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accentYellow,
                    foregroundColor: _darkHeader,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  bool _isLastSideTab() {
    final tabs = <_SideTab>[
      _SideTab.eventInfo,
      _SideTab.menu,
      if (_isEventStyling) _SideTab.themeDesign,
    ];
    return _activeSideTab == tabs.last;
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

  void _nextSideTab() {
    final tabs = <_SideTab>[
      _SideTab.eventInfo,
      _SideTab.menu,
      if (_isEventStyling) _SideTab.themeDesign,
    ];
    final idx = tabs.indexOf(_activeSideTab);
    if (idx < tabs.length - 1) {
      setState(() => _activeSideTab = tabs[idx + 1]);
    }
  }

  void _prevSideTab() {
    final tabs = <_SideTab>[
      _SideTab.eventInfo,
      _SideTab.menu,
      if (_isEventStyling) _SideTab.themeDesign,
    ];
    final idx = tabs.indexOf(_activeSideTab);
    if (idx > 0) {
      setState(() => _activeSideTab = tabs[idx - 1]);
    }
  }

  // ===========================================================================
  // BUILD - Estimated Cost Panel (Right Column)
  // ===========================================================================

  Widget _buildEstimatedCostPanel() {
    final estimate = _estimatedCost();
    final guests = _billableGuestCountForPricing();
    final buffer = _paxBufferForPricing();
    final additionalTotal = _menuAdditionalChargeTotal();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long, size: 20, color: _darkHeader),
              const SizedBox(width: 8),
              const Text(
                'Estimated Cost',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _darkHeader,
                ),
              ),
            ],
          ),
          const Divider(height: 24),

          // Package type with full description
          _costPanelRow(
            'Package',
            _packageDisplayName,
            isBold: true,
          ),
          if (_selectedPackageIndex >= 0 && _selectedPackageIndex < _locationPackages.length) ...[
            const SizedBox(height: 4),
            Text(
              _locationPackages[_selectedPackageIndex]['description'] as String,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600, height: 1.3),
            ),
          ],
          const SizedBox(height: 12),

          // Venue info (full address)
          if (_eventCity.text.trim().isNotEmpty) ...[
            const Text('Event Venue', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _darkHeader)),
            const SizedBox(height: 4),
            Text(
              _eventCity.text.trim(),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.3),
              softWrap: true,
            ),
            const SizedBox(height: 8),
          ],

          // Taguig note
          if (_isVenueInTaguig() && guests > 0 && guests < 50) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, size: 16, color: Colors.green.shade700),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Catering only within Taguig',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          const Divider(height: 16),

          // Breakdown
          if (guests > 0) ...[
            _costPanelRow(
              'Base food cost',
              '₱${(guests * kPesosPerPax).toStringAsFixed(0)}',
            ),
            _costPanelRow(
              '  ₱${kPesosPerPax.toStringAsFixed(0)} × $guests guests',
              '',
              isSubtle: true,
            ),
            if (buffer > 0) ...[
              const SizedBox(height: 4),
              _costPanelRow(
                'Pax buffer ($buffer)',
                '₱${(buffer * kPesosPerPax).toStringAsFixed(0)}',
              ),
            ],
            if (additionalTotal > 0) ...[
              const SizedBox(height: 4),
              _costPanelRow(
                'Extra set-menu fees',
                '₱${additionalTotal.toStringAsFixed(0)}',
              ),
            ],
          ],

          const SizedBox(height: 12),
          const Divider(height: 8),
          const SizedBox(height: 8),

          // Total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Flexible(
                child: Text(
                  'Estimated Total',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _darkHeader,
                  ),
                ),
              ),
              Flexible(
                child: Text(
                  '₱${(estimate + additionalTotal).toStringAsFixed(2)}',
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _darkHeader,
                  ),
                ),
              ),
            ],
          ),

          // Minimal styling checkbox (for catering only / <50 guests)
          if (!_isEventStyling) ...[
            const SizedBox(height: 16),
            const Divider(height: 8),
            const SizedBox(height: 8),
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: _includeMinimalStyling,
              onChanged: (v) =>
                  setState(() => _includeMinimalStyling = v ?? false),
              title: const Text(
                'I would like to include minimal event styling',
                style: TextStyle(fontSize: 13),
              ),
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ],

          const SizedBox(height: 16),
          Text(
            'Additional charges apply if you have additional requests not included in the package.',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _costPanelRow(String label, String value, {bool isBold = false, bool isSubtle = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            flex: 3,
            child: Text(
              label,
              softWrap: true,
              style: TextStyle(
                fontSize: isSubtle ? 11 : 13,
                fontWeight: isBold ? FontWeight.w700 : FontWeight.w400,
                color: isSubtle ? Colors.grey.shade500 : Colors.grey.shade800,
              ),
            ),
          ),
          if (value.isNotEmpty) ...[
            const SizedBox(width: 8),
            Flexible(
              flex: 2,
              child: Text(
                value,
                textAlign: TextAlign.end,
                softWrap: true,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
                  color: _darkHeader,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ===========================================================================
  // BUILD - Event Information Tab
  // ===========================================================================

  Widget _buildEventInfoTab() {
    final isEvent = _isEventStyling;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sectionTitle('Event Information'),
            const SizedBox(height: 12),

            // Event type ABOVE event title (requirement #4)
            _buildEventTypePicker(),
            const SizedBox(height: 12),
            TextField(
              controller: _eventTitle,
              decoration: _requiredDecoration(
                label: 'Event title',
                invalid: isEvent && _eventTitle.text.trim().isEmpty,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _customerName,
              decoration: _requiredDecoration(
                label: 'Customer',
                invalid: _customerName.text.trim().isEmpty,
              ),
              onChanged: (_) => setState(() {}),
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
      const SizedBox(height: 16),
      _responsiveThreeCol(
        context,
        AntdFieldShell(
          label: 'Customer Name',
          required: true,
          errorText: _fieldErrors['customer'],
          child: AntdOutlineInput(
            controller: _customer,
            hintText: 'Enter your name',
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
            onChanged: (_) => onFieldChanged('contactPerson'),
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
          ),
        ),
        AntdFieldShell(
          label: 'Number of Guests',
          required: true,
          errorText: _fieldErrors['guests'],
          child: AntdOutlineInput(
            controller: _guests,
            hintText: 'Guest count',
            keyboardType: TextInputType.number,
            onChanged:
                (_) => setState(() {
                  _fieldErrors.remove('guests');
                  _fieldErrors.remove('cateringService');
                }),
          ),
        ),
      ),
      const SizedBox(height: 8),
      Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          onPressed: () async {
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
          },
          icon: const Icon(Icons.map_outlined, size: 20),
          label: const Text('Pick on map (OpenStreetMap)'),
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
              }
            },
          ),
        ),
        AntdFieldShell(
          label: 'End Time',
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
                });
              }
            },
          ),
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
            initialValue: _eventSetting,
            isExpanded: true,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'Indoor', child: Text('Indoor')),
              DropdownMenuItem(value: 'Outdoor', child: Text('Outdoor')),
              DropdownMenuItem(value: 'Mixed', child: Text('Mixed')),
            ],
            onChanged:
                (value) => setState(() => _eventSetting = value ?? 'Indoor'),
          ),
        ),
      ),
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
            const SizedBox(height: 8),
            TextField(
              controller: _note,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),

            // Service
            const SizedBox(height: 8),
            Text(
              'Service',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            Row(
              children: [
                Expanded(
                  child: RadioListTile<String>(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('With service'),
                    value: 'yes',
                    groupValue: _serviceIncluded,
                    onChanged: (v) =>
                        setState(() => _serviceIncluded = v ?? 'yes'),
                  ),
                ),
                Expanded(
                  child: RadioListTile<String>(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Without service'),
                    value: 'no',
                    groupValue: _serviceIncluded,
                    onChanged: (v) =>
                        setState(() => _serviceIncluded = v ?? 'no'),
                  ),
                ),
              ],
            ),

            // Food tasting
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _foodTastingRequested,
              title: const Text('With food tasting'),
              onChanged: (v) =>
                  setState(() => _foodTastingRequested = v ?? false),
            ),
            if (_foodTastingRequested) ...[
              const SizedBox(height: 6),
              _responsiveTwoCol(
                context,
                TextField(
                  controller: _foodTastingDate,
                  readOnly: true,
                  decoration: _requiredDecoration(
                    label: 'Food tasting date',
                    invalid: _foodTastingRequested &&
                        _foodTastingDate.text.trim().isEmpty,
                    hint: 'date',
                  ),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate:
                          DateTime.now().subtract(const Duration(days: 1)),
                      lastDate:
                          DateTime.now().add(const Duration(days: 365 * 2)),
                    );
                    if (d == null) return;
                    setState(() {
                      _foodTastingDate.text =
                          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
                    });
                  },
                ),
                TextField(
                  controller: _foodTastingTime,
                  readOnly: true,
                  decoration: _requiredDecoration(
                    label: 'Food tasting time',
                    invalid: _foodTastingRequested &&
                        _foodTastingTime.text.trim().isEmpty,
                    hint: 'time',
                  ),
                  onTap: () async {
                    final t = await showTimePicker(
                      context: context,
                      initialTime: const TimeOfDay(hour: 13, minute: 0),
                    );
                    if (t == null) return;
                    setState(() {
                      _foodTastingTime.text =
                          '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
                    });
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEventTypePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          value: kEventTypeChoices.contains(_eventTypeChoice)
              ? _eventTypeChoice
              : 'Other',
          decoration:
              _requiredDecoration(label: 'Event type', invalid: false),
          items: kEventTypeChoices
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: (v) => setState(() => _eventTypeChoice = v ?? 'Other'),
        ),
        if (_eventTypeChoice == 'Other') ...[
          const SizedBox(height: 8),
          TextField(
            controller: _eventTypeOther,
            decoration: _requiredDecoration(
              label: 'Describe event type',
              invalid: _eventTypeOtherInvalid,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ],
    );
  }

  // ===========================================================================
  // BUILD - Menu Tab
  // ===========================================================================

  Widget _buildMenuTab() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sectionTitle('Menu'),

            // Allergens
            const SizedBox(height: 8),
            AntdFieldShell(
              label: 'Food allergens to avoid',
              child: AllergenSelectorField(
                initialSerialized: _allergensSerialized,
                onChanged: (s) {
                  setState(() {
                    _allergensSerialized = s;
                    _pruneMenuSelectionsForCurrentAllergens();
                  });
                },
              ),
            ),

            const SizedBox(height: 20),
            const Text(
              'WOULD YOU LIKE TO CURATE YOUR OWN MENU?',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            RadioListTile<bool>(
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: true,
              groupValue: _menuChoicePicked ? _curateOwn : null,
              title: const Text('Yes, curate my own menu'),
              onChanged: (v) => setState(() {
                _menuChoicePicked = true;
                _curateOwn = true;
                _menuSuggestionNote = '';
                _selectedSetMenu = 'All Dishes';
                _selectedDishIds.clear();
                _menuSelections.clear();
              }),
            ),
            RadioListTile<bool>(
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: false,
              groupValue: _menuChoicePicked ? _curateOwn : null,
              title: const Text('No, suggest a menu'),
              onChanged: (v) => setState(() {
                _menuChoicePicked = true;
                _curateOwn = false;
                _selectedDishIds.clear();
                _menuSelections.clear();
                _menuSuggestionNote = 'No, suggest me a menu instead.';
              }),
            ),
            if (_attemptedSubmit && !_menuChoicePicked)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Required',
                  style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                ),
              ),
            if (_menuChoicePicked && _curateOwn) ...[
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
                      color: _menuPrefTabIndex == 0
                          ? AntdTokens.brandOnPrimary
                          : Colors.black87,
                      fontWeight: _menuPrefTabIndex == 0
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
                      color: _menuPrefTabIndex == 1
                          ? AntdTokens.brandOnPrimary
                          : Colors.black87,
                      fontWeight: _menuPrefTabIndex == 1
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
                  final loading = MenuStore.instance.isLoading ||
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
                        initialSelections:
                            List<Map<String, dynamic>>.from(_menuSelections),
                        mode: InquiryMenuPickerMode.inquiryExclusive,
                        minCustomDishes: 4,
                        maxCustomDishes: 8,
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
            if (_menuChoicePicked && !_curateOwn) ...[
              const SizedBox(height: 8),
              Text(
                'Our team will suggest a curated menu based on your event details and preferences.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // BUILD - Theme Design Tab
  // ===========================================================================

  Widget _buildThemeDesignTab() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sectionTitle('Event Theme Design'),
            const SizedBox(height: 4),
            const Text(
              'Tell us how you want to approach your event look and feel.',
              style: TextStyle(height: 1.35),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _eventDesignChoiceCard(
                    title: "Have Macrina's design my event",
                    subtitle:
                        'Share your palette and theme; our team will propose a look.',
                    selected: _themeDesignChoice == 'suggest',
                    onTap: () => setState(() {
                      _themeDesignChoice = 'suggest';
                      _aiThemeDesignPayload = null;
                    }),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _eventDesignChoiceCard(
                    title: 'I want to design my event',
                    subtitle:
                        'Use AI to explore styles, then submit with your inquiry.',
                    selected: _themeDesignChoice == 'create_own',
                    onTap: () => setState(
                      () => _themeDesignChoice = 'create_own',
                    ),
                  ),
                ),
              ],
            ),
            if (_attemptedSubmit && _themeDesignChoice.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Choose how you want to handle event design.',
                  style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                ),
              ),
            if (_themeDesignChoice == 'suggest') ...[
              const SizedBox(height: 12),
              TextField(
                controller: _themeNotesController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Theme / styling notes',
                  hintText:
                      'Describe preferred look, colors, motif, and styling notes',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _pickThemeReferenceImage,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Upload reference images'),
                  ),
                  const SizedBox(width: 8),
                  Text('${_themeReferenceImagesB64.length} image(s)'),
                ],
              ),
              if (_themeReferenceImagesB64.isNotEmpty) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: 82,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _themeReferenceImagesB64.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) => Stack(
                      children: [
                        RepaintBoundary(
                          key: ValueKey('theme_ref_$i'),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              base64Decode(_themeReferenceImagesB64[i]),
                              width: 82,
                              height: 82,
                              fit: BoxFit.cover,
                              gaplessPlayback: true,
                            ),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: InkWell(
                            onTap: () => setState(
                              () => _themeReferenceImagesB64.removeAt(i),
                            ),
                            child: Container(
                              color: Colors.black54,
                              padding: const EdgeInsets.all(2),
                              child: const Icon(
                                Icons.close,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
            if (_themeDesignChoice == 'create_own') ...[
              const SizedBox(height: 12),
              if (_aiThemeDesignPayload != null &&
                  '${_aiThemeDesignPayload!['generatedImageUrl'] ?? ''}'
                      .trim()
                      .isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: RepaintBoundary(
                    key: ValueKey('ai_design_${_aiThemeDesignPayload!['generatedImageUrl']}'),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        '${_aiThemeDesignPayload!['generatedImageUrl']}',
                        height: 160,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                      ),
                    ),
                  ),
                ),
              _buildAiDesignForm(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _eventDesignChoiceCard({
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
                    _generatedImageUrl!,
                    fit: BoxFit.contain,
                  ),
                ),
            child: Image.network(
              _generatedImageUrl!,
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
                onPressed: () => _downloadGeneratedImage(_generatedImageUrl!),
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
                  final selected = url == _generatedImageUrl;
                  return GestureDetector(
                    onTap: () => setState(() => _generatedImageUrl = url),
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
                      child: Image.network(url, fit: BoxFit.cover),
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
              _buildFormSectionTitle('Event Type'),
              DropdownButtonFormField<String>(
                value: _resolvedEventType().isNotEmpty
                    ? (_eventTypes.contains(_resolvedEventType())
                        ? _resolvedEventType()
                        : null)
                    : null,
                items: _eventTypes
                    .map((item) =>
                        DropdownMenuItem(value: item, child: Text(item)))
                    .toList(),
                onChanged: null,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  helperText: 'Set in Event Information tab',
                  helperStyle: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                hint: Text(_resolvedEventType().isNotEmpty
                    ? _resolvedEventType()
                    : 'Set in Event Information'),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildFormSectionTitle('Style'),
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
        _buildFormSectionTitle('Mood / Lighting'),
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
              _buildFormSectionTitle('Color Palette'),
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
              _buildFormSectionTitle('Decor Elements'),
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
        _buildFormSectionTitle('Additional Instructions'),
        AntdFieldShell(
          label: 'Notes',
          child: AntdOutlineInput(
            controller: _designPromptController,
            hintText: 'e.g., simple wedding setup with garden theme',
            maxLines: 3,
          ),
        ),
        const SizedBox(height: 16),
        _buildFormSectionTitle('Venue Photo'),
        OutlinedButton.icon(
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
              color: _venueFieldError != null
                  ? const Color(0xFFFF4D4F)
                  : _venuePhotoBase64 != null
                      ? Colors.green
                      : Colors.grey.shade400,
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
        if (_venuePhotoBase64 != null) ...[
          const SizedBox(height: 8),
          RepaintBoundary(
            key: const ValueKey('venue_photo'),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                base64Decode(_venuePhotoBase64!),
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              ),
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
            onPressed: (_submitting || _generatingDesign)
                ? null
                : _generateDesignPrompt,
            icon: _generatingDesign
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_fix_high),
            label: Text(
              _generatingDesign ? 'GENERATING…' : 'GENERATE EVENT DESIGN',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentYellow,
              foregroundColor: _darkHeader,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
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
                final selected = url == _generatedImageUrl;
                return GestureDetector(
                  onTap: () => setState(() {
                    _generatedImageUrl = url;
                    _aiThemeDesignPayload = {
                      'eventDesignSource': 'customer_ai',
                      'generatedImageUrl': url,
                      ..._eventDesignConfig(),
                    };
                  }),
                  child: Container(
                    width: 72,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: selected ? _accentYellow : Colors.grey.shade300,
                        width: selected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: RepaintBoundary(
                      key: ValueKey('gen_history_$url'),
                      child: Image.network(
                        url,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFormSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: _darkHeader,
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
      items: items
          .map((item) => DropdownMenuItem(value: item, child: Text(item)))
          .toList(),
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
      children: items.map((item) {
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
          selectedColor: _accentYellow,
          backgroundColor: Colors.grey.shade200,
          labelStyle: TextStyle(
            color: isSelected ? _darkHeader : Colors.black87,
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
              _venuePhotoBase64 = base64String;
              _venueFieldError = null;
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

    final visualPrompt = <String>[
      if (eventType != null && eventType.isNotEmpty)
        '$eventType event venue'
      else
        'event venue',
      if (style != null && style.isNotEmpty) '$style theme',
      if (mood != null && mood.isNotEmpty) '$mood atmosphere',
      if (colors.isNotEmpty) '${colors.join(', ')} color palette',
      if (decor.isNotEmpty) '${decor.join(', ')} decorations',
      if (notes.isNotEmpty) notes,
      'photorealistic event styling',
      'luxury interior photography',
      'realistic venue decorations',
      'cinematic lighting',
      'ultra detailed',
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

  Map<String, dynamic> _eventDesignRunpodMeta({
    EventPromptExpansion? expansion,
  }) {
    final config = _eventDesignConfig();
    return {
      ...config,
      'task_type': 'sdxl_event_design',
      'use_nlp_prompt_expansion': false,
      if (expansion != null) ...expansion.toSdxlMeta(),
      'negative_prompt': _eventDesignNegativePrompt(),
      'guidance_scale': 6.5,
      'controlnet': {
        'enabled': true,
        'preprocessor': 'canny',
        'preserve_venue': true,
        'conditioning_scale': 0.65,
      },
      'controlnet_conditioning_scale': 0.65,
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
      final res = await http.get(Uri.parse(url));
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
      final fallbackPrompt = _composeEventDesignPrompt();
      final venueB64 = _normalizeVenueB64ForRunpod(venueRaw);
      final expansion = await RunPodService.expandEventPrompt(
        _eventDesignConfig(),
        fallbackPrompt: fallbackPrompt,
      );
      final prompt = expansion.positivePrompt;
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
        strength: 0.58,
        numInferenceSteps: 30,
        guidanceScale: 6.5,
        designMeta: _eventDesignRunpodMeta(expansion: expansion),
      );

      if (imageUrl != null) {
        setState(() {
          _wantsCustomDesign = true;
          _generatedImageUrl = imageUrl;
          if (!_generatedImageHistory.contains(imageUrl)) {
            _generatedImageHistory.add(imageUrl);
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
