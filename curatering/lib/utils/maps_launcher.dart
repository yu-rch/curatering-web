import 'package:url_launcher/url_launcher.dart';

import 'geo_utils.dart';

/// Opens the location on OpenStreetMap in the browser (no API key).
Future<bool> openOsmMap(String address, {GeoPin? pin}) async {
  final q = address.trim();
  if (q.isEmpty && pin == null) return false;

  final urls = <Uri>[
    if (pin != null)
      Uri.parse(
        'https://www.openstreetmap.org/?mlat=${pin.lat}&mlon=${pin.lng}#map=16/${pin.lat}/${pin.lng}',
      ),
    if (q.isNotEmpty)
      Uri.parse(
        'https://www.openstreetmap.org/search?query=${Uri.encodeComponent(q)}',
      ),
  ];

  for (final uri in urls) {
    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      return true;
    }
  }
  return false;
}
