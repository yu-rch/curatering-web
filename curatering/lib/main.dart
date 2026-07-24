import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Placeholder;
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'config.dart';
import 'config/site_routes.dart';
import 'widgets/app_root_route.dart';
import 'widgets/external_host_redirect.dart';
import 'widgets/legacy_path_redirect.dart';
import 'pages/login.dart';
import 'pages/dashboard.dart';
import 'pages/manage_accounts.dart';
import 'pages/catering.dart';
import 'pages/manage_loyalty_rewards.dart';
import 'pages/archive.dart';
import 'pages/menu.dart';
import 'pages/reports.dart';
import 'pages/transactions.dart';
import 'pages/settings.dart';
import 'pages/customer_website.dart';
import 'pages/gallery_page.dart';
import 'pages/contact_us_page.dart';
import 'pages/inquire_page.dart';
import 'pages/my_caterings_page.dart';
import 'pages/restaurant_order_page.dart';
import 'pages/restaurant_feedback_public_page.dart';
import 'pages/catering_menu_page.dart';
import 'auth/auth_session.dart';
import 'auth/page_permissions.dart';
import 'auth/role_guard.dart';
import 'auth/roles.dart';
import 'auth/staff_permission_refresh.dart';
import 'widgets/page_permission_guard.dart';
import 'pages/help_requests.dart';
import 'pages/customer_feedback_page.dart';
import 'pages/action_logs.dart';
import 'pages/customer_management.dart';
import 'pages/website_admin_page.dart';
import 'pages/restaurant_orders_route.dart';
import 'pages/inventory.dart';
import 'pages/super_admin_dashboard.dart';
import 'data_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  setUrlStrategy(PathUrlStrategy());

  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    // Ignore .env loading error for web deployment
  }

  if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  } else if (kDebugMode) {
    debugPrint(
      'Supabase not initialized — set SUPABASE_URL and SUPABASE_ANON_KEY for storage features.',
    );
  }

  if (redirectApexHostToSubdomain(currentWebPath())) return;

  if (bootstrapWebRouting()) return;

  runApp(const MyApp());
}

Widget _customerPage(Widget child, String path) {
  return HostRouteGuard(routePath: path, child: child);
}

Widget _staffPage(Widget child, String path) {
  return HostRouteGuard(routePath: path, child: child);
}

class _RoleAwareDashboard extends StatelessWidget {
  const _RoleAwareDashboard();

  @override
  Widget build(BuildContext context) {
    if (AuthSession.instance.currentRole == Role.superAdmin) {
      return const SuperAdminDashboardPage();
    }
    return const Dashboard();
  }
}

String _startupRoutePath() => resolveAppInitialRoute();

String _routePathFromSettings(RouteSettings settings) {
  var path = normalizeRoutePath(settings.name ?? rawWebPath());
  final raw = settings.name ?? rawWebPath();
  path = stripLegacyCustomerPrefix(path);
  if (isStaffSiteHost && (path == '/' || isLegacyBookmarkPath(raw))) {
    return '/login';
  }
  return path;
}

