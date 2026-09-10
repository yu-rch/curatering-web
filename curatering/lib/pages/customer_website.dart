import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import '../theme/customer_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
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
import '../widgets/app_snackbar.dart';
import '../widgets/antd_message.dart';
import '../widgets/antd_profile_menu.dart';
import '../widgets/pexels_attribution_badge.dart';
import '../widgets/catering_dish_info_dialog.dart';
import '../widgets/website_rich_text.dart';
import '../widgets/image_focus_dialog.dart';
import '../widgets/cms_sections_view.dart';
import '../widgets/customer_site_footer.dart';
import '../widgets/customer_website_topbar.dart';
import '../widgets/lazy_home_etd_sampler.dart';
import '../widgets/lazy_customer_inquire_form.dart';
import '../widgets/lazy_customer_contact_section.dart';
import '../widgets/customer_antd_page_hero.dart';
import '../theme/website_header_font.dart';
import '../constants/catering_meal_types.dart';
import '../constants/home_default_assets.dart';
import '../utils/browser_tab_title.dart';
import '../utils/gallery_search.dart';
import '../utils/image_cache.dart';
import '../utils/responsive_layout.dart';
import '../utils/lazy_customer_login.dart';
import '../utils/lazy_image_picker.dart';


class CustomerWebsiteScreen extends StatefulWidget {
  const CustomerWebsiteScreen({
    super.key,
    this.contentEditable = false,
    this.showStaffChrome = true,
    this.staffThemeStudioMode = false,
    this.returnRoute,
  });

  final bool contentEditable;
  final bool showStaffChrome;

  /// When true, opens the customer Event Theme Design Studio for staff (Manage Events).
  final bool staffThemeStudioMode;

  /// Prefer popping / returning here instead of role home (e.g. `/website-admin`).
  final String? returnRoute;

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
  final GlobalKey _homeNavRowKey = GlobalKey();
  final List<GlobalKey> _homeNavItemKeys = List.generate(6, (_) => GlobalKey());
  double _homeUnderlineLeft = 0;
  double _homeUnderlineWidth = 32;
  bool _homeUnderlineReady = false;
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
  List<Map<String, dynamic>> _salesPopularDishes = [];
  List<Map<String, dynamic>> _salesEventDesigns = [];
  bool _highlightsImagesRequested = false;
  bool _appliedPreviewTabArg = false;

