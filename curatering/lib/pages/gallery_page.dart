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

  Widget _buildFilterDropdown({
    required String title,
    required String value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
          isExpanded: true,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
          ),
          items: items,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildGallerySearchField({required String hintText}) {
    return TextField(
      onChanged:
          (v) => setState(() => _gallerySearchQuery = v.trim().toLowerCase()),
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: const Icon(Icons.search),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildGalleryToolbar({
    required Widget searchField,
    required List<Widget> filters,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final inline = constraints.maxWidth >= 860;
        final filterColumn = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < filters.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              filters[i],
            ],
          ],
        );

        if (!inline) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [searchField, const SizedBox(height: 16), filterColumn],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 320, child: searchField),
            const SizedBox(width: 16),
            Expanded(child: filterColumn),
          ],
        );
      },
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
        _buildGalleryToolbar(
          searchField: _buildGallerySearchField(
            hintText: 'SEARCH BY TAG OR CATEGORY',
          ),
          filters: [
            _buildFilterDropdown(
              title: 'CATEGORIES',
              value:
                  w.galleryCategories.any(
                        (cat) => cat.id == _selectedGalleryCategoryId,
                      )
                      ? _selectedGalleryCategoryId
                      : 'ALL',
              items: [
                const DropdownMenuItem(value: 'ALL', child: Text('ALL')),
                ...w.galleryCategories.map(
                  (cat) =>
                      DropdownMenuItem(value: cat.id, child: Text(cat.label)),
                ),
              ],
              onChanged:
                  (value) => setState(() {
                    _selectedGalleryCategoryId = value ?? 'ALL';
                    _galleryDetailIndex = null;
                  }),
            ),
            _buildFilterDropdown(
              title: 'TAGS',
              value:
                  allTags.any(
                        (tag) =>
                            tag.toLowerCase() ==
                            _selectedGalleryTag.toLowerCase(),
                      )
                      ? _selectedGalleryTag
                      : 'ALL',
              items: [
                const DropdownMenuItem(value: 'ALL', child: Text('ALL')),
                ...allTags.map(
                  (tag) => DropdownMenuItem(value: tag, child: Text(tag)),
                ),
              ],
              onChanged:
                  (tag) => setState(() => _selectedGalleryTag = tag ?? 'ALL'),
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
                  'No gallery items match your filters.',
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
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
                      ? 2
                      : isTablet(context)
                      ? 3
                      : 4,
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
        const SizedBox(height: 32),
        _galleryFooter(w),
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
        _buildGalleryToolbar(
          searchField: _buildGallerySearchField(hintText: 'SEARCH BY TAG'),
          filters:
              allTags.isEmpty
                  ? const []
                  : [
                    _buildFilterDropdown(
                      title: 'TAGS',
                      value:
                          allTags.any(
                                (tag) =>
                                    tag.toLowerCase() ==
                                    _selectedGalleryTag.toLowerCase(),
                              )
                              ? _selectedGalleryTag
                              : 'ALL',
                      items: [
                        const DropdownMenuItem(
                          value: 'ALL',
                          child: Text('ALL'),
                        ),
                        ...allTags.map(
                          (tag) =>
                              DropdownMenuItem(value: tag, child: Text(tag)),
                        ),
                      ],
                      onChanged:
                          (tag) => setState(
                            () => _selectedGalleryTag = tag ?? 'ALL',
                          ),
                    ),
                  ],
        ),
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
                      ? 2
                      : isTablet(context)
                      ? 3
                      : 4,
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
        const SizedBox(height: 32),
        _galleryFooter(w),
      ],
    );
  }

  Widget _galleryFooter(WebsiteContentStore w) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Wrap(
        spacing: 24,
        runSpacing: 8,
        alignment: WrapAlignment.spaceBetween,
        children: [
          Text(
            w.contactFacebook,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
          Text(
            w.contactPhone,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
          Text(
            w.contactEmail,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
