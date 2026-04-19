import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../auth/auth_session.dart';
import '../auth/roles.dart';
import '../models/menu_dish.dart';
import '../services/menu_store.dart';
import '../services/set_menu_store.dart';
import '../services/public_events_api.dart';
import '../services/website_content_store.dart';
import '../services/cart_store.dart';
import '../services/loyalty_rewards_store.dart';
import 'customer_login.dart';
import 'checkout_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SetDish {
  final String name;
  final String ingredients;
  final String tag;
  final String category;

  _SetDish({
    required this.name,
    required this.ingredients,
    required this.tag,
    required this.category,
  });
}

class _CustomDish {
  final String id;
  String name;
  String description;

  _CustomDish({
    required this.id,
    required this.name,
    required this.description,
  });
}

class _SetMenuOption {
  final String id;
  final String name;
  final String description;
  final List<_SetDish> dishes;

  _SetMenuOption({
    required this.id,
    required this.name,
    required this.description,
    required this.dishes,
  });
}

class CustomerWebsiteScreen extends StatefulWidget {
  const CustomerWebsiteScreen({
    super.key,
    this.contentEditable = false,
    this.showStaffChrome = true,
  });

  final bool contentEditable;
  final bool showStaffChrome;

  @override
  State<CustomerWebsiteScreen> createState() => _CustomerWebsiteScreenState();
}

//Responsive Helpers
bool isMobile(BuildContext context) => MediaQuery.of(context).size.width < 700;

bool isTablet(BuildContext context) =>
    MediaQuery.of(context).size.width >= 700 &&
    MediaQuery.of(context).size.width < 1100;

bool isDesktop(BuildContext context) =>
    MediaQuery.of(context).size.width >= 1100;

