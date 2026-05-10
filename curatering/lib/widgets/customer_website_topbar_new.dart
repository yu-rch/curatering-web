import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
          Expanded(
            child: Wrap(
              spacing: 2,
              runSpacing: 4,
              alignment: WrapAlignment.center,
              children: [
                _NavLink(
                  label: 'Home',
                  onTap: () => _navigateTo(context, '/'),
                ),
                _NavLink(
                  label: 'Gallery',
                  onTap: () => _navigateTo(context, '/gallery'),
                ),
                _NavLink(
                  label: 'Catering Menu',
                  onTap: () => _navigateTo(context, '/catering-menu'),
                ),
                _NavLink(
                  label: 'Restaurant',
                  onTap: () => _navigateTo(context, '/restaurant'),
                ),
                _NavLink(
                  label: 'Inquire Now',
                  onTap: () => _navigateTo(context, '/inquire'),
                ),
                _NavLink(
                  label: 'Contact Us',
                  onTap: () => _navigateTo(context, '/contact-us'),
                ),
              ],
            ),
          ),
          if (showCart) ...[
            // Cart Icon
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.shopping_cart, color: Colors.white),
                  onPressed: () => _openCart(context),
                ),
                if (CartStore.instance.itemCount > 0)
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
            // Login/Logout Button
            if (AuthSession.instance.isLoggedIn.value)
              PopupMenuButton<String>(
                onSelected: (value) async {
                  switch (value) {
                    case 'my_profile':
                      await Navigator.pushNamed(context, '/my-profile');
                      break;
                    case 'my_orders':
                      await Navigator.pushNamed(context, '/my-orders');
                      break;
                    case 'my_caterings':
                      await Navigator.pushNamed(context, '/my-caterings');
                      break;
                    case 'order_tracking':
                      await Navigator.pushNamed(context, '/order-tracking');
                      break;
                    case 'logout':
                      AuthSession.instance.clear();
                      break;
                  }
                },
                child: Row(
                  children: [
                    Icon(Icons.person, color: Colors.amber.shade400, size: 20),
                    const SizedBox(width: 4),
                    Text(
                      AuthSession.instance.currentUser.value?.fullName ?? 'Customer',
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                    const Icon(Icons.arrow_drop_down, color: Colors.white),
                  ],
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
                        Text('Logout', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              )
            else
              TextButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/customer-login'),
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

  void _navigateTo(BuildContext context, String route) {
    if (ModalRoute.of(context)?.settings.name != route) {
      Navigator.pushNamed(context, route);
    }
  }

  void _openCart(BuildContext context) {
    // Show cart sidebar instantly for improved UX
    Scaffold.of(context).openEndDrawer();
  }
}

class _NavLink extends StatelessWidget {
  const _NavLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final currentRoute = ModalRoute.of(context)?.settings.name;
    final isActive = _isCurrentRoute(currentRoute, label);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFFFFC024) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isActive
                ? null
                : Border.all(
                    color: const Color(0xFFFFC024).withOpacity(0.6),
                  ),
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              color: isActive ? const Color(0xFF1E1E1E) : const Color(0xFFFFC024),
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  bool _isCurrentRoute(String? currentRoute, String label) {
    final routeMap = {
      'Home': '/',
      'Gallery': '/gallery',
      'Catering': '/',
      'Restaurant': '/restaurant',
      'Inquire': '/inquire',
      'Contact': '/contact-us',
    };
    return routeMap[label] == currentRoute;
  }
}
