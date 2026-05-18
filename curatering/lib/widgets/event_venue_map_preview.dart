import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/nominatim_service.dart';
import '../utils/geo_utils.dart';
import '../utils/maps_launcher.dart';

/// Read-only venue map (flutter_map / OpenStreetMap) + external OSM link.
class EventVenueMapPreview extends StatefulWidget {
  final String address;

  const EventVenueMapPreview({super.key, required this.address});

  @override
  State<EventVenueMapPreview> createState() => _EventVenueMapPreviewState();
}

class _EventVenueMapPreviewState extends State<EventVenueMapPreview> {
  LatLng _pin = const LatLng(defaultMapLat, defaultMapLng);
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant EventVenueMapPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.address != widget.address) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final pin = await NominatimService.instance.geocodeAddress(widget.address);
    if (!mounted) return;
    if (pin == null) {
      setState(() {
        _loading = false;
        _error = 'Could not find this address on the map.';
      });
      return;
    }
    setState(() {
      _pin = LatLng(pin.lat, pin.lng);
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.address),
        const SizedBox(height: 8),
        if (_loading)
          const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error != null)
          Text(_error!, style: const TextStyle(color: Colors.red))
        else
          SizedBox(
            height: 260,
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
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => openOsmMap(
            widget.address,
            pin: GeoPin(lat: _pin.latitude, lng: _pin.longitude),
          ),
          icon: const Icon(Icons.map_outlined),
          label: const Text('Open in OpenStreetMap'),
        ),
      ],
    );
  }
}
