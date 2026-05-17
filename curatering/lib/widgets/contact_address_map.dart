import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../services/google_geocoding_service.dart';

/// Read-only map centered on [address] with a single marker.
class ContactAddressMap extends StatefulWidget {
  const ContactAddressMap({super.key, required this.address});

  final String address;

  @override
  State<ContactAddressMap> createState() => _ContactAddressMapState();
}

class _ContactAddressMapState extends State<ContactAddressMap> {
  static const LatLng _fallback = LatLng(14.5995, 120.9842);

  LatLng _center = _fallback;
  Set<Marker> _markers = {};
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
    if (oldWidget.address != widget.address) {
      _resolve();
    }
  }

  Future<void> _resolve() async {
    final q = widget.address.trim();
    if (q.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'No address';
        _center = _fallback;
        _markers = {};
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final coords = await GoogleGeocodingService.instance.forwardGeocode(q);
      if (coords == null) throw Exception('No coordinates');
      final latLng = LatLng(coords.latitude, coords.longitude);
      if (!mounted) return;
      setState(() {
        _center = latLng;
        _markers = {
          Marker(
            markerId: const MarkerId('business'),
            position: latLng,
            infoWindow: InfoWindow(title: 'Location', snippet: q),
          ),
        };
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Map preview unavailable';
        _center = _fallback;
        _markers = {
          Marker(
            markerId: const MarkerId('approx'),
            position: _fallback,
            infoWindow: InfoWindow(title: q),
          ),
        };
      });
    }
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
            GoogleMap(
              key: ValueKey('contact_${_center.latitude}_${_center.longitude}'),
              initialCameraPosition: CameraPosition(
                target: _center,
                zoom: 16,
              ),
              markers: _markers,
              zoomControlsEnabled: false,
              myLocationButtonEnabled: false,
              liteModeEnabled: false,
              mapToolbarEnabled: false,
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
