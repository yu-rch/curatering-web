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
            '/manage-events': (context) => const ManageEvents(),
            '/live-performance': (context) => const LivePerformance(),
            '/manage-accounts': (context) => const ManageAccounts(),
            '/loyalty': (context) => const LoyaltyRewards(),
            '/menu': (context) => const Menu(),
            '/reports': (context) => const Reports(),
            '/transactions': (context) => const Transactions(),
            '/archive': (context) => Archive(),
            '/': (context) => const Placeholder(title: 'Curatering'),
            '/settings': (context) => const Settings(),
          },
        );
      },
    );
  }
}


