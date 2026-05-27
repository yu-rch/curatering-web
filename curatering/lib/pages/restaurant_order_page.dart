import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/menu_store.dart';
import '../services/cart_store.dart';
import '../services/website_content_store.dart';
import '../models/menu_dish.dart';
import '../widgets/antd_message.dart';
import '../widgets/customer_website_topbar.dart';
import 'checkout_page.dart';

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

class RestaurantOrderPage extends StatefulWidget {
  const RestaurantOrderPage({
    super.key,
    this.contentEditable = false,
    this.showStaffChrome = true,
  });

  final bool contentEditable;
  final bool showStaffChrome;

  @override
  State<RestaurantOrderPage> createState() => _RestaurantOrderPageState();
}

class _RestaurantOrderPageState extends State<RestaurantOrderPage> {
  String _selectedRestaurantType = 'ALL';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  static const List<String> _defaultAddOns = [
    'Extra cheese',
    'Extra vegetables',
    'Extra meat',
    'Spicy',
    'No onions',
  ];

  @override
  void initState() {
    super.initState();
    unawaited(_initializeStores());
  }

  Future<void> _initializeStores() async {
    await WebsiteContentStore.instance.ensureLoaded();
    if (MenuStore.instance.activeDishes.isEmpty) {
      await MenuStore.instance.loadDishes();
    }
    await CartStore.instance.init();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CustomerWebsiteTopBar(
            showCartAndCustomerAuth: !widget.contentEditable,
          ),
          Expanded(
            child: Stack(
              children: [
                _buildRestaurantMenu(),
                if (isMobile(context)) _buildMobileTrayButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRestaurantMenu() {
    final content = WebsiteContentStore.instance;
    final allDishes = MenuStore.instance.activeDishes;

    // Show loading state if dishes are empty or currently loading
    if (MenuStore.instance.isLoading || allDishes.isEmpty) {
      return SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 60,
                height: 60,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.amber.shade700,
                  ),
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

    final restaurantDishes =
        allDishes.where((d) {
          final category = d.category.trim().toLowerCase();
          return category == 'restaurant';
        }).toList();

    // Filter restaurant dishes by selected meal type (menu_dishes.meal_type)
    String restaurantTypeForDish(MenuDish dish) {
      final rawType = dish.effectiveMealType.toLowerCase();
      if (rawType.isNotEmpty) return rawType;
      final category = dish.category.trim().toLowerCase();
      switch (category) {
        case 'main_course':
        case 'rice':
          return 'rice meals';
        case 'noodles':
          return 'pasta';
        case 'appetizer':
          return 'sandwiches';
        case 'dessert':
          return 'others';
        case 'drink':
        case 'drinks':
          return 'drinks';
        default:
          return 'others';
      }
    }

    final selectedType = _selectedRestaurantType.trim().toLowerCase();
    final search = _searchQuery.trim().toLowerCase();
    final dishes =
        restaurantDishes.where((d) {
          final matchesType =
              selectedType == 'all' || restaurantTypeForDish(d) == selectedType;
          if (!matchesType) return false;
          if (search.isEmpty) return true;
          return d.name.toLowerCase().contains(search) ||
              d.publicDescription.toLowerCase().contains(search) ||
              d.ingredients.any(
                (ingredient) => ingredient.toLowerCase().contains(search),
              );
        }).toList();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left side - Menu
        Expanded(
          flex: 3,
          child: Padding(
            padding: websitePagePadding(context, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  content.restaurantPageTitle,
                  style: GoogleFonts.getFont(
                    _primaryFont,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E1E1E),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  content.restaurantPageSubtitle,
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search restaurant menu',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon:
                        _searchQuery.isEmpty
                            ? null
                            : IconButton(
                              icon: const Icon(Icons.close),
                              onPressed:
                                  () => setState(() {
                                    _searchController.clear();
                                    _searchQuery = '';
                                  }),
                            ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onChanged:
                      (value) => setState(
                        () => _searchQuery = value.trim().toLowerCase(),
                      ),
                ),
                const SizedBox(height: 16),
                _buildCategoryTabs(restaurantDishes),
                const SizedBox(height: 24),
                Expanded(
                  child:
                      dishes.isEmpty
                          ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.restaurant_menu,
                                  size: 64,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No items available in this category',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          )
                          : GridView.builder(
                            padding: const EdgeInsets.only(bottom: 24),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount:
                                      isMobile(context)
                                          ? 1
                                          : isTablet(context)
                                          ? 2
                                          : 3,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                  childAspectRatio: 0.8,
                                ),
                            itemCount: dishes.length,
                            itemBuilder: (context, index) {
                              final dish = dishes[index];
                              return _buildDishCard(dish);
                            },
                          ),
                ),
              ],
            ),
          ),
        ),
        if (!isMobile(context))
          // Right side - Cart sidebar
          Expanded(
            flex: 1,
            child: Container(
              margin: const EdgeInsets.only(right: 20, top: 20, bottom: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: _buildCartSidebar(),
            ),
          ),
      ],
    );
  }

  Widget _buildMobileTrayButton() {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 16,
      child: ListenableBuilder(
        listenable: CartStore.instance,
        builder: (context, _) {
          final itemCount = CartStore.instance.itemCount;
          final total = CartStore.instance.totalAmount;
          if (itemCount <= 0) return const SizedBox.shrink();
          return SafeArea(
            top: false,
            child: ElevatedButton.icon(
              onPressed: _openCartSidebar,
              icon: const Icon(Icons.shopping_bag_outlined),
              label: Text(
                'YOUR TRAY · $itemCount ${itemCount == 1 ? 'ITEM' : 'ITEMS'} · ₱${total.toStringAsFixed(2)}',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E1E1E),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// [closeOverlay] runs before opening checkout (e.g. pop the mobile cart bottom sheet).
  Future<void> _proceedToCheckout({VoidCallback? closeOverlay}) async {
    if (CartStore.instance.items.isEmpty) {
      if (!mounted) return;
      showAntdMessage(
        context,
        'Your tray is empty',
        type: AntdMessageType.error,
      );
      return;
    }

    closeOverlay?.call();
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(milliseconds: 40));
    if (!mounted) return;

    try {
      await Navigator.of(context, rootNavigator: true).push<void>(
        MaterialPageRoute<void>(builder: (context) => const CheckoutPage()),
      );
    } catch (e, st) {
      debugPrint('RestaurantOrderPage checkout navigation failed: $e\n$st');
      if (!mounted) return;
      showAntdMessage(
        context,
        'Could not open checkout. ${e.toString()}',
        type: AntdMessageType.error,
      );
    }
  }

  Widget _buildCategoryTabs(List<MenuDish> restaurantDishes) {
    final types = <String>{};
    for (final dish in restaurantDishes) {
      final rawType = dish.effectiveMealType.toLowerCase();
      if (rawType.isNotEmpty) {
        types.add(rawType.toUpperCase());
      } else {
        final category = dish.category.trim().toLowerCase();
        switch (category) {
          case 'main_course':
          case 'rice':
            types.add('RICE MEALS');
            break;
          case 'noodles':
            types.add('PASTA');
            break;
          case 'appetizer':
            types.add('SANDWICHES');
            break;
          case 'dessert':
            types.add('OTHERS');
            break;
          case 'drink':
          case 'drinks':
            types.add('DRINKS');
            break;
          default:
            types.add('OTHERS');
            break;
        }
      }
    }

    final typeList = ['ALL', ...types.toList()];
    typeList.sort();
    typeList.remove('ALL');
    typeList.insert(0, 'ALL');

    return Container(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: typeList.length,
        itemBuilder: (context, index) {
          final type = typeList[index];
          final isSelected =
              type.toLowerCase() == _selectedRestaurantType.toLowerCase();

          return Container(
            margin: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(type),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedRestaurantType = type;
                  });
                }
              },
              backgroundColor: Colors.grey.shade200,
              selectedColor: const Color(0xFF1E1E1E),
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDishCard(MenuDish dish) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showDishDetails(dish),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  color: Colors.grey.shade200,
                ),
                clipBehavior: Clip.antiAlias,
                child:
                    dish.imageBase64?.isNotEmpty == true
                        ? Image.memory(
                          base64Decode(dish.imageBase64!),
                          fit: BoxFit.cover,
                        )
                        : Icon(
                          Icons.restaurant,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
              ),
            ),
            // Content
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dish.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '₱${double.tryParse(dish.price)?.toStringAsFixed(2) ?? dish.price}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E1E1E),
                          ),
                        ),
                        ElevatedButton(
                          onPressed:
                              dish.available ? () => _addToCart(dish) : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E1E1E),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            minimumSize: Size.zero,
                          ),
                          child: const Text('ADD'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDishDetails(MenuDish dish) {
    showDialog<void>(
      context: context,
      builder: (context) {
        final description = dish.publicDescription.trim();
        final ingredients =
            dish.ingredients.where((e) => e.trim().isNotEmpty).toList();
        final allergens = dish.allergens.trim();
        return AlertDialog(
          title: Text(dish.name),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (dish.imageBase64?.isNotEmpty == true)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: InteractiveViewer(
                        minScale: 1,
                        maxScale: 4,
                        child: Image.memory(
                          base64Decode(dish.imageBase64!),
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  _dishDetailBlock(
                    'Description',
                    description.isEmpty
                        ? 'No description available.'
                        : description,
                  ),
                  _dishDetailBlock(
                    'Ingredients',
                    ingredients.isEmpty
                        ? 'No ingredients listed.'
                        : ingredients.join(', '),
                  ),
                  _dishDetailBlock(
                    'Allergens',
                    allergens.isEmpty ? 'No allergens listed.' : allergens,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
            FilledButton(
              onPressed:
                  dish.available
                      ? () {
                        Navigator.of(context).pop();
                        _addToCart(dish);
                      }
                      : null,
              child: const Text('Add to tray'),
            ),
          ],
        );
      },
    );
  }

  Widget _dishDetailBlock(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(value),
        ],
      ),
    );
  }

