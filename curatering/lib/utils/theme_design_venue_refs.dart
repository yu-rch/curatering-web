List<String> venueReferencePhotosFromThemeDesign(
  Map<String, dynamic> themeDesign,
) {
  final out = <String>[];
  void add(dynamic raw) {
    final value = '$raw'.trim();
    if (value.isEmpty || value == 'null') return;
    if (!out.contains(value)) out.add(value);
  }

  add(themeDesign['venuePhotoBase64']);
  for (final key in const [
    'reference_images',
    'referenceImages',
    'venuePhotos',
  ]) {
    final values = themeDesign[key];
    if (values is List) {
      for (final value in values) {
        add(value);
      }
    }
  }
  return out;
}
