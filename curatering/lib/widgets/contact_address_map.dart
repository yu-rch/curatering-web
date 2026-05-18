import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/nominatim_service.dart';
import '../utils/geo_utils.dart';

/// Read-only map centered on [address] with a single marker (OpenStreetMap).
class ContactAddressMap extends StatefulWidget {
  const ContactAddressMap({super.key, required this.address});

  final String address;

  @override
  State<ContactAddressMap> createState() => _ContactAddressMapState();
}

class _ContactAddressMapState extends State<ContactAddressMap> {
  LatLng _center = const LatLng(defaultMapLat, defaultMapLng);
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant ContactAddressMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.address != widget.address) _resolve();
  }

  Future<void> _resolve() async {
    final q = widget.address.trim();
    if (q.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'No address';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final pin = await NominatimService.instance.geocodeAddress(q);
    if (!mounted) return;
    if (pin == null) {
      setState(() {
        _loading = false;
        _error = 'Map preview unavailable';
      });
      return;
    }
    setState(() {
      _center = LatLng(pin.lat, pin.lng);
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 220,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 220,
        child: Stack(
          children: [
            FlutterMap(
              options: MapOptions(initialCenter: _center, initialZoom: 16),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.curatering.web',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _center,
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
            if (_error != null)
              Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: Material(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
