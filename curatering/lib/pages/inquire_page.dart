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
  static const int _maxSelectedDishesRequired = 10;
  static const int _visibleDishRows = 8;
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
  final _foodTastingDate = TextEditingController();
  final _foodTastingTime = TextEditingController();

  // ---- AI Event Design fields ----
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

  void _syncCustomerFromContact() {
    if (_customerSameAsContact) _customerName.text = _contactPerson.text;
  }

  // Real-time inquiry type change when guest count is updated
  void _onGuestCountChanged() {
    final raw = _guestCount.text.trim();
    if (raw.isEmpty) return;
    final pax = int.tryParse(raw);
    if (pax == null || pax < 1) return;
    final newType = pax >= kInquiryLandingEventStylingMinPax
        ? kInquiryTypeCateringWithEventStyling
        : kInquiryTypeCatering;
    final newServiceType =
        pax >= kInquiryLandingEventStylingMinPax ? 'catering+event' : 'catering';
    if (newType != _inquiryType || newServiceType != _serviceType) {
      setState(() {
        _inquiryType = newType;
        _serviceType = newServiceType;
        if (!_isEventStyling) {
          _includeMinimalStyling = _includeMinimalStyling;
        }
      });
    }
  }

  // ===========================================================================
  // Steps logic
  // ===========================================================================

  List<_InquiryStep> get _visibleSteps => const [
    _InquiryStep.packages,
    _InquiryStep.guestCount,
    _InquiryStep.form,
    _InquiryStep.completed,
  ];

  void _goToStep(_InquiryStep step) {
    if (!_visibleSteps.contains(step)) return;
    setState(() => _currentStep = step);
  }

  void _nextStep() {
    final steps = _visibleSteps;
    final idx = steps.indexOf(_currentStep);
    if (idx < steps.length - 1) {
      setState(() => _currentStep = steps[idx + 1]);
    }
  }

  void _prevStep() {
    final steps = _visibleSteps;
    final idx = steps.indexOf(_currentStep);
    if (idx > 0) {
      setState(() => _currentStep = steps[idx - 1]);
    }
  }

  // ===========================================================================
  // Step 1 → Step 2 → Step 3 navigation
  // ===========================================================================

  int? get _landingPaxParsed {
    final raw = _landingPaxController.text.trim();
    if (raw.isEmpty) return null;
    return int.tryParse(raw);
  }

  void _selectPackage(int index) {
    if (index < 0 || index >= _locationPackages.length) return;
    final pkg = _locationPackages[index];
    setState(() {
      _selectedPackageIndex = index;
      _inquiryType = (pkg['type'] as String?) ?? kInquiryTypeCatering;
      _serviceType = (pkg['service'] as String?) ?? 'catering';
      _currentStep = _InquiryStep.guestCount;
    });
  }

  void _proceedFromPackages() {
    final pkg = _locationPackages[_selectedPackageIndex.clamp(
      0,
      _locationPackages.length - 1,
    )];
    setState(() {
      _inquiryType = (pkg['type'] as String?) ?? kInquiryTypeCatering;
      _serviceType = (pkg['service'] as String?) ?? 'catering';
      _currentStep = _InquiryStep.guestCount;
    });
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
              final referenceChanged = _venuePhotoBase64 != base64String;
              _venuePhotoBase64 = base64String;
              _venueFieldError = null;
              if (referenceChanged) {
                _generatedImageUrl = null;
                _generatedImageHistory.clear();
                _aiThemeDesignPayload = null;
                _wantsCustomDesign = false;
                _genAiError = null;
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
    final venueRaw = _venuePhotoBase64?.trim();
    if (venueRaw == null || venueRaw.isEmpty) {
      setState(
        () => _genAiError =
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
          _aiThemeDesignPayload = {
            'eventDesignSource': 'customer_ai',
            'generatedImageUrl': imageUrl,
            ..._eventDesignConfig(),
          };
          _genAiError = null;
        });
      } else {
        setState(
          () => _genAiError = 'Failed to generate design. Please try again.',
        );
      }
    } catch (e) {
      final raw = e.toString();
      final msg = raw.contains('Exception:')
          ? raw.split('Exception:').last.trim()
          : raw;
      setState(() => _genAiError = msg);
    } finally {
      if (mounted) setState(() => _generatingDesign = false);
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

  // ===========================================================================
  // Responsive layout helpers
  // ===========================================================================

  Widget _responsiveTwoCol(BuildContext context, Widget left, Widget right) {
    if (isMobile(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [left, const SizedBox(height: 12), right],
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

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        title,
        style: GoogleFonts.getFont(
          _primaryFont,
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: _darkHeader,
        ),
      ),
    );
  }

  // ===========================================================================
  // BUILD - Progress Step Bar
  // ===========================================================================

  Widget _buildProgressBar() {
    final steps = _visibleSteps;
    final currentIdx = steps.indexOf(_currentStep);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: List.generate(steps.length * 2 - 1, (i) {
          if (i.isOdd) {
            final stepBefore = i ~/ 2;
            return Expanded(
              child: Container(
                height: 2,
                color: stepBefore < currentIdx
                    ? _accentYellow
                    : Colors.grey.shade300,
              ),
            );
          }
          final stepIdx = i ~/ 2;
          final step = steps[stepIdx];
          final isCompleted = stepIdx < currentIdx;
          final isCurrent = stepIdx == currentIdx;
          return GestureDetector(
            onTap: () {
              if (stepIdx <= currentIdx || isCompleted) _goToStep(step);
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCompleted
                        ? _accentYellow
                        : isCurrent
                            ? _darkHeader
                            : Colors.grey.shade300,
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(Icons.check, size: 18, color: _darkHeader)
                        : Text(
                            '${_stepNumber(step)}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isCurrent ? Colors.white : Colors.grey.shade600,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 6),
                if (!isMobile(context))
                  Text(
                    _stepLabel(step),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                      color: isCurrent ? _darkHeader : Colors.grey.shade600,
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  // ===========================================================================
  // BUILD - Step 1: Catering Packages page
  // ===========================================================================

  Widget _buildPackagesPage(BuildContext context) {
    final content = WebsiteContentStore.instance;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxH = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : MediaQuery.sizeOf(context).height;
        return Padding(
          padding: websitePagePadding(context, vertical: 12),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 1100,
                maxHeight: maxH,
              ),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Column(
                    children: [
                      Text(
                        content.inquiryPageTitle,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.getFont(
                          _primaryFont,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: _darkHeader,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
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
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Our Catering Packages',
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, gridConstraints) {
                            final cols =
                                gridConstraints.maxWidth >= 900
                                    ? 4
                                    : gridConstraints.maxWidth >= 560
                                    ? 2
                                    : 1;
                            return GridView.count(
                              crossAxisCount: cols,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              childAspectRatio: cols >= 4 ? 0.95 : 1.15,
                              children: List.generate(_locationPackages.length, (
                                index,
                              ) {
                            final pkg = _locationPackages[index];
                            final selected = _selectedPackageIndex == index;
                            return Material(
                              color:
                                  selected
                                      ? _accentYellow.withValues(alpha: 0.25)
                                      : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => _selectPackage(index),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color:
                                          selected
                                              ? _darkHeader
                                              : Colors.grey.shade300,
                                      width: selected ? 2 : 1,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        pkg['icon'] as IconData,
                                        size: 22,
                                        color: _darkHeader,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        pkg['title'] as String,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                          color: _darkHeader,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Expanded(
                                        child: Text(
                                          pkg['description'] as String,
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey.shade700,
                                            height: 1.3,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
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
      },
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
            AntdFieldShell(
              label: 'Event title',
              required: isEvent,
              errorText: _attemptedSubmit &&
                      isEvent &&
                      _eventTitle.text.trim().isEmpty
                  ? 'Required'
                  : null,
              child: AntdOutlineInput(
                controller: _eventTitle,
                hintText: 'Event title',
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: 12),
            AntdFieldShell(
              label: 'Customer',
              required: true,
              errorText: _attemptedSubmit && _customerName.text.trim().isEmpty
                  ? 'Required'
                  : null,
              child: AntdOutlineInput(
                controller: _customerName,
                hintText: 'Customer name',
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: 2),
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: _customerSameAsContact,
              onChanged: (v) {
                setState(() {
                  _customerSameAsContact = v ?? false;
                  if (_customerSameAsContact) {
                    _customerName.text = _contactPerson.text;
                  }
                });
              },
              title: const Text('Same as contact person'),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const SizedBox(height: 8),
            AntdFieldShell(
              label: 'Formality level',
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'casual', label: Text('Casual')),
                  ButtonSegment(value: 'semiformal', label: Text('Semiformal')),
                  ButtonSegment(value: 'formal', label: Text('Formal')),
                ],
                selected: {_formalityLevel},
                onSelectionChanged: (s) =>
                    setState(() => _formalityLevel = s.first),
              ),
            ),
            const SizedBox(height: 12),
            AntdFieldShell(
              label: 'Contact person',
              required: true,
              errorText:
                  _attemptedSubmit && _contactPerson.text.trim().isEmpty
                      ? 'Required'
                      : null,
              child: AntdOutlineInput(
                controller: _contactPerson,
                hintText: 'Contact person',
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: 8),
            AntdFieldShell(
              label: 'Contact number',
              required: true,
              errorText: _attemptedSubmit && _contactNumberInvalid
                  ? 'Required'
                  : null,
              child: AntdOutlineInput(
                controller: _contactNumber,
                hintText: '09XXXXXXXXX',
                keyboardType: TextInputType.phone,
                maxLength: 11,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(11),
                ],
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: 8),
            AntdFieldShell(
              label: 'Email address',
              required: true,
              errorText: _attemptedSubmit && _emailInvalid ? 'Required' : null,
              child: AntdOutlineInput(
                controller: _inquiryEmail,
                hintText: 'name@example.com',
                keyboardType: TextInputType.emailAddress,
                onChanged: (_) => setState(() {}),
              ),
            ),

            // Event schedule
            const SizedBox(height: 20),
            Text(
              'Event schedule (from / to)',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            ...List.generate(_eventWindows.length, (index) {
              final w = _eventWindows[index];
              final dateLabel = w.date == null
                  ? 'Date'
                  : '${w.date!.year}-${w.date!.month.toString().padLeft(2, '0')}-${w.date!.day.toString().padLeft(2, '0')}';
              String fmt(TimeOfDay? t) => t == null
                  ? '—'
                  : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _pickWindowDate(index),
                            child: Text(
                              dateLabel,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        if (_eventWindows.length > 1)
                          IconButton(
                            icon: const Icon(
                              Icons.remove_circle_outline,
                              color: Colors.red,
                            ),
                            onPressed: () {
                              setState(() {
                                if (_eventWindows.length > 1) {
                                  _eventWindows.removeAt(index);
                                }
                              });
                              _scheduleConflictRefresh();
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _pickWindowFrom(index),
                            child: Text('From ${fmt(w.from)}'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _pickWindowTo(index),
                            child: Text('to ${fmt(w.to)}'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
            if (_attemptedSubmit &&
                (_hasAnyPartialWindow ||
                    _hasNoCompleteWindow ||
                    _hasWindowTimeRangeError))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _hasAnyPartialWindow
                      ? 'Complete date/start/end time for each row, or remove incomplete rows.'
                      : _hasNoCompleteWindow
                          ? 'Set at least one event day with start and end time.'
                          : 'End time must be after start time for each event.',
                  style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                ),
              ),
            if (_publicScheduleConflictCount > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '$_publicScheduleConflictCount proposed window(s) overlap active schedules. '
                  'You may still submit; availability will be confirmed.',
                  style: TextStyle(
                    color: Colors.deepOrange.shade800,
                    fontSize: 12,
                  ),
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () =>
                    setState(() => _eventWindows.add(_InquiryEventWindow())),
                icon: const Icon(Icons.add),
                label: const Text('Add another day'),
              ),
            ),

            // Venue with map picker
            const SizedBox(height: 12),
            AntdFieldShell(
              label: 'Event venue',
              required: true,
              errorText: _attemptedSubmit && _eventCity.text.trim().isEmpty
                  ? 'Required'
                  : null,
              child: Row(
                children: [
                  Expanded(
                    child: AntdOutlineInput(
                      controller: _eventCity,
                      hintText: 'Venue address',
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Pick on map',
                    onPressed: () async {
                      final res = await showMapPicker(
                        context: context,
                        initialLatitude: _addressLat,
                        initialLongitude: _addressLng,
                        initialAddress: _eventCity.text.isNotEmpty
                            ? _eventCity.text
                            : null,
                      );
                      if (res == null || !mounted) return;
                      setState(() {
                        _eventCity.text = res.address;
                        _addressLat = res.latitude;
                        _addressLng = res.longitude;
                        _venueSuggestions.clear();
                      });
                    },
                    icon: const Icon(Icons.place_outlined),
                  ),
                ],
              ),
            ),
            if (_venueSuggestions.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 6),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: _venueSuggestions
                      .map(
                        (s) => ListTile(
                          dense: true,
                          title: Text(
                            s,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () async {
                            _eventCity.text = s;
                            _venueSuggestions.clear();
                            final pin = await NominatimService.instance.geocodeAddress(s);
                            if (pin != null && mounted) {
                              setState(() {
                                _addressLat = pin.lat;
                                _addressLng = pin.lng;
                              });
                            } else {
                              setState(() {});
                            }
                          },
                        ),
                      )
                      .toList(),
                ),
              ),

            // Inline map preview
            if (_addressLat != null && _addressLng != null) ...[
              const SizedBox(height: 12),
              RepaintBoundary(
                child: SizedBox(
                  height: 220,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: LatLng(_addressLat!, _addressLng!),
                        initialZoom: 16,
                        onTap: (_, point) async {
                          setState(() {
                            _addressLat = point.latitude;
                            _addressLng = point.longitude;
                          });
                          final resolved = await NominatimService.instance
                              .reverseGeocode(GeoPin(lat: point.latitude, lng: point.longitude));
                          if (mounted && resolved.isNotEmpty) {
                            setState(() => _eventCity.text = resolved);
                          }
                        },
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.curatering.web',
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: LatLng(_addressLat!, _addressLng!),
                              width: 40,
                              height: 40,
                              child: const Icon(
                                Icons.location_pin,
                                color: Colors.red,
                                size: 40,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Tap map to adjust pin location',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ),
            ] else if (_eventCity.text.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              RepaintBoundary(
                child: EventVenueMapPreview(address: _eventCity.text.trim()),
              ),
            ],

            // Setting
            const SizedBox(height: 16),
            Text(
              'Setting of event',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: RadioListTile<String>(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Indoor'),
                    value: 'Indoor',
                    groupValue: _eventSetting,
                    onChanged: (v) =>
                        setState(() => _eventSetting = v ?? 'Indoor'),
                  ),
                ),
                Expanded(
                  child: RadioListTile<String>(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Outdoor'),
                    value: 'Outdoor',
                    groupValue: _eventSetting,
                    onChanged: (v) =>
                        setState(() => _eventSetting = v ?? 'Outdoor'),
                  ),
                ),
                Expanded(
                  child: RadioListTile<String>(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Mixed'),
                    value: 'Mixed',
                    groupValue: _eventSetting,
                    onChanged: (v) =>
                        setState(() => _eventSetting = v ?? 'Mixed'),
                  ),
                ),
              ],
            ),

            // Guests
            const SizedBox(height: 8),
            TextField(
              controller: _guestCount,
              decoration: _requiredDecoration(
                label: 'Number of guests',
                invalid: _guestCountInvalid,
              ),
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _paxBuffer,
              decoration: InputDecoration(
                labelText: 'Pax Buffer (optional)',
                helperText:
                    'Additional pax for estimate only (₱${kPesosPerPax.toStringAsFixed(0)} per pax)',
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _note,
              decoration: const InputDecoration(
                labelText: 'Order notes (add other inclusions here)',
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
                AntdFieldShell(
                  label: 'Food tasting date',
                  required: true,
                  errorText: _attemptedSubmit &&
                          _foodTastingRequested &&
                          _foodTastingDate.text.trim().isEmpty
                      ? 'Required'
                      : null,
                  child: AntdPickerInput(
                    value: _foodTastingDate.text,
                    hintText: 'Pick date',
                    icon: Icons.calendar_today_outlined,
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
                ),
                AntdFieldShell(
                  label: 'Food tasting time',
                  required: true,
                  errorText: _attemptedSubmit &&
                          _foodTastingRequested &&
                          _foodTastingTime.text.trim().isEmpty
                      ? 'Required'
                      : null,
                  child: AntdPickerInput(
                    value: _foodTastingTime.text,
                    hintText: 'Pick time',
                    icon: Icons.schedule_outlined,
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
        AntdFieldShell(
          label: 'Event type',
          required: true,
          child: DropdownButtonFormField<String>(
            value: kEventTypeChoices.contains(_eventTypeChoice)
                ? _eventTypeChoice
                : 'Other',
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            ),
            items: kEventTypeChoices
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (v) => setState(() => _eventTypeChoice = v ?? 'Other'),
          ),
        ),
        if (_eventTypeChoice == 'Other') ...[
          const SizedBox(height: 8),
          AntdFieldShell(
            label: 'Describe event type',
            required: true,
            errorText: _attemptedSubmit && _eventTypeOtherInvalid
                ? 'Required'
                : null,
            child: AntdOutlineInput(
              controller: _eventTypeOther,
              hintText: 'Describe event type',
              onChanged: (_) => setState(() {}),
            ),
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
                dropdownMode: true,
                onChanged: (s) {
                  setState(() {
                    _allergensSerialized = s;
                    _pruneMenuSelectionsForCurrentAllergens();
                  });
                },
              ),
            ),

            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              value:
                  !_menuChoicePicked
                      ? null
                      : (_curateOwn ? 'curate' : 'suggest'),
              decoration: const InputDecoration(
                labelText: 'Menu selection',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'curate',
                  child: Text('Yes, curate my own menu'),
                ),
                DropdownMenuItem(
                  value: 'suggest',
                  child: Text('No, suggest a menu'),
                ),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  _menuChoicePicked = true;
                  _curateOwn = v == 'curate';
                  if (_curateOwn) {
                    _menuSuggestionNote = '';
                    _selectedSetMenu = 'All Dishes';
                    _selectedDishIds.clear();
                    _menuSelections.clear();
                  } else {
                    _selectedDishIds.clear();
                    _menuSelections.clear();
                    _menuSuggestionNote = 'No, suggest me a menu instead.';
                  }
                });
              },
            ),
            if (_attemptedSubmit && !_menuChoicePicked)
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 8),
                child: Text(
                  'Required',
                  style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                ),
              ),
            if (_menuChoicePicked && _curateOwn) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: _menuPrefTabIndex,
                decoration: const InputDecoration(
                  labelText: 'How would you like to build your menu?',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 0,
                    child: Text('I want to make my own menu'),
                  ),
                  DropdownMenuItem(
                    value: 1,
                    child: Text('Choose from Set Menu'),
                  ),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  _switchMenuPrefTab(v);
                },
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
                        minCustomDishes: _minSelectedDishesRequired,
                        maxCustomDishes: _maxSelectedDishesRequired,
                        visibleRowCount: _visibleDishRows,
                        twoColumnSetMenu: true,
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
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "What's included in event styling",
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 6),
                  Text('• Basic table styling and centerpiece arrangement'),
                  Text('• Coordinated dinnerware / place setting layout'),
                  Text('• Soft ambient décor accents matched to your theme'),
                  Text('• On-site styling setup for the booked event window'),
                  SizedBox(height: 8),
                  Text(
                    'Other inclusions (extra décor, specialty rentals, etc.) should be added in Order notes.',
                    style: TextStyle(fontSize: 12, height: 1.35),
                  ),
                ],
              ),
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
                  labelText: 'Theme / styling notes (other inclusions → Order notes)',
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
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? const Color(0xFFFFF8E1) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? const Color(0xFFE8B923) : Colors.grey.shade400,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // BUILD - AI design form
  // ===========================================================================

  Widget _buildAiDesignForm(BuildContext context) {
    final inputsEnabled = !_generatingDesign;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AbsorbPointer(
          absorbing: !inputsEnabled,
          child: Opacity(
            opacity: inputsEnabled ? 1 : 0.55,
            child: Column(
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
                inputsEnabled
                    ? (val) => setState(() => _selectedStyle = val)
                    : null,
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
          inputsEnabled
              ? (val) => setState(() => _selectedMood = val)
              : null,
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
              _buildMultiSelect(
                _colorPalettes,
                _selectedColors,
                enabled: inputsEnabled,
              ),
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
              _buildMultiSelect(
                _decorOptions,
                _selectedDecor,
                enabled: inputsEnabled,
              ),
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
          onPressed: inputsEnabled ? _pickVenuePhoto : null,
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
              ],
            ),
          ),
        ),
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
        if (_generatingDesign) ...[
          const SizedBox(height: 8),
          Text(
            'Please wait — inputs stay locked until the design finishes.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
        ],
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
                  onTap: inputsEnabled
                      ? () => setState(() {
                            _generatedImageUrl = url;
                            _aiThemeDesignPayload = {
                              'eventDesignSource': 'customer_ai',
                              'generatedImageUrl': url,
                              ..._eventDesignConfig(),
                            };
                          })
                      : null,
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
    Function(String?)? onChanged,
  ) {
    return DropdownButtonFormField<String>(
      value: value != null && items.contains(value) ? value : null,
      items: items
          .map((item) => DropdownMenuItem(value: item, child: Text(item)))
          .toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        filled: onChanged == null,
        fillColor: onChanged == null ? Colors.grey.shade100 : null,
      ),
      hint: const Text('Select an option'),
    );
  }

  Widget _buildMultiSelect(
    List<String> items,
    List<String> selectedList, {
    bool enabled = true,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((item) {
        final isSelected = selectedList.contains(item);
        return FilterChip(
          label: Text(item),
          selected: isSelected,
          onSelected: enabled
              ? (val) {
                  setState(() {
                    if (val) {
                      selectedList.add(item);
                    } else {
                      selectedList.remove(item);
                    }
                  });
                }
              : null,
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

  // ===========================================================================
  // BUILD - Completed page
  // ===========================================================================

  Widget _buildCompletedPage() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
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
                Icon(
                  Icons.check_circle_outline,
                  size: 56,
                  color: Colors.green.shade600,
                ),
                const SizedBox(height: 16),
                Text(
                  'Inquiry submitted',
                  style: GoogleFonts.getFont(
                    _primaryFont,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: _darkHeader,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _submittedCateringId == null
                      ? 'Our team will review your inquiry and contact you soon.'
                      : 'Reference: $_submittedCateringId',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _resetInquiryForm,
                  child: const Text('Submit another inquiry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // BUILD (main)
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CustomerWebsiteTopBar(
            showCartAndCustomerAuth: !widget.contentEditable,
          ),
          _buildProgressBar(),
          Expanded(
            child: _formSubmitted || _currentStep == _InquiryStep.completed
                ? _buildCompletedPage()
                : _currentStep == _InquiryStep.packages
                    ? _buildPackagesPage(context)
                    : _currentStep == _InquiryStep.guestCount
                        ? _buildGuestCountPage(context)
                        : _buildThreeColumnLayout(context),
          ),
        ],
      ),
    );
  }
}
