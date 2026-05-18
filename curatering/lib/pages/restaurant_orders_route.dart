import 'package:flutter/material.dart';

import '../auth/auth_session.dart';
import '../auth/roles.dart';
import '../widgets/app_scaffold.dart';
import 'cashier_pos_shell.dart';
import 'restaurant_transactions_page.dart';

/// Cashiers get POS shell; managers/supervisors get full restaurant orders UI.
class RestaurantOrdersRoute extends StatelessWidget {
  const RestaurantOrdersRoute({super.key});

  @override
  Widget build(BuildContext context) {
    final role = AuthSession.instance.currentRole;
    if (role == Role.cashier) {
      return const AppScaffold(child: CashierPosShell());
    }
    return const AppScaffold(child: RestaurantTransactionsPage());
  }
}
