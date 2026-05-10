import 'package:flutter/material.dart';

import '../services/cart_store.dart';
import '../auth/auth_session.dart';

/// Responsive topbar for customer website pages
/// Provides consistent navigation across Gallery, Inquire, Contact Us, and Restaurant pages
class CustomerWebsiteTopBar extends StatelessWidget
    implements PreferredSizeWidget {
  const CustomerWebsiteTopBar({
    super.key,
    this.title,
    this.showBackButton = false,
    this.onBack,
    this.showCart = true,
  });

  final String? title;
  final bool showBackButton;
  final VoidCallback? onBack;
  final bool showCart;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1E1E1E),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          // Logo
          InkWell(
            onTap:
                () => Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/',
                  (route) => false,
                ),
            child: Image.asset(
              'lib/assets/main-2.png',
              height: 25,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 16),

          // Navigation Links
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 800) {
                  // Mobile layout
                  return _buildMobileNav(context);
                } else {
                  // Desktop layout
                  return _buildDesktopNav(context);
                }
              },
            ),
          ),

          const SizedBox(width: 16),

          // Cart and Login/Profile
          Row(
            children: [
              // Cart Icon
              if (showCart) ...[
                AnimatedBuilder(
                  animation: CartStore.instance,
                  builder: (context, child) {
                    final cartStore = CartStore.instance;
                    final cartItemCount = cartStore.items.fold<int>(
                      0,
                      (sum, item) => sum + item.quantity,
                    );

                    return Stack(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.shopping_cart,
                            color: Colors.white,
                          ),
                          onPressed: () => _openCart(context),
                          tooltip: 'View cart',
                        ),
                        if (cartItemCount > 0)
                          Positioned(
                            right: 8,
                            top: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFC024),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '$cartItemCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],

              // Login/Profile Button
              if (AuthSession.instance.isLoggedIn.value)
                PopupMenuButton<String>(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: CircleAvatar(
                      backgroundColor: Colors.grey.shade300,
                      child: Icon(Icons.person, color: Colors.white, size: 20),
                    ),
                  ),
                  child: Text(
                    AuthSession.instance.currentUser.value?.fullName ??
                        'Customer',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                  itemBuilder:
                      (context) => [
                        const PopupMenuItem(
                          value: 'my_profile',
                          child: Row(
                            children: [
                              Icon(Icons.person, size: 18),
                              SizedBox(width: 8),
                              Text('My Profile'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'my_orders',
                          child: Row(
                            children: [
                              Icon(Icons.receipt_long, size: 18),
                              SizedBox(width: 8),
                              Text('My Orders'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'my_caterings',
                          child: Row(
                            children: [
                              Icon(Icons.event, size: 18),
                              SizedBox(width: 8),
                              Text('My Caterings'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'order_tracking',
                          child: Row(
                            children: [
                              Icon(Icons.local_shipping, size: 18),
                              SizedBox(width: 8),
                              Text('Order Tracking'),
                            ],
                          ),
                        ),
                        const PopupMenuDivider(),
                        const PopupMenuItem(
                          value: 'logout',
                          child: Row(
                            children: [
                              Icon(Icons.logout, size: 18, color: Colors.red),
                              SizedBox(width: 8),
                              Text(
                                'Logout',
                                style: TextStyle(color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                      ],
                  onSelected: (value) {
                    switch (value) {
                      case 'my_profile':
                        Navigator.pushNamed(context, '/customer-profile');
                        break;
                      case 'my_orders':
                        Navigator.pushNamed(context, '/customer-orders');
                        break;
                      case 'my_caterings':
                        Navigator.pushNamed(context, '/customer-caterings');
                        break;
                      case 'order_tracking':
                        Navigator.pushNamed(context, '/order-tracking');
                        break;
                      case 'logout':
                        AuthSession.instance.clear();
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          '/customer-login',
                          (route) => false,
                        );
                        break;
                    }
                  },
                )
              else
                TextButton.icon(
                  onPressed:
                      () => Navigator.pushNamed(context, '/customer-login'),
                  icon: const Icon(Icons.login, color: Colors.white, size: 18),
                  label: const Text(
                    'Login',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMobileNav(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildNavLink('Home', '/', context),
        _buildNavLink('Gallery', '/gallery', context),
        _buildNavLink('Catering Menu', '/catering-menu', context),
        _buildNavLink('Restaurant', '/restaurant', context),
        _buildNavLink('Inquire Now', '/inquire', context),
        _buildNavLink('Contact Us', '/contact-us', context),
      ],
    );
  }

  Widget _buildDesktopNav(BuildContext context) {
    return Row(
      children: [
        _buildNavLink('Home', '/', context),
        _buildNavLink('Gallery', '/gallery', context),
        _buildNavLink('Catering Menu', '/catering-menu', context),
        _buildNavLink('Restaurant', '/restaurant', context),
        _buildNavLink('Inquire Now', '/inquire', context),
        _buildNavLink('Contact Us', '/contact-us', context),
      ],
    );
  }

  Widget _buildNavLink(String label, String route, BuildContext context) {
    final currentRoute = ModalRoute.of(context)?.settings.name ?? '/';
    final isActive = _isRouteActive(currentRoute, label);

    return InkWell(
      onTap: () => _navigateTo(context, route),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? const Color(0xFFFFC024) : Colors.white,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  void _navigateTo(BuildContext context, String route) {
    if (ModalRoute.of(context)?.settings.name != route) {
      Navigator.pushNamed(context, route);
    }
  }

  void _openCart(BuildContext context) {
    // Show cart drawer for instant access
    Scaffold.of(context).openEndDrawer();
  }

  bool _isRouteActive(String currentRoute, String label) {
    final routeMap = {
      'Home': '/',
      'Gallery': '/gallery',
      'Catering Menu': '/catering-menu',
      'Restaurant': '/restaurant',
      'Inquire Now': '/inquire',
      'Contact Us': '/contact-us',
    };
    return routeMap[label] == currentRoute;
  }
}
