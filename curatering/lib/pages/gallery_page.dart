import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import '../config.dart';
import '../services/website_content_store.dart';
import '../utils/gallery_search.dart';
import '../utils/image_cache.dart';
import '../utils/website_image_utils.dart';
import '../widgets/customer_website_topbar.dart';
import '../widgets/customer_site_footer.dart';
import '../widgets/customer_antd_page_hero.dart';
import '../widgets/image_focus_dialog.dart';

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
  List<GalleryCategoryData> _fallbackCategories = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrapGallery());
  }

  Future<void> _bootstrapGallery() async {
    try {
      if (widget.contentEditable) {
        try {
          await WebsiteContentStore.instance.loadDraft();
        } catch (_) {
          await WebsiteContentStore.instance.ensureLoaded();
        }
      } else {
        await WebsiteContentStore.instance.ensureLoaded();
      }
      await WebsiteContentStore.instance.resolveMediaRefs();
    } catch (_) {
      try {
        await WebsiteContentStore.instance.ensureLoaded();
        await WebsiteContentStore.instance.resolveMediaRefs();
      } catch (_) {}
    }
    if (mounted) setState(() {});
    if (!widget.contentEditable) {
      unawaited(_loadFallbackGalleryImages());
    }
  }

  Future<void> _loadFallbackGalleryImages() async {
    try {
      final response = await http
          .get(Uri.parse('$apiBaseUrl/api/public/homepage-highlights'))
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200 || !mounted) return;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return;
      final rawDesigns = decoded['eventDesigns'];
      if (rawDesigns is! List || rawDesigns.isEmpty) return;
      final byType = <String, List<GalleryImageData>>{};
      for (final item in rawDesigns) {
        if (item is! Map) continue;
        final image = (item['imageBase64'] ?? '').toString().trim();
        if (image.isEmpty) continue;
        final label = (item['label'] ?? item['eventType'] ?? 'Event').toString();
        final eventType =
            (item['eventType'] ?? item['type'] ?? 'Completed Events')
                .toString()
                .trim();
        final key = eventType.isEmpty ? 'Completed Events' : eventType;
        byType.putIfAbsent(key, () => <GalleryImageData>[]);
        final list = byType[key]!;
        list.add(
          GalleryImageData(
            id: 'fallback-${list.length}-${key.hashCode}',
            imageBase64: image,
            tags: [label],
          ),
        );
      }
      // Also fold in CMS event-design stills when highlights are sparse.
      final cmsDesigns = WebsiteContentStore.instance.eventDesignImageBase64;
      if (cmsDesigns.isNotEmpty) {
        byType.putIfAbsent('Event Designs', () => <GalleryImageData>[]);
        final list = byType['Event Designs']!;
        for (var i = 0; i < cmsDesigns.length; i++) {
          final image = cmsDesigns[i].trim();
          if (image.isEmpty) continue;
          list.add(
            GalleryImageData(
              id: 'cms-design-$i',
              imageBase64: image,
              tags: const ['Event Designs'],
            ),
          );
        }
      }
      if (byType.isEmpty || !mounted) return;
      setState(() {
        _fallbackCategories =
            byType.entries
                .map(
                  (e) => GalleryCategoryData(
                    id: 'fallback-${e.key.hashCode}',
                    label: e.key,
                    images: e.value,
                  ),
                )
                .toList();
      });
    } catch (_) {
      // Keep CMS-only gallery when highlights are unavailable.
      final cmsDesigns = WebsiteContentStore.instance.eventDesignImageBase64
          .where((e) => e.trim().isNotEmpty)
          .toList();
      if (cmsDesigns.isEmpty || !mounted) return;
      setState(() {
        _fallbackCategories = [
          GalleryCategoryData(
            id: 'fallback-event-designs',
            label: 'Event Designs',
            images: [
              for (var i = 0; i < cmsDesigns.length; i++)
                GalleryImageData(
                  id: 'cms-design-$i',
                  imageBase64: cmsDesigns[i],
                  tags: const ['Event Designs'],
                ),
            ],
          ),
        ];
      });
    }
  }

  List<GalleryCategoryData> _effectiveCategories(WebsiteContentStore w) {
    final cmsResolved = w.galleryCategories.any(
      (c) => c.images.any((img) => img.imageBase64.trim().isNotEmpty),
    );
    if (cmsResolved || widget.contentEditable) return w.galleryCategories;
    if (_fallbackCategories.isNotEmpty) return _fallbackCategories;
    return w.galleryCategories;
  }

  @override
  Widget build(BuildContext context) {
    final w = WebsiteContentStore.instance;

    if (_galleryDetailIndex != null) {
      final source = _effectiveCategories(w);
      final idx = _galleryDetailIndex!.clamp(0, source.length - 1);
      final cat = source[idx];
      return Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CustomerWebsiteTopBar(
              showCartAndCustomerAuth: !widget.contentEditable,
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: websitePagePadding(context),
                      child: ListenableBuilder(
                        listenable: w,
                        builder: (context, _) => _buildGalleryDetail(w, cat),
                      ),
                    ),
                    const SizedBox(height: 48),
                    ListenableBuilder(
                      listenable: w,
                      builder:
                          (context, _) => CustomerSiteFooter(
                            store: w,
                            contentEditable: widget.contentEditable,
                          ),
                    ),
                  ],
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
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: websitePagePadding(context),
                    child: ListenableBuilder(
                      listenable: w,
                      builder: (context, _) => _buildGallery(w),
                    ),
                  ),
                ),
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Column(
                    children: [
                      const Spacer(),
                      const SizedBox(height: 48),
                      ListenableBuilder(
                        listenable: w,
                        builder:
                            (context, _) => CustomerSiteFooter(
                              store: w,
                              contentEditable: widget.contentEditable,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
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
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      isDense: true,
      style: const TextStyle(fontSize: 12, color: Color(0xFF1E1E1E)),
      decoration: InputDecoration(
        labelText: title,
        labelStyle: const TextStyle(fontSize: 11),
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 4,
          vertical: 4,
        ),
      ),
      items: items,
      onChanged: onChanged,
    );
  }

  Widget _buildGallerySearchField({required String hintText}) {
    return SizedBox(
      height: 48,
      child: TextField(
        onChanged:
            (v) => setState(() => _gallerySearchQuery = v.trim().toLowerCase()),
        style: const TextStyle(fontSize: 12),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(fontSize: 11),
          prefixIcon: const Icon(Icons.search, size: 16),
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 12,
          ),
        ),
      ),
    );
  }

  Widget _galleryImage(String? b64, {BoxFit fit = BoxFit.cover}) {
    return CachedBase64Image(
      base64String: b64,
      fit: fit,
      placeholder: Container(
        color: Colors.grey.shade300,
        child: const Icon(Icons.image_outlined, color: Colors.grey),
      ),
    );
  }

  void _showGalleryImageDetail(
    GalleryImageData imgData, {
    required String categoryLabel,
  }) {
    if (imgData.imageBase64.trim().isEmpty) return;
    final tags =
        imgData.tags.where((t) => t.trim().isNotEmpty).toList(growable: false);
    final title =
        tags.isNotEmpty ? tags.first : categoryLabel.trim().isNotEmpty ? categoryLabel : 'Gallery photo';
    final description =
        tags.length > 1
            ? tags.sublist(1).join(', ')
            : tags.isEmpty && categoryLabel.trim().isNotEmpty
            ? categoryLabel
            : null;

    showImageFocusDialog(
      context,
      imageBase64: imgData.imageBase64,
      title: title,
      description: description,
      detailBlocks:
          tags.isNotEmpty
              ? [MapEntry('Tags', tags.join(', '))]
              : const [],
    );
  }

  Widget _buildGalleryToolbar({
    required Widget searchField,
    required List<Widget> filters,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 760;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: narrow ? constraints.maxWidth : null,
              child: narrow
                  ? searchField
                  : SizedBox(
                      width: (constraints.maxWidth * 0.4).clamp(220.0, 420.0),
                      child: searchField,
                    ),
            ),
            ...filters,
          ],
        );
      },
    );
  }

  Widget _buildGallery(WebsiteContentStore w) {
    final source = _effectiveCategories(w);
    final allTags = _allGalleryTags(source);
    final categories =
        source
            .where((c) => galleryCategoryMatchesSearch(c, _gallerySearchQuery))
            .where(_matchesSelectedCategory)
            .where(_matchesSelectedTag)
            .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        CustomerAntdPageHero(
          title: w.galleryTitle.trim().isEmpty ? 'GALLERY' : w.galleryTitle,
          subtitle: w.galleryIntro.trim().isEmpty
              ? 'Explore our event highlights and signature moments'
              : w.galleryIntro,
          titleFontSize: isMobile(context) ? 28 : 36,
          filters: _buildGalleryToolbar(
            searchField: _buildGallerySearchField(
              hintText: 'SEARCH BY TAG OR CATEGORY',
            ),
            filters: [
              CustomerAntdFilterSelect<String>(
                label: 'Filter by tags',
                value: allTags.any(
                      (tag) =>
                          tag.toLowerCase() ==
                          _selectedGalleryTag.toLowerCase(),
                    )
                    ? _selectedGalleryTag
                    : 'ALL',
                items: [
                  const DropdownMenuItem(value: 'ALL', child: Text('All tags')),
                  ...allTags.map(
                    (tag) => DropdownMenuItem(value: tag, child: Text(tag)),
                  ),
                ],
                onChanged: (tag) =>
                    setState(() => _selectedGalleryTag = tag ?? 'ALL'),
              ),
              CustomerAntdFilterSelect<String>(
                label: 'Filter by category',
                value: source.any((cat) => cat.id == _selectedGalleryCategoryId)
                    ? _selectedGalleryCategoryId
                    : 'ALL',
                items: [
                  const DropdownMenuItem(
                    value: 'ALL',
                    child: Text('All categories'),
                  ),
                  ...source.map(
                    (cat) => DropdownMenuItem(
                      value: cat.id,
                      child: Text(cat.label),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() {
                  _selectedGalleryCategoryId = value ?? 'ALL';
                  _galleryDetailIndex = null;
                }),
              ),
            ],
          ),
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
                      : 5,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.2,
            ),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final cat = categories[index];
              final realIndex = source.indexOf(cat);
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
                      _galleryImage(
                        cat.images.isNotEmpty
                            ? cat.images.first.imageBase64
                            : null,
                      ),
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
                  await w.saveDraft();
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
                      : 5,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: filteredImages.length,
            itemBuilder: (context, index) {
              final imgData = filteredImages[index];
              final fullIndex = cat.images.indexOf(imgData);
              return GestureDetector(
                onTap:
                    imgData.imageBase64.isNotEmpty
                        ? () => _showGalleryImageDetail(
                          imgData,
                          categoryLabel: cat.label,
                        )
                        : null,
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (imgData.imageBase64.isNotEmpty)
                        _galleryImage(imgData.imageBase64)
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
                            await w.saveDraft();
                            setState(() {});
                          },
                        ),
                      ),
                  ],
                ),
              ),
            );
            },
          ),
      ],
    );
  }
}
