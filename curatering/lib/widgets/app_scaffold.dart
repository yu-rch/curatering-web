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
    _SidebarItemData(icon: Icons.menu_book, label: 'Menu', route: '/menu'),
    _SidebarItemData(
      icon: Icons.bar_chart,
      label: 'Reports',
      route: '/reports',
    ),
    _SidebarItemData(
      icon: Icons.swap_horiz,
      label: 'Transactions',
      route: '/transactions',
    ),
    // _SidebarItemData(icon: Icons.archive, label: 'Archive', route: '/archive'),
    _SidebarItemData(icon: Icons.public, label: 'Website', route: '/website'),
  ];

  static const _superAdminSidebarItems = <_SidebarItemData>[
    _SidebarItemData(
      icon: Icons.people_alt,
      label: 'Manage Accounts',
      route: '/manage-accounts',
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

    return InkWell(
      onTap: () {
        if (currentRoute != route) {
          Navigator.of(context).pushReplacementNamed(route);
        }
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFFFC024) : Colors.transparent,
          // borderRadius: BorderRadius.circular(6),
        ),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        child: Row(
          children: [
            Icon(
              icon,
              color: isActive ? const Color(0xFF242424) : const Color(0xFFF5F7F9),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isActive ? const Color(0xFF242424) : const Color(0xFFF5F7F9),
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppTitle() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          label: 'CURATERING',
          child: Image.asset('lib/assets/main.png', height: 32, fit: BoxFit.contain),
        ),
        const SizedBox(width: 12),
      ],
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
      ..._commonSidebarItems.where((item) => pageRouteAllowed(item.route, perms)),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F3),
      body: Column(
        children: [
          // top bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            color: const Color(0xFF111111),
            child: Row(
              children: [
                _buildAppTitle(),
                const SizedBox(width: 32),
                if (showSearch)
                  Expanded(
                    child: TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        prefixIcon: const Icon(Icons.search),
                        hintText: 'Search',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 0,
                          horizontal: 12,
                        ),
                      ),
                      onChanged: onSearchChanged,
                    ),
                  ),
                if (showSearch) const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.tune, size: 18, color: Colors.black87),
                      SizedBox(width: 8),
                      Text('Filter', style: TextStyle(color: Colors.black87)),
                    ],
                  ),
                ),
                const Spacer(),
                Image.asset(
                  'lib/assets/main-2.png',
                  height: 28,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 18),
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.white,
                  backgroundImage: const AssetImage(
                    'lib/assets/profileicon 1.png',
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  userName,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
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
                    width: 220,
                    color: const Color(0xFF0F0F0F),
                    padding: const EdgeInsets.symmetric(
                      vertical: 22,
                      horizontal: 16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 10),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              children: [
                                ...sidebarItems.map((item) {
                                  return _buildSidebarItem(
                                    context,
                                    item.icon,
                                    item.label,
                                    item.route,
                                  );
                                }),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (role == Role.superAdmin ||
                            pageRouteAllowed(PagePermissionRoutes.settings, perms))
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
                      children: [
                        sidebar,
                        Expanded(child: mainContent),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      sidebar,
                      Expanded(child: mainContent),
                    ],
                  );
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
