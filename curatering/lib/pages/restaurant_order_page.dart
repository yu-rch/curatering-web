import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/menu_store.dart';
import '../services/cart_store.dart';
import '../models/menu_dish.dart';
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
  String _selectedRestaurantType = 'RICE MEALS';

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
          Expanded(child: _buildRestaurantMenu()),
        ],
      ),
    );
  }

  Widget _buildRestaurantMenu() {
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
          final isRestaurantCategory =
              category == 'restaurant' ||
              category == 'main_course' ||
              category == 'noodles' ||
              category == 'appetizer' ||
              category == 'rice' ||
              category == 'dessert' ||
              category == 'drinks' ||
              category == 'drink';
          return isRestaurantCategory || d.type.trim().isNotEmpty;
        }).toList();

    // Filter restaurant dishes by selected type
    String restaurantTypeForDish(MenuDish dish) {
      final rawType = dish.type.trim().toLowerCase();
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
    final dishes =
        restaurantDishes.where((d) {
          final dishType = restaurantTypeForDish(d);
          return dishType == selectedType;
        }).toList();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left side - Menu
        Expanded(
          flex: 3,
          child: SingleChildScrollView(
            padding: websitePagePadding(context, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  'RESTAURANT',
                  style: GoogleFonts.getFont(
                    _primaryFont,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E1E1E),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Order from our delicious restaurant menu',
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 24),

                // Category tabs
                _buildCategoryTabs(restaurantDishes),
                const SizedBox(height: 24),

                // Menu items
                if (dishes.isEmpty)
                  Center(
                    child: Column(
                      children: [
                        const SizedBox(height: 100),
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
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
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
                    color: Colors.black.withOpacity(0.1),
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

  Widget _buildCategoryTabs(List<MenuDish> restaurantDishes) {
    final types = <String>{};
    for (final dish in restaurantDishes) {
      final rawType = dish.type.trim().toLowerCase();
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

    final typeList = types.toList();
    typeList.sort();

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
                  const SizedBox(height: 4),
                  Text(
                    dish.category,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    maxLines: 1,
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
    );
  }

  Widget _buildCartSidebar() {
    final cartItems = CartStore.instance.items;
    final totalAmount = CartStore.instance.totalAmount;

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Color(0xFF1E1E1E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Row(
            children: [
              const Icon(Icons.shopping_cart, color: Colors.white),
              const SizedBox(width: 8),
              const Text(
                'Your Cart',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                '${cartItems.length} items',
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ],
          ),
        ),
        // Cart items
        Expanded(
          child:
              cartItems.isEmpty
                  ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.shopping_cart_outlined,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Your cart is empty',
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
        // Footer
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
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                  onPressed: cartItems.isEmpty ? null : _proceedToCheckout,
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
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCartItem(CartItem item) {
    return Container(
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
                  '₱${item.dish.price}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
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
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
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
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _addToCart(MenuDish dish) {
    CartStore.instance.addItem(dish);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${dish.name} added to cart'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _updateQuantity(CartItem item, int newQuantity) {
    if (newQuantity <= 0) {
      CartStore.instance.removeItem(item.dish.id);
    } else {
      CartStore.instance.updateQuantity(item.dish.id, newQuantity);
    }
  }

  void _openCartSidebar() {
    // For mobile, show bottom sheet
    if (isMobile(context)) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder:
            (context) => DraggableScrollableSheet(
              initialChildSize: 0.7,
              maxChildSize: 0.9,
              minChildSize: 0.5,
              builder:
                  (context, scrollController) => Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    child: Column(
                      children: [
                        // Handle bar
                        Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        // Cart content
                        Expanded(child: _buildCartSidebar()),
                      ],
                    ),
                  ),
            ),
      );
    }
  }

  void _proceedToCheckout() {
    // TODO: Navigate to checkout page
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Proceeding to checkout...')));
  }
}
