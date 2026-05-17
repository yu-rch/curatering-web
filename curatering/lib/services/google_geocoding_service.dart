import 'dart:convert';

import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;

import '../config.dart';

/// Lat/lng pair from geocoding.
class GeoCoordinates {
  const GeoCoordinates({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}

/// Reverse/forward geocoding via Google Geocoding API (accurate for PH addresses on web).
class GoogleGeocodingService {
  GoogleGeocodingService._();
  static final GoogleGeocodingService instance = GoogleGeocodingService._();

  static const _endpoint = 'https://maps.googleapis.com/maps/api/geocode/json';

  /// Human-readable address for map pin coordinates.
  Future<String?> reverseGeocode(double latitude, double longitude) async {
    final key = googleMapsApiKey;
    if (key.isNotEmpty) {
      try {
        final uri = Uri.parse(_endpoint).replace(
          queryParameters: {
            'latlng': '$latitude,$longitude',
            'key': key,
            'language': 'en',
            'region': 'ph',
          },
        );
        final response = await http.get(uri).timeout(const Duration(seconds: 12));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final status = data['status'] as String? ?? '';
          if (status == 'OK') {
            final results = data['results'] as List<dynamic>?;
            if (results != null && results.isNotEmpty) {
              final first = results.first as Map<String, dynamic>;
              final formatted = (first['formatted_address'] as String?)?.trim();
              if (formatted != null && formatted.isNotEmpty) {
                return formatted;
              }
            }
          }
        }
      } catch (_) {
        /* fall through */
      }
    }

    final nominatim = await _reverseGeocodeNominatim(latitude, longitude);
    if (nominatim != null && nominatim.isNotEmpty) return nominatim;

    return _reverseGeocodeFallback(latitude, longitude);
  }

  /// Coordinates for a typed or selected address string.
  Future<GeoCoordinates?> forwardGeocode(String address) async {
    final query = address.trim();
    if (query.isEmpty) return null;

    final key = googleMapsApiKey;
    if (key.isNotEmpty) {
      try {
        final uri = Uri.parse(_endpoint).replace(
          queryParameters: {
            'address': query,
            'key': key,
            'language': 'en',
            'region': 'ph',
            'components': 'country:PH',
          },
        );
        final response = await http.get(uri).timeout(const Duration(seconds: 12));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          if (data['status'] == 'OK') {
            final results = data['results'] as List<dynamic>?;
            if (results != null && results.isNotEmpty) {
              final loc = (results.first as Map<String, dynamic>)['geometry']
                  as Map<String, dynamic>?;
              final latLng = loc?['location'] as Map<String, dynamic>?;
              final lat = (latLng?['lat'] as num?)?.toDouble();
              final lng = (latLng?['lng'] as num?)?.toDouble();
              if (lat != null && lng != null) {
                return GeoCoordinates(latitude: lat, longitude: lng);
              }
            }
          }
        }
      } catch (_) {
        /* fall through */
      }
    }

    final nominatim = await _forwardGeocodeNominatim(query);
    if (nominatim != null) return nominatim;

    try {
      final locations = await locationFromAddress(query);
      if (locations.isEmpty) return null;
      final loc = locations.first;
      return GeoCoordinates(latitude: loc.latitude, longitude: loc.longitude);
    } catch (_) {
      return null;
    }
  }

  Future<String?> _reverseGeocodeNominatim(
    double latitude,
    double longitude,
  ) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse',
      ).replace(
        queryParameters: {
          'lat': latitude.toString(),
          'lon': longitude.toString(),
          'format': 'json',
          'addressdetails': '1',
        },
      );
      final response = await http.get(
        uri,
        headers: const {'User-Agent': 'CurateringWeb/1.0'},
      ).timeout(const Duration(seconds: 12));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final display = (data['display_name'] as String?)?.trim();
        if (display != null && display.isNotEmpty) return display;
      }
    } catch (_) {
      /* ignore */
    }
    return null;
  }

  Future<GeoCoordinates?> _forwardGeocodeNominatim(String query) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search',
      ).replace(
        queryParameters: {
          'q': '$query, Philippines',
          'format': 'json',
          'limit': '1',
          'countrycodes': 'ph',
        },
      );
      final response = await http.get(
        uri,
        headers: const {'User-Agent': 'CurateringWeb/1.0'},
      ).timeout(const Duration(seconds: 12));
      if (response.statusCode == 200) {
        final results = jsonDecode(response.body) as List<dynamic>;
        if (results.isNotEmpty) {
          final first = results.first as Map<String, dynamic>;
          final lat = double.tryParse(first['lat']?.toString() ?? '');
          final lon = double.tryParse(first['lon']?.toString() ?? '');
          if (lat != null && lon != null) {
            return GeoCoordinates(latitude: lat, longitude: lon);
          }
        }
      }
    } catch (_) {
      /* ignore */
    }
    return null;
  }

  Future<String?> _reverseGeocodeFallback(
    double latitude,
    double longitude,
  ) async {
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isEmpty) return null;
      return _formatPlacemark(placemarks.first);
    } catch (_) {
      return null;
    }
  }

  String _formatPlacemark(Placemark place) {
    final parts = <String>[
      if (place.name != null &&
          place.name!.isNotEmpty &&
          place.name != place.street)
        place.name!,
      if (place.street != null && place.street!.isNotEmpty) place.street!,
      if (place.subLocality != null && place.subLocality!.isNotEmpty)
        place.subLocality!,
      if (place.locality != null && place.locality!.isNotEmpty) place.locality!,
      if (place.administrativeArea != null &&
          place.administrativeArea!.isNotEmpty)
        place.administrativeArea!,
      if (place.postalCode != null && place.postalCode!.isNotEmpty)
        place.postalCode!,
      if (place.country != null && place.country!.isNotEmpty) place.country!,
    ];
    final seen = <String>{};
    final unique = <String>[];
    for (final p in parts) {
      final t = p.trim();
      if (t.isEmpty || seen.contains(t)) continue;
      seen.add(t);
      unique.add(t);
    }
    return unique.join(', ');
  }
}
