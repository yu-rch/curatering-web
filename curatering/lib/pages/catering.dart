import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:printing/printing.dart';
import '../auth/action_permissions.dart';
import '../auth/auth_session.dart';
import '../config.dart';
import '../auth/roles.dart';
import '../features/event_design/event_theme_design_screen.dart';
import '../models/event_order.dart';
import '../models/menu_dish.dart';
import '../services/api_client.dart';
import '../services/events_api.dart';
import '../services/menu_store.dart';
import '../services/order_summary_pdf_service.dart';
import '../services/checklist_pdf_service.dart';
import '../services/set_menu_store.dart';
import '../widgets/allergen_selector_field.dart';
import '../widgets/antd_buttons.dart';
import '../widgets/antd_descriptions.dart';
import '../widgets/antd_dialog.dart';
import '../widgets/antd_tokens.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/paginated_data_table.dart';
import '../widgets/map_picker.dart';
import '../widgets/processing_seating_section.dart';
import '../utils/order_calculations.dart';
import '../utils/order_type_utils.dart';
import '../utils/web_html.dart' as html;

part 'catering_manage_events_part.dart';
// import 'package:segment_anything/segment_anything.dart';

/// Reuse Manage Events order lists briefly so leaving and returning the page
/// does not always show a full reload.
class ManageEventsOrdersCache {
  ManageEventsOrdersCache._();
  static final ManageEventsOrdersCache instance = ManageEventsOrdersCache._();

  Role? _role;
  DateTime? _fetchedAt;
  List<EventOrderDto> _onlineInquiries = const [];
  List<EventOrderDto> _processing = const [];
  List<EventOrderDto> _postAnalysis = const [];
  List<EventOrderDto> _completed = const [];

  static const Duration _ttl = Duration(minutes: 5);

  void clear() {
    _fetchedAt = null;
    _role = null;
    _onlineInquiries = const [];
    _processing = const [];
    _postAnalysis = const [];
    _completed = const [];
  }

  bool tryRestore({
    required Role? role,
    required void Function({
      required List<EventOrderDto> onlineInquiries,
      required List<EventOrderDto> processing,
      required List<EventOrderDto> postAnalysis,
      required List<EventOrderDto> completed,
    })
    onData,
  }) {
    if (_fetchedAt == null || _role != role) return false;
    if (DateTime.now().difference(_fetchedAt!) > _ttl) return false;
    onData(
      onlineInquiries: List<EventOrderDto>.from(_onlineInquiries),
      processing: List<EventOrderDto>.from(_processing),
      postAnalysis: List<EventOrderDto>.from(_postAnalysis),
      completed: List<EventOrderDto>.from(_completed),
    );
    return true;
  }

  void save({
    required Role? role,
    required List<EventOrderDto> onlineInquiries,
    required List<EventOrderDto> processing,
    required List<EventOrderDto> postAnalysis,
    required List<EventOrderDto> completed,
  }) {
    _role = role;
    _fetchedAt = DateTime.now();
    _onlineInquiries = List<EventOrderDto>.unmodifiable(onlineInquiries);
    _processing = List<EventOrderDto>.unmodifiable(processing);
    _postAnalysis = List<EventOrderDto>.unmodifiable(postAnalysis);
    _completed = List<EventOrderDto>.unmodifiable(completed);
  }
}

// SAM Segmentation Classes (existing)
class SegmentedObject {
  final String id;
  final Uint8List mask;
  final String label;
  final Rect boundingBox;
  final List<Offset> polygonPoints;
  final Color? currentColor;

  SegmentedObject({
    required this.id,
    required this.mask,
    required this.label,
    required this.boundingBox,
    this.polygonPoints = const <Offset>[],
    this.currentColor,
  });
}

class SamSegmentationResult {
  final List<SegmentedObject> objects;
  final Uint8List previewImage;

  SamSegmentationResult({required this.objects, required this.previewImage});
}

class _SoftObjectOverlay extends StatelessWidget {
  const _SoftObjectOverlay({required this.object, required this.isSelected});

  final SegmentedObject object;
  final bool isSelected;

  Path _shapePath(Size size) {
    if (object.polygonPoints.length >= 3) {
      final path = Path();
      final first = object.polygonPoints.first;
      path.moveTo(first.dx * size.width, first.dy * size.height);
      for (final pt in object.polygonPoints.skip(1)) {
        path.lineTo(pt.dx * size.width, pt.dy * size.height);
      }
      path.close();
      return path;
    }
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        object.boundingBox.left,
        object.boundingBox.top,
        object.boundingBox.width,
        object.boundingBox.height,
      ),
      const Radius.circular(10),
    );
    return Path()..addRRect(rrect);
  }

  @override
  Widget build(BuildContext context) {
    final strokeColor =
        isSelected ? Colors.blue : Colors.red.withValues(alpha: 0.75);
    final fillColor =
        isSelected
            ? Colors.blue.withValues(alpha: 0.20)
            : Colors.red.withValues(alpha: 0.06);
    return CustomPaint(
      size: Size.infinite,
      painter: _SoftObjectOverlayPainter(
        pathBuilder: _shapePath,
        strokeColor: strokeColor,
        fillColor: fillColor,
      ),
    );
  }
}

class _SoftObjectOverlayPainter extends CustomPainter {
  _SoftObjectOverlayPainter({
    required this.pathBuilder,
    required this.strokeColor,
    required this.fillColor,
  });

  final Path Function(Size size) pathBuilder;
  final Color strokeColor;
  final Color fillColor;

  @override
  void paint(Canvas canvas, Size size) {
    final path = pathBuilder(size);
    final fill =
        Paint()
          ..color = fillColor
          ..style = PaintingStyle.fill;
    final stroke =
        Paint()
          ..color = strokeColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;
    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(covariant _SoftObjectOverlayPainter oldDelegate) {
    return strokeColor != oldDelegate.strokeColor ||
        fillColor != oldDelegate.fillColor;
  }
}

class ChecklistItem {
  ChecklistItem({
    required this.item,
    required this.description,
    required this.quantity,
    required this.cost,
    this.isCompleted = false,
    this.inventoryId,
  });

  final String item;
  final String description;
  final int quantity;
  final double cost;
  bool isCompleted;
  final String? inventoryId;
}

enum EventStatus {
  newEvent,
  onlineInquiries,
  forDownpayment,
  ongoing,
  forFullPayment,
  completed,
}

enum PaymentConfirmationMode { downpayment, fullPayment }

enum DownpaymentAmountOption { percent50, custom, fullPayment }

enum FullPaymentAmountOption { remainingBalance, fullTotal, custom }

enum DownPaymentType {
  none,
  fiftyPercent,
  seventyFivePercent,
  fullPayment,
  custom;

  String get displayName {
    switch (this) {
      case DownPaymentType.none:
        return 'No Downpayment';
      case DownPaymentType.fiftyPercent:
        return '50% Downpayment';
      case DownPaymentType.seventyFivePercent:
        return '75% Downpayment';
      case DownPaymentType.fullPayment:
        return 'Full Payment';
      case DownPaymentType.custom:
        return 'Custom Downpayment';
    }
  }

  double get percentage {
    switch (this) {
      case DownPaymentType.none:
        return 0.0;
      case DownPaymentType.fiftyPercent:
        return 0.5;
      case DownPaymentType.seventyFivePercent:
        return 0.75;
      case DownPaymentType.fullPayment:
        return 1.0;
      case DownPaymentType.custom:
        return 0.5; // Default to 50% for custom
    }
  }
}

enum PaymentService {
  cash,
  bankTransfer,
  ccdebitCard,
  ewallet,
  cheque;

  String get displayName {
    switch (this) {
      case PaymentService.cash:
        return 'Cash';
      case PaymentService.bankTransfer:
        return 'Bank Transfer';
      case PaymentService.ccdebitCard:
        return 'Debit/Credit Card';
      case PaymentService.ewallet:
        return 'E-wallet';
      case PaymentService.cheque:
        return 'Cheque';
    }
  }

  String get apiValue {
    switch (this) {
      case PaymentService.cash:
        return 'cash';
      case PaymentService.bankTransfer:
        return 'bank_transfer';
      case PaymentService.ccdebitCard:
        return 'debit_credit_card';
      case PaymentService.ewallet:
        return 'e_wallet';
      case PaymentService.cheque:
        return 'cheque';
    }
  }

  int? get referenceDigitLength {
    switch (this) {
      case PaymentService.bankTransfer:
        return 18;
      case PaymentService.ccdebitCard:
        return 23;
      case PaymentService.ewallet:
        return 13;
      case PaymentService.cash:
      case PaymentService.cheque:
        return null;
    }
  }
}

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
  final TextEditingController _eventSearchController = TextEditingController();
  final TextEditingController _inquirySearchController =
      TextEditingController();
  final TextEditingController _foodSearchController = TextEditingController();
  TabController? _foodTabController;
  final TextEditingController _eventTitleController = TextEditingController();
  final TextEditingController _customerController = TextEditingController();
  final TextEditingController _contactPersonController =
      TextEditingController();
  final TextEditingController _contactNumberController =
      TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _eventAddressController = TextEditingController();
  final TextEditingController _guestCountController = TextEditingController();

  EventStatus _selectedStatus = EventStatus.newEvent;
  String? _eventType;
  EventFormalityLevel? _formalityLevel;
  String? _orderType; // 'catering' or 'catering_event'
  String _inquiryServiceTypeFilter = '';
  String _inquiryEventTypeFilter = '';
  String _inquiryDateFilter = '';
  String _eventTableServiceTypeFilter = '';
  String _eventTableEventTypeFilter = '';
  String _eventTableDateFilter = '';
  final List<EventScheduleSlot> _eventScheduleSlots = [];

  bool _ordersLoading = false;
  bool _isSubmittingOrder = false; // Loading state for form submission
  List<EventOrderDto> _onlineInquiryOrders = const <EventOrderDto>[];
  List<EventOrderDto> _processingOrdersDto = const <EventOrderDto>[];
  List<EventOrderDto> _postAnalysisOrdersDto = const <EventOrderDto>[];
  List<EventOrderDto> _completedOrdersDto = const <EventOrderDto>[];
  EventOrderDto? _selectedOnlineInquiryOrder;
  Role? _lastLoadedRole;

  @override
  void initState() {
    super.initState();
    _allDishes = MenuStore.instance.activeDishes;
    MenuStore.instance.addListener(_onMenuStoreChanged);
    SetMenuStore.instance.loadSetMenus();
    _foodTabController = TabController(length: 2, vsync: this);
    _loadThemeTemplates();
    AuthSession.instance.currentUser.addListener(_handleAuthSessionChange);
    final role = AuthSession.instance.currentRole;
    if (role == Role.supervisor) {
      _selectedStatus = EventStatus.ongoing;
    }
    final restored = ManageEventsOrdersCache.instance.tryRestore(
      role: role,
      onData: ({
        required List<EventOrderDto> onlineInquiries,
        required List<EventOrderDto> processing,
        required List<EventOrderDto> postAnalysis,
        required List<EventOrderDto> completed,
      }) {
        if (!mounted) return;
        setState(() {
          _onlineInquiryOrders = onlineInquiries;
          _processingOrdersDto = processing;
          _postAnalysisOrdersDto = postAnalysis;
          _completedOrdersDto = completed;
          _lastLoadedRole = role;
        });
      },
    );
    if (!restored) {
      _refreshOrders();
    }
  }

  @override
  void dispose() {
    AuthSession.instance.currentUser.removeListener(_handleAuthSessionChange);
    MenuStore.instance.removeListener(_onMenuStoreChanged);
    _eventSearchController.dispose();
    _inquirySearchController.dispose();
    _eventTitleController.dispose();
    _customerController.dispose();
    _contactPersonController.dispose();
    _contactNumberController.dispose();
    _emailController.dispose();
    _eventAddressController.dispose();
    _guestCountController.dispose();
    _foodTabController?.dispose();
    super.dispose();
  }

  void _mutateTableState(VoidCallback fn) => setState(fn);

  void _handleAuthSessionChange() {
    if (!mounted || _ordersLoading) return;
    final role = AuthSession.instance.currentRole;
    if (role != null && role != _lastLoadedRole) {
      _refreshOrders();
    }
  }

  bool get _isSupervisor => AuthSession.instance.currentRole == Role.supervisor;

  bool get _isManager =>
      AuthSession.instance.currentRole == Role.manager ||
      AuthSession.instance.currentRole == Role.superAdmin;

  void _onMenuStoreChanged() {
    if (!mounted) return;
    setState(() {
      _allDishes = MenuStore.instance.activeDishes;
    });
  }

  EventOrderDto? _selectedProcessingOrderDto;
  EventOrderDto? _selectedPostAnalysisOrderDto;

  // Extra cost items per order (chairs, tables, etc.)
  final Map<String, List<ChecklistItem>> _extraCostItemsPerOrder = {};

  final List<Uint8List> _themeDesignImages = [];
  List<_ThemeTemplate> _themeTemplates = const [];
  final List<Uint8List> _themePicks = [];
  final Set<int> _themePickHashes = <int>{};
  int _focusedPickIndex = 0;
  List<Uint8List> _collageOrder = const [];
  /// AI / customer-parity theme design payload from EventThemeDesignScreen.
  Map<String, dynamic>? _aiThemeDesignPayload;
  bool _themeTintEnabled = false;
  Color _themeTintColor = const Color(0xFFF4511E);
  bool _isAiProcessingTheme = false;
  bool _paymentDialogLoading = false;
  final PaymentConfirmationMode _selectedPaymentMode =
      PaymentConfirmationMode.downpayment;
  DownPaymentType _selectedDownPaymentType = DownPaymentType.fiftyPercent;
  double _customDownPaymentAmount = 0.0;
  // final PaymentService _selectedPaymentService = PaymentService.cash;
  final TextEditingController _customDownPaymentController =
      TextEditingController();

  // Post analysis controllers
  final TextEditingController _postCardsController = TextEditingController();
  final TextEditingController _postInquiriesController =
      TextEditingController();
  final TextEditingController _postComplaintsController =
      TextEditingController();
  bool _postAnalysisSaving = false;

  // Validation error variables
  String? _contactNumberError;
  String? _emailError;
  String? _guestCountError;

  // SAM Integration variables
  SamSegmentationResult? _currentSegmentationResult;
  final Set<String> _selectedObjectIds = <String>{};
  Color _objectSelectionColor = const Color(0xFFF4511E);
  bool _isSegmenting = false;
  bool _showSegmentationOverlay = false;

