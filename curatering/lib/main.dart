import 'package:flutter/material.dart' hide Placeholder;
import 'package:google_fonts/google_fonts.dart';
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
import 'pages/placeholder.dart';
import 'pages/customer_website.dart';
import 'auth/auth_session.dart';
import 'data_store.dart';
import 'auth/page_permissions.dart';
import 'auth/role_guard.dart';
import 'auth/roles.dart';
import 'widgets/page_permission_guard.dart';
import 'pages/help_requests.dart';
import 'pages/action_logs.dart';
import 'pages/customer_management.dart';

void main() {
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
          ),
          initialRoute: '/public',
          routes: {
            '/login': (context) => const Login(),
            '/public': (context) => const CustomerWebsiteScreen(
                  contentEditable: false,
                  showStaffChrome: false,
                ),
            '/dashboard': (context) => RoleGuard(
                  requiredRole: Role.manager,
                  allowedRoles: {Role.manager, Role.supervisor},
                  child: PagePermissionGuard(
                    route: PagePermissionRoutes.dashboard,
                    child: const Dashboard(),
                  ),
                ),
            // '/live-performance': (context) => RoleGuard(
            //       requiredRole: Role.manager,
            //       allowedRoles: {Role.manager, Role.supervisor, Role.admin},
            //       child: PagePermissionGuard(
            //         route: PagePermissionRoutes.livePerformance,
            //         child: const LivePerformance(),
            //       ),
            //     ),
            '/manage-accounts': (context) => const RoleGuard(
                  requiredRole: Role.superAdmin,
                  child: ManageAccounts(),
                ),
            '/help-requests': (context) => const RoleGuard(
                  requiredRole: Role.superAdmin,
                  child: HelpRequestsPage(),
                ),
            '/action-logs': (context) => const RoleGuard(
                  requiredRole: Role.superAdmin,
                  child: ActionLogsPage(),
                ),
            '/customer-management': (context) => const RoleGuard(
                  requiredRole: Role.superAdmin,
                  child: CustomerManagementPage(),
                ),
            '/manage-events': (context) => RoleGuard(
                  requiredRole: Role.manager,
                  allowedRoles: {Role.manager, Role.supervisor},
                  child: PagePermissionGuard(
                    route: PagePermissionRoutes.manageEvents,
                    child: const ManageEvents(),
                  ),
                ),
            '/loyalty': (context) => RoleGuard(
                  requiredRole: Role.manager,
                  allowedRoles: {Role.manager, Role.supervisor},
                  child: PagePermissionGuard(
                    route: PagePermissionRoutes.loyalty,
                    child: const ManageLoyaltyRewards(),
                  ),
                ),
            '/menu': (context) => RoleGuard(
                  requiredRole: Role.manager,
                  allowedRoles: {Role.manager},
                  child: PagePermissionGuard(
                    route: PagePermissionRoutes.menu,
                    child: const Menu(),
                  ),
                ),
            '/reports': (context) => RoleGuard(
                  requiredRole: Role.manager,
                  allowedRoles: {Role.manager},
                  child: PagePermissionGuard(
                    route: PagePermissionRoutes.reports,
                    child: const Reports(),
                  ),
                ),
            '/transactions': (context) => RoleGuard(
                  requiredRole: Role.manager,
                  allowedRoles: {Role.manager, Role.supervisor},
                  child: PagePermissionGuard(
                    route: PagePermissionRoutes.transactions,
                    child: const Transactions(),
                  ),
                ),
            '/archive': (context) => RoleGuard(
                  requiredRole: Role.manager,
                  allowedRoles: {Role.manager, Role.superAdmin},
                  child: PagePermissionGuard(
                    route: PagePermissionRoutes.archive,
                    child: Archive(),
                  ),
                ),
            '/website': (context) => RoleGuard(
                  requiredRole: Role.manager,
                  allowedRoles: {
                    Role.manager,
                    Role.supervisor,
                    Role.superAdmin,
                  },
                  child: PagePermissionGuard(
                    route: PagePermissionRoutes.website,
                    child: Builder(
                      builder: (context) {
                        final role = AuthSession.instance.currentUser.value?.role;
                        final canEdit =
                            role == Role.manager || role == Role.superAdmin;
                        return CustomerWebsiteScreen(
                          contentEditable: canEdit,
                          showStaffChrome: true,
                        );
                      },
                    ),
                  ),
                ),
            '/': (context) => const Placeholder(title: 'Curatering'),
            '/settings': (context) => RoleGuard(
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


