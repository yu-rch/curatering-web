import 'package:flutter/material.dart' hide Placeholder;
import 'package:google_fonts/google_fonts.dart';
import 'pages/login.dart';
import 'pages/dashboard.dart';
import 'pages/manage_accounts.dart';
import 'pages/catering.dart';
import 'pages/live_performance.dart';
import 'pages/loyalty_rewards.dart';
import 'pages/archive.dart';
import 'pages/menu.dart';
import 'pages/reports.dart';
import 'pages/transactions.dart';
import 'pages/settings.dart';
import 'pages/placeholder.dart';
import 'data_store.dart';
import 'auth/role_guard.dart';
import 'auth/roles.dart';
import 'pages/help_requests.dart';
import 'pages/action_logs.dart';

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
          initialRoute: '/login',
          routes: {
            '/login': (context) => const Login(),
            '/dashboard': (context) => const Dashboard(),
            '/live-performance': (context) => const LivePerformance(),
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
            '/manage-events': (context) => const RoleGuard(
                  requiredRole: Role.manager,
                  allowedRoles: {Role.manager, Role.supervisor},
                  child: ManageEvents(),
                ),
            '/loyalty': (context) => const RoleGuard(
                  requiredRole: Role.manager,
                  allowedRoles: {Role.manager, Role.supervisor},
                  child: LoyaltyRewards(),
                ),
            '/menu': (context) => const RoleGuard(
                  requiredRole: Role.manager,
                  allowedRoles: {Role.manager},
                  child: Menu(),
                ),
            '/reports': (context) => const RoleGuard(
                  requiredRole: Role.manager,
                  allowedRoles: {Role.manager},
                  child: Reports(),
                ),
            '/transactions': (context) => const RoleGuard(
                  requiredRole: Role.manager,
                  allowedRoles: {Role.manager, Role.supervisor},
                  child: Transactions(),
                ),
            '/archive': (context) => RoleGuard(
                  requiredRole: Role.manager,
                  allowedRoles: {Role.manager},
                  child: Archive(),
                ),
            '/': (context) => const Placeholder(title: 'Curatering'),
            '/settings': (context) => const RoleGuard(
                  requiredRole: Role.manager,
                  allowedRoles: {Role.manager},
                  child: Settings(),
                ),
          },
        );
      },
    );
  }
}


