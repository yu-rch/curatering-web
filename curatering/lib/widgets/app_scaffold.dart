import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../auth/auth_session.dart';
import '../auth/page_permissions.dart';
import '../auth/roles.dart';
import '../config/site_open_tab_stub.dart'
    if (dart.library.html) '../config/site_open_tab_web.dart';
import '../config/site_routes.dart';
import 'antd_profile_menu.dart';
import 'antd_staff.dart';
import 'antd_tokens.dart';

Future<void> _staffSignOut(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Log out?'),
      content: const Text('Are you sure you want to log out?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Log out'),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  AuthSession.instance.clear();
  if (context.mounted) {
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }
}

class AppScaffold extends StatelessWidget {
  final Widget child;
  final TextEditingController? searchController;
  final bool showSearch;
  final String searchHint;
  final ValueChanged<String>? onSearchChanged;

  const AppScaffold({
    super.key,
    required this.child,
    this.searchController,
    this.showSearch = false,
    this.searchHint = 'Search staff pages',
    this.onSearchChanged,
  });

  static const _commonSidebarItems = <_SidebarItemData>[
    _SidebarItemData(
      icon: Icons.dashboard,
      label: 'Dashboard',
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
  ];

  static const _superAdminSidebarItems = <_SidebarItemData>[
    _SidebarItemData(
      icon: Icons.dashboard,
      label: 'Dashboard',
      route: '/dashboard',
    ),
    _SidebarItemData(
      icon: Icons.help_outline,
      label: 'Help Requests Management',
      route: '/help-requests',
    ),
    _SidebarItemData(
      icon: Icons.reviews_outlined,
      label: 'Customer Feedback',
      route: '/customer-feedback',
    ),
    _SidebarItemData(
      icon: Icons.web_asset,
      label: 'Website CMS',
      route: '/website-admin',
    ),
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
      icon: Icons.history,
      label: 'Action Logs',
      route: '/action-logs',
    ),
  ];

  static void _openRoute(
    BuildContext context,
    String route, {
    bool newTab = false,
  }) {
    if (newTab && kIsWeb) {
      openAppRouteInNewTab(staffSiteOrigin, route);
      return;
    }
    final currentRoute = ModalRoute.of(context)?.settings.name;
    if (currentRoute != route) {
      Navigator.of(context).pushReplacementNamed(route);
    }
  }

