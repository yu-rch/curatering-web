import 'package:flutter/material.dart';

import '../../models/customer_state.dart';
import '../../widgets/side_tab_navigation.dart';
import 'my_profile_screen.dart';
import 'restaurant_tab.dart';
import 'inquiry_wizard_screen.dart';
import 'my_orders_screen.dart';
import 'tray_screen.dart';

class CustomerShell extends StatefulWidget {
  final CustomerState state;

  const CustomerShell({super.key, required this.state});

  @override
  State<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends State<CustomerShell> {
  int _selectedIndex = 0;

  void _onDestinationSelected(int index) {
    setState(() => _selectedIndex = index);
  }

  void _openTray() {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 680),
          child: TrayScreen(state: widget.state),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return RestaurantTab(state: widget.state);
      case 1:
        return InquiryWizardScreen(state: widget.state);
      case 2:
        return MyOrdersScreen(state: widget.state);
      case 3:
        return const _InquiriesPlaceholder();
      case 4:
        return MyProfileScreen(state: widget.state);
      default:
        return RestaurantTab(state: widget.state);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SideTabNavigation(
          selectedIndex: _selectedIndex,
          onDestinationSelected: _onDestinationSelected,
          headerWidget: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Row(
              children: [
                Icon(Icons.restaurant_menu,
                    color: Theme.of(context).colorScheme.primary, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Macrina's Kitchen\n& Catering",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                          height: 1.2,
                        ),
                  ),
                ),
              ],
            ),
          ),
          destinations: const [
            SideTabDestination(
              label: 'Restaurant',
              icon: Icons.restaurant,
              selectedIcon: Icons.restaurant,
            ),
            SideTabDestination(
              label: 'Inquire Now',
              icon: Icons.event,
              selectedIcon: Icons.event,
            ),
            // separator handled visually — indices shift
            SideTabDestination(
              label: 'My Orders',
              icon: Icons.receipt_long,
              selectedIcon: Icons.receipt_long,
            ),
            SideTabDestination(
              label: 'My Inquiries',
              icon: Icons.event_note,
              selectedIcon: Icons.event_note,
            ),
            SideTabDestination(
              label: 'My Profile',
              icon: Icons.person,
              selectedIcon: Icons.person,
            ),
          ],
          body: _buildBody(),
        ),
        Positioned(
          right: 24,
          bottom: 24,
          child: ListenableBuilder(
            listenable: widget.state,
            builder: (context, _) {
              final count = widget.state.trayItemCount;
              return FloatingActionButton.extended(
                heroTag: 'tray_fab',
                onPressed: _openTray,
                icon: Badge(
                  isLabelVisible: count > 0,
                  label: Text('$count'),
                  child: const Icon(Icons.shopping_basket),
                ),
                label: Text(count > 0 ? 'Tray ($count)' : 'Tray'),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _InquiriesPlaceholder extends StatelessWidget {
  const _InquiriesPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.event_note, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('My Inquiries', style: TextStyle(fontSize: 18)),
          SizedBox(height: 8),
          Text('Coming soon', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