  // YOLO detection state variables
  bool _isDetecting = false;

  final List<MenuItem> _menuItems = [];
  String _allergensSerialized = '';
  final Map<String, String> _selectedPaxPerDish = {};
  List<MenuDish> _allDishes = MenuStore.instance.activeDishes;

  static const _eventTypes = [
    'Wedding',
    'Birthday',
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
  ];

  List<MenuDish> get _filteredDishes {
    final query = _inquirySearchController.text.trim().toLowerCase();
    var dishes = _allDishes.where((d) => d.category == 'catering').toList();
    if (query.isEmpty) return dishes;
    return dishes.where((d) => d.name.toLowerCase().contains(query)).toList();
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
      _themeDesignImages.clear();
      _themePicks.clear();
      _themePickHashes.clear();
      _collageOrder = const [];
      _aiThemeDesignPayload = null;
      _themeTintEnabled = false;
      _themeTintColor = const Color(0xFFF4511E);
      _selectedStatus = EventStatus.newEvent;
      _eventSearchController.clear();
      _inquirySearchController.clear();
      _inquiryServiceTypeFilter = '';
      _inquiryEventTypeFilter = '';
      _inquiryDateFilter = '';
      _eventTableServiceTypeFilter = '';
      _eventTableEventTypeFilter = '';
      _eventTableDateFilter = '';
    });
  }

  // Email validation helper
  bool _isValidEmail(String email) {
    return RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    ).hasMatch(email);
  }

  void _addToMenu(MenuDish dish) {
    if ((_foodTabController?.index ?? 0) != 0) return;
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
    if (_menuItems.length >= 8) {
      // max 8 dishes
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 8 dishes per menu.')),
      );
      return;
    }

    setState(() {
      _menuItems.add(MenuItem(dish: dish, paxOption: selectedPax));
    });
  }

  void _applySetMenuToNewEvent(SetMenu set) {
    final dishById = {for (final d in _allDishes) d.id: d};
    setState(() {
      _menuItems.clear();
      for (final id in set.dishIds) {
        final dish = dishById[id];
        if (dish == null) continue;
        final pax =
            _selectedPaxPerDish[dish.name] ??
            (dish.paxOptions.isNotEmpty ? dish.paxOptions.first : '1');
        _menuItems.add(MenuItem(dish: dish, paxOption: pax));
      }
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
    // Design board intentionally starts empty to avoid showing website branding assets.
    final templates = <_ThemeTemplate>[];
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
      _lastLoadedRole = role;
      // print('DEBUG: Current role = $role'); // Debug line

      if (role == null) {
        // print('DEBUG: Role is null, returning empty lists');
        _onlineInquiryOrders = const <EventOrderDto>[];
        _processingOrdersDto = const <EventOrderDto>[];
        _postAnalysisOrdersDto = const <EventOrderDto>[];
        _completedOrdersDto = const <EventOrderDto>[];
        _selectedOnlineInquiryOrder = null;
        return;
      }

      if (role == Role.supervisor) {
        final lists = await Future.wait<List<EventOrderDto>>([
          EventsApi.instance.listOrders(
            status: 'for_processing',
            roleType: 'supervisor',
            compact: true,
          ),
          EventsApi.instance.listOrders(
            status: 'new_event',
            roleType: 'supervisor',
            compact: true,
          ),
          EventsApi.instance.listOrders(
            status: 'for_down_payment',
            roleType: 'supervisor',
            compact: true,
          ),
          EventsApi.instance.listOrders(
            status: 'on_going',
            roleType: 'supervisor',
            compact: true,
          ),
          EventsApi.instance.listOrders(
            status: 'for_full_payment',
            roleType: 'supervisor',
            compact: true,
          ),
          EventsApi.instance.listOrders(
            status: 'completed',
            roleType: 'supervisor',
            compact: true,
          ),
        ]);
        _processingOrdersDto = [
          ...lists[0],
          ...lists[1],
          ...lists[2],
          ...lists[3],
        ];
        _onlineInquiryOrders = const <EventOrderDto>[];
        _postAnalysisOrdersDto = lists[4];
        _completedOrdersDto = lists[5];
      } else if (role == Role.manager || role == Role.superAdmin) {
        final lists = await Future.wait<List<EventOrderDto>>([
          EventsApi.instance.listOrders(
            status: 'online_inquiries',
            roleType: 'manager',
            compact: true,
          ),
          EventsApi.instance.listOrders(
            status: 'for_processing',
            roleType: 'manager',
            compact: true,
          ),
          EventsApi.instance.listOrders(
            status: 'new_event',
            roleType: 'manager',
            compact: true,
          ),
          EventsApi.instance.listOrders(
            status: 'for_down_payment',
            roleType: 'manager',
            compact: true,
          ),
          EventsApi.instance.listOrders(
            status: 'on_going',
            roleType: 'manager',
            compact: true,
          ),
          EventsApi.instance.listOrders(
            status: 'for_full_payment',
            roleType: 'manager',
            compact: true,
          ),
          EventsApi.instance.listOrders(
            status: 'completed',
            roleType: 'manager',
            compact: true,
          ),
        ]);
        _onlineInquiryOrders = lists[0];
        _processingOrdersDto = [
          ...lists[1],
          ...lists[2],
          ...lists[3],
          ...lists[4],
        ];
        _postAnalysisOrdersDto = lists[5];
        _completedOrdersDto = lists[6];
      } else {
        // print('DEBUG: Unknown role, returning empty lists');
        _onlineInquiryOrders = const <EventOrderDto>[];
        _processingOrdersDto = const <EventOrderDto>[];
        _postAnalysisOrdersDto = const <EventOrderDto>[];
        _completedOrdersDto = const <EventOrderDto>[];
      }
      _selectedOnlineInquiryOrder = null;
      ManageEventsOrdersCache.instance.save(
        role: role,
        onlineInquiries: _onlineInquiryOrders,
        processing: _processingOrdersDto,
        postAnalysis: _postAnalysisOrdersDto,
        completed: _completedOrdersDto,
      );
    } catch (e) {
      ManageEventsOrdersCache.instance.clear();
      // print('DEBUG: Error in _refreshOrders: $e'); // Debug line
      // print('DEBUG: Error type: ${e.runtimeType}'); // Debug line
      _onlineInquiryOrders = const <EventOrderDto>[];
      _processingOrdersDto = const <EventOrderDto>[];
      _postAnalysisOrdersDto = const <EventOrderDto>[];
      _completedOrdersDto = const <EventOrderDto>[];
      _selectedOnlineInquiryOrder = null;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load Manage Events orders: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _ordersLoading = false);
      }
    }
  }

  /// List responses may omit theme board base64; load full order when opening detail.
  Future<EventOrderDto> _resolveOrderForSelection(EventOrderDto dto) async {
    if (!dto.themeAssetsDeferred) return dto;
    final role = AuthSession.instance.currentRole;
    final roleType = role == Role.supervisor ? 'supervisor' : 'manager';
    return EventsApi.instance.getEventOrder(
      orderId: dto.id,
      roleType: roleType,
    );
  }

  Future<void> _refreshOrdersFromButton() async {
    ManageEventsOrdersCache.instance.clear();
    await _refreshOrders();
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

  Widget _buildEventTabButton(String title, int index) {
    final selected = _selectedStatus.index == index;
    return Expanded(
      child: GestureDetector(
        onTap:
            () => setState(() => _selectedStatus = EventStatus.values[index]),
        child: Container(
          height: 48,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFFFC024) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: selected ? const Color(0xFFFFC024) : Colors.grey.shade300,
              width: 1.5,
            ),
            boxShadow: [
              if (selected)
                BoxShadow(
                  color: const Color(0xFFFFC024).withValues(alpha: 0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                )
              else
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                fontSize: 13,
                letterSpacing: 0.6,
                color: selected ? Colors.white : Colors.grey.shade700,
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _themeTintColorHex(Color c) {
    final rgb = c.toARGB32() & 0xFFFFFF;
    return '#${rgb.toRadixString(16).padLeft(6, '0')}';
  }

  Color? _colorFromHexOrNull(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final match = RegExp(r'^#?([0-9a-fA-F]{6})$').firstMatch(raw.trim());
    if (match == null) return null;
    return Color(int.parse(match.group(1)!, radix: 16) + 0xFF000000);
  }

  DateTime? _tryParseDate(String? raw) {
    if (raw == null) return null;
    final value = raw.trim();
    if (value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  String _formatDateYyyyMmDd(DateTime date) {
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    return '${date.year}-$mm-$dd';
  }

  ProcessingOrder _orderToProcessingOrderSummary(EventOrderDto order) {
    final firstSlot =
        order.scheduleSlots.isNotEmpty ? order.scheduleSlots.first : null;
    final date = _tryParseDate(firstSlot?.date) ?? DateTime.now();
    final timeLabel =
        firstSlot == null
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
    // Post analysis fields sync - currently no implementation needed
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
      _eventType =
          _eventTypes.contains(order.eventType) ? order.eventType : null;
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
              date: _tryParseDate(s.date) ?? DateTime.now(),
              startTime: _timeOfDayFromHhmm(s.startTime),
              endTime: _timeOfDayFromHhmm(s.endTime),
            );
          }),
        );

      _eventAddressController.text = order.address;
      _guestCountController.text = order.guestCount.toString();
      _allergensSerialized = order.allergens;

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
      _themeTintColor =
          order.themeDesign.tintColorHex == null
              ? _themeTintColor
              : Color(
                int.parse(
                      order.themeDesign.tintColorHex!.replaceAll('#', ''),
                      radix: 16,
                    ) +
                    0xFF000000,
              );
      _collageOrder = _themePicks.toList();
    });
  }

  Map<String, dynamic> _buildPayloadFromForm() {
    final guestCount = int.tryParse(_guestCountController.text.trim());
    return {
      'eventTitle': _eventTitleController.text.trim(),
      'orderType': _orderType,
      'eventType': _eventType,
      'formalityLevel':
          _formalityLevel == null ? null : _formalityToString(_formalityLevel!),
      'customerName': _customerController.text.trim(),
      'contactPerson': _contactPersonController.text.trim(),
      'contactNumber': _contactNumberController.text.trim(),
      'emailAddress': _emailController.text.trim(),
      'scheduleSlots':
          _eventScheduleSlots.map((slot) {
            return {
              'date':
                  '${slot.date.year.toString().padLeft(4, '0')}-${slot.date.month.toString().padLeft(2, '0')}-${slot.date.day.toString().padLeft(2, '0')}',
              'startTime': _hhmmFromTimeOfDay(slot.startTime),
              'endTime': _hhmmFromTimeOfDay(slot.endTime),
            };
          }).toList(),
      'address': _eventAddressController.text.trim(),
      'guestCount': guestCount,
      'allergens': _allergensSerialized.trim(),
      'menu':
          _menuItems.map((i) {
            return {
              'dishName': i.dish.name,
              'paxOption': i.paxOption,
              'price': i.dish.price,
            };
          }).toList(),
      'themeDesign': {
        if (_aiThemeDesignPayload != null) ..._aiThemeDesignPayload!,
        'picksBase64': _themePicks.map((b) => base64Encode(b)).toList(),
        'tintEnabled': _themeTintEnabled,
        'tintColorHex':
            _themeTintEnabled ? _themeTintColorHex(_themeTintColor) : null,
        if (_aiThemeDesignPayload != null) 'wantsCustomDesign': true,
      },
    };
  }

  Widget _buildOnlineInquiryServiceType(
    String serviceType,
    Function(String) onChanged,
    int guestCount,
  ) {
    final isEditable = guestCount < 50;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildServiceTypeChip(
                'Catering Only',
                'catering',
                serviceType,
                isEditable ? onChanged : (_) {},
              ),
              const SizedBox(width: 16),
              _buildServiceTypeChip(
                'Catering + Event',
                'catering+event',
                serviceType,
                isEditable ? onChanged : (_) {},
              ),
            ],
          ),
          if (!isEditable) ...[
            const SizedBox(height: 8),
            Text(
              'Service type locked (50+ guests)',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildServiceTypeChip(
    String label,
    String value,
    String selectedValue,
    Function(String) onChanged,
  ) {
    final isSelected = selectedValue == value;
    return ElevatedButton(
      onPressed: () => onChanged(value),
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

  Widget _buildOnlineInquiryEventInfo(
    EventOrderDto order,
    TextEditingController addressController,
    TextEditingController dateController,
    TextEditingController timeController,
    BuildContext context,
    String serviceType,
  ) {
    Future<void> selectDate() async {
      final picked = await showDatePicker(
        context: context,
        initialDate: DateTime.tryParse(dateController.text) ?? DateTime.now(),
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 365)),
      );
      if (picked != null) {
        dateController.text =
            '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      }
    }

    Future<void> selectTime() async {
      final picked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      if (picked != null) {
        timeController.text =
            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      }
    }

    Future<void> selectDateThenTime() async {
      await selectDate();
      await selectTime();
    }

    Future<void> pickAddressFromMap() async {
      final picked = await showMapPicker(
        context: context,
        initialAddress:
            addressController.text.trim().isEmpty
                ? order.address
                : addressController.text.trim(),
      );
      if (picked != null) {
        addressController.text = picked.address;
      }
    }

    final isCateringOnly = serviceType == 'catering';

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
            child: const Text(
              'EVENT INFORMATION',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          const SizedBox(height: 16),

          // Read-only fields - hide event title/type/formality for catering only
          if (!isCateringOnly) ...[
            _buildReadOnlyField('EVENT TITLE', order.eventTitle),
            const SizedBox(height: 12),
            _buildReadOnlyField('EVENT TYPE', order.eventType),
            const SizedBox(height: 12),
            _buildReadOnlyField('FORMALITY LEVEL', order.formalityLevel),
            const SizedBox(height: 12),
          ],
          _buildReadOnlyField('CONTACT PERSON', order.contactPerson),
          const SizedBox(height: 12),
          _buildReadOnlyField('CONTACT NUMBER', order.contactNumber),
          const SizedBox(height: 12),
          _buildReadOnlyField('EMAIL ADDRESS', order.emailAddress),
          const SizedBox(height: 12),
          _buildReadOnlyField('CUSTOMER', order.customerName),
          const SizedBox(height: 12),
          TextField(
            controller: addressController,
            readOnly: true,
            onTap: pickAddressFromMap,
            decoration: InputDecoration(
              labelText: 'CITY OF EVENT',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.map_outlined),
                onPressed: pickAddressFromMap,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Editable Date/Time
          TextField(
            controller: dateController,
            readOnly: true,
            onTap: selectDateThenTime,
            decoration: InputDecoration(
              labelText: 'DATE OF EVENT (time prompted right after)',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.edit_calendar_outlined),
                onPressed: selectDateThenTime,
              ),
              helperText:
                  timeController.text.trim().isEmpty
                      ? 'Time not selected yet'
                      : 'Time: ${timeController.text.trim()}',
            ),
          ),
          const SizedBox(height: 12),
          _buildReadOnlyField('NO OF GUESTS', order.guestCount.toString()),
        ],
      ),
    );
  }

  Widget _buildReadOnlyField(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(4),
        color: Colors.grey.shade100,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 4),
          Text(
            value.isEmpty ? '-' : value,
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSection(
    EventOrderDto order,
    String menuChoice,
    Function(String) onMenuChoiceChanged,
    List<String> selectedDishIds,
    String? selectedSetMenuId,
    Function(String?) onSetMenuChanged,
    VoidCallback onStateChanged,
  ) {
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
              _buildMenuChoiceChip(
                'YES!',
                'yes',
                menuChoice,
                onMenuChoiceChanged,
              ),
              const SizedBox(width: 12),
              _buildMenuChoiceChip(
                'NO I\'D LIKE MACRINAS TO\nSUGGEST ME A MENU INSTEAD',
                'suggest',
                menuChoice,
                onMenuChoiceChanged,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Menu Content
          if (menuChoice == 'yes')
            _buildDishSelector(selectedDishIds, onStateChanged, order)
          else
            _buildSetMenuSelector(selectedSetMenuId, onSetMenuChanged),
        ],
      ),
    );
  }

  Widget _buildMenuChoiceChip(
    String label,
    String value,
    String selectedValue,
    Function(String) onChanged,
  ) {
    final isYes = value == 'yes';
    return ElevatedButton(
      onPressed: () => onChanged(value),
      style: ElevatedButton.styleFrom(
        backgroundColor: isYes ? const Color(0xFFE8F5E9) : Colors.white,
        foregroundColor: Colors.black,
        side: BorderSide(
          color: isYes ? const Color(0xFF4CAF50) : Colors.red.shade300,
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

  Widget _buildDishSelector(
    List<String> selectedDishIds,
    VoidCallback onStateChanged,
    EventOrderDto order,
  ) {
    final dishes = MenuStore.instance.activeDishes;
    return Container(
      constraints: const BoxConstraints(maxHeight: 350),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: dishes.length,
        itemBuilder: (context, index) {
          final dish = dishes[index];
          final isSelected = selectedDishIds.contains(dish.id);
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
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
              title: Text(
                dish.name,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: null,
              trailing:
                  isSelected
                      ? const Icon(Icons.check_circle, color: Color(0xFF4CAF50))
                      : const Icon(
                        Icons.add_circle_outline,
                        color: Colors.grey,
                      ),
              onTap: () {
                if (isSelected) {
                  selectedDishIds.remove(dish.id);
                } else {
                  selectedDishIds.add(dish.id);
                }
                onStateChanged();
              },
              selected: isSelected,
              selectedTileColor: Colors.green.shade50,
            ),
          );
        },
      ),
    );
  }

  Widget _buildSetMenuSelector(
    String? selectedSetMenuId,
    Function(String?) onChanged,
  ) {
    final setMenus = _onlineInquirySetMenus();

    return Column(
      children:
          setMenus.map((setMenu) {
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                dense: true,
                title: Text(
                  setMenu['name'] as String,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      setMenu['description'] as String,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ),
                isThreeLine: true,
                trailing: Radio<String>(
                  value: setMenu['id'] as String,
                  groupValue: selectedSetMenuId,
                  onChanged: onChanged,
                ),
                onTap: () => onChanged(setMenu['id'] as String),
              ),
            );
          }).toList(),
    );
  }

  List<Map<String, dynamic>> _onlineInquirySetMenus() {
    return [
      {
        'id': 'set_1',
        'name': 'Filipino Feast Set',
        'description': 'Bistek, Sinigang, Lechon Kawali, Kare-Kare',
        'dishes': [
          'dish_bistek',
          'dish_sinigang',
          'dish_lechon_kawali',
          'dish_kare_kare',
        ],
      },
      {
        'id': 'set_2',
        'name': 'Classic Party Set',
        'description': 'Bistek, Sinigang, Lechon Kawali',
        'dishes': ['dish_bistek', 'dish_sinigang', 'dish_lechon_kawali'],
      },
    ];
  }

  double _parseMenuDishPrice(MenuDish? d) {
    if (d == null) return 0;
    return double.tryParse(d.price.replaceAll(',', '').trim()) ?? 0;
  }

  double _calculateOnlineInquiryDishCost({
    required String menuChoice,
    required List<String> selectedDishIds,
    required String? selectedSetMenuId,
    required int guestCount,
  }) {
    final pax = guestCount > 0 ? guestCount : 1;
    final dishes = MenuStore.instance.allDishes;

    MenuDish? dishById(String id) {
      for (final d in dishes) {
        if (d.id == id) return d;
      }
      return null;
    }

    if (menuChoice == 'yes') {
      double sum = 0;
      for (final id in selectedDishIds) {
        sum += _parseMenuDishPrice(dishById(id));
      }
      return sum * pax;
    }
    if (selectedSetMenuId != null) {
      final setMenu = _onlineInquirySetMenus().firstWhere(
        (s) => s['id'] == selectedSetMenuId,
        orElse: () => {'dishes': const <String>[]},
      );
      final ids =
          (setMenu['dishes'] as List<dynamic>? ?? const [])
              .map((e) => e.toString())
              .toList();
      double sum = 0;
      for (final id in ids) {
        sum += _parseMenuDishPrice(dishById(id));
      }
      return sum * pax;
    }
    return 0.0;
  }

  Widget _buildOnlineInquiryEventDesign(EventOrderDto order) {
    final td = order.themeDesign;
    final generatedUrl = td.generatedImageUrl?.trim() ?? '';
    final designPrompt =
        (td.customInstructions ??
                td.colorPrompt ??
                td.customerThemeRequest ??
                '')
            .trim();
    final previewSources =
        td.picksBase64
            .where((s) => s.trim().isNotEmpty)
            .map((s) => s.trim())
            .toList();
    Widget? detailRow(String label, String? value) {
      final text = (value ?? '').trim();
      if (text.isEmpty) return null;
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: RichText(
          text: TextSpan(
            style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
            children: [
              TextSpan(
                text: '$label: ',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              TextSpan(text: text),
            ],
          ),
        ),
      );
    }

    String eventDesignSourceLabel() {
      final src = (td.eventDesignSource ?? '').trim();
      if (src == 'customer_ai') return 'Customer AI event design';
      if (src == 'macrina') return 'Macrina will design the event';
      if (td.wantsCustomDesign) return 'Custom event design';
      if (src.isNotEmpty) return src;
      return '';
    }

    Widget previewWidget(String source, {BoxFit fit = BoxFit.cover}) {
      if (source.startsWith('http://') || source.startsWith('https://')) {
        return Image.network(
          source,
          fit: fit,
          errorBuilder:
              (_, __, ___) => const Center(child: Icon(Icons.broken_image)),
        );
      }
      try {
        return Image.memory(base64Decode(source), fit: fit);
      } catch (_) {
        return const Center(child: Icon(Icons.broken_image));
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'EVENT DESIGN',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 12),
          ...[
            if (eventDesignSourceLabel().isNotEmpty)
              detailRow('Design source', eventDesignSourceLabel()),
            detailRow('Style', td.style),
            detailRow('Mood', td.mood),
            if (td.colorPalette.isNotEmpty)
              detailRow('Color palette', td.colorPalette.join(', ')),
            if (td.decorElements.isNotEmpty)
              detailRow('Decor elements', td.decorElements.join(', ')),
            detailRow('Customer note', td.customerNote),
            if (designPrompt.isNotEmpty)
              detailRow('Design prompt', designPrompt),
            if (generatedUrl.isNotEmpty)
              detailRow('Generated image URL', generatedUrl),
          ].whereType<Widget>(),
          if (generatedUrl.isNotEmpty) ...[
            const Text(
              'AI-generated design image',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 160,
                width: double.infinity,
                child: previewWidget(generatedUrl, fit: BoxFit.contain),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (previewSources.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3D0),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${previewSources.length} reference photo(s)',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Color(0xFF7A4E00),
                ),
              ),
            ),
          if (previewSources.isEmpty && generatedUrl.isEmpty)
            Text(
              td.wantsCustomDesign
                  ? 'Customer asked Macrinas to create the event design.'
                  : 'No event design image submitted.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          if (previewSources.isNotEmpty) const SizedBox(height: 12),
          if (previewSources.isNotEmpty)
            SizedBox(
              height: 110,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: previewSources.length,
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () {
                      showDialog<void>(
                        context: context,
                        builder: (dialogContext) {
                          return Dialog(
                            insetPadding: const EdgeInsets.all(24),
                            child: Stack(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: InteractiveViewer(
                                    minScale: 0.5,
                                    maxScale: 4.0,
                                    child: previewWidget(
                                      previewSources[index],
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 6,
                                  right: 6,
                                  child: IconButton(
                                    tooltip: 'Close preview',
                                    onPressed:
                                        () => Navigator.of(dialogContext).pop(),
                                    icon: const Icon(Icons.close),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                    child: Container(
                      width: 110,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: previewWidget(
                          previewSources[index],
                          fit: BoxFit.cover,
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

  Widget _buildLabeledReadonlyCost(String label, double value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(
            'PHP ${value.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _buildOnlineInquiryPayload(
    EventOrderDto order,
    String address,
    String date,
    String time,
    String serviceType,
    String menuChoice,
    List<String> selectedDishIds,
    String? selectedSetMenuId,
    double laborCost,
    double travelCost,
    double totalCost,
    String action,
  ) {
    List<Map<String, dynamic>> menuItems = [];
    final schedulePayload = <Map<String, dynamic>>[];

    if (menuChoice == 'yes') {
      for (final dishId in selectedDishIds) {
        final dish = MenuStore.instance.allDishes.firstWhere(
          (d) => d.id == dishId,
        );
        final paxCount = order.guestCount > 0 ? order.guestCount : 1;
        final computedPrice = 500 * paxCount;
        menuItems.add({
          'dishId': dishId,
          'dishName': dish.name,
          'paxOption': '${paxCount} pax',
          'price': computedPrice.toString(),
        });
      }
    } else if (selectedSetMenuId != null) {
      final setMenus = _onlineInquirySetMenus();
      final setMenu = setMenus.firstWhere((s) => s['id'] == selectedSetMenuId);
      final dishes = setMenu['dishes'] as List<String>;
      for (final dishId in dishes) {
        final dish = MenuStore.instance.allDishes.firstWhere(
          (d) => d.id == dishId,
        );
        final paxCount = order.guestCount > 0 ? order.guestCount : 1;
        final computedPrice = 500 * paxCount;
        menuItems.add({
          'dishId': dishId,
          'dishName': dish.name,
          'paxOption': '$paxCount pax',
          'price': computedPrice.toString(),
        });
      }
    }

    // Keep existing menu when posting estimate without changing menu selection.
    if (menuItems.isEmpty && order.menu.isNotEmpty) {
      menuItems =
          order.menu
              .map(
                (m) => <String, dynamic>{
                  'dishName': m.dishName,
                  'paxOption': m.paxOption,
                  'price': m.price,
                },
              )
              .toList();
    }

    final dateValue = date.trim();
    final timeValue = time.trim();
    if (dateValue.isNotEmpty || timeValue.isNotEmpty) {
      schedulePayload.add({
        'date': dateValue,
        'startTime': timeValue,
        'endTime': '14:00',
      });
    } else if (order.scheduleSlots.isNotEmpty) {
      schedulePayload.addAll(
        order.scheduleSlots.map(
          (slot) => <String, dynamic>{
            'date': slot.date,
            'startTime': slot.startTime,
            'endTime': slot.endTime,
          },
        ),
      );
    }

    return {
      'eventTitle': order.eventTitle,
      'eventType': order.eventType,
      'formalityLevel': order.formalityLevel,
      'customerName': order.customerName,
      'contactPerson': order.contactPerson,
      'contactNumber': order.contactNumber,
      'emailAddress': order.emailAddress,
      'scheduleSlots': schedulePayload,
      'address': address,
      'guestCount': order.guestCount,
      'serviceType': serviceType,
      'menu': menuItems,
      'themeDesign': {
        'picksBase64': order.themeDesign.picksBase64,
        'tintEnabled': order.themeDesign.tintEnabled,
        'tintColorHex': order.themeDesign.tintColorHex,
        'wantsCustomDesign': order.themeDesign.wantsCustomDesign,
        'customerThemeRequest': order.themeDesign.customerThemeRequest,
        'costBreakdown': {
          'dishCost': menuItems.fold<double>(
            0.0,
            (sum, row) => sum + (double.tryParse('${row['price']}') ?? 0.0),
          ),
          'laborCost': laborCost,
          'travelCost': travelCost,
        },
      },
      'totalCost': totalCost,
      'action': action,
    };
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

  void _removeThemePick(int index) {
    if (index >= 0 && index < _themePicks.length) {
      final removedBytes = _themePicks[index];
      final removedKey = _themeImageKey(removedBytes);

      setState(() {
        _themePicks.removeAt(index);
        _themePickHashes.remove(removedKey);

        // Adjust focused index if needed
        if (_focusedPickIndex >= _themePicks.length) {
          _focusedPickIndex = _themePicks.length - 1;
        }
        if (_focusedPickIndex < 0) {
          _focusedPickIndex = 0;
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo removed from picks'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );
      }
    }
  }

  Future<bool> _runEditObjectsFlow(Uint8List imageBytes) async {
    setState(() {
      _isDetecting = true;
      _isSegmenting = true;
    });
    try {
      double toDouble(dynamic value, [double fallback = 0.0]) {
        if (value is num) return value.toDouble();
        if (value == null) return fallback;
        return double.tryParse(value.toString().trim()) ?? fallback;
      }

      dynamic decodeIfJsonString(dynamic value) {
        if (value is String) {
          final trimmed = value.trim();
          if (trimmed.isEmpty) return null;
          if ((trimmed.startsWith('{') && trimmed.endsWith('}')) ||
              (trimmed.startsWith('[') && trimmed.endsWith(']'))) {
            try {
              return jsonDecode(trimmed);
            } catch (_) {
              return value;
            }
          }
        }
        return value;
      }

      List<dynamic> asDynamicList(dynamic value) {
        final decoded = decodeIfJsonString(value);
        if (decoded is List) return decoded;
        return const <dynamic>[];
      }

      Map<String, dynamic> asStringDynamicMap(dynamic value) {
        final decoded = decodeIfJsonString(value);
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
        return const <String, dynamic>{};
      }

      final response = await EventsApi.instance.inferThemeObjectsWithSam(
        imageBase64: base64Encode(imageBytes),
        maskFormat: 'polygon',
      );
      final objectsRaw =
          asDynamicList(response['objects'])
              .map((e) => asStringDynamicMap(e))
              .where((e) => e.isNotEmpty)
              .toList();
      if (objectsRaw.isEmpty) {
        throw Exception('No objects detected to edit.');
      }
      final responseImageWidth =
          toDouble(response['imageWidth'], 0.0) > 0
              ? toDouble(response['imageWidth'], 1.0)
              : toDouble(response['image_width'], 1.0);
      final responseImageHeight =
          toDouble(response['imageHeight'], 0.0) > 0
              ? toDouble(response['imageHeight'], 1.0)
              : toDouble(response['image_height'], 1.0);
      final segmentedObjects =
          objectsRaw.map((raw) {
            final box =
                asStringDynamicMap(raw['boundingBox']).isNotEmpty
                    ? asStringDynamicMap(raw['boundingBox'])
                    : asStringDynamicMap(raw['box']);
            final maskBase64 =
                (raw['maskBase64'] ?? raw['mask_base64'] ?? '').toString();
            final rawPolygon = asDynamicList(
              raw['polygonPoints'] ?? raw['polygon_points'],
            );
            final polygonPoints =
                rawPolygon
                    .map((point) {
                      final p = asStringDynamicMap(point);
                      if (p.isNotEmpty) {
                        return Offset(toDouble(p['x']), toDouble(p['y']));
                      }
                      if (point is List && point.length >= 2) {
                        return Offset(toDouble(point[0]), toDouble(point[1]));
                      }
                      return null;
                    })
                    .whereType<Offset>()
                    .toList();
            final rawLeft =
                toDouble(box['left'], double.nan).isNaN
                    ? toDouble(box['x'])
                    : toDouble(box['left']);
            final rawTop =
                toDouble(box['top'], double.nan).isNaN
                    ? toDouble(box['y'])
                    : toDouble(box['top']);
            final rawWidth = toDouble(box['width'], 0.2);
            final rawHeight = toDouble(box['height'], 0.2);
            final isNormalized = rawWidth <= 1.0 && rawHeight <= 1.0;
            final boxLeft =
                isNormalized ? rawLeft * responseImageWidth : rawLeft;
            final boxTop = isNormalized ? rawTop * responseImageHeight : rawTop;
            final boxWidth =
                isNormalized ? rawWidth * responseImageWidth : rawWidth;
            final boxHeight =
                isNormalized ? rawHeight * responseImageHeight : rawHeight;

            return SegmentedObject(
              id: (raw['id'] ?? '').toString(),
              mask:
                  maskBase64.isNotEmpty
                      ? base64Decode(maskBase64)
                      : Uint8List(0),
              label: (raw['label'] ?? '').toString(),
              boundingBox: Rect.fromLTWH(boxLeft, boxTop, boxWidth, boxHeight),
              polygonPoints: polygonPoints,
              currentColor: _colorFromHexOrNull(
                raw['currentColorHex'] as String?,
              ),
            );
          }).toList();

      setState(() {
        _currentSegmentationResult = SamSegmentationResult(
          objects: segmentedObjects,
          previewImage: imageBytes,
        );
      });
      return true;
    } catch (e) {
      final msg = e.toString().toLowerCase();
      final timeout = msg.contains('timeout') || msg.contains('timed out');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              timeout
                  ? 'AI service timed out. Please try again with one clear photo.'
                  : 'AI edit setup failed: ${e.toString()}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _isDetecting = false;
          _isSegmenting = false;
        });
      }
    }
  }

  double _getCalculatedDownPaymentAmount() {
    final selPost = _selectedPostAnalysisOrderDto;
    if (selPost == null) return 0.0;

    switch (_selectedDownPaymentType) {
      case DownPaymentType.none:
        return 0.0;
      case DownPaymentType.fiftyPercent:
        return selPost.totalCost * 0.5;
      case DownPaymentType.seventyFivePercent:
        return selPost.totalCost * 0.75;
      case DownPaymentType.fullPayment:
        return selPost.totalCost;
      case DownPaymentType.custom:
        return _customDownPaymentAmount;
    }
  }

  double _getCalculatedFullPaymentAmount() {
    final selPost = _selectedPostAnalysisOrderDto;
    if (selPost == null) return 0.0;

    final downPayment = _getCalculatedDownPaymentAmount();
    return selPost.totalCost - downPayment;
  }

  void _calculateDownPaymentAmount() {
    final selPost = _selectedPostAnalysisOrderDto;
    if (selPost == null) return;

    setState(() {
      if (_selectedDownPaymentType == DownPaymentType.custom) {
        _customDownPaymentAmount =
            double.tryParse(_customDownPaymentController.text) ?? 0.0;
      }
    });
  }

  Future<void> _applyColorToSelectedObjects({Color? targetColor}) async {
    if (_currentSegmentationResult == null || _selectedObjectIds.isEmpty) {
      return;
    }

    final resolvedTargetColor = targetColor ?? _themeTintColor;

    setState(() {
      _isAiProcessingTheme = true;
      _themeTintEnabled = true;
      _themeTintColor = resolvedTargetColor;
      _objectSelectionColor = resolvedTargetColor;
    });

    try {
      final selectedObjects =
          _currentSegmentationResult!.objects
              .where((obj) => _selectedObjectIds.contains(obj.id))
              .toList();
      if (selectedObjects.isEmpty) {
        setState(() {
          _isAiProcessingTheme = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No valid selected objects found. Please select again.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      final masksPayload =
          selectedObjects.map((obj) {
            final normalizedPolygon =
                obj.polygonPoints
                    .map(
                      (point) => {
                        'x': point.dx.toDouble(),
                        'y': point.dy.toDouble(),
                      },
                    )
                    .toList();
            final fallbackBoxPolygon = <Map<String, double>>[
              {
                'x': obj.boundingBox.left.toDouble(),
                'y': obj.boundingBox.top.toDouble(),
              },
              {
                'x': obj.boundingBox.right.toDouble(),
                'y': obj.boundingBox.top.toDouble(),
              },
              {
                'x': obj.boundingBox.right.toDouble(),
                'y': obj.boundingBox.bottom.toDouble(),
              },
              {
                'x': obj.boundingBox.left.toDouble(),
                'y': obj.boundingBox.bottom.toDouble(),
              },
            ];
            final maskBase64 =
                obj.mask.isNotEmpty ? base64Encode(obj.mask) : '';
            return {
              'objectId': obj.id,
              'polygonPoints':
                  normalizedPolygon.isNotEmpty
                      ? normalizedPolygon
                      : fallbackBoxPolygon,
              if (maskBase64.isNotEmpty) 'maskBase64': maskBase64,
            };
          }).toList();
      final editsPayload =
          selectedObjects.map((obj) {
            return {
              'objectId': obj.id,
              'targetHex': _themeTintColorHex(resolvedTargetColor),
              'intensity': 1.0,
            };
          }).toList();
      final recolorResponse = await EventsApi.instance.swapThemeObjectColors(
        imageBase64: base64Encode(_currentSegmentationResult!.previewImage),
        masks: masksPayload,
        edits: editsPayload,
      );
      final recoloredImageBase64 =
          (recolorResponse['imageBase64'] ?? '').toString().trim();
      final skippedObjects =
          (recolorResponse['skipped'] as List<dynamic>? ?? const []);
      final updatedPreviewImage =
          recoloredImageBase64.isNotEmpty
              ? base64Decode(recoloredImageBase64)
              : _currentSegmentationResult!.previewImage;

      final updatedObjects =
          _currentSegmentationResult!.objects.map((obj) {
            if (_selectedObjectIds.contains(obj.id)) {
              return SegmentedObject(
                id: obj.id,
                mask: obj.mask,
                label: obj.label,
                boundingBox: obj.boundingBox,
                polygonPoints: obj.polygonPoints,
                currentColor: resolvedTargetColor,
              );
            }
            return obj;
          }).toList();

      setState(() {
        _currentSegmentationResult = SamSegmentationResult(
          objects: updatedObjects,
          previewImage: updatedPreviewImage,
        );
        _isAiProcessingTheme = false;
        _selectedObjectIds.clear();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              skippedObjects.isEmpty
                  ? 'Colors applied to selected objects'
                  : 'Colors applied with ${skippedObjects.length} skipped object(s)',
            ),
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
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    setState(() {
      _showSegmentationOverlay = false;
      _currentSegmentationResult = null;
      _selectedObjectIds.clear();
    });
  }

  Widget _buildSegmentationOverlay() {
    if (!_showSegmentationOverlay || _currentSegmentationResult == null) {
      return const SizedBox.shrink();
    }

    return Dialog(
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
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  onPressed: _closeSegmentationOverlay,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Main layout: left photo, right controls
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left: larger image preview
                  Expanded(
                    flex: 3,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(10),
                        color: Colors.black12,
                      ),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Image.memory(
                              _currentSegmentationResult!.previewImage,
                              fit: BoxFit.contain,
                            ),
                          ),

                          if (_isSegmenting)
                            const Center(child: CircularProgressIndicator())
                          else
                            ..._currentSegmentationResult!.objects.map((obj) {
                              final isSelected = _selectedObjectIds.contains(
                                obj.id,
                              );
                              return Positioned(
                                left: obj.boundingBox.left,
                                top: obj.boundingBox.top,
                                width: obj.boundingBox.width,
                                height: obj.boundingBox.height,
                                child: GestureDetector(
                                  onTap: () {
                                    final groupIds =
                                        _currentSegmentationResult!.objects
                                            .where((o) => o.label == obj.label)
                                            .map((o) => o.id)
                                            .toSet();
                                    setState(() {
                                      _selectedObjectIds
                                        ..clear()
                                        ..addAll(groupIds);
                                    });
                                  },
                                  child: Stack(
                                    children: [
                                      Positioned.fill(
                                        child: _SoftObjectOverlay(
                                          object: obj,
                                          isSelected: isSelected,
                                        ),
                                      ),
                                      Positioned.fill(
                                        child: IgnorePointer(
                                          child: Container(
                                            color: Colors.transparent,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Right: top color picker, bottom detected objects + actions
                  SizedBox(
                    width: 340,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Recolor',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children:
                                    [
                                      const Color(0xFFF4511E),
                                      const Color(0xFF1DB954),
                                      const Color(0xFF1976D2),
                                      const Color(0xFFE91E63),
                                      const Color(0xFF6A1B9A),
                                      const Color(0xFFFFC107),
                                      const Color(0xFFFFFFFF),
                                      const Color(0xFF212121),
                                    ].map((c) {
                                      final isSelected =
                                          c.toARGB32() ==
                                          _objectSelectionColor.toARGB32();
                                      return GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _objectSelectionColor = c;
                                          });
                                        },
                                        child: Center(
                                          child: Container(
                                            width: 30,
                                            height: 30,
                                            decoration: BoxDecoration(
                                              color: c,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color:
                                                    isSelected
                                                        ? Colors.black
                                                        : Colors.black26,
                                                width: isSelected ? 3 : 1,
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Container(
                          height: 220,
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
                              SingleChildScrollView(
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children:
                                      (() {
                                        final grouped =
                                            <String, List<SegmentedObject>>{};
                                        for (final obj
                                            in _currentSegmentationResult!
                                                .objects) {
                                          grouped
                                              .putIfAbsent(
                                                obj.label,
                                                () => <SegmentedObject>[],
                                              )
                                              .add(obj);
                                        }
                                        return grouped.entries.map((entry) {
                                          final ids =
                                              entry.value
                                                  .map((o) => o.id)
                                                  .toSet();
                                          final isSelected = ids.any(
                                            _selectedObjectIds.contains,
                                          );
                                          final label =
                                              entry.value.length > 1
                                                  ? '${entry.key} (${entry.value.length})'
                                                  : entry.key;
                                          return FilterChip(
                                            label: Text(label),
                                            selected: isSelected,
                                            onSelected: (_) {
                                              setState(() {
                                                _selectedObjectIds
                                                  ..clear()
                                                  ..addAll(ids);
                                              });
                                            },
                                            backgroundColor:
                                                Colors.grey.shade200,
                                            selectedColor: Colors.blue
                                                .withValues(alpha: 0.3),
                                            checkmarkColor: Colors.blue,
                                          );
                                        }).toList();
                                      })(),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed:
                              _selectedObjectIds.isEmpty
                                  ? null
                                  : () => _applyColorToSelectedObjects(
                                    targetColor: _objectSelectionColor,
                                  ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1DB954),
                          ),
                          child:
                              _isAiProcessingTheme
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
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: _closeSegmentationOverlay,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey.shade400,
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
  }

  Widget _buildOnlineInquiriesView(bool isNarrow) {
    return _buildOnlineInquiriesTableView(isNarrow);
  }

  Widget _buildSelectableOrderCard(
    EventOrderDto dto,
    bool isSelected,
    void Function(EventOrderDto) onSelect,
  ) {
    final order = _orderToProcessingOrderSummary(dto);
    final bgColor = isSelected ? const Color(0xFFEFF6FF) : Colors.white;
    final borderColor =
        isSelected ? const Color(0xFF1976D2) : Colors.grey.shade300;

    // Determine status tag color and text
    Color statusColor = Colors.orange;
    String statusText = 'PENDING';

    // For processing and post analysis tabs, always show PENDING
    // For completed tab, show COMPLETED/CANCELLED based on finalStatus
    if (dto.status == 'for_processing' ||
        dto.status == 'for_full_payment' ||
        dto.status == 'for_post_analysis') {
      statusColor = Colors.orange;
      statusText = 'PENDING';
    } else if (dto.finalStatus == 'cancelled') {
      statusColor = Colors.red;
      statusText = 'CANCELLED';
    } else if (dto.finalStatus == 'successful') {
      statusColor = Colors.green;
      statusText = 'COMPLETED';
    }

    return InkWell(
      onTap: () async {
        try {
          final resolved = await _resolveOrderForSelection(dto);
          if (!context.mounted) return;
          setState(() {
            onSelect(resolved);
          });
        } catch (e) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not load full order: $e'),
              backgroundColor: Colors.red.shade800,
            ),
          );
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
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
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
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
                if (dto.status == 'for_processing')
                  ElevatedButton(
                    onPressed: () => _acceptOrder(dto),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1DB954),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
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
                    Row(
                      children: [
                        _buildSectionTitle('ORDERS FOR PROCESSING'),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Refresh processing orders',
                          onPressed:
                              _ordersLoading ? null : _refreshOrdersFromButton,
                          icon:
                              _ordersLoading
                                  ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : const Icon(Icons.refresh),
                        ),
                      ],
                    ),
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
                    ),
                    const SizedBox(height: 16),
                    if (orderDtos.isEmpty)
                      Center(
                        child: Text(
                          'No orders ready for processing.',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      )
                    else
                      Column(
                        children:
                            orderDtos.map((dto) {
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

            // Event information, seating, and menu
            if (_selectedProcessingOrderDto != null) ...[
              _buildEventInformationSection(),
              const SizedBox(height: 20),
              _buildProcessingSeatingSection(),
              const SizedBox(height: 20),
              _buildProcessingMenuSection(),
              const SizedBox(height: 20),
            ],
          ],
        ),
      );
    }

    // Wide layout - side-by-side order picker and event info
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left: Orders List (narrower)
        Expanded(
          flex: 1,
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _buildSectionTitle('ORDERS FOR PROCESSING'),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Refresh processing orders',
                        onPressed:
                            _ordersLoading ? null : _refreshOrdersFromButton,
                        icon:
                            _ordersLoading
                                ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                                : const Icon(Icons.refresh),
                      ),
                    ],
                  ),
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
                  Expanded(
                    child:
                        orderDtos.isEmpty
                            ? Center(
                              child: Text(
                                'No orders ready for processing.',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            )
                            : SingleChildScrollView(
                              child: Column(
                                children:
                                    orderDtos.map((dto) {
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 12,
                                        ),
                                        child: _buildSelectableOrderCard(
                                          dto,
                                          _selectedProcessingOrderDto?.id ==
                                              dto.id,
                                          (d) => setState(() {
                                            _selectedProcessingOrderDto = d;
                                          }),
                                        ),
                                      );
                                    }).toList(),
                              ),
                            ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 20),

        // Right: Event Information and Menu (wider)
        Expanded(
          flex: 2,
          child:
              _selectedProcessingOrderDto != null
                  ? SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildEventInformationSection(),
                        const SizedBox(height: 20),
                        _buildProcessingSeatingSection(),
                        const SizedBox(height: 20),
                        _buildProcessingMenuSection(),
                      ],
                    ),
                  )
                  : Card(
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
        ),
      ],
    );
  }

  Widget _buildExtraCostItemsSection(String orderId) {
    final extraItems = _extraCostItemsPerOrder[orderId] ?? [];

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
                const Text(
                  'Extra Cost Items',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                if (_isManager) ...[
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.grey.shade400),
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(
                        Icons.add,
                        color: Colors.black54,
                        size: 18,
                      ),
                      onPressed: () => _addExtraCostItem(orderId),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            if (extraItems.isEmpty)
              Text(
                'No extra items added yet.',
                style: TextStyle(color: Colors.grey.shade600),
              )
            else
              Column(
                children:
                    extraItems.asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                item.item,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                '${item.quantity}x',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            ),
                            if (_isManager) ...[
                              Expanded(
                                child: Text(
                                  formatPesos(item.cost),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Container(
                                width: 28,
                                height: 28,
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(
                                    Icons.remove,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                  onPressed:
                                      () =>
                                          _removeExtraCostItem(orderId, index),
                                ),
                              ),
                            ] else ...[
                              Expanded(
                                child: Text(
                                  formatPesos(item.cost),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
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

  void _addExtraCostItem(String orderId) {
    final newItem = ChecklistItem(
      item: 'Extra Item',
      description: '',
      quantity: 1,
      cost: 0.0,
      isCompleted: false,
    );

    setState(() {
      final items = _extraCostItemsPerOrder[orderId] ?? [];
      items.add(newItem);
      _extraCostItemsPerOrder[orderId] = items;
    });
  }

  void _removeExtraCostItem(String orderId, int index) {
    setState(() {
      final items = _extraCostItemsPerOrder[orderId] ?? [];
      if (index < items.length) {
        items.removeAt(index);
        _extraCostItemsPerOrder[orderId] = items;
      }
    });
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
              'ORDER NO',
              _transactionNumberForOrder(selectedOrder),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                // Only show theme design button for catering+event orders
                if (_isCateringPlusEventOrder(selectedOrder)) ...[
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
                ],
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
                const Text(
                  'Downpayment:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButton<DownPaymentType>(
                    value: _selectedDownPaymentType,
                    isExpanded: true,
                    items:
                        DownPaymentType.values.map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(type.displayName),
                          );
                        }).toList(),
                    onChanged: (DownPaymentType? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _selectedDownPaymentType = newValue;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),

            // Custom Downpayment Input (if custom is selected)
            if (_selectedDownPaymentType == DownPaymentType.custom) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _customDownPaymentController,
                decoration: const InputDecoration(
                  labelText: 'Custom Downpayment Amount',
                  border: OutlineInputBorder(),
                  prefixText: 'PHP ',
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  setState(() {
                    _customDownPaymentAmount = double.tryParse(value) ?? 0.0;
                  });
                },
              ),
            ],

            const SizedBox(height: 16),

            // Extra Cost Items Section (Chairs, Tables, etc.)
            _buildExtraCostItemsSection(selectedOrder.id),

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
                    onPressed:
                        () => _showPaymentConfirmationDialog(
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

  /// Staff “catering + event” rows: DB uses `catering_event`; some APIs use `event` or omit type when an event title exists.
  bool _isCateringPlusEventOrder(EventOrderDto o) {
    return isCateringPlusEventOrderType(o.orderType, eventTitle: o.eventTitle);
  }

  Widget _buildProcessingSeatingSection() {
    final role = AuthSession.instance.currentRole;
    if (role != Role.manager &&
        role != Role.supervisor &&
        role != Role.superAdmin) {
      return const SizedBox.shrink();
    }
    final o = _selectedProcessingOrderDto!;
    if (!_isCateringPlusEventOrder(o)) return const SizedBox.shrink();
    return ProcessingSeatingSection(order: o, onSaved: _refreshOrders);
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
                children:
                    selectedOrder.menu.map((m) {
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
                              child: const Icon(
                                Icons.fastfood,
                                color: Colors.grey,
                              ),
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
                                  // Show only PAX, no price
                                  Text(
                                    m.paxOption,
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
          (order as dynamic).orderNumber ??
          (order as dynamic).orderNo ??
          (order as dynamic).orderId;
      if (txn is String && txn.trim().isNotEmpty) return txn;
      if (txn is int) return txn.toString();
    } catch (_) {}
    return 'N/A';
  }

  Future<bool> _confirmOrderPayment(
    EventOrderDto order,
    PaymentConfirmationMode mode,
    PaymentService paymentService,
    String referenceNumber, {
    double? amount,
  }) async {
    try {
      setState(() => _paymentDialogLoading = true);
      // Use correct API for marking payments in post-analysis
      final paymentType =
          mode == PaymentConfirmationMode.fullPayment
              ? 'full_payment'
              : 'down_payment';
      await EventsApi.instance.updatePaymentStatus(
        orderId: order.id,
        paymentType: paymentType,
        status: 'paid',
        referenceNumber: referenceNumber,
        paymentMethod: paymentService.apiValue,
        amount: amount,
      );

      try {
        final isDown = mode == PaymentConfirmationMode.downpayment;
        final pdfData = buildOrderSummaryPdfData(
          order: order,
          isDownPayment: isDown,
          amountDue: amount,
        );
        final bytes = await buildOrderSummaryPdfBytes(pdfData);
        await EventsApi.instance.sendOrderSummaryEmail(
          orderId: order.id,
          pdfBase64: base64Encode(bytes),
          paymentType: paymentType,
        );
      } catch (_) {
        // Email is best-effort; payment already recorded.
      }

      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            mode == PaymentConfirmationMode.fullPayment
                ? 'Full payment marked as paid.'
                : 'Downpayment marked as paid.',
          ),
          backgroundColor: const Color(0xFF1DB954),
        ),
      );

      // Add extra cost items to checklist when payment is confirmed
      final extraItems = _extraCostItemsPerOrder[order.id] ?? [];
      if (extraItems.isNotEmpty) {
        for (final item in extraItems) {
          try {
            await EventsApi.instance.addChecklistItem(
              orderId: order.id,
              item: ChecklistItemDto(
                id: '',
                title: item.item,
                description: item.description,
                price: item.cost,
                assignedTo: '',
                isCompleted: item.isCompleted,
              ),
            );
          } catch (e) {
            // Continue even if one item fails
            continue;
          }
        }
        // Clear extra items after adding to checklist
        setState(() {
          _extraCostItemsPerOrder.remove(order.id);
        });
      }

      await _refreshOrders();
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

  double _orderTotalAmount(EventOrderDto order) {
    return order.totalCost > 0 ? order.totalCost : computeOrderTotalCost(order);
  }

  double _fullPaymentRemainingAmount(EventOrderDto order) {
    final total = _orderTotalAmount(order);
    if (order.downPaymentStatus == 'paid') {
      final paid =
          order.downPaymentAmount > 0 ? order.downPaymentAmount : total / 2;
      return (total - paid).clamp(0.0, double.infinity);
    }
    return total;
  }

  Future<void> _showDownpaymentConfirmationDialog(
    EventOrderDto order, {
    PaymentConfirmationMode mode = PaymentConfirmationMode.downpayment,
  }) async {
    var selectedPaymentService = PaymentService.cash;
    var downpaymentOption = DownpaymentAmountOption.percent50;
    var fullPaymentOption = FullPaymentAmountOption.remainingBalance;
    final referenceController = TextEditingController();
    final customAmountController = TextEditingController();
    final orderTotal = _orderTotalAmount(order);
    final remainingBalance = _fullPaymentRemainingAmount(order);

    if (mode == PaymentConfirmationMode.fullPayment) {
      customAmountController.text = remainingBalance.toStringAsFixed(2);
    }

    double resolvedDownpaymentAmount() {
      switch (downpaymentOption) {
        case DownpaymentAmountOption.percent50:
          return orderTotal / 2;
        case DownpaymentAmountOption.fullPayment:
          return orderTotal;
        case DownpaymentAmountOption.custom:
          return double.tryParse(customAmountController.text.trim()) ??
              orderTotal / 2;
      }
    }

    double resolvedFullPaymentAmount() {
      switch (fullPaymentOption) {
        case FullPaymentAmountOption.remainingBalance:
          return remainingBalance;
        case FullPaymentAmountOption.fullTotal:
          return orderTotal;
        case FullPaymentAmountOption.custom:
          return double.tryParse(customAmountController.text.trim()) ??
              remainingBalance;
      }
    }

    final isDownpayment = mode == PaymentConfirmationMode.downpayment;
    final title =
        isDownpayment ? 'Confirm downpayment' : 'Finalize full payment';
    final confirmLabel = isDownpayment ? 'Confirm' : 'Finalize';

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, dialogSetState) {
              final amount =
                  isDownpayment
                      ? resolvedDownpaymentAmount()
                      : resolvedFullPaymentAmount();
              return AlertDialog(
                title: Text(title),
                content: SizedBox(
                  width: 440,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isDownpayment) ...[
                          const Text(
                            'Downpayment amount',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<DownpaymentAmountOption>(
                            value: downpaymentOption,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: DownpaymentAmountOption.percent50,
                                child: Text('50% downpayment'),
                              ),
                              DropdownMenuItem(
                                value: DownpaymentAmountOption.custom,
                                child: Text('Custom amount'),
                              ),
                              DropdownMenuItem(
                                value: DownpaymentAmountOption.fullPayment,
                                child: Text('Full payment (100%)'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                dialogSetState(() => downpaymentOption = value);
                              }
                            },
                          ),
                          if (downpaymentOption ==
                              DownpaymentAmountOption.custom) ...[
                            const SizedBox(height: 12),
                            TextField(
                              controller: customAmountController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Custom amount (₱)',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (_) => dialogSetState(() {}),
                            ),
                          ],
                          const SizedBox(height: 16),
                        ] else ...[
                          const Text(
                            'Amount to pay',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<FullPaymentAmountOption>(
                            value: fullPaymentOption,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              DropdownMenuItem(
                                value: FullPaymentAmountOption.remainingBalance,
                                child: Text(
                                  'Remaining balance (${formatPesos(remainingBalance)})',
                                ),
                              ),
                              DropdownMenuItem(
                                value: FullPaymentAmountOption.fullTotal,
                                child: Text(
                                  'Full order total (${formatPesos(orderTotal)})',
                                ),
                              ),
                              const DropdownMenuItem(
                                value: FullPaymentAmountOption.custom,
                                child: Text('Custom amount'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                dialogSetState(() => fullPaymentOption = value);
                              }
                            },
                          ),
                          if (fullPaymentOption ==
                              FullPaymentAmountOption.custom) ...[
                            const SizedBox(height: 12),
                            TextField(
                              controller: customAmountController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Custom amount (₱)',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (_) => dialogSetState(() {}),
                            ),
                          ],
                          const SizedBox(height: 16),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          formatPesos(amount),
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFF4511E),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Payment method',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<PaymentService>(
                          value: selectedPaymentService,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                          ),
                          items:
                              PaymentService.values.map((service) {
                                return DropdownMenuItem(
                                  value: service,
                                  child: Text(service.displayName),
                                );
                              }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              dialogSetState(() {
                                selectedPaymentService = value;
                                referenceController.clear();
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Reference number',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: referenceController,
                          keyboardType:
                              selectedPaymentService.referenceDigitLength ==
                                      null
                                  ? TextInputType.text
                                  : TextInputType.number,
                          inputFormatters: [
                            if (selectedPaymentService.referenceDigitLength !=
                                null) ...[
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(
                                selectedPaymentService.referenceDigitLength!,
                              ),
                            ],
                          ],
                          decoration: InputDecoration(
                            hintText:
                                selectedPaymentService.referenceDigitLength ==
                                        null
                                    ? 'Enter reference number'
                                    : '${selectedPaymentService.referenceDigitLength}-digit reference number',
                            helperText:
                                selectedPaymentService.referenceDigitLength ==
                                        null
                                    ? 'No reference length limit for ${selectedPaymentService.displayName}.'
                                    : '${selectedPaymentService.displayName} requires exactly ${selectedPaymentService.referenceDigitLength} digits.',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) => dialogSetState(() {}),
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: TextButton(
                            onPressed: () => _showOrderSummaryDialog(order),
                            child: const Text('View order summary'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed:
                        _paymentDialogLoading
                            ? null
                            : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed:
                        _paymentDialogLoading
                            ? null
                            : () async {
                              final payAmount =
                                  isDownpayment
                                      ? resolvedDownpaymentAmount()
                                      : resolvedFullPaymentAmount();
                              if (payAmount <= 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Enter a valid amount.'),
                                  ),
                                );
                                return;
                              }
                              final reference = referenceController.text.trim();
                              final requiredReferenceLength =
                                  selectedPaymentService.referenceDigitLength;
                              if (requiredReferenceLength != null &&
                                  reference.length != requiredReferenceLength) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      '${selectedPaymentService.displayName} reference number must be exactly $requiredReferenceLength digits.',
                                    ),
                                  ),
                                );
                                return;
                              }
                              final confirmed = await _confirmOrderPayment(
                                order,
                                mode,
                                selectedPaymentService,
                                reference,
                                amount: payAmount,
                              );
                              if (confirmed && mounted) {
                                Navigator.of(context).pop();
                              }
                            },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1DB954),
                    ),
                    child:
                        _paymentDialogLoading
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
                            : Text(confirmLabel),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      referenceController.dispose();
      customAmountController.dispose();
    }
  }

  Future<void> _showFinalizeFullPaymentDialog(EventOrderDto order) {
    return _showDownpaymentConfirmationDialog(
      order,
      mode: PaymentConfirmationMode.fullPayment,
    );
  }

  @Deprecated('Use _showDownpaymentConfirmationDialog')
  Future<void> _showPaymentConfirmationDialog(
    EventOrderDto order,
    PaymentConfirmationMode mode,
  ) => _showDownpaymentConfirmationDialog(order, mode: mode);

  Future<void> _showOrderSummaryDialog(EventOrderDto order) async {
    final orderTotal = computeOrderTotalCost(order);
    await showDialog<void>(
      context: context,
      builder: (context) {
        final size = MediaQuery.sizeOf(context);
        return AlertDialog(
          title: const Text('Order Summary'),
          content: SizedBox(
            width: size.width * 0.92,
            height: size.height * 0.78,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: PagedDataTable(
                    title: 'Order Summary Items',
                    headingRowColor: WidgetStateProperty.all(
                      Colors.grey.shade200,
                    ),
                    columns: const [
                      DataColumn(label: Text('Set / Category')),
                      DataColumn(label: Text('Item')),
                      DataColumn(label: Text('Pax / Qty')),
                      DataColumn(label: Text('Details')),
                      DataColumn(label: Text('Unit Cost')),
                      DataColumn(label: Text('Total')),
                    ],
                    rows:
                        order.menu.map((m) {
                          final price = double.tryParse(m.price.trim()) ?? 0.0;
                          final details = <String>[
                            if (m.dishAllergens.trim().isNotEmpty)
                              'Allergens: ${m.dishAllergens.trim()}',
                          ].join('\n');
                          return DataRow(
                            cells: [
                              DataCell(
                                Text(
                                  m.setMenuName.trim().isEmpty
                                      ? 'A la carte'
                                      : m.setMenuName.trim(),
                                ),
                              ),
                              DataCell(Text(m.dishName.trim())),
                              DataCell(Text(m.paxOption.trim())),
                              DataCell(Text(details.isEmpty ? '—' : details)),
                              DataCell(Text(formatPesos(price))),
                              DataCell(Text(formatPesos(price))),
                            ],
                          );
                        }).toList(),
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

  List<ChecklistItem> _buildChecklistFromMenuWithIngredients(
    List<EventMenuItemDto> menu,
  ) {
    final items = <ChecklistItem>[];

    for (final menuItem in menu) {
      // Add the dish itself
      items.add(
        ChecklistItem(
          item: menuItem.dishName,
          description: menuItem.paxOption,
          quantity: 1,
          cost: double.tryParse(menuItem.price) ?? 0.0,
        ),
      );

      // Find the dish in MenuStore and add its ingredients
      final dish = MenuStore.instance.allDishes.cast<MenuDish?>().firstWhere(
        (d) => d?.name.toLowerCase() == menuItem.dishName.toLowerCase(),
        orElse: () => null,
      );

      if (dish != null && dish.ingredients.isNotEmpty) {
        for (final ingredient in dish.ingredients) {
          items.add(
            ChecklistItem(
              item: '  - $ingredient',
              description: 'Ingredient for ${menuItem.dishName}',
              quantity: 1,
              cost: 0.0,
              isCompleted: false,
            ),
          );
        }
      }
    }

    return items;
  }

  Future<void> _showChecklistDialog(EventOrderDto order) async {
    await DialogOpenGuard.runOnce(
      () => _showChecklistDialogBody(order),
      key: 'checklist:${order.id}',
    );
  }

  Future<void> _showChecklistDialogBody(EventOrderDto order) async {
    final List<ChecklistItem> editableItems =
        order.checklist.isEmpty
            ? _buildChecklistFromMenuWithIngredients(order.menu)
            : order.checklist
                .map(
                  (item) => ChecklistItem(
                    item: item.title,
                    description: item.description,
                    quantity: item.quantity,
                    cost: item.price,
                    isCompleted: item.isCompleted,
                  ),
                )
                .toList();

    final canEditChecklist =
        _isManager || AuthSession.instance.currentRole == Role.supervisor;
    final showInventoryPicker = _isManager && _isCateringPlusEventOrder(order);
    final inventoryOptions = <Map<String, dynamic>>[];
    if (showInventoryPicker) {
      try {
        final decoded = await ApiClient.instance.getJson('/api/inventory');
        final items = decoded['items'];
        if (items is List) {
          for (final raw in items) {
            if (raw is! Map) continue;
            if (raw['archived'] == true) continue;
            inventoryOptions.add(Map<String, dynamic>.from(raw));
          }
        }
      } catch (_) {}
    }

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, dialogSetState) {
            InputDecoration fieldDecoration(String label) => InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 10,
              ),
            );

            Widget buildChecklistRow(int index, ChecklistItem item) {
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child:
                              canEditChecklist
                                  ? TextFormField(
                                    key: ValueKey('item-$index-${item.item}'),
                                    initialValue: item.item,
                                    decoration: fieldDecoration('Item'),
                                    onChanged: (value) {
                                      dialogSetState(() {
                                        editableItems[index] = ChecklistItem(
                                          item: value,
                                          description: item.description,
                                          quantity: item.quantity,
                                          cost: item.cost,
                                          isCompleted: item.isCompleted,
                                          inventoryId: item.inventoryId,
                                        );
                                      });
                                    },
                                  )
                                  : Text(
                                    item.item,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 3,
                          child:
                              canEditChecklist
                                  ? TextFormField(
                                    key: ValueKey(
                                      'desc-$index-${item.description}',
                                    ),
                                    initialValue: item.description,
                                    decoration: fieldDecoration('Description'),
                                    onChanged: (value) {
                                      dialogSetState(() {
                                        editableItems[index] = ChecklistItem(
                                          item: item.item,
                                          description: value,
                                          quantity: item.quantity,
                                          cost: item.cost,
                                          isCompleted: item.isCompleted,
                                          inventoryId: item.inventoryId,
                                        );
                                      });
                                    },
                                  )
                                  : Text(item.description),
                        ),
                        if (canEditChecklist) ...[
                          const SizedBox(width: 4),
                          IconButton(
                            tooltip: 'Remove item',
                            onPressed: () {
                              dialogSetState(() {
                                editableItems.removeAt(index);
                              });
                            },
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        SizedBox(
                          width: 100,
                          child:
                              canEditChecklist
                                  ? TextFormField(
                                    key: ValueKey(
                                      'qty-$index-${item.quantity}',
                                    ),
                                    initialValue: item.quantity.toString(),
                                    decoration: fieldDecoration('Qty'),
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    onChanged: (value) {
                                      final newQuantity =
                                          int.tryParse(value) ?? item.quantity;
                                      dialogSetState(() {
                                        editableItems[index] = ChecklistItem(
                                          item: item.item,
                                          description: item.description,
                                          quantity: newQuantity,
                                          cost: item.cost,
                                          isCompleted: item.isCompleted,
                                          inventoryId: item.inventoryId,
                                        );
                                      });
                                    },
                                  )
                                  : Text('Qty: ${item.quantity}'),
                        ),
                        const SizedBox(width: 8),
                        if (_isManager) ...[
                          SizedBox(
                            width: 140,
                            child: TextFormField(
                              key: ValueKey('cost-$index-${item.cost}'),
                              initialValue: item.cost.toStringAsFixed(2),
                              decoration: fieldDecoration('Price/1').copyWith(
                                prefixText: '₱ ',
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              onChanged: (value) {
                                final newCost =
                                    double.tryParse(value) ?? item.cost;
                                dialogSetState(() {
                                  editableItems[index] = ChecklistItem(
                                    item: item.item,
                                    description: item.description,
                                    quantity: item.quantity,
                                    cost: newCost,
                                    isCompleted: item.isCompleted,
                                    inventoryId: item.inventoryId,
                                  );
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Total ₱${(item.cost * item.quantity).toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ] else ...[
                          Text(formatPesos(item.cost)),
                        ],
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color:
                                item.isCompleted
                                    ? Colors.green.shade50
                                    : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color:
                                  item.isCompleted ? Colors.green : Colors.red,
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<bool>(
                              value: item.isCompleted,
                              isDense: true,
                              items: const [
                                DropdownMenuItem(
                                  value: true,
                                  child: Text('completed'),
                                ),
                                DropdownMenuItem(
                                  value: false,
                                  child: Text('not done'),
                                ),
                              ],
                              onChanged: (value) {
                                if (value == null) return;
                                dialogSetState(() {
                                  editableItems[index] = ChecklistItem(
                                    item: item.item,
                                    description: item.description,
                                    quantity: item.quantity,
                                    cost: item.cost,
                                    isCompleted: value,
                                    inventoryId: item.inventoryId,
                                  );
                                });
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }

            return AlertDialog(
              backgroundColor: const Color(0xFFF7F8FA),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text('Checklist for ${order.eventTitle}'),
              content: SizedBox(
                width: 920,
                height: 560,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Event Checklist',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed:
                              () => _exportChecklistToPDF(
                                order,
                                editableItems,
                              ),
                          icon: const Icon(Icons.picture_as_pdf, size: 18),
                          label: const Text('Print PDF'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child:
                          editableItems.isEmpty
                              ? Center(
                                child: Text(
                                  'No checklist items yet.',
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                              )
                              : ListView.builder(
                                itemCount: editableItems.length,
                                itemBuilder: (context, index) {
                                  return buildChecklistRow(
                                    index,
                                    editableItems[index],
                                  );
                                },
                              ),
                    ),
                    if (canEditChecklist) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed:
                                        () => _addNewChecklistItem(
                                          dialogSetState,
                                          editableItems,
                                        ),
                                    icon: const Icon(Icons.add),
                                    label: const Text('Add non-inventory item'),
                                  ),
                                ),
                              ],
                            ),
                            if (showInventoryPicker &&
                                inventoryOptions.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              DropdownButtonFormField<String>(
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Add from inventory',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                hint: const Text('Select inventory item'),
                                items:
                                    inventoryOptions
                                        .map(
                                          (row) => DropdownMenuItem<String>(
                                            value: row['id']?.toString(),
                                            child: Text(
                                              '${row['name']} (${row['quantity']} ${row['unit']})',
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        )
                                        .toList(),
                                onChanged: (id) {
                                  if (id == null) return;
                                  final row = inventoryOptions.firstWhere(
                                    (r) => r['id']?.toString() == id,
                                  );
                                  final unitCost =
                                      row['unitCost'] is num
                                          ? (row['unitCost'] as num).toDouble()
                                          : double.tryParse(
                                                '${row['unitCost']}',
                                              ) ??
                                              0;
                                  dialogSetState(() {
                                    editableItems.add(
                                      ChecklistItem(
                                        item: '${row['name']}',
                                        description:
                                            (row['category'] ?? 'Inventory')
                                                .toString(),
                                        quantity: 1,
                                        cost: unitCost,
                                        inventoryId: id,
                                      ),
                                    );
                                  });
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                  ),
                  child: const Text('Cancel'),
                ),
                OutlinedButton(
                  onPressed: () => _saveChecklist(order, editableItems),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.green,
                    side: const BorderSide(color: Colors.green),
                  ),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _cancelProcessingOrder(EventOrderDto order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Close button
                  Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      icon: const Icon(Icons.close, color: Colors.black),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Title
                  const Text(
                    'CANCEL ORDER',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Are you sure you want to cancel the order for ${order.customerName}?',
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 24),
                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'YES, CANCEL',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey.shade300,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'NO',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
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
      setState(() => _selectedStatus = EventStatus.forFullPayment);
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

  Future<void> _createAutoCollage() async {
    if (_themePicks.isEmpty) return;

    setState(() {
      _isAiProcessingTheme = true;
    });

    try {
      // Simulate auto collage creation
      await Future.delayed(const Duration(seconds: 2));

      // Create a simple grid collage by arranging photos
      final collageOrder = <Uint8List>[];
      for (int i = 0; i < _themePicks.length; i++) {
        collageOrder.add(_themePicks[i]);
      }

      setState(() {
        _collageOrder = collageOrder;
        _isAiProcessingTheme = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Auto collage created successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
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
            content: Text('Failed to create auto collage: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showThemeDesignDialog() async {
    final selectedOrder =
        _selectedStatus == EventStatus.newEvent
            ? null
            : _selectedProcessingOrderDto;
    final isForProcessingReadOnly = selectedOrder?.status == 'for_processing';
    if (isForProcessingReadOnly && selectedOrder != null) {
      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: const Color(0xFFF7F8FA),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            title: const Text('Events Theme Design'),
            content: SizedBox(
              width: 760,
              height: 520,
              child: SingleChildScrollView(
                child: _buildEventDesignDetailSection(selectedOrder),
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
      return;
    }

    // Same AI theme design experience as the customer inquire flow.
    final userEmail =
        AuthSession.instance.currentUser.value?.email.trim() ??
        'staff@curatering.com';
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder:
            (_) => EventThemeDesignScreen(
              apiBase: apiBaseUrl,
              userEmail: userEmail,
              initialEventType: _eventType ?? 'Birthday',
              eventTitle: _eventTitleController.text.trim().isEmpty
                  ? null
                  : _eventTitleController.text.trim(),
              formalityLevel:
                  _formalityLevel == null ? null : _formalityLevel!.displayName,
              initialThemeDesign: _aiThemeDesignPayload,
              persistToOrder: false,
            ),
      ),
    );
    if (result == null || !mounted) return;

    setState(() {
      _aiThemeDesignPayload = Map<String, dynamic>.from(result);
    });

    final imageUrl =
        '${result['generatedImageUrl'] ?? result['imageUrl'] ?? ''}'.trim();
    if (imageUrl.isNotEmpty) {
      try {
        final res = await http.get(Uri.parse(imageUrl));
        if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
          final bytes = Uint8List.fromList(res.bodyBytes);
          final key = _themeImageKey(bytes);
          if (mounted) {
            setState(() {
              _themePicks
                ..clear()
                ..add(bytes);
              _themePickHashes
                ..clear()
                ..add(key);
              _collageOrder = _themePicks.toList();
              _focusedPickIndex = 0;
            });
          }
        }
      } catch (_) {
        /* preview download optional */
      }
    }
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
                children:
                    orderDtos
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
                children:
                    _selectedPostAnalysisOrderDto!.menu.map((m) {
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
                              child: const Icon(
                                Icons.fastfood,
                                color: Colors.grey,
                              ),
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
                                    m.paxOption,
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
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
            // Payment Processing Section
            if (!_isSupervisor) ...[
              const Text(
                'Payment Processing',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if (selPost == null)
                Text(
                  'Select an order to process payments.',
                  style: TextStyle(color: Colors.grey.shade600),
                )
              else ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      // Downpayment Type Selection
                      Row(
                        children: [
                          const Text(
                            'Downpayment Type:',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButton<DownPaymentType>(
                              value: _selectedDownPaymentType,
                              isExpanded: true,
                              items:
                                  DownPaymentType.values.map((type) {
                                    return DropdownMenuItem<DownPaymentType>(
                                      value: type,
                                      child: Text(type.displayName),
                                    );
                                  }).toList(),
                              onChanged: (DownPaymentType? newValue) {
                                if (newValue != null) {
                                  setState(() {
                                    _selectedDownPaymentType = newValue;
                                    _calculateDownPaymentAmount();
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),

                      // Custom Downpayment Input (if custom is selected)
                      if (_selectedDownPaymentType ==
                          DownPaymentType.custom) ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: _customDownPaymentController,
                          decoration: const InputDecoration(
                            labelText: 'Custom Downpayment Amount',
                            border: OutlineInputBorder(),
                            prefixText: 'PHP ',
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (value) {
                            setState(() {
                              _customDownPaymentAmount =
                                  double.tryParse(value) ?? 0.0;
                            });
                          },
                        ),
                      ],

                      const SizedBox(height: 12),

                      // Payment Summary
                      _buildPaymentRow(
                        'Down Payment:',
                        '${_getCalculatedDownPaymentAmount().toStringAsFixed(2)}',
                        selPost.downPaymentStatus,
                      ),
                      const SizedBox(height: 8),
                      _buildPaymentRow(
                        'Full Payment:',
                        '${_getCalculatedFullPaymentAmount().toStringAsFixed(2)}',
                        selPost.fullPaymentStatus,
                      ),
                      const SizedBox(height: 8),
                      _buildPaymentRow(
                        'Total Cost:',
                        '${selPost.totalCost.toStringAsFixed(2)}',
                        'calculated',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed:
                            selPost.downPaymentStatus == 'paid'
                                ? null
                                : () => _showPaymentConfirmationDialog(
                                  selPost,
                                  PaymentConfirmationMode.downpayment,
                                ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              selPost.downPaymentStatus == 'paid'
                                  ? Colors.grey
                                  : Colors.green,
                        ),
                        child: Text('Mark Down Payment as Paid'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed:
                            selPost.fullPaymentStatus == 'paid'
                                ? null
                                : () => _showPaymentConfirmationDialog(
                                  selPost,
                                  PaymentConfirmationMode.fullPayment,
                                ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              selPost.fullPaymentStatus == 'paid'
                                  ? Colors.grey
                                  : Colors.green,
                        ),
                        child: Text('Mark Full Payment as Paid'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ],

            // Actual Event Photos Section - Only for catering+event orders
            if (!_isSupervisor &&
                selPost != null &&
                _isCateringPlusEventOrder(selPost)) ...[
              const Text(
                'Actual Event Photos',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    if (selPost.actualEventImages.isEmpty)
                      Column(
                        children: [
                          Icon(
                            Icons.photo_library_outlined,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No event photos uploaded yet',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: () => _uploadEventPhotos(selPost),
                            icon: const Icon(Icons.upload),
                            label: const Text('Upload Photos'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      )
                    else
                      Column(
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children:
                                selPost.actualEventImages.asMap().entries.map((
                                  entry,
                                ) {
                                  final index = entry.key;
                                  final imageUrl = entry.value;
                                  return Stack(
                                    children: [
                                      Container(
                                        width: 80,
                                        height: 80,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: Colors.grey.shade300,
                                          ),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            7,
                                          ),
                                          child:
                                              imageUrl.startsWith('http')
                                                  ? Image.network(
                                                    imageUrl,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (
                                                      context,
                                                      error,
                                                      stackTrace,
                                                    ) {
                                                      return Container(
                                                        color:
                                                            Colors
                                                                .grey
                                                                .shade200,
                                                        child: const Icon(
                                                          Icons.broken_image,
                                                        ),
                                                      );
                                                    },
                                                  )
                                                  : Image.memory(
                                                    Uint8List.fromList(
                                                      imageUrl.codeUnits,
                                                    ),
                                                    fit: BoxFit.cover,
                                                  ),
                                        ),
                                      ),
                                      Positioned(
                                        top: 4,
                                        right: 4,
                                        child: GestureDetector(
                                          onTap:
                                              () => _removeEventPhoto(
                                                selPost,
                                                index,
                                              ),
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: Colors.red,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: const Icon(
                                              Icons.close,
                                              size: 12,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: () => _uploadEventPhotos(selPost),
                            icon: const Icon(Icons.add_photo_alternate),
                            label: const Text('Add More Photos'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

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
                  onPressed:
                      _postAnalysisSaving
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
                  child:
                      _postAnalysisSaving
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

  Widget _buildProcessingOrdersListSection(List<EventOrderDto> orders) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildSectionTitle('FOR PROCESSING'),
                const Spacer(),
                IconButton(
                  tooltip: 'Refresh processing orders',
                  onPressed: _ordersLoading ? null : _refreshOrdersFromButton,
                  icon:
                      _ordersLoading
                          ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.refresh),
                ),
              ],
            ),
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
            if (orders.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text(
                    'No orders ready for processing.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              )
            else
              Column(
                children:
                    orders.map((dto) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildSelectableOrderCard(
                          dto,
                          _selectedProcessingOrderDto?.id == dto.id,
                          (d) => setState(() {
                            _selectedProcessingOrderDto = d;
                            _selectedPostAnalysisOrderDto = null;
                          }),
                        ),
                      );
                    }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostAnalysisOrdersListSection(List<EventOrderDto> orders) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildSectionTitle('POST-ANALYSIS'),
                const Spacer(),
                IconButton(
                  tooltip: 'Refresh orders',
                  onPressed: _ordersLoading ? null : _refreshOrdersFromButton,
                  icon:
                      _ordersLoading
                          ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.refresh),
                ),
              ],
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
            if (orders.isEmpty)
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
                children:
                    orders.map((dto) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildSelectableOrderCard(
                          dto,
                          _selectedPostAnalysisOrderDto?.id == dto.id,
                          (d) => setState(() {
                            _selectedPostAnalysisOrderDto = d;
                            _selectedProcessingOrderDto = null;
                            _syncPostAnalysisFields(d);
                          }),
                        ),
                      );
                    }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCombinedDetailsSection() {
    // Show Processing details if a processing order is selected
    if (_selectedProcessingOrderDto != null) {
      return Column(
        children: [
          _buildEventInformationSection(),
          const SizedBox(height: 20),
          _buildProcessingMenuSection(),
        ],
      );
    }

    // Show Post-Analysis details if a post-analysis order is selected
    if (_selectedPostAnalysisOrderDto != null) {
      return _buildPostAnalysisDetailsSection();
    }

    // No order selected
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Text(
            'Select an order from either list to view details.',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ),
      ),
    );
  }

  Widget _buildPostAnalysisDetailsSection() {
    final selPost = _selectedPostAnalysisOrderDto!;
    final postTotal = computeOrderTotalCost(selPost);
    final postDown = postTotal > 0 ? postTotal / 2 : 0.0;

    return Column(
      children: [
        // Menu Section
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
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
                Column(
                  children:
                      selPost.menu.map((m) {
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
                                child: const Icon(
                                  Icons.fastfood,
                                  color: Colors.grey,
                                ),
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
                                      m.paxOption,
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
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
        ),
        const SizedBox(height: 20),
        // Info Section
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!_isSupervisor) ...[
                  const Text(
                    'Payment Processing',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        _buildPaymentRow(
                          'Down Payment:',
                          '${selPost.downPaymentAmount.toStringAsFixed(2)}',
                          selPost.downPaymentStatus,
                        ),
                        const SizedBox(height: 8),
                        _buildPaymentRow(
                          'Full Payment:',
                          '${selPost.fullPaymentAmount.toStringAsFixed(2)}',
                          selPost.fullPaymentStatus,
                        ),
                        const SizedBox(height: 8),
                        _buildPaymentRow(
                          'Total Cost:',
                          '${selPost.totalCost.toStringAsFixed(2)}',
                          'calculated',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed:
                              selPost.downPaymentStatus == 'paid'
                                  ? null
                                  : () => _showPaymentConfirmationDialog(
                                    selPost,
                                    PaymentConfirmationMode.downpayment,
                                  ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                selPost.downPaymentStatus == 'paid'
                                    ? Colors.grey
                                    : Colors.green,
                          ),
                          child: const Text('Mark Down Payment as Paid'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed:
                              selPost.fullPaymentStatus == 'paid'
                                  ? null
                                  : () => _showPaymentConfirmationDialog(
                                    selPost,
                                    PaymentConfirmationMode.fullPayment,
                                  ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                selPost.fullPaymentStatus == 'paid'
                                    ? Colors.grey
                                    : Colors.green,
                          ),
                          child: const Text('Mark Full Payment as Paid'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                const Text(
                  'Other Info',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
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
                    onPressed:
                        _postAnalysisSaving
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
                    child:
                        _postAnalysisSaving
                            ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Text('Done'),
                  ),
                ),
                const SizedBox(height: 16),
                _buildCostBlock(
                  'Cost Estimation',
                  formatPesos(postTotal),
                  Colors.orange,
                ),
                const SizedBox(height: 8),
                _buildCostBlock(
                  'Downpayment',
                  formatPesos(postDown),
                  Colors.blue,
                ),
                const SizedBox(height: 8),
                _buildCostBlock(
                  'Total Cost',
                  formatPesos(postTotal),
                  Colors.green,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompletedEventsView(bool isNarrow) {
    // Filter completed orders to only show those from last 1 month
    final oneMonthAgo = DateTime.now().subtract(const Duration(days: 30));
    final orderDtos =
        _completedOrdersDto.where((dto) {
          if (dto.scheduleSlots.isEmpty) return false;
          final eventDate = _tryParseDate(dto.scheduleSlots.first.date);
          if (eventDate == null) return false;
          return eventDate.isAfter(oneMonthAgo) ||
              eventDate.isAtSameMomentAs(oneMonthAgo);
        }).toList();

    return SingleChildScrollView(
      child: _buildOrdersTablePanel(
        title: 'Completed & cancelled events',
        orders: orderDtos,
        emptyMessage: 'No completed or cancelled events in the last 30 days.',
        actionCells:
            (dto) => [
              _eventIconAction(
                icon: Icons.visibility_outlined,
                tooltip: 'View details',
                permissionKey: ActionPermissionKeys.manageEventsViewDetails,
                onPressed: () => _showEventOrderDetailModal(dto),
              ),
              _eventIconAction(
                icon: Icons.receipt_long_outlined,
                tooltip: 'Order summary',
                permissionKey: ActionPermissionKeys.manageEventsViewDetails,
                onPressed: () => _showOrderSummaryDialog(dto),
              ),
            ],
      ),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3D0),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Color(0xFF2E2E2E),
          letterSpacing: 0.2,
        ),
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
        color: color.withValues(alpha: 0.1),
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
      case EventStatus.forDownpayment:
        return _buildForDownpaymentTableView(isNarrow);
      case EventStatus.ongoing:
        return _buildOngoingTableView(isNarrow);
      case EventStatus.forFullPayment:
        return _buildForFullPaymentTableView(isNarrow);
      case EventStatus.completed:
        return _buildCompletedEventsView(isNarrow);
      case EventStatus.newEvent:
        return Row(
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
                    _buildEventMenuSection(),
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
              onPressed:
                  _isSubmittingOrder
                      ? null
                      : () async {
                        // Clear previous errors
                        setState(() {
                          _contactNumberError = null;
                          _emailError = null;
                          _guestCountError = null;
                        });

                        final missing = <String>[];
                        final isCateringOnly = _orderType == 'catering';

                        if (_orderType == null) missing.add('Service type');

                        // Only validate event-specific fields for catering + event orders
                        if (!isCateringOnly) {
                          if (_eventTitleController.text.trim().isEmpty) {
                            missing.add('Event title');
                          }
                          if (_eventType == null) missing.add('Event type');
                          if (_formalityLevel == null)
                            missing.add('Formality level');
                        }

                        if (_customerController.text.trim().isEmpty) {
                          missing.add('Customer name');
                        }
                        if (_contactPersonController.text.trim().isEmpty) {
                          missing.add('Contact person');
                        }

                        // Contact number validation
                        final contactNumber =
                            _contactNumberController.text.trim();
                        if (contactNumber.isEmpty) {
                          missing.add('Contact number');
                        } else if (contactNumber.length < 10) {
                          setState(() {
                            _contactNumberError =
                                'Contact number must be at least 10 digits';
                          });
                          return;
                        }

                        // Email validation
                        final email = _emailController.text.trim();
                        if (email.isEmpty) {
                          missing.add('Email address');
                        } else if (!_isValidEmail(email)) {
                          setState(() {
                            _emailError = 'Please enter a valid email address';
                          });
                          return;
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
                          setState(() {
                            _guestCountError =
                                'Please enter a valid number of guests';
                          });
                          return;
                        }

                        if (_menuItems.isEmpty) {
                          missing.add('Menu');
                        } else if (_menuItems.length < 4) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Select at least 4 dishes for the menu.',
                              ),
                            ),
                          );
                          return;
                        }

                        // Only validate theme picks for catering + event orders
                        if (!isCateringOnly && _themePicks.isEmpty)
                          missing.add('Theme picks');

                        if (missing.isNotEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Please complete: ${missing.join(', ')}',
                              ),
                            ),
                          );
                          return;
                        }

                        setState(() {
                          _isSubmittingOrder = true;
                        });

                        try {
                          final payload = _buildPayloadFromForm();

                          // backend commit
                          await EventsApi.instance
                              .managerSubmitNewEventToProcessing(
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
                          setState(
                            () => _selectedStatus = EventStatus.forDownpayment,
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Failed to submit order.'),
                            ),
                          );
                        } finally {
                          setState(() {
                            _isSubmittingOrder = false;
                          });
                        }
                      },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1DB954),
              ),
              child:
                  _isSubmittingOrder
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
                      : const Text('SUBMIT'),
            ),
          ],
        ),
      ),
    );
  }

  // Event Management Page
  Widget _buildEventForm() {
    final isCateringOnly = _orderType == 'catering';

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
                  filled: isCateringOnly,
                  fillColor: isCateringOnly ? Colors.grey.shade200 : null,
                  disabledBorder:
                      isCateringOnly
                          ? OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.grey.shade400),
                          )
                          : null,
                ),
                enabled: !isCateringOnly,
              ),
              const SizedBox(height: 12),
              // Service type radio buttons
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Service Type',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: RadioListTile<String>(
                          title: const Text('Catering Only'),
                          value: 'catering',
                          groupValue: _orderType,
                          onChanged: (value) {
                            setState(() {
                              _orderType = value;
                              // Clear event-specific fields when switching to catering only
                              if (value == 'catering') {
                                _eventTitleController.clear();
                                _eventType = null;
                                _formalityLevel = null;
                              }
                            });
                          },
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<String>(
                          title: const Text('Catering + Event'),
                          value: 'catering_event',
                          groupValue: _orderType,
                          onChanged: (value) {
                            setState(() {
                              _orderType = value;
                            });
                          },
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value:
                          _eventTypes.contains(_eventType) ? _eventType : null,
                      items:
                          _eventTypes
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
                        filled: isCateringOnly,
                        fillColor: isCateringOnly ? Colors.grey.shade200 : null,
                        disabledBorder:
                            isCateringOnly
                                ? OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade400,
                                  ),
                                )
                                : null,
                      ),
                      onChanged:
                          isCateringOnly
                              ? null
                              : (value) {
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
                      textCapitalization: TextCapitalization.words,
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(50),
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[a-zA-Z\s]'),
                        ),
                        TextInputFormatter.withFunction((oldValue, newValue) {
                          final text = newValue.text.trim();
                          if (text.isEmpty) return newValue;
                          final words = text.split(' ');
                          final capitalizedWords = words
                              .map((word) {
                                if (word.isEmpty) return '';
                                return word[0].toUpperCase() +
                                    word.substring(1).toLowerCase();
                              })
                              .join(' ');
                          return TextEditingValue(
                            text: capitalizedWords,
                            selection: newValue.selection,
                            composing: newValue.composing,
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<EventFormalityLevel>(
                value: _formalityLevel,
                items:
                    EventFormalityLevel.values
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
                  filled: isCateringOnly,
                  fillColor: isCateringOnly ? Colors.grey.shade200 : null,
                  disabledBorder:
                      isCateringOnly
                          ? OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.grey.shade400),
                          )
                          : null,
                ),
                onChanged:
                    isCateringOnly
                        ? null
                        : (value) {
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
                      textCapitalization: TextCapitalization.words,
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(50),
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[a-zA-Z\s]'),
                        ),
                        TextInputFormatter.withFunction((oldValue, newValue) {
                          final text = newValue.text.trim();
                          if (text.isEmpty) return newValue;
                          final words = text.split(' ');
                          final capitalizedWords = words
                              .map((word) {
                                if (word.isEmpty) return '';
                                return word[0].toUpperCase() +
                                    word.substring(1).toLowerCase();
                              })
                              .join(' ');
                          return TextEditingValue(
                            text: capitalizedWords,
                            selection: newValue.selection,
                            composing: newValue.composing,
                          );
                        }),
                      ],
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
                        errorText: _contactNumberError,
                      ),
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(11),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _contactNumberError = null;
                        });
                      },
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
                        errorText: _emailError,
                      ),
                      keyboardType: TextInputType.emailAddress,
                      onChanged: (value) {
                        setState(() {
                          _emailError = null;
                        });
                      },
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
                            children:
                                _eventScheduleSlots.asMap().entries.map((e) {
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
                        errorText: _guestCountError,
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(3),
                      ],
                      onChanged: (value) {
                        if (value.isNotEmpty) {
                          if (int.parse(value) >= 500) {
                            _guestCountController.text = "500";
                          }
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              AllergenSelectorField(
                initialSerialized: _allergensSerialized,
                onChanged: (s) => _allergensSerialized = s,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Menu View
  Widget _buildEventMenuSection() {
    final isCateringOnly = _orderType == 'catering';

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
          child:
              _menuItems.isEmpty
                  ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: const [
                      Text("You don't have anything on the menu right now..."),
                      SizedBox(height: 20),
                      SizedBox(height: 30),
                    ],
                  )
                  : Column(
                    children:
                        _menuItems.map((item) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${item.dish.name} · ${item.paxOption}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Text(
                                  item.dish.price,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
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
            onPressed: isCateringOnly ? null : _showThemeDesignDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  isCateringOnly
                      ? Colors.grey.shade400
                      : const Color(0xFF1DB954),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              isCateringOnly
                  ? 'EVENTS THEME DESIGN (Not Available for Catering Only)'
                  : 'EVENTS THEME DESIGN',
              style: TextStyle(
                color: isCateringOnly ? Colors.grey.shade600 : Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Selected Dish View
  Widget _buildDishCard(MenuDish dish) {
    final selectedPax =
        _selectedPaxPerDish[dish.name] ??
        (dish.paxOptions.isNotEmpty ? dish.paxOptions.first : 1);

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
              children:
                  dish.paxOptions.map((option) {
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
      showSearch: false,
      child: Container(
        color: const Color(0xFFF7F8FA),
        padding: const EdgeInsets.all(20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 1100;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Manage Events',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1F1F1F),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Track inquiries, process events, and finalize outcomes.',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.black.withValues(alpha: 0.08),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      children: [
                        if (!_isSupervisor) ...[
                          _buildEventTabButton('New Event', 0),
                          const SizedBox(width: 2),
                          _buildEventTabButton('Online Inquiries', 1),
                          const SizedBox(width: 2),
                          _buildEventTabButton('For Downpayment', 2),
                          const SizedBox(width: 2),
                        ],
                        _buildEventTabButton('Ongoing', 3),
                        if (!_isSupervisor) ...[
                          const SizedBox(width: 2),
                          _buildEventTabButton('For Full Payment', 4),
                          const SizedBox(width: 2),
                          _buildEventTabButton('Completed', 5),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child:
                      _selectedStatus.index == 0
                          ? _buildBodyContent(EventStatus.newEvent, isNarrow)
                          : _selectedStatus.index == 1
                          ? _buildBodyContent(
                            EventStatus.onlineInquiries,
                            isNarrow,
                          )
                          : _selectedStatus.index == 2
                          ? _buildBodyContent(
                            EventStatus.forDownpayment,
                            isNarrow,
                          )
                          : _selectedStatus.index == 3
                          ? _buildBodyContent(EventStatus.ongoing, isNarrow)
                          : _selectedStatus.index == 4
                          ? _buildBodyContent(
                            EventStatus.forFullPayment,
                            isNarrow,
                          )
                          : _buildBodyContent(EventStatus.completed, isNarrow),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildFoodBrowser() {
    final cateringDishes =
        _allDishes
            .where(
              (d) =>
                  d.category.toLowerCase().trim() == 'catering' &&
                  !d.archived &&
                  d.available,
            )
            .toList();
    final sets = SetMenuStore.instance.activeSetMenus;
    final filtered =
        cateringDishes.where((d) {
          if (_foodSearchController.text.trim().isEmpty) return true;
          return d.name.toLowerCase().contains(
            _foodSearchController.text.trim().toLowerCase(),
          );
        }).toList();

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
        const SizedBox(height: 8),
        Text(
          'Choose 5–8 dishes (all dishes) or pick one premade set menu.',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
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
                TabBar(
                  controller: _foodTabController,
                  labelColor: const Color(0xFF1E1E1E),
                  indicatorColor: const Color(0xFFFFC024),
                  tabs: const [
                    Tab(text: 'All dishes'),
                    Tab(text: 'Set menu dishes'),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 340,
                  child: TabBarView(
                    controller: _foodTabController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
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
                          const SizedBox(height: 8),
                          Text(
                            '${_menuItems.length}/8 dishes selected (min 4)',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child:
                                filtered.isEmpty
                                    ? Center(
                                      child: Text(
                                        'No dishes match your search.',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    )
                                    : ListView(
                                      children:
                                          filtered
                                              .map(
                                                (dish) => Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        bottom: 12,
                                                      ),
                                                  child: _buildDishCard(dish),
                                                ),
                                              )
                                              .toList(),
                                    ),
                          ),
                        ],
                      ),
                      ListView.builder(
                        itemCount: sets.length,
                        itemBuilder: (context, i) {
                          final s = sets[i];
                          final names = s.dishIds
                              .map((id) {
                                for (final d in cateringDishes) {
                                  if (d.id == id) return d.name;
                                }
                                return id;
                              })
                              .join(', ');
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text(s.name),
                              subtitle: Text(
                                s.dishIds.isEmpty ? 'No dishes' : names,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: AntdPrimaryButton(
                                label: 'Use set',
                                onPressed:
                                    s.dishIds.isEmpty
                                        ? null
                                        : () => _applySetMenuToNewEvent(s),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentRow(String label, String amount, String status) {
    Color statusColor = Colors.grey;
    if (status == 'paid') {
      statusColor = Colors.green;
    } else if (status == 'pending') {
      statusColor = Colors.orange;
    } else if (status == 'overdue') {
      statusColor = Colors.red;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        Row(
          children: [
            Text(
              amount,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: statusColor),
              ),
              child: Text(
                status.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _uploadEventPhotos(EventOrderDto order) async {
    try {
      // For now, just show a placeholder dialog
      await showDialog<void>(
        context: context,
        builder:
            (context) => Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 420),
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Close button
                    Align(
                      alignment: Alignment.topRight,
                      child: IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Colors.black),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Title
                    const Text(
                      'UPLOAD EVENT PHOTOS',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Photo upload functionality will be implemented here.',
                      style: TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 24),
                    // Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFC024),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'CLOSE',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to open photo upload'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _removeEventPhoto(EventOrderDto order, int photoIndex) async {
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder:
            (context) => Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 420),
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Close button
                    Align(
                      alignment: Alignment.topRight,
                      child: IconButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        icon: const Icon(Icons.close, color: Colors.black),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Title
                    const Text(
                      'REMOVE PHOTO',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Are you sure you want to remove this photo?',
                      style: TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 24),
                    // Buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'REMOVE',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey.shade300,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'CANCEL',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
      );

      if (confirmed != true) return;

      // Update backend
      await EventsApi.instance.removeEventPhoto(
        orderId: order.id,
        photoIndex: photoIndex,
      );

      // Refresh orders
      await _refreshOrders();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo removed successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to remove photo'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _addNewChecklistItem(
    StateSetter dialogSetState,
    List<ChecklistItem> editableItems,
  ) {
    dialogSetState(() {
      editableItems.add(
        ChecklistItem(
          item: 'New Item',
          description: 'Enter description',
          quantity: 1,
          cost: 0.0,
        ),
      );
    });
  }

  Future<void> _saveChecklist(
    EventOrderDto order,
    List<ChecklistItem> editableItems,
  ) async {
    try {
      if (!mounted) return;

      await EventsApi.instance.replaceChecklist(
        orderId: order.id,
        deductInventory: _isCateringPlusEventOrder(order),
        items:
            editableItems
                .map(
                  (item) => {
                    'item': item.item,
                    'title': item.item,
                    'description': item.description,
                    'quantity': item.quantity,
                    'cost': item.cost,
                    'price': item.cost,
                    'isCompleted': item.isCompleted,
                    if (item.inventoryId != null)
                      'inventoryId': item.inventoryId,
                  },
                )
                .toList(),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Checklist saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      // Refresh orders
      await _refreshOrders();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save checklist: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _exportChecklistToPDF(
    EventOrderDto order,
    List<ChecklistItem> editableItems,
  ) async {
    try {
      final lines =
          editableItems
              .map(
                (item) => ChecklistPdfLine(
                  item: item.item,
                  description: item.description,
                  quantity: item.quantity,
                  cost: item.cost,
                  isCompleted: item.isCompleted,
                ),
              )
              .toList();
      final bytes = await buildChecklistPdfBytes(order: order, items: lines);
      final safeTitle =
          order.eventTitle
              .replaceAll(RegExp(r'[^\w\s-]'), '')
              .trim()
              .replaceAll(RegExp(r'\s+'), '-');
      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: '${safeTitle.isEmpty ? 'event' : safeTitle}-checklist.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate PDF: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
