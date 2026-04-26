import 'package:flutter/material.dart';

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
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _tabButton('Home', CustomerPageTab.home, Icons.home_outlined),
          _tabButton('My Profile', CustomerPageTab.profile, Icons.person_outline),
          _tabButton('My Orders', CustomerPageTab.orders, Icons.receipt_long_outlined),
          _tabButton('My Caterings', CustomerPageTab.caterings, Icons.event_outlined),
          _tabButton('Order Tracking', CustomerPageTab.tracking, Icons.local_shipping_outlined),
        ],
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
          children: [
            Icon(icon, size: 16, color: const Color(0xFF1E1E1E)),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF1E1E1E),
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
