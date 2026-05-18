import 'dart:convert';
import 'dart:typed_data';
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
import '../utils/geo_utils.dart';
import '../utils/inquiry_pricing.dart';
import '../widgets/async_dialogs.dart';
import '../widgets/antd_dialog.dart';
import '../utils/image_download.dart';

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
  final _dateController = TextEditingController();
  final _timeController = TextEditingController();

  // State
  String _eventType = 'Birthday';
  String _formality = 'casual';
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
  final _eventTypeOtherController = TextEditingController();
  final _styleOtherController = TextEditingController();
  final _moodOtherController = TextEditingController();
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
  ];

  @override
  void initState() {
    super.initState();
    if (!_inquiryEventTypes.contains(_eventType)) {
      _eventType = _inquiryEventTypes.first;
    }
    MenuStore.instance.loadDishes();
    SetMenuStore.instance.loadSetMenus();
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
    _dateController.dispose();
    _timeController.dispose();
    _designPromptController.dispose();
    _macrinaPalette.dispose();
    _macrinaTheme.dispose();
    _eventTypeOtherController.dispose();
    _styleOtherController.dispose();
    _moodOtherController.dispose();
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

  double _estimateMenuCost() {
    final guestCount = int.tryParse(_guests.text.trim()) ?? 0;
    return estimateInquiryCateringTotal(guestCount);
  }

  Future<void> _showOrderSummaryAndConfirm() async {
    final guestCount = int.tryParse(_guests.text.trim()) ?? 0;
    final estimated = _estimateMenuCost();

    final confirmed = await showAntdModal<bool>(
      context: context,
      title: 'Confirm your inquiry',
      maxWidth: 520,
      barrierDismissible: false,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Event: ${_eventTitle.text.trim()}'),
          Text('Customer: ${_customer.text.trim()}'),
          Text('Guests: $guestCount'),
          Text('Service: $_serviceType'),
          const SizedBox(height: 12),
          Text(
            'Initial catering estimate (₱${kCateringInquiryPricePerGuest.toStringAsFixed(0)} × guests — final quote may differ):',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text('Estimated subtotal: ₱${estimated.toStringAsFixed(2)}'),
          if (guestCount > 0)
            Text(
              '₱${kCateringInquiryPricePerGuest.toStringAsFixed(0)} × $guestCount guests',
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
      await showBlockingLoadingDialog(
        context,
        message: 'Submitting inquiry…',
      );

      final guestCount = int.tryParse(_guests.text.trim()) ?? 0;
      final scheduleSlots = <Map<String, dynamic>>[
        {
          'date': _dateController.text.trim(),
          'startTime': _timeController.text.trim(),
          'endTime': '',
        },
      ];

      final payload = <String, dynamic>{
        'orderType': _serviceType == 'catering' ? 'catering' : 'catering_event',
        'eventTitle':
            _serviceType == 'catering'
                ? _customer.text.trim()
                : _eventTitle.text.trim(),
        'eventType': _eventType,
        'formalityLevel': _formality,
        'customerName': _customer.text.trim(),
        'contactPerson': _contactPerson.text.trim(),
        'contactNumber': _phone.text.trim(),
        'emailAddress': _email.text.trim(),
        'address': _address.text.trim(),
        if (_addressLat != null) 'addressLat': _addressLat,
        if (_addressLng != null) 'addressLng': _addressLng,
        'guestCount': guestCount,
        'scheduleSlots': scheduleSlots,
        'menu': _buildMenuForApi(),
        'allergens': _allergensSerialized.trim(),
        'source': 'web',
      };
      final themeDesign = _buildThemeDesignForApi();
      if (themeDesign != null) {
        payload['themeDesign'] = themeDesign;
      }

      await PublicEventsApi.instance.submitOnlineInquiry(payload: payload);

      if (mounted) {
        showAntdMessage(
          context,
          'Inquiry submitted successfully! We\'ll contact you soon.',
        );
        _clearForm();
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
        hideBlockingLoadingDialog(context);
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

    if (_serviceType != 'catering' && _eventTitle.text.trim().isEmpty) {
      err('eventTitle', 'Please enter an event title');
    }
    if (_customer.text.trim().isEmpty) err('customer', 'Please enter your name');
    if (_contactPerson.text.trim().isEmpty) err('contactPerson', 'Please enter a contact person');
    if (_phone.text.trim().isEmpty) err('phone', 'Please enter a phone number');
    if (_email.text.trim().isEmpty) {
      err('email', 'Please enter an email address');
    } else if (!_email.text.contains('@')) {
      err('email', 'Enter a valid email address');
    }
    final guestCount = int.tryParse(_guests.text.trim()) ?? 0;
    if (guestCount < 1) err('guests', 'Enter a valid guest count (at least 1)');
    if (_address.text.trim().isEmpty) {
      err('address', 'Please enter the event address');
    } else if (!isAllowedCateringAddress(_address.text)) {
      err('address', cateringCoverageError);
    }
    if (_dateController.text.trim().isEmpty) err('date', 'Please select an event date');
    if (_timeController.text.trim().isEmpty) {
      err('time', 'Please select an event time');
    }
    if (_menuSelections.isEmpty) {
      err('menu', 'Choose your menu using the options below');
    } else {
      final block = _menuSelections.first;
      final kind = block['kind'] as String? ?? 'custom';
      if (kind == 'custom') {
        final n = (block['dishIds'] as List<dynamic>?)?.length ?? 0;
        if (n < 4 || n > 8) {
          err('menu', 'Select between 4 and 8 dishes for your custom menu');
        }
      }
    }
    if (_serviceType == 'catering') {
      final guests = int.tryParse(_guests.text.trim()) ?? 0;
      if (guests > 0 && guests < 50 && _includeCateringService == null) {
        err('cateringService', 'Please choose whether to include catering service');
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
    if (_serviceType != 'catering+event') return true;
    if (_eventDesignMode == 'macrina') {
      return _validateMacrinaStep();
    }
    return true;
  }

  void _goNextFromMainForm() {
    if (!_validatePhase0MainForm()) return;
    if (_serviceType == 'catering+event') {
      setState(() => _formPhase = 1);
    } else {
      _showOrderSummaryAndConfirm();
    }
  }

  void _goNextFromDesignChoice() {
    if (_eventDesignMode == null) {
      setState(() => _fieldErrors['eventDesignMode'] = 'Please choose who will design your event');
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
    if (_serviceType == 'catering') return null;
    if (_eventDesignMode == 'macrina') {
      return {
        'eventDesignSource': 'macrina',
        'macrinaColorPalette': _macrinaPalette.text.trim(),
        'macrinaTheme': _macrinaTheme.text.trim(),
        'serviceType': _serviceType,
      };
    }
    if (_eventDesignMode == 'customer') {
      final style = _selectedStyle == 'Other'
          ? _styleOtherController.text.trim()
          : (_selectedStyle ?? '');
      final mood = _selectedMood == 'Other'
          ? _moodOtherController.text.trim()
          : (_selectedMood ?? '');
      final eventType = _selectedEventType == 'Other'
          ? _eventTypeOtherController.text.trim()
          : (_selectedEventType ?? '');
      return {
        'eventDesignSource': 'customer_ai',
        'wantsCustomDesign': _wantsCustomDesign,
        if (_generatedImageUrl != null && _generatedImageUrl!.trim().isNotEmpty)
          'generatedImageUrl': _generatedImageUrl!.trim(),
        if (eventType.isNotEmpty) 'eventDesignEventType': eventType,
        if (style.isNotEmpty) 'style': style,
        if (mood.isNotEmpty) 'mood': mood,
        if (_selectedColors.isNotEmpty) 'colorPalette': List<String>.from(_selectedColors),
        if (_selectedDecor.isNotEmpty) 'decorElements': List<String>.from(_selectedDecor),
        if (_designPromptController.text.trim().isNotEmpty)
          'customInstructions': _designPromptController.text.trim(),
        'serviceType': _serviceType,
      };
    }
    return null;
  }

  /// API `/api/online-inquiries` expects `menu`: list of `{ dishName }`.
  List<Map<String, dynamic>> _buildMenuForApi() {
    final out = <Map<String, dynamic>>[];
    for (final block in _menuSelections) {
      final names = (block['dishNames'] as List<dynamic>?)
              ?.map((e) => e.toString().trim())
              .where((n) => n.isNotEmpty)
              .toList() ??
          const [];
      for (final n in names) {
        out.add({'dishName': n});
      }
    }
    if (out.isEmpty) {
      return [
        {'dishName': 'Customer will confirm menu details with coordinator'},
      ];
    }
    return out;
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
    _eventType = 'Birthday';
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
    _designPromptController.clear();
    _venuePhotoBase64 = null;
    });
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
      _fieldErrors.remove('menu');
    });
  }

  List<MenuDish> _inquiryCateringDishes() {
    return MenuStore.instance.activeDishes
        .where(
          (d) =>
              d.category.toLowerCase().trim() == 'catering' &&
              !d.archived &&
              d.available,
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
    'Birthday',
    'Wedding',
    'Corporate Event',
    'Anniversary',
    'Graduation',
    'Other',
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
        children: [
          left,
          const SizedBox(height: 16),
          right,
        ],
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

  String _mapInquiryEventTypeToDesign(String t) {
    if (t == 'Corporate Event') return 'Corporate';
    if (t == 'Anniversary' || t == 'Graduation') return 'Other';
    if (_eventTypes.contains(t)) return t;
    return 'Other';
  }

  List<Widget> _buildPhase0Content(BuildContext context) {
    void onFieldChanged(String key) {
      if (_fieldErrors.containsKey(key)) {
        setState(() => _fieldErrors.remove(key));
      }
    }

    final eventTypeValue =
        _inquiryEventTypes.contains(_eventType) ? _eventType : _inquiryEventTypes.first;

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
              title: const Text('Catering Only', style: TextStyle(fontSize: 14)),
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
              title: const Text(
                'Catering + Event Design',
                style: TextStyle(fontSize: 14),
              ),
              value: 'catering+event',
              groupValue: _serviceType,
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _serviceType = value;
                    _selectedEventType = _mapInquiryEventTypeToDesign(_eventType);
                  });
                }
              },
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            ),
          ),
        ],
      ),
      const SizedBox(height: 20),
      _responsiveTwoCol(
        context,
        AntdFieldShell(
          label: 'Event Title',
          required: _serviceType != 'catering',
          errorText: _fieldErrors['eventTitle'],
          child: AntdOutlineInput(
            controller: _eventTitle,
            hintText:
                _serviceType == 'catering'
                    ? 'Not required for catering only'
                    : 'Enter event title',
            readOnly: _serviceType == 'catering',
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
                if (_serviceType == 'catering+event') {
                  _selectedEventType = _mapInquiryEventTypeToDesign(value);
                }
              });
            },
          ),
        ),
      ),
      const SizedBox(height: 16),
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
      const SizedBox(height: 32),
      _inquirySectionTitle('Contact Information'),
      const SizedBox(height: 16),
      _responsiveTwoCol(
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
      ),
      const SizedBox(height: 16),
      _responsiveTwoCol(
        context,
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
      ),
      const SizedBox(height: 16),
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
      AntdFieldShell(
        label: 'Number of Guests',
        required: true,
        errorText: _fieldErrors['guests'],
        child: AntdOutlineInput(
          controller: _guests,
          hintText: 'Guest count',
          keyboardType: TextInputType.number,
          onChanged: (_) => setState(() {
            _fieldErrors.remove('guests');
            _fieldErrors.remove('cateringService');
          }),
        ),
      ),
      const SizedBox(height: 12),
      _responsiveTwoCol(
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
                initialDate:
                    DateTime.tryParse(_dateController.text) ?? now,
                firstDate: now,
                lastDate: now.add(const Duration(days: 365 * 2)),
              );
              if (pickedDate != null) {
                setState(() {
                  _dateController.text = DateFormat('yyyy-MM-dd').format(
                    pickedDate,
                  );
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
      ),
      if (_serviceType == 'catering') ...[
        Builder(
          builder: (context) {
            final guests = int.tryParse(_guests.text.trim()) ?? 0;
            if (guests <= 0 || guests >= 50) return const SizedBox.shrink();
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
                          'For catering orders with less than 50 guests, additional charges may apply.',
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
                _inquirySectionTitle('Include catering service'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<bool>(
                        title: const Text('Yes', style: TextStyle(fontSize: 14)),
                        value: true,
                        groupValue: _includeCateringService,
                        onChanged: (v) {
                          setState(() {
                            _includeCateringService = v;
                            _fieldErrors.remove('cateringService');
                          });
                        },
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<bool>(
                        title: const Text('No', style: TextStyle(fontSize: 14)),
                        value: false,
                        groupValue: _includeCateringService,
                        onChanged: (v) {
                          setState(() {
                            _includeCateringService = v;
                            _fieldErrors.remove('cateringService');
                          });
                        },
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
                if (_includeCateringService == true)
                  const Padding(
                    padding: EdgeInsets.only(top: 4, bottom: 8),
                    child: Text(
                      'May incur additional charges.',
                      style: TextStyle(
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
                    style: const TextStyle(color: Color(0xFFFF4D4F), fontSize: 12),
                  ),
                const SizedBox(height: 16),
              ],
            );
          },
        ),
      ],
      const SizedBox(height: 32),
      _inquirySectionTitle('Menu preferences'),
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
              fontWeight: _menuPrefTabIndex == 0 ? FontWeight.w700 : FontWeight.normal,
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
              fontWeight: _menuPrefTabIndex == 1 ? FontWeight.w700 : FontWeight.normal,
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
              MenuStore.instance.isLoading || SetMenuStore.instance.isLoading;
          if (loading &&
              _inquiryCateringDishes().isEmpty &&
              SetMenuStore.instance.activeSetMenus.isEmpty) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return InquiryMenuPicker(
            key: ValueKey<int>(_menuPrefTabIndex),
            embedded: true,
            tabIndex: _menuPrefTabIndex,
            cateringDishes: _inquiryCateringDishes(),
            setMenus: SetMenuStore.instance.activeSetMenus,
            initialSelections: List<Map<String, dynamic>>.from(_menuSelections),
            mode: InquiryMenuPickerMode.inquiryExclusive,
            minCustomDishes: 4,
            maxCustomDishes: 8,
            externalError: _fieldErrors['menu'],
            onSelectionChanged: _onInlineMenuSelectionChanged,
          );
        },
      ),
      const SizedBox(height: 16),
      AntdFieldShell(
        label: 'Allergens',
        child: AllergenSelectorField(
          initialSerialized: _allergensSerialized,
          onChanged: (s) => _allergensSerialized = s,
        ),
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
          color: selected
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
                  color: selected
                      ? AntdTokens.brandOnPrimary
                      : Colors.grey.shade700,
                ),
                const Spacer(),
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: selected
                      ? AntdTokens.brandPrimary
                      : Colors.grey.shade500,
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
          subtitle: 'Share your palette and theme; our team will propose a look.',
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
              subtitle: 'Use AI to explore styles, then submit with your inquiry.',
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
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: child,
        ),
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
            onTap: () => _openZoomableImage(
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
                          color: selected
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
        ]
        else
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
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
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
            onTap: () => _openZoomableImage(
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
              _buildChips(
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
        _buildChips(
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
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSectionTitle('Decor Elements'),
              _buildMultiSelect(_decorOptions, _selectedDecor),
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
            onPressed: () => setState(() => _venuePhotoBase64 = null),
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
            onPressed: (_submitting || _generatingDesign) ? null : _generateDesignPrompt,
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

    final layout = wide
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
              if (_generatedImageUrl != null || _venuePhotoBase64 != null) ...[
                _buildAiDesignPreviewPanel(minHeight: 220),
                const SizedBox(height: 20),
              ],
              _buildAiDesignForm(context),
              if (_generatedImageUrl == null && _venuePhotoBase64 == null) ...[
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
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                      : const Text(
                        'SUBMIT INQUIRY',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
            ),
          ),
        ],
      ),
    ];
  }

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
          Expanded(
            child: CenteredViewportScroll(
              padding: websitePagePadding(context),
              child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Text(
              'INQUIRE',
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
                child: const Text(
                  'Inquire for Catering or Event',
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
                    if (_formPhase == 0) ..._buildPhase0Content(context),
                    if (_formPhase == 1 && _serviceType == 'catering+event') ..._buildPhase1Content(),
                    if (_formPhase == 2 && _serviceType == 'catering+event') ..._buildPhase2Content(context),
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

  Widget _buildChips(
    List<String> items,
    String? selected,
    Function(String) onSelect,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children:
          items.map((item) {
            final isSelected = selected == item;
            return ChoiceChip(
              label: Text(item),
              selected: isSelected,
              onSelected: (_) => onSelect(item),
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
    final parts = <String>[];
    final eventType = _resolvedCategory(
      _selectedEventType,
      _eventTypeOtherController,
    );
    final style = _resolvedCategory(_selectedStyle, _styleOtherController);
    final mood = _resolvedCategory(_selectedMood, _moodOtherController);
    if (eventType != null && eventType.isNotEmpty) {
      parts.add('Event type: $eventType');
    }
    if (style != null && style.isNotEmpty) {
      parts.add('Style: $style');
    }
    if (mood != null && mood.isNotEmpty) {
      parts.add('Mood: $mood');
    }
    if (_selectedColors.isNotEmpty) {
      parts.add('Colors: ${_selectedColors.join(', ')}');
    }
    if (_selectedDecor.isNotEmpty) {
      parts.add('Decor: ${_selectedDecor.join(', ')}');
    }
    final notes = _designPromptController.text.trim();
    if (notes.isNotEmpty) parts.add(notes);
    if (parts.isEmpty) {
      return 'Decorate the existing venue in the reference photo, preserve room layout, elegant lighting';
    }
    return '${parts.join('. ')}. Decorate the existing venue in the reference photo, '
        'preserve room layout and architecture, high quality realistic lighting';
  }

  Future<void> _downloadVenuePhoto() async {
    final b64 = _venuePhotoBase64;
    if (b64 == null) return;
    try {
      await downloadImageBytes(base64Decode(b64), 'venue-reference.png');
    } catch (e) {
      if (mounted) {
        showAntdMessage(context, 'Download failed: $e', type: AntdMessageType.error);
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
        showAntdMessage(context, 'Download failed: $e', type: AntdMessageType.error);
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
      final prompt = _composeEventDesignPrompt();
      final venueB64 = _normalizeVenueB64ForRunpod(venueRaw);
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
        strength: 0.52,
        numInferenceSteps: 18,
        designMeta: {
          if (_selectedEventType != null && _selectedEventType!.isNotEmpty)
            'event_type': _selectedEventType,
          if (_selectedStyle != null && _selectedStyle!.isNotEmpty)
            'style': _selectedStyle,
          if (_selectedMood != null && _selectedMood!.isNotEmpty)
            'mood': _selectedMood,
          if (_selectedColors.isNotEmpty) 'colors': _selectedColors.join(', '),
          if (_selectedDecor.isNotEmpty) 'decor': _selectedDecor.join(', '),
          'formality': _formality,
        },
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
      final msg = raw.contains('Exception:')
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
