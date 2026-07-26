import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/site_open_tab_stub.dart'
    if (dart.library.html) '../config/site_open_tab_web.dart';
import '../config/site_routes.dart';
import '../constants/catering_meal_types.dart';
import '../pages/checkout_page.dart';
import '../pages/customer_login.dart';
import '../pages/my_caterings_page.dart';
import '../pages/my_order_tracking_page.dart';
import '../pages/my_orders_page.dart';
import '../pages/my_profile_page.dart';
import '../services/cart_store.dart';
import '../services/menu_store.dart';
import '../utils/image_cache.dart';
import 'antd_message.dart';
import 'antd_profile_menu.dart';

/// Public site header matching the homepage (`CustomerWebsiteScreen`) styling:
/// dark bar, centered wrap nav, red cart badge, customer login from SharedPreferences.
class CustomerWebsiteTopBar extends StatefulWidget {
  const CustomerWebsiteTopBar({super.key, this.showCartAndCustomerAuth = true});

  /// When false (e.g. staff preview with content editing), cart and login strip are hidden.
  final bool showCartAndCustomerAuth;

  @override
  State<CustomerWebsiteTopBar> createState() => _CustomerWebsiteTopBarState();
}

class _CustomerWebsiteTopBarState extends State<CustomerWebsiteTopBar> {
  bool _isCustomerLoggedIn = false;
  Map<String, dynamic>? _customerData;

  @override
  void initState() {
    super.initState();
    CartStore.instance.addListener(_onCartChanged);
    MenuStore.instance.addListener(_onCartChanged);
    _refreshCustomerAuth();
  }

  @override
  void dispose() {
    CartStore.instance.removeListener(_onCartChanged);
    MenuStore.instance.removeListener(_onCartChanged);
    super.dispose();
  }

