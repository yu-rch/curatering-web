import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/website_content_store.dart';
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
            Expanded(child: _buildGalleryDetail(w, cat)),
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
          Expanded(child: _buildGallery(w)),
        ],
      ),
    );
  }

  Widget _buildGallery(WebsiteContentStore w) {
    return SingleChildScrollView(
      padding: websitePagePadding(context),
      child: Column(
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
                (v) => setState(
                  () => _gallerySearchQuery = v.trim().toLowerCase(),
                ),
            decoration: InputDecoration(
              hintText: 'SEARCH',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 32),
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
            itemCount: w.galleryCategories.length,
            itemBuilder: (context, index) {
              final cat = w.galleryCategories[index];
              final filteredImages =
                  _gallerySearchQuery.isEmpty
                      ? cat.imageBase64List
                      : cat.imageBase64List
                          .where(
                            (img) =>
                                img.toLowerCase().contains(_gallerySearchQuery),
                          )
                          .toList();

              return GestureDetector(
                onTap: () => setState(() => _galleryDetailIndex = index),
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (cat.imageBase64List.isNotEmpty)
                        Image.memory(
                          base64Decode(cat.imageBase64List.first),
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
                              Colors.black.withOpacity(0.7),
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
                              '${filteredImages.length} images',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (widget.contentEditable)
                        Positioned(
                          right: 6,
                          top: 6,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.edit, size: 16),
                              onPressed: () async {
                                // TODO: Implement edit functionality
                              },
                            ),
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
      ),
    );
  }

  Widget _buildGalleryDetail(WebsiteContentStore w, dynamic cat) {
    final filteredImages =
        _gallerySearchQuery.isEmpty
            ? cat.imageBase64List
            : cat.imageBase64List
                .where((img) => img.toLowerCase().contains(_gallerySearchQuery))
                .toList();

    return SingleChildScrollView(
      padding: websitePagePadding(context),
      child: Column(
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
                    // TODO: Implement add image functionality
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
                (v) => setState(
                  () => _gallerySearchQuery = v.trim().toLowerCase(),
                ),
            decoration: InputDecoration(
              hintText: 'SEARCH IMAGES',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
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
                        ? 1
                        : isTablet(context)
                        ? 2
                        : 3,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: filteredImages.length,
              itemBuilder: (context, index) {
                final img = filteredImages[index];
                return Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Stack(
                    children: [
                      if (img.isNotEmpty)
                        Image.memory(base64Decode(img), fit: BoxFit.cover)
                      else
                        Container(color: Colors.grey.shade300),
                      if (widget.contentEditable)
                        Positioned(
                          right: 6,
                          top: 6,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.delete, size: 16),
                              onPressed: () async {
                                // TODO: Implement delete functionality
                              },
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
    );
  }
}
