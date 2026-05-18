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
import 'pages/restaurant_order_page.dart';
import 'pages/catering_menu_page.dart';
import 'auth/page_permissions.dart';
import 'auth/role_guard.dart';
import 'auth/roles.dart';
import 'widgets/page_permission_guard.dart';
import 'pages/help_requests.dart';
import 'pages/action_logs.dart';
import 'pages/customer_management.dart';
import 'pages/website_admin_page.dart';
import 'pages/restaurant_transactions_page.dart';
import 'pages/inventory.dart';
import 'widgets/app_scaffold.dart';
import 'data_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  setUrlStrategy(PathUrlStrategy());

  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    // Ignore .env loading error for web deployment
  }

  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);

  if (isApexCurateringHost) {
    redirectApexHostToSubdomain(Uri.base.path);
    return;
  }

  runApp(const MyApp());
}

Widget _customerPage(Widget child, String path) {
  return HostRouteGuard(
    routePath: path,
    child: child,
  );
}

Widget _staffPage(Widget child, String path) {
  return HostRouteGuard(
    routePath: path,
    child: child,
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: DataStore.isDarkMode,
      builder: (context, dark, _) {
        return MaterialApp(
          title: 'Curatering',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
            useMaterial3: true,
            brightness: dark ? Brightness.dark : Brightness.light,
            textTheme: GoogleFonts.interTextTheme(),
            pageTransitionsTheme: const PageTransitionsTheme(
              builders: {
                TargetPlatform.android: _NoTransitionsBuilder(),
                TargetPlatform.iOS: _NoTransitionsBuilder(),
                TargetPlatform.linux: _NoTransitionsBuilder(),
                TargetPlatform.macOS: _NoTransitionsBuilder(),
                TargetPlatform.windows: _NoTransitionsBuilder(),
                TargetPlatform.fuchsia: _NoTransitionsBuilder(),
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
                return dark
                    ? const Color(0xFF5C5C5C)
                    : const Color(0xFFBFBFBF);
              }),
            ),
          ),
          initialRoute: resolveAppInitialRoute(),
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
              return MaterialPageRoute<void>(
                settings: settings,
                builder:
                    (_) => ExternalHostRedirect(
                      origin: customerSiteOrigin,
                      path: customerRoute(name),
                    ),
              );
            }
            if (isCustomerSiteHost) {
              if (isStaffRoute(name)) {
                return MaterialPageRoute<void>(
                  settings: settings,
                  builder:
                      (_) => ExternalHostRedirect(
                        origin: staffSiteOrigin,
                        path: name,
                      ),
                );
              }
            }
            if (isStaffRoute(name)) {
              return MaterialPageRoute<void>(
                settings: settings,
                builder: (_) => _staffPage(const Login(), '/login'),
              );
            }
            final rawName = settings.name ?? name;
            if (isLegacyBookmarkPath(rawName)) {
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
            kLegacyCustomerPathPrefix:
                (context) => const LegacyPathRedirect(target: '/'),
            '$kLegacyCustomerPathPrefix/gallery':
                (context) => const LegacyPathRedirect(target: '/gallery'),
            '$kLegacyCustomerPathPrefix/contact-us':
                (context) => const LegacyPathRedirect(target: '/contact-us'),
            '$kLegacyCustomerPathPrefix/inquire':
                (context) => const LegacyPathRedirect(target: '/inquire'),
            '$kLegacyCustomerPathPrefix/restaurant':
                (context) => const LegacyPathRedirect(target: '/restaurant'),
            '$kLegacyCustomerPathPrefix/catering-menu':
                (context) => const LegacyPathRedirect(target: '/catering-menu'),
            '/dashboard':
                (context) => _staffPage(
                  RoleGuard(
                    requiredRole: Role.manager,
                    allowedRoles: {Role.manager, Role.supervisor},
                    child: PagePermissionGuard(
                      route: PagePermissionRoutes.dashboard,
                      child: const Dashboard(),
                    ),
                  ),
                  '/dashboard',
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
                    allowedRoles: {Role.manager, Role.supervisor},
                    child: PagePermissionGuard(
                      route: PagePermissionRoutes.restaurantOrders,
                      child: const AppScaffold(
                        child: RestaurantTransactionsPage(),
                      ),
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
                      contentEditable: false,
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

/// Disables route transition animations for snappier staff navigation.
class _NoTransitionsBuilder extends PageTransitionsBuilder {
  const _NoTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
}
