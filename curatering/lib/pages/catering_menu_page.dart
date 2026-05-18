import 'dart:convert';

import 'package:flutter/material.dart';
import '../theme/website_header_font.dart';

import '../models/menu_dish.dart';
import '../services/meal_types_store.dart';
import '../services/menu_store.dart';
import '../widgets/catering_dish_info_dialog.dart';
import '../widgets/customer_website_topbar.dart';

// Font constants
const String _primaryFont = 'Inter';

//Responsive Helpers
bool isMobile(BuildContext context) => MediaQuery.of(context).size.width < 700;

bool isTablet(BuildContext context) =>
    MediaQuery.of(context).size.width >= 700 &&
    MediaQuery.of(context).size.width < 1100;

bool isDesktop(BuildContext context) =>
    MediaQuery.of(context).size.width >= 1100;

EdgeInsets websitePagePadding(BuildContext context, {double vertical = 24}) {
  final horizontal =
      isDesktop(context)
          ? 40.0
          : isTablet(context)
          ? 24.0
          : 16.0;
  return EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical);
}

class CateringMenuPage extends StatefulWidget {
  const CateringMenuPage({
    super.key,
    this.contentEditable = false,
    this.showStaffChrome = true,
  });

  final bool contentEditable;
  final bool showStaffChrome;

  @override
  State<CateringMenuPage> createState() => _CateringMenuPageState();
}

class _CateringMenuPageState extends State<CateringMenuPage> {
  String _mealTypeFilter = '';
  List<String> _mealTypes = const [];

  @override
  void initState() {
    super.initState();
    MenuStore.instance.addListener(_onMenuChanged);
    _loadMealTypes();
    if (MenuStore.instance.activeDishes.isEmpty && !MenuStore.instance.isLoading) {
      MenuStore.instance.loadDishes();
    }
  }

  @override
  void dispose() {
    MenuStore.instance.removeListener(_onMenuChanged);
    super.dispose();
  }

  void _onMenuChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadMealTypes() async {
    final types = await MealTypesStore.instance.load();
    if (!mounted) return;
    setState(() => _mealTypes = types);
  }

  Widget _withHomepageTopBar(BuildContext context, {required Widget child}) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CustomerWebsiteTopBar(
            showCartAndCustomerAuth: !widget.contentEditable,
          ),
          Expanded(child: child),
        ],
      ),
    );
  }

  List<MenuDish> _filteredCateringDishes(List<MenuDish> dishes) {
    if (_mealTypeFilter.isEmpty) return dishes;
    return dishes
        .where(
          (d) =>
              d.mealType.trim().toLowerCase() ==
              _mealTypeFilter.toLowerCase(),
        )
        .toList();
  }

  Widget _mealTypeChips() {
    final types = <String>{
      ..._mealTypes,
      for (final d in MenuStore.instance.activeDishes.where(
        (x) => x.category == 'catering' && x.mealType.trim().isNotEmpty,
      ))
        d.mealType.trim(),
    }.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    if (types.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        FilterChip(
          label: const Text('All'),
          selected: _mealTypeFilter.isEmpty,
          onSelected: (_) => setState(() => _mealTypeFilter = ''),
          selectedColor: const Color(0xFFFFC024),
        ),
        for (final t in types)
          FilterChip(
            label: Text(t),
            selected: _mealTypeFilter == t,
            onSelected: (_) => setState(() => _mealTypeFilter = t),
            selectedColor: const Color(0xFFFFC024),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final allDishes = MenuStore.instance.activeDishes;
    final cateringDishes =
        allDishes.where((d) => d.category == 'catering').toList();
    final visibleDishes = _filteredCateringDishes(cateringDishes);

    // Show loading state if dishes are empty or currently loading
    if (MenuStore.instance.isLoading || allDishes.isEmpty) {
      return _withHomepageTopBar(
        context,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 60,
                height: 60,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Loading our delicious menu...',
                style: GoogleFonts.getFont(
                  _primaryFont,
                  fontSize: 16,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Show error state
    if (MenuStore.instance.error != null) {
      return _withHomepageTopBar(
        context,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red.shade400,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Oops, there was an error loading the website.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.getFont(
                    _primaryFont,
                    fontSize: 18,
                    color: Colors.grey.shade800,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Try reloading the page.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.getFont(
                    _primaryFont,
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 32),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.amber[600]!, Colors.amber[800]!],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.amber.shade200,
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: () => MenuStore.instance.loadDishes(),
                    icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                    label: Text(
                      'Reload Page',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return _withHomepageTopBar(
      context,
      child: SingleChildScrollView(
        padding: websitePagePadding(context),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 24),
                Text(
                  'CATERING MENU',
                  textAlign: TextAlign.center,
                  style: websiteHeaderStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E1E1E),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Color(0xFFFFC024),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Explore Our Catering Offerings',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E1E1E),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _mealTypeChips(),
                const SizedBox(height: 24),
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (visibleDishes.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(32),
                            child: Center(
                              child: Text(
                                _mealTypeFilter.isEmpty
                                    ? 'No dishes available'
                                    : 'No dishes in "$_mealTypeFilter"',
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          )
                        else
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount:
                                      isMobile(context)
                                          ? 2
                                          : isTablet(context)
                                          ? 3
                                          : 5,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: 0.8,
                                ),
                            itemCount: visibleDishes.length,
                            itemBuilder: (ctx, i) {
                              final d = visibleDishes[i];
                              return Card(
                                clipBehavior: Clip.antiAlias,
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: InkWell(
                                  onTap:
                                      () => showCateringDishInfoDialog(
                                        context,
                                        d,
                                      ),
                                  child: Column(
                                    children: [
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius:
                                              const BorderRadius.vertical(
                                                top: Radius.circular(8),
                                              ),
                                          child:
                                              d.imageBase64 != null &&
                                                      d.imageBase64!.isNotEmpty
                                                  ? Image.memory(
                                                    base64Decode(
                                                      d.imageBase64!,
                                                    ),
                                                    fit: BoxFit.cover,
                                                    width: double.infinity,
                                                  )
                                                  : Container(
                                                    color:
                                                        Colors.grey.shade200,
                                                    child: const Icon(
                                                      Icons.fastfood,
                                                      size: 48,
                                                    ),
                                                  ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              d.name.toUpperCase(),
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 12,
                                              ),
                                            ),
                                            if (d.mealType.trim().isNotEmpty)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  top: 4,
                                                ),
                                                child: Text(
                                                  d.mealType,
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
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
}
