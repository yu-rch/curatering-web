import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import '../theme/customer_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../services/nominatim_service.dart';
import '../utils/geo_utils.dart';

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
  final bool enforceDeliveryRadius;

  const MapPicker({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
    this.initialAddress,
    this.enforceDeliveryRadius = false,
  });

  @override
  State<MapPicker> createState() => _MapPickerState();
}

class _MapPickerState extends State<MapPicker> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  LatLng? _selectedLocation;
  String _address = '';
  Map<String, String> _addressParts = const {};
  bool _isLoading = false;
  bool _isGettingLocation = false;
  String? _error;
  List<String> _suggestions = const [];
  int _pickRequestId = 0;

  bool get _enforceArea => widget.enforceDeliveryRadius;

  String get _outOfAreaMessage =>
      'Delivery is only available in ${restaurantDeliveryAreaLabel()}.';

  bool get _locationAllowed {
    if (!_enforceArea) return true;
    if (_address.trim().isEmpty) return false;
    return isAllowedRestaurantDeliveryLocation(
      address: _address,
      addressParts: _addressParts,
    );
  }

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.initialAddress?.trim() ?? '';
    _searchController.addListener(_onSearchChanged);
    _initializeLocation();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final q = _searchController.text.trim();
    if (q.length < 3) {
      if (_suggestions.isNotEmpty) setState(() => _suggestions = const []);
      return;
    }
    Future.delayed(const Duration(milliseconds: 300), () async {
      if (_searchController.text.trim() != q) return;
      final list = await NominatimService.instance.searchAddresses(q);
      final filtered = _enforceArea
          ? list
              .where(
                (s) => isAllowedRestaurantDeliveryLocation(address: s),
              )
              .toList()
          : list;
      if (mounted && _searchController.text.trim() == q) {
        setState(() => _suggestions = filtered);
      }
    });
  }

  Future<void> _initializeLocation() async {
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      _selectedLocation = LatLng(
        widget.initialLatitude!,
        widget.initialLongitude!,
      );
      _address = widget.initialAddress?.trim() ?? '';
      if (_address.isEmpty) await _resolveAddress();
      setState(() {});
      return;
    }
    final query = widget.initialAddress?.trim() ?? '';
    if (query.isNotEmpty) {
      setState(() => _isLoading = true);
      final pin = await NominatimService.instance.geocodeAddress(query);
      if (pin != null && mounted) {
        _selectedLocation = LatLng(pin.lat, pin.lng);
        await _resolveAddress();
      } else {
        _selectedLocation = const LatLng(defaultMapLat, defaultMapLng);
      }
      if (mounted) setState(() => _isLoading = false);
    } else {
      _selectedLocation = const LatLng(defaultMapLat, defaultMapLng);
    }
    setState(() {});
  }

  Future<void> _resolveAddress({int? requestId}) async {
    final loc = _selectedLocation;
    if (loc == null) return;
    setState(() => _isLoading = true);
    try {
      final resolved = await NominatimService.instance.reverseGeocodeDetails(
        GeoPin(lat: loc.latitude, lng: loc.longitude),
      );
      if (!mounted) return;
      if (requestId != null && requestId != _pickRequestId) return;
      final current = _selectedLocation;
      if (current == null ||
          current.latitude != loc.latitude ||
          current.longitude != loc.longitude) {
        return;
      }
      final allowed = !_enforceArea ||
          isAllowedRestaurantDeliveryLocation(
            address: resolved.displayName,
            addressParts: resolved.addressParts,
          );
      setState(() {
        _address = resolved.displayName;
        _addressParts = resolved.addressParts;
        _error = allowed ? null : _outOfAreaMessage;
      });
    } finally {
      if (mounted && (requestId == null || requestId == _pickRequestId)) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _onPick(LatLng location) async {
    final requestId = ++_pickRequestId;
    setState(() {
      _selectedLocation = location;
      _address = '';
      _addressParts = const {};
      _error = null;
      _suggestions = const [];
    });
    _mapController.move(location, _mapController.camera.zoom);
    await _resolveAddress(requestId: requestId);
  }

  Future<void> _applySearch(String query) async {
    final pin = await NominatimService.instance.geocodeAddress(query);
    if (pin == null) {
      setState(() => _error = 'Address not found');
      return;
    }
    await _onPick(LatLng(pin.lat, pin.lng));
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isGettingLocation = true);
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) throw Exception('Location services are disabled.');

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Location permission denied');
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      await _onPick(LatLng(pos.latitude, pos.longitude));
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isGettingLocation = false);
    }
  }

  bool get _canConfirm {
    if (_selectedLocation == null || _isLoading) return false;
    if (_address.trim().isEmpty) return false;
    if (_enforceArea && !_locationAllowed) return false;
    return true;
  }

  void _confirm() {
    final loc = _selectedLocation;
    if (loc == null) return;
    if (_enforceArea && !_locationAllowed) {
      setState(() => _error = _outOfAreaMessage);
      return;
    }
    Navigator.of(context).pop(
      MapPickerResult(
        latitude: loc.latitude,
        longitude: loc.longitude,
        address: _address.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final center =
        _selectedLocation ?? const LatLng(defaultMapLat, defaultMapLng);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        foregroundColor: Colors.white,
        title: Text(
          'Select Location',
          style: CustomerFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'Search place or address',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: () => _applySearch(_searchController.text),
                    ),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: _applySearch,
                ),
                if (_suggestions.isNotEmpty)
                  Material(
                    elevation: 2,
                    child: ListView(
                      shrinkWrap: true,
                      children:
                          _suggestions
                              .map(
                                (s) => ListTile(
                                  dense: true,
                                  title: Text(
                                    s,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                  onTap: () {
                                    _searchController.text = s;
                                    setState(() => _suggestions = const []);
                                    _applySearch(s);
                                  },
                                ),
                              )
                              .toList(),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _enforceArea
                      ? 'Tap the map to set the pin. Delivery is limited to ${restaurantDeliveryAreaLabel()}.'
                      : 'Tap the map to set the pin. Address updates via OpenStreetMap.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 6),
                if (_isLoading)
                  const LinearProgressIndicator()
                else
                  Text(
                    _address.isNotEmpty
                        ? _address
                        : 'Tap the map to place the pin',
                    style: CustomerFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                if (_selectedLocation != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${center.latitude.toStringAsFixed(6)}, ${center.longitude.toStringAsFixed(6)}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 6),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
              ],
            ),
          ),
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: center,
                initialZoom: 16,
                onTap: (_, point) {
                  FocusScope.of(context).unfocus();
                  _onPick(point);
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.curatering.web',
                ),
                if (_selectedLocation != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _selectedLocation!,
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
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed:
                          _isGettingLocation ? null : _getCurrentLocation,
                      icon: const Icon(Icons.my_location, size: 18),
                      label: const Text('Use my location'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _canConfirm ? _confirm : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFC024),
                        foregroundColor: Colors.black,
                      ),
                      child: const Text('Save'),
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
  bool enforceDeliveryRadius = false,
}) {
  return Navigator.of(context).push<MapPickerResult>(
    MaterialPageRoute(
      builder:
          (context) => MapPicker(
            initialLatitude: initialLatitude,
            initialLongitude: initialLongitude,
            initialAddress: initialAddress,
            enforceDeliveryRadius: enforceDeliveryRadius,
          ),
    ),
  );
}
