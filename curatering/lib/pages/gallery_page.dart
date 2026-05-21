import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/website_content_store.dart';
import '../utils/gallery_search.dart';
import '../utils/website_image_utils.dart';
import '../widgets/centered_viewport_scroll.dart';
import '../widgets/customer_website_topbar.dart';
import '../widgets/pexels_attribution_badge.dart';

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

class GalleryPage extends StatefulWidget {
  const GalleryPage({
    super.key,
    this.contentEditable = false,
    this.showStaffChrome = true,
  });

  final bool contentEditable;
  final bool showStaffChrome;

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  int? _galleryDetailIndex;
  String _gallerySearchQuery = '';
  String _selectedGalleryCategoryId = 'ALL';
  String _selectedGalleryTag = 'ALL';

  @override
  void initState() {
    super.initState();
    WebsiteContentStore.instance.ensureLoaded().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final w = WebsiteContentStore.instance;

    if (_galleryDetailIndex != null) {
      final cat = w.galleryCategories[_galleryDetailIndex!];
      return Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CustomerWebsiteTopBar(
              showCartAndCustomerAuth: !widget.contentEditable,
            ),
            Expanded(
              child: CenteredViewportScroll(
                padding: websitePagePadding(context),
                child: ListenableBuilder(
                  listenable: w,
                  builder: (context, _) => _buildGalleryDetail(w, cat),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CustomerWebsiteTopBar(
            showCartAndCustomerAuth: !widget.contentEditable,
          ),
          Expanded(
            child: CenteredViewportScroll(
              padding: websitePagePadding(context),
              child: ListenableBuilder(
                listenable: w,
                builder: (context, _) => _buildGallery(w),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<String> _allGalleryTags(Iterable<GalleryCategoryData> categories) {
    final tags = <String>{};
    for (final cat in categories) {
      for (final image in cat.images) {
        for (final tag in image.tags) {
          final trimmed = tag.trim();
          if (trimmed.isNotEmpty) tags.add(trimmed);
        }
      }
    }
    final sorted =
        tags.toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return sorted;
  }

  bool _matchesSelectedCategory(GalleryCategoryData cat) {
    return _selectedGalleryCategoryId == 'ALL' ||
        cat.id == _selectedGalleryCategoryId;
  }

  bool _matchesSelectedTag(GalleryCategoryData cat) {
    if (_selectedGalleryTag == 'ALL') return true;
    final selected = _selectedGalleryTag.toLowerCase();
    return cat.images.any(
      (image) => image.tags.any((tag) => tag.toLowerCase() == selected),
    );
  }

  List<GalleryImageData> _filteredGalleryImages(GalleryCategoryData cat) {
    final bySearch = filterGalleryImages(cat, _gallerySearchQuery);
    if (_selectedGalleryTag == 'ALL') return bySearch;
    final selected = _selectedGalleryTag.toLowerCase();
    return bySearch
        .where(
          (image) => image.tags.any((tag) => tag.toLowerCase() == selected),
        )
        .toList();
  }

  Widget _buildFilterChips({
    required String title,
    required List<Widget> chips,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 42,
          child: ListView(scrollDirection: Axis.horizontal, children: chips),
        ),
      ],
    );
  }

  Widget _buildGallery(WebsiteContentStore w) {
    final allTags = _allGalleryTags(w.galleryCategories);
    final categories =
        w.galleryCategories
            .where((c) => galleryCategoryMatchesSearch(c, _gallerySearchQuery))
            .where(_matchesSelectedCategory)
            .where(_matchesSelectedTag)
            .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Text(
          'GALLERY',
          style: GoogleFonts.getFont(
            _primaryFont,
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1E1E1E),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          onChanged:
              (v) =>
                  setState(() => _gallerySearchQuery = v.trim().toLowerCase()),
          decoration: InputDecoration(
            hintText: 'SEARCH BY TAG OR CATEGORY',
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(height: 16),
        _buildFilterChips(
          title: 'CATEGORIES',
          chips: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: const Text('ALL'),
                selected: _selectedGalleryCategoryId == 'ALL',
                onSelected:
                    (_) => setState(() => _selectedGalleryCategoryId = 'ALL'),
              ),
            ),
            ...w.galleryCategories.map(
              (cat) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(cat.label),
                  selected: _selectedGalleryCategoryId == cat.id,
                  onSelected:
                      (_) => setState(() {
                        _selectedGalleryCategoryId = cat.id;
                        _galleryDetailIndex = null;
                      }),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildFilterChips(
          title: 'TAGS',
          chips: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: const Text('ALL'),
                selected: _selectedGalleryTag == 'ALL',
                onSelected: (_) => setState(() => _selectedGalleryTag = 'ALL'),
              ),
            ),
            ...allTags.map(
              (tag) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(tag),
                  selected:
                      _selectedGalleryTag.toLowerCase() == tag.toLowerCase(),
                  onSelected: (_) => setState(() => _selectedGalleryTag = tag),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        if (categories.isEmpty)
          Center(
            child: Column(
              children: [
                const SizedBox(height: 80),
                Icon(
                  Icons.image_search_outlined,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'No gallery categories match these filters',
                  style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
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
              childAspectRatio: 1.2,
            ),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final cat = categories[index];
              final realIndex = w.galleryCategories.indexOf(cat);
              final visibleCount = _filteredGalleryImages(cat).length;

              return GestureDetector(
                onTap: () => setState(() => _galleryDetailIndex = realIndex),
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (cat.images.isNotEmpty)
                        Image.memory(
                          base64Decode(cat.images.first.imageBase64),
                          fit: BoxFit.cover,
                        )
                      else
                        Container(color: Colors.grey.shade300),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.7),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 16,
                        left: 16,
                        right: 16,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cat.label,
                              style: GoogleFonts.getFont(
                                _primaryFont,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$visibleCount images',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
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
        const SizedBox(height: 48),
        const PexelsAttributionBadge(photographer: 'Curatering Gallery'),
      ],
    );
  }

  Widget _buildGalleryDetail(WebsiteContentStore w, GalleryCategoryData cat) {
    final filteredImages = _filteredGalleryImages(cat);
    final allTags = _allGalleryTags([cat]);

    return Column(
      children: [
        const SizedBox(height: 24),
        Row(
          children: [
            FilledButton.tonal(
              onPressed: () => setState(() => _galleryDetailIndex = null),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1E1E1E),
                foregroundColor: Colors.white,
              ),
              child: const Text('BACK TO GALLERY'),
            ),
            if (widget.contentEditable) ...[
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: () async {
                  final b64s = await pickMultipleWebsiteImagesBase64();
                  if (b64s.isEmpty) return;
                  cat.addImagesFromBase64(b64s);
                  await w.save();
                  setState(() {});
                },
                icon: const Icon(Icons.add),
                label: const Text('ADD IMAGE'),
              ),
            ],
          ],
        ),
        const SizedBox(height: 24),
        TextField(
          onChanged:
              (v) =>
                  setState(() => _gallerySearchQuery = v.trim().toLowerCase()),
          decoration: InputDecoration(
            hintText: 'SEARCH BY TAG',
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        if (allTags.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildFilterChips(
            title: 'TAGS',
            chips: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: const Text('ALL'),
                  selected: _selectedGalleryTag == 'ALL',
                  onSelected:
                      (_) => setState(() => _selectedGalleryTag = 'ALL'),
                ),
              ),
              ...allTags.map(
                (tag) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(tag),
                    selected:
                        _selectedGalleryTag.toLowerCase() == tag.toLowerCase(),
                    onSelected:
                        (_) => setState(() => _selectedGalleryTag = tag),
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 32),
        if (filteredImages.isEmpty)
          Center(
            child: Column(
              children: [
                const SizedBox(height: 100),
                Icon(
                  Icons.image_not_supported,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'No images found',
                  style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
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
            ),
            itemCount: filteredImages.length,
            itemBuilder: (context, index) {
              final imgData = filteredImages[index];
              final fullIndex = cat.images.indexOf(imgData);
              return Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (imgData.imageBase64.isNotEmpty)
                      Image.memory(
                        base64Decode(imgData.imageBase64),
                        fit: BoxFit.cover,
                      )
                    else
                      Container(color: Colors.grey.shade300),
                    if (imgData.tags.isNotEmpty)
                      Positioned(
                        left: 8,
                        bottom: 8,
                        right: 8,
                        child: Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children:
                              imgData.tags
                                  .map(
                                    (t) => Chip(
                                      label: Text(
                                        t,
                                        style: const TextStyle(fontSize: 10),
                                      ),
                                      visualDensity: VisualDensity.compact,
                                      backgroundColor: Colors.white.withValues(
                                        alpha: 0.9,
                                      ),
                                    ),
                                  )
                                  .toList(),
                        ),
                      ),
                    if (widget.contentEditable)
                      Positioned(
                        right: 6,
                        top: 6,
                        child: IconButton(
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.delete, size: 18),
                          onPressed: () async {
                            if (fullIndex >= 0) cat.images.removeAt(fullIndex);
                            await w.save();
                            setState(() {});
                          },
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}