  @override
  void initState() {
    super.initState();
    _pageScrollController.addListener(_maybeLoadHighlightImages);
    _initialize();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_appliedPreviewTabArg) return;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['previewTab'] is int) {
      final tab = (args['previewTab'] as int).clamp(0, 5);
      _appliedPreviewTabArg = true;
      if (tab != _navIndex) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _selectNavIndex(tab);
        });
      }
    }
  }

  void _maybeLoadHighlightImages() {
    if (_highlightsImagesRequested || !mounted) return;
    if (!_pageScrollController.hasClients) return;
    // Wait until the popular-dishes / event-design band is near the viewport.
    if (_pageScrollController.offset < 900) return;
    _highlightsImagesRequested = true;
    unawaited(_loadHomepageHighlights(lite: false));
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

    // Paint homepage sections from local CMS cache immediately.
    await WebsiteContentStore.instance.hydrateFromLocalCache();
    if (mounted) setState(() {});

    unawaited(_refreshWebsiteContent());
    unawaited(_loadDeferredBootstrap());
  }

  Future<void> _refreshWebsiteContent() async {
    try {
      if (widget.contentEditable) {
        // Keep in-memory CMS edits when already in draft mode (preview from admin).
        if (!WebsiteContentStore.instance.isDraftMode) {
          try {
            await WebsiteContentStore.instance.loadDraft();
          } catch (_) {
            await WebsiteContentStore.instance.ensureLoaded();
          }
        }
      } else {
        await WebsiteContentStore.instance.ensureLoaded();
      }
    } catch (e) {
      debugPrint('Website content refresh error: $e');
    }
    if (mounted) setState(() {});
  }

  Future<void> _loadDeferredBootstrap() async {
    unawaited(_bootstrapMenuAndCart());
    unawaited(_checkCustomerAuth());
    // Metadata only on cold load — full base64 images load when the user
    // scrolls near the highlights section (see _maybeLoadHighlightImages).
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (mounted) unawaited(_loadHomepageHighlights(lite: true));
    });
  }

  Future<void> _bootstrapMenuAndCart() async {
    try {
      if (widget.contentEditable) {
        if (MenuStore.instance.activeDishes.isEmpty) {
          await MenuStore.instance.loadDishes();
        }
        unawaited(MenuStore.instance.ensureImagesLoaded());
      }
      await CartStore.instance.init();
    } catch (e) {
      debugPrint('Deferred bootstrap error: $e');
    }
    if (mounted) setState(() {});
  }

  Future<void> _ensureMenuLoaded() async {
    try {
      if (MenuStore.instance.activeDishes.isEmpty) {
        await MenuStore.instance.loadDishes();
      }
      unawaited(MenuStore.instance.ensureImagesLoaded());
    } catch (e) {
      debugPrint('Menu load error: $e');
    }
    if (mounted) setState(() {});
  }

  Future<void> _loadHomepageHighlights({bool lite = true}) async {
    try {
      final uri = Uri.parse(
        '$apiBaseUrl/api/public/homepage-highlights${lite ? '?lite=1' : ''}',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) return;
      final decoded = jsonDecode(res.body);
      if (decoded is! Map) return;
      final popular = <Map<String, dynamic>>[];
      final designs = <Map<String, dynamic>>[];
      final rawPopular = decoded['popularDishes'];
      if (rawPopular is List) {
        for (final row in rawPopular) {
          if (row is! Map) continue;
          final name = (row['name'] ?? '').toString().trim();
          if (name.isEmpty) continue;
          Map<String, dynamic>? existing;
          if (!lite) {
            for (final r in _salesPopularDishes) {
              if ((r['name'] ?? '').toString().trim().toLowerCase() == name.toLowerCase()) {
                existing = r;
                break;
              }
            }
          }
          popular.add({
            'name': name,
            'count': row['count'],
            'imageBase64': lite
                ? (existing?['imageBase64'] ?? '').toString()
                : (row['imageBase64'] ?? '').toString(),
            'description': (row['description'] ?? '').toString(),
          });
        }
      }
      final rawDesigns = decoded['eventDesigns'];
      if (rawDesigns is List) {
        for (final row in rawDesigns) {
          if (row is! Map) continue;
          final image = (row['imageBase64'] ?? '').toString().trim();
          final label = (row['label'] ?? 'Featured Event Design').toString();
          if (!lite && image.isEmpty) continue;
          if (lite && label.trim().isEmpty) continue;
          designs.add({
            'imageBase64': image,
            'label': label,
            'description': (row['description'] ?? '').toString(),
          });
        }
      }
      if (!mounted) return;
      setState(() {
        if (popular.isNotEmpty) _salesPopularDishes = popular;
        if (designs.isNotEmpty) _salesEventDesigns = designs;
      });
    } catch (e) {
      debugPrint('Homepage highlights error: $e');
    }
  }

  /// Preview draft stays on staff `/website` — switch tabs in-app instead of
  /// navigating to customer-host routes (which redirect off the CMS).
  void _openSiteTab(int index, {BuildContext? sheetContext}) {
    if (sheetContext != null) {
      Navigator.pop(sheetContext);
    }
    if (widget.contentEditable) {
      _showCustomerSiteTab(index);
      return;
    }
    const routes = <int, String>{
      1: '/gallery',
      2: '/catering-menu',
      3: '/restaurant',
      4: '/inquire',
      5: '/contact-us',
    };
    final path = routes[index];
    if (path == null) {
      _selectNavIndex(index);
      return;
    }
    Navigator.pushReplacementNamed(context, customerRoute(path));
  }

  void _selectNavIndex(int index) {
    setState(() {
      _galleryDetailIndex = null;
      _navIndex = index;
    });
    // Dish photos are heavy â€” fetch only when opening menu tabs.
    if (index == 2 || index == 3) {
      unawaited(_ensureMenuLoaded());
    }
    if (index == 3) {
      unawaited(LoyaltyRewardsStore.instance.ensureLoaded());
    }
    const labels = [
      'Home',
      'Gallery',
      'Catering Menu',
      'Restaurant',
      'Inquire Now',
      'Contact Us',
    ];
    final label = index >= 0 && index < labels.length ? labels[index] : 'Home';
    unawaited(setBrowserTabTitle(label, staff: false));
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
    await showLazyCustomerLoginDialog(context);
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
    // Refresh dish grids and home kitchen slideshow when menu photos arrive.
    if (_navIndex == 0 ||
        _navIndex == 2 ||
        _navIndex == 3 ||
        _isCustomerLoggedIn) {
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

  Future<void> _showSauceSelectionDialog(MenuDish dish) async {
    final showAddOns = dish.supportsAddOns && dish.sauces.isNotEmpty;
    String? selectedSauce;
    final notesController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder:
          (dialogContext) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: Text(
                    'Add to tray',
                    style: CustomerFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                  content: SizedBox(
                    width: 720,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final wide = constraints.maxWidth >= 560;
                        final image =
                            dish.imageBase64?.isNotEmpty == true
                                ? ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: SizedBox(
                                    width: wide ? 260 : double.infinity,
                                    height: 220,
                                    child: CachedBase64Image(
                                      base64String: dish.imageBase64,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                )
                                : Container(
                                  width: wide ? 260 : double.infinity,
                                  height: 220,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.restaurant, size: 48),
                                );
                        final details = SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                dish.name,
                                style: CustomerFonts.poppins(
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
                              if (showAddOns) ...[
                                const SizedBox(height: 16),
                                Text(
                                  'Add-ons',
                                  style: CustomerFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                ...dish.sauces.map(
                                  (sauce) => RadioListTile<String>(
                                    title: Text(
                                      sauce.toUpperCase(),
                                      style: CustomerFonts.poppins(fontSize: 13),
                                    ),
                                    value: sauce,
                                    groupValue: selectedSauce,
                                    onChanged: (value) {
                                      setDialogState(
                                        () => selectedSauce = value,
                                      );
                                    },
                                    activeColor: Colors.amber.shade700,
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                              ],
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
                        );
                        if (!wide) {
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              image,
                              const SizedBox(height: 12),
                              details,
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            image,
                            const SizedBox(width: 16),
                            Expanded(child: details),
                          ],
                        );
                      },
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: Text(
                        'Cancel',
                        style: CustomerFonts.poppins(color: Colors.grey.shade600),
                      ),
                    ),
                    ElevatedButton(
                      onPressed:
                          !showAddOns || selectedSauce != null
                              ? () async {
                                final ok = await _confirmAction(
                                  title: 'Add to tray?',
                                  message:
                                      selectedSauce == null
                                          ? 'Add ${dish.name} to your tray?'
                                          : 'Add ${dish.name} with $selectedSauce to your tray?',
                                  confirmLabel: 'Add to tray',
                                );
                                if (!ok) return;
                                await _withLoadingDialog(
                                  'Adding to tray...',
                                  () async {
                                    CartStore.instance.addItem(
                                      dish,
                                      selectedSauce: selectedSauce,
                                      addOnQuantity:
                                          selectedSauce == null ? 0 : 1,
                                      addOns: const [],
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
                        style: CustomerFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
          ),
    );
    notesController.dispose();
  }

  /// Resolve tray dish photo from the cart line, falling back to MenuStore.
  String? _trayDishImageBase64(CartItem cartItem) {
    final fromLine = cartItem.dish.imageBase64?.trim();
    if (fromLine != null && fromLine.isNotEmpty) return fromLine;
    for (final d in MenuStore.instance.activeDishes) {
      if (d.id == cartItem.dish.id) {
        final fromMenu = d.imageBase64?.trim();
        if (fromMenu != null && fromMenu.isNotEmpty) return fromMenu;
        break;
      }
    }
    return null;
  }

  Widget _trayDishCapsule(CartItem cartItem) {
    final unitPrice = double.tryParse(cartItem.dish.price) ?? 0;
    final mealRaw = cartItem.dish.effectiveMealType.trim();
    final mealLabel =
        mealRaw.isEmpty
            ? 'Item'
            : mealTypeDisplayLabel(mealRaw);
    final imageB64 = _trayDishImageBase64(cartItem);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child:
                      imageB64 != null
                          ? CachedBase64Image(
                            base64String: imageB64,
                            width: 64,
                            height: 64,
                            fit: BoxFit.cover,
                            placeholder: Container(
                              width: 64,
                              height: 64,
                              color: Colors.grey.shade200,
                              child: Icon(
                                Icons.restaurant,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          )
                          : Container(
                            width: 64,
                            height: 64,
                            color: Colors.grey.shade200,
                            child: Icon(
                              Icons.restaurant,
                              color: Colors.grey.shade500,
                            ),
                          ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cartItem.dish.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: Colors.black,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$mealLabel Ã—${cartItem.quantity} @ â‚±${unitPrice.toStringAsFixed(2)} Â· â‚±${cartItem.lineSubtotal.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          height: 1.3,
                        ),
                      ),
                      _cartItemAddonDetails(cartItem, fontSize: 11),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade200),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '$mealLabel qty',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.remove_circle_outline, size: 22),
                  onPressed: () {
                    CartStore.instance.updateCartItemQuantity(
                      cartItem,
                      cartItem.quantity - 1,
                    );
                  },
                ),
                Text(
                  '${cartItem.quantity}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.add_circle_outline, size: 22),
                  onPressed: () {
                    CartStore.instance.updateCartItemQuantity(
                      cartItem,
                      cartItem.quantity + 1,
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
            ? '${cartItem.selectedSauce!.toUpperCase()} Ã— ${cartItem.addOnQuantity}'
            : 'Sauce: ${cartItem.selectedSauce} Ã— ${cartItem.addOnQuantity}',
      );
    }
    if (cartItem.addonExtraSubtotal > 0) {
      addLine(
        compact
            ? 'EXTRA ADD-ON: â‚±${cartItem.addonExtraSubtotal.toStringAsFixed(2)}'
            : 'Extra add-on: â‚±${cartItem.addonExtraSubtotal.toStringAsFixed(2)}',
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
    unawaited(MenuStore.instance.ensureImagesLoaded());
    _scaffoldKey.currentState?.openEndDrawer();
  }

  void _openHomeMobileNavMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) {
        Widget navTile(String label, VoidCallback onTap, {bool active = false}) {
          return ListTile(
            title: Text(
              label,
              style: TextStyle(
                color: active ? const Color(0xFFFFC024) : Colors.white,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            onTap: () {
              Navigator.pop(sheetCtx);
              onTap();
            },
          );
        }

        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                navTile(
                  'Home',
                  () => _selectNavIndex(0),
                  active: _navIndex == 0 && _galleryDetailIndex == null,
                ),
                navTile(
                  'Gallery',
                  () => _openSiteTab(1),
                ),
                navTile(
                  'Catering Menu',
                  () => _openSiteTab(2),
                ),
                navTile(
                  'Restaurant',
                  () => _openSiteTab(3),
                ),
                navTile(
                  'Inquire Now',
                  () => _openSiteTab(4),
                ),
                navTile(
                  'Contact Us',
                  () => _openSiteTab(5),
                ),
                if (!widget.contentEditable)
                  navTile(
                    'Track Order',
                    () => Navigator.pushReplacementNamed(
                      context,
                      customerRoute('/track-order'),
                    ),
                  ),
                if (!widget.contentEditable) ...[
                  const Divider(color: Colors.white24),
                  if (_isCustomerLoggedIn) ...[
                    ListTile(
                      leading: const Icon(Icons.person_outline, color: Colors.white70),
                      title: Text(
                        _customerData?['fullName'] ?? 'Customer',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                      enabled: false,
                    ),
                    ListTile(
                      leading: const Icon(Icons.person_outline, color: Colors.white70),
                      title: const Text('My Profile', style: TextStyle(color: Colors.white)),
                      onTap: () {
                        Navigator.pop(sheetCtx);
                        _navigateToMyProfile();
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.receipt_long, color: Colors.white70),
                      title: const Text('My Orders', style: TextStyle(color: Colors.white)),
                      onTap: () {
                        Navigator.pop(sheetCtx);
                        _navigateToMyOrders();
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.event, color: Colors.white70),
                      title: const Text('My Caterings', style: TextStyle(color: Colors.white)),
                      onTap: () {
                        Navigator.pop(sheetCtx);
                        _navigateToMyCaterings();
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.local_shipping_outlined, color: Colors.white70),
                      title: const Text('Order Tracking', style: TextStyle(color: Colors.white)),
                      onTap: () {
                        Navigator.pop(sheetCtx);
                        _navigateToOrderTracking();
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.logout, color: Colors.redAccent),
                      title: const Text('Logout', style: TextStyle(color: Colors.redAccent)),
                      onTap: () {
                        Navigator.pop(sheetCtx);
                        _handleLogout();
                      },
                    ),
                  ] else
                    ListTile(
                      leading: const Icon(Icons.login, color: Colors.white70),
                      title: const Text('Login', style: TextStyle(color: Colors.white)),
                      onTap: () {
                        Navigator.pop(sheetCtx);
                        _handleLogin();
                      },
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMobileTrayButton() {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 16,
      child: ListenableBuilder(
        listenable: CartStore.instance,
        builder: (context, _) {
          final itemCount = CartStore.instance.itemCount;
          final total = CartStore.instance.totalAmount;
          if (itemCount <= 0) return const SizedBox.shrink();
          return SafeArea(
            top: false,
            child: ElevatedButton.icon(
              onPressed: _openCartSidebar,
              icon: const Icon(Icons.shopping_bag_outlined),
              label: Text(
                'YOUR TRAY Â· $itemCount ${itemCount == 1 ? 'ITEM' : 'ITEMS'} Â· â‚±${total.toStringAsFixed(2)}',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E1E1E),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          );
        },
      ),
    );
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
      nav.pushNamed(customerRoute('/checkout'));
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
    ).pushNamed(customerRoute('/my-orders'));
    if (result == 'login_required' && mounted) {
      await _handleLogin();
    }
  }

  Future<void> _navigateToMyCaterings() async {
    final result = await Navigator.of(
      context,
    ).pushNamed(customerRoute('/my-inquiries'));
    if (result == 'login_required' && mounted) {
      await _handleLogin();
    }
  }

  Future<void> _navigateToOrderTracking() async {
    final result = await Navigator.of(
      context,
    ).pushNamed(customerRoute('/my-tracking'));
    if (result == 'login_required' && mounted) {
      await _handleLogin();
    }
  }

  Future<void> _navigateToMyProfile() async {
    final result = await Navigator.of(
      context,
    ).pushNamed(customerRoute('/my-profile'));
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
    _pageScrollController.removeListener(_maybeLoadHighlightImages);
    MenuStore.instance.removeListener(_onMenuChanged);
    CartStore.instance.removeListener(_onCartChanged);
    _pageScrollController.dispose();
    super.dispose();
  }

  String _staffHomeRoute() {
    final r = AuthSession.instance.currentUser.value?.role;
    return switch (r) {
      Role.superAdmin => '/dashboard',
      Role.supervisor => '/manage-events',
      _ => '/manage-events',
    };
  }

  Future<String?> _pickImageB64() => pickImageBase64();

  Future<List<String>> _pickMultipleImageB64() => pickMultipleImagesBase64();

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
    await w.saveDraft();
    if (mounted) setState(() {});
  }

  Widget _publicHeader() {
    final mobile = isMobileWidth(context);

    final logo = InkWell(
      onTap: () => _selectNavIndex(0),
      child: Image.asset(
        'lib/assets/main-2.png',
        height: 34,
        fit: BoxFit.contain,
      ),
    );

    final navLinks = _buildHomeSlidingNav();
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateHomeUnderline());

    final trailingActions = !widget.contentEditable
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.local_shipping_outlined,
                  color: Colors.white,
                ),
                tooltip: 'Track your order',
                onPressed: () async {
                  if (_isCustomerLoggedIn) {
                    await _navigateToOrderTracking();
                    return;
                  }
                  if (!mounted) return;
                  Navigator.of(context).pushNamed(customerRoute('/track-order'));
                },
              ),
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
              if (!mobile) ...[
                const SizedBox(width: 8),
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
          )
        : const SizedBox.shrink();

    return Container(
      color: const Color(0xFF1E1E1E),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: mobile
          ? Row(
              children: [
                logo,
                IconButton(
                  icon: const Icon(Icons.menu, color: Colors.white),
                  tooltip: 'Menu',
                  onPressed: _openHomeMobileNavMenu,
                ),
                const Spacer(),
                trailingActions,
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: logo,
                  ),
                ),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: navLinks,
                  ),
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: trailingActions,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildHomeSlidingNav() {
    const labels = [
      'Home',
      'Gallery',
      'Catering Menu',
      'Restaurant',
      'Inquire Now',
      'Contact Us',
    ];
    return Stack(
      key: _homeNavRowKey,
      clipBehavior: Clip.none,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < labels.length; i++)
              KeyedSubtree(
                key: _homeNavItemKeys[i],
                child: _navLink(labels[i], i),
              ),
          ],
        ),
        if (_homeUnderlineReady)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            left: _homeUnderlineLeft,
            bottom: 2,
            width: _homeUnderlineWidth,
            height: 2,
            child: const ColoredBox(color: Color(0xFFFFC024)),
          ),
      ],
    );
  }

  void _updateHomeUnderline() {
    if (!mounted) return;
    final activeIndex = _navIndex.clamp(0, _homeNavItemKeys.length - 1);
    final itemCtx = _homeNavItemKeys[activeIndex].currentContext;
    final rowCtx = _homeNavRowKey.currentContext;
    if (itemCtx == null || rowCtx == null) return;
    final itemBox = itemCtx.findRenderObject() as RenderBox?;
    final rowBox = rowCtx.findRenderObject() as RenderBox?;
    if (itemBox == null ||
        rowBox == null ||
        !itemBox.hasSize ||
        !rowBox.hasSize) {
      return;
    }
    final offset = itemBox.localToGlobal(Offset.zero, ancestor: rowBox);
    const barWidth = 32.0;
    final left = offset.dx + (itemBox.size.width - barWidth) / 2;

    if (!_homeUnderlineReady) {
      final seedLeft = CustomerWebsiteTopBar.sharedUnderlineLeft ?? left;
      final seedWidth = CustomerWebsiteTopBar.sharedUnderlineWidth ?? barWidth;
      setState(() {
        _homeUnderlineLeft = seedLeft;
        _homeUnderlineWidth = seedWidth;
        _homeUnderlineReady = true;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _homeUnderlineLeft = left;
          _homeUnderlineWidth = barWidth;
        });
        CustomerWebsiteTopBar.sharedUnderlineLeft = left;
        CustomerWebsiteTopBar.sharedUnderlineWidth = barWidth;
      });
      return;
    }

    if (_homeUnderlineLeft == left && _homeUnderlineWidth == barWidth) return;
    setState(() {
      _homeUnderlineLeft = left;
      _homeUnderlineWidth = barWidth;
    });
    CustomerWebsiteTopBar.sharedUnderlineLeft = left;
    CustomerWebsiteTopBar.sharedUnderlineWidth = barWidth;
  }

  Widget _navLink(String label, int index) {
    final on = _navIndex == index && _galleryDetailIndex == null;

    VoidCallback onTap = () => _openSiteTab(index);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Text(
          label,
          style: TextStyle(
            color: on ? Colors.white : Colors.white70,
            fontWeight: on ? FontWeight.w700 : FontWeight.w500,
          ),
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
            style: CustomerFonts.poppins(
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
                              'â‚±${d.price}',
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
    final hasHeroImage = w.homeHeroImageBase64.trim().isNotEmpty;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        SizedBox(
          height: isMobile(context) ? 280 : 380,
          width: double.infinity,
          child:
              hasHeroImage
                  ? _b64Image(
                    w.homeHeroImageBase64,
                    height: isMobile(context) ? 280 : 380,
                    alignment: _imageAlignmentFor(w, w.homeHeroImageBase64),
                  )
                  : Image.asset(
                    HomeDefaultAssets.hero,
                    height: isMobile(context) ? 280 : 380,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    filterQuality: FilterQuality.medium,
                  ),
        ),
        // Soften photo so centered logo stays readable.
        Positioned.fill(
          child: Container(color: Colors.black.withValues(alpha: 0.28)),
        ),
        Positioned.fill(
          child: Center(
            child: Image.asset(
              'lib/assets/main-2.png',
              height: isMobile(context) ? 80 : 128,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
            ),
          ),
        ),
        _editChip(() async {
          final b64 = await _pickImageB64();
          if (b64 == null) return;
          w.homeHeroImageBase64 = b64;
          await w.saveDraft();
          setState(() {});
        }),
        if (widget.contentEditable && hasHeroImage)
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
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
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
    final bannerStyle = websiteHeaderStyle(
      fontSize: 22,
      color: const Color(0xFFFFC024),
      fontWeight: FontWeight.w700,
    );
    return Container(
      width: double.infinity,
      color: const Color(0xFF1E1E1E),
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        children: [
          _RedBannerMarquee(text: w.redBannerText, style: bannerStyle),
          if (widget.contentEditable)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: TextButton.icon(
                onPressed: () async {
                  final value = await showWebsiteRichTextEditor(
                    context: context,
                    title: 'Edit red banner text',
                    initialValue: w.redBannerText,
                  );
                  if (value == null || value.isEmpty) return;
                  w.redBannerText = value;
                  await w.saveDraft();
                  setState(() {});
                },
                icon: const Icon(Icons.edit, size: 16, color: Color(0xFFFFC024)),
                label: const Text(
                  'Edit banner',
                  style: TextStyle(color: Color(0xFFFFC024)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLatestEventCollage(WebsiteContentStore w) {
    return LayoutBuilder(
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
                  height: 150,
                  fallbackAsset: HomeDefaultAssets.collageAt(0),
                ),
                SizedBox(width: gap),
                _collageTile(
                  at(1),
                  width: halfW,
                  height: 150,
                  fallbackAsset: HomeDefaultAssets.collageAt(1),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _collageTile(
                  at(2),
                  width: halfW,
                  height: 150,
                  fallbackAsset: HomeDefaultAssets.collageAt(2),
                ),
                SizedBox(width: gap),
                _collageTile(
                  at(3),
                  width: halfW,
                  height: 150,
                  fallbackAsset: HomeDefaultAssets.collageAt(3),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildEtdAdvertCard({required bool compact}) {
    return LazyHomeEtdSampler(compact: compact);
  }

  List<MenuDish> _restaurantActiveDishes() {
    return MenuStore.instance.activeDishes
        .where((d) => d.category.trim().toLowerCase() == 'restaurant')
        .toList();
  }

  Widget _buildKitchenDishSlideshow() {
    return ListenableBuilder(
      listenable: MenuStore.instance,
      builder: (context, _) {
        final dishes = _restaurantActiveDishes();
        if (dishes.isEmpty) {
          return Container(
            height: 140,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.grey.shade800,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Restaurant dishes coming soon',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          );
        }
        return _HomeKitchenDishCarousel(dishes: dishes);
      },
    );
  }

  Widget _buildOwnerBlurb(WebsiteContentStore w) {
    final blurb = w.ownerBlurb.trim();
    if (blurb.isEmpty && !widget.contentEditable) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _homeSectionTag('ABOUT'),
        const SizedBox(height: 8),
        if (blurb.isEmpty)
          Text(
            'Add an About section from the website CMS.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          )
        else
          WebsiteRichText(
            value: blurb,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: Colors.grey.shade800,
            ),
          ),
      ],
    );
  }

  Widget _buildHomeSidePanel(WebsiteContentStore w) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            w.kitchenPanelTitle.trim().isEmpty
                ? "Macrina's Kitchen"
                : w.kitchenPanelTitle,
            style: const TextStyle(
              color: Color(0xFFFFC024),
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            w.kitchenPanelSubtitle.trim().isEmpty
                ? 'Restaurant favorites ready for dine-in and pickup.'
                : w.kitchenPanelSubtitle,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 10),
          _buildKitchenDishSlideshow(),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.center,
            child: OutlinedButton(
            onPressed:
                () => Navigator.pushReplacementNamed(
                  context,
                  customerRoute('/restaurant'),
                ),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFFFC024),
              side: const BorderSide(color: Color(0xFFFFC024)),
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            child: const Text('Go to Restaurant'),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            w.cateringPanelTitle.trim().isEmpty
                ? "Macrina's Catering"
                : w.cateringPanelTitle,
            style: const TextStyle(
              color: Color(0xFFFFC024),
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            w.cateringPanelSubtitle.trim().isEmpty
                ? 'Full-service catering with event theme designs.'
                : w.cateringPanelSubtitle,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 10),
          _buildEtdAdvertCard(compact: true),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.center,
            child: OutlinedButton(
            onPressed:
                () => Navigator.pushReplacementNamed(
                  context,
                  customerRoute('/inquire'),
                ),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFFFC024),
              side: const BorderSide(color: Color(0xFFFFC024)),
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            child: const Text(
              'Inquire Now',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLatestEventSection(WebsiteContentStore w) {
    final mobile = isMobile(context);
    return Stack(
      children: [
        Flex(
          direction: mobile ? Axis.vertical : Axis.horizontal,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _homeSectionTag(w.latestEventSectionLabel),
                  const SizedBox(height: 12),
                  WebsiteRichText(
                    value: w.latestEventTitle,
                    style: CustomerFonts.pacifico(
                      fontSize: mobile ? 32 : 48,
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
                  const SizedBox(height: 12),
                  Stack(
                    children: [
                      _buildLatestEventCollage(w),
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
                        await w.saveDraft();
                        setState(() {});
                      }),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(width: mobile ? 0 : 20, height: mobile ? 20 : 0),
            Expanded(flex: 4, child: _buildHomeSidePanel(w)),
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
          await w.saveDraft();
          setState(() {});
        }),
      ],
    );
  }

  Widget _buildHome(WebsiteContentStore w) {
    return ListenableBuilder(
      listenable: w,
      builder: (context, _) {
        final blocks = w.homeLayout.isEmpty
            ? [
                CmsPageBlock(id: 'hero', label: 'Hero'),
                CmsPageBlock(id: 'banner', label: 'Banner'),
                CmsPageBlock(id: 'latestEvent', label: 'Latest event'),
                CmsPageBlock(id: 'about', label: 'About'),
                CmsPageBlock(id: 'popularDishes', label: 'Popular dishes'),
                CmsPageBlock(id: 'eventDesigns', label: 'Event designs'),
                CmsPageBlock(id: 'extras', label: 'Extra sections'),
              ]
            : w.homeLayout;
        Widget blockFor(CmsPageBlock block) {
          if (!block.visible) return const SizedBox.shrink();
          switch (block.id) {
            case 'hero':
              return _buildHomeHero(w);
            case 'banner':
              return _buildRedBannerStrip(w);
            case 'latestEvent':
              return Padding(
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
                      ],
                    ),
                  ),
                ),
              );
            case 'about':
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: websiteContentMaxWidth(context),
                    ),
                    child: _buildOwnerBlurb(w),
                  ),
                ),
              );
            case 'popularDishes':
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: websiteContentMaxWidth(context),
                    ),
                    child: _buildPopularDishesCarousel(w),
                  ),
                ),
              );
            case 'eventDesigns':
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: websiteContentMaxWidth(context),
                    ),
                    child: _eventDesignsSection(w),
                  ),
                ),
              );
            case 'extras':
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: websiteContentMaxWidth(context),
                    ),
                    child: CmsSectionsView(
                      sections: w.pageExtraSections['home'] ?? const [],
                    ),
                  ),
                ),
              );
            default:
              return const SizedBox.shrink();
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final block in blocks) blockFor(block),
          ],
        );
      },
    );
  }

  Widget _popularDishCarouselTile({
    required String? imageB64,
    required String label,
    String? description,
  }) {
    return _HoverZoomPhotoTile(
      imageB64: imageB64,
      label: label,
      description: description,
      width: 200,
      height: 200,
      margin: const EdgeInsets.only(right: 10),
      placeholderIcon: Icons.fastfood,
      onTap: () => Navigator.pushReplacementNamed(
        context,
        customerRoute('/catering-menu'),
      ),
    );
  }

  String _popularDishLabel(WebsiteContentStore w, int index) {
    if (index < w.popularDishLabels.length &&
        w.popularDishLabels[index].trim().isNotEmpty) {
      return w.popularDishLabels[index].trim();
    }
    final dishes = MenuStore.instance.activeDishes;
    if (index < dishes.length && dishes[index].name.trim().isNotEmpty) {
      return dishes[index].name.trim();
    }
    return 'Popular dish ${index + 1}';
  }

  List<MenuDish> _fallbackPopularDishes() {
    if (_reorderDishes.isNotEmpty) {
      return _reorderDishes
          .map((row) => row['dish'] as MenuDish)
          .take(10)
          .toList();
    }
    return MenuStore.instance.activeDishes.take(10).toList();
  }

  Widget _buildPopularDishesCarousel(WebsiteContentStore w) {
    return ListenableBuilder(
      listenable: MenuStore.instance,
      builder: (context, _) {
        final cmsCount = w.popularDishImageBase64.length;
        final fallbackDishes = _fallbackPopularDishes();
        final salesPopular =
            _salesPopularDishes
                .where(
                  (row) =>
                      (row['imageBase64'] ?? '').toString().trim().isNotEmpty ||
                      (row['name'] ?? '').toString().trim().isNotEmpty,
                )
                .toList();
        final useSalesPopular =
            !widget.contentEditable && salesPopular.isNotEmpty;

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
                    useSalesPopular
                        ? salesPopular.map((row) {
                          final name = (row['name'] ?? 'Popular dish')
                              .toString()
                              .trim();
                          final image = (row['imageBase64'] ?? '')
                              .toString()
                              .trim();
                          final description = (row['description'] ?? '')
                              .toString()
                              .trim();
                          MenuDish? menuMatch;
                          for (final d in MenuStore.instance.activeDishes) {
                            if (d.name.trim().toLowerCase() ==
                                name.toLowerCase()) {
                              menuMatch = d;
                              break;
                            }
                          }
                          return _popularDishCarouselTile(
                            imageB64:
                                image.isNotEmpty
                                    ? image
                                    : menuMatch?.imageBase64,
                            label: name.isNotEmpty ? name : 'Popular dish',
                            description:
                                description.isNotEmpty
                                    ? description
                                    : (menuMatch?.publicDescription
                                            .trim()
                                            .isNotEmpty ==
                                        true
                                    ? menuMatch!.publicDescription.trim()
                                    : null),
                          );
                        }).toList()
                        : cmsCount > 0 ||
                            w.popularDishLabels.any((l) => l.trim().isNotEmpty)
                        ? List.generate(
                          [
                            cmsCount,
                            w.popularDishLabels.length,
                            10,
                          ].reduce(math.max),
                          (i) {
                          final label = _popularDishLabel(w, i);
                          final description =
                              i < MenuStore.instance.activeDishes.length
                                  ? MenuStore.instance
                                      .activeDishes[i]
                                      .publicDescription
                                      .trim()
                                  : null;
                          return _popularDishCarouselTile(
                            imageB64:
                                i < w.popularDishImageBase64.length
                                    ? w.popularDishImageBase64[i]
                                    : null,
                            label: label,
                            description:
                                description != null && description.isNotEmpty
                                    ? description
                                    : null,
                          );
                        })
                        : fallbackDishes.isNotEmpty
                        ? fallbackDishes
                            .map(
                              (d) => _popularDishCarouselTile(
                                imageB64: d.imageBase64,
                                label:
                                    d.name.trim().isNotEmpty
                                        ? d.name.trim()
                                        : 'Featured dish',
                                description:
                                    d.publicDescription.trim().isNotEmpty
                                        ? d.publicDescription.trim()
                                        : null,
                              ),
                            )
                            .toList()
                        : List.generate(
                          10,
                          (i) => _popularDishCarouselTile(
                            imageB64: null,
                            label: _popularDishLabel(w, i),
                            description: null,
                          ),
                        ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _eventDesignsSection(WebsiteContentStore w) {
    return ListenableBuilder(
      listenable: MenuStore.instance,
      builder: (context, _) {
        final cmsEventImages =
            w.eventDesignImageBase64
                .asMap()
                .entries
                .where((e) => e.value.trim().isNotEmpty)
                .toList();
        final salesEventDesigns = _salesEventDesigns;
        final useSalesDesigns =
            !widget.contentEditable && salesEventDesigns.isNotEmpty;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _homeSectionTag(w.eventDesignsSectionLabel),
            const SizedBox(height: 8),
            WebsiteRichText(
              value: w.eventDesignsSubtitle,
              style: websiteHeaderStyle(fontSize: 18),
            ),
            const SizedBox(height: 12),
            if (useSalesDesigns)
              SizedBox(
                height: 160,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children:
                      salesEventDesigns.map((row) {
                        final label =
                            (row['label'] ?? '').toString().trim();
                        final description =
                            (row['description'] ?? '').toString().trim();
                        return _HoverZoomPhotoTile(
                          imageB64: (row['imageBase64'] ?? '').toString(),
                          label:
                              label.isNotEmpty
                                  ? label
                                  : 'Featured Event Design',
                          description:
                              description.isNotEmpty ? description : null,
                          width: 200,
                          height: 160,
                          margin: const EdgeInsets.only(right: 8),
                          placeholderIcon: Icons.celebration_outlined,
                        );
                      }).toList(),
                ),
              )
            else if (widget.contentEditable && cmsEventImages.isNotEmpty)
              SizedBox(
                height: 160,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children:
                      cmsEventImages.map((entry) {
                        return _HoverZoomPhotoTile(
                          imageB64: entry.value,
                          label: 'Draft design ${entry.key + 1}',
                          width: 200,
                          height: 160,
                          margin: const EdgeInsets.only(right: 8),
                          placeholderIcon: Icons.celebration_outlined,
                        );
                      }).toList(),
                ),
              )
            else if (!widget.contentEditable)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Completed event designs will appear here once available.',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
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
                    await w.saveDraft();
                    setState(() {});
                  },
                  icon: const Icon(Icons.add_photo_alternate),
                  label: const Text('Add event design photo'),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _collageTile(
    String? b64, {
    required double width,
    required double height,
    String? fallbackAsset,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          final src = b64?.trim() ?? '';
          if (src.isNotEmpty) {
            showImageFocusDialog(
              context,
              imageBase64: src,
              title: 'Latest event',
            );
            return;
          }
          if (fallbackAsset != null) {
            showDialog<void>(
              context: context,
              builder: (ctx) => Dialog(
                backgroundColor: Colors.black,
                child: Image.asset(fallbackAsset, fit: BoxFit.contain),
              ),
            );
          }
        },
        child: SizedBox(
          width: width,
          height: height,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: _b64Image(
              b64,
              fit: BoxFit.cover,
              placeholder:
                  fallbackAsset == null
                      ? null
                      : Image.asset(
                        fallbackAsset,
                        fit: BoxFit.cover,
                        width: width,
                        height: height,
                        filterQuality: FilterQuality.medium,
                      ),
            ),
          ),
        ),
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
                              await w.saveDraft();
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
                                : 5,
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
                                                await w.saveDraft();
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
                              : 5,
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
                                                  w.saveDraft();
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
                style: CustomerFonts.poppins(
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
                  style: CustomerFonts.poppins(
                    fontSize: 18,
                    color: Colors.grey.shade800,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Try reloading the page.',
                  textAlign: TextAlign.center,
                  style: CustomerFonts.poppins(
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
                      style: CustomerFonts.poppins(
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
                style: CustomerFonts.poppins(
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
                          style: CustomerFonts.playfairDisplay(
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
                style: CustomerFonts.poppins(
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
          if (selectedType.isEmpty || selectedType == 'all') return true;
          final dishType = restaurantTypeForDish(d);
          return dishType == selectedType;
        }).toList();

    final panelH = (MediaQuery.sizeOf(context).height * 0.72).clamp(
      280.0,
      880.0,
    );
    final mobile = isMobileWidth(context);
    final tablet = isTabletWidth(context);
    final screenW = MediaQuery.sizeOf(context).width;
    // Dish cards: 4-column grid on desktop; fewer on smaller screens.
    final gridCrossAxisCount =
        mobile ? (screenW < 400 ? 1 : 2) : tablet ? 3 : 4;

    final menuPanel = ConstrainedBox(
      constraints: BoxConstraints(maxHeight: mobile ? double.infinity : panelH),
      child: SingleChildScrollView(
        padding: websitePagePadding(context, vertical: 20),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomerAntdPageHero(
                title: 'Restaurant',
                subtitle: WebsiteContentStore.instance.restaurantPageSubtitle
                        .trim()
                        .isEmpty
                    ? 'Order from our delicious restaurant menu'
                    : WebsiteContentStore.instance.restaurantPageSubtitle,
                titleFontSize: responsiveValue(
                  context,
                  mobile: 28.0,
                  desktop: 36.0,
                ),
                filters: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!_isCustomerLoggedIn) ...[
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton(
                          onPressed: _handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: CustomerAntdPageHero.accentYellow,
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
                      ),
                      const SizedBox(height: 12),
                    ],
                    _buildLoyaltyBanner(),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: 'SEARCH',
                              hintStyle: const TextStyle(color: Colors.grey),
                              prefixIcon: const Icon(
                                Icons.search,
                                color: Colors.grey,
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: const OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.all(Radius.circular(8)),
                                borderSide: BorderSide(
                                  color: CustomerAntdPageHero.accentYellow,
                                  width: 1.5,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    CustomerAntdFilterChips(
                      options: const {
                        'RICE MEALS': 'Rice Meals',
                        'SILOG MEALS': 'Silog Meals',
                        'PASTA': 'Pasta',
                        'SANDWICHES': 'Sandwiches',
                        'OTHERS': 'Others',
                        'DRINKS': 'Drinks',
                      },
                      selected: _selectedRestaurantType.trim().toUpperCase() ==
                                  'ALL' ||
                              _selectedRestaurantType.trim().isEmpty
                          ? ''
                          : _selectedRestaurantType.trim().toUpperCase(),
                      onSelected: (value) {
                        setState(() {
                          _selectedRestaurantType =
                              value.isEmpty ? 'ALL' : value;
                        });
                      },
                    ),
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
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: gridCrossAxisCount,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: mobile ? 0.78 : 0.82,
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
                                        'â‚±${d.price}',
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
              if (mobile) const SizedBox(height: 80),
            ],
          ),
        ),
    );

    if (mobile) {
      return menuPanel;
    }

    final traySidebar = Padding(
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
                      'MY TRAY',
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
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _trayDishCapsule(cartItems[index]),
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
                                'â‚±${totalAmount.toStringAsFixed(2)}',
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
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 3, child: menuPanel),
        traySidebar,
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
        body: const LazyCustomerInquireForm(staffThemeStudioMode: true),
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
            4 => const LazyCustomerInquireForm(staffThemeStudioMode: false),
            5 => LazyCustomerContactSection(
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
                        onPressed: () {
                          final args = ModalRoute.of(context)?.settings.arguments;
                          String? returnRoute = widget.returnRoute;
                          if (args is Map && args['returnRoute'] is String) {
                            returnRoute = args['returnRoute'] as String;
                          }
                          if (Navigator.of(context).canPop()) {
                            Navigator.of(context).pop();
                            return;
                          }
                          Navigator.pushReplacementNamed(
                            context,
                            returnRoute ?? _staffHomeRoute(),
                          );
                        },
                        child: const Text(
                          'â† Back to Curatering',
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
            child: Stack(
              children: [
                CustomScrollView(
                  controller: _pageScrollController,
                  slivers: [
                    SliverToBoxAdapter(child: body),
                    SliverToBoxAdapter(
                      child: CustomerSiteFooter(
                        store: w,
                        contentEditable: widget.contentEditable,
                        isCustomerLoggedIn: _isCustomerLoggedIn,
                        onLogin: _checkCustomerAuth,
                        onSaved: () {
                          if (mounted) setState(() {});
                        },
                      ),
                    ),
                  ],
                ),
                if (isMobileWidth(context) &&
                    _navIndex == 3 &&
                    !widget.contentEditable)
                  _buildMobileTrayButton(),
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
        listenable: Listenable.merge([
          CartStore.instance,
          MenuStore.instance,
        ]),
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
                                    'My Tray',
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
                                      'Add dishes from the Restaurant page â€” '
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
                                    (_, __) => const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  return _trayDishCapsule(cartItems[index]);
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
                                      'â‚±${totalAmount.toStringAsFixed(2)}',
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
    final store = LoyaltyRewardsStore.instance;
    final double minimumOrderForPoints = store.minimumOrderForPoints(
      orderType: 'restaurant',
    );
    final int pointsRatePercent = store.pointsRatePercent(
      orderType: 'restaurant',
    );
    final cartTotal = CartStore.instance.totalAmount;
    final estimatedCartPoints = store.getPointsForOrder(
      cartTotal,
      orderType: 'restaurant',
    );
    final earnCopy =
        cartTotal > 0 && estimatedCartPoints > 0
            ? 'Earn $pointsRatePercent% on orders â‰¥ â‚±${minimumOrderForPoints.toStringAsFixed(2)} (e.g. ~$estimatedCartPoints pts on your tray)'
            : 'Earn $pointsRatePercent% on orders â‰¥ â‚±${minimumOrderForPoints.toStringAsFixed(2)}';
    final int currentPoints = _restaurantLoyaltyPoints;
    final availableRewards = store.rewardsConditions;

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
                      '${_cateringLoyaltyPoints > 0 ? ' Â· Catering: $_cateringLoyaltyPoints pts' : ''}'
                      ' Â· $earnCopy',
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

class _SampleEventThemeTile extends StatelessWidget {
  const _SampleEventThemeTile({
    required this.label,
    required this.subtitle,
    required this.assetPath,
  });

  final String label;
  final String subtitle;
  final String assetPath;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      height: 160,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            assetPath,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              color: Colors.black.withValues(alpha: 0.45),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 11,
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
}

class _HomeKitchenDishCarousel extends StatefulWidget {
  const _HomeKitchenDishCarousel({required this.dishes});

  final List<MenuDish> dishes;

  @override
  State<_HomeKitchenDishCarousel> createState() =>
      _HomeKitchenDishCarouselState();
}

class _HomeKitchenDishCarouselState extends State<_HomeKitchenDishCarousel> {
  late final PageController _controller;
  Timer? _timer;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    _restartTimer();
  }

  @override
  void didUpdateWidget(covariant _HomeKitchenDishCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final lengthChanged = oldWidget.dishes.length != widget.dishes.length;
    final imagesChanged = !_sameDishImages(oldWidget.dishes, widget.dishes);
    if (lengthChanged || imagesChanged) {
      _page = 0;
      if (_controller.hasClients) {
        _controller.jumpToPage(0);
      }
      _restartTimer();
      // Force PageView children to rebuild when photos arrive after first paint.
      setState(() {});
    }
  }

  bool _sameDishImages(List<MenuDish> a, List<MenuDish> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if ((a[i].imageBase64 ?? '') != (b[i].imageBase64 ?? '')) return false;
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  void _restartTimer() {
    _timer?.cancel();
    if (widget.dishes.length <= 1) return;
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_controller.hasClients) return;
      final next = (_page + 1) % widget.dishes.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dishes = widget.dishes;
    return Column(
      children: [
        SizedBox(
          height: 148,
          child: PageView.builder(
            key: ValueKey(
              dishes
                  .map((d) => '${d.id}:${(d.imageBase64 ?? '').length}')
                  .join('|'),
            ),
            controller: _controller,
            itemCount: dishes.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, index) {
              final dish = dishes[index];
              final image = dish.imageBase64?.trim() ?? '';
              return ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    image.isNotEmpty
                        ? CachedBase64Image(
                          base64String: image,
                          fit: BoxFit.cover,
                          placeholder: Container(color: Colors.grey.shade700),
                        )
                        : Container(
                          color: Colors.grey.shade700,
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.restaurant,
                            color: Colors.white38,
                            size: 40,
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
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.75),
                            ],
                          ),
                        ),
                        child: Text(
                          dish.name.trim().isNotEmpty
                              ? dish.name.trim()
                              : 'Dish',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        if (dishes.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(dishes.length, (i) {
              final on = i == _page;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: on ? 14 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: on
                      ? const Color(0xFFFFC024)
                      : Colors.white.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}

class _HoverZoomPhotoTile extends StatelessWidget {
  const _HoverZoomPhotoTile({
    required this.imageB64,
    required this.label,
    this.description,
    required this.width,
    required this.height,
    required this.margin,
    required this.placeholderIcon,
    this.onTap,
  });

  final String? imageB64;
  final String label;
  final String? description;
  final double width;
  final double height;
  final EdgeInsets margin;
  final IconData placeholderIcon;
  final VoidCallback? onTap;

  Widget _image({BoxFit fit = BoxFit.cover}) {
    final image = imageB64;
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
        placeholderIcon,
        size: 48,
        color: Colors.grey.shade700,
      ),
    );
  }

  void _openFocus(BuildContext context) {
    if (onTap != null) {
      onTap!();
      return;
    }
    if (imageB64 == null || imageB64!.isEmpty) return;
    showImageFocusDialog(
      context,
      imageBase64: imageB64,
      title: label.trim().isNotEmpty ? label : 'Photo',
      description: description,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => _openFocus(context),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: width,
              height: height,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _image(),
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
                        label.trim().isNotEmpty ? label : 'Photo',
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
    );
  }
}

class _RedBannerMarquee extends StatefulWidget {
  const _RedBannerMarquee({required this.text, required this.style});

  final String text;
  final TextStyle style;

  @override
  State<_RedBannerMarquee> createState() => _RedBannerMarqueeState();
}

class _RedBannerMarqueeState extends State<_RedBannerMarquee>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 28),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final plain = widget.text.replaceAll(RegExp(r'<[^>]*>'), ' ').trim();
    final label = plain.isEmpty ? 'WE CATER' : plain;
    final unit = '$label    â€¢    ';
    // Approximate unit width so we can loop seamlessly without a measure pass.
    final unitWidth =
        (unit.length * (widget.style.fontSize ?? 14) * 0.62).clamp(160.0, 900.0);

    return SizedBox(
      height: 36,
      width: double.infinity,
      child: ClipRect(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final dx = -unitWidth * _controller.value;
            return OverflowBox(
              maxWidth: double.infinity,
              alignment: Alignment.centerLeft,
              child: Transform.translate(
                offset: Offset(dx, 0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(16, (_) {
                    return Text(
                      unit,
                      maxLines: 1,
                      softWrap: false,
                      style: widget.style,
                    );
                  }),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