  static Widget _buildSidebarItem(
    BuildContext context,
    IconData icon,
    String label,
    String route,
  ) {
    final currentRoute = ModalRoute.of(context)?.settings.name;
    final isActive = currentRoute == route;

    return GestureDetector(
      onSecondaryTap:
          kIsWeb ? () => _openRoute(context, route, newTab: true) : null,
      onTap: () => _openRoute(context, route),
      child: Listener(
        onPointerDown: (e) {
          if (kIsWeb && e.buttons == 4) {
            _openRoute(context, route, newTab: true);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFFFFC024) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color:
                    isActive
                        ? const Color(0xFF1E1E1E)
                        : const Color(0xFFF5F7F9),
                size: 18,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color:
                        isActive
                            ? const Color(0xFF1E1E1E)
                            : const Color(0xFFF5F7F9),
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static List<_SidebarItemData> _sidebarItemsForRole(
    Role? role,
    Map<String, dynamic>? perms,
  ) {
    if (role == Role.cashier) {
      return const [
        _SidebarItemData(
          icon: Icons.point_of_sale,
          label: 'POS',
          route: '/restaurant-orders',
        ),
      ];
    }
    if (role == Role.supervisor) {
      return const [
        _SidebarItemData(
          icon: Icons.event,
          label: 'Manage Events',
          route: '/manage-events',
        ),
      ];
    }
    if (role == Role.superAdmin) {
      return [
        ..._superAdminSidebarItems,
        ..._commonSidebarItems.where(
          (item) =>
              item.route != '/help-requests' && item.route != '/dashboard',
        ),
      ];
    }
    return _commonSidebarItems
        .where((item) => pageRouteAllowed(item.route, perms))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UserProfile?>(
      valueListenable: AuthSession.instance.currentUser,
      builder: (context, user, _) {
        return Theme(
          data: Theme.of(context).copyWith(
            scaffoldBackgroundColor: AntdTokens.staffBg,
            cardTheme: CardThemeData(
              color: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AntdTokens.radiusLg),
                side: const BorderSide(color: AntdTokens.borderSubtle),
              ),
            ),
            dialogTheme: DialogThemeData(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AntdTokens.radiusLg),
              ),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: AntdTokens.brandPrimary,
                foregroundColor: AntdTokens.brandOnPrimary,
                disabledBackgroundColor: AntdTokens.brandPrimary.withValues(
                  alpha: 0.45,
                ),
                disabledForegroundColor: AntdTokens.brandOnPrimary.withValues(
                  alpha: 0.55,
                ),
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AntdTokens.radiusSm),
                ),
              ),
            ),
            filledButtonTheme: FilledButtonThemeData(
              style: FilledButton.styleFrom(
                backgroundColor: AntdTokens.brandPrimary,
                foregroundColor: AntdTokens.brandOnPrimary,
                disabledBackgroundColor: AntdTokens.brandPrimary.withValues(
                  alpha: 0.45,
                ),
                disabledForegroundColor: AntdTokens.brandOnPrimary.withValues(
                  alpha: 0.55,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AntdTokens.radiusSm),
                ),
              ),
            ),
            outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(
                foregroundColor: AntdTokens.valueDark,
                side: const BorderSide(color: AntdTokens.border),
                backgroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AntdTokens.radiusSm),
                ),
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: AntdTokens.blue,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AntdTokens.radiusSm),
                ),
              ),
            ),
            iconButtonTheme: IconButtonThemeData(
              style: IconButton.styleFrom(
                foregroundColor: AntdTokens.valueDark,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AntdTokens.radiusSm),
                ),
              ),
            ),
            chipTheme: ChipThemeData(
              backgroundColor: Colors.white,
              selectedColor: AntdTokens.brandPrimary,
              disabledColor: AntdTokens.fillTertiary,
              side: const BorderSide(color: AntdTokens.border),
              labelStyle: const TextStyle(color: AntdTokens.valueDark),
              secondaryLabelStyle: const TextStyle(
                color: AntdTokens.brandOnPrimary,
                fontWeight: FontWeight.w600,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            tabBarTheme: const TabBarThemeData(
              labelColor: AntdTokens.brandOnPrimary,
              unselectedLabelColor: AntdTokens.textSecondary,
              indicatorColor: AntdTokens.brandPrimary,
              dividerColor: AntdTokens.borderSubtle,
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AntdTokens.radiusSm),
                borderSide: const BorderSide(color: AntdTokens.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AntdTokens.radiusSm),
                borderSide: const BorderSide(color: AntdTokens.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AntdTokens.radiusSm),
                borderSide: const BorderSide(color: AntdTokens.blue),
              ),
            ),
          ),
          child: _buildScaffold(context, user),
        );
      },
    );
  }

  Widget _buildScaffold(BuildContext context, UserProfile? user) {
    final userName = user?.fullName ?? 'Guest';
    final role = user?.role;

    final perms = user?.pagePermissions;
    final sidebarItems = _sidebarItemsForRole(role, perms);

    final profileItems = <AntdProfileMenuItem>[
      AntdProfileMenuItem.header(userName),
      if (role == Role.superAdmin ||
          pageRouteAllowed(PagePermissionRoutes.settings, perms))
        AntdProfileMenuItem.action(
          id: 'settings',
          icon: Icons.settings_outlined,
          label: 'Settings',
          onSelected: () {
            Navigator.of(context).pushReplacementNamed('/settings');
          },
        ),
      if (role == Role.superAdmin)
        AntdProfileMenuItem.action(
          id: 'help_requests',
          icon: Icons.help_outline,
          label: 'Help Requests Management',
          onSelected: () {
            Navigator.of(context).pushReplacementNamed('/help-requests');
          },
        ),
      AntdProfileMenuItem.action(
        id: 'logout',
        icon: Icons.logout,
        label: 'Logout',
        destructive: true,
        dividerBefore: true,
        onSelected: () => _staffSignOut(context),
      ),
    ];

    return Scaffold(
      backgroundColor: AntdTokens.staffBg,
      body: Column(
        children: [
          // top bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF111111),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Left logo
                Image.asset(
                  'lib/assets/main.png',
                  height: 32,
                  fit: BoxFit.contain,
                ),
                const Spacer(),
                if (showSearch && searchController != null) ...[
                  AntdSearchInput(
                    controller: searchController!,
                    hintText: searchHint,
                    width: 320,
                    onChanged: onSearchChanged,
                    onClear: () {
                      searchController!.clear();
                      onSearchChanged?.call('');
                    },
                  ),
                  const SizedBox(width: 12),
                ],
                AntdProfileMenu(
                  triggerLabel: userName,
                  leading: Image.asset(
                    'lib/assets/main-2.png',
                    height: 22,
                    fit: BoxFit.contain,
                  ),
                  items: profileItems,
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
                          color: Colors.black.withValues(alpha: 0.1),
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
