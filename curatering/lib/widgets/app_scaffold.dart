import 'package:flutter/material.dart';

import '../auth/auth_session.dart';
import '../auth/page_permissions.dart';
import '../auth/roles.dart';

class AppScaffold extends StatelessWidget {
  final Widget child;
  final TextEditingController? searchController;
  final bool showSearch;
  final ValueChanged<String>? onSearchChanged;

  const AppScaffold({
    super.key,
    required this.child,
    this.searchController,
    this.showSearch = false,
    this.onSearchChanged,
  });

  static const _commonSidebarItems = <_SidebarItemData>[
    _SidebarItemData(
      icon: Icons.dashboard,
      label: 'Liveboards',
      route: '/dashboard',
    ),
    _SidebarItemData(
      icon: Icons.event,
      label: 'Manage Events',
      route: '/manage-events',
    ),
    _SidebarItemData(
      icon: Icons.loyalty,
      label: 'Loyalty Rewards',
      route: '/loyalty',
    ),
    _SidebarItemData(
      icon: Icons.menu_book,
      label: 'Catering/Restaurant Menu',
      route: '/catering-restaurant-menu',
    ),
    _SidebarItemData(
      icon: Icons.inventory,
      label: 'Inventory',
      route: '/inventory',
    ),
    _SidebarItemData(
      icon: Icons.receipt_long,
      label: 'Restaurant Orders',
      route: '/restaurant-orders',
    ),
    _SidebarItemData(
      icon: Icons.bar_chart,
      label: 'Reports',
      route: '/reports',
    ),
    _SidebarItemData(
      icon: Icons.swap_horiz,
      label: 'Order History',
      route: '/order-history',
    ),
    _SidebarItemData(icon: Icons.archive, label: 'Archive', route: '/archive'),
    _SidebarItemData(icon: Icons.public, label: 'Website', route: '/website'),
  ];

  static const _superAdminSidebarItems = <_SidebarItemData>[
    _SidebarItemData(
      icon: Icons.people_alt,
      label: 'Manage Accounts',
      route: '/manage-accounts',
    ),
    _SidebarItemData(
      icon: Icons.person_outline,
      label: 'Customer Management',
      route: '/customer-management',
    ),
    _SidebarItemData(
      icon: Icons.help_outline,
      label: 'Help Requests',
      route: '/help-requests',
    ),
    _SidebarItemData(
      icon: Icons.history,
      label: 'Action Logs',
      route: '/action-logs',
    ),
  ];

  static Widget _buildSidebarItem(
    BuildContext context,
    IconData icon,
    String label,
    String route,
  ) {
    final currentRoute = ModalRoute.of(context)?.settings.name;
    final isActive = currentRoute == route;

    return GestureDetector(
      onTap: () {
        if (currentRoute != route) {
          Navigator.of(context).pushReplacementNamed(route);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        child: Row(
          children: [
            Icon(
              icon,
              color:
                  isActive ? const Color(0xFF242424) : const Color(0xFFF5F7F9),
              size: 18,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color:
                      isActive
                          ? const Color(0xFF242424)
                          : const Color(0xFFF5F7F9),
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthSession.instance.currentUser.value;
    final userName = user?.fullName ?? 'Guest';
    final role = user?.role;

    final perms = user?.pagePermissions;
    final sidebarItems = <_SidebarItemData>[
      if (role == Role.superAdmin) ..._superAdminSidebarItems,
      ..._commonSidebarItems.where(
        (item) => pageRouteAllowed(item.route, perms),
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F3),
      body: Column(
        children: [
          // top bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF111111),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // App title with enhanced styling
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFC024).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFFFC024).withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 24,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFC024),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Curatering',
                        style: TextStyle(
                          color: const Color(0xFFFFC024),
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                if (showSearch)
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: searchController,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white,
                          prefixIcon: Container(
                            padding: const EdgeInsets.all(12),
                            child: Icon(
                              Icons.search,
                              color: Colors.grey.shade600,
                              size: 20,
                            ),
                          ),
                          hintText: 'Search...',
                          hintStyle: TextStyle(color: Colors.grey.shade500),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 16,
                          ),
                        ),
                        onChanged: onSearchChanged,
                      ),
                    ),
                  ),
                if (showSearch) const SizedBox(width: 16),
                // Enhanced filter button
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.tune,
                        size: 18,
                        color: const Color(0xFF242424),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Filter',
                        style: TextStyle(
                          color: const Color(0xFF242424),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Enhanced logo
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'lib/assets/main-2.png',
                    height: 32,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(width: 16),
                // Enhanced profile section
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: const Color(
                          0xFFFFC024,
                        ).withOpacity(0.1),
                        backgroundImage: const AssetImage(
                          'lib/assets/profileicon 1.png',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            userName,
                            style: TextStyle(
                              color: const Color(0xFF111111),
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            AuthSession.instance.currentRole?.displayName ??
                                'Staff',
                            style: TextStyle(
                              color: const Color(0xFF242424),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
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
          // content area
          Expanded(
            child: SafeArea(
              top: false,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 960;

                  Widget sidebar = Container(
                    width: 240,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F0F0F),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 12,
                          offset: const Offset(2, 0),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 16),
                        // Menu items
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Column(
                              children: [
                                const SizedBox(height: 8),
                                ...sidebarItems.map(
                                  (item) => _buildSidebarItem(
                                    context,
                                    item.icon,
                                    item.label,
                                    item.route,
                                  ),
                                ),
                                const SizedBox(height: 20),
                              ],
                            ),
                          ),
                        ),
                        if (role == Role.superAdmin ||
                            pageRouteAllowed(
                              PagePermissionRoutes.settings,
                              perms,
                            ))
                          _buildSidebarItem(
                            context,
                            Icons.settings,
                            'Settings',
                            '/settings',
                          ),
                      ],
                    ),
                  );

                  Widget mainContent = child;

                  if (isNarrow) {
                    return Column(
                      children: [sidebar, Expanded(child: mainContent)],
                    );
                  }

                  return Row(children: [sidebar, Expanded(child: mainContent)]);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarItemData {
  final IconData icon;
  final String label;
  final String route;

  const _SidebarItemData({
    required this.icon,
    required this.label,
    required this.route,
  });
}