Route<dynamic>? _buildRouteForPath(String path) {
  final routes = <String, Widget Function(BuildContext)>{
    '/': (context) => const AppRootRoute(),
    '/login': (context) => _staffPage(const Login(), '/login'),
    '/gallery':
        (context) => _customerPage(
          const GalleryPage(contentEditable: false, showStaffChrome: false),
          '/gallery',
        ),
    '/contact-us':
        (context) => _customerPage(
          const ContactUsPage(contentEditable: false, showStaffChrome: false),
          '/contact-us',
        ),
    '/inquire':
        (context) => _customerPage(
          const InquirePage(contentEditable: false, showStaffChrome: false),
          '/inquire',
        ),
    '/my-inquiries':
        (context) => _customerPage(
          const MyCateringsPage(),
          '/my-inquiries',
        ),
    '/restaurant':
        (context) => _customerPage(
          const RestaurantOrderPage(
            contentEditable: false,
            showStaffChrome: false,
          ),
          '/restaurant',
        ),
    '/restaurant-feedback':
        (context) => _customerPage(
          RestaurantFeedbackPublicPage(
            token: Uri.base.queryParameters['token'] ?? '',
          ),
          '/restaurant-feedback',
        ),
    '/catering-menu':
        (context) => _customerPage(
          const CateringMenuPage(
            contentEditable: false,
            showStaffChrome: false,
          ),
          '/catering-menu',
        ),
    '/dashboard':
        (context) => _staffPage(
          RoleGuard(
            requiredRole: Role.manager,
            allowedRoles: {Role.manager, Role.supervisor, Role.superAdmin},
            child: PagePermissionGuard(
              route: PagePermissionRoutes.dashboard,
              child: const _RoleAwareDashboard(),
            ),
          ),
          '/dashboard',
        ),
    '/super-admin-dashboard':
        (context) => _staffPage(
          const RoleGuard(
            requiredRole: Role.superAdmin,
            child: _RoleAwareDashboard(),
          ),
          '/super-admin-dashboard',
        ),
    '/manager-dashboard':
        (context) => _staffPage(
          const RoleGuard(requiredRole: Role.superAdmin, child: Dashboard()),
          '/manager-dashboard',
        ),
    '/manage-accounts':
        (context) => _staffPage(
          const RoleGuard(
            requiredRole: Role.superAdmin,
            child: ManageAccounts(),
          ),
          '/manage-accounts',
        ),
    '/help-requests':
        (context) => _staffPage(
          RoleGuard(
            requiredRole: Role.superAdmin,
            allowedRoles: {Role.manager, Role.supervisor},
            child: PagePermissionGuard(
              route: PagePermissionRoutes.helpRequests,
              child: const HelpRequestsPage(),
            ),
          ),
          '/help-requests',
        ),
    '/customer-feedback':
        (context) => _staffPage(
          RoleGuard(
            requiredRole: Role.superAdmin,
            allowedRoles: {Role.manager},
            child: CustomerFeedbackPage(),
          ),
          '/customer-feedback',
        ),
    '/action-logs':
        (context) => _staffPage(
          const RoleGuard(
            requiredRole: Role.superAdmin,
            child: ActionLogsPage(),
          ),
          '/action-logs',
        ),
    '/customer-management':
        (context) => _staffPage(
          const RoleGuard(
            requiredRole: Role.superAdmin,
            child: CustomerManagementPage(),
          ),
          '/customer-management',
        ),
    '/manage-events':
        (context) => _staffPage(
          RoleGuard(
            requiredRole: Role.manager,
            allowedRoles: {Role.manager, Role.supervisor},
            child: PagePermissionGuard(
              route: PagePermissionRoutes.manageEvents,
              child: const ManageEvents(),
            ),
          ),
          '/manage-events',
        ),
    '/loyalty':
        (context) => _staffPage(
          RoleGuard(
            requiredRole: Role.manager,
            allowedRoles: {Role.manager, Role.supervisor},
            child: PagePermissionGuard(
              route: PagePermissionRoutes.loyalty,
              child: const ManageLoyaltyRewards(),
            ),
          ),
          '/loyalty',
        ),
    '/catering-restaurant-menu':
        (context) => _staffPage(
          RoleGuard(
            requiredRole: Role.manager,
            allowedRoles: {Role.manager},
            child: PagePermissionGuard(
              route: PagePermissionRoutes.menu,
              child: const Menu(),
            ),
          ),
          '/catering-restaurant-menu',
        ),
    '/inventory':
        (context) => _staffPage(
          RoleGuard(
            requiredRole: Role.manager,
            allowedRoles: {Role.manager, Role.supervisor},
            child: PagePermissionGuard(
              route: PagePermissionRoutes.inventory,
              child: const Inventory(),
            ),
          ),
          '/inventory',
        ),
    '/restaurant-orders':
        (context) => _staffPage(
          RoleGuard(
            requiredRole: Role.manager,
            allowedRoles: {Role.manager, Role.supervisor, Role.cashier},
            child: PagePermissionGuard(
              route: PagePermissionRoutes.restaurantOrders,
              child: const RestaurantOrdersRoute(),
            ),
          ),
          '/restaurant-orders',
        ),
    '/reports':
        (context) => _staffPage(
          RoleGuard(
            requiredRole: Role.manager,
            allowedRoles: {Role.manager},
            child: PagePermissionGuard(
              route: PagePermissionRoutes.reports,
              child: const Reports(),
            ),
          ),
          '/reports',
        ),
    '/order-history':
        (context) => _staffPage(
          RoleGuard(
            requiredRole: Role.manager,
            allowedRoles: {Role.manager, Role.supervisor},
            child: PagePermissionGuard(
              route: PagePermissionRoutes.orderHistory,
              child: const Transactions(),
            ),
          ),
          '/order-history',
        ),
    '/archive':
        (context) => _staffPage(
          RoleGuard(
            requiredRole: Role.manager,
            allowedRoles: {Role.manager, Role.superAdmin},
            child: PagePermissionGuard(
              route: PagePermissionRoutes.archive,
              child: Archive(),
            ),
          ),
          '/archive',
        ),
    '/website':
        (context) => _staffPage(
          const RoleGuard(
            requiredRole: Role.superAdmin,
            child: CustomerWebsiteScreen(
              contentEditable: true,
              showStaffChrome: true,
            ),
          ),
          '/website',
        ),
    '/website-admin':
        (context) => _staffPage(
          const RoleGuard(
            requiredRole: Role.superAdmin,
            child: WebsiteAdminPage(),
          ),
          '/website-admin',
        ),
    '/settings':
        (context) => _staffPage(
          RoleGuard(
            requiredRole: Role.manager,
            allowedRoles: {Role.manager, Role.supervisor},
            child: PagePermissionGuard(
              route: PagePermissionRoutes.settings,
              child: const Settings(),
            ),
          ),
          '/settings',
        ),
  };

  if (needsRedirectToCustomerSite(path)) {
    return MaterialPageRoute<void>(
      settings: RouteSettings(name: path),
      builder:
          (_) => ExternalHostRedirect(
            origin: customerSiteOrigin,
            path: customerRoute(path),
          ),
    );
  }
  if (needsRedirectToStaffSite(path)) {
    return MaterialPageRoute<void>(
      settings: RouteSettings(name: path),
      builder: (_) => ExternalHostRedirect(origin: staffSiteOrigin, path: path),
    );
  }

  final builder = routes[path];
  if (builder == null) return null;
  return MaterialPageRoute<void>(
    settings: RouteSettings(name: path),
    builder: builder,
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  static const Duration _staffIdleTimeout = Duration(minutes: 5);

  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  Timer? _staffIdleTimer;
  bool _showingTimeoutDialog = false;

  @override
  void initState() {
    super.initState();
    AuthSession.instance.isLoggedIn.addListener(_handleSessionChanged);
    _handleSessionChanged();
  }

  @override
  void dispose() {
    AuthSession.instance.isLoggedIn.removeListener(_handleSessionChanged);
    _staffIdleTimer?.cancel();
    super.dispose();
  }

  void _handleSessionChanged() {
    if (AuthSession.instance.hasToken) {
      _armStaffIdleTimer();
    } else {
      _staffIdleTimer?.cancel();
      _staffIdleTimer = null;
    }
  }

  void _recordStaffActivity() {
    if (AuthSession.instance.hasToken) {
      _armStaffIdleTimer();
    }
  }

  void _armStaffIdleTimer() {
    _staffIdleTimer?.cancel();
    _staffIdleTimer = Timer(_staffIdleTimeout, _expireStaffSessionForIdle);
  }

  Future<void> _expireStaffSessionForIdle() async {
    if (!AuthSession.instance.hasToken) return;
    final nav = _navigatorKey.currentState;
    if (nav == null) return;
    final context = _navigatorKey.currentContext;
    if (context != null && !_showingTimeoutDialog) {
      _showingTimeoutDialog = true;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder:
            (dialogContext) => AlertDialog(
              title: const Text('Account timed out'),
              content: const Text(
                'Your account has timed out, login to continue access.',
              ),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
      );
      _showingTimeoutDialog = false;
    }
    if (!AuthSession.instance.hasToken) return;
    AuthSession.instance.clear();
    nav.pushNamedAndRemoveUntil('/login', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: DataStore.isDarkMode,
      builder: (context, dark, _) {
        return MaterialApp(
          title: 'Curatering',
          navigatorKey: _navigatorKey,
          navigatorObservers: [StaffPermissionRefreshObserver.instance],
          builder:
              (context, child) => Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: (_) => _recordStaffActivity(),
                onPointerMove: (_) => _recordStaffActivity(),
                onPointerHover: (_) => _recordStaffActivity(),
                onPointerSignal: (_) => _recordStaffActivity(),
                child: child ?? const SizedBox.shrink(),
              ),
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
            useMaterial3: true,
            brightness: dark ? Brightness.dark : Brightness.light,
            textTheme: GoogleFonts.interTextTheme(),
            pageTransitionsTheme: const PageTransitionsTheme(
              builders: {
                TargetPlatform.android: _SmoothPageTransitionsBuilder(),
                TargetPlatform.iOS: _SmoothPageTransitionsBuilder(),
                TargetPlatform.linux: _SmoothPageTransitionsBuilder(),
                TargetPlatform.macOS: _SmoothPageTransitionsBuilder(),
                TargetPlatform.windows: _SmoothPageTransitionsBuilder(),
                TargetPlatform.fuchsia: _SmoothPageTransitionsBuilder(),
              },
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFC024),
                foregroundColor: const Color(0xFF1E1E1E),
              ),
            ),
            filledButtonTheme: FilledButtonThemeData(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFFC024),
                foregroundColor: const Color(0xFF1E1E1E),
              ),
            ),
            radioTheme: RadioThemeData(
              fillColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return const Color(0xFFFFC024);
                }
                return dark ? const Color(0xFF5C5C5C) : const Color(0xFFBFBFBF);
              }),
            ),
          ),
          onGenerateInitialRoutes: (_) {
            final path = _startupRoutePath();
            final built = _buildRouteForPath(path);
            return [
              built ??
                  MaterialPageRoute<void>(
                    settings: RouteSettings(name: path),
                    builder: (_) => const AppRootRoute(),
                  ),
            ];
          },
          onGenerateRoute: (settings) {
            final path = _routePathFromSettings(settings);
            final built = _buildRouteForPath(path);
            if (built != null) return built;
            return null;
          },
          onUnknownRoute: (settings) {
            final name = stripLegacyCustomerPrefix(
              settings.name ?? resolveAppInitialRoute(),
            );
            if (isStaffSiteHost) {
              if (isStaffRoute(name)) {
                return MaterialPageRoute<void>(
                  settings: settings,
                  builder: (_) => _staffPage(const Login(), '/login'),
                );
              }
              if (needsRedirectToCustomerSite(name)) {
                return MaterialPageRoute<void>(
                  settings: settings,
                  builder:
                      (_) => ExternalHostRedirect(
                        origin: customerSiteOrigin,
                        path: customerRoute(name),
                      ),
                );
              }
            }
            if (needsRedirectToStaffSite(name)) {
              return MaterialPageRoute<void>(
                settings: settings,
                builder:
                    (_) => ExternalHostRedirect(
                      origin: staffSiteOrigin,
                      path: name,
                    ),
              );
            }
            if (isStaffRoute(name)) {
              return MaterialPageRoute<void>(
                settings: settings,
                builder: (_) => _staffPage(const Login(), '/login'),
              );
            }
            final rawName = settings.name ?? name;
            if (isLegacyBookmarkPath(rawName)) {
              if (isStaffSiteHost) {
                return MaterialPageRoute<void>(
                  settings: const RouteSettings(name: '/login'),
                  builder: (_) => _staffPage(const Login(), '/login'),
                );
              }
              return MaterialPageRoute<void>(
                settings: settings,
                builder:
                    (_) => LegacyPathRedirect(
                      target: stripLegacyCustomerPrefix(rawName),
                    ),
              );
            }
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => const AppRootRoute(),
            );
          },
          routes: {
            '/': (context) => const AppRootRoute(),
            '/login': (context) => _staffPage(const Login(), '/login'),
            '/gallery':
                (context) => _customerPage(
                  const GalleryPage(
                    contentEditable: false,
                    showStaffChrome: false,
                  ),
                  '/gallery',
                ),
            '/contact-us':
                (context) => _customerPage(
                  const ContactUsPage(
                    contentEditable: false,
                    showStaffChrome: false,
                  ),
                  '/contact-us',
                ),
            '/inquire':
                (context) => _customerPage(
                  const InquirePage(
                    contentEditable: false,
                    showStaffChrome: false,
                  ),
                  '/inquire',
                ),
            '/my-inquiries':
                (context) => _customerPage(
                  const MyCateringsPage(),
                  '/my-inquiries',
                ),
            '/restaurant':
                (context) => _customerPage(
                  const RestaurantOrderPage(
                    contentEditable: false,
                    showStaffChrome: false,
                  ),
                  '/restaurant',
                ),
            '/catering-menu':
                (context) => _customerPage(
                  const CateringMenuPage(
                    contentEditable: false,
                    showStaffChrome: false,
                  ),
                  '/catering-menu',
                ),
            '/dashboard':
                (context) => _staffPage(
                  RoleGuard(
                    requiredRole: Role.manager,
                    allowedRoles: {
                      Role.manager,
                      Role.supervisor,
                      Role.superAdmin,
                    },
                    child: PagePermissionGuard(
                      route: PagePermissionRoutes.dashboard,
                      child: const _RoleAwareDashboard(),
                    ),
                  ),
                  '/dashboard',
                ),
            '/manager-dashboard':
                (context) => _staffPage(
                  const RoleGuard(
                    requiredRole: Role.superAdmin,
                    child: Dashboard(),
                  ),
                  '/manager-dashboard',
                ),
            '/manage-accounts':
                (context) => _staffPage(
                  const RoleGuard(
                    requiredRole: Role.superAdmin,
                    child: ManageAccounts(),
                  ),
                  '/manage-accounts',
                ),
            '/help-requests':
                (context) => _staffPage(
                  const RoleGuard(
                    requiredRole: Role.superAdmin,
                    child: HelpRequestsPage(),
                  ),
                  '/help-requests',
                ),
            '/customer-feedback':
                (context) => _staffPage(
                  RoleGuard(
                    requiredRole: Role.superAdmin,
                    allowedRoles: {Role.manager},
                    child: CustomerFeedbackPage(),
                  ),
                  '/customer-feedback',
                ),
            '/action-logs':
                (context) => _staffPage(
                  const RoleGuard(
                    requiredRole: Role.superAdmin,
                    child: ActionLogsPage(),
                  ),
                  '/action-logs',
                ),
            '/customer-management':
                (context) => _staffPage(
                  const RoleGuard(
                    requiredRole: Role.superAdmin,
                    child: CustomerManagementPage(),
                  ),
                  '/customer-management',
                ),
            '/manage-events':
                (context) => _staffPage(
                  RoleGuard(
                    requiredRole: Role.manager,
                    allowedRoles: {Role.manager, Role.supervisor},
                    child: PagePermissionGuard(
                      route: PagePermissionRoutes.manageEvents,
                      child: const ManageEvents(),
                    ),
                  ),
                  '/manage-events',
                ),
            '/loyalty':
                (context) => _staffPage(
                  RoleGuard(
                    requiredRole: Role.manager,
                    allowedRoles: {Role.manager, Role.supervisor},
                    child: PagePermissionGuard(
                      route: PagePermissionRoutes.loyalty,
                      child: const ManageLoyaltyRewards(),
                    ),
                  ),
                  '/loyalty',
                ),
            '/catering-restaurant-menu':
                (context) => _staffPage(
                  RoleGuard(
                    requiredRole: Role.manager,
                    allowedRoles: {Role.manager},
                    child: PagePermissionGuard(
                      route: PagePermissionRoutes.menu,
                      child: const Menu(),
                    ),
                  ),
                  '/catering-restaurant-menu',
                ),
            '/inventory':
                (context) => _staffPage(
                  RoleGuard(
                    requiredRole: Role.manager,
                    allowedRoles: {Role.manager, Role.supervisor},
                    child: PagePermissionGuard(
                      route: PagePermissionRoutes.inventory,
                      child: const Inventory(),
                    ),
                  ),
                  '/inventory',
                ),
            '/restaurant-orders':
                (context) => _staffPage(
                  RoleGuard(
                    requiredRole: Role.manager,
                    allowedRoles: {Role.manager, Role.supervisor, Role.cashier},
                    child: PagePermissionGuard(
                      route: PagePermissionRoutes.restaurantOrders,
                      child: const RestaurantOrdersRoute(),
                    ),
                  ),
                  '/restaurant-orders',
                ),
            '/reports':
                (context) => _staffPage(
                  RoleGuard(
                    requiredRole: Role.manager,
                    allowedRoles: {Role.manager},
                    child: PagePermissionGuard(
                      route: PagePermissionRoutes.reports,
                      child: const Reports(),
                    ),
                  ),
                  '/reports',
                ),
            '/order-history':
                (context) => _staffPage(
                  RoleGuard(
                    requiredRole: Role.manager,
                    allowedRoles: {Role.manager, Role.supervisor},
                    child: PagePermissionGuard(
                      route: PagePermissionRoutes.orderHistory,
                      child: const Transactions(),
                    ),
                  ),
                  '/order-history',
                ),
            '/archive':
                (context) => _staffPage(
                  RoleGuard(
                    requiredRole: Role.manager,
                    allowedRoles: {Role.manager, Role.superAdmin},
                    child: PagePermissionGuard(
                      route: PagePermissionRoutes.archive,
                      child: Archive(),
                    ),
                  ),
                  '/archive',
                ),
            '/website':
                (context) => _staffPage(
                  const RoleGuard(
                    requiredRole: Role.superAdmin,
                    child: CustomerWebsiteScreen(
                      contentEditable: true,
                      showStaffChrome: true,
                    ),
                  ),
                  '/website',
                ),
            '/website-admin':
                (context) => _staffPage(
                  const RoleGuard(
                    requiredRole: Role.superAdmin,
                    child: WebsiteAdminPage(),
                  ),
                  '/website-admin',
                ),
            '/settings':
                (context) => _staffPage(
                  RoleGuard(
                    requiredRole: Role.manager,
                    allowedRoles: {Role.manager, Role.supervisor},
                    child: PagePermissionGuard(
                      route: PagePermissionRoutes.settings,
                      child: const Settings(),
                    ),
                  ),
                  '/settings',
                ),
          },
        );
      },
    );
  }
}

/// Smooths route changes without making staff navigation feel slow.
class _SmoothPageTransitionsBuilder extends PageTransitionsBuilder {
  const _SmoothPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (route.isFirst) return child;
    final curved = animation.drive(CurveTween(curve: Curves.easeOutQuart));
    return FadeTransition(
      opacity: Tween<double>(begin: 0.0, end: 1.0).animate(curved),
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.995, end: 1.0).animate(curved),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.012, 0.008),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      ),
    );
  }
}
