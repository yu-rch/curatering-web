import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/customer_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../auth/auth_session.dart';
import '../config.dart';
import '../config/site_routes.dart';
import '../models/menu_dish.dart';
import '../services/menu_store.dart';
import '../services/set_menu_store.dart';
import '../services/public_events_api.dart';
import '../services/website_content_store.dart';
import '../services/cart_store.dart';
import '../services/loyalty_rewards_store.dart';
import '../services/api_client.dart';
import '../widgets/map_picker.dart';
import '../widgets/contact_address_map.dart';
import '../widgets/event_venue_map_preview.dart';
import '../widgets/venue_autocomplete_field.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/antd_message.dart';
import '../widgets/antd_profile_menu.dart';
import '../widgets/pexels_attribution_badge.dart';
import '../widgets/catering_dish_info_dialog.dart';
import '../widgets/website_rich_text.dart';
import '../widgets/image_focus_dialog.dart';
import '../widgets/cms_sections.dart';
import '../widgets/customer_site_footer.dart';
import '../widgets/customer_website_topbar.dart';
import '../widgets/customer_antd_page_hero.dart';
import '../theme/website_header_font.dart';
import '../constants/catering_meal_types.dart';
import '../constants/home_default_assets.dart';
import '../utils/lazy_customer_login.dart';
import '../utils/gallery_search.dart';
import '../utils/inquiry_pricing.dart';
import '../utils/image_cache.dart';
import '../utils/responsive_layout.dart';

part 'customer_website_theme_editor.dart';

/// Letterboxing for placement editor: map between canvas coords and image bitmap (BoxFit.contain).
class _PlacementContainLayout {
  const _PlacementContainLayout({
    required this.offX,
    required this.offY,
    required this.dispW,
    required this.dispH,
    required this.scale,
  });
  final double offX;
  final double offY;
  final double dispW;
  final double dispH;
  final double scale;
}

_PlacementContainLayout _placementContainLayout(
  double cw,
  double ch,
  double iw,
  double ih,
) {
  final scale = math.min(cw / iw, ch / ih);
  final dispW = iw * scale;
  final dispH = ih * scale;
  final offX = (cw - dispW) / 2;
  final offY = (ch - dispH) / 2;
  return _PlacementContainLayout(
    offX: offX,
    offY: offY,
    dispW: dispW,
    dispH: dispH,
    scale: scale,
  );
}

class _SetDish {
  final String name;
  final String ingredients;
  final String tag;
  final String category;

  _SetDish({
    required this.name,
    required this.ingredients,
    required this.tag,
    required this.category,
  });
}

class _CustomDish {
  final String id;
  String name;
  String description;

  _CustomDish({
    required this.id,
    required this.name,
    required this.description,
  });
}

class _SetMenuOption {
  final String id;
  final String name;
  final String description;
  final List<_SetDish> dishes;

  _SetMenuOption({
    required this.id,
    required this.name,
    required this.description,
    required this.dishes,
  });
}

class _InquiryScheduleSlot {
  final DateTime date;
  final TimeOfDay startTime;
  final TimeOfDay endTime;

  const _InquiryScheduleSlot({
    required this.date,
    required this.startTime,
    required this.endTime,
  });

  String label(BuildContext context) {
    final dateStr =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return '$dateStr Â· ${startTime.format(context)}-${endTime.format(context)}';
  }
}

class _SoftCustomerOverlayPainter extends CustomPainter {
  _SoftCustomerOverlayPainter({
    required this.polygonPoints,
    required this.boundingBox,
    required this.selected,
  });

  final List<Map<String, dynamic>> polygonPoints;
  final Rect boundingBox;
  final bool selected;

  Path _buildPath(Size size) {
    if (polygonPoints.length >= 3) {
      final path = Path();
      final first = polygonPoints.first;
      final fx = (first['x'] as num?)?.toDouble() ?? 0;
      final fy = (first['y'] as num?)?.toDouble() ?? 0;
      path.moveTo(fx * size.width, fy * size.height);
      for (final pt in polygonPoints.skip(1)) {
        final x = (pt['x'] as num?)?.toDouble() ?? 0;
        final y = (pt['y'] as num?)?.toDouble() ?? 0;
        path.lineTo(x * size.width, y * size.height);
      }
      path.close();
      return path;
    }
    return Path()..addRRect(
      RRect.fromRectAndRadius(boundingBox, const Radius.circular(10)),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = _buildPath(size);
    final stroke =
        Paint()
          ..color = selected ? Colors.blue : Colors.orange
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;
    final fill =
        Paint()
          ..color =
              selected
                  ? Colors.blue.withValues(alpha: 0.20)
                  : Colors.orange.withValues(alpha: 0.08)
          ..style = PaintingStyle.fill;
    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(covariant _SoftCustomerOverlayPainter oldDelegate) {
    return selected != oldDelegate.selected ||
        polygonPoints.length != oldDelegate.polygonPoints.length ||
        boundingBox != oldDelegate.boundingBox;
  }
}
class CustomerInquireForm extends StatefulWidget {
  const CustomerInquireForm({this.staffThemeStudioMode = false});

  final bool staffThemeStudioMode;

  @override
  State<CustomerInquireForm> createState() => _CustomerInquireFormState();
}

class _CustomerInquireFormState extends State<CustomerInquireForm> {
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
  final List<_InquiryScheduleSlot> _eventScheduleSlots = [];

  // State
  String _eventType = 'Birthday';
  String _formality = 'casual';
  bool _submitting = false;

  // Service Type Selection
  String _serviceType = 'catering'; // 'catering' or 'catering+event'

  // Catering Service for small orders (< 50 PAX)
  bool?
  _cateringServiceSelected; // null = not selected yet, true/false for selection

  // Menu Selection State
  String _menuChoice = 'suggest'; // 'yes' or 'suggest'
  final Map<String, String> _selectedPaxOptions = {}; // dishId -> paxOption
  final List<String> _selectedDishIds = [];

  // Event Design State
  bool _wantsCustomDesign = false;

  // Set Menus (for suggest option)
  final List<_SetMenuOption> _setMenus = [];

  // Custom dishes (when curating own menu)
  final List<_CustomDish> _customDishes = [];
  final _customDishNameCtrl = TextEditingController();
  final _customDishDescCtrl = TextEditingController();

  // Event Design State (photos and theme)
  final List<String> _designPhotoUrls = []; // For uploaded/linked photos
  final _designPhotoCtrl = TextEditingController();
  final _linkedBaseUrlCtrl = TextEditingController();
  int? _focusedPhotoIndex;
  final _themeRequestCtrl =
      TextEditingController(); // For "I want to design my event" prompt
  bool _isDetectingAiObjects = false;
  bool _isSearchingThemeImages = false;
  bool _isExtractingThemeObjects = false;
  bool _isRenderingComposite = false;
  bool _isAddingByPrompt = false;
  bool _isAutoPlacing = false;
  bool _isAnalyzingBase = false;
  bool _isLockingBase = false;
  String? _selectedBaseImage;
  String? _confirmedCompositeBase64;
  final List<Map<String, dynamic>> _themeSuggestions = [];
  final Set<int> _selectedSuggestionIndexes = <int>{};
  final List<Map<String, dynamic>> _extractedThemeObjects = [];
  final List<Map<String, dynamic>> _placedThemeObjects = [];
  bool _isPlacementSaved = false;

  /// Natural pixel size of the selected base image (for placement â†” bitmap alignment).
  double? _baseImageNaturalW;
  double? _baseImageNaturalH;
  final List<Map<String, dynamic>> _baseFreeSpaces = [];
  final List<String> _baseRecommendations = [];
  final ScrollController _objectsStripScrollCtrl = ScrollController();
  // Avoid repeatedly base64-decoding the same images during drag/resize UI updates.
  final Map<String, Uint8List> _base64DecodeCache = {};
  static const Duration _aiRequestTimeout = Duration(seconds: 180);

  /// Wizard for "Design my event": 0 = pick base, 1 = pick add-on source images, 2 = compose.
  int _designEventWizardStep = 0;
  int? _pendingBaseSuggestionIndex;
  int _designEventBaseCarouselPage = 0;
  int _designEventAddonCarouselPage = 0;
  int _themeSearchPage = 1;
  bool _themeSearchHasMore = false;
  int _themeSearchTotal = 0;
  static const int _themeSearchPerPage = 12;

  int _themeSearchMaxPages() {
    if (_themeSearchTotal <= 0) return 1;
    return (_themeSearchTotal + _themeSearchPerPage - 1) ~/ _themeSearchPerPage;
  }

  @override
  void initState() {
    super.initState();
    SetMenuStore.instance.addListener(_onSetMenusChanged);
    MenuStore.instance.addListener(_onMenuChanged);
    if (widget.staffThemeStudioMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showDesignMyEventEditorPage();
      });
    }
    // Ensure set menus are loaded
    if (SetMenuStore.instance.activeSetMenus.isEmpty) {
      SetMenuStore.instance.loadSetMenus();
    }
    // Ensure dishes are loaded for set menu display
    if (MenuStore.instance.activeDishes.isEmpty) {
      MenuStore.instance.loadDishes().then((_) {
        unawaited(MenuStore.instance.ensureImagesLoaded());
      });
    } else {
      unawaited(MenuStore.instance.ensureImagesLoaded());
    }
    // Staff theme studio must not prompt for customer login.
    if (!widget.staffThemeStudioMode) {
      _loadCustomerData();
    }
  }

  Future<void> _loadCustomerData() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('customer_token');
    final customerData = prefs.getString('customer_data');

