import 'package:flutter/material.dart';

import '../config/site_routes.dart';
import 'customer_pages_top_bar.dart';

/// Side navigation used on My Orders / My Caterings / Order Tracking / Profile.
class CustomerAccountShell extends StatelessWidget {
  const CustomerAccountShell({
    super.key,
    required this.currentTab,
    required this.body,
  });

  final CustomerPageTab currentTab;
  final Widget body;

  void _open(BuildContext context, CustomerPageTab tab) {
    if (tab == currentTab) return;
    if (tab == CustomerPageTab.home) {
      Navigator.of(context).pushNamedAndRemoveUntil(
        customerRoute('/'),
        (_) => false,
      );
      return;
    }
    final String route = switch (tab) {
      CustomerPageTab.profile => '/my-profile',
      CustomerPageTab.orders => '/my-orders',
      CustomerPageTab.caterings => '/my-inquiries',
      CustomerPageTab.tracking => '/my-tracking',
      CustomerPageTab.home => '/',
    };
    Navigator.of(context).pushReplacementNamed(customerRoute(route));
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    if (!wide) {
      return Column(
        children: [
          CustomerPagesTopBar(
            currentTab: currentTab,
            onTabSelected: (tab) => _open(context, tab),
          ),
          Expanded(child: body),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 220,
          child: Material(
            color: const Color(0xFF1E1E1E),
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
              children: [
                _navTile(context, Icons.home_outlined, 'Home', CustomerPageTab.home),
                _navTile(context, Icons.person_outline, 'My Profile', CustomerPageTab.profile),
                _navTile(context, Icons.receipt_long_outlined, 'My Orders', CustomerPageTab.orders),
                _navTile(context, Icons.event_outlined, 'My Caterings', CustomerPageTab.caterings),
                _navTile(context, Icons.local_shipping_outlined, 'Order Tracking', CustomerPageTab.tracking),
              ],
            ),
          ),
        ),
        Expanded(child: body),
      ],
    );
  }

  Widget _navTile(
    BuildContext context,
    IconData icon,
    String label,
    CustomerPageTab tab,
  ) {
    final selected = currentTab == tab;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected ? const Color(0xFFFFC024) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: ListTile(
          dense: true,
          leading: Icon(
            icon,
            color: selected ? const Color(0xFF1E1E1E) : Colors.white,
          ),
          title: Text(
            label,
            style: TextStyle(
              color: selected ? const Color(0xFF1E1E1E) : Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          onTap: () => _open(context, tab),
        ),
      ),
    );
  }
}
