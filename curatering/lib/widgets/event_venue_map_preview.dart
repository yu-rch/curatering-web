import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/nominatim_service.dart';
import '../utils/geo_utils.dart';
import '../utils/maps_launcher.dart';
import 'antd_buttons.dart';
import 'antd_dialog.dart';

/// Read-only venue map (flutter_map / OpenStreetMap) + external OSM link.
class EventVenueMapPreview extends StatefulWidget {
  final String address;
  final double? latitude;
  final double? longitude;

  const EventVenueMapPreview({
    super.key,
    required this.address,
    this.latitude,
    this.longitude,
  });

  @override
  State<EventVenueMapPreview> createState() => _EventVenueMapPreviewState();
}

class _EventVenueMapPreviewState extends State<EventVenueMapPreview> {
  LatLng? _pin;
  String? _error;
  bool _loading = true;

  bool get _hasStoredPin =>
      widget.latitude != null &&
      widget.longitude != null &&
      widget.latitude!.isFinite &&
      widget.longitude!.isFinite;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant EventVenueMapPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.address != widget.address ||
        oldWidget.latitude != widget.latitude ||
        oldWidget.longitude != widget.longitude) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _pin = null;
    });

    if (_hasStoredPin) {
      if (!mounted) return;
      setState(() {
        _pin = LatLng(widget.latitude!, widget.longitude!);
        _loading = false;
      });
      return;
    }

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

  Future<void> _openExternalMap() async {
    final pin = _pin;
    await openOsmMap(
      widget.address,
      pin: pin == null ? null : GeoPin(lat: pin.latitude, lng: pin.longitude),
    );
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
        else if (_pin != null)
          SizedBox(
            height: 260,
            child: FlutterMap(
              options: MapOptions(initialCenter: _pin!, initialZoom: 16),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.curatering.web',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _pin!,
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
          onPressed: _openExternalMap,
          icon: const Icon(Icons.map_outlined),
          label: const Text('Open in OpenStreetMap'),
        ),
      ],
    );
  }
}

/// Staff read-only venue map popup for a tappable address.
Future<void> showVenueMapDialog(
  BuildContext context,
  String address, {
  double? latitude,
  double? longitude,
}) async {
  final trimmed = address.trim();
  if (trimmed.isEmpty || trimmed == '—') return;
  await showAntdModal<void>(
    context: context,
    title: 'Venue map',
    maxWidth: 640,
    body: EventVenueMapPreview(
      address: trimmed,
      latitude: latitude,
      longitude: longitude,
    ),
    actions: [
      AntdPrimaryButton(
        label: 'Close',
        onPressed: () => Navigator.of(context).pop(),
      ),
    ],
  );
}
