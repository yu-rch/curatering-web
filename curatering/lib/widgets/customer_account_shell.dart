import 'package:flutter/material.dart';

import '../config/site_routes.dart';
import 'customer_pages_top_bar.dart';

/// Side navigation used on My Orders / My Caterings / Order Tracking / Profile.
class CustomerAccountShell extends StatelessWidget {
  const CustomerAccountShell({
    super.key,
    required this.currentTab,
    required this.body,
    this.trackingRoute = '/my-tracking',
    this.guestTrackingMode = false,
    this.guestTrackingSection = GuestTrackingSection.inquiries,
    this.onGuestTrackingSection,
  });

  final CustomerPageTab currentTab;
  final Widget body;

  /// Guests use `/track-order`; signed-in customers use `/my-tracking`.
  final String trackingRoute;

  /// When true (guest track-order), sidebar only shows Inquiries + Restaurant.
  final bool guestTrackingMode;
  final GuestTrackingSection guestTrackingSection;
  final ValueChanged<GuestTrackingSection>? onGuestTrackingSection;

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
      CustomerPageTab.tracking => trackingRoute,
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
          if (guestTrackingMode)
            _GuestTrackingTopBar(
              section: guestTrackingSection,
              onSection: onGuestTrackingSection,
            )
          else
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
              children:
                  guestTrackingMode
                      ? [
                        _guestNavTile(
                          Icons.event_note_outlined,
                          'Inquiries',
                          GuestTrackingSection.inquiries,
                        ),
                        _guestNavTile(
                          Icons.restaurant_menu_outlined,
                          'Restaurant orders',
                          GuestTrackingSection.restaurant,
                        ),
                      ]
                      : [
                        _navTile(
                          context,
                          Icons.home_outlined,
                          'Home',
                          CustomerPageTab.home,
                        ),
                        _navTile(
                          context,
                          Icons.person_outline,
                          'My Profile',
                          CustomerPageTab.profile,
                        ),
                        _navTile(
                          context,
                          Icons.receipt_long_outlined,
                          'My Orders',
                          CustomerPageTab.orders,
                        ),
                        _navTile(
                          context,
                          Icons.event_outlined,
                          'My Caterings',
                          CustomerPageTab.caterings,
                        ),
                        _navTile(
                          context,
                          Icons.local_shipping_outlined,
                          'Order Tracking',
                          CustomerPageTab.tracking,
                        ),
                      ],
            ),
          ),
        ),
        Expanded(child: body),
      ],
    );
  }

  Widget _guestNavTile(
    IconData icon,
    String label,
    GuestTrackingSection section,
  ) {
    final selected = guestTrackingSection == section;
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
          onTap: () => onGuestTrackingSection?.call(section),
        ),
      ),
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

enum GuestTrackingSection { inquiries, restaurant }

class _GuestTrackingTopBar extends StatelessWidget {
  const _GuestTrackingTopBar({
    required this.section,
    required this.onSection,
  });

  final GuestTrackingSection section;
  final ValueChanged<GuestTrackingSection>? onSection;

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, GuestTrackingSection value, IconData icon) {
      final selected = section == value;
      return Expanded(
        child: Material(
          color: selected ? const Color(0xFFFFC024) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => onSection?.call(value),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: selected
                        ? const Color(0xFF1E1E1E)
                        : Colors.grey.shade700,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: selected
                            ? const Color(0xFF1E1E1E)
                            : Colors.grey.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          chip('Inquiries', GuestTrackingSection.inquiries, Icons.event_note_outlined),
          const SizedBox(width: 8),
          chip(
            'Restaurant orders',
            GuestTrackingSection.restaurant,
            Icons.restaurant_menu_outlined,
          ),
        ],
      ),
    );
  }
}
