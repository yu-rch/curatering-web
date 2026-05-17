import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/google_geocoding_service.dart';

class MapPickerResult {
  final double latitude;
  final double longitude;
  final String address;

  const MapPickerResult({
    required this.latitude,
    required this.longitude,
    required this.address,
  });
}

class MapPicker extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;
  final String? initialAddress;

  const MapPicker({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
    this.initialAddress,
  });

  @override
  State<MapPicker> createState() => _MapPickerState();
}

class _MapPickerState extends State<MapPicker> {
  GoogleMapController? _mapController;
  LatLng? _selectedLocation;
  Marker? _selectedMarker;
  String _address = '';
  bool _isLoading = false;
  bool _isGettingLocation = false;

  static const LatLng _defaultLocation = LatLng(14.5995, 120.9842);

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  void _initializeLocation() {
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      _selectedLocation = LatLng(
        widget.initialLatitude!,
        widget.initialLongitude!,
      );
      _address = widget.initialAddress?.trim() ?? '';
      _updateMarker();
      _getAddressFromLatLng(_selectedLocation!);
    } else {
      _selectedLocation = _defaultLocation;
      _updateMarker();
    }
  }

  void _updateMarker() {
    if (_selectedLocation == null) return;
    final snippet =
        _address.isNotEmpty
            ? (_address.length > 90 ? '${_address.substring(0, 87)}…' : _address)
            : 'Resolving address…';
    _selectedMarker = Marker(
      markerId: const MarkerId('selected_location'),
      position: _selectedLocation!,
      infoWindow: InfoWindow(
        title: 'Selected location',
        snippet: snippet,
      ),
    );
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isGettingLocation = true);

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled.');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied');
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final currentLocation = LatLng(position.latitude, position.longitude);

      setState(() {
        _selectedLocation = currentLocation;
        _updateMarker();
      });

      await _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: currentLocation, zoom: 17),
        ),
      );

      await _getAddressFromLatLng(currentLocation);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting location: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGettingLocation = false);
    }
  }

  Future<void> _getAddressFromLatLng(LatLng location) async {
    setState(() => _isLoading = true);

    try {
      final resolved = await GoogleGeocodingService.instance.reverseGeocode(
        location.latitude,
        location.longitude,
      );

      if (!mounted) return;
      setState(() {
        _address =
            (resolved != null && resolved.trim().isNotEmpty)
                ? resolved.trim()
                : 'Address not found for this pin';
        _updateMarker();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _address = 'Unable to resolve address for this pin';
        _updateMarker();
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onMapTap(LatLng location) {
    setState(() {
      _selectedLocation = location;
      _updateMarker();
    });
    _getAddressFromLatLng(location);
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    if (_selectedLocation != null) {
      controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: _selectedLocation!, zoom: 17),
        ),
      );
    }
  }

  bool get _canConfirm {
    if (_selectedLocation == null || _isLoading) return false;
    return _address.isNotEmpty &&
        _address != 'Unable to resolve address for this pin' &&
        _address != 'Address not found for this pin';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        foregroundColor: Colors.white,
        title: Text(
          'Select Location',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        actions: [
          if (_isGettingLocation)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Address at pin:',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                if (_isLoading)
                  const SizedBox(
                    height: 20,
                    child: LinearProgressIndicator(),
                  )
                else
                  Text(
                    _address.isNotEmpty
                        ? _address
                        : 'Tap the map to place the delivery pin',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                if (_selectedLocation != null && !_isLoading) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Pin: ${_selectedLocation!.latitude.toStringAsFixed(6)}, '
                    '${_selectedLocation!.longitude.toStringAsFixed(6)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: GoogleMap(
              onMapCreated: _onMapCreated,
              initialCameraPosition: CameraPosition(
                target: _selectedLocation ?? _defaultLocation,
                zoom: 17,
              ),
              onTap: _onMapTap,
              markers: _selectedMarker != null ? {_selectedMarker!} : {},
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: true,
              mapType: MapType.normal,
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isGettingLocation ? null : _getCurrentLocation,
                      icon: const Icon(Icons.my_location, size: 18),
                      label: const Text('Use Current Location'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade200,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed:
                          _canConfirm
                              ? () {
                                Navigator.of(context).pop(
                                  MapPickerResult(
                                    latitude: _selectedLocation!.latitude,
                                    longitude: _selectedLocation!.longitude,
                                    address: _address,
                                  ),
                                );
                              }
                              : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFC024),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Confirm Location'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<MapPickerResult?> showMapPicker({
  required BuildContext context,
  double? initialLatitude,
  double? initialLongitude,
  String? initialAddress,
}) async {
  return Navigator.of(context).push<MapPickerResult>(
    MaterialPageRoute(
      builder:
          (context) => MapPicker(
            initialLatitude: initialLatitude,
            initialLongitude: initialLongitude,
            initialAddress: initialAddress,
          ),
    ),
  );
}
