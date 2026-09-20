import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import '../theme/customer_fonts.dart';
import 'package:http/http.dart' as http;

import '../config.dart';
import '../services/website_content_store.dart';
import '../utils/gallery_search.dart';
import '../utils/image_cache.dart';
import '../utils/website_image_utils.dart' deferred as web_images;
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
          await WebsiteContentStore.instance.ensureLoaded(
            resolveHomeMedia: false,
          );
        }
      } else {
        // Paint categories/text first; skip home media resolve on this route.
        await WebsiteContentStore.instance.ensureLoaded(
          resolveHomeMedia: false,
        );
      }
    } catch (_) {
      try {
        await WebsiteContentStore.instance.ensureLoaded(
          resolveHomeMedia: false,
        );
      } catch (_) {}
    }
    if (mounted) setState(() {});

    // Heavy base64 media + fallback highlights after first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(() async {
        try {
          await WebsiteContentStore.instance.resolveGalleryMediaRefs();
        } catch (_) {}
        if (mounted) setState(() {});
        if (!widget.contentEditable) {
          unawaited(_loadFallbackGalleryImages());
        }
      }());
    });
  }

  Future<void> _loadFallbackGalleryImages() async {
    try {
      final response = await http
          .get(Uri.parse('$apiBaseUrl/api/public/homepage-highlights?for=gallery'))
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
        final imageUrl = (item['imageUrl'] ?? item['image_url'] ?? '')
            .toString()
            .trim();
        if (image.isEmpty && imageUrl.isEmpty) continue;
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
            imageUrl: imageUrl.isEmpty ? null : imageUrl,
            tags: [label],
            details: _eventDesignDetailsFromMap(item),
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
      (c) => c.images.any((img) => img.hasVisual),
    );
    if (cmsResolved || widget.contentEditable) return w.galleryCategories;
    if (_fallbackCategories.isNotEmpty) return _fallbackCategories;
    return w.galleryCategories;
  }

  Map<String, String> _eventDesignDetailsFromMap(Map raw) {
    final out = <String, String>{};
    void add(String label, dynamic value) {
      if (value == null) return;
      if (value is List) {
        final joined = value
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .join(', ');
        if (joined.isNotEmpty) out[label] = joined;
        return;
      }
      final text = value.toString().trim();
      if (text.isNotEmpty) out[label] = text;
    }

    add('Event type', raw['eventType'] ?? raw['event_type'] ?? raw['type']);
    add('Style', raw['style']);
    add('Mood & lighting', raw['mood']);
    add('Formality', raw['formality']);
    add('Setting', raw['setting'] ?? raw['eventSetting']);
    add('Color palette', raw['colorPalette'] ?? raw['color_palette']);
    add('Decor', raw['decorElements'] ?? raw['decor_elements']);
    return out;
  }

  String? _resolvedGalleryImageUrl(String? raw) {
    final url = (raw ?? '').trim();
    if (url.isEmpty) return null;
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    if (url.startsWith('/')) {
      final base = apiBaseUrl.endsWith('/')
          ? apiBaseUrl.substring(0, apiBaseUrl.length - 1)
          : apiBaseUrl;
      return '$base$url';
    }
    return url;
  }

  Widget _galleryImageVisual(GalleryImageData imgData, {BoxFit fit = BoxFit.cover}) {
    final networkUrl = _resolvedGalleryImageUrl(imgData.imageUrl);
    if (networkUrl != null) {
      return Image.network(
        networkUrl,
        fit: fit,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) {
          if (imgData.imageBase64.trim().isNotEmpty) {
            return _galleryImage(imgData.imageBase64, fit: fit);
          }
          return Container(
            color: Colors.grey.shade300,
            child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
          );
        },
      );
    }
    return _galleryImage(imgData.imageBase64, fit: fit);
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
    if (!imgData.hasVisual) return;
    final tags =
        imgData.tags.where((t) => t.trim().isNotEmpty).toList(growable: false);
    final title =
        tags.isNotEmpty
            ? tags.first
            : categoryLabel.trim().isNotEmpty
            ? categoryLabel
            : 'Gallery photo';
    final description =
        tags.length > 1
            ? tags.sublist(1).join(', ')
            : tags.isEmpty && categoryLabel.trim().isNotEmpty
            ? categoryLabel
            : null;
    final detailBlocks = <MapEntry<String, String>>[
      ...imgData.details.entries,
      if (tags.isNotEmpty && imgData.details.isEmpty)
        MapEntry('Tags', tags.join(', ')),
    ];

    showImageFocusDialog(
      context,
      imageBase64:
          imgData.imageBase64.trim().isEmpty ? null : imgData.imageBase64,
      imageUrl: _resolvedGalleryImageUrl(imgData.imageUrl),
      title: title,
      description: description,
      detailBlocks: detailBlocks,
    );
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

  bool _matchesSelectedCategory(GalleryCategoryData cat) {
    return _selectedGalleryCategoryId == 'ALL' ||
        cat.id == _selectedGalleryCategoryId;
  }

  List<GalleryImageData> _filteredGalleryImages(GalleryCategoryData cat) {
    return filterGalleryImages(cat, _gallerySearchQuery);
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
    final categories =
        source
            .where((c) => galleryCategoryMatchesSearch(c, _gallerySearchQuery))
            .where(_matchesSelectedCategory)
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
              hintText: 'SEARCH BY CATEGORY',
            ),
            filters: [
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
              final visibleCount =
                  _filteredGalleryImages(cat).where((img) => img.hasVisual).length;

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
                      if (cat.images.isNotEmpty && cat.images.first.hasVisual)
                        _galleryImageVisual(cat.images.first)
                      else
                        Container(
                          color: Colors.grey.shade300,
                          child: const Icon(
                            Icons.image_outlined,
                            color: Colors.grey,
                          ),
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
                              style: CustomerFonts.getFont(
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
    final galleryTitle =
        w.galleryTitle.trim().isEmpty ? 'Gallery' : w.galleryTitle.trim();
    final categoryTitle =
        cat.label.trim().isEmpty ? 'Category' : cat.label.trim();
    final photoCount = filteredImages.where((img) => img.hasVisual).length;

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
                  await web_images.loadLibrary();
                  final b64s =
                      await web_images.pickMultipleWebsiteImagesBase64();
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
        const SizedBox(height: 20),
        Text(
          '$galleryTitle | $categoryTitle',
          style: CustomerFonts.getFont(
            _primaryFont,
            fontSize: isMobile(context) ? 26 : 32,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1E1E1E),
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '$photoCount photo${photoCount == 1 ? '' : 's'}',
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 20),
        _buildGalleryToolbar(
          searchField: _buildGallerySearchField(hintText: 'SEARCH PHOTOS'),
          filters: const [],
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
                    imgData.hasVisual
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
                      if (imgData.hasVisual)
                        _galleryImageVisual(imgData)
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
