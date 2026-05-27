import 'package:flutter/material.dart';

import '../auth/auth_session.dart';
import '../auth/roles.dart';
import '../widgets/app_scaffold.dart';
import 'cashier_pos_shell.dart';
import 'restaurant_transactions_page.dart';

/// Cashiers get POS shell; managers/supervisors can switch between orders and POS.
class RestaurantOrdersRoute extends StatefulWidget {
  const RestaurantOrdersRoute({super.key});

  @override
  State<RestaurantOrdersRoute> createState() => _RestaurantOrdersRouteState();
}

class _RestaurantOrdersRouteState extends State<RestaurantOrdersRoute> {
  bool _showPos = false;

  @override
  Widget build(BuildContext context) {
    final role = AuthSession.instance.currentRole;
    if (role == Role.cashier) {
      return const CashierPosShell();
    }
    return AppScaffold(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                const Text(
                  'Restaurant Orders',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('Manager view')),
                    ButtonSegment(value: true, label: Text('Cashier POS')),
                  ],
                  selected: {_showPos},
                  onSelectionChanged: (value) {
                    setState(() => _showPos = value.first);
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child:
                _showPos
                    ? const CashierPosShell()
                    : const RestaurantTransactionsPage(),
          ),
        ],
      ),
    );
  }
}
