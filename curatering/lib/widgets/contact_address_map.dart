import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../utils/geo_utils.dart';

/// Read-only map preview for Contact Us (fixed Macrina's Kitchen coordinates).
class ContactAddressMap extends StatelessWidget {
  const ContactAddressMap({super.key, required this.address});

  /// Shown in UI copy; map center uses [contactPageMapLat] / [contactPageMapLng].
  final String address;

  static final LatLng _pin = LatLng(contactPageMapLat, contactPageMapLng);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 220,
        child: FlutterMap(
          options: MapOptions(initialCenter: _pin, initialZoom: 16),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.curatering.web',
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: _pin,
                  width: 40,
                  height: 40,
                  child: const Icon(
                    Icons.location_pin,
                    color: Colors.red,
                    size: 40,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
