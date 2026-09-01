import 'dart:async';

import 'package:flutter/material.dart';
import '../theme/customer_fonts.dart';

import '../models/menu_dish.dart';
import '../constants/catering_meal_types.dart';
import '../services/menu_store.dart';
import '../services/set_menu_store.dart';
import '../services/website_content_store.dart';
import '../utils/image_cache.dart';
import '../widgets/catering_dish_info_dialog.dart';
import '../widgets/customer_site_footer.dart';
import '../widgets/customer_website_topbar.dart';
import '../widgets/customer_antd_page_hero.dart';

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
  String _setMenuFilterId = '';

  @override
  void initState() {
    super.initState();
    MenuStore.instance.addListener(_onMenuChanged);
    SetMenuStore.instance.addListener(_onMenuChanged);
    WebsiteContentStore.instance.addListener(_onMenuChanged);
    unawaited(WebsiteContentStore.instance.ensureLoaded());
    unawaited(MenuStore.instance.ensureImagesLoaded());
    SetMenuStore.instance.loadSetMenus();
  }

  @override
  void dispose() {
    MenuStore.instance.removeListener(_onMenuChanged);
    SetMenuStore.instance.removeListener(_onMenuChanged);
    WebsiteContentStore.instance.removeListener(_onMenuChanged);
    super.dispose();
  }

  void _onMenuChanged() {
    if (mounted) setState(() {});
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
    var filtered = dishes;
    if (_setMenuFilterId.isNotEmpty) {
      SetMenu? selectedSet;
      for (final set in SetMenuStore.instance.activeSetMenus) {
        if (set.id == _setMenuFilterId) {
          selectedSet = set;
          break;
        }
      }
      final dishIds = selectedSet?.dishIds.toSet() ?? const <String>{};
      filtered = filtered.where((dish) => dishIds.contains(dish.id)).toList();
    }
    if (_mealTypeFilter.isEmpty) return filtered;
    return filtered
        .where(
          (d) => cateringMealTypeMatches(d.effectiveMealType, _mealTypeFilter),
        )
        .toList();
  }

  Widget _setMenuDropdown(List<SetMenu> setMenus) {
    if (setMenus.isEmpty) return const SizedBox.shrink();
    final validValue =
        setMenus.any((set) => set.id == _setMenuFilterId)
            ? _setMenuFilterId
            : '';
    if (validValue != _setMenuFilterId) {
      _setMenuFilterId = validValue;
    }
    return SizedBox(
      width: 280,
      child: DropdownButtonFormField<String>(
        value: validValue,
        isExpanded: true,
        isDense: true,
        decoration: InputDecoration(
          labelText: 'Filter by set menu',
          filled: true,
          fillColor: Colors.white,
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 8,
          ),
        ),
        items: [
          const DropdownMenuItem(value: '', child: Text('All set menus')),
          for (final set in setMenus)
            DropdownMenuItem(value: set.id, child: Text(set.name)),
        ],
        onChanged: (value) => setState(() => _setMenuFilterId = value ?? ''),
      ),
    );
  }

  Widget _mealTypeChips() {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      alignment: WrapAlignment.center,
      children: [
        FilterChip(
          label: const Text('All', style: TextStyle(fontSize: 12)),
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          selected: _mealTypeFilter.trim().isEmpty,
          onSelected: (_) => setState(() => _mealTypeFilter = ''),
          selectedColor: const Color(0xFFFFC024),
        ),
        for (final t in kCateringMealTypes)
          FilterChip(
            label: Text(
              mealTypeDisplayLabel(t),
              style: const TextStyle(fontSize: 12),
            ),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            selected:
                cateringMealTypeMatches(_mealTypeFilter, t) &&
                _mealTypeFilter.trim().isNotEmpty,
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
    final setMenus = SetMenuStore.instance.activeSetMenus;
    final visibleDishes = _filteredCateringDishes(cateringDishes);

    // Show loading state while menu is fetching
    if (MenuStore.instance.isLoading) {
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
                style: CustomerFonts.getFont(
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
                  style: CustomerFonts.getFont(
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
                  style: CustomerFonts.getFont(
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
                    icon: const Icon(
                      Icons.refresh_rounded,
                      color: Colors.white,
                    ),
                    label: Text(
                      'Reload Page',
                      style: CustomerFonts.inter(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: const Color(0xFFF5F5F5),
            elevation: 1,
            child: Padding(
              padding: websitePagePadding(context, vertical: 12),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CustomerAntdPageHero(
                        title: WebsiteContentStore.instance.cateringPageTitle,
                        subtitle:
                            WebsiteContentStore.instance.cateringPageSubtitle,
                        filters: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _setMenuDropdown(setMenus),
                            _mealTypeChips(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: websitePagePadding(context, vertical: 16),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1200),
                        child: Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(24),
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
                                  _dishGrid(context, visibleDishes),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  CustomerSiteFooter(
                    store: WebsiteContentStore.instance,
                    contentEditable: widget.contentEditable,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dishGrid(BuildContext context, List<MenuDish> dishes) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
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
      itemCount: dishes.length,
      itemBuilder: (ctx, i) {
        final d = dishes[i];
        return Card(
          clipBehavior: Clip.antiAlias,
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: InkWell(
            onTap: () => showCateringDishInfoDialog(context, d),
            child: Column(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(8),
                    ),
                    child:
                        d.imageBase64 != null && d.imageBase64!.isNotEmpty
                            ? CachedBase64Image(
                              base64String: d.imageBase64,
                              fit: BoxFit.cover,
                              width: double.infinity,
                            )
                            : Container(
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.fastfood, size: 48),
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
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
