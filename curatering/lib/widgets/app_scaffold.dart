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

void _staffSignOut(BuildContext context) {
  AuthSession.instance.clear();
  Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
}

class AppScaffold extends StatefulWidget {
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
    VoidCallback? beforeNavigate,
  }) {
    beforeNavigate?.call();
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
    String route, {
    VoidCallback? beforeNavigate,
  }) {
    final currentRoute = ModalRoute.of(context)?.settings.name;
    final isActive = currentRoute == route;

    return GestureDetector(
      onSecondaryTap:
          kIsWeb
              ? () => _openRoute(
                context,
                route,
                newTab: true,
                beforeNavigate: beforeNavigate,
              )
              : null,
      onTap:
          () => _openRoute(context, route, beforeNavigate: beforeNavigate),
      child: Listener(
        onPointerDown: (e) {
          if (kIsWeb && e.buttons == 4) {
            _openRoute(
              context,
              route,
              newTab: true,
              beforeNavigate: beforeNavigate,
            );
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          decoration: BoxDecoration(
            color:
                isActive
                    ? const Color(0xFFFFC024).withValues(alpha: 0.28)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border:
                isActive
                    ? const Border(
                      left: BorderSide(color: Color(0xFFFFC024), width: 3),
                    )
                    : null,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color:
                    isActive
                        ? const Color(0xFF1E1E1E)
                        : const Color(0xFF1E1E1E).withValues(alpha: 0.72),
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
                            : const Color(0xFF1E1E1E).withValues(alpha: 0.78),
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
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
  State<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends State<AppScaffold> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  static const double _mobileBreakpoint = 900;

  void _closeDrawerIfOpen() {
    final state = _scaffoldKey.currentState;
    if (state?.isDrawerOpen == true) {
      state!.closeDrawer();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UserProfile?>(
      valueListenable: AuthSession.instance.currentUser,
      builder: (context, user, _) {
        final showSearch = widget.showSearch;
        final searchController = widget.searchController;
        final searchHint = widget.searchHint;
        final onSearchChanged = widget.onSearchChanged;
        final child = widget.child;

        final role = AuthSession.instance.currentRole;
        final perms = user?.pagePermissions;
        final userName = user?.fullName ?? user?.email ?? 'Staff';
        final sidebarItems = AppScaffold._sidebarItemsForRole(role, perms);
        final isNarrow =
            MediaQuery.sizeOf(context).width < _mobileBreakpoint;

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

        Widget buildSidebarList({required bool inDrawer}) {
          void closeDrawer() {
            if (inDrawer) _closeDrawerIfOpen();
          }

          final items = [
            const SizedBox(height: 8),
            ...sidebarItems.map(
              (item) => AppScaffold._buildSidebarItem(
                context,
                item.icon,
                item.label,
                item.route,
                beforeNavigate: closeDrawer,
              ),
            ),
            const SizedBox(height: 20),
          ];

          if (inDrawer) {
            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                  child: Row(
                    children: [
                      Image.asset(
                        'lib/assets/main.png',
                        height: 28,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Menu',
                          style: TextStyle(
                            color: Color(0xFF1E1E1E),
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: _closeDrawerIfOpen,
                        icon: const Icon(
                          Icons.close,
                          color: Color(0xFF1E1E1E),
                        ),
                      ),
                    ],
                  ),
                ),
                ...items,
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(children: items),
                ),
              ),
            ],
          );
        }

        Widget buildSidebarPanel({bool inDrawer = false}) {
          return Container(
            width: inDrawer ? null : 240,
            color: const Color(0xFFCDEDEC),
            child: buildSidebarList(inDrawer: inDrawer),
          );
        }

        return Theme(
          data: Theme.of(context).copyWith(
            scaffoldBackgroundColor: AntdTokens.staffBg,
          ),
          child: Scaffold(
            key: _scaffoldKey,
            backgroundColor: AntdTokens.staffBg,
            drawer:
                isNarrow
                    ? Drawer(
                      backgroundColor: const Color(0xFFCDEDEC),
                      width: 280,
                      child: SafeArea(
                        child: buildSidebarPanel(inDrawer: true),
                      ),
                    )
                    : null,
            body: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCDEDEC),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      if (isNarrow)
                        IconButton(
                          tooltip: 'Open menu',
                          onPressed:
                              () => _scaffoldKey.currentState?.openDrawer(),
                          icon: const Icon(
                            Icons.menu,
                            color: Color(0xFF1E1E1E),
                          ),
                        ),
                      Image.asset(
                        'lib/assets/main.png',
                        height: 32,
                        fit: BoxFit.contain,
                      ),
                      const Spacer(),
                      if (showSearch && searchController != null) ...[
                        Flexible(
                          child: AntdSearchInput(
                            controller: searchController,
                            hintText: searchHint,
                            width: isNarrow ? 180 : 320,
                            onChanged: onSearchChanged,
                            onClear: () {
                              searchController.clear();
                              onSearchChanged?.call('');
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      AntdProfileMenu(
                        triggerLabel: userName,
                        triggerForegroundColor: const Color(0xFF1E1E1E),
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
                Expanded(
                  child: SafeArea(
                    top: false,
                    child:
                        isNarrow
                            ? child
                            : Row(
                              children: [
                                DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFCDEDEC),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.08,
                                        ),
                                        blurRadius: 12,
                                        offset: const Offset(2, 0),
                                      ),
                                    ],
                                  ),
                                  child: SizedBox(
                                    width: 240,
                                    child: buildSidebarPanel(),
                                  ),
                                ),
                                Expanded(child: child),
                              ],
                            ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
