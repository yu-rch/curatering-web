import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../auth/auth_session.dart';
import '../auth/roles.dart';
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
import '../widgets/customer_footer_feedback.dart';
import '../theme/website_header_font.dart';
import '../constants/catering_meal_types.dart';
import '../utils/gallery_search.dart';
import '../utils/inquiry_pricing.dart';
import '../utils/image_cache.dart';
import 'customer_login.dart';
import 'checkout_page.dart';
import 'my_orders_page.dart';
import 'my_caterings_page.dart';
import 'my_order_tracking_page.dart';
import 'my_profile_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    return '$dateStr · ${startTime.format(context)}-${endTime.format(context)}';
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

class CustomerWebsiteScreen extends StatefulWidget {
  const CustomerWebsiteScreen({
    super.key,
    this.contentEditable = false,
    this.showStaffChrome = true,
    this.staffThemeStudioMode = false,
  });

  final bool contentEditable;
  final bool showStaffChrome;

  /// When true, opens the customer Event Theme Design Studio for staff (Manage Events).
  final bool staffThemeStudioMode;

  @override
  State<CustomerWebsiteScreen> createState() => _CustomerWebsiteScreenState();
}

//Responsive Helpers
bool isMobile(BuildContext context) => MediaQuery.of(context).size.width < 700;

bool isTablet(BuildContext context) =>
    MediaQuery.of(context).size.width >= 700 &&
    MediaQuery.of(context).size.width < 1100;

bool isDesktop(BuildContext context) =>
    MediaQuery.of(context).size.width >= 1100;

double websiteContentMaxWidth(BuildContext context) {
  final width = MediaQuery.of(context).size.width;
  if (width >= 1800) return 1680;
  if (width >= 1400) return 1440;
  if (width >= 1100) return 1280;
  return double.infinity;
}

EdgeInsets websitePagePadding(BuildContext context, {double vertical = 24}) {
  final horizontal =
      isDesktop(context)
          ? 40.0
          : isTablet(context)
          ? 24.0
          : 16.0;
  return EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical);
}

/// Builds each main tab only after it has been opened once, then keeps it in an [IndexedStack].
class _LazyMainTabStack extends StatefulWidget {
  const _LazyMainTabStack({required this.index, required this.childBuilder});

  final int index;
  final Widget Function(int index) childBuilder;

  @override
  State<_LazyMainTabStack> createState() => _LazyMainTabStackState();
}

class _LazyMainTabStackState extends State<_LazyMainTabStack> {
  final Set<int> _activated = {};

  @override
  void initState() {
    super.initState();
    _activated.add(widget.index.clamp(0, 5));
  }

  @override
  void didUpdateWidget(covariant _LazyMainTabStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    _activated.add(widget.index.clamp(0, 5));
  }

  @override
  Widget build(BuildContext context) {
    final idx = widget.index.clamp(0, 5);
    return IndexedStack(
      index: idx,
      sizing: StackFit.passthrough,
      children: List.generate(6, (i) {
        if (!_activated.contains(i)) {
          return const SizedBox.shrink();
        }
        return KeyedSubtree(
          key: ValueKey<String>('site-tab-$i'),
          child: widget.childBuilder(i),
        );
      }),
    );
  }
}

