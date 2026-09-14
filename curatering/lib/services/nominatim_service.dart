import 'dart:convert';

import 'package:http/http.dart' as http;

import '../utils/geo_utils.dart';

/// Forward/reverse geocoding and address search via Nominatim (OpenStreetMap).
class NominatimService {
  NominatimService._();
  static final NominatimService instance = NominatimService._();

  static const _base = 'https://nominatim.openstreetmap.org';

  Future<dynamic> _get(Uri uri) async {
    final res = await http
        .get(uri, headers: {'User-Agent': nominatimUserAgent})
        .timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) {
      throw Exception('Nominatim HTTP ${res.statusCode}');
    }
    return jsonDecode(res.body);
  }

  Future<GeoPin?> geocodeAddress(String query) async {
    final q = query.trim();
    if (q.isEmpty) return null;
    final uri = Uri.parse('$_base/search').replace(
      queryParameters: {
        'q': '$q, Philippines',
        'format': 'json',
        'limit': '1',
        'countrycodes': 'ph',
      },
    );
    final list = await _get(uri);
    if (list is! List || list.isEmpty) return null;
    final first = list.first;
    if (first is! Map) return null;
    final lat = double.tryParse('${first['lat']}');
    final lng = double.tryParse('${first['lon']}');
    if (lat == null || lng == null) return null;
    return GeoPin(lat: lat, lng: lng);
  }

  Future<List<String>> searchAddresses(String query, {int limit = 5}) async {
    final q = query.trim();
    if (q.length < 3) return const [];
    final uri = Uri.parse('$_base/search').replace(
      queryParameters: {
        'q': '$q, Philippines',
        'format': 'json',
        'limit': '$limit',
        'countrycodes': 'ph',
      },
    );
    final list = await _get(uri);
    if (list is! List) return const [];
    final out = <String>[];
    for (final e in list) {
      if (e is! Map) continue;
      final name = (e['display_name'] ?? '').toString().trim();
      if (name.isNotEmpty) out.add(name);
    }
    return out.take(limit).toList();
  }

  Future<String> reverseGeocode(GeoPin pin) async {
    final details = await reverseGeocodeDetails(pin);
    return details.displayName;
  }

  /// Reverse geocode with address components (for city allowlist checks).
  Future<ReverseGeocodeDetails> reverseGeocodeDetails(GeoPin pin) async {
    final uri = Uri.parse('$_base/reverse').replace(
      queryParameters: {
        'lat': pin.lat.toString(),
        'lon': pin.lng.toString(),
        'format': 'json',
        'addressdetails': '1',
      },
    );
    try {
      final body = await _get(uri);
      if (body is Map) {
        final name = (body['display_name'] ?? '').toString().trim();
        final rawAddr = body['address'];
        final parts = <String, String>{};
        if (rawAddr is Map) {
          rawAddr.forEach((key, value) {
            final k = key.toString();
            final v = value?.toString().trim() ?? '';
            if (v.isNotEmpty) parts[k] = v;
          });
        }
        if (name.isNotEmpty) {
          return ReverseGeocodeDetails(displayName: name, addressParts: parts);
        }
      }
    } catch (_) {
      /* fall through */
    }
    return ReverseGeocodeDetails(
      displayName: '${pin.lat.toStringAsFixed(6)}, ${pin.lng.toStringAsFixed(6)}',
    );
  }
}

class ReverseGeocodeDetails {
  const ReverseGeocodeDetails({
    required this.displayName,
    this.addressParts = const {},
  });

  final String displayName;
  final Map<String, String> addressParts;
}
