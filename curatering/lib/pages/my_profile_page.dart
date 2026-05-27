import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import '../widgets/map_picker.dart';

class MyProfilePage extends StatefulWidget {
  const MyProfilePage({super.key});

  @override
  State<MyProfilePage> createState() => _MyProfilePageState();
}

class _MyProfilePageState extends State<MyProfilePage> {
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  Map<String, dynamic>? _profileData;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isChangingPassword = false;
  String? _error;
  double? _deliveryLat;
  double? _deliveryLng;
  List<Map<String, dynamic>> _otherAddresses = [];

  String get _apiBaseUrl => apiBaseUrl;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('customer_token');

      if (token == null || token.isEmpty) {
        if (mounted) {
          Navigator.of(context).pop('login_required');
        }
        return;
      }

      final response = await http.get(
        Uri.parse('$_apiBaseUrl/api/customer/profile'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 401) {
        await prefs.remove('customer_token');
        await prefs.remove('customer_data');
        if (mounted) {
          _showSessionExpiredDialog();
        }
        return;
      }

      if (response.statusCode != 200) {
        throw Exception('Failed to load profile: ${response.statusCode}');
      }

      final data = jsonDecode(response.body);
      if (mounted) {
        setState(() {
          _profileData = data;
          _fullNameController.text = data['fullName'] ?? '';
          _phoneController.text = data['phone'] ?? '';
          _addressController.text = data['deliveryAddress'] ?? '';
          _deliveryLat = data['deliveryLat']?.toDouble();
          _deliveryLng = data['deliveryLng']?.toDouble();
          if (data['otherDeliveryAddresses'] is List) {
            _otherAddresses = List<Map<String, dynamic>>.from(
              (data['otherDeliveryAddresses'] as List).map(
                (e) => e is Map<String, dynamic> ? e : <String, dynamic>{},
              ),
            );
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error loading profile: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _showSessionExpiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Session Expired'),
        content: const Text(
          'Your session has expired. Please log in again.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop('login_required');
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveProfile() async {
    if (_fullNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Full name is required')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('customer_token');

      final response = await http.put(
        Uri.parse('$_apiBaseUrl/api/customer/profile'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'fullName': _fullNameController.text,
          'phone':
              _phoneController.text.isEmpty ? null : _phoneController.text,
          'deliveryAddress':
              _addressController.text.isEmpty ? null : _addressController.text,
          'deliveryLat': _deliveryLat,
          'deliveryLng': _deliveryLng,
          'otherDeliveryAddresses': _otherAddresses,
        }),
      );

      if (response.statusCode == 401) {
        await prefs.remove('customer_token');
        await prefs.remove('customer_data');
        if (mounted) {
          _showSessionExpiredDialog();
        }
        return;
      }

      if (response.statusCode != 200) {
        throw Exception('Failed to save profile');
      }

      final customerData = prefs.getString('customer_data');
      if (customerData != null) {
        final data = jsonDecode(customerData);
        data['fullName'] = _fullNameController.text;
        data['phone'] = _phoneController.text;
        await prefs.setString('customer_data', jsonEncode(data));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop('profile_updated');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _changePassword() async {
    if (_currentPasswordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your current password')),
      );
      return;
    }

    if (_newPasswordController.text.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('New password must be at least 8 characters'),
        ),
      );
      return;
    }

    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New passwords do not match')),
      );
      return;
    }

    setState(() => _isChangingPassword = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('customer_token');

      final response = await http.put(
        Uri.parse('$_apiBaseUrl/api/customer/password'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'currentPassword': _currentPasswordController.text,
          'newPassword': _newPasswordController.text,
        }),
      );

      if (response.statusCode == 401) {
        final data = jsonDecode(response.body);
        if (data['error'] == 'Current password is incorrect') {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Current password is incorrect'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
        await prefs.remove('customer_token');
        await prefs.remove('customer_data');
        if (mounted) {
          _showSessionExpiredDialog();
        }
        return;
      }

      if (response.statusCode != 200) {
        throw Exception('Failed to change password');
      }

      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password changed successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error changing password: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isChangingPassword = false);
      }
    }
  }

  void _showChangePasswordDialog() {
    String? errorMessage;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.black),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'CHANGE PASSWORD',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 24),
                if (errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: Colors.red.shade700,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            errorMessage!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.red.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _passwordField(
                        'CURRENT PASSWORD',
                        _currentPasswordController,
                      ),
                      const SizedBox(height: 12),
                      _passwordField(
                        'NEW PASSWORD',
                        _newPasswordController,
                        helperText: 'At least 8 characters',
                      ),
                      const SizedBox(height: 12),
                      _passwordField(
                        'CONFIRM PASSWORD',
                        _confirmPasswordController,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isChangingPassword
                      ? null
                      : () async {
                          if (_currentPasswordController.text.isEmpty) {
                            setDialogState(
                              () => errorMessage =
                                  'Please enter your current password',
                            );
                            return;
                          }
                          if (_newPasswordController.text.length < 8) {
                            setDialogState(
                              () => errorMessage =
                                  'New password must be at least 8 characters',
                            );
                            return;
                          }
                          if (_newPasswordController.text !=
                              _confirmPasswordController.text) {
                            setDialogState(
                              () => errorMessage = 'Passwords do not match',
                            );
                            return;
                          }
                          await _changePassword();
                          if (mounted && errorMessage == null) {
                            Navigator.of(context).pop();
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFC024),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 32,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isChangingPassword
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Text(
                          'CHANGE PASSWORD',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _passwordField(
    String label,
    TextEditingController controller, {
    String? helperText,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(label, style: const TextStyle(fontSize: 11)),
        ),
        Expanded(
          child: TextField(
            controller: controller,
            obscureText: true,
            decoration: InputDecoration(
              isDense: true,
              border: const OutlineInputBorder(),
              helperText: helperText,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showMapPicker() async {
    final result = await showMapPicker(
      context: context,
      initialLatitude: _deliveryLat,
      initialLongitude: _deliveryLng,
      initialAddress:
          _addressController.text.isNotEmpty ? _addressController.text : null,
    );

    if (result != null) {
      setState(() {
        _addressController.text = result.address;
        _deliveryLat = result.latitude;
        _deliveryLng = result.longitude;
      });
    }
  }

  void _addOtherAddress() {
    final labelCtrl = TextEditingController();
    final addressCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add Delivery Address',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: labelCtrl,
                decoration: const InputDecoration(
                  labelText: 'Label (e.g. Home, Office)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.label_outline),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addressCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Full Address',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on_outlined),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      if (addressCtrl.text.trim().isEmpty) return;
                      setState(() {
                        _otherAddresses.add({
                          'label': labelCtrl.text.trim().isEmpty
                              ? 'Address ${_otherAddresses.length + 1}'
                              : labelCtrl.text.trim(),
                          'address': addressCtrl.text.trim(),
                        });
                      });
                      Navigator.of(ctx).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFC024),
                      foregroundColor: Colors.black,
                    ),
                    child: const Text('Add'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _removeOtherAddress(int index) {
    setState(() {
      _otherAddresses.removeAt(index);
    });
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('customer_token');
    await prefs.remove('customer_data');
    if (mounted) {
      Navigator.of(context).pop('logged_out');
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'My Profile',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadProfile,
            tooltip: 'Refresh profile',
          ),
        ],
      ),
      body: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _error!,
                              style: const TextStyle(color: Colors.red),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadProfile,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1E1E1E),
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 960),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildProfileHeader(),
                                const SizedBox(height: 24),
                                if (isWide)
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          children: [
                                            _buildPersonalInfoCard(),
                                            const SizedBox(height: 24),
                                            _buildSecurityCard(),
                                            const SizedBox(height: 24),
                                            _buildAccountInfoCard(),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 24),
                                      Expanded(
                                        child: Column(
                                          children: [
                                            _buildDeliveryAddressCard(),
                                            const SizedBox(height: 24),
                                            _buildOtherAddressesCard(),
                                          ],
                                        ),
                                      ),
                                    ],
                                  )
                                else ...[
                                  _buildPersonalInfoCard(),
                                  const SizedBox(height: 24),
                                  _buildDeliveryAddressCard(),
                                  const SizedBox(height: 24),
                                  _buildOtherAddressesCard(),
                                  const SizedBox(height: 24),
                                  _buildSecurityCard(),
                                  const SizedBox(height: 24),
                                  _buildAccountInfoCard(),
                                ],
                                const SizedBox(height: 32),
                                _buildLogoutButton(),
                                const SizedBox(height: 32),
                              ],
                            ),
                          ),
                        ),
                      ),
    );
  }

  Widget _buildProfileHeader() {
    final restaurantPts = _profileData?['restaurantLoyaltyPoints'] ?? 0;
    final cateringPts = _profileData?['cateringLoyaltyPoints'] ?? 0;
    final totalPts =
        (restaurantPts is num ? restaurantPts.toInt() : 0) +
        (cateringPts is num ? cateringPts.toInt() : 0);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.black.withOpacity(0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: const Color(0xFFF4511E),
              child: Text(
                _profileData?['fullName']
                        ?.substring(0, 1)
                        .toUpperCase() ??
                    'C',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _profileData?['fullName'] ?? 'Customer',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _profileData?['email'] ?? '',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
                  ),
                  if (_profileData?['customerCode'] != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Code: ${_profileData!['customerCode']}',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _loyaltyBadge(
                        icon: Icons.restaurant,
                        label: '$restaurantPts Restaurant Points',
                        tooltip: 'Restaurant Loyalty Points',
                        colors: [
                          Colors.orange.shade400,
                          Colors.deepOrange.shade500,
                        ],
                      ),
                      _loyaltyBadge(
                        icon: Icons.event,
                        label: '$cateringPts Catering Points',
                        tooltip: 'Catering Loyalty Points',
                        colors: [
                          Colors.purple.shade400,
                          Colors.deepPurple.shade500,
                        ],
                      ),
                      _loyaltyBadge(
                        icon: Icons.star,
                        label: '$totalPts Total Points',
                        tooltip: 'Total Loyalty Points',
                        colors: [
                          Colors.amber.shade400,
                          Colors.orange.shade600,
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _loyaltyBadge({
    required IconData icon,
    required String label,
    required String tooltip,
    required List<Color> colors,
  }) {
    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 14),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildPersonalInfoCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.black.withOpacity(0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Personal Information'),
            TextField(
              controller: TextEditingController(
                text: _profileData?['email'] ?? '',
              ),
              readOnly: true,
              enabled: false,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _fullNameController,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Contact Number',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveProfile,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save),
                label: Text(_isSaving ? 'Saving...' : 'Save Profile'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFC024),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryAddressCard() {
    final hasCoords = _deliveryLat != null && _deliveryLng != null;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.black.withOpacity(0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Primary Delivery Address'),
            TextField(
              controller: _addressController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Delivery Address',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.location_on),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.map, color: Color(0xFFFFC024)),
                  onPressed: _showMapPicker,
                  tooltip: 'Pick from map',
                ),
              ),
            ),
            if (hasCoords) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.pin_drop, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    '${_deliveryLat!.toStringAsFixed(6)}, ${_deliveryLng!.toStringAsFixed(6)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 200,
                  child: IgnorePointer(
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: LatLng(_deliveryLat!, _deliveryLng!),
                        initialZoom: 15,
                        interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.none,
                        ),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.curatering.web',
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: LatLng(_deliveryLat!, _deliveryLng!),
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
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _showMapPicker,
                  icon: const Icon(Icons.edit_location_alt, size: 16),
                  label: const Text('Change Pin'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFF4511E),
                  ),
                ),
              ),
            ] else ...[
              const SizedBox(height: 12),
              Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: InkWell(
                  onTap: _showMapPicker,
                  borderRadius: BorderRadius.circular(12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_location_alt,
                        size: 36,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap to pin your delivery location',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOtherAddressesCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.black.withOpacity(0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: _sectionTitle('Other Delivery Addresses')),
                IconButton(
                  onPressed: _addOtherAddress,
                  icon: const Icon(Icons.add_circle_outline),
                  tooltip: 'Add address',
                  color: const Color(0xFFFFC024),
                ),
              ],
            ),
            if (_otherAddresses.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 24),
                width: double.infinity,
                child: Column(
                  children: [
                    Icon(
                      Icons.location_off_outlined,
                      size: 32,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No other addresses saved',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              )
            else
              ...List.generate(_otherAddresses.length, (i) {
                final addr = _otherAddresses[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 20,
                        color: Color(0xFFF4511E),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${addr['label'] ?? 'Address ${i + 1}'}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${addr['address'] ?? ''}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: Colors.red.shade400,
                        ),
                        onPressed: () => _removeOtherAddress(i),
                        tooltip: 'Remove',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                );
              }),
            if (_otherAddresses.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Save your profile to persist address changes.',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.black.withOpacity(0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Security'),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.lock_outline,
                color: Color(0xFFF4511E),
              ),
              title: const Text('Change Password'),
              subtitle: const Text('Update your account password'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _showChangePasswordDialog,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountInfoCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.black.withOpacity(0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Account Information'),
            _accountRow(
              Icons.badge_outlined,
              'Customer ID',
              _profileData?['id'] ?? 'N/A',
            ),
            if (_profileData?['customerCode'] != null)
              _accountRow(
                Icons.qr_code,
                'Customer Code',
                '${_profileData!['customerCode']}',
              ),
            _accountRow(
              Icons.calendar_today_outlined,
              'Member Since',
              _formatDate(_profileData?['createdAt']),
            ),
          ],
        ),
      ),
    );
  }

  Widget _accountRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _logout,
        icon: const Icon(Icons.logout, size: 18),
        label: const Text('Logout'),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red,
          side: const BorderSide(color: Colors.red),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'N/A';
    try {
      final date = DateTime.parse(dateStr);
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    } catch (_) {
      return dateStr;
    }
  }
}