  void _onCartChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _refreshCustomerAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('customer_token');
    final raw = prefs.getString('customer_data');
    Map<String, dynamic>? data;
    if (raw != null) {
      try {
        data = jsonDecode(raw) as Map<String, dynamic>?;
      } catch (_) {
        data = null;
      }
    }
    if (!mounted) return;
    setState(() {
      _isCustomerLoggedIn = token != null && token.isNotEmpty;
      _customerData = data;
    });
  }

  Future<void> _handleLogin() async {
    await showDialog<void>(
      context: context,
      builder: (context) => const CustomerLoginPage(),
    );
    await _refreshCustomerAuth();
  }

  Future<void> _handleLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('customer_token');
    await prefs.remove('customer_data');
    if (!mounted) return;
    setState(() {
      _isCustomerLoggedIn = false;
      _customerData = null;
    });
    showAntdMessage(context, 'Logged out successfully');
  }

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

  Widget _trayDishCapsule(CartItem item) {
    final unitPrice = double.tryParse(item.dish.price) ?? 0;
    final mealRaw = item.dish.effectiveMealType.trim();
    final mealLabel = mealRaw.isEmpty ? 'Item' : mealTypeDisplayLabel(mealRaw);
    final imageB64 = _trayDishImageBase64(item);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
                        item.dish.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$mealLabel ×${item.quantity} @ ₱${unitPrice.toStringAsFixed(2)} · ₱${item.lineSubtotal.toStringAsFixed(2)}',
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
                    ),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.remove_circle_outline, size: 22),
                  onPressed: () {
                    CartStore.instance.updateCartItemQuantity(
                      item,
                      item.quantity - 1,
                    );
                  },
                ),
                Text(
                  '${item.quantity}',
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
                      item,
                      item.quantity + 1,
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

  void _openCart() {
    MenuStore.instance.ensureImagesLoaded();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.55,
            minChildSize: 0.35,
            maxChildSize: 0.92,
            builder: (context, scrollController) {
              return AnimatedBuilder(
                animation: Listenable.merge([
                  CartStore.instance,
                  MenuStore.instance,
                ]),
                builder: (context, _) {
                  final cartItems = CartStore.instance.items;
                  final totalAmount = CartStore.instance.totalAmount;
                  return Column(
                    children: [
                      const SizedBox(height: 8),
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
                        child: Row(
                          children: [
                            const Icon(Icons.shopping_bag_outlined),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'My Tray',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child:
                            cartItems.isEmpty
                                ? Center(
                                  child: Text(
                                    'Your tray is empty',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                )
                                : ListView.builder(
                                  controller: scrollController,
                                  padding: const EdgeInsets.all(12),
                                  itemCount: cartItems.length,
                                  itemBuilder: (context, index) {
                                    return _trayDishCapsule(cartItems[index]);
                                  },
                                ),
                      ),
                      if (cartItems.isNotEmpty)
                        SafeArea(
                          top: false,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Total',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      '₱${totalAmount.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                      Navigator.of(this.context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) => const CheckoutPage(),
                                        ),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF1E1E1E),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                    ),
                                    child: const Text('Proceed to checkout'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  String _currentRoute(BuildContext context) {
    return ModalRoute.of(context)?.settings.name ?? '/';
  }

  Widget _navLabel(String label, {required bool active}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              color: active ? Colors.white : Colors.white70,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          if (active)
            Container(height: 2, width: 32, color: const Color(0xFFFFC024)),
        ],
      ),
    );
  }

  void _goHome(BuildContext context) {
    Navigator.pushNamedAndRemoveUntil(
      context,
      customerRoute('/'),
      (route) => false,
    );
  }

  void _go(BuildContext context, String route, {bool newTab = false}) {
    final target = customerRoute(route);
    if (newTab && kIsWeb) {
      openAppRouteInNewTab(customerSiteOrigin, route);
      return;
    }
    if (_currentRoute(context) != target) {
      Navigator.pushReplacementNamed(context, target);
    }
  }

  Widget _navLink(
    BuildContext context, {
    required String label,
    required String route,
    required bool active,
  }) {
    return GestureDetector(
      onSecondaryTap: kIsWeb ? () => _go(context, route, newTab: true) : null,
      onTap: () => _go(context, route),
      child: Listener(
        onPointerDown: (e) {
          if (kIsWeb && e.buttons == 4) {
            _go(context, route, newTab: true);
          }
        },
        child: _navLabel(label, active: active),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final route = _currentRoute(context);

    return Material(
      color: const Color(0xFF1E1E1E),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              InkWell(
                onTap: () => _goHome(context),
                child: Image.asset(
                  'lib/assets/main-2.png',
                  height: 34,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Wrap(
                  spacing: 2,
                  runSpacing: 4,
                  alignment: WrapAlignment.center,
                  children: [
                    _navLink(
                      context,
                      label: 'Home',
                      route: '/',
                      active: route == customerRoute('/'),
                    ),
                    _navLink(
                      context,
                      label: 'Gallery',
                      route: '/gallery',
                      active: route == customerRoute('/gallery'),
                    ),
                    _navLink(
                      context,
                      label: 'Catering Menu',
                      route: '/catering-menu',
                      active: route == customerRoute('/catering-menu'),
                    ),
                    _navLink(
                      context,
                      label: 'Restaurant',
                      route: '/restaurant',
                      active: route == customerRoute('/restaurant'),
                    ),
                    _navLink(
                      context,
                      label: 'Inquire Now',
                      route: '/inquire',
                      active: route == customerRoute('/inquire'),
                    ),
                    _navLink(
                      context,
                      label: 'Contact Us',
                      route: '/contact-us',
                      active: route == customerRoute('/contact-us'),
                    ),
                  ],
                ),
              ),
              if (widget.showCartAndCustomerAuth) ...[
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.shopping_bag_outlined,
                        color: Colors.white,
                      ),
                      onPressed: _openCart,
                      tooltip: 'View tray',
                    ),
                    if (CartStore.instance.itemCount > 0)
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
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          child: Text(
                            '${CartStore.instance.itemCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
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
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const MyProfilePage(),
                            ),
                          );
                        },
                      ),
                      AntdProfileMenuItem.action(
                        id: 'my_orders',
                        icon: Icons.receipt_long,
                        label: 'My Orders',
                        onSelected: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const MyOrdersPage(),
                            ),
                          );
                        },
                      ),
                      AntdProfileMenuItem.action(
                        id: 'my_caterings',
                        icon: Icons.event,
                        label: 'My Caterings',
                        onSelected: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const MyCateringsPage(),
                            ),
                          );
                        },
                      ),
                      AntdProfileMenuItem.action(
                        id: 'order_tracking',
                        icon: Icons.local_shipping_outlined,
                        label: 'Order Tracking',
                        onSelected: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const MyOrderTrackingPage(),
                            ),
                          );
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
                    icon: const Icon(
                      Icons.login,
                      color: Colors.white,
                      size: 18,
                    ),
                    label: const Text(
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
}
