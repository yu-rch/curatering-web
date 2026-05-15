import 'package:flutter/material.dart';

class AppScaffold1 extends StatelessWidget {
  final Widget child;
  final TextEditingController? searchController;
  final bool showSearch;
  final ValueChanged<String>? onSearchChanged;

  const AppScaffold1({
    super.key,
    required this.child,
    this.searchController,
    this.showSearch = false,
    this.onSearchChanged,
  });

  static const _sidebarItems = <_SidebarItemData>[
    _SidebarItemData(
      icon: Icons.dashboard,
      label: 'Liveboards',
      route: '/dashboard',
    ),
    _SidebarItemData(
      icon: Icons.event,
      label: 'Manage Events',
      route: '/manage-events',
    ),
    _SidebarItemData(
      icon: Icons.loyalty,
      label: 'Loyalty Rewards',
      route: '/loyalty',
    ),
    _SidebarItemData(
      icon: Icons.swap_horiz,
      label: 'Order History',
      route: '/order-history',
    ),
    _SidebarItemData(
      icon: Icons.menu_book,
      label: 'Catering/Restaurant Menu',
      route: '/catering-restaurant-menu',
    ),
    _SidebarItemData(
      icon: Icons.bar_chart,
      label: 'Reports',
      route: '/reports',
    ),
    _SidebarItemData(icon: Icons.archive, label: 'Archive', route: '/archive'),
    _SidebarItemData(icon: Icons.public, label: 'Website', route: '/website'),
  ];

  static Widget _buildSidebarItem(
    BuildContext context,
    IconData icon,
    String label,
    String route,
  ) {
    final currentRoute = ModalRoute.of(context)?.settings.name;
    final isActive = currentRoute == route;

    return InkWell(
      onTap: () {
        if (currentRoute != route) {
          Navigator.of(context).pushReplacementNamed(route);
        }
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFFFC024) : Colors.transparent,
          // borderRadius: BorderRadius.circular(6),
        ),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        child: Row(
          children: [
            Icon(
              icon,
              color: isActive ? const Color(0xFF1E1E1E) : const Color(0xFFF5F7F9),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isActive ? const Color(0xFF1E1E1E) : const Color(0xFFF5F7F9),
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppTitle() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          label: 'CURATERING',
          child: Image.asset('lib/assets/main.png', height: 32, fit: BoxFit.contain),
        ),
        const SizedBox(width: 12),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F3),
      body: Column(
        children: [
          // top bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            color: const Color(0xFF111111),
            child: Row(
              children: [
                _buildAppTitle(),
                const SizedBox(width: 32),
                if (showSearch)
                  Expanded(
                    child: TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        prefixIcon: const Icon(Icons.search),
                        hintText: 'Search',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 0,
                          horizontal: 12,
                        ),
                      ),
                      onChanged: onSearchChanged,
                    ),
                  ),
                if (showSearch) const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.tune, size: 18, color: Colors.black87),
                      SizedBox(width: 8),
                      Text('Filter', style: TextStyle(color: Colors.black87)),
                    ],
                  ),
                ),
                const Spacer(),
                Image.asset(
                  'lib/assets/main-2.png',
                  height: 28,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 18),
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.white,
                  backgroundImage: const AssetImage(
                    'lib/assets/profileicon 1.png',
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'HANNAH DREX',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          // content area
          Expanded(
            child: SafeArea(
              top: false,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 960;

                  Widget sidebar = Container(
                    width: 220,
                    color: const Color(0xFF0F0F0F),
                    padding: const EdgeInsets.symmetric(
                      vertical: 22,
                      horizontal: 16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 10),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              children: [
                                ..._sidebarItems.map((item) {
                                  return _buildSidebarItem(
                                    context,
                                    item.icon,
                                    item.label,
                                    item.route,
                                  );
                                }),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );

                  Widget mainContent = child;

                  if (isNarrow) {
                    return Column(
                      children: [
                        sidebar,
                        Expanded(child: mainContent),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      sidebar,
                      Expanded(child: mainContent),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarItemData {
  final IconData icon;
  final String label;
  final String route;

  const _SidebarItemData({
    required this.icon,
    required this.label,
    required this.route,
  });
}
