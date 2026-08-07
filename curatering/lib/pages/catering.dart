import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:printing/printing.dart';
import '../features/event_design/event_theme_design_screen.dart';
import '../features/seating/seating_layout_editor_screen.dart';
import '../auth/action_permissions.dart';
import '../auth/auth_session.dart';
import '../config.dart';
import '../auth/roles.dart';
import '../models/event_order.dart';
import '../models/menu_dish.dart';
import '../services/api_client.dart';
import '../services/events_api.dart';
import '../services/manager_catering_api.dart';
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
import '../widgets/inquiry_menu_selection_dialog.dart';
import '../utils/inquiry_pricing.dart';
import '../utils/order_calculations.dart';
import '../utils/order_type_utils.dart';
import '../utils/web_html.dart' as html;
import 'customer_website.dart';

part 'catering_manage_events_part.dart';
part 'catering_manage_events_detail_part.dart';
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

enum _NewEventSideTab { eventInfo, menuAndAllergens, submitAndCosts }

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
    with TickerProviderStateMixin {
  late TabController _tabController;
  bool _showNewEventForm = false;
  _NewEventSideTab _activeNewEventSideTab = _NewEventSideTab.eventInfo;
  int _newEventMenuPrefTabIndex = 0;

  static const _stageKeys = [
    'new_event',
    'online_inquiries',
    'for_down_payment',
    'on_going',
    'for_full_payment',
    'completed',
    'cancelled',
  ];
  static const _stageLabels = [
    'New Event',
    'Online Inquiries',
    'For Down Payment',
    'On Going',
    'For Full Payment',
    'Completed',
    'Cancelled',
  ];
  static const _supervisorStageLabels = ['On Going'];

  List<String> get _visibleStageLabels =>
      _isSupervisor ? _supervisorStageLabels : _stageLabels;

  int get _tabCount => _visibleStageLabels.length;

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
  List<EventOrderDto> _cancelledOrdersDto = const <EventOrderDto>[];
  EventOrderDto? _selectedOnlineInquiryOrder;
  EventOrderDto? _selectedManageEventsOrder;
  bool _manageEventsDetailLoading = false;
  String? _manageEventsDetailError;
  Role? _lastLoadedRole;

  @override
  void initState() {
    super.initState();
    final role = AuthSession.instance.currentRole;
    final isSupervisor = role == Role.supervisor;
    _tabController = TabController(
      length: isSupervisor ? 1 : 7,
      vsync: this,
    );
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      setState(() {
        if (_isSupervisor) {
          _selectedStatus = EventStatus.ongoing;
        } else {
          final idx = _tabController.index;
          if (idx < EventStatus.values.length) {
            _selectedStatus = EventStatus.values[idx];
          }
        }
        _selectedManageEventsOrder = null;
        _manageEventsDetailError = null;
      });
    });
    _allDishes = MenuStore.instance.activeDishes;
    MenuStore.instance.addListener(_onMenuStoreChanged);
    SetMenuStore.instance.loadSetMenus();
    _foodTabController = TabController(length: 2, vsync: this);
    _loadThemeTemplates();
    AuthSession.instance.currentUser.addListener(_handleAuthSessionChange);
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
    _tabController.dispose();
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
    _newEventPaxBufferController.dispose();
    _newEventLaborCostController.dispose();
    _newEventTravelCostController.dispose();
    _newEventAdditionalCostLabelController.dispose();
    _newEventAdditionalCostAmountController.dispose();
    _foodTabController?.dispose();
    super.dispose();
  }

  void _mutateTableState(VoidCallback fn) {
    final oldStatus = _selectedStatus;
    setState(fn);
    if (_selectedStatus != oldStatus) {
      final targetIndex =
          _isSupervisor
              ? (_selectedStatus == EventStatus.ongoing ? 0 : -1)
              : _selectedStatus.index;
      if (targetIndex >= 0 &&
          targetIndex < _tabController.length &&
          targetIndex != _tabController.index) {
        _tabController.animateTo(targetIndex);
      }
    }
  }

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
  List<Map<String, dynamic>> _newEventMenuBlocks = [];
  final Map<String, double> _newEventSetMenuChargeOverrides = {};
  final TextEditingController _newEventPaxBufferController =
      TextEditingController(text: '0');
  final TextEditingController _newEventLaborCostController =
      TextEditingController(text: '0.00');
  final TextEditingController _newEventTravelCostController =
      TextEditingController(text: '0.00');
  final TextEditingController _newEventAdditionalCostLabelController =
      TextEditingController();
  final TextEditingController _newEventAdditionalCostAmountController =
      TextEditingController();
  final List<Map<String, dynamic>> _newEventAdditionalCosts = [];
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
      _themeTintEnabled = false;
      _themeTintColor = const Color(0xFFF4511E);
      _newEventPaxBufferController.text = '0';
      _newEventLaborCostController.text = '0.00';
      _newEventTravelCostController.text = '0.00';
      _newEventAdditionalCostLabelController.clear();
      _newEventAdditionalCostAmountController.clear();
      _newEventAdditionalCosts.clear();
      _newEventSetMenuChargeOverrides.clear();
      _activeNewEventSideTab = _NewEventSideTab.eventInfo;
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
      _newEventMenuBlocks = [];
      _menuItems.add(MenuItem(dish: dish, paxOption: selectedPax));
    });
  }

  void _applySetMenuToNewEvent(SetMenu set) {
    unawaited(_openNewEventMenuPicker(preselectSet: set));
  }

  void _removeFromMenu(MenuItem item) {
    setState(() {
      _menuItems.remove(item);
      _newEventMenuBlocks = [];
    });
  }

  Map<String, MenuDish> get _newEventDishById => {
    for (final dish in _allDishes) dish.id: dish,
  };

  List<Map<String, dynamic>> _setMenuChargeRowsForBlocks(
    List<Map<String, dynamic>> blocks,
    Map<String, double> chargeOverrides,
  ) {
    if (blocks.isEmpty) return const [];
    final block = blocks.first;
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
    final addedIds =
        selectedIds.where((id) => !originalIds.contains(id)).toList();
    if (addedIds.isEmpty) return const [];
    return addedIds.map((id) {
      final dish = _newEventDishById[id];
      final posInSelected = selectedIds.indexOf(id);
      final overSlot = posInSelected >= originalCount;
      final baseAmount =
          overSlot ? (dish?.additionalChargeAmount ?? 0) : 0;
      final amount = chargeOverrides[id] ?? baseAmount;
      return {'dishId': id, 'dishName': dish?.name ?? id, 'amount': amount};
    }).toList();
  }

  List<Map<String, dynamic>> _newEventSetMenuAdditionalChargeRows() {
    return _setMenuChargeRowsForBlocks(
      _newEventMenuBlocks,
      _newEventSetMenuChargeOverrides,
    );
  }

  List<Map<String, dynamic>> _inquiryMenuBlocksFromOrder(EventOrderDto order) {
    if (order.menu.isEmpty) return [];
    final byName = <String, MenuDish>{};
    for (final d in MenuStore.instance.allDishes) {
      byName[d.name.trim().toLowerCase()] = d;
    }
    final ids = <String>[];
    for (final m in order.menu) {
      final dish = byName[m.dishName.trim().toLowerCase()];
      if (dish != null) ids.add(dish.id);
    }
    if (ids.isEmpty) return [];
    final setMenuName = order.menu
        .map((m) => m.setMenuName.trim())
        .firstWhere((n) => n.isNotEmpty, orElse: () => '');
    if (setMenuName.isNotEmpty) {
      for (final s in SetMenuStore.instance.activeSetMenus) {
        if (s.name.trim().toLowerCase() == setMenuName.toLowerCase()) {
          return [
            {
              'kind': 'set',
              'setMenuId': s.id,
              'setMenuName': s.name,
              'dishIds': ids,
              'originalDishIds': List<String>.from(s.dishIds),
              'originalDishCount': s.dishIds.length,
            },
          ];
        }
      }
    }
    return [
      {
        'kind': 'custom',
        'dishIds': ids,
        'originalDishIds': List<String>.from(ids),
        'originalDishCount': ids.length,
      },
    ];
  }

  List<Map<String, dynamic>> _menuPayloadFromInquiryBlocks(
    List<Map<String, dynamic>> blocks,
    Map<String, double> chargeOverrides,
    int guestCount,
  ) {
    final out = <Map<String, dynamic>>[];
    for (final block in blocks) {
      final ids = (block['dishIds'] as List<dynamic>? ?? const [])
          .map((e) => '$e')
          .where((id) => id.isNotEmpty);
      for (final id in ids) {
        final dish = _newEventDishById[id];
        final pax = guestCount > 0 ? guestCount : 1;
        final addCharge =
            chargeOverrides[id] ?? (dish?.additionalChargeAmount ?? 0);
        out.add({
          'dishId': id,
          'dishName': dish?.name ?? id,
          'paxOption': '$pax pax',
          'price': '${500 * pax}',
          'additionalChargeAmount': addCharge,
          'menu_dishes_additional_charge_amount': addCharge,
        });
      }
    }
    return out;
  }

  double _newEventSetMenuAdditionalChargeTotal() {
    return _newEventSetMenuAdditionalChargeRows().fold<double>(
      0,
      (sum, row) => sum + ((row['amount'] as num?)?.toDouble() ?? 0),
    );
  }

  void _applyNewEventMenuBlocks(List<Map<String, dynamic>> blocks) {
    final dishById = _newEventDishById;
    setState(() {
      _newEventMenuBlocks = blocks;
      _newEventSetMenuChargeOverrides.removeWhere((dishId, _) {
        final exists = blocks.any((b) {
          final ids = (b['dishIds'] as List<dynamic>? ?? const [])
              .map((e) => '$e')
              .toSet();
          return ids.contains(dishId);
        });
        return !exists;
      });
      _menuItems.clear();
      for (final block in blocks) {
        final ids = (block['dishIds'] as List<dynamic>? ?? const [])
            .map((e) => e.toString())
            .where((e) => e.isNotEmpty);
        for (final id in ids) {
          final dish = dishById[id];
          if (dish == null) continue;
          final pax =
              _selectedPaxPerDish[dish.name] ??
              (dish.paxOptions.isNotEmpty ? dish.paxOptions.first : '1');
          _menuItems.add(MenuItem(dish: dish, paxOption: pax));
        }
      }
    });
  }

  Future<void> _openNewEventMenuPicker({SetMenu? preselectSet}) async {
    final cateringDishes =
        _allDishes
            .where(
              (d) =>
                  d.category.toLowerCase().trim() == 'catering' &&
                  !d.archived &&
                  d.available,
            )
            .toList();
    final dishById = _newEventDishById;
    List<Map<String, dynamic>> initial = _newEventMenuBlocks;
    if (preselectSet != null) {
      final ids = preselectSet.dishIds;
      initial = [
        {
          'kind': 'set',
          'setMenuName': preselectSet.name,
          'originalDishIds': ids,
          'originalDishCount': ids.length,
          'dishIds': ids,
          'dishNames': ids.map((id) => dishById[id]?.name ?? id).toList(),
        },
      ];
    }
    final blocks = await showInquiryMenuSelectionDialog(
      context,
      cateringDishes: cateringDishes,
      setMenus: SetMenuStore.instance.activeSetMenus,
      initialSelections: initial,
      mode: InquiryMenuPickerMode.staffNewEvent,
      minCustomDishes: 4,
      maxCustomDishes: 8,
    );
    if (blocks == null || !mounted) return;
    _applyNewEventMenuBlocks(blocks);
  }

  List<Map<String, dynamic>> _buildNewEventMenuPayload() {
    if (_newEventMenuBlocks.isEmpty) {
      return _menuItems
          .map(
            (i) => {
              'dishId': i.dish.id,
              'dishName': i.dish.name,
              'paxOption': i.paxOption,
              'price': '0',
              'additionalChargeAmount': i.dish.additionalChargeAmount,
              'menu_dishes_additional_charge_amount':
                  i.dish.additionalChargeAmount,
            },
          )
          .toList();
    }
    final dishById = _newEventDishById;
    final additionalRows = _newEventSetMenuAdditionalChargeRows();
    final additionalTotal = _newEventSetMenuAdditionalChargeTotal();
    return _newEventMenuBlocks.map((block) {
      final out = Map<String, dynamic>.from(block);
      final ids = (out['dishIds'] as List<dynamic>? ?? const [])
          .map((id) => id.toString())
          .where((id) => id.isNotEmpty)
          .toList();
      out['dishRows'] = ids.map((id) {
        final dish = dishById[id];
        final addCharge =
            _newEventSetMenuChargeOverrides[id] ?? (dish?.additionalChargeAmount ?? 0);
        return {
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

  double _estimateNewEventTotalCost() {
    final guests = int.tryParse(_guestCountController.text.trim()) ?? 0;
    var total = estimateInquiryCateringTotal(guests);
    total += _newEventSetMenuAdditionalChargeTotal();
    total += _newEventAdditionalCosts.fold<double>(
      0,
      (sum, e) => sum + (double.tryParse('${e['amount'] ?? 0}') ?? 0),
    );
    return total;
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
        _onlineInquiryOrders = const <EventOrderDto>[];
        _processingOrdersDto = const <EventOrderDto>[];
        _postAnalysisOrdersDto = const <EventOrderDto>[];
        _completedOrdersDto = const <EventOrderDto>[];
        _cancelledOrdersDto = const <EventOrderDto>[];
        _selectedOnlineInquiryOrder = null;
        return;
      }

      if (role == Role.supervisor) {
        final lists = await Future.wait<List<EventOrderDto>>([
          EventsApi.instance.listOrders(
            status: 'for_processing',
            roleType: 'supervisor',
            compact: false,
          ),
          EventsApi.instance.listOrders(
            status: 'new_event',
            roleType: 'supervisor',
            compact: false,
          ),
          EventsApi.instance.listOrders(
            status: 'for_down_payment',
            roleType: 'supervisor',
            compact: false,
          ),
          EventsApi.instance.listOrders(
            status: 'on_going',
            roleType: 'supervisor',
            compact: false,
          ),
          EventsApi.instance.listOrders(
            status: 'for_full_payment',
            roleType: 'supervisor',
            compact: false,
          ),
          EventsApi.instance.listOrders(
            status: 'completed',
            roleType: 'supervisor',
            compact: false,
          ),
          EventsApi.instance.listOrders(
            status: 'cancelled',
            roleType: 'supervisor',
            compact: false,
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
        _cancelledOrdersDto = lists[6];
      } else if (role == Role.manager || role == Role.superAdmin) {
        final lists = await Future.wait<List<EventOrderDto>>([
          EventsApi.instance.listOrders(
            status: 'online_inquiries',
            roleType: 'manager',
            compact: false,
          ),
          EventsApi.instance.listOrders(
            status: 'for_processing',
            roleType: 'manager',
            compact: false,
          ),
          EventsApi.instance.listOrders(
            status: 'new_event',
            roleType: 'manager',
            compact: false,
          ),
          EventsApi.instance.listOrders(
            status: 'for_down_payment',
            roleType: 'manager',
            compact: false,
          ),
          EventsApi.instance.listOrders(
            status: 'on_going',
            roleType: 'manager',
            compact: false,
          ),
          EventsApi.instance.listOrders(
            status: 'for_full_payment',
            roleType: 'manager',
            compact: false,
          ),
          EventsApi.instance.listOrders(
            status: 'completed',
            roleType: 'manager',
            compact: false,
          ),
          EventsApi.instance.listOrders(
            status: 'cancelled',
            roleType: 'manager',
            compact: false,
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
        _cancelledOrdersDto = lists[7];
      } else {
        _onlineInquiryOrders = const <EventOrderDto>[];
        _processingOrdersDto = const <EventOrderDto>[];
        _postAnalysisOrdersDto = const <EventOrderDto>[];
        _completedOrdersDto = const <EventOrderDto>[];
        _cancelledOrdersDto = const <EventOrderDto>[];
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
      _onlineInquiryOrders = const <EventOrderDto>[];
      _processingOrdersDto = const <EventOrderDto>[];
      _postAnalysisOrdersDto = const <EventOrderDto>[];
      _completedOrdersDto = const <EventOrderDto>[];
      _cancelledOrdersDto = const <EventOrderDto>[];
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
    final paxBuffer = int.tryParse(_newEventPaxBufferController.text.trim()) ?? 0;
    final laborCost =
        double.tryParse(_newEventLaborCostController.text.trim()) ?? 0.0;
    final travelCost =
        double.tryParse(_newEventTravelCostController.text.trim()) ?? 0.0;
    final totalCost = _estimateNewEventTotalCost() + laborCost + travelCost;
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
      'paxBuffer': paxBuffer,
      'laborCost': laborCost,
      'travelCost': travelCost,
      'totalCost': totalCost,
      'allergens': _allergensSerialized.trim(),
      'menu': _buildNewEventMenuPayload(),
      'menu_additional_charge_total': _newEventSetMenuAdditionalChargeTotal(),
      'additional_costs': _newEventAdditionalCosts,
      'themeDesign': {
        'picksBase64': _themePicks.map((b) => base64Encode(b)).toList(),
        'tintEnabled': _themeTintEnabled,
        'tintColorHex':
            _themeTintEnabled ? _themeTintColorHex(_themeTintColor) : null,
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
    final generatedUrl = order.themeDesign.generatedImageUrl?.trim() ?? '';
    final designPrompt =
        (order.themeDesign.customInstructions ??
                order.themeDesign.colorPrompt ??
                order.themeDesign.customerThemeRequest ??
                '')
            .trim();
    final previewSources =
        order.themeDesign.picksBase64
            .where((s) => s.trim().isNotEmpty)
            .map((s) => s.trim())
            .toList();
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
          if (designPrompt.isNotEmpty) ...[
            const Text(
              'Customer design prompt',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            ),
            const SizedBox(height: 6),
            Text(
              designPrompt,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
            ),
            const SizedBox(height: 12),
          ],
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
              order.themeDesign.wantsCustomDesign
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
    {List<Map<String, dynamic>> additionalCosts = const [],
    String? eventTitleOverride,
    String? eventTypeOverride,
    String? formalityLevelOverride,
    int? guestCountOverride,
    List<Map<String, dynamic>>? menuOverride,
    String? allergensOverride,
    String? customerNameOverride,
    String? contactPersonOverride,
    String? contactNumberOverride,
    String? emailAddressOverride,
    String? endTimeOverride,
    String? noteOverride}) {
    final effectiveGuestCount = guestCountOverride ?? order.guestCount;
    List<Map<String, dynamic>> menuItems = [];
    final schedulePayload = <Map<String, dynamic>>[];

    if (menuOverride != null && menuOverride.isNotEmpty) {
      menuItems = List<Map<String, dynamic>>.from(menuOverride);
    } else if (menuChoice == 'yes') {
      for (final dishId in selectedDishIds) {
        final dish = MenuStore.instance.allDishes.firstWhere(
          (d) => d.id == dishId,
        );
        final paxCount = effectiveGuestCount > 0 ? effectiveGuestCount : 1;
        final computedPrice = 500 * paxCount;
        menuItems.add({
          'dishId': dishId,
          'dishName': dish.name,
          'paxOption': '${paxCount} pax',
          'price': computedPrice.toString(),
          'additionalChargeAmount': dish.additionalChargeAmount,
          'menu_dishes_additional_charge_amount': dish.additionalChargeAmount,
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
        final paxCount = effectiveGuestCount > 0 ? effectiveGuestCount : 1;
        final computedPrice = 500 * paxCount;
        menuItems.add({
          'dishId': dishId,
          'dishName': dish.name,
          'paxOption': '$paxCount pax',
          'price': computedPrice.toString(),
          'additionalChargeAmount': dish.additionalChargeAmount,
          'menu_dishes_additional_charge_amount': dish.additionalChargeAmount,
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
                  'additionalChargeAmount': m.additionalChargeAmount,
                },
              )
              .toList();
    }

    final dateValue = date.trim();
    final timeValue = time.trim();
    final endTimeValue = (endTimeOverride ?? '').trim();
    if (dateValue.isNotEmpty || timeValue.isNotEmpty) {
      final fallbackEnd =
          order.scheduleSlots.isNotEmpty &&
                  order.scheduleSlots.first.endTime.trim().isNotEmpty
              ? order.scheduleSlots.first.endTime.trim()
              : '14:00';
      schedulePayload.add({
        'date': dateValue,
        'startTime': timeValue,
        'endTime': endTimeValue.isNotEmpty ? endTimeValue : fallbackEnd,
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

    final dishCost = menuItems.fold<double>(
      0.0,
      (sum, row) => sum + (double.tryParse('${row['price']}') ?? 0.0),
    );

    return {
      'eventTitle': eventTitleOverride ?? order.eventTitle,
      'eventType': eventTypeOverride ?? order.eventType,
      'formalityLevel': formalityLevelOverride ?? order.formalityLevel,
      'customerName': customerNameOverride ?? order.customerName,
      'contactPerson': contactPersonOverride ?? order.contactPerson,
      'contactNumber': contactNumberOverride ?? order.contactNumber,
      'emailAddress': emailAddressOverride ?? order.emailAddress,
      'scheduleSlots': schedulePayload,
      'address': address,
      'guestCount': effectiveGuestCount,
      'serviceType': serviceType,
      'menu': menuItems,
      if (allergensOverride != null) 'allergens': allergensOverride,
      if (noteOverride != null) 'note': noteOverride,
      // Only cost fields — preserve existing theme assets server-side via merge.
      'themeDesign': {
        'costBreakdown': {
          'dishCost': dishCost > 0
              ? dishCost
              : estimateInquiryCateringTotal(effectiveGuestCount),
          'laborCost': laborCost,
          'travelCost': travelCost,
        },
        'laborCost': laborCost,
        'travelCost': travelCost,
      },
      'laborCost': laborCost,
      'travelCost': travelCost,
      'additional_costs': additionalCosts,
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
    final txn = order.transactionNo.trim();
    return txn.isNotEmpty ? txn : 'N/A';
  }

  Future<bool> _confirmOrderPayment(
    EventOrderDto order,
    PaymentConfirmationMode mode,
    PaymentService paymentService,
    String referenceNumber, {
    double? amount,
    String? paymentProofBase64,
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
        paymentProofBase64: paymentProofBase64,
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
    String? paymentProofBase64;
    String? paymentProofFileName;
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
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Total cost',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                formatPesos(orderTotal),
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (isDownpayment)
                                Text(
                                  'Down payment due (50%): ${formatPesos(orderTotal / 2)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade700,
                                  ),
                                )
                              else
                                Text(
                                  'Balance due: ${formatPesos(remainingBalance)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
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
                        const Text(
                          'Payment proof (optional)',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final result = await FilePicker.platform.pickFiles(
                              type: FileType.image,
                              withData: true,
                            );
                            if (result == null || result.files.isEmpty) return;
                            final file = result.files.first;
                            if (file.bytes == null) return;
                            dialogSetState(() {
                              paymentProofFileName = file.name;
                              paymentProofBase64 = base64Encode(file.bytes!);
                            });
                          },
                          icon: const Icon(Icons.upload_file, size: 18),
                          label: Text(
                            paymentProofBase64 == null
                                ? 'Upload proof image'
                                : 'Proof: ${paymentProofFileName ?? 'image'}',
                          ),
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
                                paymentProofBase64: paymentProofBase64,
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
                      DataColumn(
                        label: Text('Set / Category'),
                        columnWidth: FixedColumnWidth(168),
                      ),
                      DataColumn(
                        label: Text('Item'),
                        columnWidth: FlexColumnWidth(2.2),
                      ),
                      DataColumn(
                        label: Text('Pax / Qty'),
                        columnWidth: FixedColumnWidth(88),
                      ),
                      DataColumn(
                        label: Text('Details'),
                        columnWidth: FlexColumnWidth(1.6),
                      ),
                      DataColumn(
                        label: Text('Unit Cost'),
                        columnWidth: FixedColumnWidth(100),
                      ),
                      DataColumn(
                        label: Text('Total'),
                        columnWidth: FixedColumnWidth(100),
                      ),
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
    EventOrderDto sourceOrder = order;
    try {
      final roleType =
          AuthSession.instance.currentRole == Role.supervisor
              ? 'supervisor'
              : 'manager';
      sourceOrder = await EventsApi.instance.getEventOrder(
        orderId: order.id,
        roleType: roleType,
      );
    } catch (_) {}

    final List<ChecklistItem> editableItems =
        sourceOrder.checklist.isEmpty
            ? _buildChecklistFromMenuWithIngredients(sourceOrder.menu)
            : sourceOrder.checklist
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

    final canToggleChecklistStatus =
        _isManager || AuthSession.instance.currentRole == Role.supervisor;
    final canMutateChecklist = _isManager;
    final showInventoryPicker = _isManager && _isCateringPlusEventOrder(sourceOrder);
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

    final newItemController = TextEditingController();
    int? duplicateHighlightIndex;
    var showNewItemRow = false;
    try {
    await showDialog<void>(
      context: context,
      builder: (context) {
        final dialogSize = MediaQuery.sizeOf(context);
        return StatefulBuilder(
          builder: (context, dialogSetState) {
            void addChecklistByName(
              String raw, {
              Map<String, dynamic>? inventoryRow,
            }) {
              final name = raw.trim();
              if (name.isEmpty) return;
              final dupIdx = editableItems.indexWhere(
                (e) => e.item.trim().toLowerCase() == name.toLowerCase(),
              );
              if (dupIdx >= 0) {
                dialogSetState(() => duplicateHighlightIndex = dupIdx);
                return;
              }
              dialogSetState(() {
                duplicateHighlightIndex = null;
                showNewItemRow = false;
                if (inventoryRow != null) {
                  final id = inventoryRow['id']?.toString() ?? '';
                  final unitCost = inventoryRow['unitCost'] is num
                      ? (inventoryRow['unitCost'] as num).toDouble()
                      : double.tryParse('${inventoryRow['unitCost']}') ?? 0;
                  editableItems.add(
                    ChecklistItem(
                      item: name,
                      description:
                          (inventoryRow['category'] ?? 'Inventory').toString(),
                      quantity: 1,
                      cost: unitCost,
                      inventoryId: id,
                    ),
                  );
                } else {
                  editableItems.add(
                    ChecklistItem(
                      item: name,
                      description: '',
                      quantity: 1,
                      cost: 0.0,
                    ),
                  );
                }
                newItemController.clear();
              });
            }

            Future<void> editChecklistRowDialog(int index) async {
              final item = editableItems[index];
              final itemCtrl = TextEditingController(text: item.item);
              final descCtrl = TextEditingController(text: item.description);
              final qtyCtrl = TextEditingController(text: '${item.quantity}');
              final costCtrl = TextEditingController(
                text: item.cost.toStringAsFixed(2),
              );
              var completed = item.isCompleted;
              await showDialog<void>(
                context: context,
                builder:
                    (dctx) => StatefulBuilder(
                      builder: (dctx, setEditState) => AlertDialog(
                      title: const Text('Edit checklist row'),
                      content: SizedBox(
                        width: 440,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextField(
                              controller: itemCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Item',
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: descCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Description',
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: qtyCtrl,
                                    decoration: const InputDecoration(
                                      labelText: 'Quantity',
                                    ),
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: costCtrl,
                                    decoration: const InputDecoration(
                                      labelText: 'Cost',
                                      prefixText: 'PHP ',
                                    ),
                                    keyboardType: const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              value: completed,
                              onChanged: (v) {
                                if (v == null) return;
                                setEditState(() => completed = v);
                              },
                              title: const Text('Completed'),
                            ),
                          ],
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dctx),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () {
                            dialogSetState(() {
                              editableItems[index] = ChecklistItem(
                                item: itemCtrl.text.trim(),
                                description: descCtrl.text.trim(),
                                quantity: int.tryParse(qtyCtrl.text.trim()) ?? 1,
                                cost: double.tryParse(costCtrl.text.trim()) ?? 0,
                                isCompleted: completed,
                                inventoryId: item.inventoryId,
                              );
                            });
                            Navigator.pop(dctx);
                          },
                          child: const Text('Apply'),
                        ),
                      ],
                    ),
                    ),
              );
              itemCtrl.dispose();
              descCtrl.dispose();
              qtyCtrl.dispose();
              costCtrl.dispose();
            }

            return AlertDialog(
              title: Text('Checklist for ${sourceOrder.eventTitle}'),
              content: SizedBox(
                width: dialogSize.width * 0.92 > 1040 ? 1040 : dialogSize.width * 0.92,
                height: dialogSize.height * 0.82 > 680 ? 680 : dialogSize.height * 0.82,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, tableConstraints) {
                          return Align(
                            alignment: Alignment.topLeft,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: tableConstraints.maxWidth,
                              ),
                              child: PagedDataTable(
                        title: 'Event Checklist',
                        key: ValueKey(editableItems.length),
                        maxTableHeight: tableConstraints.maxHeight,
                        forceVerticalScroll: true,
                        toolbarActions:
                            canMutateChecklist
                                ? [
                                  AntdSecondaryButton(
                                    onPressed: () => dialogSetState(() {
                                      showNewItemRow = true;
                                      duplicateHighlightIndex = null;
                                      newItemController.clear();
                                    }),
                                    icon: Icons.add_circle_outline,
                                    label: 'Add item',
                                  ),
                                ]
                                : const [],
                        columnSpacing: 12,
                        horizontalMargin: 8,
                        dataRowMinHeight: 52,
                        dataRowMaxHeight: 96,
                        headingRowColor: WidgetStateProperty.all(
                          Colors.grey.shade200,
                        ),
                        columns: [
                          const DataColumn(
                            label: Text('Item'),
                            columnWidth: FixedColumnWidth(170),
                          ),
                          const DataColumn(
                            label: Text('Description'),
                            columnWidth: FixedColumnWidth(200),
                          ),
                          const DataColumn(
                            label: Text('Quantity'),
                            columnWidth: FixedColumnWidth(80),
                          ),
                          if (_isManager) ...[
                            const DataColumn(
                              label: Text('Price/1'),
                              columnWidth: FixedColumnWidth(100),
                            ),
                            const DataColumn(
                              label: Text('Total Price'),
                              columnWidth: FixedColumnWidth(100),
                            ),
                          ] else ...[
                            const DataColumn(
                              label: Text('Cost'),
                              columnWidth: FixedColumnWidth(100),
                            ),
                          ],
                          const DataColumn(
                            label: Text('Status'),
                            columnWidth: FixedColumnWidth(120),
                          ),
                          if (canMutateChecklist) ...[
                            const DataColumn(
                              label: Text('Actions'),
                              columnWidth: FixedColumnWidth(110),
                            ),
                          ],
                        ],
                        rows: [
                          ...editableItems.asMap().entries.map((entry) {
                              final index = entry.key;
                              final item = entry.value;
                              final isDuplicateRow =
                                  duplicateHighlightIndex == index;
                              return DataRow(
                                color:
                                    isDuplicateRow
                                        ? WidgetStateProperty.all(
                                          const Color(0x33FFC107),
                                        )
                                        : null,
                                cells: [
                                  DataCell(
                                    SizedBox(
                                      width: 162,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          canMutateChecklist
                                              ? TextFormField(
                                                initialValue: item.item,
                                                decoration: InputDecoration(
                                                  border: OutlineInputBorder(
                                                    borderSide: BorderSide(
                                                      color:
                                                          isDuplicateRow
                                                              ? const Color(
                                                                0xFFFFC107,
                                                              )
                                                              : Colors.grey,
                                                    ),
                                                  ),
                                                  contentPadding:
                                                      const EdgeInsets.all(8),
                                                  isDense: true,
                                                ),
                                                onChanged: (value) {
                                                  dialogSetState(() {
                                                    if (duplicateHighlightIndex ==
                                                        index) {
                                                      duplicateHighlightIndex =
                                                          null;
                                                    }
                                                    editableItems[index] =
                                                        ChecklistItem(
                                                          item: value,
                                                          description:
                                                              item.description,
                                                          quantity:
                                                              item.quantity,
                                                          cost: item.cost,
                                                          isCompleted:
                                                              item.isCompleted,
                                                          inventoryId:
                                                              item.inventoryId,
                                                        );
                                                  });
                                                },
                                              )
                                              : Text(item.item),
                                          if (isDuplicateRow)
                                            const Padding(
                                              padding: EdgeInsets.only(top: 4),
                                              child: Text(
                                                'Item already exists',
                                                style: TextStyle(
                                                  color: Color(0xFFB8860B),
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: 192,
                                      child: canMutateChecklist
                                          ? TextFormField(
                                          initialValue: item.description,
                                          decoration: const InputDecoration(
                                            border: OutlineInputBorder(),
                                            contentPadding: EdgeInsets.all(8),
                                            isDense: true,
                                          ),
                                          onChanged: (value) {
                                            dialogSetState(() {
                                              editableItems[index] =
                                                  ChecklistItem(
                                                    item: item.item,
                                                    description: value,
                                                    quantity: item.quantity,
                                                    cost: item.cost,
                                                    isCompleted:
                                                        item.isCompleted,
                                                  );
                                            });
                                          },
                                        )
                                          : Text(item.description),
                                    ),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: 72,
                                      child: canMutateChecklist
                                          ? TextFormField(
                                          initialValue:
                                              item.quantity.toString(),
                                          decoration: const InputDecoration(
                                            border: OutlineInputBorder(),
                                            contentPadding: EdgeInsets.all(8),
                                            isDense: true,
                                          ),
                                          keyboardType: TextInputType.number,
                                          onChanged: (value) {
                                            final newQuantity =
                                                int.tryParse(value) ??
                                                item.quantity;
                                            dialogSetState(() {
                                              editableItems[index] =
                                                  ChecklistItem(
                                                    item: item.item,
                                                    description:
                                                        item.description,
                                                    quantity: newQuantity,
                                                    cost: item.cost,
                                                    isCompleted:
                                                        item.isCompleted,
                                                  );
                                            });
                                          },
                                        )
                                          : Text('${item.quantity}'),
                                    ),
                                  ),
                                  if (_isManager) ...[
                                    DataCell(
                                      SizedBox(
                                        width: 92,
                                        child: TextFormField(
                                        initialValue: item.cost.toStringAsFixed(
                                          2,
                                        ),
                                        decoration: const InputDecoration(
                                          border: OutlineInputBorder(),
                                          contentPadding: EdgeInsets.all(8),
                                          isDense: true,
                                          prefixText: 'PHP ',
                                        ),
                                        keyboardType: TextInputType.number,
                                        onChanged: (value) {
                                          final newCost =
                                              double.tryParse(value) ??
                                              item.cost;
                                          dialogSetState(() {
                                            editableItems[index] =
                                                ChecklistItem(
                                                  item: item.item,
                                                  description: item.description,
                                                  quantity: item.quantity,
                                                  cost: newCost,
                                                  isCompleted: item.isCompleted,
                                                );
                                          });
                                        },
                                      ),
                                      ),
                                    ),
                                    DataCell(
                                      SizedBox(
                                        width: 92,
                                        child: Text(
                                          'PHP ${(item.cost * item.quantity).toStringAsFixed(2)}',
                                        ),
                                      ),
                                    ),
                                  ] else ...[
                                    DataCell(
                                      SizedBox(
                                        width: 92,
                                        child: Text(formatPesos(item.cost)),
                                      ),
                                    ),
                                  ],
                                  DataCell(
                                    SizedBox(
                                      width: 112,
                                      child: canToggleChecklistStatus
                                          ? Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color:
                                                  item.isCompleted
                                                      ? Colors.green.shade50
                                                      : Colors.red.shade50,
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(
                                                color:
                                                    item.isCompleted
                                                        ? Colors.green
                                                        : Colors.red,
                                                width: 1,
                                              ),
                                            ),
                                            child: DropdownButtonHideUnderline(
                                              child: DropdownButton<bool>(
                                                value: item.isCompleted,
                                                isDense: true,
                                                icon: const Icon(
                                                  Icons.keyboard_arrow_down,
                                                  size: 18,
                                                ),
                                                style: TextStyle(
                                                  color:
                                                      item.isCompleted
                                                          ? Colors.green
                                                          : Colors.red,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 12,
                                                ),
                                                items: const [
                                                  DropdownMenuItem(
                                                    value: true,
                                                    child: Text(
                                                      'completed',
                                                      style: TextStyle(
                                                        color: Colors.green,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                  DropdownMenuItem(
                                                    value: false,
                                                    child: Text(
                                                      'not done',
                                                      style: TextStyle(
                                                        color: Colors.red,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                                onChanged: (value) {
                                                  if (value != null) {
                                                    dialogSetState(() {
                                                      editableItems[index] =
                                                          ChecklistItem(
                                                            item: item.item,
                                                            description:
                                                                item.description,
                                                            quantity: item.quantity,
                                                            cost: item.cost,
                                                            isCompleted: value,
                                                            inventoryId:
                                                                item.inventoryId,
                                                          );
                                                    });
                                                  }
                                                },
                                              ),
                                            ),
                                          )
                                          : Text(
                                            item.isCompleted ? 'completed' : 'not done',
                                            style: TextStyle(
                                              color:
                                                  item.isCompleted
                                                      ? Colors.green
                                                      : Colors.red,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 12,
                                            ),
                                          ),
                                    ),
                                  ),
                                  if (canMutateChecklist) ...[
                                    DataCell(
                                      SizedBox(
                                        width: 104,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              tooltip: 'Edit item',
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                              onPressed: () => editChecklistRowDialog(index),
                                              icon: const Icon(Icons.edit_outlined),
                                            ),
                                            IconButton(
                                              tooltip: 'Remove item',
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                              onPressed: () {
                                                dialogSetState(() {
                                                  if (duplicateHighlightIndex ==
                                                      index) {
                                                    duplicateHighlightIndex = null;
                                                  }
                                                  editableItems.removeAt(index);
                                                });
                                              },
                                              icon: const Icon(
                                                Icons.remove_circle_outline,
                                                color: Colors.red,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              );
                            }),
                          if (canMutateChecklist && showNewItemRow)
                            DataRow(
                              color: WidgetStateProperty.all(
                                Colors.blue.shade50,
                              ),
                              cells: [
                                DataCell(
                                  SizedBox(
                                    width: 162,
                                    child: showInventoryPicker &&
                                            inventoryOptions.isNotEmpty
                                        ? Autocomplete<Map<String, dynamic>>(
                                          optionsBuilder: (text) {
                                            final q =
                                                text.text.trim().toLowerCase();
                                            if (q.isEmpty) {
                                              return inventoryOptions.take(20);
                                            }
                                            return inventoryOptions
                                                .where((row) {
                                                  final name =
                                                      '${row['name'] ?? ''}'
                                                          .toLowerCase();
                                                  final cat =
                                                      '${row['category'] ?? ''}'
                                                          .toLowerCase();
                                                  return name.contains(q) ||
                                                      cat.contains(q);
                                                })
                                                .take(20);
                                          },
                                          displayStringForOption: (row) =>
                                              '${row['name']} (${row['quantity']} ${row['unit']})',
                                          fieldViewBuilder: (
                                            context,
                                            controller,
                                            focusNode,
                                            onFieldSubmitted,
                                          ) {
                                            if (controller.text !=
                                                newItemController.text) {
                                              controller.text =
                                                  newItemController.text;
                                            }
                                            return TextField(
                                              controller: controller,
                                              focusNode: focusNode,
                                              autofocus: true,
                                              decoration:
                                                  const InputDecoration(
                                                labelText: 'New item',
                                                hintText:
                                                    'Search inventory or type name',
                                                border: OutlineInputBorder(),
                                                isDense: true,
                                              ),
                                              onChanged: (v) =>
                                                  newItemController.text = v,
                                              onSubmitted: addChecklistByName,
                                            );
                                          },
                                          onSelected: (row) {
                                            addChecklistByName(
                                              '${row['name']}',
                                              inventoryRow: row,
                                            );
                                          },
                                        )
                                        : TextField(
                                          controller: newItemController,
                                          autofocus: true,
                                          decoration: const InputDecoration(
                                            labelText: 'New item',
                                            border: OutlineInputBorder(),
                                            isDense: true,
                                          ),
                                          onSubmitted: addChecklistByName,
                                        ),
                                  ),
                                ),
                                const DataCell(Text('')),
                                const DataCell(Text('')),
                                if (_isManager) ...[
                                  const DataCell(Text('')),
                                  const DataCell(Text('')),
                                ] else
                                  const DataCell(Text('')),
                                const DataCell(Text('')),
                                if (canMutateChecklist)
                                  DataCell(
                                    IconButton(
                                      tooltip: 'Cancel new row',
                                      onPressed: () => dialogSetState(() {
                                        showNewItemRow = false;
                                        newItemController.clear();
                                      }),
                                      icon: const Icon(Icons.close),
                                    ),
                                  ),
                              ],
                            ),
                        ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Bottom action buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Generate PDF button (outline style)
                        OutlinedButton(
                          onPressed:
                              () => _exportChecklistToPDF(sourceOrder, editableItems),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.black87,
                            side: BorderSide(color: Colors.grey.shade400),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                          ),
                          child: const Text('generate PDF'),
                        ),
                        const SizedBox(width: 12),
                        if (canToggleChecklistStatus)
                          OutlinedButton(
                            onPressed: () => _saveChecklist(
                              sourceOrder,
                              editableItems,
                              dialogContext: context,
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.green,
                              side: const BorderSide(color: Colors.green),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                            ),
                            child: const Text('save'),
                          ),
                        const SizedBox(width: 12),
                        // Close button (red outline)
                        OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                          ),
                          child: const Text('close'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [],
            );
          },
        );
      },
    );
    } finally {
      newItemController.dispose();
    }
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
      await _selectManageEventsOrder(order);
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
      final previewSources =
          selectedOrder.themeDesign.picksBase64
              .where((s) => s.trim().isNotEmpty)
              .map((s) => s.trim())
              .toList();
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
              child:
                  previewSources.isEmpty
                      ? Center(
                        child: Text(
                          'No event theme design image available.',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      )
                      : GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              childAspectRatio: 1.1,
                            ),
                        itemCount: previewSources.length,
                        itemBuilder: (context, index) {
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: previewWidget(
                              previewSources[index],
                              fit: BoxFit.cover,
                            ),
                          );
                        },
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
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder:
            (_) => const CustomerWebsiteScreen(
              showStaffChrome: false,
              staffThemeStudioMode: true,
            ),
      ),
    );
    if (result == null || !mounted) return;

    setState(() {
      _themePicks.clear();
      _themePickHashes.clear();
      final composite = result['confirmedCompositeBase64']?.toString().trim();
      if (composite != null && composite.isNotEmpty) {
        try {
          final bytes = base64Decode(composite);
          _themePicks.add(bytes);
          _themePickHashes.add(_themeImageKey(bytes));
        } catch (_) {}
      }
      final picks = result['picksBase64'];
      if (picks is List) {
        for (final item in picks) {
          final s = item.toString().trim();
          if (s.isEmpty) continue;
          try {
            final bytes = base64Decode(s);
            final key = _themeImageKey(bytes);
            if (!_themePickHashes.contains(key)) {
              _themePicks.add(bytes);
              _themePickHashes.add(key);
            }
          } catch (_) {}
        }
      }
      _collageOrder = _themePicks.toList();
      _focusedPickIndex = 0;
    });
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
            if (selPost != null && _isCateringPlusEventOrder(selPost)) ...[
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
                                        child: _isManager
                                            ? GestureDetector(
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
                                            )
                                            : const SizedBox.shrink(),
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
                              await EventsApi.instance.completeOrder(
                                orderId: selPost.id,
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
                                await EventsApi.instance.completeOrder(
                                  orderId: selPost.id,
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

    return _buildOrdersTablePanel(
      title: '',
      orders: orderDtos,
      emptyMessage: 'No completed events in the last 30 days.',
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

  String _newEventSideTabLabel(_NewEventSideTab tab) {
    switch (tab) {
      case _NewEventSideTab.eventInfo:
        return 'Event Information';
      case _NewEventSideTab.menuAndAllergens:
        return 'Menu & Allergens';
      case _NewEventSideTab.submitAndCosts:
        return 'Submit & Costs';
    }
  }

  IconData _newEventSideTabIcon(_NewEventSideTab tab) {
    switch (tab) {
      case _NewEventSideTab.eventInfo:
        return Icons.event_note;
      case _NewEventSideTab.menuAndAllergens:
        return Icons.restaurant_menu;
      case _NewEventSideTab.submitAndCosts:
        return Icons.payments;
    }
  }

  Widget _buildNewEventSideTabNav() {
    final tabs = _NewEventSideTab.values;
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              'New Event',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Color(0xFF1E1E1E),
              ),
            ),
          ),
          const Divider(height: 1),
          ...tabs.map((tab) {
            final active = _activeNewEventSideTab == tab;
            return Material(
              color:
                  active
                      ? const Color(0xFFFFC024).withValues(alpha: 0.16)
                      : Colors.transparent,
              child: InkWell(
                onTap: () => setState(() => _activeNewEventSideTab = tab),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(
                        color:
                            active ? const Color(0xFFFFC024) : Colors.transparent,
                        width: 4,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _newEventSideTabIcon(tab),
                        size: 20,
                        color: active ? Colors.black87 : Colors.grey.shade600,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _newEventSideTabLabel(tab),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight:
                                active ? FontWeight.w700 : FontWeight.w500,
                            color: active ? Colors.black87 : Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildNewEventMobileTabs() {
    final tabs = _NewEventSideTab.values;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children:
            tabs.map((tab) {
              final active = _activeNewEventSideTab == tab;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _activeNewEventSideTab = tab),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color:
                              active
                                  ? const Color(0xFFFFC024)
                                  : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                    child: Text(
                      _newEventSideTabLabel(tab),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                        color: active ? Colors.black87 : Colors.grey.shade600,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }

  bool _isLastNewEventSideTab() {
    final tabs = _NewEventSideTab.values;
    return _activeNewEventSideTab == tabs.last;
  }

  bool _isFirstNewEventSideTab() {
    final tabs = _NewEventSideTab.values;
    return _activeNewEventSideTab == tabs.first;
  }

  void _nextNewEventSideTab() {
    final tabs = _NewEventSideTab.values;
    final idx = tabs.indexOf(_activeNewEventSideTab);
    if (idx >= 0 && idx < tabs.length - 1) {
      setState(() => _activeNewEventSideTab = tabs[idx + 1]);
    }
  }

  void _prevNewEventSideTab() {
    final tabs = _NewEventSideTab.values;
    final idx = tabs.indexOf(_activeNewEventSideTab);
    if (idx > 0) {
      setState(() => _activeNewEventSideTab = tabs[idx - 1]);
    }
  }

  Widget _buildNewEventThemeDesignBlock() {
    final isCateringOnly = _orderType == 'catering';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: double.infinity,
          height: 46,
          child: OutlinedButton.icon(
            onPressed: isCateringOnly ? null : _showThemeDesignDialog,
            icon: const Icon(Icons.palette_outlined, size: 20),
            label: Text(
              isCateringOnly
                  ? 'Event theme design (not for catering-only)'
                  : 'Edit Event Theme Design',
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF1E1E1E),
              side: BorderSide(color: Colors.grey.shade400),
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (!isCateringOnly && _themePicks.isNotEmpty)
          SizedBox(
            height: 92,
            child: Scrollbar(
              thumbVisibility: true,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _themePicks.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) => Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.memory(
                    _themePicks[i],
                    width: 92,
                    height: 92,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          )
        else if (!isCateringOnly)
          Text(
            'No theme design preview yet. Open the editor to add picks.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
      ],
    );
  }

  Widget _buildNewEventSubmitActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Saved draft.')),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFFA726),
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          child: const Text('SAVE DRAFT'),
        ),
        const SizedBox(height: 10),
        ElevatedButton(
          onPressed: _isSubmittingOrder ? null : _submitNewEventFromForm,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1DB954),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          child:
              _isSubmittingOrder
                  ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                  : const Text('SUBMIT'),
        ),
      ],
    );
  }

  Future<void> _submitNewEventFromForm() async {
    setState(() {
      _contactNumberError = null;
      _emailError = null;
      _guestCountError = null;
    });

    final missing = <String>[];
    final isCateringOnly = _orderType == 'catering';

    if (_orderType == null) missing.add('Service type');

    if (!isCateringOnly) {
      if (_eventTitleController.text.trim().isEmpty) {
        missing.add('Event title');
      }
      if (_eventType == null) missing.add('Event type');
      if (_formalityLevel == null) missing.add('Formality level');
    }

    if (_customerController.text.trim().isEmpty) {
      missing.add('Customer name');
    }
    if (_contactPersonController.text.trim().isEmpty) {
      missing.add('Contact person');
    }

    final contactNumber = _contactNumberController.text.trim();
    if (contactNumber.isEmpty) {
      missing.add('Contact number');
    } else if (contactNumber.length < 10) {
      setState(() {
        _contactNumberError = 'Contact number must be at least 10 digits';
      });
      return;
    }

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

    final guestCount = int.tryParse(_guestCountController.text.trim());

    if (_guestCountController.text.trim().isEmpty) {
      missing.add('No. of guests');
    } else if (guestCount == null || guestCount <= 0) {
      setState(() {
        _guestCountError = 'Please enter a valid number of guests';
      });
      return;
    }

    if (_menuItems.isEmpty) {
      missing.add('Menu');
    } else if (_menuItems.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select at least 4 dishes for the menu.'),
        ),
      );
      return;
    }

    if (missing.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please complete: ${missing.join(', ')}'),
        ),
      );
      return;
    }

    setState(() => _isSubmittingOrder = true);

    try {
      final payload = _buildPayloadFromForm();
      await EventsApi.instance.managerSubmitNewEventToProcessing(
        payload: payload,
      );
      await _refreshOrders();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order submitted successfully.')),
      );
      _resetForm();
      setState(() => _selectedStatus = EventStatus.forDownpayment);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to submit order.')),
      );
    } finally {
      if (mounted) setState(() => _isSubmittingOrder = false);
    }
  }

  Widget _buildNewEventEstimatedCostPanel({bool showSubmitActions = false}) {
    final guestCount = int.tryParse(_guestCountController.text.trim()) ?? 0;
    final dishCost = estimateInquiryCateringTotal(guestCount);
    final menuAddOns = _newEventSetMenuAdditionalChargeTotal();
    final labor = double.tryParse(_newEventLaborCostController.text.trim()) ?? 0.0;
    final travel =
        double.tryParse(_newEventTravelCostController.text.trim()) ?? 0.0;
    final additional = _newEventAdditionalCosts.fold<double>(
      0,
      (sum, e) => sum + (double.tryParse('${e['amount'] ?? 0}') ?? 0),
    );
    final total = dishCost + menuAddOns + labor + travel + additional;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.receipt_long, size: 20, color: Color(0xFF1E1E1E)),
                SizedBox(width: 8),
                Text(
                  'Estimated Cost',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: Color(0xFF1E1E1E),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow('Dish Cost', formatPesos(dishCost)),
            _buildInfoRow('Menu Add-ons', formatPesos(menuAddOns)),
            _buildInfoRow('Labor', formatPesos(labor)),
            _buildInfoRow('Travel', formatPesos(travel)),
            _buildInfoRow('Additional Costs', formatPesos(additional)),
            const SizedBox(height: 8),
            _buildCostBlock(
              'Total',
              formatPesos(total),
              const Color(0xFFFFC024),
            ),
            const SizedBox(height: 6),
            Text(
              'Formula: (pax × 500) + menu add-ons + labor + travel + additional costs',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
            if (showSubmitActions) ...[
              const SizedBox(height: 16),
              _buildNewEventSubmitActions(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNewEventCenterContent({required bool isNarrow}) {
    final isMenuTab = _activeNewEventSideTab == _NewEventSideTab.menuAndAllergens;
    Widget body;
    switch (_activeNewEventSideTab) {
      case _NewEventSideTab.eventInfo:
        body = _buildEventForm();
        break;
      case _NewEventSideTab.menuAndAllergens:
        body = _buildEventMenuSection();
        break;
      case _NewEventSideTab.submitAndCosts:
        body = _buildNewEventSubmissionBar();
        break;
    }
    final nav = Row(
      children: [
        if (!_isFirstNewEventSideTab())
          OutlinedButton.icon(
            onPressed: _prevNewEventSideTab,
            icon: const Icon(Icons.arrow_back, size: 16),
            label: const Text('Previous'),
          ),
        const Spacer(),
        if (_isLastNewEventSideTab())
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFC024).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check, size: 16),
                SizedBox(width: 6),
                Text(
                  'Review submit actions below',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          )
        else
          ElevatedButton.icon(
            onPressed: _nextNewEventSideTab,
            icon: const Text('Next'),
            label: const Icon(Icons.arrow_forward, size: 16),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFC024),
              foregroundColor: const Color(0xFF1E1E1E),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
      ],
    );

    if (isMenuTab) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _newEventSideTabLabel(_activeNewEventSideTab),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1E1E1E),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(child: body),
            const SizedBox(height: 20),
            nav,
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _newEventSideTabLabel(_activeNewEventSideTab),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E1E1E),
            ),
          ),
          const SizedBox(height: 12),
          body,
          const SizedBox(height: 20),
          nav,
        ],
      ),
    );
  }

  Widget _buildNewEventFormLayout(bool isNarrow) {
    if (isNarrow) {
      return Column(
        children: [
          _buildNewEventMobileTabs(),
          Expanded(child: _buildNewEventCenterContent(isNarrow: true)),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 300, child: _buildNewEventSideTabNav()),
        Expanded(flex: 3, child: _buildNewEventCenterContent(isNarrow: false)),
        SizedBox(
          width: 400,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(0, 16, 16, 16),
            child: _buildNewEventEstimatedCostPanel(showSubmitActions: true),
          ),
        ),
      ],
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
        return _buildNewEventFormLayout(isNarrow);
    }
  }

  Widget _buildNewEventSubmissionBar({bool showSubmitActions = false}) {
    final setMenuChargeRows = _newEventSetMenuAdditionalChargeRows();

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildNewEventThemeDesignBlock(),
            const SizedBox(height: 16),
            TextField(
              controller: _newEventPaxBufferController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: false,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Pax buffer',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _newEventLaborCostController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Labor cost',
                      prefixText: 'PHP ',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _newEventTravelCostController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Travel cost',
                      prefixText: 'PHP ',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            const Text(
              'Additional costs',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newEventAdditionalCostLabelController,
                          decoration: const InputDecoration(
                            labelText: 'Label',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 140,
                        child: TextField(
                          controller: _newEventAdditionalCostAmountController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Amount',
                            prefixText: 'PHP ',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Add additional cost',
                        onPressed: () {
                          final label =
                              _newEventAdditionalCostLabelController.text.trim();
                          final amount = double.tryParse(
                            _newEventAdditionalCostAmountController.text.trim(),
                          );
                          if (label.isEmpty || amount == null) return;
                          setState(() {
                            _newEventAdditionalCosts.add({
                              'label': label,
                              'amount': amount,
                            });
                            _newEventAdditionalCostLabelController.clear();
                            _newEventAdditionalCostAmountController.clear();
                          });
                        },
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
            if (_newEventAdditionalCosts.isNotEmpty) ...[
              const SizedBox(height: 4),
              ..._newEventAdditionalCosts.asMap().entries.map((entry) {
                final index = entry.key;
                final row = entry.value;
                final amount = double.tryParse('${row['amount'] ?? 0}') ?? 0;
                return Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${row['label']} — ${formatPesos(amount)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Remove additional cost',
                      onPressed:
                          () => setState(
                            () => _newEventAdditionalCosts.removeAt(index),
                          ),
                      icon: const Icon(Icons.delete_outline, size: 18),
                    ),
                  ],
                );
              }),
            ],
            if (setMenuChargeRows.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text(
                'Menu modifications add\'l charges',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
              ),
              const SizedBox(height: 6),
              ...setMenuChargeRows.map((row) {
                final dishId = '${row['dishId']}';
                final dishName = '${row['dishName']}';
                final amount = (row['amount'] as num?)?.toDouble() ?? 0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          dishName,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 140,
                        child: TextFormField(
                          initialValue: amount.toStringAsFixed(2),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Add\'l charge',
                            prefixText: 'PHP ',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (v) {
                            final parsed = double.tryParse(v.trim()) ?? 0;
                            setState(() {
                              _newEventSetMenuChargeOverrides[dishId] =
                                  parsed < 0 ? 0 : parsed;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
            if (showSubmitActions) ...[
              const SizedBox(height: 16),
              _buildNewEventSubmitActions(),
            ],
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
            ],
          ),
        ),
      ],
    );
  }

  // Menu View
  Widget _buildEventMenuSection() {
    final cateringDishes =
        _allDishes
            .where(
              (d) =>
                  d.category.toLowerCase().trim() == 'catering' &&
                  !d.archived &&
                  d.available,
            )
            .toList();
    final chargeRows = _newEventSetMenuAdditionalChargeRows();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Menu & Allergens',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: DefaultTabController(
            length: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TabBar(
                  labelColor: const Color(0xFF1E1E1E),
                  unselectedLabelColor: Colors.grey.shade700,
                  indicatorColor: const Color(0xFFFFC024),
                  onTap: (i) => setState(() => _newEventMenuPrefTabIndex = i),
                  tabs: const [
                    Tab(text: 'Allergens'),
                    Tab(text: 'Menu'),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: TabBarView(
                    children: [
                      SingleChildScrollView(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: AllergenSelectorField(
                            initialSerialized: _allergensSerialized,
                            onChanged: (s) => setState(() => _allergensSerialized = s),
                          ),
                        ),
                      ),
                      SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Wrap(
                              spacing: 8,
                              children: [
                                ChoiceChip(
                                  label: const Text('Custom dishes'),
                                  selected: _newEventMenuPrefTabIndex == 0,
                                  onSelected: (_) => setState(
                                    () => _newEventMenuPrefTabIndex = 0,
                                  ),
                                ),
                                ChoiceChip(
                                  label: const Text('Set menu'),
                                  selected: _newEventMenuPrefTabIndex == 1,
                                  onSelected: (_) => setState(
                                    () => _newEventMenuPrefTabIndex = 1,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            InquiryMenuPicker(
                              key: ValueKey<int>(_newEventMenuPrefTabIndex),
                              embedded: true,
                              tabIndex: _newEventMenuPrefTabIndex,
                              cateringDishes: cateringDishes,
                              setMenus: SetMenuStore.instance.activeSetMenus,
                              initialSelections: _newEventMenuBlocks,
                              mode: InquiryMenuPickerMode.staffNewEvent,
                              minCustomDishes: 0,
                              maxCustomDishes: 999,
                              onSelectionChanged: (blocks) {
                                setState(() {
                                  _newEventMenuBlocks = blocks;
                                  _applyNewEventMenuBlocks(blocks);
                                });
                              },
                            ),
                            if (chargeRows.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              const Text(
                                'Add\'l charges (editable)',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 6),
                              ...chargeRows.map((row) {
                                final dishId = '${row['dishId']}';
                                final amount =
                                    (row['amount'] as num?)?.toDouble() ?? 0;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text('${row['dishName']}'),
                                      ),
                                      SizedBox(
                                        width: 140,
                                        child: TextFormField(
                                          initialValue: amount.toStringAsFixed(2),
                                          keyboardType:
                                              const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                          decoration: const InputDecoration(
                                            labelText: 'Add\'l charge',
                                            prefixText: 'PHP ',
                                            isDense: true,
                                            border: OutlineInputBorder(),
                                          ),
                                          onChanged: (v) {
                                            final parsed =
                                                double.tryParse(v.trim()) ?? 0;
                                            setState(() {
                                              _newEventSetMenuChargeOverrides[dishId] =
                                                  parsed < 0 ? 0 : parsed;
                                            });
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_newEventSetMenuAdditionalChargeTotal() > 0) ...[
          const SizedBox(height: 8),
          Text(
            'Set-menu extra dish fees: ${formatPesos(_newEventSetMenuAdditionalChargeTotal())}',
            style: TextStyle(
              color: Colors.orange.shade800,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _openNewEventMenuPicker,
          icon: const Icon(Icons.restaurant_menu, size: 18),
          label: const Text('Open menu picker (dishes or set menu)'),
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

  List<EventOrderDto> get _newEventOrders => _processingOrdersDto.where((o) {
        final s = o.status.trim().toLowerCase();
        return s == 'new_event' || s == 'for_processing';
      }).toList();

  int _orderCountForTab(int tabIndex) {
    if (_isSupervisor) {
      return tabIndex == 0 ? _ongoingOrders.length : 0;
    }
    switch (tabIndex) {
      case 0:
        return _newEventOrders.length;
      case 1:
        return _onlineInquiryOrders.length;
      case 2:
        return _downpaymentOrders.length;
      case 3:
        return _ongoingOrders.length;
      case 4:
        return _postAnalysisOrdersDto.length;
      default:
        return 0;
    }
  }

  List<Widget> _manageEventsTabViews(bool isNarrow) {
    if (_isSupervisor) {
      return [_buildOngoingTableView(isNarrow)];
    }
    return [
      _buildNewEventTab(isNarrow),
      _buildOnlineInquiriesView(isNarrow),
      _buildForDownpaymentTableView(isNarrow),
      _buildOngoingTableView(isNarrow),
      _buildForFullPaymentTableView(isNarrow),
      _buildCompletedEventsView(isNarrow),
      _buildCancelledTab(isNarrow),
    ];
  }

  Widget _tabCountBadge(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFFFC024),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFF242424),
        ),
      ),
    );
  }

  Widget _buildNewEventTab(bool isNarrow) {
    if (_showNewEventForm) {
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: Colors.grey.shade50,
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: () => setState(() {
                    _showNewEventForm = false;
                    _activeNewEventSideTab = _NewEventSideTab.eventInfo;
                  }),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Back to list'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _buildBodyContent(EventStatus.newEvent, isNarrow),
          ),
        ],
      );
    }
    final orders = _newEventOrders;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_isManager)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: () => setState(() {
                  _showNewEventForm = true;
                  _activeNewEventSideTab = _NewEventSideTab.eventInfo;
                }),
                icon: const Icon(Icons.add_circle_outline),
                label: const Text(
                  'CREATE NEW EVENT',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFFC024),
                  foregroundColor: Colors.black,
                ),
              ),
            ),
          ),
        Expanded(
          child: _buildOrdersTablePanel(
            title: '',
            orders: orders,
            emptyMessage: 'No new events.',
            showGuestsAndTotal: false,
          ),
        ),
      ],
    );
  }

  Widget _buildCancelledTab(bool isNarrow) {
    return _buildOrdersTablePanel(
      title: '',
      orders: _cancelledOrdersDto,
      emptyMessage: 'No cancelled events.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 1100;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                color: const Color(0xFF242424),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(
                children: [
                  Text(
                    _visibleStageLabels[_tabController.index].toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFFFFC024),
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Refresh',
                    onPressed:
                        _ordersLoading ? null : _refreshOrdersFromButton,
                    icon: _ordersLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFFFFC024),
                            ),
                          )
                        : const Icon(
                            Icons.refresh,
                            color: Color(0xFFFFC024),
                          ),
                  ),
                ],
              ),
            ),
            Material(
              color: Colors.white,
              elevation: 2,
              shadowColor: Colors.black26,
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                indicatorColor: const Color(0xFFFFC024),
                labelColor: const Color(0xFFFFC024),
                unselectedLabelColor: Colors.grey.shade700,
                tabAlignment: TabAlignment.start,
                tabs: List.generate(_tabCount, (i) {
                  final count = _orderCountForTab(i);
                  return Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_visibleStageLabels[i]),
                        if ((_isSupervisor && count > 0) ||
                            (!_isSupervisor && i <= 4 && count > 0)) ...[
                          const SizedBox(width: 6),
                          _tabCountBadge(count),
                        ],
                      ],
                    ),
                  );
                }),
              ),
            ),
            Expanded(
              child: Container(
                color: const Color(0xFFF7F8FA),
                child: TabBarView(
                  controller: _tabController,
                  children: _manageEventsTabViews(isNarrow),
                ),
              ),
            ),
            ],
          );
        },
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _openNewEventMenuPicker,
                            icon: const Icon(Icons.tune, size: 18),
                            label: const Text('Choose / customize set menu'),
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: Scrollbar(
                              thumbVisibility: true,
                              child: ListView(
                                children: sets.map((s) {
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
                                        label: 'Customize',
                                        onPressed:
                                            s.dishIds.isEmpty
                                                ? null
                                                : () => _applySetMenuToNewEvent(s),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
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
                color: statusColor.withOpacity(0.1),
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
    List<ChecklistItem> editableItems, {
    BuildContext? dialogContext,
  }) async {
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Save checklist'),
            content: const Text(
              'Save checklist changes and update generated checklist output?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Save'),
              ),
            ],
          ),
    );
    if (confirmed != true) return;

    BuildContext? loaderContext;
    try {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          loaderContext = ctx;
          return const AlertDialog(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text('Saving checklist...'),
              ],
            ),
          );
        },
      );

      final checklistPayload =
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
              .toList();

      await EventsApi.instance.replaceChecklist(
        orderId: order.id,
        deductInventory: _isCateringPlusEventOrder(order),
        items: checklistPayload,
      );

      final orderKind =
          order.orderKind == 'catering'
              ? 'catering'
              : order.orderKind == 'event'
                  ? 'event'
                  : (order.orderType.toLowerCase() == 'catering'
                      ? 'catering'
                      : 'event');
      await ManagerCateringApi.instance.patchStageData(
        id: order.id,
        orderKind: orderKind,
        patch: {'checklist': checklistPayload},
      );

      if (loaderContext != null && Navigator.of(loaderContext!).canPop()) {
        Navigator.of(loaderContext!).pop();
      }

      if (dialogContext != null && Navigator.of(dialogContext).canPop()) {
        Navigator.of(dialogContext).pop();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Checklist saved successfully.'),
            backgroundColor: Color(0xFF1DB954),
          ),
        );
      }

      await _refreshOrders();
      await _selectManageEventsOrder(order);
    } catch (e) {
      if (loaderContext != null && Navigator.of(loaderContext!).canPop()) {
        Navigator.of(loaderContext!).pop();
      }
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
      // Generate PDF content (simplified for demo)
      _generatePDFContent(order, editableItems);

      // Create download link (in a real implementation, this would generate and serve the PDF)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF generated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
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

  String _generatePDFContent(
    EventOrderDto order,
    List<ChecklistItem> editableItems,
  ) {
    final buffer = StringBuffer();
    buffer.writeln('EVENT CHECKLIST');
    buffer.writeln('================');
    buffer.writeln('Event: ${order.eventTitle}');
    buffer.writeln('Customer: ${order.customerName}');
    buffer.writeln(
      'Date: ${order.scheduleSlots.isNotEmpty ? order.scheduleSlots.first.date : "TBD"}',
    );
    buffer.writeln('');

    buffer.writeln('CHECKLIST ITEMS:');
    buffer.writeln('----------------');

    for (final item in editableItems) {
      buffer.writeln('');
      buffer.writeln('Item: ${item.item}');
      buffer.writeln('Description: ${item.description}');
      buffer.writeln('Quantity: ${item.quantity}');
      buffer.writeln('Price per item: PHP ${item.cost.toStringAsFixed(2)}');
      buffer.writeln(
        'Total Price: PHP ${(item.cost * item.quantity).toStringAsFixed(2)}',
      );
      buffer.writeln('Status: ${item.isCompleted ? "Completed" : "Pending"}');
      buffer.writeln('----------------');
    }

    final totalCost = editableItems.fold(
      0.0,
      (sum, item) => sum + (item.cost * item.quantity),
    );
    buffer.writeln('');
    buffer.writeln('TOTAL COST: PHP ${totalCost.toStringAsFixed(2)}');

    return buffer.toString();
  }
}