    if (token != null && token.isNotEmpty && customerData != null) {
      // User is logged in, auto-fill contact info
      final data = jsonDecode(customerData);
      if (mounted) {
        setState(() {
          _contactPerson.text = data['fullName'] ?? '';
          _email.text = data['email'] ?? '';
          _phone.text = data['phone'] ?? '';
        });
      }
    } else if (!widget.staffThemeStudioMode) {
      // User is not logged in, show login dialog
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await showLazyCustomerLoginDialog(
            context,
            redirectToCheckout: true,
          );
          if (!mounted) return;
          await _loadCustomerData();
        });
      }
    }
  }

  String? _selectedSetMenuId;

  void _onSetMenusChanged() {
    if (mounted) setState(() {});
  }

  void _onMenuChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    SetMenuStore.instance.removeListener(_onSetMenusChanged);
    MenuStore.instance.removeListener(_onMenuChanged);
    _customDishNameCtrl.dispose();
    _customDishDescCtrl.dispose();
    _designPhotoCtrl.dispose();
    _linkedBaseUrlCtrl.dispose();
    _objectsStripScrollCtrl.dispose();
    _themeRequestCtrl.dispose();
    super.dispose();
  }

  String _toHhmm(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  Future<void> _pickAddressFromMap() async {
    final picked = await showMapPicker(
      context: context,
      initialAddress: _address.text.trim(),
      initialLatitude: _addressLat,
      initialLongitude: _addressLng,
    );
    if (picked != null) {
      setState(() {
        _address.text = picked.address;
        _addressLat = picked.latitude;
        _addressLng = picked.longitude;
      });
    }
  }

  Future<void> _addEventScheduleSlot() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (pickedDate == null) return;

    final start = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );
    if (start == null) return;

    final end = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: (start.hour + 1) % 24, minute: start.minute),
    );
    if (end == null) return;

    setState(() {
      _eventScheduleSlots.add(
        _InquiryScheduleSlot(date: pickedDate, startTime: start, endTime: end),
      );
      _dateController.text =
          '${pickedDate.month.toString().padLeft(2, '0')}/${pickedDate.day.toString().padLeft(2, '0')}/${pickedDate.year}';
      _timeController.text = start.format(context);
    });
  }

  Future<void> _showOrderSummaryDialog() async {
    // Validate required fields first
    final missing = <String>[];
    final isCateringOnly = _serviceType == 'catering';

    if (!isCateringOnly) {
      if (_eventTitle.text.trim().isEmpty) missing.add('event title');
    }
    if (_customer.text.trim().isEmpty) missing.add('customer name');
    if (_contactPerson.text.trim().isEmpty) missing.add('contact person');
    if (_phone.text.trim().isEmpty) missing.add('phone');
    if (_email.text.trim().isEmpty) missing.add('email');
    if (_address.text.trim().isEmpty) missing.add('city / address');
    if (_eventScheduleSlots.isEmpty) missing.add('event schedule');
    final g = int.tryParse(_guests.text.trim());
    if (g == null || g < 1) missing.add('guest count');

    // Menu is required
    if (_menuChoice == 'yes' &&
        _selectedDishIds.isEmpty &&
        _customDishes.isEmpty) {
      missing.add('menu (select dishes or add custom dishes)');
    } else if (_menuChoice == 'suggest' && _selectedSetMenuId == null) {
      missing.add('menu (select a set menu)');
    }

    if (missing.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Complete: ${missing.join(', ')}')),
      );
      return;
    }

    // Build menu items for summary
    List<Map<String, dynamic>> menuItems = [];
    String menuSummaryTitle = '';

    if (_menuChoice == 'yes') {
      menuSummaryTitle = 'Curated Menu';
      for (final dishId in _selectedDishIds) {
        final dish = MenuStore.instance.allDishes.firstWhere(
          (d) => d.id == dishId,
        );
        menuItems.add({'dishName': dish.name, 'paxOption': '', 'price': '0'});
      }
      for (final customDish in _customDishes) {
        menuItems.add({
          'dishName': customDish.name,
          'paxOption': 'Custom',
          'price': 0,
        });
      }
    } else if (_selectedSetMenuId != null) {
      final setMenu = SetMenuStore.instance.activeSetMenus.firstWhere(
        (s) => s.id == _selectedSetMenuId,
      );
      menuSummaryTitle = 'Set Menu: ${setMenu.name}';
      for (final dishId in setMenu.dishIds) {
        final dish = MenuStore.instance.allDishes.firstWhere(
          (d) => d.id == dishId,
        );
        menuItems.add({'dishName': dish.name, 'paxOption': '', 'price': '0'});
      }
    } else {
      menuSummaryTitle = 'Menu to be suggested by our team';
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.receipt_long, color: Color(0xFF4CAF50)),
              SizedBox(width: 8),
              Text('Order Summary'),
            ],
          ),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Event Details
                  _buildSummarySection('Event Details', [
                    _buildSummaryRow(
                      'Service Type',
                      _serviceType == 'catering'
                          ? 'Catering Only'
                          : 'Catering + Event',
                    ),
                    if (!isCateringOnly) ...[
                      _buildSummaryRow('Event Title', _eventTitle.text.trim()),
                      _buildSummaryRow('Event Type', _eventType),
                      _buildSummaryRow('Formality', _formality),
                    ],
                    _buildSummaryRow('Date', _dateController.text.trim()),
                    _buildSummaryRow('Time', _timeController.text.trim()),
                    _buildSummaryRow('Guests', _guests.text.trim()),
                    if (g != null && g > 0)
                      _buildSummaryRow(
                        'Catering estimate',
                        'â‚±${estimateInquiryCateringTotal(g).toStringAsFixed(0)} '
                            '(â‚±${kCateringInquiryPricePerGuest.toStringAsFixed(0)} Ã— $g guests)',
                      ),
                  ]),
                  const Divider(height: 24),

                  // Contact Information
                  _buildSummarySection('Contact Information', [
                    _buildSummaryRow('Customer', _customer.text.trim()),
                    _buildSummaryRow(
                      'Contact Person',
                      _contactPerson.text.trim(),
                    ),
                    _buildSummaryRow('Phone', _phone.text.trim()),
                    _buildSummaryRow('Email', _email.text.trim()),
                    _buildSummaryRow('Address', _address.text.trim()),
                  ]),
                  const Divider(height: 24),

                  // Menu
                  _buildSummarySection(
                    menuSummaryTitle,
                    menuItems.isEmpty
                        ? [
                          _buildSummaryRow(
                            'Menu',
                            'Will be suggested by our team',
                          ),
                        ]
                        : menuItems
                            .map(
                              (item) => _buildSummaryRow(
                                item['dishName'],
                                'Selected',
                              ),
                            )
                            .toList(),
                  ),

                  // Theme/Design
                  if (_serviceType == 'catering+event') ...[
                    const Divider(height: 24),
                    _buildSummarySection('Theme & Design', [
                      _buildSummaryRow(
                        'Custom Design',
                        _wantsCustomDesign ? 'Yes' : 'Standard',
                      ),
                      if (_themeRequestCtrl.text.trim().isNotEmpty)
                        _buildSummaryRow(
                          'Theme Request',
                          _themeRequestCtrl.text.trim(),
                        ),
                      if (_designBoardPhotos().isNotEmpty)
                        _buildSummaryRow(
                          'Reference Photos',
                          '${_designBoardPhotos().length} photo(s)',
                        ),
                    ]),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('EDIT'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                foregroundColor: Colors.white,
              ),
              child: const Text('CONFIRM & SUBMIT'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _submit();
    }
  }

  Widget _buildSummarySection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Color(0xFF4CAF50),
          ),
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final missing = <String>[];
    final isCateringOnly = _serviceType == 'catering';

    // Only validate event-specific fields for catering+event
    if (!isCateringOnly) {
      if (_eventTitle.text.trim().isEmpty) missing.add('event title');
    }
    if (_customer.text.trim().isEmpty) missing.add('customer name');
    if (_contactPerson.text.trim().isEmpty) missing.add('contact person');
    if (_phone.text.trim().isEmpty) missing.add('phone');
    if (_email.text.trim().isEmpty) missing.add('email');
    if (_address.text.trim().isEmpty) missing.add('city / address');
    if (_eventScheduleSlots.isEmpty) missing.add('event schedule');
    final g = int.tryParse(_guests.text.trim());
    if (g == null || g < 1) missing.add('guest count');

    // Menu is required
    if (_menuChoice == 'yes' &&
        _selectedDishIds.isEmpty &&
        _customDishes.isEmpty) {
      missing.add('menu (select dishes or add custom dishes)');
    } else if (_menuChoice == 'suggest' && _selectedSetMenuId == null) {
      missing.add('menu (select a set menu)');
    }

    if (missing.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Complete: ${missing.join(', ')}')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      // Build menu items
      List<Map<String, dynamic>> menuItems = [];
      if (_menuChoice == 'yes') {
        // Curated menu - include selected dishes
        for (final dishId in _selectedDishIds) {
          final dish = MenuStore.instance.allDishes.firstWhere(
            (d) => d.id == dishId,
          );
          menuItems.add({
            'dishId': dishId,
            'dishName': dish.name,
            'paxOption': '',
            'price': '0',
            'isCustom': false,
          });
        }
        // Add custom dishes
        for (final customDish in _customDishes) {
          menuItems.add({
            'dishId': customDish.id,
            'dishName': customDish.name,
            'paxOption': 'Custom',
            'price': 0,
            'isCustom': true,
            'description': customDish.description,
          });
        }
      } else if (_selectedSetMenuId != null) {
        // Set menu selected - use SetMenuStore
        final setMenu = SetMenuStore.instance.activeSetMenus.firstWhere(
          (s) => s.id == _selectedSetMenuId,
        );
        for (final dishId in setMenu.dishIds) {
          final dish = MenuStore.instance.allDishes.firstWhere(
            (d) => d.id == dishId,
          );
          menuItems.add({
            'dishId': dishId,
            'dishName': dish.name,
            'paxOption': '',
            'price': '0',
            'isCustom': false,
          });
        }
      }

      await PublicEventsApi.instance.submitOnlineInquiry(
        payload: {
          'orderType':
              _serviceType == 'catering' ? 'catering' : 'catering_event',
          'eventTitle':
              _serviceType == 'catering' ? '' : _eventTitle.text.trim(),
          'eventType': _serviceType == 'catering' ? null : _eventType,
          'formalityLevel': _serviceType == 'catering' ? null : _formality,
          'customerName': _customer.text.trim(),
          'contactPerson': _contactPerson.text.trim(),
          'contactNumber': _phone.text.trim(),
          'emailAddress': _email.text.trim(),
          'scheduleSlots':
              _eventScheduleSlots
                  .map(
                    (slot) => {
                      'date':
                          '${slot.date.year.toString().padLeft(4, '0')}-${slot.date.month.toString().padLeft(2, '0')}-${slot.date.day.toString().padLeft(2, '0')}',
                      'startTime': _toHhmm(slot.startTime),
                      'endTime': _toHhmm(slot.endTime),
                    },
                  )
                  .toList(),
          'address': _address.text.trim(),
          if (_addressLat != null) 'addressLat': _addressLat,
          if (_addressLng != null) 'addressLng': _addressLng,
          'guestCount': g,
          'menu': menuItems,
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inquiry submitted. We\'ll get back to you soon!'),
        ),
      );
      // Reset form after successful submission
      _resetForm();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not submit. Is the server running?'),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _resetForm() {
    setState(() {
      // Clear all text controllers
      _eventTitle.clear();
      _customer.clear();
      _contactPerson.clear();
      _phone.clear();
      _email.clear();
      _address.clear();
      _guests.clear();
      _dateController.clear();
      _timeController.clear();
      _eventScheduleSlots.clear();
      _themeRequestCtrl.clear();
      _designPhotoCtrl.clear();

      // Reset state variables to initial values
      _eventType = 'Birthday';
      _formality = 'casual';
      _serviceType = 'catering';
      _cateringServiceSelected = null;
      _menuChoice = 'suggest';
      _wantsCustomDesign = false;
      _selectedSetMenuId = null;

      // Clear collections
      _selectedPaxOptions.clear();
      _selectedDishIds.clear();
      _setMenus.clear();
      _customDishes.clear();
      _designPhotoUrls.clear();
      _focusedPhotoIndex = null;
      _selectedBaseImage = null;
      _baseImageNaturalW = null;
      _baseImageNaturalH = null;
      _confirmedCompositeBase64 = null;
      _themeSuggestions.clear();
      _selectedSuggestionIndexes.clear();
      _extractedThemeObjects.clear();
      _placedThemeObjects.clear();
      _isPlacementSaved = false;
      _baseFreeSpaces.clear();
      _baseRecommendations.clear();
      _designEventWizardStep = 0;
      _pendingBaseSuggestionIndex = null;
      _designEventBaseCarouselPage = 0;
      _designEventAddonCarouselPage = 0;
      _themeSearchPage = 1;
      _themeSearchHasMore = false;
      _themeSearchTotal = 0;

      // Keep customer info if logged in (reload from saved data)
      _loadCustomerData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktopWidth(context) ? 40 : 16,
        vertical: isDesktopWidth(context) ? 24 : 16,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: appContentMaxWidth(context),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title
              Text(
                'Inquire',
                textAlign: TextAlign.center,
                style: websiteHeaderStyle(
                  fontSize: 42,
                  color: Colors.red.shade400,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFFFC024)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Inquire for Catering or Event',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Three Column Layout
              isDesktopWidth(context)
                  ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 5, child: _buildEventInfoColumn()),
                      const SizedBox(width: 16),
                      Expanded(flex: 5, child: _buildMenuColumn()),
                      const SizedBox(width: 16),
                      if (_serviceType == 'catering+event')
                        Expanded(flex: 4, child: _buildEventDesignColumn()),
                    ],
                  )
                  : Column(
                    children: [
                      _buildEventInfoColumn(),
                      const SizedBox(height: 16),
                      _buildMenuColumn(),
                      const SizedBox(height: 16),
                      if (_serviceType == 'catering+event')
                        _buildEventDesignColumn(),
                    ],
                  ),

              const SizedBox(height: 32),
              // Submit Button
              Center(
                child: SizedBox(
                  width: screenWidth < 600 ? double.infinity : 360,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _showOrderSummaryDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      side: const BorderSide(
                        color: Color(0xFF4CAF50),
                        width: 2,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child:
                        _submitting
                            ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Text(
                              'REVIEW & SUBMIT',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildServiceTypeButton(String label, String value) {
    final isSelected = _serviceType == value;
    return ElevatedButton(
      onPressed: () => setState(() => _serviceType = value),
      style: ElevatedButton.styleFrom(
        backgroundColor:
            isSelected ? const Color(0xFFFFC107) : Colors.grey.shade200,
        foregroundColor: Colors.black,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isSelected ? const Color(0xFFFFC107) : Colors.grey.shade400,
          ),
        ),
      ),
      child: Text(label),
    );
  }

  Widget _buildEventInfoColumn() {
    final isCateringOnly = _serviceType == 'catering';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFC107),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isCateringOnly ? 'ORDER INFORMATION' : 'EVENT INFORMATION',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'SERVICE TYPE',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildServiceTypeButton('Catering Only', 'catering'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildServiceTypeButton(
                  'Catering + Event',
                  'catering+event',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Only show event fields for catering+event
          if (!isCateringOnly) ...[
            _buildTextField(_eventTitle, 'EVENT TITLE'),
            const SizedBox(height: 12),
            _buildDropdown('EVENT TYPE', _eventType, [
              'Wedding',
              'Birthday',
              'Anniversary',
              'Corporate',
              'Private Party',
              'Sports',
              'Government',
              'Show',
              'Educational',
              'Reunion',
              'Gala',
              'Dinner',
              'Other',
            ], (v) => setState(() => _eventType = v)),
            const SizedBox(height: 12),
            _buildDropdown(
              'FORMALITY LEVEL',
              _formality,
              ['casual', 'semi_formal', 'formal'],
              (v) => setState(() => _formality = v),
              displayMap: {
                'casual': 'Casual',
                'semi_formal': 'Semi-formal',
                'formal': 'Formal',
              },
            ),
            const SizedBox(height: 12),
          ],
          _buildTextField(_customer, 'CUSTOMER NAME'),
          const SizedBox(height: 12),
          _buildTextField(_contactPerson, 'CONTACT PERSON'),
          const SizedBox(height: 12),
          _buildTextField(
            _phone,
            'CONTACT NUMBER',
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            _email,
            'EMAIL ADDRESS',
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),
          VenueAutocompleteField(
            controller: _address,
            label: 'Venue / address',
            onSelected: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _pickAddressFromMap,
              icon: const Icon(Icons.map_outlined, size: 20),
              label: const Text('Pick on map (OpenStreetMap)'),
            ),
          ),
          if (_address.text.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            EventVenueMapPreview(address: _address.text.trim()),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _addEventScheduleSlot,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF4511E),
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.add),
              label: const Text('Add Event Schedule'),
            ),
          ),
          const SizedBox(height: 8),
          if (_eventScheduleSlots.isEmpty)
            Text(
              'No schedules yet.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  _eventScheduleSlots.asMap().entries.map((entry) {
                    final index = entry.key;
                    final slot = entry.value;
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
          const SizedBox(height: 12),
          TextField(
            controller: _guests,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'NO OF GUESTS',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 10,
              ),
            ),
            style: const TextStyle(fontSize: 13),
            onChanged:
                (value) => setState(() {
                  // Reset catering service selection when guest count changes
                  final count = int.tryParse(value) ?? 0;
                  if (count >= 50) {
                    _cateringServiceSelected = null;
                  }
                }),
          ),
          const SizedBox(height: 12),
          // Catering Service radio for small orders (< 50 PAX)
          _buildCateringServiceOption(),
        ],
      ),
    );
  }

  Widget _buildCateringServiceOption() {
    // Check if guest count is less than 50
    final guestCount = int.tryParse(_guests.text) ?? 0;
    if (guestCount >= 50 || guestCount <= 0) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'CATERING SERVICE',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: RadioListTile<bool>(
                title: const Text('Yes'),
                value: true,
                groupValue: _cateringServiceSelected,
                onChanged: (v) => setState(() => _cateringServiceSelected = v),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            Expanded(
              child: RadioListTile<bool>(
                title: const Text('No'),
                value: false,
                groupValue: _cateringServiceSelected,
                onChanged: (v) => setState(() => _cateringServiceSelected = v),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
        if (_cateringServiceSelected == true)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              border: Border.all(color: Colors.orange.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber,
                  color: Colors.orange.shade700,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'For catering orders with less than 50 PAX will incur additional charges.',
                    style: TextStyle(
                      color: Colors.orange.shade700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildMenuColumn() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
        borderRadius: BorderRadius.circular(14),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFC107),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'MENU',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'WOULD YOU LIKE TO CURATE YOUR OWN MENU?',
            style: TextStyle(fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildMenuChoiceButton('YES!', 'yes'),
              const SizedBox(width: 12),
              _buildMenuChoiceButton(
                'NO I\'D LIKE MACRINAS TO\nSUGGEST ME A MENU INSTEAD',
                'suggest',
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Menu Content
          if (_menuChoice == 'yes')
            _buildDishSelectionList()
          else if (_selectedSetMenuId != null)
            _buildSetMenuView()
          else
            _buildSetMenuSelection(),
        ],
      ),
    );
  }

  Widget _buildMenuChoiceButton(String label, String value) {
    final isSelected = _menuChoice == value;
    return ElevatedButton(
      onPressed: () => setState(() => _menuChoice = value),
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? const Color(0xFFE8F5E9) : Colors.white,
        foregroundColor: Colors.black,
        side: BorderSide(
          color: isSelected ? const Color(0xFF4CAF50) : Colors.grey.shade400,
          width: 2,
        ),
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 11),
      ),
    );
  }

  Widget _buildDishSelectionList() {
    final dishes =
        MenuStore.instance.activeDishes
            .where((d) => d.category == 'catering')
            .toList();
    return Container(
      constraints: const BoxConstraints(maxHeight: 500),
      child: Column(
        children: [
          // Add Custom Dish Button
          ElevatedButton.icon(
            onPressed: _showAddCustomDishDialog,
            icon: const Icon(Icons.add),
            label: const Text('Add Custom Dish'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFC024),
              foregroundColor: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          // Custom Dishes Section
          if (_customDishes.isNotEmpty) ...[
            const Text(
              'Custom Dishes:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ..._customDishes.map(
              (customDish) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                color: Colors.amber.shade50,
                child: ListTile(
                  leading: const Icon(
                    Icons.edit_note,
                    size: 40,
                    color: Color(0xFFFFC024),
                  ),
                  title: Text(
                    customDish.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    customDish.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        _customDishes.removeWhere((d) => d.id == customDish.id);
                      });
                    },
                  ),
                ),
              ),
            ),
            const Divider(),
          ],
          // Catering Dishes from Menu
          Expanded(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: dishes.length,
              itemBuilder: (context, index) {
                final dish = dishes[index];
                final isSelected = _selectedDishIds.contains(dish.id);
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading:
                        dish.imageBase64 != null
                            ? Image.memory(
                              base64Decode(dish.imageBase64!),
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                            )
                            : const Icon(Icons.restaurant, size: 40),
                    title: Text(
                      dish.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${formatInquiryCateringDishPrice()} / guest',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    trailing:
                        isSelected
                            ? const Icon(
                              Icons.check_circle,
                              color: Color(0xFF4CAF50),
                            )
                            : const Icon(
                              Icons.add_circle_outline,
                              color: Colors.grey,
                            ),
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedDishIds.remove(dish.id);
                          _selectedPaxOptions.remove(dish.id);
                        } else {
                          _selectedDishIds.add(dish.id);
                          _selectedPaxOptions[dish.id] = '';
                        }
                      });
                    },
                    selected: isSelected,
                    selectedTileColor: Colors.green.shade50,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showAddCustomDishDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Add Custom Dish'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _customDishNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Dish Name',
                    hintText: 'e.g., Grilled Salmon with Lemon Butter',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _customDishDescCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    hintText: 'Special requests, ingredients, etc.',
                  ),
                  maxLines: 3,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (_customDishNameCtrl.text.trim().isNotEmpty) {
                    setState(() {
                      _customDishes.add(
                        _CustomDish(
                          id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
                          name: _customDishNameCtrl.text.trim(),
                          description: _customDishDescCtrl.text.trim(),
                        ),
                      );
                      _customDishNameCtrl.clear();
                      _customDishDescCtrl.clear();
                    });
                  }
                  Navigator.pop(context);
                },
                child: const Text('Add'),
              ),
            ],
          ),
    );
  }

  Widget _buildSetMenuSelection() {
    final setMenus = SetMenuStore.instance.activeSetMenus;
    if (setMenus.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'No set menus available. Please choose "YES!" to curate your own menu.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }
    return Column(
      children:
          setMenus.map((setMenu) {
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color:
                      _selectedSetMenuId == setMenu.id
                          ? const Color(0xFFFFC024)
                          : Colors.grey.shade300,
                  width: _selectedSetMenuId == setMenu.id ? 1.5 : 1,
                ),
              ),
              child: ListTile(
                title: Text(
                  setMenu.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${setMenu.dishIds.length} dishes',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap to preview dishes',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                isThreeLine: true,
                trailing: Radio<String>(
                  value: setMenu.id,
                  groupValue: _selectedSetMenuId,
                  onChanged: (v) {
                    setState(() {
                      _selectedSetMenuId = v;
                    });
                  },
                ),
                onTap: () {
                  setState(() {
                    _selectedSetMenuId = setMenu.id;
                  });
                },
              ),
            );
          }).toList(),
    );
  }

  Widget _buildSetMenuView() {
    final setMenu = SetMenuStore.instance.activeSetMenus.firstWhere(
      (s) => s.id == _selectedSetMenuId,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              setMenu.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3D0),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${setMenu.dishIds.length} dishes',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: Color(0xFF9A6B00),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'Dishes in this set:',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        ...setMenu.dishIds.map((dishId) {
          final dish = MenuStore.instance.allDishes.firstWhere(
            (d) => d.id == dishId,
            orElse:
                () => MenuDish(
                  id: dishId,
                  name: 'Unknown Dish',
                  category: '',
                  price: '0',
                  archived: false,
                  paxOptions: ['10 pax'],
                ),
          );
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: ListTile(
              dense: true,
              leading:
                  dish.imageBase64 != null
                      ? Image.memory(
                        base64Decode(dish.imageBase64!),
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                      )
                      : const Icon(Icons.restaurant, size: 32),
              title: Text(dish.name, style: const TextStyle(fontSize: 13)),
              subtitle: const Text(
                'Selected dish',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              trailing: const Icon(
                Icons.check_circle,
                color: Color(0xFF1DB954),
              ),
            ),
          );
        }),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: () => setState(() => _selectedSetMenuId = null),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade100,
            foregroundColor: Colors.red,
          ),
          child: const Text('Change Set Menu'),
        ),
      ],
    );
  }

  Widget _buildEventDesignColumn() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'EVENT DESIGN',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 16),
          const Text(
            'WE CAN SUGGEST SOME DESIGNS FOR\nINSPIRATION FOR YOU TO PUT TOGETHER!\n\nJUST LET US KNOW HOW YOU\'D LIKE YOUR\nEVENT TO LOOK!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11),
          ),
          const SizedBox(height: 24),
          // Show selected state
          if (_wantsCustomDesign) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                border: Border.all(color: const Color(0xFF4CAF50)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  const Row(
                    children: [
                      Icon(Icons.check_circle, color: Color(0xFF4CAF50)),
                      SizedBox(width: 8),
                      Text(
                        'You will create your event design',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  if (_designBoardPhotos().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('${_designBoardPhotos().length} photo(s) added'),
                  ],
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _showCustomDesignDialog,
                    child: const Text('Manage Photos'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => setState(() => _wantsCustomDesign = false),
              child: const Text('Change to Assisted Design'),
            ),
          ] else if (_themeRequestCtrl.text.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                border: Border.all(color: Colors.red.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  const Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.red),
                      SizedBox(width: 8),
                      Text(
                        'Assisted event design is selected',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _showDesignMyEventDialog,
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        'Theme: ${_themeRequestCtrl.text}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          decoration: TextDecoration.underline,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  if ((_confirmedCompositeBase64 ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        height: 84,
                        width: double.infinity,
                        child: _designImagePreview(
                          _confirmedCompositeBase64!,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Tap theme text to continue editing this draft design.',
                      style: TextStyle(fontSize: 11, color: Colors.black54),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                setState(() => _wantsCustomDesign = true);
                _showCustomDesignDialog();
              },
              child: const Text('Change to My Design'),
            ),
          ] else ...[
            ElevatedButton(
              onPressed: () {
                setState(() => _wantsCustomDesign = true);
                _showCustomDesignDialog();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                side: const BorderSide(color: Color(0xFF4CAF50), width: 2),
                elevation: 0,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('I WANT TO CREATE MY OWN DESIGN'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                _showDesignMyEventDialog();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                side: BorderSide(color: Colors.red.shade300, width: 2),
                elevation: 0,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'I WANT TO DESIGN MY EVENT',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _searchThemeSuggestions({
    bool loadMore = false,
    int? goToPage,
  }) async {
    final prompt = _themeRequestCtrl.text.trim();
    if (prompt.isEmpty) return;
    final int nextPage;
    if (goToPage != null) {
      nextPage = goToPage;
    } else if (loadMore) {
      nextPage = _themeSearchPage + 1;
    } else {
      nextPage = 1;
    }
    final isNewSearch = !loadMore && goToPage == null;
    final isPageNav = goToPage != null;
    setState(() => _isSearchingThemeImages = true);
    try {
      final response = await PublicEventsApi.instance.searchThemeImages(
        eventTitle: _eventTitle.text.trim(),
        eventType: _eventType,
        formalityLevel: _formality,
        prompt: prompt,
        baseImageUrl: _selectedBaseImage,
        tags: const ['decoration', 'design', 'theme'],
        page: nextPage,
        perPage: _themeSearchPerPage,
      );
      final usedFallback = response['usedFallback'] == true;
      final warning = (response['error'] ?? '').toString().trim();
      final hasMore = response['hasMore'] == true;
      final rawTotal = response['total'];
      var total =
          rawTotal is num ? rawTotal.toInt() : int.tryParse('$rawTotal') ?? 0;
      final rawImages =
          (response['images'] as List<dynamic>? ?? const [])
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
      final images =
          rawImages
              .where((row) => !_isLikelyPeopleImageSuggestion(row))
              .toList();
      if (total <= 0 && images.isNotEmpty) {
        total = images.length;
      }
      setState(() {
        _themeSearchPage = nextPage;
        _themeSearchHasMore = hasMore;
        _themeSearchTotal = total;
        if (loadMore && goToPage == null) {
          final seen =
              _themeSuggestions
                  .map((row) => (row['imageUrl'] ?? '').toString())
                  .toSet();
          for (final row in images) {
            final url = (row['imageUrl'] ?? '').toString();
            if (url.isEmpty || seen.contains(url)) continue;
            seen.add(url);
            _themeSuggestions.add(row);
          }
        } else {
          _themeSuggestions
            ..clear()
            ..addAll(images);
          if (isNewSearch) {
            _selectedSuggestionIndexes.clear();
            // Only reset base image if we're in Step 0 (template selection)
            // In Step 2 (element selection), preserve the base image
            if (_designEventWizardStep == 0) {
              _selectedBaseImage = null;
              _baseImageNaturalW = null;
              _baseImageNaturalH = null;
              _isPlacementSaved = false;
              _designEventWizardStep = 0;
              _pendingBaseSuggestionIndex = null;
              _designEventBaseCarouselPage = 0;
              _designEventAddonCarouselPage = 0;
            }
          } else if (isPageNav) {
            _selectedSuggestionIndexes.clear();
            _pendingBaseSuggestionIndex = null;
            _designEventBaseCarouselPage = 0;
            _designEventAddonCarouselPage = 0;
            if (_designEventWizardStep == 0) {
              _selectedBaseImage = null;
            }
          }
        }
      });
      if (mounted) {
        if (!loadMore && !isPageNav && images.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No decor-only results found. Try a more specific prompt (e.g. "table setup, balloons, centerpieces, no people").',
              ),
            ),
          );
        } else if (!loadMore && !isPageNav && usedFallback) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                warning.isNotEmpty
                    ? 'Using fallback image suggestions: $warning'
                    : 'Using fallback image suggestions. Check Pexels API key/config in server env.',
              ),
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isSearchingThemeImages = false);
    }
  }

  bool _isLikelyPeopleImageSuggestion(Map<String, dynamic> row) {
    final source = (row['source'] ?? '').toString().toLowerCase().trim();
    final text = [
      row['title'],
      row['description'],
      row['imageUrl'],
      row['thumbnailUrl'],
      row['photographer'],
      row['pexelsUrl'],
    ].map((v) => (v ?? '').toString().toLowerCase()).join(' ');

    final hasPeopleKeyword = RegExp(
      r'\b(person|people|human|portrait|face|selfie|man|woman|boy|girl|bride|groom|model|crowd|group)\b',
    ).hasMatch(text);

    // When backend falls back to generic stock images, aggressively filter
    // to avoid showing people-focused references in the design workflow.
    if (source == 'fallback' &&
        !text.contains('decor') &&
        !text.contains('tablescape')) {
      return true;
    }
    return hasPeopleKeyword;
  }

  Future<void> _extractSelectedObjects() async {
    if (_selectedSuggestionIndexes.isEmpty) return;
    setState(() => _isExtractingThemeObjects = true);
    try {
      final selectedUrls =
          _selectedSuggestionIndexes
              .map((i) => _themeSuggestions[i]['imageUrl']?.toString() ?? '')
              .where((u) => u.isNotEmpty)
              .toList();
      final bytesList = await Future.wait(
        selectedUrls.map(_resolveDesignPhotoBytes),
      );
      final encoded = bytesList.map(base64Encode).toList();
      final response = await PublicEventsApi.instance.extractThemeObjects(
        imagesBase64: encoded,
      );
      final imageGroups =
          (response['images'] as List<dynamic>? ?? const []).whereType<Map>();
      final flattened = <Map<String, dynamic>>[];
      var failedImages = 0;
      for (final group in imageGroups) {
        if ((group['error'] ?? '').toString().trim().isNotEmpty) {
          failedImages += 1;
        }
        final objects = (group['objects'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e));
        flattened.addAll(objects);
      }
      var visibleObjects =
          flattened
              .where(
                (row) => (row['objectImageBase64'] ?? '').toString().isNotEmpty,
              )
              .toList();
      var usedSourceFallback = false;
      if (visibleObjects.isEmpty) {
        usedSourceFallback = true;
        visibleObjects =
            encoded.take(6).toList().asMap().entries.map((entry) {
              return <String, dynamic>{
                'id': 'fallback_source_${entry.key}',
                'label': 'Source image',
                'score': 1.0,
                'objectImageBase64': entry.value,
              };
            }).toList();
      }
      setState(() {
        _extractedThemeObjects
          ..clear()
          ..addAll(visibleObjects);
        _placedThemeObjects.clear();
        _isPlacementSaved = false;
      });
      if (mounted && usedSourceFallback) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No objects were extracted. Using selected source images as fallback cutouts.',
            ),
          ),
        );
      }
      if (mounted && failedImages > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              failedImages == 1
                  ? 'Segmentation failed for 1 source image; others were kept if any.'
                  : 'Segmentation failed for $failedImages source images; others were kept if any.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExtractingThemeObjects = false);
    }
  }

  Future<void> _analyzeBaseAndRecommend() async {
    if (_selectedBaseImage == null) return;
    setState(() => _isAnalyzingBase = true);
    try {
      final baseBytes = await _resolveDesignPhotoBytes(_selectedBaseImage!);
      final response = await PublicEventsApi.instance.analyzeBaseImage(
        baseImageBase64: base64Encode(baseBytes),
      );
      setState(() {
        _baseFreeSpaces
          ..clear()
          ..addAll(
            (response['freeSpaces'] as List<dynamic>? ?? const [])
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e)),
          );
        _baseRecommendations
          ..clear()
          ..addAll(
            (response['recommendations'] as List<dynamic>? ?? const []).map(
              (e) => e.toString(),
            ),
          );
      });
    } finally {
      if (mounted) setState(() => _isAnalyzingBase = false);
    }
  }

  Future<void> _autoPlaceSelectedObjects() async {
    if (_extractedThemeObjects.isEmpty) return;
    setState(() => _isAutoPlacing = true);
    try {
      final response = await PublicEventsApi.instance.autoPlaceThemeObjects(
        freeSpaces: _baseFreeSpaces,
        objects: _extractedThemeObjects,
      );
      final placements =
          (response['placements'] as List<dynamic>? ?? const [])
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();

      final nextPlaced = <Map<String, dynamic>>[];
      for (var i = 0; i < placements.length; i++) {
        final p = placements[i];
        final pid = (p['objectId'] ?? '').toString();
        Map<String, dynamic>? match;
        for (final obj in _extractedThemeObjects) {
          if ((obj['id'] ?? '').toString() == pid) {
            match = obj;
            break;
          }
        }
        match ??=
            i < _extractedThemeObjects.length
                ? _extractedThemeObjects[i]
                : null;
        if (match == null) continue;
        final b64 = (match['objectImageBase64'] ?? '').toString();
        if (b64.isEmpty) continue;
        nextPlaced.add({
          'id': p['objectId'] ?? match['id'],
          'x': p['x'],
          'y': p['y'],
          'width': p['width'],
          'height': p['height'],
          'rotation': p['rotation'] ?? 0,
          'zIndex': p['zIndex'] ?? i,
          'intensity': 1.0,
          'targetHex': '#f4511e',
          '_checked': false,
          'objectImageBase64': b64,
        });
      }

      if (nextPlaced.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Auto place had nothing to apply. Your current placement was left unchanged.',
              ),
            ),
          );
        }
        return;
      }

      setState(() {
        _placedThemeObjects
          ..clear()
          ..addAll(nextPlaced);
        _isPlacementSaved = false;
      });
    } catch (e, st) {
      debugPrint('autoPlace: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is Exception
                  ? e.toString().replaceFirst('Exception: ', '')
                  : 'Auto place failed. Your placement was left unchanged.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isAutoPlacing = false);
    }
  }

  Future<void> _renderComposite() async {
    if (_selectedBaseImage == null) return;
    if (_baseImageNaturalW == null ||
        _baseImageNaturalH == null ||
        _baseImageNaturalW! <= 0 ||
        _baseImageNaturalH! <= 0) {
      await _cacheBaseImageNaturalSize();
    }
    if (_baseImageNaturalW == null ||
        _baseImageNaturalH == null ||
        _baseImageNaturalW! <= 0 ||
        _baseImageNaturalH! <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not read base image size. Try re-selecting the base image.',
            ),
          ),
        );
      }
      return;
    }
    if (!_isPlacementSaved) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please click Save Placement before rendering.'),
          ),
        );
      }
      return;
    }
    setState(() => _isRenderingComposite = true);
    try {
      // FastAPI validation is strict (e.g. width/height must be > 1).
      // Sanitize current editor state before sending to render-composite.
      final iw = _baseImageNaturalW!;
      final ih = _baseImageNaturalH!;
      final sanitizedObjects =
          _placedThemeObjects
              .where(
                (o) =>
                    (o['objectImageBase64'] ?? '').toString().trim().isNotEmpty,
              )
              .map((o) {
                double _finite(num? v, double fallback) {
                  final d = (v ?? fallback).toDouble();
                  return d.isFinite ? d : fallback;
                }

                double x = _finite(o['x'] as num?, 0.0);
                double y = _finite(o['y'] as num?, 0.0);
                double width = _finite(o['width'] as num?, 0.15);
                double height = _finite(o['height'] as num?, 0.15);

                final looksNormalized =
                    x <= 1.01 &&
                    y <= 1.01 &&
                    width <= 1.01 &&
                    height <= 1.01 &&
                    x >= -0.001 &&
                    y >= -0.001;
                if (looksNormalized) {
                  x *= iw;
                  y *= ih;
                  width *= iw;
                  height *= ih;
                } else {
                  if (width <= 1.0) width = 2.1;
                  if (height <= 1.0) height = 2.1;
                }
                if (width < 2.0) width = 2.0;
                if (height < 2.0) height = 2.0;
                final rotation = _finite(o['rotation'] as num?, 0.0);
                final intensity = _finite(
                  o['intensity'] as num?,
                  1.0,
                ).clamp(0.0, 1.0);
                final zIndex = (o['zIndex'] as num?)?.toInt() ?? 0;

                final targetHex = (o['targetHex'] ?? '').toString().trim();

                return {
                  'objectImageBase64':
                      (o['objectImageBase64'] ?? '').toString(),
                  'x': x,
                  'y': y,
                  'width': width,
                  'height': height,
                  'rotation': rotation,
                  'zIndex': zIndex,
                  'intensity': intensity,
                  'targetHex': targetHex.isEmpty ? null : targetHex,
                };
              })
              .toList();

      final baseBytes = await _resolveDesignPhotoBytes(_selectedBaseImage!);
      final response = await PublicEventsApi.instance.renderThemeComposite(
        baseImageBase64: base64Encode(baseBytes),
        objects: sanitizedObjects,
      );
      final imageBase64 = (response['imageBase64'] ?? '').toString().trim();
      if (imageBase64.isNotEmpty) {
        setState(() {
          _confirmedCompositeBase64 = imageBase64;
        });
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Render returned no image. Try again or adjust objects.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is Exception
                  ? e.toString().replaceFirst('Exception: ', '')
                  : 'Render failed. The server may be busy â€” try again in a moment.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isRenderingComposite = false);
    }
  }

  void _showThemeImageEnlargeDialog(
    BuildContext dialogContext,
    String imageUrl,
  ) {
    showDialog<void>(
      context: dialogContext,
      builder:
          (ctx) => Dialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 24,
            ),
            child: SizedBox(
              width: MediaQuery.of(ctx).size.width * 0.92,
              height: MediaQuery.of(ctx).size.height * 0.88,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: InteractiveViewer(
                      minScale: 0.5,
                      maxScale: 4,
                      child: Center(
                        child: _designImagePreview(
                          imageUrl,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: IconButton(
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black54,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  void _showDesignMyEventDialog() {
    _showDesignMyEventEditorPage();
  }

  Map<String, dynamic> _staffThemeStudioResult() {
    final photos =
        _designBoardPhotos().where((src) => src.trim().isNotEmpty).toList();
    return {
      'confirmedCompositeBase64':
          (_confirmedCompositeBase64 ?? '').trim().isEmpty
              ? null
              : _confirmedCompositeBase64!.trim(),
      'picksBase64': photos,
    };
  }

  void _finishStaffThemeStudio(BuildContext dialogContext) {
    final result = _staffThemeStudioResult();
    final navigator = Navigator.of(context);
    Navigator.of(dialogContext).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (navigator.canPop()) {
        navigator.pop(result);
      }
    });
  }

  Widget _buildPlacementEditor({
    required String baseImage,
    required List<Map<String, dynamic>> placedObjects,
    required List<Map<String, dynamic>> extractedObjects,
    required VoidCallback onChanged,
    double? editorWidth,
    double? editorMaxHeight,
  }) {
    final safeEditorWidth =
        (editorWidth != null && editorWidth.isFinite) ? editorWidth : null;
    final safeEditorMaxHeight =
        (editorMaxHeight != null &&
                editorMaxHeight.isFinite &&
                editorMaxHeight > 0)
            ? editorMaxHeight
            : null;
    final sourceCandidates =
        extractedObjects
            .where((o) => (o['objectImageBase64'] ?? '').toString().isNotEmpty)
            .toList();

    Widget dragCanvas(double width, double height) {
      final imgW = _baseImageNaturalW;
      final imgH = _baseImageNaturalH;
      final layoutReady = imgW != null && imgH != null && imgW > 0 && imgH > 0;
      final L =
          layoutReady
              ? _placementContainLayout(width, height, imgW, imgH)
              : null;

      return StatefulBuilder(
        builder: (context, setLocalState) {
          void notifyPlacementChanged() {
            setLocalState(() {});
            onChanged();
          }

          return DragTarget<Map<String, dynamic>>(
            onAcceptWithDetails: (details) {
              final lay = L;
              final iw = imgW;
              final ih = imgH;
              if (lay == null || iw == null || ih == null) return;

              final local1 = details.offset;
              final renderBox = context.findRenderObject() as RenderBox?;
              final local2 =
                  renderBox != null
                      ? renderBox.globalToLocal(details.offset)
                      : local1;

              final local1InBounds =
                  local1.dx >= 0 &&
                  local1.dx <= width &&
                  local1.dy >= 0 &&
                  local1.dy <= height;
              final local2InBounds =
                  local2.dx >= 0 &&
                  local2.dx <= width &&
                  local2.dy >= 0 &&
                  local2.dy <= height;

              final local =
                  local1InBounds ? local1 : (local2InBounds ? local2 : local1);

              const defaultCanvasPx = 120.0;
              final nw = (defaultCanvasPx / lay.dispW).clamp(0.02, 1.0);
              final nh = (defaultCanvasPx / lay.dispH).clamp(0.02, 1.0);
              final ix = (local.dx - lay.offX) / lay.scale;
              final iy = (local.dy - lay.offY) / lay.scale;
              final nx = (ix / iw).clamp(0.0, 1.0 - nw);
              final ny = (iy / ih).clamp(0.0, 1.0 - nh);

              _placedThemeObjects.add({
                'id': details.data['id'],
                'objectImageBase64':
                    (details.data['objectImageBase64'] ?? '').toString(),
                'x': nx,
                'y': ny,
                'width': nw,
                'height': nh,
                'rotation': 0.0,
                'zIndex': _placedThemeObjects.length,
                'targetHex': '#f4511e',
                'intensity': 1.0,
                '_checked': false,
              });
              _isPlacementSaved = false;
              notifyPlacementChanged();
            },
            builder: (context, _, __) {
              return Container(
                height: height,
                width: width,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    Positioned.fill(
                      child: _designImagePreview(
                        baseImage,
                        fit: BoxFit.contain,
                      ),
                    ),
                    if (!layoutReady)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircularProgressIndicator(),
                              const SizedBox(height: 12),
                              Text(
                                'Loading image layoutâ€¦',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ...placedObjects.asMap().entries.map((entry) {
                        final index = entry.key;
                        final obj = entry.value;
                        final color =
                            (obj['targetHex'] ?? '#f4511e').toString();
                        final isChecked = obj['_checked'] == true;
                        final lay = L!;

                        final nx = (obj['x'] as num?)?.toDouble() ?? 0.0;
                        final ny = (obj['y'] as num?)?.toDouble() ?? 0.0;
                        final nw = (obj['width'] as num?)?.toDouble() ?? 0.15;
                        final nh = (obj['height'] as num?)?.toDouble() ?? 0.15;

                        return Positioned(
                          left: lay.offX + nx * lay.dispW,
                          top: lay.offY + ny * lay.dispH,
                          child: GestureDetector(
                            onPanUpdate: (d) {
                              if (isChecked) return;
                              if ((obj['_isResizing'] ?? false) == true) return;
                              final onx = (obj['x'] as num?)?.toDouble() ?? 0.0;
                              final ony = (obj['y'] as num?)?.toDouble() ?? 0.0;
                              final ow =
                                  (obj['width'] as num?)?.toDouble() ?? 0.15;
                              final oh =
                                  (obj['height'] as num?)?.toDouble() ?? 0.15;
                              obj['x'] = (onx + d.delta.dx / lay.dispW).clamp(
                                0.0,
                                1.0 - ow,
                              );
                              obj['y'] = (ony + d.delta.dy / lay.dispH).clamp(
                                0.0,
                                1.0 - oh,
                              );
                              _isPlacementSaved = false;
                              notifyPlacementChanged();
                            },
                            onTap: () {
                              if (isChecked) return;
                              final palette = [
                                '#f4511e',
                                '#1db954',
                                '#1976d2',
                                '#e91e63',
                                '#6a1b9a',
                                '#ffc107',
                              ];
                              final current = palette.indexOf(
                                color.toLowerCase(),
                              );
                              obj['targetHex'] =
                                  palette[(current + 1) % palette.length];
                              _isPlacementSaved = false;
                              notifyPlacementChanged();
                            },
                            child: Container(
                              width: nw * lay.dispW,
                              height: nh * lay.dispH,
                              decoration: BoxDecoration(
                                border:
                                    isChecked
                                        ? null
                                        : Border.all(
                                          color: Colors.white,
                                          width: 2,
                                        ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.15),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: _designImagePreview(
                                      (obj['objectImageBase64'] ?? '')
                                          .toString(),
                                      fit: BoxFit.contain,
                                    ),
                                  ),

                                  // Resize handle (bottom-right).
                                  if (!isChecked)
                                    Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: GestureDetector(
                                        onPanStart: (_) {
                                          obj['_isResizing'] = true;
                                        },
                                        onPanUpdate: (d) {
                                          final objX =
                                              (obj['x'] as num?)?.toDouble() ??
                                              0;
                                          final objY =
                                              (obj['y'] as num?)?.toDouble() ??
                                              0;
                                          final objW =
                                              ((obj['width'] as num?)
                                                      ?.toDouble() ??
                                                  0.15);
                                          final objH =
                                              ((obj['height'] as num?)
                                                      ?.toDouble() ??
                                                  0.15);

                                          const minUserSize = 40.0;
                                          const minApiPix = 2.0;
                                          final minWn = math.max(
                                            minUserSize / lay.dispW,
                                            minApiPix / imgW,
                                          );
                                          final minHn = math.max(
                                            minUserSize / lay.dispH,
                                            minApiPix / imgH,
                                          );

                                          final maxWn = (1.0 - objX).clamp(
                                            minWn,
                                            1.0,
                                          );
                                          final maxHn = (1.0 - objY).clamp(
                                            minHn,
                                            1.0,
                                          );

                                          final nextW =
                                              objW + d.delta.dx / lay.dispW;
                                          final nextH =
                                              objH + d.delta.dy / lay.dispH;

                                          obj['width'] = nextW.clamp(
                                            minWn,
                                            maxWn,
                                          );
                                          obj['height'] = nextH.clamp(
                                            minHn,
                                            maxHn,
                                          );
                                          _isPlacementSaved = false;
                                          notifyPlacementChanged();
                                        },
                                        onPanEnd: (_) {
                                          obj['_isResizing'] = false;
                                          notifyPlacementChanged();
                                        },
                                        child: Container(
                                          width: 22,
                                          height: 22,
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(
                                              alpha: 0.95,
                                            ),
                                            border: Border.all(
                                              color: Colors.black54,
                                              width: 1,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.open_with,
                                            size: 14,
                                            color: Colors.black54,
                                          ),
                                        ),
                                      ),
                                    ),

                                  Positioned(
                                    left: 2,
                                    top: 2,
                                    child: GestureDetector(
                                      onTap: () {
                                        obj['_checked'] =
                                            !(obj['_checked'] == true);
                                        _isPlacementSaved = false;
                                        notifyPlacementChanged();
                                      },
                                      child: CircleAvatar(
                                        radius: 10,
                                        backgroundColor:
                                            isChecked
                                                ? const Color(0xFF2E7D32)
                                                : Colors.black54,
                                        child: Icon(
                                          isChecked
                                              ? Icons.check
                                              : Icons.check_box_outline_blank,
                                          size: 12,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (!isChecked)
                                    Positioned(
                                      right: 2,
                                      top: 2,
                                      child: GestureDetector(
                                        onTap: () {
                                          _placedThemeObjects.removeAt(index);
                                          _isPlacementSaved = false;
                                          notifyPlacementChanged();
                                        },
                                        child: const CircleAvatar(
                                          radius: 10,
                                          backgroundColor: Colors.red,
                                          child: Icon(
                                            Icons.close,
                                            size: 12,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              );
            },
          );
        },
      );
    }

    final strip = Row(
      children: [
        IconButton(
          tooltip: 'Scroll left',
          onPressed:
              sourceCandidates.isEmpty
                  ? null
                  : () {
                    if (!_objectsStripScrollCtrl.hasClients) return;
                    final target = (_objectsStripScrollCtrl.offset - 180).clamp(
                      0.0,
                      _objectsStripScrollCtrl.position.maxScrollExtent,
                    );
                    _objectsStripScrollCtrl.animateTo(
                      target,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                    );
                  },
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 108),
            child: Scrollbar(
              controller: _objectsStripScrollCtrl,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _objectsStripScrollCtrl,
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children:
                      sourceCandidates.map((obj) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8, bottom: 4),
                          child: Draggable<Map<String, dynamic>>(
                            data: obj,
                            feedback: SizedBox(
                              width: 80,
                              height: 80,
                              child: _designImagePreview(
                                (obj['objectImageBase64'] ?? '').toString(),
                                fit: BoxFit.contain,
                              ),
                            ),
                            childWhenDragging: Opacity(
                              opacity: 0.3,
                              child: SizedBox(
                                width: 72,
                                height: 72,
                                child: _designImagePreview(
                                  (obj['objectImageBase64'] ?? '').toString(),
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                            child: SizedBox(
                              width: 72,
                              height: 72,
                              child: _designImagePreview(
                                (obj['objectImageBase64'] ?? '').toString(),
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                ),
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: 'Scroll right',
          onPressed:
              sourceCandidates.isEmpty
                  ? null
                  : () {
                    if (!_objectsStripScrollCtrl.hasClients) return;
                    final target = (_objectsStripScrollCtrl.offset + 180).clamp(
                      0.0,
                      _objectsStripScrollCtrl.position.maxScrollExtent,
                    );
                    _objectsStripScrollCtrl.animateTo(
                      target,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                    );
                  },
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );

    if (safeEditorMaxHeight != null) {
      return SizedBox(
        width: safeEditorWidth,
        height: safeEditorMaxHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Drag objects onto base image',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (placedObjects.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  _isPlacementSaved
                      ? 'Placement saved. Checked objects are locked for a clear preview.'
                      : 'Tip: tap each object check button to lock it, then click Save Placement.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ),
            if (sourceCandidates.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  'Use Extract Objects on the left to load cutouts.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              )
            else
              strip,
            const SizedBox(height: 8),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final w = editorWidth ?? constraints.maxWidth;
                  final h = constraints.maxHeight;
                  return dragCanvas(w, h);
                },
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Drag objects onto base image',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (sourceCandidates.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              'Use Extract Objects on the left to load cutouts.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          )
        else
          strip,
        const SizedBox(height: 10),
        if (placedObjects.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              _isPlacementSaved
                  ? 'Placement saved. Checked objects are locked for a clear preview.'
                  : 'Tip: tap each object check button to lock it, then click Save Placement.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          ),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = editorWidth ?? constraints.maxWidth;
            return dragCanvas(width, 420);
          },
        ),
      ],
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 10,
        ),
      ),
      style: const TextStyle(fontSize: 13),
    );
  }

  Widget _buildDropdown(
    String label,
    String value,
    List<String> options,
    Function(String) onChanged, {
    Map<String, String>? displayMap,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 10,
        ),
      ),
      items:
          options
              .map(
                (o) => DropdownMenuItem(
                  value: o,
                  child: Text(
                    displayMap?[o] ?? o,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              )
              .toList(),
      onChanged: (v) => onChanged(v!),
    );
  }

  String? _normalizeBase64Payload(String value) {
    final raw = value.trim();
    if (raw.isEmpty) return null;
    final payload =
        raw.startsWith('data:image/')
            ? raw.substring(raw.indexOf(',') + 1)
            : raw;
    final compact = payload.replaceAll(RegExp(r'\s+'), '');
    if (compact.isEmpty) return null;
    if (!RegExp(r'^[A-Za-z0-9+/_=-]+$').hasMatch(compact)) return null;
    final normalized = compact.replaceAll('-', '+').replaceAll('_', '/');
    final mod = normalized.length % 4;
    if (mod == 0) return normalized;
    return '$normalized${'=' * (4 - mod)}';
  }

  bool _looksLikeBase64Image(String value) {
    final t = value.trim().toLowerCase();
    if (t.startsWith('http://') || t.startsWith('https://')) return false;
    return _normalizeBase64Payload(value) != null;
  }

  Widget _designImagePreview(String value, {BoxFit fit = BoxFit.cover}) {
    final trimmed = value.trim();
    if (_looksLikeBase64Image(trimmed)) {
      try {
        final payload = _normalizeBase64Payload(trimmed);
        if (payload == null) {
          return const Center(
            child: Icon(Icons.broken_image, color: Colors.grey),
          );
        }
        final bytes = _base64DecodeCache.putIfAbsent(
          payload,
          () => base64Decode(payload),
        );
        return Image.memory(
          bytes,
          fit: fit,
          errorBuilder:
              (ctx, err, stack) => const Center(
                child: Icon(Icons.broken_image, color: Colors.grey),
              ),
        );
      } catch (_) {
        return const Center(
          child: Icon(Icons.broken_image, color: Colors.grey),
        );
      }
    }
    return Image.network(
      trimmed,
      fit: fit,
      errorBuilder:
          (ctx, err, stack) =>
              const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
    );
  }

  bool _isLikelyDesignBoardAsset(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) return true;
    if (_looksLikeBase64Image(normalized)) return false;
    return normalized.contains('logo') ||
        normalized.contains('favicon') ||
        normalized.contains('icon') ||
        normalized.contains('brand') ||
        normalized.contains('/assets/') ||
        normalized.contains('\\assets\\');
  }

  List<String> _designBoardPhotos() {
    return _designPhotoUrls
        .where((photo) => !_isLikelyDesignBoardAsset(photo))
        .toList();
  }

  Future<Uint8List> _resolveDesignPhotoBytes(String value) async {
    final trimmed = value.trim();
    if (_looksLikeBase64Image(trimmed)) {
      final payload = _normalizeBase64Payload(trimmed);
      if (payload == null) {
        throw Exception('Invalid base64 image payload');
      }
      return base64Decode(payload);
    }
    final uri = Uri.tryParse(trimmed);
    if (uri == null) {
      throw Exception('Invalid design photo source');
    }
    final response = await http.get(uri).timeout(_aiRequestTimeout);
    if (response.statusCode != 200) {
      throw Exception('Failed to download selected design photo');
    }
    return response.bodyBytes;
  }

  Future<void> _openExternalLink(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _cacheBaseImageNaturalSize() async {
    final src = _selectedBaseImage;
    if (src == null || src.trim().isEmpty) {
      if (mounted) {
        setState(() {
          _baseImageNaturalW = null;
          _baseImageNaturalH = null;
        });
      }
      return;
    }
    try {
      final bytes = await _resolveDesignPhotoBytes(src);
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final w = frame.image.width.toDouble();
      final h = frame.image.height.toDouble();
      frame.image.dispose();
      if (!mounted) return;
      setState(() {
        _baseImageNaturalW = w;
        _baseImageNaturalH = h;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _baseImageNaturalW = null;
          _baseImageNaturalH = null;
        });
      }
    }
  }

  Future<void> _runCustomerEditObjectsFlow(
    void Function(void Function()) setDialogState,
  ) async {
    final photos = _designBoardPhotos();
    if (photos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add at least one design board photo first.'),
        ),
      );
      return;
    }
    final focusedIndex = (_focusedPhotoIndex ?? 0).clamp(0, photos.length - 1);
    final source = photos[focusedIndex];
    setState(() => _isDetectingAiObjects = true);
    try {
      final bytes = await _resolveDesignPhotoBytes(source);
      final imageBase64 = base64Encode(bytes);
      final segmented = await PublicEventsApi.instance
          .inferThemeObjectsWithSam(
            imageBase64: imageBase64,
            maxDetections: 20,
            maskFormat: 'polygon',
          )
          .timeout(_aiRequestTimeout);
      final objects =
          (segmented['objects'] as List<dynamic>? ?? const [])
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
      if (objects.isEmpty) {
        throw Exception('No objects detected to edit.');
      }

      final grouped = <String, List<Map<String, dynamic>>>{};
      for (final obj in objects) {
        final label = (obj['label'] ?? 'Object').toString();
        grouped.putIfAbsent(label, () => <Map<String, dynamic>>[]).add(obj);
      }

      final selection = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) {
          String? selectedLabel;
          String selectedHex = '#F4511E';
          double selectedAlpha = 1.0;
          const palette = <String>[
            '#F4511E',
            '#1DB954',
            '#1976D2',
            '#E91E63',
            '#6A1B9A',
            '#FFC107',
            '#FFFFFF',
            '#212121',
          ];
          return StatefulBuilder(
            builder: (context, setLocalState) {
              return Dialog(
                backgroundColor: const Color(0xFFF7F8FA),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Container(
                  width: 1160,
                  height: 760,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Object Selection',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFF4511E),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              flex: 3,
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                  color: Colors.black12,
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      final w = constraints.maxWidth;
                                      final h = constraints.maxHeight;
                                      return Stack(
                                        children: [
                                          Positioned.fill(
                                            child: Image.memory(
                                              bytes,
                                              fit: BoxFit.contain,
                                            ),
                                          ),
                                          ...objects.map((obj) {
                                            final boxRaw =
                                                Map<String, dynamic>.from(
                                                  (obj['boundingBox']
                                                          as Map?) ??
                                                      const <String, dynamic>{},
                                                );
                                            final leftRaw =
                                                (boxRaw['left'] as num?)
                                                    ?.toDouble() ??
                                                0;
                                            final topRaw =
                                                (boxRaw['top'] as num?)
                                                    ?.toDouble() ??
                                                0;
                                            final widthRaw =
                                                (boxRaw['width'] as num?)
                                                    ?.toDouble() ??
                                                0.2;
                                            final heightRaw =
                                                (boxRaw['height'] as num?)
                                                    ?.toDouble() ??
                                                0.2;
                                            final isNormalized =
                                                widthRaw <= 1.0 &&
                                                heightRaw <= 1.0;
                                            final left =
                                                isNormalized
                                                    ? leftRaw * w
                                                    : leftRaw;
                                            final top =
                                                isNormalized
                                                    ? topRaw * h
                                                    : topRaw;
                                            final width =
                                                isNormalized
                                                    ? widthRaw * w
                                                    : widthRaw;
                                            final height =
                                                isNormalized
                                                    ? heightRaw * h
                                                    : heightRaw;
                                            final active =
                                                selectedLabel ==
                                                (obj['label'] ?? 'Object')
                                                    .toString();
                                            return Positioned(
                                              left: left,
                                              top: top,
                                              width: width,
                                              height: height,
                                              child: GestureDetector(
                                                onTap:
                                                    () => setLocalState(
                                                      () =>
                                                          selectedLabel =
                                                              (obj['label'] ??
                                                                      'Object')
                                                                  .toString(),
                                                    ),
                                                child: CustomPaint(
                                                  painter:
                                                      _SoftCustomerOverlayPainter(
                                                        polygonPoints:
                                                            const <
                                                              Map<
                                                                String,
                                                                dynamic
                                                              >
                                                            >[],
                                                        boundingBox:
                                                            Rect.fromLTWH(
                                                              0,
                                                              0,
                                                              width,
                                                              height,
                                                            ),
                                                        selected: active,
                                                      ),
                                                ),
                                              ),
                                            );
                                          }),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            SizedBox(
                              width: 340,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      border: Border.all(
                                        color: Colors.grey.shade300,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Recolor',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children:
                                              palette.map((hex) {
                                                final color = Color(
                                                  int.parse(
                                                        hex.substring(1),
                                                        radix: 16,
                                                      ) +
                                                      0xFF000000,
                                                );
                                                final selected =
                                                    selectedHex == hex;
                                                return GestureDetector(
                                                  onTap:
                                                      () => setLocalState(
                                                        () => selectedHex = hex,
                                                      ),
                                                  child: Container(
                                                    width: 30,
                                                    height: 30,
                                                    decoration: BoxDecoration(
                                                      color: color,
                                                      shape: BoxShape.circle,
                                                      border: Border.all(
                                                        color:
                                                            selected
                                                                ? Colors.black
                                                                : Colors
                                                                    .black26,
                                                        width: selected ? 3 : 1,
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              }).toList(),
                                        ),
                                        const SizedBox(height: 12),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Alpha: ${(selectedAlpha * 100).round()}%',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Slider(
                                              value: selectedAlpha,
                                              min: 0.0,
                                              max: 1.0,
                                              divisions: 20,
                                              activeColor: Color(
                                                int.parse(
                                                      selectedHex.substring(1),
                                                      radix: 16,
                                                    ) +
                                                    0xFF000000,
                                              ),
                                              onChanged:
                                                  (value) => setLocalState(
                                                    () => selectedAlpha = value,
                                                  ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Container(
                                          width: double.infinity,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: Color(
                                              int.parse(
                                                    selectedHex.substring(1),
                                                    radix: 16,
                                                  ) +
                                                  (selectedAlpha * 255)
                                                          .round() *
                                                      0x1000000,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                            border: Border.all(
                                              color: Colors.grey.shade400,
                                            ),
                                          ),
                                          child: Center(
                                            child: Text(
                                              'Preview',
                                              style: TextStyle(
                                                color:
                                                    selectedAlpha > 0.5
                                                        ? Colors.white
                                                        : Colors.black,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Spacer(),
                                  Container(
                                    height: 220,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      border: Border.all(
                                        color: Colors.grey.shade300,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Detected Objects:',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Expanded(
                                          child: SingleChildScrollView(
                                            child: Wrap(
                                              spacing: 8,
                                              runSpacing: 8,
                                              children:
                                                  grouped.entries.map((entry) {
                                                    final label =
                                                        entry.value.length > 1
                                                            ? '${entry.key} (${entry.value.length})'
                                                            : entry.key;
                                                    final active =
                                                        selectedLabel ==
                                                        entry.key;
                                                    return FilterChip(
                                                      label: Text(label),
                                                      selected: active,
                                                      onSelected:
                                                          (_) =>
                                                              setLocalState(() {
                                                                selectedLabel =
                                                                    entry.key;
                                                              }),
                                                      backgroundColor:
                                                          Colors.grey.shade200,
                                                      selectedColor: Colors.blue
                                                          .withValues(
                                                            alpha: 0.3,
                                                          ),
                                                      checkmarkColor:
                                                          Colors.blue,
                                                    );
                                                  }).toList(),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  ElevatedButton(
                                    onPressed:
                                        selectedLabel == null
                                            ? null
                                            : () => Navigator.of(context).pop({
                                              'label': selectedLabel!,
                                              'hex': selectedHex,
                                              'alpha': selectedAlpha,
                                            }),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF1DB954),
                                      foregroundColor: Colors.white,
                                    ),
                                    child: const Text(
                                      'Apply Colors to Selected',
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ElevatedButton(
                                    onPressed:
                                        () => Navigator.of(context).pop(),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.grey.shade400,
                                      foregroundColor: Colors.white,
                                    ),
                                    child: const Text('Cancel'),
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
              );
            },
          );
        },
      );
      if (selection == null) return;
      final selectedLabel = selection['label'];
      final targetHex = selection['hex'];
      final targetAlpha = selection['alpha'] as double? ?? 1.0;
      if (selectedLabel == null || targetHex == null) return;

      final selectedObjects =
          grouped[selectedLabel] ?? const <Map<String, dynamic>>[];
      final masks =
          selectedObjects.map((obj) {
            final rawPolygon =
                (obj['polygonPoints'] as List<dynamic>? ??
                        obj['polygon_points'] as List<dynamic>? ??
                        const [])
                    .toList();
            final polygon =
                rawPolygon
                    .map((point) {
                      if (point is Map) {
                        return {
                          'x': (point['x'] as num?)?.toDouble() ?? 0.0,
                          'y': (point['y'] as num?)?.toDouble() ?? 0.0,
                        };
                      }
                      if (point is List && point.length >= 2) {
                        final x = point[0];
                        final y = point[1];
                        if (x is num && y is num) {
                          return {'x': x.toDouble(), 'y': y.toDouble()};
                        }
                      }
                      return null;
                    })
                    .whereType<Map<String, double>>()
                    .toList();
            final maskBase64 =
                (obj['maskBase64'] ?? obj['mask_base64'] ?? '')
                    .toString()
                    .trim();
            return {
              'objectId': (obj['id'] ?? '').toString(),
              if (polygon.isNotEmpty) 'polygonPoints': polygon,
              if (maskBase64.isNotEmpty) 'maskBase64': maskBase64,
            };
          }).toList();
      final edits =
          selectedObjects
              .map(
                (obj) => {
                  'objectId': (obj['id'] ?? '').toString(),
                  'targetHex': targetHex,
                  'intensity': targetAlpha,
                },
              )
              .toList();

      final recolor = await PublicEventsApi.instance
          .swapThemeObjectColors(
            imageBase64: imageBase64,
            masks: masks,
            edits: edits,
          )
          .timeout(_aiRequestTimeout);
      final recoloredBase64 = (recolor['imageBase64'] ?? '').toString().trim();
      if (recoloredBase64.isEmpty) {
        throw Exception('AI recolor did not return an image.');
      }

      setDialogState(() {
        final existingIndex = _designPhotoUrls.indexOf(source);
        if (existingIndex >= 0) {
          // Replace the original with the edited version to avoid duplicate previews.
          _designPhotoUrls[existingIndex] = recoloredBase64;
          _focusedPhotoIndex = existingIndex;
        } else {
          _designPhotoUrls.add(recoloredBase64);
          _focusedPhotoIndex = _designPhotoUrls.length - 1;
        }
      });
      setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('AI edit applied.')));
      }
    } catch (e) {
      final msg = e.toString().toLowerCase();
      final timeout =
          msg.contains('timeout') ||
          msg.contains('timed out') ||
          msg.contains('upstream_timeout');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              timeout
                  ? 'AI service timed out. Please try one clear image and retry.'
                  : 'Failed to edit objects: $e',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDetectingAiObjects = false);
    }
  }

  void _showCustomDesignDialog() {
    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setDialogState) {
              final designBoardPhotos = _designBoardPhotos();
              final screenWidth = MediaQuery.of(context).size.width;
              final isNarrow = screenWidth < 720;
              final dialogWidth = isNarrow ? screenWidth * 0.92 : 620.0;
              final previewHeight = isNarrow ? 160.0 : 200.0;
              final thumbSize = isNarrow ? 64.0 : 80.0;
              final thumbStripHeight = isNarrow ? 64.0 : 80.0;
              return AlertDialog(
                backgroundColor: const Color(0xFFF7F8FA),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                title: Row(
                  children: const [
                    Icon(Icons.palette_outlined, color: Color(0xFFF4511E)),
                    SizedBox(width: 8),
                    Text('Events Theme Design'),
                  ],
                ),
                content: SizedBox(
                  width: dialogWidth,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.black.withValues(alpha: 0.08),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 14,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF3D0),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text(
                                  'AI EDIT TOOLS',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                    color: Color(0xFF7A4E00),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Flow: EDIT OBJECTS -> choose grouped object -> pick color -> apply.',
                                style: TextStyle(fontSize: 12),
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed:
                                      _isDetectingAiObjects
                                          ? null
                                          : () => _runCustomerEditObjectsFlow(
                                            setDialogState,
                                          ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFF4511E),
                                    foregroundColor: Colors.white,
                                  ),
                                  child:
                                      _isDetectingAiObjects
                                          ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                    Colors.white,
                                                  ),
                                            ),
                                          )
                                          : const Text('EDIT OBJECTS'),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.black.withValues(alpha: 0.08),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Add reference photos (upload or URL).:',
                                style: TextStyle(fontSize: 13),
                              ),
                              const SizedBox(height: 10),
                              if (isNarrow)
                                Column(
                                  children: [
                                    TextField(
                                      controller: _designPhotoCtrl,
                                      decoration: const InputDecoration(
                                        labelText: 'Photo URL',
                                        hintText: 'Paste image link here...',
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      width: double.infinity,
                                      child: Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          ElevatedButton(
                                            onPressed: () async {
                                              final picked = await ImagePicker()
                                                  .pickImage(
                                                    source: ImageSource.gallery,
                                                  );
                                              if (picked == null) return;
                                              final bytes =
                                                  await picked.readAsBytes();
                                              final encoded = base64Encode(
                                                bytes,
                                              );
                                              setDialogState(() {
                                                _designPhotoUrls.add(encoded);
                                                _focusedPhotoIndex =
                                                    _designPhotoUrls.length - 1;
                                              });
                                              setState(() {});
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(
                                                0xFF1976D2,
                                              ),
                                              foregroundColor: Colors.white,
                                            ),
                                            child: const Text('Upload Photo'),
                                          ),
                                          ElevatedButton(
                                            onPressed: () {
                                              final input =
                                                  _designPhotoCtrl.text.trim();
                                              if (input.isEmpty) return;
                                              if (_isLikelyDesignBoardAsset(
                                                input,
                                              )) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'Logo/asset links are not added to the design board. Please use event inspiration photos.',
                                                    ),
                                                  ),
                                                );
                                                return;
                                              }
                                              setDialogState(() {
                                                _designPhotoUrls.add(input);
                                                _designPhotoCtrl.clear();
                                              });
                                              setState(() {});
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(
                                                0xFFFFC024,
                                              ),
                                              foregroundColor: Colors.black87,
                                            ),
                                            child: const Text('Add URL'),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                )
                              else
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _designPhotoCtrl,
                                        decoration: const InputDecoration(
                                          labelText: 'Photo URL',
                                          hintText: 'Paste image link here...',
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      onPressed: () async {
                                        final picked = await ImagePicker()
                                            .pickImage(
                                              source: ImageSource.gallery,
                                            );
                                        if (picked == null) return;
                                        final bytes =
                                            await picked.readAsBytes();
                                        final encoded = base64Encode(bytes);
                                        setDialogState(() {
                                          _designPhotoUrls.add(encoded);
                                          _focusedPhotoIndex =
                                              _designPhotoUrls.length - 1;
                                        });
                                        setState(() {});
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF1976D2,
                                        ),
                                        foregroundColor: Colors.white,
                                      ),
                                      child: const Text('Upload Photo'),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      onPressed: () {
                                        final input =
                                            _designPhotoCtrl.text.trim();
                                        if (input.isEmpty) return;
                                        if (_isLikelyDesignBoardAsset(input)) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Logo/asset links are not added to the design board. Please use event inspiration photos.',
                                              ),
                                            ),
                                          );
                                          return;
                                        }
                                        setDialogState(() {
                                          _designPhotoUrls.add(input);
                                          _designPhotoCtrl.clear();
                                        });
                                        setState(() {});
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFFFFC024,
                                        ),
                                        foregroundColor: Colors.black87,
                                      ),
                                      child: const Text('Add URL'),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF3D0),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${designBoardPhotos.length} design board photo(s)',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Color(0xFF7A4E00),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (designBoardPhotos.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            height: previewHeight,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: _designImagePreview(
                                _focusedPhotoIndex != null &&
                                        _focusedPhotoIndex! <
                                            designBoardPhotos.length
                                    ? designBoardPhotos[_focusedPhotoIndex!]
                                    : designBoardPhotos.first,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: thumbStripHeight,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: designBoardPhotos.length,
                              itemBuilder: (ctx, index) {
                                final isFocused =
                                    _focusedPhotoIndex == index ||
                                    (_focusedPhotoIndex == null && index == 0);
                                return GestureDetector(
                                  onTap: () {
                                    setDialogState(() {
                                      _focusedPhotoIndex = index;
                                    });
                                  },
                                  child: Container(
                                    width: thumbSize,
                                    margin: const EdgeInsets.only(right: 8),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color:
                                            isFocused
                                                ? const Color(0xFFFFC024)
                                                : Colors.grey.shade300,
                                        width: isFocused ? 3 : 1,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          _designImagePreview(
                                            designBoardPhotos[index],
                                            fit: BoxFit.cover,
                                          ),
                                          Positioned(
                                            top: 2,
                                            right: 2,
                                            child: GestureDetector(
                                              onTap: () {
                                                final photoToRemove =
                                                    designBoardPhotos[index];
                                                setDialogState(() {
                                                  _designPhotoUrls.remove(
                                                    photoToRemove,
                                                  );
                                                  if (_focusedPhotoIndex !=
                                                          null &&
                                                      _focusedPhotoIndex! >=
                                                          index) {
                                                    _focusedPhotoIndex =
                                                        _focusedPhotoIndex! > 0
                                                            ? _focusedPhotoIndex! -
                                                                1
                                                            : null;
                                                  }
                                                });
                                                setState(() {});
                                              },
                                              child: Container(
                                                padding: const EdgeInsets.all(
                                                  2,
                                                ),
                                                decoration: const BoxDecoration(
                                                  color: Colors.red,
                                                  shape: BoxShape.circle,
                                                ),
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
                                );
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                actions: [
                  SizedBox(
                    width: 140,
                    child: ElevatedButton(
                      onPressed:
                          widget.staffThemeStudioMode
                              ? () => _finishStaffThemeStudio(context)
                              : () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1DB954),
                        foregroundColor: Colors.white,
                      ),
                      child: Text(
                        widget.staffThemeStudioMode ? 'USE DESIGN' : 'DONE',
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 140,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade400,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('CANCEL'),
                    ),
                  ),
                ],
              );
            },
          ),
    );
  }
}
