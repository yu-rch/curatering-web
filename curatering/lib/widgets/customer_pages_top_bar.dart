import 'package:flutter/material.dart';

import '../utils/responsive_layout.dart';

enum CustomerPageTab { home, profile, orders, caterings, tracking }

class CustomerPagesTopBar extends StatelessWidget {
  const CustomerPagesTopBar({
    super.key,
    required this.currentTab,
    required this.onTabSelected,
  });

  final CustomerPageTab currentTab;
  final ValueChanged<CustomerPageTab> onTabSelected;

  @override
  Widget build(BuildContext context) {
    final mobile = isMobileWidth(context);
    final tabs = <({String label, CustomerPageTab tab, IconData icon})>[
      (label: mobile ? 'Home' : 'Home', tab: CustomerPageTab.home, icon: Icons.home_outlined),
      (label: mobile ? 'Profile' : 'My Profile', tab: CustomerPageTab.profile, icon: Icons.person_outline),
      (label: mobile ? 'Orders' : 'My Orders', tab: CustomerPageTab.orders, icon: Icons.receipt_long_outlined),
      (label: mobile ? 'Caterings' : 'My Caterings', tab: CustomerPageTab.caterings, icon: Icons.event_outlined),
      (label: mobile ? 'Tracking' : 'Order Tracking', tab: CustomerPageTab.tracking, icon: Icons.local_shipping_outlined),
    ];

    final tabButtons = tabs
        .map((t) => _tabButton(t.label, t.tab, t.icon))
        .toList();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: mobile
          ? SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: tabButtons),
            )
          : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tabButtons,
            ),
    );
  }

  Widget _tabButton(String label, CustomerPageTab tab, IconData icon) {
    final selected = currentTab == tab;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: selected ? null : () => onTabSelected(tab),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: selected ? const Color(0xFFFFC024) : const Color(0xFFF4F5F7),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? Colors.white : const Color(0xFF1E1E1E),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : const Color(0xFF1E1E1E),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