class _CustomerWebsiteScreenState extends State<CustomerWebsiteScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ScrollController _pageScrollController = ScrollController();
  int _navIndex = 0;
  int? _galleryDetailIndex;
  String _gallerySearchQuery = '';
  String _selectedGalleryCategoryId = 'ALL';
  Map<String, dynamic>? _customerData;
  bool _isCustomerLoggedIn = false;
  int _restaurantLoyaltyPoints = 0;
  int _cateringLoyaltyPoints = 0;
  String _selectedRestaurantType = 'RICE MEALS'; // Default selected category
  String _selectedCateringMealType = ''; // Empty = all catering dishes
  List<Map<String, dynamic>> _reorderDishes = [];
  bool _loadingReorder = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  void _recordPageView() {
    final path = ModalRoute.of(context)?.settings.name ?? customerRoute('/');
    unawaited(
      http.post(
        Uri.parse('$apiBaseUrl/api/public/analytics/page-view'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'platform': 'web', 'path': path}),
      ),
    );
  }

  Future<void> _initialize() async {
    _recordPageView();
    MenuStore.instance.addListener(_onMenuChanged);
    CartStore.instance.addListener(_onCartChanged);

    // CMS first (local-cache hydrated) so home can paint without waiting on menu/cart.
    await WebsiteContentStore.instance.ensureLoaded();
    if (mounted) setState(() {});

    // Menu metadata, cart sync, and auth continue in the background.
    unawaited(_loadDeferredBootstrap());
  }

  Future<void> _loadDeferredBootstrap() async {
    try {
      if (MenuStore.instance.activeDishes.isEmpty) {
        await MenuStore.instance.loadDishes();
      }
      await CartStore.instance.init();
      await _checkCustomerAuth();
    } catch (e) {
      debugPrint('Deferred bootstrap error: $e');
    }
    if (mounted) setState(() {});
  }

  void _selectNavIndex(int index) {
    setState(() {
      _galleryDetailIndex = null;
      _navIndex = index;
    });
    // Dish photos are heavy — fetch only when opening menu tabs.
    if (index == 2 || index == 3) {
      unawaited(MenuStore.instance.ensureImagesLoaded());
    }
    if (index == 3) {
      unawaited(LoyaltyRewardsStore.instance.ensureLoaded());
    }
  }

  Future<bool> _confirmAction({
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(confirmLabel),
              ),
            ],
          ),
    );
    return result == true;
  }

  Future<T?> _withLoadingDialog<T>(
    String message,
    Future<T> Function() action,
  ) async {
    var shown = true;
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder:
            (_) => AlertDialog(
              content: Row(
                children: [
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: Text(message)),
                ],
              ),
            ),
      ).then((_) => shown = false),
    );
    try {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      return await action();
    } finally {
      await Future<void>.delayed(const Duration(milliseconds: 120));
      if (mounted && shown) Navigator.of(context, rootNavigator: true).pop();
    }
  }

  Future<void> _checkCustomerAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('customer_token');
    final customerData = prefs.getString('customer_data');
    if (mounted) {
      setState(() {
        _isCustomerLoggedIn = token != null && token.isNotEmpty;
        if (customerData != null) {
          try {
            _customerData = jsonDecode(customerData);
          } catch (_) {
            _customerData = null;
          }
        }
      });
    }
    if (mounted && _isCustomerLoggedIn) {
      unawaited(_loadPopularOrdersForHome());
      unawaited(_refreshLoyaltyPointsFromProfile());
    }
  }

  Future<void> _refreshLoyaltyPointsFromProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('customer_token');
    if (token == null || token.isEmpty) return;
    try {
      final res = await http
          .get(
            Uri.parse('$apiBaseUrl/api/customer/profile'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200 || !mounted) return;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      setState(() {
        _restaurantLoyaltyPoints =
            (data['restaurantLoyaltyPoints'] as num?)?.toInt() ?? 0;
        _cateringLoyaltyPoints =
            (data['cateringLoyaltyPoints'] as num?)?.toInt() ?? 0;
      });
    } catch (_) {
      /* keep last known points */
    }
  }

  Future<void> _handleLogin() async {
    await showDialog(
      context: context,
      builder: (context) => const CustomerLoginPage(),
    );
    if (mounted) {
      await _checkCustomerAuth();
    }
  }

  Future<void> _loadPopularOrdersForHome() async {
    if (!_isCustomerLoggedIn) {
      if (_reorderDishes.isNotEmpty && mounted) {
        setState(() => _reorderDishes = []);
      }
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('customer_token');
    if (token == null || token.isEmpty) return;
    if (mounted) setState(() => _loadingReorder = true);
    try {
      final res = await http
          .get(
            Uri.parse('$apiBaseUrl/api/restaurant/orders'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) {
        if (mounted) setState(() => _loadingReorder = false);
        return;
      }
      final data = jsonDecode(res.body);
      final orders = data['orders'] as List<dynamic>? ?? const [];
      final counts = <String, int>{};
      for (final o in orders) {
        if (o is! Map) continue;
        final m = Map<String, dynamic>.from(o);
        if ((m['status'] ?? '').toString() != 'delivered') continue;
        var rawItems = m['items'];
        List<dynamic> items = const [];
        if (rawItems is String) {
          try {
            items = jsonDecode(rawItems) as List<dynamic>;
          } catch (_) {
            items = const [];
          }
        } else if (rawItems is List) {
          items = rawItems;
        }
        for (final it in items) {
          if (it is! Map) continue;
          final im = Map<String, dynamic>.from(it);
          final id =
              (im['id'] ?? im['dishId'] ?? im['dish_id'] ?? '')
                  .toString()
                  .trim();
          final name =
              (im['name'] ?? im['dishName'] ?? im['dish_name'] ?? '')
                  .toString()
                  .trim();
          final key = id.isNotEmpty ? 'id:$id' : 'n:$name';
          if (key == 'n:') continue;
          final q = int.tryParse('${im['quantity'] ?? 1}') ?? 1;
          counts[key] = (counts[key] ?? 0) + q;
        }
      }
      final sorted =
          counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      final out = <Map<String, dynamic>>[];
      for (final e in sorted.take(10)) {
        final key = e.key;
        MenuDish? d;
        if (key.startsWith('id:')) {
          final id = key.substring(3);
          for (final x in MenuStore.instance.activeDishes) {
            if (x.id == id) {
              d = x;
              break;
            }
          }
        }
        if (d == null && key.startsWith('n:')) {
          final name = key.substring(2);
          for (final x in MenuStore.instance.activeDishes) {
            if (x.name.toLowerCase() == name.toLowerCase()) {
              d = x;
              break;
            }
          }
        }
        if (d != null && d.available) {
          out.add({'dish': d, 'count': e.value});
        }
      }
      if (mounted) {
        setState(() {
          _reorderDishes = out;
          _loadingReorder = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadingReorder = false);
      }
    }
  }

  Future<void> _handleLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('customer_token');
    await prefs.remove('customer_data');
    if (mounted) {
      setState(() {
        _isCustomerLoggedIn = false;
        _customerData = null;
        _reorderDishes = [];
        _loadingReorder = false;
      });
      showAntdMessage(context, 'Logged out successfully');
    }
  }

  void _onMenuChanged() {
    if (!mounted) return;
    // Avoid rebuilding the whole site (and re-decoding home images) for every
    // menu notify — only refresh when a dish grid tab is visible.
    if (_navIndex == 2 || _navIndex == 3 || _isCustomerLoggedIn) {
      setState(() {});
    }
    if (_isCustomerLoggedIn) {
      unawaited(_loadPopularOrdersForHome());
    }
  }

  void _onCartChanged() {
    if (!mounted) return;
    // End drawer / header badge use ListenableBuilder. Restaurant tab has an
    // inline tray that still needs a local rebuild.
    if (_navIndex == 3) setState(() {});
  }

  Future<void> _addToCart(MenuDish dish) async {
    if (!dish.available) {
      showAppSnackBar(
        context,
        '${dish.name} is currently not available',
        error: true,
        icon: Icons.block,
      );
      return;
    }

    await _showSauceSelectionDialog(dish);
  }

  static const List<String> _defaultExtras = [
    'Extra cheese',
    'Extra vegetables',
    'Extra meat',
    'Spicy',
    'No onions',
  ];

  Future<void> _showSauceSelectionDialog(MenuDish dish) async {
    String? selectedSauce;
    var addOnQuantity = 1;
    final selectedExtras = <String>{};
    final notesController = TextEditingController();
    final extraFee =
        dish.additionalChargeAmount > 0
            ? dish.additionalChargeAmount
            : kRestaurantAddonExtraPhp;
    final hasSauces = dish.sauces.isNotEmpty;

    await showDialog<void>(
      context: context,
      builder:
          (dialogContext) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: Text(
                    'Add to tray',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                  content: SizedBox(
                    width: 420,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dish.name,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _dishInfoLine(
                            label: 'Description',
                            value:
                                dish.publicDescription.trim().isEmpty
                                    ? 'No description provided.'
                                    : dish.publicDescription.trim(),
                          ),
                          const SizedBox(height: 8),
                          _dishInfoLine(
                            label: 'Ingredients',
                            value:
                                dish.ingredients.isEmpty
                                    ? 'No ingredients listed.'
                                    : dish.ingredients.join(', '),
                          ),
                          const SizedBox(height: 8),
                          _dishInfoLine(
                            label: 'Allergens',
                            value:
                                dish.allergens.trim().isEmpty
                                    ? 'No allergens listed.'
                                    : dish.allergens.trim(),
                            valueColor:
                                dish.allergens.trim().isEmpty
                                    ? Colors.grey.shade700
                                    : Colors.red.shade700,
                            valueWeight: FontWeight.w600,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Sauces / dips',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          if (!hasSauces)
                            Text(
                              'No sauces available for this dish.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                              ),
                            )
                          else ...[
                            ...dish.sauces.map(
                              (sauce) => RadioListTile<String>(
                                title: Text(
                                  sauce.toUpperCase(),
                                  style: GoogleFonts.poppins(fontSize: 13),
                                ),
                                value: sauce,
                                groupValue: selectedSauce,
                                onChanged: (value) {
                                  setDialogState(() {
                                    selectedSauce = value;
                                    addOnQuantity = 1;
                                  });
                                },
                                activeColor: Colors.amber.shade700,
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                            if (selectedSauce != null) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Add-on portions',
                                      style: GoogleFonts.poppins(fontSize: 13),
                                    ),
                                  ),
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    onPressed:
                                        addOnQuantity > 1
                                            ? () => setDialogState(
                                              () => addOnQuantity--,
                                            )
                                            : null,
                                    icon: const Icon(
                                      Icons.remove_circle_outline,
                                    ),
                                  ),
                                  Text(
                                    '$addOnQuantity',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    onPressed:
                                        () => setDialogState(
                                          () => addOnQuantity++,
                                        ),
                                    icon: const Icon(Icons.add_circle_outline),
                                  ),
                                ],
                              ),
                              Text(
                                'First portion is included; +₱${extraFee.toStringAsFixed(0)} for each extra per main dish.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ],
                          const SizedBox(height: 14),
                          Text(
                            'Extras',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children:
                                _defaultExtras.map((extra) {
                                  final selected = selectedExtras.contains(
                                    extra,
                                  );
                                  return FilterChip(
                                    label: Text(
                                      extra,
                                      style: GoogleFonts.poppins(fontSize: 12),
                                    ),
                                    selected: selected,
                                    selectedColor: Colors.amber.shade100,
                                    checkmarkColor: Colors.amber.shade900,
                                    onSelected: (value) {
                                      setDialogState(() {
                                        if (value) {
                                          selectedExtras.add(extra);
                                        } else {
                                          selectedExtras.remove(extra);
                                        }
                                      });
                                    },
                                  );
                                }).toList(),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: notesController,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: 'Notes',
                              hintText:
                                  'Optional notes for this dish, e.g. no onions',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.poppins(color: Colors.grey.shade600),
                      ),
                    ),
                    ElevatedButton(
                      onPressed:
                          !hasSauces || selectedSauce != null
                              ? () async {
                                final extrasLabel =
                                    selectedExtras.isEmpty
                                        ? null
                                        : selectedExtras.join(', ');
                                final ok = await _confirmAction(
                                  title: 'Add to tray?',
                                  message:
                                      selectedSauce == null
                                          ? extrasLabel == null
                                              ? 'Add ${dish.name} to your tray?'
                                              : 'Add ${dish.name} with $extrasLabel to your tray?'
                                          : extrasLabel == null
                                          ? 'Add ${dish.name} with $selectedSauce to your tray?'
                                          : 'Add ${dish.name} with $selectedSauce and $extrasLabel to your tray?',
                                  confirmLabel: 'Add to tray',
                                );
                                if (!ok) return;
                                await _withLoadingDialog(
                                  'Adding to tray...',
                                  () async {
                                    CartStore.instance.addItem(
                                      dish,
                                      selectedSauce: selectedSauce,
                                      addOnQuantity: addOnQuantity,
                                      addOns: selectedExtras.toList(),
                                      specialInstructions:
                                          notesController.text.trim(),
                                    );
                                  },
                                );
                                Navigator.pop(dialogContext);
                                final rootCtx = this.context;
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  if (!mounted) return;
                                  showAppSnackBar(
                                    rootCtx,
                                    selectedSauce == null
                                        ? '${dish.name} added to tray'
                                        : '${dish.name} with $selectedSauce added to tray',
                                    icon: Icons.shopping_bag_outlined,
                                    duration: const Duration(seconds: 2),
                                  );
                                  _scaffoldKey.currentState?.openEndDrawer();
                                });
                              }
                              : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber.shade700,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(
                        'Add to Tray',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
          ),
    );
    notesController.dispose();
  }

  /// Shared tray line details for sidebar / drawer (sauces, extras, notes, fees).
  Widget _cartItemAddonDetails(
    CartItem cartItem, {
    double fontSize = 11,
    bool compact = false,
  }) {
    final children = <Widget>[];
    void addLine(String text, {Color? color}) {
      children.add(
        Text(
          text,
          style: TextStyle(
            fontSize: fontSize,
            color: color ?? Colors.grey.shade600,
            height: 1.35,
          ),
        ),
      );
    }

    if (cartItem.selectedSauce?.trim().isNotEmpty == true) {
      addLine(
        compact
            ? '${cartItem.selectedSauce!.toUpperCase()} × ${cartItem.addOnQuantity}'
            : 'Sauce: ${cartItem.selectedSauce} × ${cartItem.addOnQuantity}',
      );
    }
    if (cartItem.addonExtraSubtotal > 0) {
      addLine(
        compact
            ? 'EXTRA ADD-ON: ₱${cartItem.addonExtraSubtotal.toStringAsFixed(2)}'
            : 'Extra add-on: ₱${cartItem.addonExtraSubtotal.toStringAsFixed(2)}',
        color: Colors.orange.shade800,
      );
    }
    if (cartItem.addOns.isNotEmpty) {
      addLine(
        compact
            ? 'ADD-ONS: ${cartItem.addOns.join(', ').toUpperCase()}'
            : 'Add-ons: ${cartItem.addOns.join(', ')}',
      );
    }
    if (cartItem.specialInstructions?.trim().isNotEmpty == true) {
      addLine(
        compact
            ? 'NOTE: ${cartItem.specialInstructions}'
            : 'Note: ${cartItem.specialInstructions}',
      );
    }
    if (children.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _dishInfoLine({
    required String label,
    required String value,
    Color? valueColor,
    FontWeight valueWeight = FontWeight.normal,
  }) {
    return RichText(
      text: TextSpan(
        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          TextSpan(
            text: value,
            style: TextStyle(color: valueColor, fontWeight: valueWeight),
          ),
        ],
      ),
    );
  }

  void _openCartSidebar() {
    _scaffoldKey.currentState?.openEndDrawer();
  }

  Future<void> _navigateToCheckout({NavigatorState? navigator}) async {
    if (CartStore.instance.items.isEmpty) {
      showAppSnackBar(
        context,
        'Your tray is empty',
        icon: Icons.shopping_bag_outlined,
      );
      return;
    }
    if (!mounted) return;
    final nav = navigator ?? Navigator.of(context, rootNavigator: true);
    if (!nav.mounted) {
      debugPrint('_navigateToCheckout: navigator not mounted');
      return;
    }
    try {
      nav.push(
        MaterialPageRoute<void>(builder: (context) => const CheckoutPage()),
      );
    } catch (e, st) {
      debugPrint('Navigate to checkout failed: $e\n$st');
      if (!mounted) return;
      showAppSnackBar(
        context,
        'Could not open checkout. Please try again.',
        icon: Icons.error_outline,
      );
    }
  }

  Future<void> _navigateToMyOrders() async {
    final result = await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const MyOrdersPage()));
    if (result == 'login_required' && mounted) {
      await _handleLogin();
    }
  }

  Future<void> _navigateToMyCaterings() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const MyCateringsPage()),
    );
    if (result == 'login_required' && mounted) {
      await _handleLogin();
    }
  }

  Future<void> _navigateToOrderTracking() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const MyOrderTrackingPage()),
    );
    if (result == 'login_required' && mounted) {
      await _handleLogin();
    }
  }

  Future<void> _navigateToMyProfile() async {
    final result = await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const MyProfilePage()));
    if (result == 'login_required' && mounted) {
      await _handleLogin();
    }
    // Refresh customer data after profile update
    if (result == 'profile_updated' && mounted) {
      await _checkCustomerAuth();
    }
  }

  @override
  void dispose() {
    MenuStore.instance.removeListener(_onMenuChanged);
    CartStore.instance.removeListener(_onCartChanged);
    _pageScrollController.dispose();
    super.dispose();
  }

  String _staffHomeRoute() {
    final r = AuthSession.instance.currentUser.value?.role;
    return switch (r) {
      Role.superAdmin => '/manage-accounts',
      Role.supervisor => '/dashboard',
      _ => '/manage-events',
    };
  }

  Future<String?> _pickImageB64() async {
    final x = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1800,
      imageQuality: 82,
    );
    if (x == null) return null;
    final bytes = await x.readAsBytes();
    return base64Encode(bytes);
  }

  Future<List<String>> _pickMultipleImageB64() async {
    final picked = await ImagePicker().pickMultiImage(
      maxWidth: 1800,
      imageQuality: 82,
    );
    if (picked.isEmpty) return const [];
    final out = <String>[];
    for (final x in picked) {
      final bytes = await x.readAsBytes();
      out.add(base64Encode(bytes));
    }
    return out;
  }

  Widget _b64Image(
    String? b64, {
    double? height,
    double? width,
    BoxFit fit = BoxFit.cover,
    Alignment alignment = Alignment.center,
    Widget? placeholder,
  }) {
    final ph =
        placeholder ??
        Container(
          color: Colors.grey.shade300,
          child: const Icon(
            Icons.image_not_supported,
            size: 48,
            color: Colors.grey,
          ),
        );
    if (b64 == null || b64.isEmpty) return ph;
    final normalized =
        b64
            .replaceFirst(RegExp(r'^data:image\/[^;]+;base64,'), '')
            .replaceAll('\n', '')
            .trim();
    return CachedBase64Image(
      base64String: normalized,
      height: height,
      width: width ?? double.infinity,
      fit: fit,
      placeholder: ph,
    );
  }

  String _imageKey(String? b64) {
    final v = (b64 ?? '').trim();
    if (v.isEmpty) return '';
    return v.length <= 48 ? v : v.substring(0, 48);
  }

  Alignment _imageAlignmentFor(WebsiteContentStore w, String? b64) {
    final key = _imageKey(b64);
    final row = w.imageAlignments[key];
    if (row == null) return Alignment.center;
    return Alignment(
      (row['x'] ?? 0).clamp(-1.0, 1.0),
      (row['y'] ?? 0).clamp(-1.0, 1.0),
    );
  }

  Future<void> _editImagePosition({
    required WebsiteContentStore w,
    required String? b64,
  }) async {
    if (b64 == null || b64.isEmpty) return;
    final key = _imageKey(b64);
    var current = _imageAlignmentFor(w, b64);
    final next = await showDialog<Alignment>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Adjust image position'),
            content: StatefulBuilder(
              builder:
                  (ctx, setLocal) => SizedBox(
                    width: 420,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AspectRatio(
                          aspectRatio: 1.8,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: _b64Image(
                              b64,
                              fit: BoxFit.cover,
                              alignment: current,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Horizontal'),
                        ),
                        Slider(
                          value: current.x,
                          min: -1,
                          max: 1,
                          onChanged:
                              (v) => setLocal(
                                () => current = Alignment(v, current.y),
                              ),
                        ),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Vertical'),
                        ),
                        Slider(
                          value: current.y,
                          min: -1,
                          max: 1,
                          onChanged:
                              (v) => setLocal(
                                () => current = Alignment(current.x, v),
                              ),
                        ),
                      ],
                    ),
                  ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, current),
                child: const Text('Save'),
              ),
            ],
          ),
    );
    if (next == null) return;
    w.imageAlignments[key] = {'x': next.x, 'y': next.y};
    await w.save();
    if (mounted) setState(() {});
  }

  Widget _publicHeader() {
    return Container(
      color: const Color(0xFF1E1E1E),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Image.asset('lib/assets/main-2.png', height: 34, fit: BoxFit.contain),
          const SizedBox(width: 16),
          Expanded(
            child: Wrap(
              spacing: 2,
              runSpacing: 4,
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _navLink('Home', 0),
                _navLink('Gallery', 1),
                _navLink('Catering Menu', 2),
                _navLink('Restaurant', 3),
                _navLink('Inquire Now', 4),
                _navLink('Contact Us', 5),
              ],
            ),
          ),
          if (!widget.contentEditable) ...[
            // Tray icon
            ListenableBuilder(
              listenable: CartStore.instance,
              builder: (context, _) {
                final count = CartStore.instance.itemCount;
                return Stack(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.shopping_bag_outlined,
                        color: Colors.white,
                      ),
                      onPressed: _openCartSidebar,
                    ),
                    if (count > 0)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          child: Text(
                            '$count',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(width: 8),
            // Login/Logout Button
            if (_isCustomerLoggedIn)
              AntdProfileMenu(
                triggerLabel: _customerData?['fullName'] ?? 'Customer',
                leading: const Icon(
                  Icons.person_outline,
                  color: Colors.white,
                  size: 20,
                ),
                items: [
                  AntdProfileMenuItem.header(
                    _customerData?['fullName'] ?? 'Customer',
                  ),
                  AntdProfileMenuItem.action(
                    id: 'my_profile',
                    icon: Icons.person_outline,
                    label: 'My Profile',
                    onSelected: () {
                      _navigateToMyProfile();
                    },
                  ),
                  AntdProfileMenuItem.action(
                    id: 'my_orders',
                    icon: Icons.receipt_long,
                    label: 'My Orders',
                    onSelected: () {
                      _navigateToMyOrders();
                    },
                  ),
                  AntdProfileMenuItem.action(
                    id: 'my_caterings',
                    icon: Icons.event,
                    label: 'My Caterings',
                    onSelected: () {
                      _navigateToMyCaterings();
                    },
                  ),
                  AntdProfileMenuItem.action(
                    id: 'order_tracking',
                    icon: Icons.local_shipping_outlined,
                    label: 'Order Tracking',
                    onSelected: () {
                      _navigateToOrderTracking();
                    },
                  ),
                  AntdProfileMenuItem.action(
                    id: 'logout',
                    icon: Icons.logout,
                    label: 'Logout',
                    destructive: true,
                    dividerBefore: true,
                    onSelected: () {
                      _handleLogout();
                    },
                  ),
                ],
              )
            else
              TextButton.icon(
                onPressed: _handleLogin,
                icon: const Icon(Icons.login, color: Colors.white, size: 18),
                label: const Text(
                  'Login',
                  style: TextStyle(color: Colors.white),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _navLink(String label, int index) {
    final on = _navIndex == index && _galleryDetailIndex == null;

    // Handle special navigation for gallery, restaurant, inquire, and contact us
    if (index == 1 && label == 'Gallery') {
      return InkWell(
        onTap:
            () => Navigator.pushReplacementNamed(
              context,
              customerRoute('/gallery'),
            ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.normal,
            ),
          ),
        ),
      );
    }

    if (index == 3 && label == 'Restaurant') {
      return InkWell(
        onTap:
            () => Navigator.pushReplacementNamed(
              context,
              customerRoute('/restaurant'),
            ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.normal,
            ),
          ),
        ),
      );
    }

    if (index == 4 && label == 'Inquire Now') {
      return InkWell(
        onTap:
            () => Navigator.pushReplacementNamed(
              context,
              customerRoute('/inquire'),
            ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.normal,
            ),
          ),
        ),
      );
    }

    if (index == 5 && label == 'Contact Us') {
      return InkWell(
        onTap:
            () => Navigator.pushReplacementNamed(
              context,
              customerRoute('/contact-us'),
            ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.normal,
            ),
          ),
        ),
      );
    }

    return InkWell(
      onTap: () => _selectNavIndex(index),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                color: on ? Colors.white : Colors.white70,
                fontWeight: on ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            if (on)
              Container(height: 2, width: 32, color: const Color(0xFFFFC024)),
          ],
        ),
      ),
    );
  }

  void _showCustomerSiteTab(int index) {
    _selectNavIndex(index);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_pageScrollController.hasClients) return;
      _pageScrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Widget _footerPageLink(String label, int index) {
    return TextButton(
      onPressed: () => _showCustomerSiteTab(index),
      child: Text(label, style: const TextStyle(color: Color(0xFFF5F7F9))),
    );
  }

  Widget _footer(WebsiteContentStore w) {
    return Container(
      color: const Color(0xFF242424),
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth > 900;
          final cols = [
            SizedBox(
              width: wide ? null : 220,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextButton(
                    onPressed: () {},
                    child: Text(
                      w.footerPrivacyLabel,
                      style: const TextStyle(color: Colors.black),
                    ),
                  ),
                  WebsiteRichText(
                    value: w.footerCopyright,
                    style: const TextStyle(fontSize: 11, height: 1.4),
                  ),
                  if (widget.contentEditable)
                    TextButton.icon(
                      onPressed: () async {
                        final value = await showWebsiteRichTextEditor(
                          context: context,
                          title: 'Edit footer copyright',
                          initialValue: w.footerCopyright,
                        );
                        if (value == null || value.isEmpty) return;
                        w.footerCopyright = value;
                        await w.save();
                        setState(() {});
                      },
                      icon: const Icon(Icons.edit, size: 14),
                      label: const Text('Edit'),
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _footerPageLink('GALLERY', 1),
                _footerPageLink('MENU', 2),
                _footerPageLink('RESTAURANT', 3),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _footerPageLink('INQUIRE NOW', 4),
                _footerPageLink('CONTACT US', 5),
                TextButton(
                  onPressed:
                      () => showCustomerFooterFeedback(
                        context,
                        isLoggedIn: _isCustomerLoggedIn,
                        onLogin: _checkCustomerAuth,
                      ),
                  child: const Text(
                    'FEEDBACK',
                    style: TextStyle(color: const Color(0xFFF5F7F9)),
                  ),
                ),
              ],
            ),
            _footerCol(Icons.facebook, w.contactFacebook),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _footerRow(Icons.place, w.contactAddress),
                _footerRow(Icons.schedule, w.contactHours),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _footerRow(Icons.phone, w.contactPhone),
                _footerRow(Icons.email, w.contactEmail),
              ],
            ),
          ];
          if (wide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < cols.length; i++) ...[
                  if (i > 0) const SizedBox(width: 28),
                  Expanded(child: cols[i]),
                ],
                const SizedBox(width: 16),
                Image.asset(
                  'lib/assets/main-2.png',
                  height: 72,
                  fit: BoxFit.contain,
                ),
              ],
            );
          }
          return Wrap(
            spacing: 24,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.start,
            children: cols,
          );
        },
      ),
    );
  }

  Widget _footerCol(IconData icon, String text) {
    return SizedBox(
      width: 200,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.white),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _footerRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.white),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _editChip(VoidCallback onEdit) {
    if (!widget.contentEditable) return const SizedBox.shrink();
    return Positioned(
      top: 8,
      right: 8,
      child: Material(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(20),
        child: IconButton(
          icon: const Icon(Icons.edit, color: Colors.white, size: 20),
          onPressed: onEdit,
        ),
      ),
    );
  }

  Widget _buildOrderAgainStrip() {
    if (_loadingReorder) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8),
        child: LinearProgressIndicator(minHeight: 3),
      );
    }
    if (_reorderDishes.isEmpty) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order again',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Popular picks from your past restaurant orders',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 128,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _reorderDishes.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (ctx, i) {
                final row = _reorderDishes[i];
                final d = row['dish'] as MenuDish;
                final c = row['count'] as int;
                return SizedBox(
                  width: 200,
                  child: Material(
                    color: Colors.white,
                    elevation: 1,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _addToCart(d),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              d.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              'Ordered ${c}x before',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '₱${d.price}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.amber.shade800,
                              ),
                            ),
                          ],
                        ),
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

  Widget _homeSectionTag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: const Color(0xFFFFC024),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
      ),
    );
  }

  Widget _buildHomeHero(WebsiteContentStore w) {
    return Stack(
      children: [
        SizedBox(
          height: isMobile(context) ? 280 : 380,
          width: double.infinity,
          child:
              w.homeHeroImageBase64.isEmpty
                  ? Container(
                    color: Colors.grey.shade700,
                    alignment: Alignment.center,
                    child: Text(
                      'Macrina\'s Kitchen and Catering',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 28,
                        color: Colors.white,
                      ),
                    ),
                  )
                  : _b64Image(
                    w.homeHeroImageBase64,
                    height: isMobile(context) ? 280 : 380,
                    alignment: _imageAlignmentFor(w, w.homeHeroImageBase64),
                  ),
        ),
        Positioned.fill(
          child: Container(color: Colors.black.withValues(alpha: 0.35)),
        ),
        Positioned.fill(
          child: Center(
            child: Image.asset(
              'lib/assets/main-2.png',
              height: isMobile(context) ? 80 : 128,
              fit: BoxFit.contain,
            ),
          ),
        ),
        _editChip(() async {
          final b64 = await _pickImageB64();
          if (b64 == null) return;
          w.homeHeroImageBase64 = b64;
          await w.save();
          setState(() {});
        }),
        if (widget.contentEditable && w.homeHeroImageBase64.isNotEmpty)
          Positioned(
            right: 8,
            bottom: 8,
            child: FilledButton.tonalIcon(
              onPressed:
                  () => _editImagePosition(w: w, b64: w.homeHeroImageBase64),
              icon: const Icon(Icons.open_with, size: 16),
              label: const Text('Position'),
            ),
          ),
      ],
    );
  }

  // Kept for staff preview variants that may re-enable inline home navigation.
  // ignore: unused_element
  Widget _buildHomeInlineNav() {
    return Material(
      color: const Color(0xFF1E1E1E),
      child: SafeArea(
        bottom: false,
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 2,
                  runSpacing: 4,
                  children: [
                    _navLink('Home', 0),
                    _navLink('Gallery', 1),
                    _navLink('Catering Menu', 2),
                    _navLink('Restaurant', 3),
                    _navLink('Inquire Now', 4),
                    _navLink('Contact Us', 5),
                  ],
                ),
              ),
              if (!widget.contentEditable) ...[
                ListenableBuilder(
                  listenable: CartStore.instance,
                  builder: (context, _) {
                    final count = CartStore.instance.itemCount;
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.shopping_bag_outlined,
                            color: Colors.white,
                          ),
                          onPressed: _openCartSidebar,
                        ),
                        if (count > 0)
                          Positioned(
                            right: 6,
                            top: 6,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 16,
                                minHeight: 16,
                              ),
                              child: Text(
                                '$count',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                if (_isCustomerLoggedIn)
                  AntdProfileMenu(
                    triggerLabel: _customerData?['fullName'] ?? 'Account',
                    leading: const Icon(
                      Icons.person_outline,
                      color: Colors.white,
                      size: 20,
                    ),
                    items: [
                      AntdProfileMenuItem.action(
                        id: 'my_profile',
                        icon: Icons.person_outline,
                        label: 'My Profile',
                        onSelected: _navigateToMyProfile,
                      ),
                      AntdProfileMenuItem.action(
                        id: 'logout',
                        icon: Icons.logout,
                        label: 'Logout',
                        destructive: true,
                        dividerBefore: true,
                        onSelected: _handleLogout,
                      ),
                    ],
                  )
                else
                  TextButton(
                    onPressed: _handleLogin,
                    child: const Text(
                      'Login',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRedBannerStrip(WebsiteContentStore w) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: websiteContentMaxWidth(context),
          ),
          child: Column(
            children: [
              WebsiteRichText(
                value: w.redBannerText,
                style: websiteHeaderStyle(
                  fontSize: 22,
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              if (widget.contentEditable)
                TextButton.icon(
                  onPressed: () async {
                    final value = await showWebsiteRichTextEditor(
                      context: context,
                      title: 'Edit red banner text',
                      initialValue: w.redBannerText,
                    );
                    if (value == null || value.isEmpty) return;
                    w.redBannerText = value;
                    await w.save();
                    setState(() {});
                  },
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Edit banner'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLatestEventSection(WebsiteContentStore w) {
    return Stack(
      children: [
        Flex(
          direction: isMobile(context) ? Axis.vertical : Axis.horizontal,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _homeSectionTag(w.latestEventSectionLabel),
                  const SizedBox(height: 12),
                  WebsiteRichText(
                    value: w.latestEventTitle,
                    style: GoogleFonts.pacifico(
                      fontSize: isMobile(context) ? 32 : 48,
                      color: const Color(0xFFB0305A),
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  WebsiteRichText(
                    value: w.latestEventSubtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F0F0),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: WebsiteRichText(
                      value: w.latestEventBody,
                      style: const TextStyle(fontSize: 14, height: 1.45),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: isMobile(context) ? 0 : 24,
              height: isMobile(context) ? 20 : 0,
            ),
            Expanded(
              flex: 5,
              child: Stack(
                children: [
                  Column(
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final totalW = constraints.maxWidth;
                          final gap = 10.0;
                          final halfW = (totalW - gap) / 2;
                          final list = w.latestEventCollageBase64;
                          String? at(int i) => i < list.length ? list[i] : null;
                          return Column(
                            children: [
                              Row(
                                children: [
                                  _collageTile(
                                    at(0),
                                    width: halfW,
                                    height: 170,
                                  ),
                                  SizedBox(width: gap),
                                  _collageTile(
                                    at(1),
                                    width: halfW,
                                    height: 170,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  _collageTile(
                                    at(2),
                                    width: halfW,
                                    height: 170,
                                  ),
                                  SizedBox(width: gap),
                                  _collageTile(
                                    at(3),
                                    width: halfW,
                                    height: 170,
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                  _editChip(() async {
                    final b64 = await _pickImageB64();
                    if (b64 == null) return;
                    if (w.latestEventCollageBase64.length < 4) {
                      w.latestEventCollageBase64.add(b64);
                    } else {
                      w.latestEventCollageBase64[w
                                  .latestEventCollageBase64
                                  .length -
                              1] =
                          b64;
                    }
                    await w.save();
                    setState(() {});
                  }),
                ],
              ),
            ),
          ],
        ),
        _editChip(() async {
          final nextTitle = await showWebsiteRichTextEditor(
            context: context,
            title: 'Edit latest event title',
            initialValue: w.latestEventTitle,
          );
          if (nextTitle == null) return;
          final nextSubtitle = await showWebsiteRichTextEditor(
            context: context,
            title: 'Edit latest event subtitle',
            initialValue: w.latestEventSubtitle,
          );
          if (nextSubtitle == null) return;
          final nextBody = await showWebsiteRichTextEditor(
            context: context,
            title: 'Edit latest event body',
            initialValue: w.latestEventBody,
          );
          if (nextBody == null) return;
          w.latestEventTitle = nextTitle;
          w.latestEventSubtitle = nextSubtitle;
          w.latestEventBody = nextBody;
          await w.save();
          setState(() {});
        }),
      ],
    );
  }

  Widget _buildHome(WebsiteContentStore w) {
    return ListenableBuilder(
      listenable: w,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHomeHero(w),
            _buildRedBannerStrip(w),
            Container(
              color: const Color(0xFFF5F5F5),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: websiteContentMaxWidth(context),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_isCustomerLoggedIn) ...[
                        _buildOrderAgainStrip(),
                        const SizedBox(height: 28),
                      ],
                      _buildLatestEventSection(w),
                      const SizedBox(height: 40),
                      _popularAndDesigns(w),
                    ],
                  ),
                ),
              ),
            ),
            _buildRedBannerStrip(w),
          ],
        );
      },
    );
  }

  Widget _popularDishCarouselTile({
    required String? imageB64,
    required String label,
  }) {
    return _HoverZoomPhotoTile(
      imageB64: imageB64,
      label: label,
      width: 200,
      height: 200,
      margin: const EdgeInsets.only(right: 10),
      placeholderIcon: Icons.fastfood,
    );
  }

  Widget _popularAndDesigns(WebsiteContentStore w) {
    final cmsCount = w.popularDishImageBase64.length;
    final dishes = MenuStore.instance.activeDishes.take(5).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _homeSectionTag(w.popularDishesSectionLabel),
        const SizedBox(height: 8),
        WebsiteRichText(
          value: w.popularDishesSubtitle,
          style: websiteHeaderStyle(fontSize: 18),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children:
                cmsCount > 0
                    ? List.generate(cmsCount, (i) {
                      final label =
                          i < w.popularDishLabels.length &&
                                  w.popularDishLabels[i].trim().isNotEmpty
                              ? w.popularDishLabels[i]
                              : 'Dish ${i + 1}';
                      return _popularDishCarouselTile(
                        imageB64: w.popularDishImageBase64[i],
                        label: label,
                      );
                    })
                    : dishes
                        .map(
                          (d) => _popularDishCarouselTile(
                            imageB64: d.imageBase64,
                            label: d.name,
                          ),
                        )
                        .toList(),
          ),
        ),
        const SizedBox(height: 28),
        _homeSectionTag(w.eventDesignsSectionLabel),
        const SizedBox(height: 8),
        WebsiteRichText(
          value: w.eventDesignsSubtitle,
          style: websiteHeaderStyle(fontSize: 18),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 160,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: List.generate(
              5,
              (i) => _HoverZoomPhotoTile(
                imageB64:
                    i < w.eventDesignImageBase64.length
                        ? w.eventDesignImageBase64[i]
                        : null,
                label: 'Event Design ${i + 1}',
                width: 200,
                height: 160,
                margin: const EdgeInsets.only(right: 8),
                placeholderIcon: Icons.celebration_outlined,
              ),
            ),
          ),
        ),
        if (widget.contentEditable)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () async {
                final b64 = await _pickImageB64();
                if (b64 == null) return;
                w.eventDesignImageBase64.add(b64);
                await w.save();
                setState(() {});
              },
              icon: const Icon(Icons.add_photo_alternate),
              label: const Text('Add event design photo'),
            ),
          ),
      ],
    );
  }

  Widget _collageTile(
    String? b64, {
    required double width,
    required double height,
  }) {
    return SizedBox(
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: _b64Image(b64, fit: BoxFit.cover),
      ),
    );
  }

  Widget _buildGallery(WebsiteContentStore w) {
    return ListenableBuilder(
      listenable: w,
      builder: (context, _) {
        if (_galleryDetailIndex != null) {
          final cat = w.galleryCategories[_galleryDetailIndex!];
          final filteredImages = filterGalleryImages(cat, _gallerySearchQuery);
          return SingleChildScrollView(
            padding: websitePagePadding(context),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: websiteContentMaxWidth(context),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        FilledButton.tonal(
                          onPressed:
                              () => setState(() => _galleryDetailIndex = null),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF1E1E1E),
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('GO BACK'),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFC024),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              cat.label,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        if (widget.contentEditable) ...[
                          const SizedBox(width: 10),
                          FilledButton.icon(
                            onPressed: () async {
                              final b64s = await _pickMultipleImageB64();
                              if (b64s.isEmpty) return;
                              cat.addImagesFromBase64(b64s);
                              await w.save();
                              setState(() {});
                            },
                            icon: const Icon(Icons.add_photo_alternate),
                            label: const Text('Add Photos'),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      onChanged:
                          (v) => setState(
                            () => _gallerySearchQuery = v.trim().toLowerCase(),
                          ),
                      decoration: InputDecoration(
                        hintText: 'SEARCH BY TAG',
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.amber.shade700),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.amber.shade700),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount:
                            isMobile(context)
                                ? 2
                                : isTablet(context)
                                ? 3
                                : 4,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 0.95,
                      ),
                      itemCount: filteredImages.length,
                      itemBuilder: (ctx, i) {
                        final imgData = filteredImages[i];
                        final img = imgData.imageBase64;
                        final fullIndex = cat.images.indexOf(imgData);
                        return Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              showDialog<void>(
                                context: context,
                                builder:
                                    (dlgCtx) => Dialog(
                                      insetPadding: const EdgeInsets.symmetric(
                                        horizontal: 120,
                                        vertical: 60,
                                      ),
                                      child: Stack(
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.all(18),
                                            child: _b64Image(
                                              img,
                                              fit: BoxFit.contain,
                                              alignment: _imageAlignmentFor(
                                                w,
                                                img,
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            top: 8,
                                            right: 8,
                                            child: IconButton(
                                              onPressed:
                                                  () => Navigator.pop(dlgCtx),
                                              icon: const Icon(Icons.close),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                    child: Stack(
                                      children: [
                                        Positioned.fill(
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            child: _b64Image(
                                              img,
                                              fit: BoxFit.cover,
                                              alignment: _imageAlignmentFor(
                                                w,
                                                img,
                                              ),
                                            ),
                                          ),
                                        ),
                                        if (widget.contentEditable)
                                          Positioned(
                                            right: 6,
                                            top: 6,
                                            child: PopupMenuButton<String>(
                                              icon: const Icon(
                                                Icons.more_vert,
                                                color: Colors.white,
                                              ),
                                              onSelected: (value) async {
                                                if (value == 'position') {
                                                  await _editImagePosition(
                                                    w: w,
                                                    b64: img,
                                                  );
                                                  return;
                                                } else if (value == 'tags') {
                                                  final ctrl =
                                                      TextEditingController(
                                                        text: imgData.tags.join(
                                                          ', ',
                                                        ),
                                                      );
                                                  final saved = await showDialog<
                                                    bool
                                                  >(
                                                    context: context,
                                                    builder:
                                                        (ctx) => AlertDialog(
                                                          title: const Text(
                                                            'Photo tags',
                                                          ),
                                                          content: TextField(
                                                            controller: ctrl,
                                                            decoration:
                                                                InputDecoration(
                                                                  hintText:
                                                                      galleryTagsHint(),
                                                                ),
                                                          ),
                                                          actions: [
                                                            TextButton(
                                                              onPressed:
                                                                  () =>
                                                                      Navigator.pop(
                                                                        ctx,
                                                                        false,
                                                                      ),
                                                              child: const Text(
                                                                'Cancel',
                                                              ),
                                                            ),
                                                            FilledButton(
                                                              onPressed:
                                                                  () =>
                                                                      Navigator.pop(
                                                                        ctx,
                                                                        true,
                                                                      ),
                                                              child: const Text(
                                                                'Save',
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                  );
                                                  if (saved == true) {
                                                    imgData.tags
                                                      ..clear()
                                                      ..addAll(
                                                        parseTagsInput(
                                                          ctrl.text,
                                                        ),
                                                      );
                                                  }
                                                  ctrl.dispose();
                                                } else if (value == 'delete' &&
                                                    fullIndex >= 0) {
                                                  cat.images.removeAt(
                                                    fullIndex,
                                                  );
                                                } else if (value == 'up' &&
                                                    fullIndex > 0) {
                                                  final tmp =
                                                      cat.images[fullIndex - 1];
                                                  cat.images[fullIndex - 1] =
                                                      cat.images[fullIndex];
                                                  cat.images[fullIndex] = tmp;
                                                } else if (value == 'down' &&
                                                    fullIndex >= 0 &&
                                                    fullIndex <
                                                        cat.images.length - 1) {
                                                  final tmp =
                                                      cat.images[fullIndex + 1];
                                                  cat.images[fullIndex + 1] =
                                                      cat.images[fullIndex];
                                                  cat.images[fullIndex] = tmp;
                                                } else {
                                                  return;
                                                }
                                                await w.save();
                                                setState(() {});
                                              },
                                              itemBuilder:
                                                  (_) => const [
                                                    PopupMenuItem(
                                                      value: 'position',
                                                      child: Text(
                                                        'Adjust Position',
                                                      ),
                                                    ),
                                                    PopupMenuItem(
                                                      value: 'tags',
                                                      child: Text('Edit tags'),
                                                    ),
                                                    PopupMenuItem(
                                                      value: 'up',
                                                      child: Text('Move Up'),
                                                    ),
                                                    PopupMenuItem(
                                                      value: 'down',
                                                      child: Text('Move Down'),
                                                    ),
                                                    PopupMenuItem(
                                                      value: 'delete',
                                                      child: Text('Delete'),
                                                    ),
                                                  ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  if (imgData.tags.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Wrap(
                                        spacing: 4,
                                        runSpacing: 2,
                                        children:
                                            imgData.tags
                                                .map(
                                                  (t) => Chip(
                                                    label: Text(
                                                      t,
                                                      style: const TextStyle(
                                                        fontSize: 10,
                                                      ),
                                                    ),
                                                    visualDensity:
                                                        VisualDensity.compact,
                                                    padding: EdgeInsets.zero,
                                                  ),
                                                )
                                                .toList(),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final galleryCategories =
            w.galleryCategories
                .where(
                  (c) => galleryCategoryMatchesSearch(c, _gallerySearchQuery),
                )
                .where(
                  (c) =>
                      _selectedGalleryCategoryId == 'ALL' ||
                      c.id == _selectedGalleryCategoryId,
                )
                .toList();

        return SingleChildScrollView(
          padding: websitePagePadding(context),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: websiteContentMaxWidth(context),
              ),
              child: Column(
                children: [
                  WebsiteRichText(
                    value: w.galleryTitle,
                    style: websiteHeaderStyle(
                      fontSize: 42,
                      color: Colors.red.shade400,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  WebsiteRichText(
                    value: w.galleryIntro,
                    textAlign: TextAlign.center,
                    style: const TextStyle(height: 1.35),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    onChanged:
                        (v) => setState(
                          () => _gallerySearchQuery = v.trim().toLowerCase(),
                        ),
                    decoration: InputDecoration(
                      hintText: 'SEARCH BY TAG OR CATEGORY',
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.amber.shade700),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.amber.shade700),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value:
                        w.galleryCategories.any(
                              (c) => c.id == _selectedGalleryCategoryId,
                            )
                            ? _selectedGalleryCategoryId
                            : 'ALL',
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'CATEGORY',
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.amber.shade700),
                      ),
                    ),
                    items: [
                      const DropdownMenuItem(value: 'ALL', child: Text('ALL')),
                      ...w.galleryCategories.map(
                        (cat) => DropdownMenuItem(
                          value: cat.id,
                          child: Text(cat.label),
                        ),
                      ),
                    ],
                    onChanged:
                        (value) => setState(
                          () => _selectedGalleryCategoryId = value ?? 'ALL',
                        ),
                  ),
                  const SizedBox(height: 24),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount:
                          isMobile(context)
                              ? 2
                              : isTablet(context)
                              ? 3
                              : 4,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.1,
                    ),
                    itemCount: galleryCategories.length,
                    itemBuilder: (ctx, i) {
                      final c = galleryCategories[i];
                      final realIndex = w.galleryCategories.indexOf(c);
                      final thumb =
                          c.images.isNotEmpty
                              ? c.images.first.imageBase64
                              : null;
                      return InkWell(
                        onTap:
                            () =>
                                setState(() => _galleryDetailIndex = realIndex),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: AspectRatio(
                                aspectRatio: 1.1,
                                child: _b64Image(
                                  thumb,
                                  fit: BoxFit.cover,
                                  alignment: _imageAlignmentFor(w, thumb),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 8,
                              left: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.92),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.deepOrange.shade200,
                                  ),
                                ),
                                child: Text(
                                  c.label,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                            if (widget.contentEditable)
                              Positioned(
                                top: 4,
                                right: 4,
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.edit,
                                    color: Colors.white,
                                  ),
                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.black45,
                                  ),
                                  onPressed: () async {
                                    final ctrl = TextEditingController(
                                      text: c.label,
                                    );
                                    await showDialog<void>(
                                      context: context,
                                      builder:
                                          (ctx) => AlertDialog(
                                            title: const Text('Category label'),
                                            content: TextField(
                                              controller: ctrl,
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed:
                                                    () => Navigator.pop(ctx),
                                                child: const Text('Cancel'),
                                              ),
                                              TextButton(
                                                onPressed: () {
                                                  c.label = ctrl.text;
                                                  w.save();
                                                  Navigator.pop(ctx);
                                                  setState(() {});
                                                },
                                                child: const Text('Save'),
                                              ),
                                            ],
                                          ),
                                    );
                                  },
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCateringMealTypeChip(String label, String value) {
    final selected =
        value.isEmpty
            ? _selectedCateringMealType.isEmpty
            : cateringMealTypeMatches(_selectedCateringMealType, value);
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        setState(() => _selectedCateringMealType = value);
      },
      selectedColor: const Color(0xFFFFC024),
      checkmarkColor: const Color(0xFF1E1E1E),
    );
  }

  Widget _buildCateringMealTypeFilters() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        _buildCateringMealTypeChip('All', ''),
        for (final t in kCateringMealTypes)
          _buildCateringMealTypeChip(mealTypeDisplayLabel(t), t),
      ],
    );
  }

  Widget _buildCateringMenu() {
    final allDishes = MenuStore.instance.activeDishes;
    final cateringDishes =
        allDishes
            .where((d) => d.category == 'catering')
            .where(
              (d) => cateringMealTypeMatches(
                d.effectiveMealType,
                _selectedCateringMealType,
              ),
            )
            .toList();

    // Show loading state if dishes are empty or currently loading
    if (MenuStore.instance.isLoading || allDishes.isEmpty) {
      return SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 60,
                height: 60,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.amber.shade700,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Loading our delicious menu...',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Show error state
    if (MenuStore.instance.error != null) {
      return SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red.shade400,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Oops, there was an error loading the website.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    color: Colors.grey.shade800,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Try reloading the page.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 32),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.amber.shade600, Colors.amber.shade800],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.amber.shade200,
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: () => MenuStore.instance.ensureImagesLoaded(),
                    icon: const Icon(
                      Icons.refresh_rounded,
                      color: Colors.white,
                    ),
                    label: Text(
                      'Reload Page',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
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

    return SingleChildScrollView(
      padding: websitePagePadding(context),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: websiteContentMaxWidth(context),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 24),
              Text(
                'CATERING MENU',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E1E1E),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFC024),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Explore Our Catering Offerings',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E1E1E),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _buildCateringMealTypeFilters(),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.center,
                child: FilledButton.icon(
                  onPressed: () => _showCustomerSiteTab(4),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1E1E1E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                  ),
                  icon: const Icon(Icons.event_available_outlined),
                  label: const Text('INQUIRE NOW'),
                ),
              ),
              const SizedBox(height: 24),
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
                      if (cateringDishes.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            _selectedCateringMealType.isEmpty
                                ? 'No dishes available'
                                : 'No ${mealTypeDisplayLabel(_selectedCateringMealType)} dishes',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 16,
                            ),
                          ),
                        )
                      else
                        Text(
                          'Our Dishes',
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1E1E1E),
                          ),
                        ),
                      const SizedBox(height: 24),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount:
                              isMobile(context)
                                  ? 2
                                  : isTablet(context)
                                  ? 3
                                  : 5,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.8,
                        ),
                        itemCount: cateringDishes.length,
                        itemBuilder: (ctx, i) {
                          final d = cateringDishes[i];
                          return Card(
                            clipBehavior: Clip.antiAlias,
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: InkWell(
                              onTap:
                                  () => showCateringDishInfoDialog(
                                    context,
                                    d,
                                    onInquireNow: () => _showCustomerSiteTab(4),
                                  ),
                              child: Column(
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(8),
                                      ),
                                      child:
                                          d.imageBase64 != null &&
                                                  d.imageBase64!.isNotEmpty
                                              ? _b64Image(
                                                d.imageBase64,
                                                fit: BoxFit.cover,
                                              )
                                              : Container(
                                                color: Colors.grey.shade200,
                                                child: const Icon(
                                                  Icons.fastfood,
                                                  size: 48,
                                                ),
                                              ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          d.name.toUpperCase(),
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
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
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRestaurantMenu() {
    final allDishes = MenuStore.instance.activeDishes;

    // Show loading state if dishes are empty or currently loading
    if (MenuStore.instance.isLoading || allDishes.isEmpty) {
      return SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 60,
                height: 60,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.amber.shade700,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Loading our delicious menu...',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final restaurantDishes =
        allDishes.where((d) {
          final category = d.category.trim().toLowerCase();
          final isRestaurantCategory =
              category == 'restaurant' ||
              category == 'main_course' ||
              category == 'noodles' ||
              category == 'appetizer' ||
              category == 'rice' ||
              category == 'dessert' ||
              category == 'drinks' ||
              category == 'drink';
          return isRestaurantCategory || d.effectiveMealType.isNotEmpty;
        }).toList();
    final cartItems = CartStore.instance.items;
    final totalAmount = CartStore.instance.totalAmount;
    // Filter restaurant dishes by selected meal type (menu_dishes.meal_type)
    String restaurantTypeForDish(MenuDish dish) {
      final rawType = dish.effectiveMealType.toLowerCase();
      if (rawType.isNotEmpty) return rawType;
      final category = dish.category.trim().toLowerCase();
      switch (category) {
        case 'main_course':
        case 'rice':
          return 'rice meals';
        case 'noodles':
          return 'pasta';
        case 'appetizer':
          return 'sandwiches';
        case 'dessert':
          return 'others';
        case 'drink':
        case 'drinks':
          return 'drinks';
        default:
          return 'others';
      }
    }

    final selectedType = _selectedRestaurantType.trim().toLowerCase();
    final dishes =
        restaurantDishes.where((d) {
          final dishType = restaurantTypeForDish(d);
          return dishType == selectedType;
        }).toList();

    final panelH = (MediaQuery.sizeOf(context).height * 0.72).clamp(
      280.0,
      880.0,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left side - Menu (bounded height so the row stays viewport-sized and the tray checkout stays reachable)
        Expanded(
          flex: 3,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: panelH),
            child: SingleChildScrollView(
              padding: websitePagePadding(context, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and Login button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Center(
                          child: Text(
                            'Restaurant',
                            style: websiteHeaderStyle(
                              fontSize: 42,
                              color: Colors.red.shade400,
                            ),
                          ),
                        ),
                      ),
                      if (!_isCustomerLoggedIn)
                        ElevatedButton(
                          onPressed: _handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFC024),
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'LOG IN TO ORDER',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Loyalty Points Banner
                  _buildLoyaltyBanner(),
                  const SizedBox(height: 16),
                  // Search and Filter
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFFFC024)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const TextField(
                            decoration: InputDecoration(
                              hintText: 'SEARCH',
                              hintStyle: TextStyle(color: Colors.grey),
                              prefixIcon: Icon(
                                Icons.search,
                                color: Colors.grey,
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 1,
                        child: OutlinedButton(
                          onPressed: () {},
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.grey),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('FILTER'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Category tabs
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildCategoryTab('RICE MEALS'),
                        _buildCategoryTab('SILOG MEALS'),
                        _buildCategoryTab('PASTA'),
                        _buildCategoryTab('SANDWICHES'),
                        _buildCategoryTab('OTHERS'),
                        _buildCategoryTab('DRINKS'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Dishes grid
                  if (dishes.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'No dishes available',
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      ),
                    )
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 5,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 0.70,
                          ),
                      itemCount: dishes.length,
                      itemBuilder: (ctx, i) {
                        final d = dishes[i];
                        return Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                flex: 3,
                                child: ClipRRect(
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(12),
                                  ),
                                  child:
                                      d.imageBase64 != null &&
                                              d.imageBase64!.isNotEmpty
                                          ? _b64Image(
                                            d.imageBase64,
                                            fit: BoxFit.cover,
                                          )
                                          : Container(
                                            color: Colors.grey.shade200,
                                            child: const Icon(
                                              Icons.fastfood,
                                              size: 48,
                                            ),
                                          ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        d.name.toUpperCase(),
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 11,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        d.sauces.isNotEmpty
                                            ? d.sauces.join(', ').toUpperCase()
                                            : '',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 9,
                                          color: Colors.grey.shade600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '₱${d.price}',
                                        style: TextStyle(
                                          color: Colors.amber.shade800,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      if (_isCustomerLoggedIn)
                                        SizedBox(
                                          height: 28,
                                          child: ElevatedButton(
                                            onPressed:
                                                d.available
                                                    ? () => _addToCart(d)
                                                    : null,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  d.available
                                                      ? const Color(0xFF1E1E1E)
                                                      : Colors.grey.shade500,
                                              foregroundColor: Colors.white,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                  ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                            ),
                                            child: Text(
                                              d.available
                                                  ? 'Add to tray'
                                                  : 'Not Available',
                                              style: TextStyle(fontSize: 11),
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
                      },
                    ),
                ],
              ),
            ),
          ),
        ),
        // Right side - Tray sidebar
        Padding(
          padding: const EdgeInsets.only(right: 24, top: 8, bottom: 8),
          child: SizedBox(
            width: 280,
            height: panelH,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                    child: const Text(
                      'YOUR TRAY',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  // Tray items
                  Expanded(
                    child:
                        cartItems.isEmpty
                            ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.shopping_bag_outlined,
                                    size: 48,
                                    color: Colors.grey.shade300,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Your tray is empty',
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            )
                            : ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: cartItems.length,
                              itemBuilder: (context, index) {
                                final cartItem = cartItems[index];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Row(
                                    children: [
                                      if (cartItem.dish.imageBase64 != null &&
                                          cartItem.dish.imageBase64!
                                              .isNotEmpty)
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                          child: CachedBase64Image(
                                            base64String:
                                                cartItem.dish.imageBase64,
                                            width: 50,
                                            height: 50,
                                            fit: BoxFit.cover,
                                          ),
                                        )
                                      else
                                        Container(
                                          width: 50,
                                          height: 50,
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade200,
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.fastfood,
                                            size: 20,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              cartItem.dish.name.toUpperCase(),
                                              style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            _cartItemAddonDetails(
                                              cartItem,
                                              fontSize: 8,
                                              compact: true,
                                            ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            'x${cartItem.quantity}',
                                            style: const TextStyle(
                                              fontSize: 10,
                                            ),
                                          ),
                                          Text(
                                            '₱${cartItem.lineSubtotal.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                  ),
                  // Footer with total and checkout
                  if (cartItems.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Colors.grey.shade200),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'TOTAL',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '₱${totalAmount.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () {
                                unawaited(_navigateToCheckout());
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFFC024),
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              child: Text(
                                _isCustomerLoggedIn
                                    ? 'CHECKOUT'
                                    : 'LOG IN TO ORDER',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryTab(String label) {
    final isSelected = label == _selectedRestaurantType;
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: ElevatedButton(
        onPressed: () {
          setState(() {
            _selectedRestaurantType = label;
          });
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected ? const Color(0xFF1E1E1E) : Colors.white,
          foregroundColor: isSelected ? const Color(0xFFFFC024) : Colors.black,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.grey.shade300),
          ),
        ),
        child: Text(label, style: const TextStyle(fontSize: 11)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.staffThemeStudioMode) {
      return Scaffold(
        backgroundColor: const Color(0xFFF7F8FA),
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0,
          title: const Text('Event Theme Design Studio'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: const _InquireForm(staffThemeStudioMode: true),
      );
    }

    final w = WebsiteContentStore.instance;

    Widget body;
    if (_galleryDetailIndex != null && _navIndex == 1) {
      body = _buildGallery(w);
    } else {
      body = _LazyMainTabStack(
        index: _navIndex.clamp(0, 5),
        childBuilder: (i) {
          return switch (i) {
            0 => _buildHome(w),
            1 => _buildGallery(w),
            2 => _buildCateringMenu(),
            3 => _buildRestaurantMenu(),
            4 => const _InquireForm(staffThemeStudioMode: false),
            5 => _ContactSection(
              store: w,
              contentEditable: widget.contentEditable,
              pickB64: _pickImageB64,
            ),
            _ => _buildHome(w),
          };
        },
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF5F5F5),

      body: Column(
        children: [
          if (widget.showStaffChrome && AuthSession.instance.hasToken)
            Material(
              color: Colors.black,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      TextButton(
                        onPressed:
                            () => Navigator.pushReplacementNamed(
                              context,
                              _staffHomeRoute(),
                            ),
                        child: const Text(
                          '← Back to Curatering',
                          style: TextStyle(color: Color(0xFFFFC024)),
                        ),
                      ),
                      const Spacer(),
                      if (widget.contentEditable)
                        Chip(
                          label: const Text(
                            'EDIT MODE',
                            style: TextStyle(fontSize: 11),
                          ),
                          backgroundColor: Colors.amber.shade100,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          _publicHeader(),
          Expanded(
            child: CustomScrollView(
              controller: _pageScrollController,
              slivers: [
                SliverToBoxAdapter(child: body),
                SliverToBoxAdapter(child: _footer(w)),
              ],
            ),
          ),
        ],
      ),
      endDrawer: _buildCartSidebar(),
      endDrawerEnableOpenDragGesture: false,
    );
  }

  Widget _buildCartSidebar() {
    final screenW = MediaQuery.sizeOf(context).width;
    final drawerW = math.min(440.0, screenW * 0.92);

    return Drawer(
      width: drawerW,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(left: Radius.circular(16)),
      ),
      child: ListenableBuilder(
        listenable: CartStore.instance,
        builder: (context, _) {
          final cartItems = CartStore.instance.items;
          final totalAmount = CartStore.instance.totalAmount;
          final itemCount = CartStore.instance.itemCount;

          return Builder(
            builder: (drawerContext) {
              return SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Material(
                      color: const Color(0xFF1E1E1E),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.shopping_bag_outlined,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Your tray',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    itemCount == 0
                                        ? 'Nothing added yet'
                                        : '$itemCount ${itemCount == 1 ? 'item' : 'items'}',
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.75,
                                      ),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Close',
                              icon: const Icon(
                                Icons.close,
                                color: Colors.white,
                              ),
                              onPressed: () => Navigator.pop(drawerContext),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child:
                          cartItems.isEmpty
                              ? Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.shopping_bag_outlined,
                                      size: 56,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Your tray is empty',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey.shade800,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Add dishes from the Restaurant page — '
                                      'this list updates live while the drawer is open.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 13,
                                        height: 1.35,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    FilledButton.icon(
                                      onPressed: () {
                                        Navigator.pop(drawerContext);
                                        setState(() => _navIndex = 3);
                                      },
                                      icon: const Icon(Icons.restaurant_menu),
                                      label: const Text('Go to Restaurant'),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF1E1E1E,
                                        ),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 20,
                                          vertical: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                              : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  12,
                                  12,
                                  8,
                                ),
                                itemCount: cartItems.length,
                                separatorBuilder:
                                    (_, __) => const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  final cartItem = cartItems[index];
                                  return Card(
                                    elevation: 0,
                                    color: Colors.grey.shade50,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(
                                        color: Colors.grey.shade200,
                                      ),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if (cartItem.dish.imageBase64 !=
                                                  null &&
                                              cartItem.dish.imageBase64!
                                                  .isNotEmpty)
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: CachedBase64Image(
                                                base64String:
                                                    cartItem.dish.imageBase64,
                                                width: 56,
                                                height: 56,
                                                fit: BoxFit.cover,
                                              ),
                                            )
                                          else
                                            Container(
                                              width: 56,
                                              height: 56,
                                              decoration: BoxDecoration(
                                                color: Colors.grey.shade200,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Icon(
                                                Icons.restaurant,
                                                size: 24,
                                                color: Colors.grey.shade500,
                                              ),
                                            ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  cartItem.dish.name,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                                _cartItemAddonDetails(
                                                  cartItem,
                                                  fontSize: 12,
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  '₱${cartItem.lineSubtotal.toStringAsFixed(2)}',
                                                  style: TextStyle(
                                                    color:
                                                        Colors.amber.shade900,
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Column(
                                            children: [
                                              IconButton(
                                                visualDensity:
                                                    VisualDensity.compact,
                                                icon: const Icon(
                                                  Icons.remove_circle_outline,
                                                  size: 22,
                                                ),
                                                onPressed: () {
                                                  CartStore.instance
                                                      .updateCartItemQuantity(
                                                        cartItem,
                                                        cartItem.quantity - 1,
                                                      );
                                                },
                                              ),
                                              Text(
                                                '${cartItem.quantity}',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              IconButton(
                                                visualDensity:
                                                    VisualDensity.compact,
                                                icon: const Icon(
                                                  Icons.add_circle_outline,
                                                  size: 22,
                                                ),
                                                onPressed: () {
                                                  CartStore.instance
                                                      .updateCartItemQuantity(
                                                        cartItem,
                                                        cartItem.quantity + 1,
                                                      );
                                                },
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
                    if (cartItems.isNotEmpty)
                      Material(
                        elevation: 8,
                        color: Colors.white,
                        child: SafeArea(
                          top: false,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Total',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      '₱${totalAmount.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.amber.shade900,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                OutlinedButton(
                                  onPressed: () => Navigator.pop(drawerContext),
                                  child: const Text('Keep shopping'),
                                ),
                                const SizedBox(height: 8),
                                FilledButton(
                                  onPressed: () async {
                                    final nav = Navigator.of(
                                      drawerContext,
                                      rootNavigator: true,
                                    );
                                    if (nav.canPop()) {
                                      nav.pop();
                                    }
                                    await WidgetsBinding.instance.endOfFrame;
                                    await Future<void>.delayed(
                                      const Duration(milliseconds: 48),
                                    );
                                    if (!mounted) return;
                                    await _navigateToCheckout(navigator: nav);
                                  },
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF1E1E1E),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text(
                                    'Proceed to checkout',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  // Loyalty Points Banner - shows points earned and reward selection
  Widget _buildLoyaltyBanner() {
    // Get values from LoyaltyRewardsStore (persisted from management page)
    final double minimumOrderForPoints = LoyaltyRewardsStore.instance
        .minimumOrderForPoints(orderType: 'restaurant');
    final int pointsEarned = LoyaltyRewardsStore.instance.pointsEarned(
      orderType: 'restaurant',
    );
    final int currentPoints = _restaurantLoyaltyPoints;
    final availableRewards = LoyaltyRewardsStore.instance.rewardsConditions;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.amber.shade400, Colors.orange.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.3),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.stars, color: Colors.white, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Loyalty Rewards',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Restaurant: $currentPoints pts'
                      '${_cateringLoyaltyPoints > 0 ? ' · Catering: $_cateringLoyaltyPoints pts' : ''}'
                      ' · Earn $pointsEarned pts on orders ≥ ₱${minimumOrderForPoints.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$currentPoints pts',
                  style: TextStyle(
                    color: Colors.orange.shade700,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isCustomerLoggedIn)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed:
                    () => _showRewardDialog(availableRewards, currentPoints),
                icon: const Icon(Icons.redeem, color: Colors.white),
                label: const Text(
                  'Redeem Rewards',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black.withValues(alpha: 0.2),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _handleLogin,
                icon: const Icon(Icons.login, color: Colors.white),
                label: const Text(
                  'Log in to view and redeem rewards',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black.withValues(alpha: 0.2),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Show reward selection dialog
  Future<void> _showRewardDialog(
    List<RewardsCondition> rewards,
    int currentPoints,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.card_giftcard, color: Colors.orange),
              const SizedBox(width: 8),
              const Text('Redeem Rewards'),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.stars, color: Colors.amber.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'Your Points: $currentPoints',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.amber.shade800,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Available Rewards:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                ...rewards.map((reward) {
                  final canRedeem = currentPoints >= reward.minimumPoints;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            canRedeem ? Colors.green : Colors.grey.shade300,
                        child: Icon(
                          canRedeem ? Icons.check : Icons.lock,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      title: Text(reward.reward),
                      subtitle: Text(reward.description),
                      trailing: Chip(
                        label: Text('${reward.minimumPoints} pts'),
                        backgroundColor:
                            canRedeem
                                ? Colors.green.shade100
                                : Colors.grey.shade200,
                        labelStyle: TextStyle(
                          color:
                              canRedeem
                                  ? Colors.green.shade800
                                  : Colors.grey.shade600,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      onTap:
                          canRedeem
                              ? () {
                                Navigator.of(context).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      '${reward.reward} redeemed successfully!',
                                    ),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                              : null,
                    ),
                  );
                }).toList(),
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
}

class _HoverZoomPhotoTile extends StatefulWidget {
  const _HoverZoomPhotoTile({
    required this.imageB64,
    required this.label,
    required this.width,
    required this.height,
    required this.margin,
    required this.placeholderIcon,
  });

  final String? imageB64;
  final String label;
  final double width;
  final double height;
  final EdgeInsets margin;
  final IconData placeholderIcon;

  @override
  State<_HoverZoomPhotoTile> createState() => _HoverZoomPhotoTileState();
}

class _HoverZoomPhotoTileState extends State<_HoverZoomPhotoTile> {
  bool _hovered = false;

  Widget _image({BoxFit fit = BoxFit.cover}) {
    final image = widget.imageB64;
    if (image != null && image.isNotEmpty) {
      final normalized =
          image
              .replaceFirst(RegExp(r'^data:image\/[^;]+;base64,'), '')
              .replaceAll('\n', '')
              .trim();
      return CachedBase64Image(
        base64String: normalized,
        fit: fit,
        placeholder: Container(
          color: Colors.grey.shade300,
          child: const Icon(Icons.broken_image_outlined, size: 42),
        ),
      );
    }
    return Container(
      color: Colors.grey.shade300,
      child: Icon(
        widget.placeholderIcon,
        size: 48,
        color: Colors.grey.shade700,
      ),
    );
  }

  void _openZoom() {
    if (widget.imageB64 == null || widget.imageB64!.isEmpty) return;
    showDialog<void>(
      context: context,
      builder:
          (ctx) => Dialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 80,
              vertical: 48,
            ),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: InteractiveViewer(
                    minScale: 1,
                    maxScale: 5,
                    child: Center(child: _image(fit: BoxFit.contain)),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: widget.margin,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: _openZoom,
          child: AnimatedScale(
            duration: const Duration(milliseconds: 160),
            scale: _hovered ? 1.04 : 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: widget.width,
                height: widget.height,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _image(),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      color: Colors.black.withValues(
                        alpha: _hovered ? 0.08 : 0,
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        color: Colors.black.withValues(alpha: 0.45),
                        child: Text(
                          widget.label,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ContactSection extends StatefulWidget {
  const _ContactSection({
    required this.store,
    required this.contentEditable,
    required this.pickB64,
  });

  final WebsiteContentStore store;
  final bool contentEditable;
  final Future<String?> Function() pickB64;

  @override
  State<_ContactSection> createState() => _ContactSectionState();
}

class _ContactSectionState extends State<_ContactSection> {
  final _helpNameCtrl = TextEditingController();
  final _helpEmailCtrl = TextEditingController();
  final _helpMessageCtrl = TextEditingController();
  bool _submittingHelp = false;

  @override
  void dispose() {
    _helpNameCtrl.dispose();
    _helpEmailCtrl.dispose();
    _helpMessageCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitHelpRequest() async {
    if (_helpNameCtrl.text.trim().isEmpty ||
        _helpEmailCtrl.text.trim().isEmpty ||
        _helpMessageCtrl.text.trim().isEmpty) {
      showAntdMessage(
        context,
        'Please fill in all message fields',
        type: AntdMessageType.error,
      );
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Send message?'),
            content: const Text('Submit this message to Curatering?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Send'),
              ),
            ],
          ),
    );
    if (ok != true) return;

    setState(() => _submittingHelp = true);
    try {
      await ApiClient.instance.postJson(
        '/api/public/help-requests',
        body: {
          'name': _helpNameCtrl.text.trim(),
          'email': _helpEmailCtrl.text.trim(),
          'message': _helpMessageCtrl.text.trim(),
        },
      );
      if (!mounted) return;
      showAntdMessage(context, 'Message sent successfully');
      _helpNameCtrl.clear();
      _helpEmailCtrl.clear();
      _helpMessageCtrl.clear();
    } catch (e) {
      if (!mounted) return;
      showAntdMessage(
        context,
        'Failed to send message',
        type: AntdMessageType.error,
      );
    } finally {
      if (mounted) setState(() => _submittingHelp = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        return SingleChildScrollView(
          padding: websitePagePadding(context, vertical: 32),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: websiteContentMaxWidth(context),
              ),
              child: Column(
                children: [
                  WebsiteRichText(
                    value: widget.store.contactTitle,
                    style: websiteHeaderStyle(
                      fontSize: 42,
                      color: Colors.red.shade400,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFFFC024)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: WebsiteRichText(
                      value: widget.store.contactBannerText,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (widget.store.contactPageIntro.trim().isNotEmpty) ...[
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: WebsiteRichText(
                        value: widget.store.contactPageIntro,
                        style: const TextStyle(fontSize: 15, height: 1.45),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        WebsiteRichText(
                          value: widget.store.contactReachUsLabel,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 16),
                        _contactRow(
                          Icons.facebook,
                          widget.store.contactFacebook,
                          widget.contentEditable,
                          context,
                          (ctx) async {
                            final t = TextEditingController(
                              text: widget.store.contactFacebook,
                            );
                            await showDialog<void>(
                              context: ctx,
                              builder:
                                  (dctx) => AlertDialog(
                                    content: TextField(controller: t),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(dctx),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          widget.store.contactFacebook = t.text;
                                          widget.store.save();
                                          Navigator.pop(dctx);
                                        },
                                        child: const Text('Save'),
                                      ),
                                    ],
                                  ),
                            );
                          },
                        ),
                        _contactRow(
                          Icons.place,
                          widget.store.contactAddress,
                          widget.contentEditable,
                          context,
                          (ctx) async {
                            final t = TextEditingController(
                              text: widget.store.contactAddress,
                            );
                            await showDialog<void>(
                              context: ctx,
                              builder:
                                  (dctx) => AlertDialog(
                                    content: TextField(
                                      controller: t,
                                      maxLines: 2,
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(dctx),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          widget.store.contactAddress = t.text;
                                          widget.store.save();
                                          Navigator.pop(dctx);
                                        },
                                        child: const Text('Save'),
                                      ),
                                    ],
                                  ),
                            );
                          },
                        ),
                        if (widget.store.contactAddress.trim().isNotEmpty) ...[
                          const SizedBox(height: 12),
                          ContactAddressMap(
                            address: widget.store.contactAddress,
                          ),
                        ],
                        _contactRow(
                          Icons.schedule,
                          widget.store.contactHours,
                          widget.contentEditable,
                          context,
                          (ctx) async {
                            final t = TextEditingController(
                              text: widget.store.contactHours,
                            );
                            await showDialog<void>(
                              context: ctx,
                              builder:
                                  (dctx) => AlertDialog(
                                    title: const Text('Hours'),
                                    content: TextField(controller: t),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(dctx),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          widget.store.contactHours = t.text;
                                          widget.store.save();
                                          Navigator.pop(dctx);
                                        },
                                        child: const Text('Save'),
                                      ),
                                    ],
                                  ),
                            );
                          },
                        ),
                        _contactRow(
                          Icons.phone,
                          widget.store.contactPhone,
                          widget.contentEditable,
                          context,
                          (ctx) async {
                            final t = TextEditingController(
                              text: widget.store.contactPhone,
                            );
                            await showDialog<void>(
                              context: ctx,
                              builder:
                                  (dctx) => AlertDialog(
                                    title: const Text('Phone'),
                                    content: TextField(controller: t),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(dctx),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          widget.store.contactPhone = t.text;
                                          widget.store.save();
                                          Navigator.pop(dctx);
                                        },
                                        child: const Text('Save'),
                                      ),
                                    ],
                                  ),
                            );
                          },
                        ),
                        _contactRow(
                          Icons.email,
                          widget.store.contactEmail,
                          widget.contentEditable,
                          context,
                          (ctx) async {
                            final t = TextEditingController(
                              text: widget.store.contactEmail,
                            );
                            await showDialog<void>(
                              context: ctx,
                              builder:
                                  (dctx) => AlertDialog(
                                    title: const Text('Email'),
                                    content: TextField(controller: t),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(dctx),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          widget.store.contactEmail = t.text;
                                          widget.store.save();
                                          Navigator.pop(dctx);
                                        },
                                        child: const Text('Save'),
                                      ),
                                    ],
                                  ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Message Us Form
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.grey.shade50,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'MESSAGE US',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Send us a message and we\'ll get back to you.',
                          style: TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _helpNameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Your Name',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _helpEmailCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Email Address',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _helpMessageCtrl,
                          decoration: const InputDecoration(
                            labelText: 'How can we help you?',
                            border: OutlineInputBorder(),
                            alignLabelWithHint: true,
                          ),
                          maxLines: 4,
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed:
                                _submittingHelp ? null : _submitHelpRequest,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFFC024),
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child:
                                _submittingHelp
                                    ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                    : const Text('SEND MESSAGE'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _contactRow(
    IconData icon,
    String text,
    bool edit,
    BuildContext context,
    Future<void> Function(BuildContext ctx) onEdit,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
          if (edit)
            IconButton(
              icon: const Icon(Icons.edit, size: 18),
              onPressed: () => onEdit(context),
            ),
        ],
      ),
    );
  }
}

class _InquireForm extends StatefulWidget {
  const _InquireForm({this.staffThemeStudioMode = false});

  final bool staffThemeStudioMode;

  @override
  State<_InquireForm> createState() => _InquireFormState();
}

class _InquireFormState extends State<_InquireForm> {
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

  /// Natural pixel size of the selected base image (for placement ↔ bitmap alignment).
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
      MenuStore.instance.loadDishes();
    }
    // Load customer data if logged in
    _loadCustomerData();
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
    } else {
      // User is not logged in, show login dialog
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          final result = await showDialog(
            context: context,
            builder:
                (context) => const CustomerLoginPage(redirectToCheckout: true),
          );
          if (result != null) {
            // Reload customer data after login
            await _loadCustomerData();
          }
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
                        '₱${estimateInquiryCateringTotal(g).toStringAsFixed(0)} '
                            '(₱${kCateringInquiryPricePerGuest.toStringAsFixed(0)} × $g guests)',
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
        horizontal: isDesktop(context) ? 40 : 16,
        vertical: isDesktop(context) ? 24 : 16,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: websiteContentMaxWidth(context),
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
              isDesktop(context)
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
                  : 'Render failed. The server may be busy — try again in a moment.',
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
    Navigator.of(dialogContext).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop(result);
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
                                'Loading image layout…',
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