class _CustomerWebsiteScreenState extends State<CustomerWebsiteScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _navIndex = 0;
  int? _galleryDetailIndex;
  Map<String, dynamic>? _customerData;
  bool _isCustomerLoggedIn = false;

  @override
  void initState() {
    super.initState();
    WebsiteContentStore.instance.ensureLoaded().then((_) {
      if (mounted) setState(() {});
    });
    MenuStore.instance.addListener(_onMenuChanged);
    // Ensure dishes are loaded
    if (MenuStore.instance.activeDishes.isEmpty) {
      MenuStore.instance.loadDishes();
    }
    CartStore.instance.init();
    CartStore.instance.addListener(_onCartChanged);
    _checkCustomerAuth();
  }

  Future<void> _checkCustomerAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('customer_token');
    final customerData = prefs.getString('customer_data');
    if (mounted) {
      setState(() {
        _isCustomerLoggedIn = token != null && token.isNotEmpty;
        if (customerData != null) {
          try {
            _customerData = jsonDecode(customerData);
          } catch (_) {
            _customerData = null;
          }
        }
      });
    }
  }

  Future<void> _handleLogin() async {
    await showDialog(
      context: context,
      builder: (context) => const CustomerLoginPage(),
    );
    if (mounted) {
      await _checkCustomerAuth();
    }
  }

  Future<void> _handleLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('customer_token');
    await prefs.remove('customer_data');
    if (mounted) {
      setState(() {
        _isCustomerLoggedIn = false;
        _customerData = null;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Logged out successfully')));
    }
  }

  void _onMenuChanged() {
    if (mounted) setState(() {});
  }

  void _onCartChanged() {
    if (mounted) setState(() {});
  }

  void _addToCart(MenuDish dish) {
    CartStore.instance.addItem(dish);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${dish.name} added to cart'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _openCartSidebar() {
    _scaffoldKey.currentState?.openEndDrawer();
  }

  void _navigateToCheckout() {
    if (CartStore.instance.items.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Your cart is empty')));
      return;
    }
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const CheckoutPage()));
  }

  @override
  void dispose() {
    MenuStore.instance.removeListener(_onMenuChanged);
    CartStore.instance.removeListener(_onCartChanged);
    super.dispose();
  }

  String _staffHomeRoute() {
    final r = AuthSession.instance.currentUser.value?.role;
    return switch (r) {
      Role.superAdmin => '/manage-accounts',
      Role.supervisor => '/dashboard',
      _ => '/manage-events',
    };
  }

  Future<String?> _pickImageB64() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (x == null) return null;
    final bytes = await x.readAsBytes();
    return base64Encode(bytes);
  }

  Widget _b64Image(
    String? b64, {
    double? height,
    BoxFit fit = BoxFit.cover,
    Widget? placeholder,
  }) {
    final ph =
        placeholder ??
        Container(
          color: Colors.grey.shade300,
          child: const Icon(
            Icons.image_not_supported,
            size: 48,
            color: Colors.grey,
          ),
        );
    if (b64 == null || b64.isEmpty) return ph;
    try {
      return Image.memory(
        base64Decode(b64),
        height: height,
        width: double.infinity,
        fit: fit,
        gaplessPlayback: true,
      );
    } catch (_) {
      return ph;
    }
  }

  Widget _publicHeader() {
    return Container(
      color: const Color(0xFF1E1E1E),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: Colors.white,
            child: Icon(Icons.restaurant, color: Colors.amber.shade800),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _navLink('Home', 0),
                _navLink('Gallery', 1),
                _navLink('Catering Menu', 2),
                _navLink('Restaurant', 3),
                _navLink('Inquire Now', 4),
                _navLink('Contact Us', 5),
              ],
            ),
          ),
          // Cart Icon
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart, color: Colors.white),
                onPressed: _openCartSidebar,
              ),
              if (CartStore.instance.itemCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Text(
                      '${CartStore.instance.itemCount}',
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
          // Login/Logout Button
          if (_isCustomerLoggedIn)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'logout') {
                  _handleLogout();
                }
              },
              child: Row(
                children: [
                  Icon(Icons.person, color: Colors.amber.shade400, size: 20),
                  const SizedBox(width: 4),
                  Text(
                    _customerData?['fullName'] ?? 'Customer',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                  const Icon(Icons.arrow_drop_down, color: Colors.white),
                ],
              ),
              itemBuilder:
                  (context) => [
                    const PopupMenuItem(
                      value: 'logout',
                      child: Row(
                        children: [
                          Icon(Icons.logout, size: 18),
                          SizedBox(width: 8),
                          Text('Logout'),
                        ],
                      ),
                    ),
                  ],
            )
          else
            TextButton.icon(
              onPressed: _handleLogin,
              icon: const Icon(Icons.login, color: Colors.white, size: 18),
              label: const Text('Login', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
    );
  }

  Widget _navLink(String label, int index) {
    final on = _navIndex == index && _galleryDetailIndex == null;
    return InkWell(
      onTap:
          () => setState(() {
            _galleryDetailIndex = null;
            _navIndex = index;
          }),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontWeight: on ? FontWeight.w700 : FontWeight.w400,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 4),
            if (on)
              Container(height: 2, width: 36, color: const Color(0xFFFFC024)),
          ],
        ),
      ),
    );
  }

  Widget _footer(WebsiteContentStore w) {
    return Container(
      color: const Color(0xFFFFC107),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
      child: Wrap(
        spacing: 32,
        runSpacing: 16,
        crossAxisAlignment: WrapCrossAlignment.start,
        children: [
          SizedBox(
            width: 220,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextButton(
                  onPressed: () {},
                  child: const Text('PRIVACY POLICY'),
                ),
                Text(
                  w.footerCopyright,
                  style: const TextStyle(fontSize: 11, height: 1.4),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextButton(
                onPressed: () => setState(() => _navIndex = 1),
                child: const Text('GALLERY'),
              ),
              TextButton(
                onPressed: () => setState(() => _navIndex = 2),
                child: const Text('CATERING MENU'),
              ),
              TextButton(
                onPressed: () => setState(() => _navIndex = 3),
                child: const Text('RESTAURANT'),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextButton(
                onPressed: () => setState(() => _navIndex = 4),
                child: const Text('INQUIRE NOW'),
              ),
              TextButton(
                onPressed: () => setState(() => _navIndex = 5),
                child: const Text('CONTACT US'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pushNamed('/login'),
                child: const Text(
                  'STAFF LOGIN',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          _footerCol(Icons.facebook, w.contactFacebook),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _footerRow(Icons.place, w.contactAddress),
              _footerRow(Icons.schedule, w.contactHours),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _footerRow(Icons.phone, w.contactPhone),
              _footerRow(Icons.email, w.contactEmail),
            ],
          ),
        ],
      ),
    );
  }

  Widget _footerCol(IconData icon, String text) {
    return SizedBox(
      width: 200,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  Widget _footerRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  Widget _editChip(VoidCallback onEdit) {
    if (!widget.contentEditable) return const SizedBox.shrink();
    return Positioned(
      top: 8,
      right: 8,
      child: Material(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(20),
        child: IconButton(
          icon: const Icon(Icons.edit, color: Colors.white, size: 20),
          onPressed: onEdit,
        ),
      ),
    );
  }

  Widget _buildHome(WebsiteContentStore w) {
    return ListenableBuilder(
      listenable: w,
      builder: (context, _) {
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Stack(
                children: [
                  SizedBox(
                    height: 280,
                    width: double.infinity,
                    child:
                        w.homeHeroImageBase64.isEmpty
                            ? Container(
                              color: Colors.grey.shade400,
                              alignment: Alignment.center,
                              child: Text(
                                'Macrina\'s Kitchen and Catering',
                                style: GoogleFonts.playfairDisplay(
                                  fontSize: 28,
                                  color: Colors.white,
                                ),
                              ),
                            )
                            : _b64Image(w.homeHeroImageBase64, height: 280),
                  ),
                  _editChip(() async {
                    final b64 = await _pickImageB64();
                    if (b64 == null) return;
                    w.homeHeroImageBase64 = b64;
                    await w.save();
                    setState(() {});
                  }),
                ],
              ),
              Container(
                color: const Color(0xFFF5F5F5),
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isDesktop(context) ? 1100 : double.infinity,
                    ),
                    child: Column(
                      children: [
                        Text(
                          w.redBannerText,
                          style: GoogleFonts.dancingScript(
                            fontSize: 26,
                            color: Colors.red.shade700,
                            fontWeight: FontWeight.w700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 5,
                              child: Stack(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.grey.shade300,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          color: const Color(0xFFFFC024),
                                          child: const Text(
                                            'LATEST EVENT',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          w.latestEventTitle,
                                          style: GoogleFonts.dancingScript(
                                            fontSize: 32,
                                            color: Colors.pink.shade300,
                                          ),
                                        ),
                                        Text(
                                          w.latestEventSubtitle,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Text(w.latestEventBody),
                                        const SizedBox(height: 12),
                                        TextButton(
                                          onPressed:
                                              () =>
                                                  setState(() => _navIndex = 3),
                                          child: const Text('INQUIRE NOW!'),
                                        ),
                                      ],
                                    ),
                                  ),
                                  _editChip(() async {
                                    final title = TextEditingController(
                                      text: w.latestEventTitle,
                                    );
                                    final sub = TextEditingController(
                                      text: w.latestEventSubtitle,
                                    );
                                    final body = TextEditingController(
                                      text: w.latestEventBody,
                                    );
                                    await showDialog<void>(
                                      context: context,
                                      builder:
                                          (ctx) => AlertDialog(
                                            title: const Text(
                                              'Edit latest event',
                                            ),
                                            content: SingleChildScrollView(
                                              child: Column(
                                                children: [
                                                  TextField(
                                                    controller: title,
                                                    decoration:
                                                        const InputDecoration(
                                                          labelText: 'Title',
                                                        ),
                                                  ),
                                                  TextField(
                                                    controller: sub,
                                                    decoration:
                                                        const InputDecoration(
                                                          labelText: 'Subtitle',
                                                        ),
                                                  ),
                                                  TextField(
                                                    controller: body,
                                                    maxLines: 4,
                                                    decoration:
                                                        const InputDecoration(
                                                          labelText: 'Body',
                                                        ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed:
                                                    () => Navigator.pop(ctx),
                                                child: const Text('Cancel'),
                                              ),
                                              TextButton(
                                                onPressed: () {
                                                  w.latestEventTitle =
                                                      title.text;
                                                  w.latestEventSubtitle =
                                                      sub.text;
                                                  w.latestEventBody = body.text;
                                                  w.save();
                                                  Navigator.pop(ctx);
                                                  setState(() {});
                                                },
                                                child: const Text('Save'),
                                              ),
                                            ],
                                          ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              flex: 5,
                              child: Stack(
                                children: [
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: List.generate(4, (i) {
                                      final list = w.latestEventCollageBase64;
                                      final b64 =
                                          i < list.length ? list[i] : null;
                                      return SizedBox(
                                        width: 160,
                                        height: 120,
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          child: _b64Image(
                                            b64,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      );
                                    }),
                                  ),
                                  _editChip(() async {
                                    final b64 = await _pickImageB64();
                                    if (b64 == null) return;
                                    if (w.latestEventCollageBase64.length < 4) {
                                      w.latestEventCollageBase64.add(b64);
                                    } else {
                                      w.latestEventCollageBase64[w
                                                  .latestEventCollageBase64
                                                  .length -
                                              1] =
                                          b64;
                                    }
                                    await w.save();
                                    setState(() {});
                                  }),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        _popularAndDesigns(w),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _popularAndDesigns(WebsiteContentStore w) {
    final dishes = MenuStore.instance.activeDishes.take(5).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: const Color(0xFFFFC024),
              child: const Text(
                'POPULAR DISHES',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        Text(
          'Our all-time most requested dishes!',
          style: GoogleFonts.dancingScript(fontSize: 18),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 160,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children:
                dishes.map((d) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: SizedBox(
                      width: 140,
                      child: Column(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child:
                                  d.imageBase64 != null &&
                                          d.imageBase64!.isNotEmpty
                                      ? _b64Image(
                                        d.imageBase64,
                                        fit: BoxFit.cover,
                                      )
                                      : Container(
                                        color: Colors.grey.shade200,
                                        child: const Icon(
                                          Icons.fastfood,
                                          size: 40,
                                        ),
                                      ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            d.name.toUpperCase(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '₱${d.price}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.amber.shade800,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            height: 24,
                            child: ElevatedButton.icon(
                              onPressed: () => _addToCart(d),
                              icon: const Icon(Icons.add, size: 14),
                              label: const Text(
                                'Add',
                                style: TextStyle(fontSize: 10),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1E1E1E),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
          ),
        ),
        const SizedBox(height: 28),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: const Color(0xFFFFC024),
              child: const Text(
                'EVENT DESIGNS',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        Text(
          'From decorations to dinnerware!',
          style: GoogleFonts.dancingScript(fontSize: 18),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: List.generate(
              5,
              (i) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 160,
                    child:
                        i < w.eventDesignImageBase64.length
                            ? _b64Image(
                              w.eventDesignImageBase64[i],
                              fit: BoxFit.cover,
                            )
                            : Container(color: Colors.grey.shade300),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (widget.contentEditable)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () async {
                final b64 = await _pickImageB64();
                if (b64 == null) return;
                w.eventDesignImageBase64.add(b64);
                await w.save();
                setState(() {});
              },
              icon: const Icon(Icons.add_photo_alternate),
              label: const Text('Add event design photo'),
            ),
          ),
      ],
    );
  }

  Widget _buildGallery(WebsiteContentStore w) {
    if (_galleryDetailIndex != null) {
      final cat = w.galleryCategories[_galleryDetailIndex!];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                OutlinedButton(
                  onPressed: () => setState(() => _galleryDetailIndex = null),
                  child: const Text('GO BACK'),
                ),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  color: const Color(0xFFFFC024),
                  child: Text(
                    cat.label,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const Spacer(),
                if (widget.contentEditable)
                  TextButton.icon(
                    onPressed: () async {
                      final b64 = await _pickImageB64();
                      if (b64 == null) return;
                      cat.imageBase64List.add(b64);
                      await w.save();
                      setState(() {});
                    },
                    icon: const Icon(Icons.upload),
                    label: const Text('Upload'),
                  ),
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(24),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount:
                    isMobile(context)
                        ? 1
                        : isTablet(context)
                        ? 2
                        : 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.2,
              ),
              itemCount: cat.imageBase64List.length,
              itemBuilder:
                  (ctx, i) => ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: _b64Image(cat.imageBase64List[i], fit: BoxFit.cover),
                  ),
            ),
          ),
        ],
      );
    }

    return ListenableBuilder(
      listenable: w,
      builder: (context, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isDesktop(context) ? 1100 : double.infinity,
              ),
              child: Column(
                children: [
                  Text(
                    'Gallery',
                    style: GoogleFonts.dancingScript(
                      fontSize: 42,
                      color: Colors.red.shade400,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'WE CATER TO MANY DIFFERENT TYPES OF EVENTS. TAKE A LOOK AT OUR WORK!',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
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
                      childAspectRatio: 1.1,
                    ),
                    itemCount: w.galleryCategories.length,
                    itemBuilder: (ctx, i) {
                      final c = w.galleryCategories[i];
                      final thumb =
                          c.imageBase64List.isNotEmpty
                              ? c.imageBase64List.first
                              : null;
                      return InkWell(
                        onTap: () => setState(() => _galleryDetailIndex = i),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: AspectRatio(
                                aspectRatio: 1.1,
                                child: _b64Image(thumb, fit: BoxFit.cover),
                              ),
                            ),
                            Positioned(
                              bottom: 8,
                              left: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.92),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.deepOrange.shade200,
                                  ),
                                ),
                                child: Text(
                                  c.label,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                            if (widget.contentEditable)
                              Positioned(
                                top: 4,
                                right: 4,
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.edit,
                                    color: Colors.white,
                                  ),
                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.black45,
                                  ),
                                  onPressed: () async {
                                    final ctrl = TextEditingController(
                                      text: c.label,
                                    );
                                    await showDialog<void>(
                                      context: context,
                                      builder:
                                          (ctx) => AlertDialog(
                                            title: const Text('Category label'),
                                            content: TextField(
                                              controller: ctrl,
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed:
                                                    () => Navigator.pop(ctx),
                                                child: const Text('Cancel'),
                                              ),
                                              TextButton(
                                                onPressed: () {
                                                  c.label = ctrl.text;
                                                  w.save();
                                                  Navigator.pop(ctx);
                                                  setState(() {});
                                                },
                                                child: const Text('Save'),
                                              ),
                                            ],
                                          ),
                                    );
                                  },
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCateringMenu() {
    // Show loading state
    if (MenuStore.instance.isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading menu...'),
          ],
        ),
      );
    }

    // Show error state
    if (MenuStore.instance.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error: ${MenuStore.instance.error}'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => MenuStore.instance.loadDishes(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final allDishes = MenuStore.instance.activeDishes;
    final cateringDishes =
        allDishes.where((d) => d.category == 'catering').toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isDesktop(context) ? 1100 : double.infinity,
          ),
          child: Column(
            children: [
              Text(
                'Catering Menu',
                style: GoogleFonts.dancingScript(
                  fontSize: 42,
                  color: Colors.red.shade400,
                ),
              ),
              const SizedBox(height: 24),
              if (cateringDishes.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'No dishes available',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
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
                    childAspectRatio: 0.9,
                  ),
                  itemCount: cateringDishes.length,
                  itemBuilder: (ctx, i) {
                    final d = cateringDishes[i];
                    return Card(
                      child: Column(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(8),
                              ),
                              child:
                                  d.imageBase64 != null &&
                                          d.imageBase64!.isNotEmpty
                                      ? _b64Image(
                                        d.imageBase64,
                                        fit: BoxFit.cover,
                                      )
                                      : Container(
                                        color: Colors.grey.shade200,
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
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRestaurantMenu() {
    final allDishes = MenuStore.instance.activeDishes;
    final restaurantDishes =
        allDishes.where((d) => d.category == 'restaurant').toList();
    final cartItems = CartStore.instance.items;
    final totalAmount = CartStore.instance.totalAmount;
    final dishes = restaurantDishes;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left side - Menu
        Expanded(
          flex: 3,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title and Login button
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Center(
                        child: Text(
                          'Restaurant',
                          style: GoogleFonts.dancingScript(
                            fontSize: 42,
                            color: Colors.red.shade400,
                          ),
                        ),
                      ),
                    ),
                    if (!_isCustomerLoggedIn)
                      ElevatedButton(
                        onPressed: _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFC024),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'LOG IN TO ORDER',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                // Loyalty Points Banner
                _buildLoyaltyBanner(),
                const SizedBox(height: 16),
                // Search and Filter
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFFFC024)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const TextField(
                          decoration: InputDecoration(
                            hintText: 'SEARCH',
                            hintStyle: TextStyle(color: Colors.grey),
                            prefixIcon: Icon(Icons.search, color: Colors.grey),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: OutlinedButton(
                        onPressed: () {},
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.grey),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('FILTER'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Category tabs
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildCategoryTab('RICE MEALS', true),
                      _buildCategoryTab('SILOG MEALS', false),
                      _buildCategoryTab('PASTA', false),
                      _buildCategoryTab('SANDWICHES', false),
                      _buildCategoryTab('OTHERS', false),
                      _buildCategoryTab('DRINKS', false),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Dishes grid
                if (dishes.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'No dishes available',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    ),
                  )
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.75,
                        ),
                    itemCount: dishes.length,
                    itemBuilder: (ctx, i) {
                      final d = dishes[i];
                      return Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              flex: 3,
                              child: ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(12),
                                ),
                                child:
                                    d.imageBase64 != null &&
                                            d.imageBase64!.isNotEmpty
                                        ? _b64Image(
                                          d.imageBase64,
                                          fit: BoxFit.cover,
                                        )
                                        : Container(
                                          color: Colors.grey.shade200,
                                          child: const Icon(
                                            Icons.fastfood,
                                            size: 48,
                                          ),
                                        ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      d.name.toUpperCase(),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 11,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      d.sauces.isNotEmpty
                                          ? d.sauces.join(', ').toUpperCase()
                                          : '',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: Colors.grey.shade600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '₱${d.price}',
                                      style: TextStyle(
                                        color: Colors.amber.shade800,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    if (_isCustomerLoggedIn)
                                      SizedBox(
                                        height: 28,
                                        child: ElevatedButton(
                                          onPressed: () => _addToCart(d),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(
                                              0xFF1E1E1E,
                                            ),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                          ),
                                          child: const Text(
                                            'Add',
                                            style: TextStyle(fontSize: 11),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
        // Right side - Cart Sidebar
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 600),
          child: Container(
            width: 280,
            margin: const EdgeInsets.only(right: 24, top: 24, bottom: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                  child: const Text(
                    'YOUR TRAY',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                // Cart items
                Flexible(
                  child:
                      cartItems.isEmpty
                          ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.shopping_cart_outlined,
                                  size: 48,
                                  color: Colors.grey.shade300,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Your tray is empty',
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          )
                          : ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: cartItems.length,
                            itemBuilder: (context, index) {
                              final cartItem = cartItems[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Row(
                                  children: [
                                    if (cartItem.dish.imageBase64 != null)
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: Image.memory(
                                          base64Decode(
                                            cartItem.dish.imageBase64!,
                                          ),
                                          width: 50,
                                          height: 50,
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                    else
                                      Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade200,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.fastfood,
                                          size: 20,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            cartItem.dish.name.toUpperCase(),
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (cartItem.dish.sauces.isNotEmpty)
                                            Text(
                                              cartItem.dish.sauces.first
                                                  .toUpperCase(),
                                              style: TextStyle(
                                                fontSize: 8,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          'x${cartItem.quantity}',
                                          style: const TextStyle(fontSize: 10),
                                        ),
                                        Text(
                                          '₱${(double.tryParse(cartItem.dish.price) ?? 0) * cartItem.quantity}',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                ),
                // Footer with total and checkout
                if (cartItems.isNotEmpty || true)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'TOTAL',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '₱${totalAmount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed:
                                _isCustomerLoggedIn
                                    ? () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder:
                                            (context) => const CheckoutPage(),
                                      ),
                                    )
                                    : _handleLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFFC024),
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            child: Text(
                              _isCustomerLoggedIn
                                  ? 'CHECKOUT'
                                  : 'LOG IN TO ORDER',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryTab(String label, bool isSelected) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: ElevatedButton(
        onPressed: () {},
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected ? const Color(0xFF1E1E1E) : Colors.white,
          foregroundColor: isSelected ? const Color(0xFFFFC024) : Colors.black,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.grey.shade300),
          ),
        ),
        child: Text(label, style: const TextStyle(fontSize: 11)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = WebsiteContentStore.instance;

    Widget body;
    if (_galleryDetailIndex != null && _navIndex == 1) {
      body = _buildGallery(w);
    } else {
      body = switch (_navIndex) {
        0 => _buildHome(w),
        1 => _buildGallery(w),
        2 => _buildCateringMenu(),
        3 => _buildRestaurantMenu(),
        4 => const _InquireForm(),
        5 => _ContactSection(
          store: w,
          contentEditable: widget.contentEditable,
          pickB64: _pickImageB64,
        ),
        _ => _buildHome(w),
      };
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF5F5F5),

      /// ✅ Sticky header using NestedScrollView
      body: NestedScrollView(
        headerSliverBuilder:
            (context, innerBoxIsScrolled) => [
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    if (widget.showStaffChrome && AuthSession.instance.hasToken)
                      Material(
                        color: Colors.black,
                        child: SafeArea(
                          bottom: false,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            child: Row(
                              children: [
                                TextButton(
                                  onPressed:
                                      () => Navigator.pushReplacementNamed(
                                        context,
                                        _staffHomeRoute(),
                                      ),
                                  child: const Text(
                                    '← Back to Curatering',
                                    style: TextStyle(color: Color(0xFFFFC024)),
                                  ),
                                ),
                                const Spacer(),
                                if (widget.contentEditable)
                                  Chip(
                                    label: const Text(
                                      'EDIT MODE',
                                      style: TextStyle(fontSize: 11),
                                    ),
                                    backgroundColor: Colors.amber.shade100,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),

                    /// ✅ Sticky public header
                    _publicHeader(),
                  ],
                ),
              ),
            ],

        /// ✅ Scrollable content + footer
        body: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: body),
            SliverToBoxAdapter(child: _footer(w)),
          ],
        ),
      ),
      endDrawer: _buildCartSidebar(),
    );
  }

  Widget _buildCartSidebar() {
    final cartItems = CartStore.instance.items;
    final totalAmount = CartStore.instance.totalAmount;

    return Drawer(
      width: 400,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              color: const Color(0xFF1E1E1E),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                children: [
                  const Icon(Icons.shopping_cart, color: Colors.white),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Your Cart',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
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
                              size: 64,
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
                          final cartItem = cartItems[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  if (cartItem.dish.imageBase64 != null)
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.memory(
                                        base64Decode(
                                          cartItem.dish.imageBase64!,
                                        ),
                                        width: 60,
                                        height: 60,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  else
                                    Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade300,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.restaurant,
                                        size: 24,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          cartItem.dish.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '₱${cartItem.dish.price}',
                                          style: TextStyle(
                                            color: Colors.amber.shade800,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                          Icons.remove_circle_outline,
                                          size: 20,
                                        ),
                                        onPressed: () {
                                          if (cartItem.quantity > 1) {
                                            CartStore.instance.updateQuantity(
                                              cartItem.dish.id,
                                              cartItem.quantity - 1,
                                            );
                                          } else {
                                            CartStore.instance.removeItem(
                                              cartItem.dish.id,
                                            );
                                          }
                                        },
                                      ),
                                      Text(
                                        '${cartItem.quantity}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.add_circle_outline,
                                          size: 20,
                                        ),
                                        onPressed: () {
                                          CartStore.instance.updateQuantity(
                                            cartItem.dish.id,
                                            cartItem.quantity + 1,
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
            ),
            // Footer with total and checkout
            if (cartItems.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.3),
                      spreadRadius: 1,
                      blurRadius: 5,
                      offset: const Offset(0, -3),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total:',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '₱${totalAmount.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber.shade800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            _navigateToCheckout();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E1E1E),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'Proceed to Checkout',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
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

  // Loyalty Points Banner - shows points earned and reward selection
  Widget _buildLoyaltyBanner() {
    // Get values from LoyaltyRewardsStore (persisted from management page)
    final double minimumOrderForPoints = LoyaltyRewardsStore.instance.minimumOrderForPoints;
    final int pointsEarned = LoyaltyRewardsStore.instance.pointsEarned;
    final int currentPoints = 150; // User's current points balance - in production from API
    final availableRewards = LoyaltyRewardsStore.instance.rewardsConditions;
    // Ensure store is loaded
    LoyaltyRewardsStore.instance.ensureLoaded();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.amber.shade400, Colors.orange.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.3),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.stars, color: Colors.white, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Loyalty Rewards',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Earn $pointsEarned points on orders ≥ ₱${minimumOrderForPoints.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$currentPoints pts',
                  style: TextStyle(
                    color: Colors.orange.shade700,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isCustomerLoggedIn)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed:
                    () => _showRewardDialog(availableRewards, currentPoints),
                icon: const Icon(Icons.redeem, color: Colors.white),
                label: const Text(
                  'Redeem Rewards',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black.withOpacity(0.2),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _handleLogin,
                icon: const Icon(Icons.login, color: Colors.white),
                label: const Text(
                  'Log in to view and redeem rewards',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black.withOpacity(0.2),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Show reward selection dialog
  Future<void> _showRewardDialog(
    List<RewardsCondition> rewards,
    int currentPoints,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.card_giftcard, color: Colors.orange),
              const SizedBox(width: 8),
              const Text('Redeem Rewards'),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.stars, color: Colors.amber.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'Your Points: $currentPoints',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.amber.shade800,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Available Rewards:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                ...rewards.map((reward) {
                  final canRedeem = currentPoints >= reward.minimumPoints;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            canRedeem ? Colors.green : Colors.grey.shade300,
                        child: Icon(
                          canRedeem ? Icons.check : Icons.lock,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      title: Text(reward.reward),
                      subtitle: Text(reward.description),
                      trailing: Chip(
                        label: Text('${reward.minimumPoints} pts'),
                        backgroundColor:
                            canRedeem
                                ? Colors.green.shade100
                                : Colors.grey.shade200,
                        labelStyle: TextStyle(
                          color:
                              canRedeem
                                  ? Colors.green.shade800
                                  : Colors.grey.shade600,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      onTap:
                          canRedeem
                              ? () {
                                Navigator.of(context).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      '${reward.reward} redeemed successfully!',
                                    ),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                              : null,
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}

class _ContactSection extends StatefulWidget {
  const _ContactSection({
    required this.store,
    required this.contentEditable,
    required this.pickB64,
  });

  final WebsiteContentStore store;
  final bool contentEditable;
  final Future<String?> Function() pickB64;

  @override
  State<_ContactSection> createState() => _ContactSectionState();
}

class _ContactSectionState extends State<_ContactSection> {
  final _helpNameCtrl = TextEditingController();
  final _helpEmailCtrl = TextEditingController();
  final _helpMessageCtrl = TextEditingController();
  bool _submittingHelp = false;

  @override
  void dispose() {
    _helpNameCtrl.dispose();
    _helpEmailCtrl.dispose();
    _helpMessageCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitHelpRequest() async {
    if (_helpNameCtrl.text.trim().isEmpty ||
        _helpEmailCtrl.text.trim().isEmpty ||
        _helpMessageCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    setState(() => _submittingHelp = true);
    try {
      // TODO: Add API call to submit help request
      await Future.delayed(const Duration(seconds: 1)); // Simulate API call
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Help request submitted successfully!')),
      );
      _helpNameCtrl.clear();
      _helpEmailCtrl.clear();
      _helpMessageCtrl.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to submit help request')),
      );
    } finally {
      if (mounted) setState(() => _submittingHelp = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isDesktop(context) ? 1100 : double.infinity,
              ),
              child: Column(
                children: [
                  Text(
                    'Contact Us',
                    style: GoogleFonts.dancingScript(
                      fontSize: 42,
                      color: Colors.red.shade400,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFFFC024)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'WE\'D LOVE TO HEAR FROM YOU!',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('YOU CAN REACH US VIA:'),
                        const SizedBox(height: 16),
                        _contactRow(
                          Icons.facebook,
                          widget.store.contactFacebook,
                          widget.contentEditable,
                          context,
                          (ctx) async {
                            final t = TextEditingController(
                              text: widget.store.contactFacebook,
                            );
                            await showDialog<void>(
                              context: ctx,
                              builder:
                                  (dctx) => AlertDialog(
                                    content: TextField(controller: t),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(dctx),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          widget.store.contactFacebook = t.text;
                                          widget.store.save();
                                          Navigator.pop(dctx);
                                        },
                                        child: const Text('Save'),
                                      ),
                                    ],
                                  ),
                            );
                          },
                        ),
                        _contactRow(
                          Icons.place,
                          widget.store.contactAddress,
                          widget.contentEditable,
                          context,
                          (ctx) async {
                            final t = TextEditingController(
                              text: widget.store.contactAddress,
                            );
                            await showDialog<void>(
                              context: ctx,
                              builder:
                                  (dctx) => AlertDialog(
                                    content: TextField(
                                      controller: t,
                                      maxLines: 2,
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(dctx),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          widget.store.contactAddress = t.text;
                                          widget.store.save();
                                          Navigator.pop(dctx);
                                        },
                                        child: const Text('Save'),
                                      ),
                                    ],
                                  ),
                            );
                          },
                        ),
                        _contactRow(
                          Icons.schedule,
                          widget.store.contactHours,
                          widget.contentEditable,
                          context,
                          (ctx) async {
                            final t = TextEditingController(
                              text: widget.store.contactHours,
                            );
                            await showDialog<void>(
                              context: ctx,
                              builder:
                                  (dctx) => AlertDialog(
                                    title: const Text('Hours'),
                                    content: TextField(controller: t),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(dctx),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          widget.store.contactHours = t.text;
                                          widget.store.save();
                                          Navigator.pop(dctx);
                                        },
                                        child: const Text('Save'),
                                      ),
                                    ],
                                  ),
                            );
                          },
                        ),
                        _contactRow(
                          Icons.phone,
                          widget.store.contactPhone,
                          widget.contentEditable,
                          context,
                          (ctx) async {
                            final t = TextEditingController(
                              text: widget.store.contactPhone,
                            );
                            await showDialog<void>(
                              context: ctx,
                              builder:
                                  (dctx) => AlertDialog(
                                    title: const Text('Phone'),
                                    content: TextField(controller: t),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(dctx),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          widget.store.contactPhone = t.text;
                                          widget.store.save();
                                          Navigator.pop(dctx);
                                        },
                                        child: const Text('Save'),
                                      ),
                                    ],
                                  ),
                            );
                          },
                        ),
                        _contactRow(
                          Icons.email,
                          widget.store.contactEmail,
                          widget.contentEditable,
                          context,
                          (ctx) async {
                            final t = TextEditingController(
                              text: widget.store.contactEmail,
                            );
                            await showDialog<void>(
                              context: ctx,
                              builder:
                                  (dctx) => AlertDialog(
                                    title: const Text('Email'),
                                    content: TextField(controller: t),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(dctx),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          widget.store.contactEmail = t.text;
                                          widget.store.save();
                                          Navigator.pop(dctx);
                                        },
                                        child: const Text('Save'),
                                      ),
                                    ],
                                  ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Help Request Form
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.grey.shade50,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'NEED HELP?',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Submit a help request and we\'ll get back to you.',
                          style: TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _helpNameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Your Name',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _helpEmailCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Email Address',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _helpMessageCtrl,
                          decoration: const InputDecoration(
                            labelText: 'How can we help you?',
                            border: OutlineInputBorder(),
                            alignLabelWithHint: true,
                          ),
                          maxLines: 4,
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed:
                                _submittingHelp ? null : _submitHelpRequest,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFFC024),
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child:
                                _submittingHelp
                                    ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                    : const Text('SUBMIT HELP REQUEST'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _contactRow(
    IconData icon,
    String text,
    bool edit,
    BuildContext context,
    Future<void> Function(BuildContext ctx) onEdit,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
          if (edit)
            IconButton(
              icon: const Icon(Icons.edit, size: 18),
              onPressed: () => onEdit(context),
            ),
        ],
      ),
    );
  }
}

class _InquireForm extends StatefulWidget {
  const _InquireForm();

  @override
  State<_InquireForm> createState() => _InquireFormState();
}

class _InquireFormState extends State<_InquireForm> {
  // Event Information Controllers
  final _eventTitle = TextEditingController();
  final _customer = TextEditingController();
  final _contactPerson = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  final _guests = TextEditingController();
  final _dateController = TextEditingController();
  final _timeController = TextEditingController();

  // State
  String _eventType = 'Birthday';
  String _formality = 'casual';
  bool _submitting = false;

  // Service Type Selection
  String _serviceType = 'catering'; // 'catering' or 'catering+event'

  // Catering Service for small orders (< 50 PAX)
  bool?
  _cateringServiceSelected; // null = not selected yet, true/false for selection

  // Menu Selection State
  String _menuChoice = 'suggest'; // 'yes' or 'suggest'
  final Map<String, String> _selectedPaxOptions = {}; // dishId -> paxOption
  final List<String> _selectedDishIds = [];

  // Set Menu Pax Selection State
  final Map<String, String> _setMenuDishPaxOptions =
      {}; // dishId -> paxOption for set menu dishes

  // Event Design State
  bool _wantsCustomDesign = false;

  // Set Menus (for suggest option)
  final List<_SetMenuOption> _setMenus = [];

  // Custom dishes (when curating own menu)
  final List<_CustomDish> _customDishes = [];
  final _customDishNameCtrl = TextEditingController();
  final _customDishDescCtrl = TextEditingController();

  // Event Design State (photos and theme)
  final List<String> _designPhotoUrls = []; // For uploaded/linked photos
  final _designPhotoCtrl = TextEditingController();
  int? _focusedPhotoIndex;
  final _themeRequestCtrl =
      TextEditingController(); // For Macrina's theme request

  @override
  void initState() {
    super.initState();
    SetMenuStore.instance.addListener(_onSetMenusChanged);
    MenuStore.instance.addListener(_onMenuChanged);
    // Ensure set menus are loaded
    if (SetMenuStore.instance.activeSetMenus.isEmpty) {
      SetMenuStore.instance.loadSetMenus();
    }
    // Ensure dishes are loaded for set menu display
    if (MenuStore.instance.activeDishes.isEmpty) {
      MenuStore.instance.loadDishes();
    }
    // Load customer data if logged in
    _loadCustomerData();
  }

  Future<void> _loadCustomerData() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('customer_token');
    final customerData = prefs.getString('customer_data');

    if (token != null && token.isNotEmpty && customerData != null) {
      // User is logged in, auto-fill contact info
      final data = jsonDecode(customerData);
      if (mounted) {
        setState(() {
          _contactPerson.text = data['fullName'] ?? '';
          _email.text = data['email'] ?? '';
          _phone.text = data['phone'] ?? '';
        });
      }
    } else {
      // User is not logged in, show login dialog
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          final result = await showDialog(
            context: context,
            builder:
                (context) => const CustomerLoginPage(redirectToCheckout: true),
          );
          if (result != null) {
            // Reload customer data after login
            await _loadCustomerData();
          }
        });
      }
    }
  }

  String? _selectedSetMenuId;

  void _onSetMenusChanged() {
    if (mounted) setState(() {});
  }

  void _onMenuChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    SetMenuStore.instance.removeListener(_onSetMenusChanged);
    MenuStore.instance.removeListener(_onMenuChanged);
    _customDishNameCtrl.dispose();
    _customDishDescCtrl.dispose();
    _designPhotoCtrl.dispose();
    _themeRequestCtrl.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _dateController.text =
            '${picked.month.toString().padLeft(2, '0')}/${picked.day.toString().padLeft(2, '0')}/${picked.year}';
      });
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        _timeController.text = picked.format(context);
      });
    }
  }

  Future<void> _submit() async {
    final missing = <String>[];
    final isCateringOnly = _serviceType == 'catering';

    // Only validate event-specific fields for catering+event
    if (!isCateringOnly) {
      if (_eventTitle.text.trim().isEmpty) missing.add('event title');
    }
    if (_customer.text.trim().isEmpty) missing.add('customer name');
    if (_contactPerson.text.trim().isEmpty) missing.add('contact person');
    if (_phone.text.trim().isEmpty) missing.add('phone');
    if (_email.text.trim().isEmpty) missing.add('email');
    if (_address.text.trim().isEmpty) missing.add('city / address');
    if (_dateController.text.trim().isEmpty) missing.add('event date');
    if (_timeController.text.trim().isEmpty) missing.add('event time');
    final g = int.tryParse(_guests.text.trim());
    if (g == null || g < 1) missing.add('guest count');

    // Menu is required
    if (_menuChoice == 'yes' &&
        _selectedDishIds.isEmpty &&
        _customDishes.isEmpty) {
      missing.add('menu (select dishes or add custom dishes)');
    } else if (_menuChoice == 'suggest' && _selectedSetMenuId == null) {
      missing.add('menu (select a set menu)');
    }

    if (missing.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Complete: ${missing.join(', ')}')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      // Build menu items
      List<Map<String, dynamic>> menuItems = [];
      if (_menuChoice == 'yes') {
        // Curated menu - include selected dishes
        for (final dishId in _selectedDishIds) {
          final dish = MenuStore.instance.allDishes.firstWhere(
            (d) => d.id == dishId,
          );
          final paxOption =
              _selectedPaxOptions[dishId] ?? dish.paxOptions.first;
          menuItems.add({
            'dishId': dishId,
            'dishName': dish.name,
            'paxOption': paxOption,
            'price': dish.price,
            'isCustom': false,
          });
        }
        // Add custom dishes
        for (final customDish in _customDishes) {
          menuItems.add({
            'dishId': customDish.id,
            'dishName': customDish.name,
            'paxOption': 'Custom',
            'price': 0,
            'isCustom': true,
            'description': customDish.description,
          });
        }
      } else if (_selectedSetMenuId != null) {
        // Set menu selected - use SetMenuStore
        final setMenu = SetMenuStore.instance.activeSetMenus.firstWhere(
          (s) => s.id == _selectedSetMenuId,
        );
        for (final dishId in setMenu.dishIds) {
          final dish = MenuStore.instance.allDishes.firstWhere(
            (d) => d.id == dishId,
          );
          final paxOption =
              _setMenuDishPaxOptions[dishId] ?? dish.paxOptions.first;
          menuItems.add({
            'dishId': dishId,
            'dishName': dish.name,
            'paxOption': paxOption,
            'price': dish.price,
            'isCustom': false,
          });
        }
      }

      final now = DateTime.now();
      final date =
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      await PublicEventsApi.instance.submitOnlineInquiry(
        payload: {
          'orderType':
              _serviceType == 'catering' ? 'catering' : 'catering_event',
          'eventTitle':
              _serviceType == 'catering' ? '' : _eventTitle.text.trim(),
          'eventType': _serviceType == 'catering' ? null : _eventType,
          'formalityLevel': _serviceType == 'catering' ? null : _formality,
          'customerName': _customer.text.trim(),
          'contactPerson': _contactPerson.text.trim(),
          'contactNumber': _phone.text.trim(),
          'emailAddress': _email.text.trim(),
          'scheduleSlots': [
            {
              'date': date,
              'startTime': _timeController.text.trim(),
              'endTime': '14:00',
            },
          ],
          'address': _address.text.trim(),
          'guestCount': g,
          'menu': menuItems,
          'themeDesign': {
            'picksBase64': _designPhotoUrls,
            'tintEnabled': false,
            'tintColorHex': null,
            'colorPrompt': _themeRequestCtrl.text.trim(),
            'wantsCustomDesign': _wantsCustomDesign,
            'customerThemeRequest':
                _wantsCustomDesign ? null : _themeRequestCtrl.text.trim(),
          },
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inquiry submitted. We\'ll get back to you soon!'),
        ),
      );
      // Reset form after successful submission
      _resetForm();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not submit. Is the server running?'),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _resetForm() {
    setState(() {
      // Clear all text controllers
      _eventTitle.clear();
      _customer.clear();
      _contactPerson.clear();
      _phone.clear();
      _email.clear();
      _address.clear();
      _guests.clear();
      _dateController.clear();
      _timeController.clear();
      _themeRequestCtrl.clear();
      _designPhotoCtrl.clear();

      // Reset state variables to initial values
      _eventType = 'Birthday';
      _formality = 'casual';
      _serviceType = 'catering';
      _cateringServiceSelected = null;
      _menuChoice = 'suggest';
      _wantsCustomDesign = false;
      _selectedSetMenuId = null;

      // Clear collections
      _selectedPaxOptions.clear();
      _selectedDishIds.clear();
      _setMenuDishPaxOptions.clear();
      _setMenus.clear();
      _customDishes.clear();
      _designPhotoUrls.clear();
      _focusedPhotoIndex = null;

      // Keep customer info if logged in (reload from saved data)
      _loadCustomerData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isDesktop(context) ? 1200 : double.infinity,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title
              Text(
                'Inquire',
                textAlign: TextAlign.center,
                style: GoogleFonts.dancingScript(
                  fontSize: 42,
                  color: Colors.red.shade400,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFFFC024)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'INQUIRY FORM',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Service Type Selection
              _buildServiceTypeSelection(),
              const SizedBox(height: 24),

              // Three Column Layout
              isDesktop(context)
                  ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildEventInfoColumn()),
                      const SizedBox(width: 16),
                      Expanded(child: _buildMenuColumn()),
                      const SizedBox(width: 16),
                      if (_serviceType == 'catering+event')
                        Expanded(child: _buildEventDesignColumn()),
                    ],
                  )
                  : Column(
                    children: [
                      _buildEventInfoColumn(),
                      const SizedBox(height: 16),
                      _buildMenuColumn(),
                      const SizedBox(height: 16),
                      if (_serviceType == 'catering+event')
                        _buildEventDesignColumn(),
                    ],
                  ),

              const SizedBox(height: 32),
              // Submit Button
              Center(
                child: SizedBox(
                  width: 300,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      side: const BorderSide(
                        color: Color(0xFF4CAF50),
                        width: 2,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child:
                        _submitting
                            ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Text(
                              'SUBMIT INQUIRY',
                              style: TextStyle(fontWeight: FontWeight.bold),
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

  Widget _buildServiceTypeSelection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          const Text(
            'WHAT SERVICE DO YOU NEED?',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildServiceTypeButton('Catering Only', 'catering'),
              const SizedBox(width: 16),
              _buildServiceTypeButton('Catering + Event', 'catering+event'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildServiceTypeButton(String label, String value) {
    final isSelected = _serviceType == value;
    return ElevatedButton(
      onPressed: () => setState(() => _serviceType = value),
      style: ElevatedButton.styleFrom(
        backgroundColor:
            isSelected ? const Color(0xFFFFC107) : Colors.grey.shade200,
        foregroundColor: Colors.black,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isSelected ? const Color(0xFFFFC107) : Colors.grey.shade400,
          ),
        ),
      ),
      child: Text(label),
    );
  }

  Widget _buildEventInfoColumn() {
    final isCateringOnly = _serviceType == 'catering';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFC107),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isCateringOnly ? 'ORDER INFORMATION' : 'EVENT INFORMATION',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          const SizedBox(height: 16),
          // Only show event fields for catering+event
          if (!isCateringOnly) ...[
            _buildTextField(_eventTitle, 'EVENT TITLE'),
            const SizedBox(height: 12),
            _buildDropdown('EVENT TYPE', _eventType, [
              'Wedding',
              'Birthday',
              'Corporate',
              'Private Party',
              'Sports',
              'Government',
              'Show',
              'Educational',
              'Reunion',
              'Gala',
              'Dinner',
              'Other',
            ], (v) => setState(() => _eventType = v)),
            const SizedBox(height: 12),
            _buildDropdown(
              'FORMALITY LEVEL',
              _formality,
              ['casual', 'semi_formal', 'formal'],
              (v) => setState(() => _formality = v),
              displayMap: {
                'casual': 'Casual',
                'semi_formal': 'Semi-formal',
                'formal': 'Formal',
              },
            ),
            const SizedBox(height: 12),
          ],
          _buildTextField(_customer, 'CUSTOMER NAME'),
          const SizedBox(height: 12),
          _buildTextField(_contactPerson, 'CONTACT PERSON'),
          const SizedBox(height: 12),
          _buildTextField(
            _phone,
            'CONTACT NUMBER',
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            _email,
            'EMAIL ADDRESS',
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),
          _buildTextField(_address, 'Address'),
          const SizedBox(height: 12),
          // Date/Time Row
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _dateController,
                  readOnly: true,
                  onTap: _selectDate,
                  decoration: InputDecoration(
                    labelText: 'DATE/TIME OF EVENT',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: _selectDate,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _selectTime,
                icon: const Icon(Icons.access_time),
              ),
              IconButton(
                onPressed: () {
                  // Add another date/time slot
                },
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _guests,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'NO OF GUESTS',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 10,
              ),
            ),
            style: const TextStyle(fontSize: 13),
            onChanged:
                (value) => setState(() {
                  // Reset catering service selection when guest count changes
                  final count = int.tryParse(value) ?? 0;
                  if (count >= 50) {
                    _cateringServiceSelected = null;
                  }
                }),
          ),
          const SizedBox(height: 12),
          // Catering Service radio for small orders (< 50 PAX)
          _buildCateringServiceOption(),
        ],
      ),
    );
  }

  Widget _buildCateringServiceOption() {
    // Check if guest count is less than 50
    final guestCount = int.tryParse(_guests.text) ?? 0;
    if (guestCount >= 50 || guestCount <= 0) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'CATERING SERVICE',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: RadioListTile<bool>(
                title: const Text('Yes'),
                value: true,
                groupValue: _cateringServiceSelected,
                onChanged: (v) => setState(() => _cateringServiceSelected = v),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            Expanded(
              child: RadioListTile<bool>(
                title: const Text('No'),
                value: false,
                groupValue: _cateringServiceSelected,
                onChanged: (v) => setState(() => _cateringServiceSelected = v),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
        if (_cateringServiceSelected == true)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              border: Border.all(color: Colors.orange.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber,
                  color: Colors.orange.shade700,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'For catering orders with less than 50 PAX will incur additional charges.',
                    style: TextStyle(
                      color: Colors.orange.shade700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildMenuColumn() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFC107),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'MENU',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'WOULD YOU LIKE TO CURATE YOUR OWN MENU?',
            style: TextStyle(fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildMenuChoiceButton('YES!', 'yes'),
              const SizedBox(width: 12),
              _buildMenuChoiceButton(
                'NO I\'D LIKE MACRINAS TO\nSUGGEST ME A MENU INSTEAD',
                'suggest',
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Menu Content
          if (_menuChoice == 'yes')
            _buildDishSelectionList()
          else if (_selectedSetMenuId != null)
            _buildSetMenuView()
          else
            _buildSetMenuSelection(),
        ],
      ),
    );
  }

  Widget _buildMenuChoiceButton(String label, String value) {
    final isSelected = _menuChoice == value;
    final isYes = value == 'yes';
    return ElevatedButton(
      onPressed: () => setState(() => _menuChoice = value),
      style: ElevatedButton.styleFrom(
        backgroundColor: isYes ? const Color(0xFFE8F5E9) : Colors.white,
        foregroundColor: Colors.black,
        side: BorderSide(
          color: isYes ? const Color(0xFF4CAF50) : Colors.red.shade300,
          width: 2,
        ),
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 11),
      ),
    );
  }

  Widget _buildDishSelectionList() {
    final dishes =
        MenuStore.instance.activeDishes
            .where((d) => d.category == 'catering')
            .toList();
    return Container(
      constraints: const BoxConstraints(maxHeight: 500),
      child: Column(
        children: [
          // Add Custom Dish Button
          ElevatedButton.icon(
            onPressed: _showAddCustomDishDialog,
            icon: const Icon(Icons.add),
            label: const Text('Add Custom Dish'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFC024),
              foregroundColor: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          // Custom Dishes Section
          if (_customDishes.isNotEmpty) ...[
            const Text(
              'Custom Dishes:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ..._customDishes.map(
              (customDish) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                color: Colors.amber.shade50,
                child: ListTile(
                  leading: const Icon(
                    Icons.edit_note,
                    size: 40,
                    color: Color(0xFFFFC024),
                  ),
                  title: Text(
                    customDish.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    customDish.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        _customDishes.removeWhere((d) => d.id == customDish.id);
                      });
                    },
                  ),
                ),
              ),
            ),
            const Divider(),
          ],
          // Catering Dishes from Menu
          Expanded(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: dishes.length,
              itemBuilder: (context, index) {
                final dish = dishes[index];
                final isSelected = _selectedDishIds.contains(dish.id);
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading:
                        dish.imageBase64 != null
                            ? Image.memory(
                              base64Decode(dish.imageBase64!),
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                            )
                            : const Icon(Icons.restaurant, size: 40),
                    title: Text(
                      dish.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('₱${dish.price}'),
                    trailing:
                        isSelected
                            ? DropdownButton<String>(
                              value:
                                  _selectedPaxOptions[dish.id] ??
                                  dish.paxOptions.first,
                              isDense: true,
                              items:
                                  dish.paxOptions
                                      .map(
                                        (p) => DropdownMenuItem(
                                          value: p,
                                          child: Text(p),
                                        ),
                                      )
                                      .toList(),
                              onChanged: (v) {
                                setState(() {
                                  _selectedPaxOptions[dish.id] = v!;
                                });
                              },
                            )
                            : null,
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedDishIds.remove(dish.id);
                          _selectedPaxOptions.remove(dish.id);
                        } else {
                          _selectedDishIds.add(dish.id);
                          _selectedPaxOptions[dish.id] = dish.paxOptions.first;
                        }
                      });
                    },
                    selected: isSelected,
                    selectedTileColor: Colors.green.shade50,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showAddCustomDishDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Add Custom Dish'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _customDishNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Dish Name',
                    hintText: 'e.g., Grilled Salmon with Lemon Butter',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _customDishDescCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    hintText: 'Special requests, ingredients, etc.',
                  ),
                  maxLines: 3,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (_customDishNameCtrl.text.trim().isNotEmpty) {
                    setState(() {
                      _customDishes.add(
                        _CustomDish(
                          id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
                          name: _customDishNameCtrl.text.trim(),
                          description: _customDishDescCtrl.text.trim(),
                        ),
                      );
                      _customDishNameCtrl.clear();
                      _customDishDescCtrl.clear();
                    });
                  }
                  Navigator.pop(context);
                },
                child: const Text('Add'),
              ),
            ],
          ),
    );
  }

  Widget _buildSetMenuSelection() {
    final setMenus = SetMenuStore.instance.activeSetMenus;
    if (setMenus.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'No set menus available. Please choose "YES!" to curate your own menu.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }
    return Column(
      children:
          setMenus.map((setMenu) {
            // Calculate total price for this set menu
            double totalPrice = 0;
            for (final dishId in setMenu.dishIds) {
              final dish = MenuStore.instance.allDishes.firstWhere(
                (d) => d.id == dishId,
                orElse:
                    () => MenuDish(
                      id: dishId,
                      name: 'Unknown',
                      category: '',
                      price: '0',
                      archived: false,
                      paxOptions: ['10 pax'],
                    ),
              );
              final price = double.tryParse(dish.price) ?? 0;
              final paxOption =
                  _setMenuDishPaxOptions[dishId] ?? dish.paxOptions.first;
              final paxCount =
                  int.tryParse(paxOption.replaceAll(RegExp(r'[^0-9]'), '')) ??
                  10;
              totalPrice += price * (paxCount / 10);
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(
                  setMenu.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${setMenu.dishIds.length} dishes',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '₱${totalPrice.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFFC024),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                isThreeLine: true,
                trailing: Radio<String>(
                  value: setMenu.id,
                  groupValue: _selectedSetMenuId,
                  onChanged: (v) {
                    setState(() {
                      _selectedSetMenuId = v;
                      // Initialize pax options for all dishes in this set menu
                      for (final dishId in setMenu.dishIds) {
                        final dish = MenuStore.instance.allDishes.firstWhere(
                          (d) => d.id == dishId,
                          orElse:
                              () => MenuDish(
                                id: dishId,
                                name: 'Unknown',
                                category: '',
                                price: '0',
                                archived: false,
                                paxOptions: ['10 pax'],
                              ),
                        );
                        if (!_setMenuDishPaxOptions.containsKey(dishId)) {
                          _setMenuDishPaxOptions[dishId] =
                              dish.paxOptions.first;
                        }
                      }
                    });
                  },
                ),
                onTap: () {
                  setState(() {
                    _selectedSetMenuId = setMenu.id;
                    // Initialize pax options for all dishes in this set menu
                    for (final dishId in setMenu.dishIds) {
                      final dish = MenuStore.instance.allDishes.firstWhere(
                        (d) => d.id == dishId,
                        orElse:
                            () => MenuDish(
                              id: dishId,
                              name: 'Unknown',
                              category: '',
                              price: '0',
                              archived: false,
                              paxOptions: ['10 pax'],
                            ),
                      );
                      if (!_setMenuDishPaxOptions.containsKey(dishId)) {
                        _setMenuDishPaxOptions[dishId] = dish.paxOptions.first;
                      }
                    }
                  });
                },
              ),
            );
          }).toList(),
    );
  }

  Widget _buildSetMenuView() {
    final setMenu = SetMenuStore.instance.activeSetMenus.firstWhere(
      (s) => s.id == _selectedSetMenuId,
    );

    // Calculate total price for this set menu
    double totalPrice = 0;
    for (final dishId in setMenu.dishIds) {
      final dish = MenuStore.instance.allDishes.firstWhere(
        (d) => d.id == dishId,
        orElse:
            () => MenuDish(
              id: dishId,
              name: 'Unknown Dish',
              category: '',
              price: '0',
              archived: false,
              paxOptions: ['10 pax'],
            ),
      );
      final price = double.tryParse(dish.price) ?? 0;
      final paxOption = _setMenuDishPaxOptions[dishId] ?? dish.paxOptions.first;
      final paxCount =
          int.tryParse(paxOption.replaceAll(RegExp(r'[^0-9]'), '')) ?? 10;
      totalPrice += price * (paxCount / 10);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              setMenu.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              '₱${totalPrice.toStringAsFixed(2)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Color(0xFFFFC024),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text('${setMenu.dishIds.length} dishes'),
        const SizedBox(height: 16),
        const Text(
          'Dishes in this set:',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        ...setMenu.dishIds.map((dishId) {
          final dish = MenuStore.instance.allDishes.firstWhere(
            (d) => d.id == dishId,
            orElse:
                () => MenuDish(
                  id: dishId,
                  name: 'Unknown Dish',
                  category: '',
                  price: '0',
                  archived: false,
                  paxOptions: ['10 pax'],
                ),
          );
          final price = double.tryParse(dish.price) ?? 0;
          final paxOption =
              _setMenuDishPaxOptions[dishId] ?? dish.paxOptions.first;
          final paxCount =
              int.tryParse(paxOption.replaceAll(RegExp(r'[^0-9]'), '')) ?? 10;
          final adjustedPrice = price * (paxCount / 10);

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              dense: true,
              leading:
                  dish.imageBase64 != null
                      ? Image.memory(
                        base64Decode(dish.imageBase64!),
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                      )
                      : const Icon(Icons.restaurant, size: 32),
              title: Text(dish.name, style: const TextStyle(fontSize: 13)),
              subtitle: Text(
                '₱${adjustedPrice.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFFFFC024),
                ),
              ),
              trailing: DropdownButton<String>(
                value: _setMenuDishPaxOptions[dishId] ?? dish.paxOptions.first,
                isDense: true,
                style: const TextStyle(fontSize: 12),
                items:
                    dish.paxOptions
                        .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                        .toList(),
                onChanged: (v) {
                  setState(() {
                    _setMenuDishPaxOptions[dishId] = v!;
                  });
                },
              ),
            ),
          );
        }),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: () => setState(() => _selectedSetMenuId = null),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade100,
            foregroundColor: Colors.red,
          ),
          child: const Text('Change Set Menu'),
        ),
      ],
    );
  }

  Widget _buildEventDesignColumn() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'EVENT DESIGN',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 16),
          const Text(
            'WE CAN SUGGEST SOME DESIGNS FOR\nINSPIRATION FOR YOU TO PUT TOGETHER!\n\nJUST LET US KNOW HOW YOU\'D LIKE YOUR\nEVENT TO LOOK!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11),
          ),
          const SizedBox(height: 24),
          // Show selected state
          if (_wantsCustomDesign) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                border: Border.all(color: const Color(0xFF4CAF50)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  const Row(
                    children: [
                      Icon(Icons.check_circle, color: Color(0xFF4CAF50)),
                      SizedBox(width: 8),
                      Text(
                        'You will create your event design',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  if (_designPhotoUrls.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('${_designPhotoUrls.length} photo(s) added'),
                  ],
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _showCustomDesignDialog,
                    child: const Text('Manage Photos'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => setState(() => _wantsCustomDesign = false),
              child: const Text('Change to Macrina\'s Design'),
            ),
          ] else if (_themeRequestCtrl.text.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                border: Border.all(color: Colors.red.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  const Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.red),
                      SizedBox(width: 8),
                      Text(
                        'Macrina\'s will create your design',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Theme: ${_themeRequestCtrl.text}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => setState(() => _wantsCustomDesign = true),
              child: const Text('Change to My Design'),
            ),
          ] else ...[
            ElevatedButton(
              onPressed: () {
                setState(() => _wantsCustomDesign = true);
                _showCustomDesignDialog();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                side: const BorderSide(color: Color(0xFF4CAF50), width: 2),
                elevation: 0,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('CREATE MY EVENT DESIGN'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                _showMacrinaDesignDialog();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                side: BorderSide(color: Colors.red.shade300, width: 2),
                elevation: 0,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'NO I\'D LIKE MACRINAS TO CREATE MY\nEVENT DESIGN INSTEAD',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showMacrinaDesignDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Macrina\'s Will Create Your Design'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Let us know what themes, colors, or styles you\'d like for your event.',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _themeRequestCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Theme/Style Preferences',
                    hintText:
                        'e.g., Rustic, Elegant, Garden theme, Pink and gold colors...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 4,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (_themeRequestCtrl.text.trim().isNotEmpty) {
                    setState(() => _wantsCustomDesign = false);
                  }
                  Navigator.pop(context);
                },
                child: const Text('Confirm'),
              ),
            ],
          ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 10,
        ),
      ),
      style: const TextStyle(fontSize: 13),
    );
  }

  Widget _buildDropdown(
    String label,
    String value,
    List<String> options,
    Function(String) onChanged, {
    Map<String, String>? displayMap,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 10,
        ),
      ),
      items:
          options
              .map(
                (o) => DropdownMenuItem(
                  value: o,
                  child: Text(
                    displayMap?[o] ?? o,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              )
              .toList(),
      onChanged: (v) => onChanged(v!),
    );
  }

  void _showCustomDesignDialog() {
    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: const Text('Create Your Event Design'),
                  content: SizedBox(
                    width: 500,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Upload or link inspiration photos for your event design:',
                            style: TextStyle(fontSize: 13),
                          ),
                          const SizedBox(height: 16),
                          // Photo URL input
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _designPhotoCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Photo URL',
                                    hintText: 'Paste image link here...',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () {
                                  if (_designPhotoCtrl.text.trim().isNotEmpty) {
                                    setDialogState(() {
                                      _designPhotoUrls.add(
                                        _designPhotoCtrl.text.trim(),
                                      );
                                      _designPhotoCtrl.clear();
                                    });
                                    setState(() {});
                                  }
                                },
                                child: const Text('Add'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Photo count
                          Text(
                            '${_designPhotoUrls.length} photo(s) added',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          // List of added URLs (for verification)
                          if (_designPhotoUrls.isNotEmpty) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: _designPhotoUrls.asMap().entries.map((entry) {
                                  final idx = entry.key;
                                  final url = entry.value;
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 2),
                                    child: Row(
                                      children: [
                                        Text(
                                          '${idx + 1}. ',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade600,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            url.length > 50 ? '${url.substring(0, 50)}...' : url,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey.shade700,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          // Focused photo display (larger)
                          if (_designPhotoUrls.isNotEmpty) ...[
                            Container(
                              height: 200,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  _focusedPhotoIndex != null &&
                                          _focusedPhotoIndex! <
                                              _designPhotoUrls.length
                                      ? _designPhotoUrls[_focusedPhotoIndex!]
                                      : _designPhotoUrls.first,
                                  fit: BoxFit.contain,
                                  errorBuilder:
                                      (ctx, err, stack) => const Center(
                                        child: Icon(
                                          Icons.broken_image,
                                          size: 48,
                                          color: Colors.grey,
                                        ),
                                      ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Photo carousel (smaller thumbnails)
                            SizedBox(
                              height: 80,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: _designPhotoUrls.length,
                                itemBuilder: (ctx, index) {
                                  final isFocused =
                                      _focusedPhotoIndex == index ||
                                      (_focusedPhotoIndex == null &&
                                          index == 0);
                                  return GestureDetector(
                                    onTap: () {
                                      setDialogState(() {
                                        _focusedPhotoIndex = index;
                                      });
                                    },
                                    child: Container(
                                      width: 80,
                                      margin: const EdgeInsets.only(right: 8),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color:
                                              isFocused
                                                  ? const Color(0xFFFFC024)
                                                  : Colors.grey.shade300,
                                          width: isFocused ? 3 : 1,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            Image.network(
                                              _designPhotoUrls[index],
                                              fit: BoxFit.cover,
                                              errorBuilder:
                                                  (ctx, err, stack) =>
                                                      const Center(
                                                        child: Icon(
                                                          Icons.broken_image,
                                                          color: Colors.grey,
                                                        ),
                                                      ),
                                            ),
                                            // Delete button
                                            Positioned(
                                              top: 2,
                                              right: 2,
                                              child: GestureDetector(
                                                onTap: () {
                                                  setDialogState(() {
                                                    _designPhotoUrls.removeAt(
                                                      index,
                                                    );
                                                    if (_focusedPhotoIndex !=
                                                            null &&
                                                        _focusedPhotoIndex! >=
                                                            index) {
                                                      _focusedPhotoIndex =
                                                          _focusedPhotoIndex! >
                                                                  0
                                                              ? _focusedPhotoIndex! -
                                                                  1
                                                              : null;
                                                    }
                                                  });
                                                  setState(() {});
                                                },
                                                child: Container(
                                                  padding: const EdgeInsets.all(
                                                    2,
                                                  ),
                                                  decoration:
                                                      const BoxDecoration(
                                                        color: Colors.red,
                                                        shape: BoxShape.circle,
                                                      ),
                                                  child: const Icon(
                                                    Icons.close,
                                                    size: 14,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Done'),
                    ),
                  ],
                ),
          ),
    );
  }
}
