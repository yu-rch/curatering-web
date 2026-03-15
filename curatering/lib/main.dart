import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'pages/login_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/manage_accounts_page.dart';
import 'pages/catering_page.dart';
import 'pages/live_performance_page.dart';
import 'pages/loyalty_rewards_page.dart';
import 'pages/archive_page.dart';
import 'pages/menu_page.dart';
import 'pages/reports_page.dart';
import 'pages/transactions_page.dart';
import 'pages/settings_page.dart';
import 'pages/placeholder_page.dart';
import 'data_store.dart';

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
            '/login': (context) => const LoginPage(),
            '/dashboard': (context) => const DashboardPage(),
            '/manage-events': (context) => const ManageEventsPage(),
            '/live-performance': (context) => const LivePerformancePage(),
            '/manage-accounts': (context) => const ManageAccountsPage(),
            '/loyalty': (context) => const LoyaltyRewardsPage(),
            '/menu': (context) => const MenuPage(),
            '/reports': (context) => const ReportsPage(),
            '/transactions': (context) => const TransactionsPage(),
            '/archive': (context) => ArchivePage(),
            '/': (context) => const PlaceholderPage(title: 'Curatering'),
            '/settings': (context) => const SettingsPage(),
          },
        );
      },
    );
  }
}


