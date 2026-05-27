import 'dart:math' as math;

/// OpenStreetMap / Nominatim user agent (required by usage policy).
const String nominatimUserAgent = 'CurateringWeb/1.0 (support@macrina.local)';

/// Restaurant anchor — Taguig. Kept for map defaults and distance utilities.
const double restaurantLat = 14.513436;
const double restaurantLng = 121.059198;
/// Restaurant delivery radius for online ordering (matches mobile).
const double deliveryMaxDistanceKm = 5;

const double defaultMapLat = 14.5995;
const double defaultMapLng = 120.9842;

/// Contact Us page map preview (Macrina's Kitchen).
const double contactPageMapLat = 14.513537;
const double contactPageMapLng = 121.061896;

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

bool isWithinDeliveryRadius(GeoPin pin) {
  final km = haversineKm(
    const GeoPin(lat: restaurantLat, lng: restaurantLng),
    pin,
  );
  return km <= deliveryMaxDistanceKm;
}

bool isAllowedCateringAddress(String address) {
  return address.trim().isNotEmpty;
}
