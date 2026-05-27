import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'customer_website.dart';
import 'my_profile_page.dart';
import 'my_orders_page.dart';
import 'my_inquiries_page.dart';
import 'my_order_tracking_page.dart';

enum CustomerAccountTab { profile, orders, inquiries, tracking }

class CustomerAccountShell extends StatefulWidget {
  const CustomerAccountShell({
    super.key,
    this.initialTab = CustomerAccountTab.profile,
  });

  final CustomerAccountTab initialTab;

  @override
  State<CustomerAccountShell> createState() => _CustomerAccountShellState();
}

class _CustomerAccountShellState extends State<CustomerAccountShell> {
  late CustomerAccountTab _currentTab;

  static const _sidebarWidth = 220.0;
  static const _sidebarColor = Color(0xFF1E1E1E);
  static const _accent = Color(0xFFFFC024);

  @override
  void initState() {
    super.initState();
    _currentTab = widget.initialTab;
  }

  void _goHome() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const CustomerWebsiteScreen()),
    );
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('customer_token');
    await prefs.remove('customer_data');
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const CustomerWebsiteScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isNarrow = screenWidth < 700;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      drawer: isNarrow ? _buildDrawer() : null,
      body: Row(
        children: [
          if (!isNarrow) _buildSidebar(),
          if (!isNarrow)
            Container(width: 1, color: Colors.grey.shade300),
          Expanded(
            child: _buildContent(isNarrow),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(bool isNarrow) {
    Widget page = switch (_currentTab) {
      CustomerAccountTab.profile => const MyProfilePage(),
      CustomerAccountTab.orders => const MyOrdersPage(),
      CustomerAccountTab.inquiries => const MyInquiriesPage(),
      CustomerAccountTab.tracking => const MyOrderTrackingPage(),
    };

    if (isNarrow) {
      return Column(
        children: [
          _buildMobileTopBar(),
          Expanded(child: page),
        ],
      );
    }
    return page;
  }

  Widget _buildMobileTopBar() {
    return Container(
      color: _sidebarColor,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Builder(
              builder: (ctx) => IconButton(
                icon: const Icon(Icons.menu, color: Colors.white),
                onPressed: () => Scaffold.of(ctx).openDrawer(),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              _tabLabel(_currentTab),
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Drawer _buildDrawer() {
    return Drawer(
      backgroundColor: _sidebarColor,
      child: SafeArea(
        child: Column(
          children: [
            _buildSidebarHeader(),
            const SizedBox(height: 8),
            _drawerItem(
              Icons.home_outlined,
              'Home',
              onTap: () {
                Navigator.of(context).pop();
                _goHome();
              },
            ),
            _drawerItem(
              Icons.person_outline,
              'My Profile',
              active: _currentTab == CustomerAccountTab.profile,
              onTap: () {
                Navigator.of(context).pop();
                setState(() => _currentTab = CustomerAccountTab.profile);
              },
            ),
            _drawerItem(
              Icons.receipt_long_outlined,
              'My Orders',
              active: _currentTab == CustomerAccountTab.orders,
              onTap: () {
                Navigator.of(context).pop();
                setState(() => _currentTab = CustomerAccountTab.orders);
              },
            ),
            _drawerItem(
              Icons.mail_outline,
              'My Inquiries',
              active: _currentTab == CustomerAccountTab.inquiries,
              onTap: () {
                Navigator.of(context).pop();
                setState(() => _currentTab = CustomerAccountTab.inquiries);
              },
            ),
            _drawerItem(
              Icons.local_shipping_outlined,
              'Order Tracking',
              active: _currentTab == CustomerAccountTab.tracking,
              onTap: () {
                Navigator.of(context).pop();
                setState(() => _currentTab = CustomerAccountTab.tracking);
              },
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Divider(color: Colors.white24, height: 1),
            ),
            _drawerItem(
              Icons.logout,
              'Logout',
              color: Colors.red.shade400,
              onTap: () {
                Navigator.of(context).pop();
                _logout();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem(
    IconData icon,
    String label, {
    bool active = false,
    Color? color,
    VoidCallback? onTap,
  }) {
    final itemColor = color ?? (active ? _accent : Colors.white70);
    return ListTile(
      leading: Icon(icon, color: itemColor, size: 22),
      title: Text(
        label,
        style: TextStyle(
          color: itemColor,
          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          fontSize: 14,
        ),
      ),
      selected: active,
      selectedTileColor: _accent.withAlpha(30),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onTap: onTap,
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: _sidebarWidth,
      color: _sidebarColor,
      child: Column(
        children: [
          _buildSidebarHeader(),
          const SizedBox(height: 8),
          _sidebarItem(
            icon: Icons.home_outlined,
            label: 'Home',
            onTap: _goHome,
          ),
          _sidebarItem(
            icon: Icons.person_outline,
            label: 'My Profile',
            active: _currentTab == CustomerAccountTab.profile,
            onTap: () => setState(() => _currentTab = CustomerAccountTab.profile),
          ),
          _sidebarItem(
            icon: Icons.receipt_long_outlined,
            label: 'My Orders',
            active: _currentTab == CustomerAccountTab.orders,
            onTap: () => setState(() => _currentTab = CustomerAccountTab.orders),
          ),
          _sidebarItem(
            icon: Icons.mail_outline,
            label: 'My Inquiries',
            active: _currentTab == CustomerAccountTab.inquiries,
            onTap: () => setState(() => _currentTab = CustomerAccountTab.inquiries),
          ),
          _sidebarItem(
            icon: Icons.local_shipping_outlined,
            label: 'Order Tracking',
            active: _currentTab == CustomerAccountTab.tracking,
            onTap: () => setState(() => _currentTab = CustomerAccountTab.tracking),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Divider(color: Colors.white24, height: 1),
          ),
          const SizedBox(height: 8),
          _sidebarItem(
            icon: Icons.logout,
            label: 'Logout',
            color: Colors.red.shade400,
            onTap: _logout,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSidebarHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _accent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.person, color: Color(0xFF1E1E1E), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'My Account',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sidebarItem({
    required IconData icon,
    required String label,
    bool active = false,
    Color? color,
    VoidCallback? onTap,
  }) {
    final itemColor = color ?? (active ? _accent : Colors.white70);

    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: active ? _accent.withAlpha(30) : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: active ? _accent : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: itemColor, size: 20),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: itemColor,
                fontSize: 13,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _tabLabel(CustomerAccountTab tab) {
    return switch (tab) {
      CustomerAccountTab.profile => 'My Profile',
      CustomerAccountTab.orders => 'My Orders',
      CustomerAccountTab.inquiries => 'My Inquiries',
      CustomerAccountTab.tracking => 'Order Tracking',
    };
  }
}
