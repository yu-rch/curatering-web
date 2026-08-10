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

  Widget _modeSwitcher({bool onDarkAppBar = false}) {
    final button = SegmentedButton<bool>(
      style: SegmentedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      segments: const [
        ButtonSegment(value: false, label: Text('Manager view')),
        ButtonSegment(value: true, label: Text('Cashier POS')),
      ],
      selected: {_showPos},
      onSelectionChanged: (value) {
        setState(() => _showPos = value.first);
      },
    );
    if (!onDarkAppBar) return button;
    return Theme(
      data: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFF5C518),
          brightness: Brightness.dark,
        ),
      ),
      child: button,
    );
  }

  @override
  Widget build(BuildContext context) {
    final role = AuthSession.instance.currentRole;
    if (role == Role.cashier) {
      return const CashierPosShell();
    }

    // POS already has its own AppBar — skip the outer "Restaurant Orders"
    // header to avoid double chrome. Mode switch lives in the POS AppBar.
    if (_showPos) {
      return CashierPosShell(appBarTrailing: _modeSwitcher(onDarkAppBar: true));
    }

    return AppScaffold(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < 560;
                if (narrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Restaurant Orders',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: _modeSwitcher(),
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    const Text(
                      'Restaurant Orders',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    _modeSwitcher(),
                  ],
                );
              },
            ),
          ),
          const Expanded(child: RestaurantTransactionsPage()),
        ],
      ),
    );
  }
}
