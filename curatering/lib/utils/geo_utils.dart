import 'dart:math' as math;

/// OpenStreetMap / Nominatim user agent (required by usage policy).
const String nominatimUserAgent = 'CurateringWeb/1.0 (support@macrina.local)';

/// Restaurant anchor — Taguig. Kept for map defaults and distance utilities.
const double restaurantLat = 14.513436;
const double restaurantLng = 121.059198;
const double deliveryMaxDistanceKm = 50;

const double defaultMapLat = restaurantLat;
const double defaultMapLng = restaurantLng;

/// Contact Us page map preview (Macrina's Kitchen).
const double contactPageMapLat = 14.513537;
const double contactPageMapLng = 121.061896;

/// Restaurant delivery: Taguig plus bordering / adjacent cities.
/// Matching is case-insensitive substring against reverse-geocode text.
const List<String> kRestaurantDeliveryCities = [
  'Taguig',
  'Makati',
  'Pasig',
  'Pateros',
  'Parañaque',
  'Paranaque',
  'Pasay',
  'Mandaluyong',
];

class GeoPin {
  final double lat;
  final double lng;

  const GeoPin({required this.lat, required this.lng});
}

double haversineKm(GeoPin a, GeoPin b) {
  const r = 6371.0;
  final dLat = _deg2rad(b.lat - a.lat);
  final dLng = _deg2rad(b.lng - a.lng);
  final lat1 = _deg2rad(a.lat);
  final lat2 = _deg2rad(b.lat);
  final x =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1) * math.cos(lat2) * math.sin(dLng / 2) * math.sin(dLng / 2);
  return r * 2 * math.atan2(math.sqrt(x), math.sqrt(1 - x));
}

double _deg2rad(double deg) => deg * math.pi / 180;

String restaurantDeliveryAreaLabel() {
  // Prefer accented Parañaque in user-facing copy once.
  const display = [
    'Taguig',
    'Makati',
    'Pasig',
    'Pateros',
    'Parañaque',
    'Pasay',
    'Mandaluyong',
  ];
  return display.join(', ');
}

/// True when [address] / Nominatim parts mention Taguig or an adjacent city.
bool isAllowedRestaurantDeliveryLocation({
  required String address,
  Map<String, String>? addressParts,
}) {
  final parts = <String>[address];
  if (addressParts != null) {
    // Prefer locality fields first.
    for (final key in const [
      'city',
      'town',
      'municipality',
      'city_district',
      'suburb',
      'village',
      'county',
      'state_district',
    ]) {
      final v = addressParts[key];
      if (v != null && v.trim().isNotEmpty) parts.add(v);
    }
    parts.addAll(addressParts.values);
  }
  final haystack = parts.join(' ').toLowerCase();
  if (haystack.trim().isEmpty) return false;

  for (final city in kRestaurantDeliveryCities) {
    final needle = city.toLowerCase();
    if (haystack.contains(needle)) return true;
  }
  return false;
}

/// Legacy name used by map picker — city allowlist for restaurant delivery.
bool isWithinDeliveryRadius(GeoPin pin, {String address = ''}) {
  if (address.trim().isNotEmpty) {
    return isAllowedRestaurantDeliveryLocation(address: address);
  }
  // Without an address, allow provisional pin placement; Save still needs
  // reverse-geocode + city check.
  return true;
}

bool isAllowedCateringAddress(String address) {
  return address.trim().isNotEmpty;
}
