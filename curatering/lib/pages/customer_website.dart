import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../auth/auth_session.dart';
import '../auth/roles.dart';
import '../services/menu_store.dart';
import '../services/public_events_api.dart';
import '../services/website_content_store.dart';

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
  int _navIndex = 0;
  int? _galleryDetailIndex;

  @override
  void initState() {
    super.initState();
    WebsiteContentStore.instance.ensureLoaded().then((_) {
      if (mounted) setState(() {});
    });
    MenuStore.instance.addListener(_onMenuChanged);
  }

  void _onMenuChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    MenuStore.instance.removeListener(_onMenuChanged);
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
                _navLink('Menu', 2),
                _navLink('Inquire Now', 3),
                _navLink('Contact Us', 4),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _navLink(String label, int index) {
    final on = _navIndex == index && _galleryDetailIndex == null;
    return InkWell(
      onTap: () => setState(() {
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
                child: const Text('MENU'),
              ),
              TextButton(
                onPressed: () => setState(() => _navIndex = 3),
                child: const Text('INQUIRE NOW'),
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
                    child: w.homeHeroImageBase64.isEmpty
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
                                          onPressed: () =>
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
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('Edit latest event'),
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
                                            onPressed: () => Navigator.pop(ctx),
                                            child: const Text('Cancel'),
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              w.latestEventTitle = title.text;
                                              w.latestEventSubtitle = sub.text;
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
                                      final b64 = i < list.length
                                          ? list[i]
                                          : null;
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
            children: dishes.map((d) {
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
                              d.imageBase64 != null && d.imageBase64!.isNotEmpty
                              ? _b64Image(d.imageBase64, fit: BoxFit.cover)
                              : Container(
                                  color: Colors.grey.shade200,
                                  child: const Icon(Icons.fastfood, size: 40),
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
                    child: i < w.eventDesignImageBase64.length
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
                crossAxisCount: isMobile(context)
                    ? 1
                    : isTablet(context)
                    ? 2
                    : 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.2,
              ),
              itemCount: cat.imageBase64List.length,
              itemBuilder: (ctx, i) => ClipRRect(
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
                      crossAxisCount: isMobile(context)
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
                      final thumb = c.imageBase64List.isNotEmpty
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
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('Category label'),
                                        content: TextField(controller: ctrl),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(ctx),
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

  Widget _buildPublicMenu() {
    final dishes = MenuStore.instance.activeDishes;
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
                'Menu',
                style: GoogleFonts.dancingScript(
                  fontSize: 42,
                  color: Colors.red.shade400,
                ),
              ),
              const SizedBox(height: 20),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: isMobile(context)
                      ? 1
                      : isTablet(context)
                      ? 2
                      : 3,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.85,
                ),
                itemCount: dishes.length,
                itemBuilder: (ctx, i) {
                  final d = dishes[i];
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
                                ? _b64Image(d.imageBase64, fit: BoxFit.cover)
                                : Container(
                                    color: Colors.grey.shade200,
                                    child: const Icon(Icons.fastfood, size: 48),
                                  ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            d.name.toUpperCase(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
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
        2 => _buildPublicMenu(),
        3 => const _InquireForm(),
        4 => _ContactSection(
          store: w,
          contentEditable: widget.contentEditable,
          pickB64: _pickImageB64,
        ),
        _ => _buildHome(w),
      };
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),

      /// ✅ Sticky header using NestedScrollView
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
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
                              onPressed: () => Navigator.pushReplacementNamed(
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
    );
  }
}

class _ContactSection extends StatelessWidget {
  const _ContactSection({
    required this.store,
    required this.contentEditable,
    required this.pickB64,
  });

  final WebsiteContentStore store;
  final bool contentEditable;
  final Future<String?> Function() pickB64;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
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
                          store.contactFacebook,
                          contentEditable,
                          context,
                          (ctx) async {
                            final t = TextEditingController(
                              text: store.contactFacebook,
                            );
                            await showDialog<void>(
                              context: ctx,
                              builder: (dctx) => AlertDialog(
                                content: TextField(controller: t),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(dctx),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      store.contactFacebook = t.text;
                                      store.save();
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
                          store.contactAddress,
                          contentEditable,
                          context,
                          (ctx) async {
                            final t = TextEditingController(
                              text: store.contactAddress,
                            );
                            await showDialog<void>(
                              context: ctx,
                              builder: (dctx) => AlertDialog(
                                content: TextField(controller: t, maxLines: 2),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(dctx),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      store.contactAddress = t.text;
                                      store.save();
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
                          store.contactHours,
                          contentEditable,
                          context,
                          (ctx) async {
                            final t = TextEditingController(
                              text: store.contactHours,
                            );
                            await showDialog<void>(
                              context: ctx,
                              builder: (dctx) => AlertDialog(
                                title: const Text('Hours'),
                                content: TextField(controller: t),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(dctx),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      store.contactHours = t.text;
                                      store.save();
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
                          store.contactPhone,
                          contentEditable,
                          context,
                          (ctx) async {
                            final t = TextEditingController(
                              text: store.contactPhone,
                            );
                            await showDialog<void>(
                              context: ctx,
                              builder: (dctx) => AlertDialog(
                                title: const Text('Phone'),
                                content: TextField(controller: t),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(dctx),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      store.contactPhone = t.text;
                                      store.save();
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
                          store.contactEmail,
                          contentEditable,
                          context,
                          (ctx) async {
                            final t = TextEditingController(
                              text: store.contactEmail,
                            );
                            await showDialog<void>(
                              context: ctx,
                              builder: (dctx) => AlertDialog(
                                title: const Text('Email'),
                                content: TextField(controller: t),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(dctx),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      store.contactEmail = t.text;
                                      store.save();
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
  final _eventTitle = TextEditingController();
  final _customer = TextEditingController();
  final _contactPerson = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  final _guests = TextEditingController();
  String _eventType = 'Wedding';
  String _formality = 'casual';
  bool _submitting = false;

  @override
  void dispose() {
    _eventTitle.dispose();
    _customer.dispose();
    _contactPerson.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    _guests.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final missing = <String>[];
    if (_eventTitle.text.trim().isEmpty) missing.add('event title');
    if (_customer.text.trim().isEmpty) missing.add('customer name');
    if (_contactPerson.text.trim().isEmpty) missing.add('contact person');
    if (_phone.text.trim().isEmpty) missing.add('phone');
    if (_email.text.trim().isEmpty) missing.add('email');
    if (_address.text.trim().isEmpty) missing.add('city / address');
    final g = int.tryParse(_guests.text.trim());
    if (g == null || g < 1) missing.add('guest count');
    if (missing.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Complete: ${missing.join(', ')}')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final now = DateTime.now();
      final date =
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      await PublicEventsApi.instance.submitOnlineInquiry(
        payload: {
          'eventTitle': _eventTitle.text.trim(),
          'eventType': _eventType,
          'formalityLevel': _formality,
          'customerName': _customer.text.trim(),
          'contactPerson': _contactPerson.text.trim(),
          'contactNumber': _phone.text.trim(),
          'emailAddress': _email.text.trim(),
          'scheduleSlots': [
            {'date': date, 'startTime': '10:00', 'endTime': '14:00'},
          ],
          'address': _address.text.trim(),
          'guestCount': g,
          'menu': [],
          'themeDesign': {
            'picksBase64': <String>[],
            'tintEnabled': false,
            'tintColorHex': null,
            'colorPrompt': '',
          },
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inquiry submitted. We\'ll get back to you soon!'),
        ),
      );
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

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isDesktop(context) ? 1100 : double.infinity,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
              TextField(
                controller: _eventTitle,
                decoration: const InputDecoration(
                  labelText: 'EVENT TITLE',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _eventType,
                decoration: const InputDecoration(
                  labelText: 'EVENT TYPE',
                  border: OutlineInputBorder(),
                ),
                items:
                    const [
                          'Wedding',
                          'Birthday',
                          'Corporate',
                          'Private Party',
                          'Other',
                        ]
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                onChanged: (v) => setState(() => _eventType = v ?? _eventType),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _formality,
                decoration: const InputDecoration(
                  labelText: 'FORMALITY',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'casual', child: Text('Casual')),
                  DropdownMenuItem(
                    value: 'semi_formal',
                    child: Text('Semi-formal'),
                  ),
                  DropdownMenuItem(value: 'formal', child: Text('Formal')),
                ],
                onChanged: (v) => setState(() => _formality = v ?? _formality),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _contactPerson,
                decoration: const InputDecoration(
                  labelText: 'CONTACT PERSON',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _phone,
                decoration: const InputDecoration(
                  labelText: 'CONTACT NUMBER',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _email,
                decoration: const InputDecoration(
                  labelText: 'EMAIL',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _customer,
                decoration: const InputDecoration(
                  labelText: 'CUSTOMER / COMPANY NAME',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _address,
                decoration: const InputDecoration(
                  labelText: 'CITY OF EVENT',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _guests,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'NO. OF GUESTS',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1DB954),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _submitting
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('SUBMIT INQUIRY'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
