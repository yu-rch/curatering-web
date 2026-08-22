/// Bundled homepage photos shown before CMS / API media resolves.
abstract final class HomeDefaultAssets {
  static const String hero = 'lib/assets/home/home-hero.jpg';
  static const List<String> collage = [
    'lib/assets/home/home-collage-1.jpg',
    'lib/assets/home/home-collage-2.jpg',
    'lib/assets/home/home-collage-3.jpg',
    'lib/assets/home/home-collage-4.jpg',
  ];

  /// Venue photos exclusive to the Event Theme Design sampler.
  static const List<String> etdSamples = [
    'lib/assets/home/etd-sample-1.jpg',
    'lib/assets/home/etd-sample-2.jpg',
    'lib/assets/home/etd-sample-3.jpg',
  ];

  static String? collageAt(int index) {
    if (index < 0 || index >= collage.length) return null;
    return collage[index];
  }

  static String? etdSampleAt(int index) {
    if (index < 0 || index >= etdSamples.length) return null;
    return etdSamples[index];
  }
}