  Widget _buildCartSidebar({VoidCallback? closeOverlay}) {
    return ListenableBuilder(
      listenable: CartStore.instance,
      builder: (context, _) {
        final cartItems = CartStore.instance.items;
        final totalAmount = CartStore.instance.totalAmount;
        final itemCount = CartStore.instance.itemCount;

        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFF1E1E1E),
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shopping_bag_outlined, color: Colors.white),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Your Tray',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    itemCount == 0
                        ? '0 items'
                        : '$itemCount ${itemCount == 1 ? 'item' : 'items'}',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ],
              ),
            ),
            Expanded(
              child:
                  cartItems.isEmpty
                      ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.shopping_bag_outlined,
                              size: 48,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Your tray is empty',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Add items from the restaurant menu',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      )
                      : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: cartItems.length,
                        itemBuilder: (context, index) {
                          final item = cartItems[index];
                          return _buildCartItem(item);
                        },
                      ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(12),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total:',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '₱${totalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E1E1E),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed:
                          cartItems.isEmpty
                              ? null
                              : () => unawaited(
                                _proceedToCheckout(closeOverlay: closeOverlay),
                              ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E1E1E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'PROCEED TO CHECKOUT',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCartItem(CartItem item) {
    return InkWell(
      onTap: () => _showCustomizeCartItem(item),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            // Item info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.dish.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₱${item.lineSubtotal.toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  if (item.selectedSauce?.trim().isNotEmpty == true ||
                      item.addOns.isNotEmpty ||
                      item.specialInstructions?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (item.selectedSauce?.trim().isNotEmpty == true)
                          'Sauce: ${item.selectedSauce} × ${item.addOnQuantity}',
                        if (item.addonExtraSubtotal > 0)
                          'Extra add-on fee: ₱${item.addonExtraSubtotal.toStringAsFixed(2)}',
                        if (item.addOns.isNotEmpty)
                          'Add-ons: ${item.addOns.join(', ')}',
                        if (item.specialInstructions?.trim().isNotEmpty == true)
                          'Note: ${item.specialInstructions}',
                      ].join('\n'),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Quantity controls
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove, size: 16),
                  onPressed: () => _updateQuantity(item, item.quantity - 1),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
                Text(
                  '${item.quantity}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add, size: 16),
                  onPressed: () => _updateQuantity(item, item.quantity + 1),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _addToCart(MenuDish dish) {
    _showAddToCartOptions(dish);
  }

  void _updateQuantity(CartItem item, int newQuantity) {
    CartStore.instance.updateCartItemQuantity(item, newQuantity);
  }

  Future<void> _showAddToCartOptions(MenuDish dish) async {
    String? selectedSauce = dish.sauces.isNotEmpty ? dish.sauces.first : null;
    var addOnQuantity = selectedSauce?.trim().isNotEmpty == true ? 1 : 1;
    final selectedAddOns = <String>{};
    final noteController = TextEditingController();
    await showDialog<void>(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: Text('Customize ${dish.name}'),
                  content: SizedBox(
                    width: 420,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _dishDetailBlock(
                            'Description',
                            dish.publicDescription.trim().isEmpty
                                ? 'No description available.'
                                : dish.publicDescription.trim(),
                          ),
                          _dishDetailBlock(
                            'Ingredients',
                            dish.ingredients.isEmpty
                                ? 'No ingredients listed.'
                                : dish.ingredients.join(', '),
                          ),
                          _dishDetailBlock(
                            'Allergens',
                            dish.allergens.trim().isEmpty
                                ? 'No allergens listed.'
                                : dish.allergens.trim(),
                          ),
                          const SizedBox(height: 12),
                          if (dish.sauces.isNotEmpty) ...[
                            const Text(
                              'Add-ons',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            for (final sauce in dish.sauces)
                              RadioListTile<String>(
                                value: sauce,
                                groupValue: selectedSauce,
                                title: Text(sauce),
                                onChanged:
                                    (value) => setDialogState(() {
                                      selectedSauce = value;
                                      addOnQuantity = 1;
                                    }),
                              ),
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Add-on portions',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline),
                                  onPressed:
                                      addOnQuantity > 0
                                          ? () => setDialogState(
                                            () => addOnQuantity--,
                                          )
                                          : null,
                                ),
                                Text(
                                  '$addOnQuantity',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline),
                                  onPressed:
                                      () =>
                                          setDialogState(() => addOnQuantity++),
                                ),
                              ],
                            ),
                            Text(
                              'First add-on is included; +₱${dish.additionalChargeAmount > 0 ? dish.additionalChargeAmount.toStringAsFixed(0) : kRestaurantAddonExtraPhp.toStringAsFixed(0)} for each extra per main dish.',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                          if (dish.sauces.isEmpty)
                            const Text(
                              'Add-ons',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          Wrap(
                            spacing: 8,
                            children:
                                _defaultAddOns.isEmpty
                                    ? [
                                      Chip(
                                        label: const Text(
                                          'No add-ons available',
                                        ),
                                        backgroundColor: Colors.grey.shade100,
                                      ),
                                    ]
                                    : _defaultAddOns.map((addon) {
                                      return FilterChip(
                                        label: Text(addon),
                                        selected: selectedAddOns.contains(
                                          addon,
                                        ),
                                        onSelected:
                                            (selected) => setDialogState(() {
                                              if (selected) {
                                                selectedAddOns.add(addon);
                                              } else {
                                                selectedAddOns.remove(addon);
                                              }
                                            }),
                                      );
                                    }).toList(),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: noteController,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              labelText: 'Notes',
                              hintText: 'Optional notes for this dish',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () {
                        CartStore.instance.addItem(
                          dish,
                          selectedSauce: selectedSauce,
                          addOnQuantity: addOnQuantity,
                          addOns: selectedAddOns.toList(),
                          specialInstructions: noteController.text.trim(),
                        );
                        Navigator.of(context).pop();
                        showAntdMessage(
                          context,
                          '${dish.name} added to tray',
                          duration: const Duration(seconds: 2),
                        );
                      },
                      child: const Text('Add to tray'),
                    ),
                  ],
                ),
          ),
    );
    noteController.dispose();
  }

  Future<void> _showCustomizeCartItem(CartItem item) async {
    String? selectedSauce = item.selectedSauce;
    var addOnQuantity = item.addOnQuantity;
    final selectedAddOns = item.addOns.toSet();
    final noteController = TextEditingController(
      text: item.specialInstructions ?? '',
    );
    await showDialog<void>(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: Text('Edit ${item.dish.name}'),
                  content: SizedBox(
                    width: 420,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (item.dish.sauces.isNotEmpty) ...[
                            const Text(
                              'Sauce selection',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            for (final sauce in item.dish.sauces)
                              RadioListTile<String>(
                                value: sauce,
                                groupValue: selectedSauce,
                                title: Text(sauce),
                                onChanged:
                                    (value) => setDialogState(() {
                                      selectedSauce = value;
                                      addOnQuantity = 1;
                                    }),
                              ),
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Add-on portions',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline),
                                  onPressed:
                                      addOnQuantity > 0
                                          ? () => setDialogState(
                                            () => addOnQuantity--,
                                          )
                                          : null,
                                ),
                                Text(
                                  '$addOnQuantity',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline),
                                  onPressed:
                                      () =>
                                          setDialogState(() => addOnQuantity++),
                                ),
                              ],
                            ),
                            Text(
                              'First add-on is included; +₱${item.dish.additionalChargeAmount > 0 ? item.dish.additionalChargeAmount.toStringAsFixed(0) : kRestaurantAddonExtraPhp.toStringAsFixed(0)} for each extra per main dish.',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                          const Text(
                            'Add-ons / toppings',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Wrap(
                            spacing: 8,
                            children:
                                _defaultAddOns.map((addon) {
                                  return FilterChip(
                                    label: Text(addon),
                                    selected: selectedAddOns.contains(addon),
                                    onSelected:
                                        (selected) => setDialogState(() {
                                          if (selected) {
                                            selectedAddOns.add(addon);
                                          } else {
                                            selectedAddOns.remove(addon);
                                          }
                                        }),
                                  );
                                }).toList(),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: noteController,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              labelText: 'Special instructions',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        CartStore.instance.removeCartItem(item);
                        Navigator.of(context).pop();
                      },
                      child: const Text('Remove'),
                    ),
                    FilledButton(
                      onPressed: () {
                        CartStore.instance.updateCartItemCustomizations(
                          item,
                          selectedSauce: selectedSauce,
                          addOnQuantity: addOnQuantity,
                          addOns: selectedAddOns.toList(),
                          specialInstructions: noteController.text.trim(),
                        );
                        Navigator.of(context).pop();
                      },
                      child: const Text('Save'),
                    ),
                  ],
                ),
          ),
    );
    noteController.dispose();
  }

  // ignore: unused_element
  void _openCartSidebar() {
    // For mobile, show bottom sheet
    if (isMobile(context)) {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (sheetContext) {
          return DraggableScrollableSheet(
            initialChildSize: 0.7,
            maxChildSize: 0.9,
            minChildSize: 0.5,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Expanded(
                      child: _buildCartSidebar(
                        closeOverlay: () {
                          if (Navigator.of(sheetContext).canPop()) {
                            Navigator.of(sheetContext).pop();
                          }
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    }
  }
}
