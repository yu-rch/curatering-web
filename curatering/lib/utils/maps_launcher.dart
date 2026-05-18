import 'package:url_launcher/url_launcher.dart';

import 'geo_utils.dart';

/// Opens Google Maps in the browser (no Maps SDK / API key).
Future<bool> openGoogleMaps(String address, {GeoPin? pin}) async {
  final q = address.trim();
  if (q.isEmpty) return false;

  final urls = <Uri>[
    if (pin != null)
      Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${pin.lat},${pin.lng}',
      ),
    Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(q)}'),
    Uri.parse('https://maps.google.com/maps?q=${Uri.encodeComponent(q)}'),
  ];

  for (final uri in urls) {
    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      return true;
    }
  }
  return false;
}
