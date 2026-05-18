import '../services/website_content_store.dart';

bool galleryCategoryMatchesSearch(GalleryCategoryData cat, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  if (cat.label.toLowerCase().contains(q)) return true;
  for (final img in cat.images) {
    for (final tag in img.tags) {
      if (tag.toLowerCase().contains(q)) return true;
    }
  }
  return false;
}

List<GalleryImageData> filterGalleryImages(
  GalleryCategoryData cat,
  String query,
) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return List<GalleryImageData>.from(cat.images);
  return cat.images
      .where(
        (img) => img.tags.any((tag) => tag.toLowerCase().contains(q)),
      )
      .toList();
}

String galleryTagsHint() => 'e.g. wedding, outdoor, buffet (comma-separated)';

List<String> parseTagsInput(String raw) {
  return raw
      .split(RegExp(r'[,;]'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
}
