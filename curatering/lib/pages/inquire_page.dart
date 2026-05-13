import 'dart:convert';

import 'package:intl/intl.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';

import '../services/menu_store.dart';
import '../services/public_events_api.dart';
import '../services/runpod_service.dart';
import '../services/set_menu_store.dart';
import '../widgets/centered_viewport_scroll.dart';
import '../widgets/customer_website_topbar.dart';
import '../widgets/inquiry_menu_selection_dialog.dart';
import '../widgets/map_picker.dart';

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
  String? _generatedImageUrl;

  // Service Type Selection
  String _serviceType = 'catering'; // 'catering' or 'catering+event'

  // Menu Selection State
  String _menuChoice = 'suggest'; // 'yes' or 'suggest'
  final List<String> _selectedDishIds = [];
  final List<Map<String, dynamic>> _menuSelections = [];

  // Event Design - Prompt Based GenAI
  bool _wantsCustomDesign = false;
  String? _selectedEventType;
  String? _selectedStyle;
  String? _selectedMood;
  final List<String> _selectedColors = [];
  final List<String> _selectedDecor = [];
  final _designPromptController = TextEditingController();
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
  ];
  final _moods = ["Romantic", "Bright", "Dramatic", "Cozy", "Luxurious", "Fun"];
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
    MenuStore.instance.loadDishes();
    SetMenuStore.instance.loadSetMenus();
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
    super.dispose();
  }

  Future<void> _submitInquiry() async {
    if (!_validateForm()) return;

    setState(() => _submitting = true);

    try {
      final payload = {
        'eventTitle': _eventTitle.text.trim(),
        'eventType': _eventType,
        'formalityLevel': _formality,
        'customerName': _customer.text.trim(),
        'contactPerson': _contactPerson.text.trim(),
        'contactNumber': _phone.text.trim(),
        'emailAddress': _email.text.trim(),
        'address': _address.text.trim(),
        if (_addressLat != null) 'addressLat': _addressLat,
        if (_addressLng != null) 'addressLng': _addressLng,
        'guestCount': int.tryParse(_guests.text) ?? 0,
        'eventDate': _dateController.text.trim(),
        'eventTime': _timeController.text.trim(),
        'serviceType': _serviceType,
        'menuChoice': _menuChoice,
        'selectedDishIds': _selectedDishIds,
        if (_menuSelections.isNotEmpty) 'menuSelections': _menuSelections,
        'wantsCustomDesign': _wantsCustomDesign,
        'eventDesign':
            _serviceType == 'catering+event'
                ? {
                  'eventType': _selectedEventType,
                  'style': _selectedStyle,
                  'mood': _selectedMood,
                  'colorPalette': _selectedColors,
                  'decorElements': _selectedDecor,
                  'customInstructions': _designPromptController.text,
                  'venuePhoto': _venuePhotoBase64,
                }
                : null,
        'createdAt': DateTime.now().toIso8601String(),
      };

      await PublicEventsApi.instance.submitOnlineInquiry(payload: payload);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Inquiry submitted successfully! We\'ll contact you soon.',
            ),
            backgroundColor: Colors.green,
          ),
        );
        _clearForm();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit inquiry: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  bool _validateForm() {
    if (_eventTitle.text.trim().isEmpty) {
      _showError('Please enter an event title');
      return false;
    }
    if (_customer.text.trim().isEmpty) {
      _showError('Please enter your name');
      return false;
    }
    if (_contactPerson.text.trim().isEmpty) {
      _showError('Please enter a contact person');
      return false;
    }
    if (_phone.text.trim().isEmpty) {
      _showError('Please enter a phone number');
      return false;
    }
    if (_email.text.trim().isEmpty) {
      _showError('Please enter an email address');
      return false;
    }
    if (_guests.text.trim().isEmpty) {
      _showError('Please enter the number of guests');
      return false;
    }
    return true;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
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
    _menuChoice = 'suggest';
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

  Future<void> _openMenuPicker() async {
    await MenuStore.instance.loadDishes();
    await SetMenuStore.instance.loadSetMenus();
    if (!mounted) return;
    final catering =
        MenuStore.instance.activeDishes
            .where(
              (d) =>
                  d.category.toLowerCase().trim() == 'catering' &&
                  !d.archived &&
                  d.available,
            )
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    final sets = SetMenuStore.instance.activeSetMenus;
    final result = await showInquiryMenuSelectionDialog(
      context,
      cateringDishes: catering,
      setMenus: sets,
      initialSelections: List<Map<String, dynamic>>.from(_menuSelections),
    );
    if (result != null && mounted) {
      _applyMenuSelections(result);
    }
  }

  Widget _buildMenuSelectionSummary(Map<String, dynamic> block) {
    final kind = block['kind'] as String? ?? 'custom';
    final names =
        (block['dishNames'] as List<dynamic>?)?.cast<String>().join(', ') ??
        '';
    if (kind == 'set') {
      final title = block['setMenuName'] as String? ?? 'Set menu';
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(
              names,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('À la carte', style: TextStyle(fontWeight: FontWeight.w700)),
          Text(
            names,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
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
                    // Event Information Section
                    Text(
                      'Event Information',
                      style: GoogleFonts.getFont(
                        _primaryFont,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1E1E1E),
                      ),
                    ),
                    const SizedBox(height: 24),

                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _eventTitle,
                            decoration: const InputDecoration(
                              labelText: 'Event Title',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _eventType,
                            decoration: const InputDecoration(
                              labelText: 'Event Type',
                              border: OutlineInputBorder(),
                            ),
                            items:
                                [
                                      'Birthday',
                                      'Wedding',
                                      'Corporate Event',
                                      'Anniversary',
                                      'Graduation',
                                      'Other',
                                    ]
                                    .map(
                                      (type) => DropdownMenuItem(
                                        value: type,
                                        child: Text(type),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _eventType = value;
                                  // Auto-populate event type in event design section
                                  if (_serviceType == 'catering+event') {
                                    _selectedEventType = value;
                                  }
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    DropdownButtonFormField<String>(
                      value: _formality,
                      decoration: const InputDecoration(
                        labelText: 'Formality Level',
                        border: OutlineInputBorder(),
                      ),
                      items:
                          ['casual', 'semi-formal', 'formal']
                              .map(
                                (level) => DropdownMenuItem(
                                  value: level,
                                  child: Text(level.toUpperCase()),
                                ),
                              )
                              .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _formality = value);
                        }
                      },
                    ),
                    const SizedBox(height: 24),

                    // Contact Information Section
                    Text(
                      'Contact Information',
                      style: GoogleFonts.getFont(
                        _primaryFont,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1E1E1E),
                      ),
                    ),
                    const SizedBox(height: 24),

                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _customer,
                            decoration: const InputDecoration(
                              labelText: 'Customer Name',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: _contactPerson,
                            decoration: const InputDecoration(
                              labelText: 'Contact Person',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _phone,
                            decoration: const InputDecoration(
                              labelText: 'Phone Number',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.phone,
                            maxLength: 13,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(13),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: _email,
                            decoration: const InputDecoration(
                              labelText: 'Email Address',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.emailAddress,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: _address,
                      decoration: const InputDecoration(
                        labelText: 'Event Address',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
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
                            initialAddress:
                                _address.text.isNotEmpty
                                    ? _address.text
                                    : null,
                          );
                          if (res == null || !mounted) return;
                          setState(() {
                            _address.text = res.address;
                            _addressLat = res.latitude;
                            _addressLng = res.longitude;
                          });
                        },
                        icon: const Icon(Icons.map_outlined, size: 20),
                        label: const Text('Pick on map'),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Event Details Section
                    Text(
                      'Event Details',
                      style: GoogleFonts.getFont(
                        _primaryFont,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1E1E1E),
                      ),
                    ),
                    const SizedBox(height: 24),

                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _guests,
                            decoration: const InputDecoration(
                              labelText: 'Number of Guests',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final now = DateTime.now();
                              final pickedDate = await showDatePicker(
                                context: context,
                                initialDate:
                                    DateTime.tryParse(_dateController.text) ??
                                    now,
                                firstDate: now,
                                lastDate: now.add(
                                  const Duration(days: 365 * 2),
                                ),
                              );
                              if (pickedDate != null) {
                                _dateController.text = DateFormat(
                                  'yyyy-MM-dd',
                                ).format(pickedDate);
                              }
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Event Date',
                                border: OutlineInputBorder(),
                                hintText: 'YYYY-MM-DD',
                                suffixIcon: Icon(Icons.calendar_today),
                              ),
                              child: IgnorePointer(
                                child: TextField(
                                  controller: _dateController,
                                  enabled: false,
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    InkWell(
                      onTap: () async {
                        final pickedTime = await showTimePicker(
                          context: context,
                          initialTime:
                              _timeController.text.isNotEmpty
                                  ? TimeOfDay.fromDateTime(
                                    DateFormat(
                                      'h:mm a',
                                    ).parse(_timeController.text),
                                  )
                                  : const TimeOfDay(hour: 10, minute: 0),
                        );
                        if (pickedTime != null) {
                          _timeController.text = pickedTime
                              .format(context)
                              .replaceAll(' ', '');
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Event Time',
                          border: OutlineInputBorder(),
                          hintText: 'e.g., 6:00 PM',
                          suffixIcon: Icon(Icons.access_time),
                        ),
                        child: IgnorePointer(
                          child: TextField(
                            controller: _timeController,
                            enabled: false,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Service Type Section
                    Text(
                      'Service Type',
                      style: GoogleFonts.getFont(
                        _primaryFont,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1E1E1E),
                      ),
                    ),
                    const SizedBox(height: 16),

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
                                setState(() => _serviceType = value);
                              }
                            },
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 4,
                            ),
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
                                setState(() => _serviceType = value);
                              }
                            },
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 4,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    Text(
                      'Menu preferences',
                      style: GoogleFonts.getFont(
                        _primaryFont,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1E1E1E),
                      ),
                    ),
                    const SizedBox(height: 8),
                    RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Suggest a menu for us'),
                      value: 'suggest',
                      groupValue: _menuChoice,
                      onChanged: (v) {
                        if (v != null) setState(() => _menuChoice = v);
                      },
                    ),
                    RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('I want to pick dishes from your menus'),
                      value: 'yes',
                      groupValue: _menuChoice,
                      onChanged: (v) {
                        if (v != null) setState(() => _menuChoice = v);
                      },
                    ),
                    if (_menuChoice == 'yes') ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _openMenuPicker,
                        icon: const Icon(Icons.restaurant_menu),
                        label: const Text('Choose catering & set menu dishes'),
                      ),
                      if (_menuSelections.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Selected',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        ..._menuSelections.map(_buildMenuSelectionSummary),
                      ],
                    ],
                    const SizedBox(height: 24),

                    // Event Design Section (Prompt Based GenAI)
                    if (_serviceType == 'catering+event') ...[
                      if (_generatedImageUrl != null) ...[
                        Column(
                          children: [
                            Text(
                              'Generated Event Design',
                              style: GoogleFonts.getFont(
                                _primaryFont,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF1E1E1E),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              width: double.infinity,
                              height: 300,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  _generatedImageUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stack) {
                                    return Container(
                                      color: Colors.grey.shade200,
                                      child: const Center(
                                        child: Icon(
                                          Icons.error,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Your custom event design is ready!',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF1E1E1E),
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        Text(
                          'Event Design',
                          style: GoogleFonts.getFont(
                            _primaryFont,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1E1E1E),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Use our AI to design your event. Select your preferences below:',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),

                      // Event Type
                      _buildSectionTitle('Event Type'),
                      _buildDropdown(
                        _eventTypes,
                        _selectedEventType,
                        (val) => setState(() => _selectedEventType = val),
                      ),
                      const SizedBox(height: 16),

                      // Style
                      _buildSectionTitle('Style'),
                      _buildChips(
                        _styles,
                        _selectedStyle,
                        (val) => setState(() => _selectedStyle = val),
                      ),
                      const SizedBox(height: 16),

                      // Mood / Lighting
                      _buildSectionTitle('Mood / Lighting'),
                      _buildChips(
                        _moods,
                        _selectedMood,
                        (val) => setState(() => _selectedMood = val),
                      ),
                      const SizedBox(height: 16),

                      // Color Palette
                      _buildSectionTitle('Color Palette'),
                      _buildMultiSelect(_colorPalettes, _selectedColors),
                      const SizedBox(height: 16),

                      // Decor Elements
                      _buildSectionTitle('Decor Elements'),
                      _buildMultiSelect(_decorOptions, _selectedDecor),
                      const SizedBox(height: 16),

                      // Additional Instructions
                      _buildSectionTitle('Additional Instructions'),
                      TextField(
                        controller: _designPromptController,
                        decoration: const InputDecoration(
                          hintText:
                              'e.g., simple wedding setup with garden theme',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),

                      // Venue Photo Upload
                      _buildSectionTitle('Venue Photo'),
                      Tooltip(
                        message: 'Upload a photo of the venue',
                        child: OutlinedButton.icon(
                          onPressed: _pickVenuePhoto,
                          icon: const Icon(Icons.upload_file),
                          label: Text(
                            _venuePhotoBase64 != null
                                ? 'Photo Uploaded'
                                : 'Upload a photo of the venue',
                          ),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48),
                            side: BorderSide(
                              color:
                                  _venuePhotoBase64 != null
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
                      if (_venuePhotoBase64 != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          height: 150,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              base64Decode(_venuePhotoBase64!),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed:
                              () => setState(() => _venuePhotoBase64 = null),
                          icon: const Icon(Icons.delete, color: Colors.red),
                          label: const Text(
                            'Remove Photo',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),

                      // Generate Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _generateDesignPrompt,
                          icon: const Icon(Icons.auto_fix_high),
                          label: const Text(
                            'GENERATE EVENT DESIGN',
                            style: TextStyle(
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
                      const SizedBox(height: 32),
                    ],

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _submitting ? null : _submitInquiry,
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
      value: value,
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

  Future<void> _pickVenuePhoto() async {
    try {
      // Pick image file
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true, // Important: get the file bytes
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;

        // Check file size (max 5MB)
        if (file.bytes != null && file.bytes!.length > 5 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Image size should be less than 5MB'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        // Convert to base64
        if (file.bytes != null) {
          final base64String = base64Encode(file.bytes!);
          setState(() {
            _venuePhotoBase64 = base64String;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Photo uploaded: ${file.name}'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload photo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _generateDesignPrompt() async {
    // Validate that at least some selections are made
    if (_selectedEventType == null &&
        _selectedStyle == null &&
        _selectedMood == null &&
        _selectedColors.isEmpty &&
        _selectedDecor.isEmpty &&
        _designPromptController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select at least one option or provide instructions.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _submitting = true;
    });

    try {
      // Build the design prompt
      final prompt =
          _designPromptController.text.isNotEmpty
              ? _designPromptController.text
              : '${_selectedEventType ?? ''} ${_selectedStyle ?? ''} ${_selectedMood ?? ''} ${_selectedColors.join(', ')}';

      // Generate image using RunPod service
      final imageUrl = await RunPodService.generateImageWithPolling(
        prompt,
        user_id:
            'customer_${DateTime.now().millisecondsSinceEpoch}', // Generate unique user ID
      );

      if (imageUrl != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Event design generated successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );

        setState(() {
          _wantsCustomDesign = true;
          _generatedImageUrl = imageUrl;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to generate design. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        _submitting = false;
      });
    }
  }
}
