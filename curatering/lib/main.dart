import 'package:flutter/material.dart' hide Placeholder;
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'config.dart';
import 'config/site_routes.dart';
import 'widgets/customer_route_redirect.dart';
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
import 'auth/auth_session.dart';
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

  // For web deployment, environment variables are set through build config
  // or platform-specific methods, not through .env file loading
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    // Ignore .env loading error for web deployment
    // Environment variables will be loaded from platform or build config
  }

  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
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
            final name = settings.name ?? resolveAppInitialRoute();
            if (isStaffRoute(name)) {
              return MaterialPageRoute<void>(
                settings: settings,
                builder: (_) => const Login(),
              );
            }
            return MaterialPageRoute<void>(
              settings: settings,
              builder:
                  (_) => CustomerRouteRedirect(
                    target: name.startsWith('/') ? name : '/$name',
                  ),
            );
          },
          routes: {
            '/login': (context) => const Login(),
            '/': (context) => const CustomerRouteRedirect(target: '/'),
            kCustomerSitePrefix:
                (context) => const CustomerWebsiteScreen(
                  contentEditable: false,
                  showStaffChrome: false,
                ),
            '$kCustomerSitePrefix/gallery':
                (context) => const GalleryPage(
                  contentEditable: false,
                  showStaffChrome: false,
                ),
            '$kCustomerSitePrefix/contact-us':
                (context) => const ContactUsPage(
                  contentEditable: false,
                  showStaffChrome: false,
                ),
            '$kCustomerSitePrefix/inquire':
                (context) => const InquirePage(
                  contentEditable: false,
                  showStaffChrome: false,
                ),
            '$kCustomerSitePrefix/restaurant':
                (context) => const RestaurantOrderPage(
                  contentEditable: false,
                  showStaffChrome: false,
                ),
            '$kCustomerSitePrefix/catering-menu':
                (context) => const CateringMenuPage(
                  contentEditable: false,
                  showStaffChrome: false,
                ),
            '/gallery':
                (context) => const CustomerRouteRedirect(target: '/gallery'),
            '/contact-us':
                (context) => const CustomerRouteRedirect(target: '/contact-us'),
            '/inquire':
                (context) => const CustomerRouteRedirect(target: '/inquire'),
            '/restaurant':
                (context) => const CustomerRouteRedirect(target: '/restaurant'),
            '/catering-menu':
                (context) =>
                    const CustomerRouteRedirect(target: '/catering-menu'),
            '/dashboard':
                (context) => RoleGuard(
                  requiredRole: Role.manager,
                  allowedRoles: {Role.manager, Role.supervisor},
                  child: PagePermissionGuard(
                    route: PagePermissionRoutes.dashboard,
                    child: const Dashboard(),
                  ),
                ),
            '/manage-accounts':
                (context) => const RoleGuard(
                  requiredRole: Role.superAdmin,
                  child: ManageAccounts(),
                ),
            '/help-requests':
                (context) => const RoleGuard(
                  requiredRole: Role.superAdmin,
                  child: HelpRequestsPage(),
                ),
            '/action-logs':
                (context) => const RoleGuard(
                  requiredRole: Role.superAdmin,
                  child: ActionLogsPage(),
                ),
            '/customer-management':
                (context) => const RoleGuard(
                  requiredRole: Role.superAdmin,
                  child: CustomerManagementPage(),
                ),
            '/manage-events':
                (context) => RoleGuard(
                  requiredRole: Role.manager,
                  allowedRoles: {Role.manager, Role.supervisor},
                  child: PagePermissionGuard(
                    route: PagePermissionRoutes.manageEvents,
                    child: const ManageEvents(),
                  ),
                ),
            '/loyalty':
                (context) => RoleGuard(
                  requiredRole: Role.manager,
                  allowedRoles: {Role.manager, Role.supervisor},
                  child: PagePermissionGuard(
                    route: PagePermissionRoutes.loyalty,
                    child: const ManageLoyaltyRewards(),
                  ),
                ),
            '/catering-restaurant-menu':
                (context) => RoleGuard(
                  requiredRole: Role.manager,
                  allowedRoles: {Role.manager},
                  child: PagePermissionGuard(
                    route: PagePermissionRoutes.menu,
                    child: const Menu(),
                  ),
                ),
            '/inventory':
                (context) => RoleGuard(
                  requiredRole: Role.manager,
                  allowedRoles: {Role.manager, Role.supervisor},
                  child: PagePermissionGuard(
                    route: PagePermissionRoutes.inventory,
                    child: const Inventory(),
                  ),
                ),
            '/restaurant-orders':
                (context) => RoleGuard(
                  requiredRole: Role.manager,
                  allowedRoles: {Role.manager, Role.supervisor},
                  child: PagePermissionGuard(
                    route: PagePermissionRoutes.restaurantOrders,
                    child: const AppScaffold(
                      child: RestaurantTransactionsPage(),
                    ),
                  ),
                ),
            '/reports':
                (context) => RoleGuard(
                  requiredRole: Role.manager,
                  allowedRoles: {Role.manager},
                  child: PagePermissionGuard(
                    route: PagePermissionRoutes.reports,
                    child: const Reports(),
                  ),
                ),
            '/order-history':
                (context) => RoleGuard(
                  requiredRole: Role.manager,
                  allowedRoles: {Role.manager, Role.supervisor},
                  child: PagePermissionGuard(
                    route: PagePermissionRoutes.orderHistory,
                    child: const Transactions(),
                  ),
                ),
            '/archive':
                (context) => RoleGuard(
                  requiredRole: Role.manager,
                  allowedRoles: {Role.manager, Role.superAdmin},
                  child: PagePermissionGuard(
                    route: PagePermissionRoutes.archive,
                    child: Archive(),
                  ),
                ),
            '/website':
                (context) => const RoleGuard(
                  requiredRole: Role.superAdmin,
                  child: CustomerWebsiteScreen(
                    contentEditable: false,
                    showStaffChrome: true,
                  ),
                ),
            '/website-admin':
                (context) => const RoleGuard(
                  requiredRole: Role.superAdmin,
                  child: WebsiteAdminPage(),
                ),
            '/settings':
                (context) => RoleGuard(
                  requiredRole: Role.manager,
                  allowedRoles: {Role.manager, Role.supervisor},
                  child: PagePermissionGuard(
                    route: PagePermissionRoutes.settings,
                    child: const Settings(),
                  ),
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
