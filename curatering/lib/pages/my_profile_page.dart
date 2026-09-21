import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/customer_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import '../widgets/customer_account_shell.dart';
import '../widgets/customer_pages_top_bar.dart';
import '../widgets/map_picker.dart';
import '../widgets/antd_dialog.dart';
import 'customer_website.dart';
import 'my_caterings_page.dart';
import 'my_order_tracking_page.dart';
import 'my_orders_page.dart';

class MyProfilePage extends StatefulWidget {
  const MyProfilePage({super.key});

  @override
  State<MyProfilePage> createState() => _MyProfilePageState();
}

class _MyProfilePageState extends State<MyProfilePage> {
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  Map<String, dynamic>? _profileData;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isChangingPassword = false;
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  String? _error;
  List<_SavedAddress> _addresses = [];

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
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  List<_SavedAddress> _parseAddresses(Map<String, dynamic> data) {
    final raw = data['deliveryAddresses'];
    final list = <_SavedAddress>[];
    if (raw is List) {
      for (var i = 0; i < raw.length; i++) {
        final e = raw[i];
        if (e is! Map) continue;
        final addr = _SavedAddress.fromJson(Map<String, dynamic>.from(e), i);
        if (addr.address.trim().isNotEmpty) list.add(addr);
      }
    }
    if (list.isEmpty) {
      final single = (data['deliveryAddress'] ?? '').toString().trim();
      if (single.isNotEmpty) {
        list.add(
          _SavedAddress(
            id: 'legacy_default',
            label: 'Default',
            address: single,
            lat: (data['deliveryLat'] as num?)?.toDouble(),
            lng: (data['deliveryLng'] as num?)?.toDouble(),
            isDefault: true,
          ),
        );
      }
    }
    if (list.isNotEmpty && !list.any((a) => a.isDefault)) {
      list[0] = list[0].copyWith(isDefault: true);
    }
    return list;
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
        final map =
            data is Map
                ? Map<String, dynamic>.from(data)
                : <String, dynamic>{};
        setState(() {
          _profileData = map;
          _fullNameController.text = map['fullName'] ?? '';
          final phoneDigits =
              (map['phone'] ?? '').toString().replaceAll(RegExp(r'\D'), '');
          _phoneController.text =
              phoneDigits.length > 11 ? phoneDigits.substring(0, 11) : phoneDigits;
          _addresses = _parseAddresses(map);
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
      builder:
          (context) => AlertDialog(
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
    final fullName = _fullNameController.text.trim();
    if (fullName.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Full name is required')));
      return;
    }
    if (!RegExp(r'^[A-Za-z]+(?:\s+[A-Za-z]+)*$').hasMatch(fullName)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Full name should contain letters only')),
      );
      return;
    }
    final phoneDigits = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    if (phoneDigits.isNotEmpty && phoneDigits.length > 11) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phone number must be at most 11 digits')),
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
          'fullName': fullName,
          'phone': phoneDigits.isEmpty ? null : phoneDigits,
          'deliveryAddresses': _addresses.map((a) => a.toJson()).toList(),
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

      // Update local storage
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
        // Return result to refresh parent
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

      // Clear password fields
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
        Navigator.of(context).pop(); // Close dialog
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
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => Dialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 480),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Close button
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
                        // Title
                        const Text(
                          'CHANGE PASSWORD',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Error message
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

                        // Form fields
                        SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  const SizedBox(
                                    width: 150,
                                    child: Text(
                                      'CURRENT PASSWORD',
                                      maxLines: 1,
                                      softWrap: false,
                                      overflow: TextOverflow.visible,
                                      style: TextStyle(fontSize: 11),
                                    ),
                                  ),
                                  Expanded(
                                    child: TextField(
                                      controller: _currentPasswordController,
                                      obscureText: _obscureCurrentPassword,
                                      decoration: InputDecoration(
                                        isDense: true,
                                        border: const OutlineInputBorder(),
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _obscureCurrentPassword
                                                ? Icons.visibility_off
                                                : Icons.visibility,
                                            size: 18,
                                          ),
                                          onPressed: () {
                                            setDialogState(
                                              () => _obscureCurrentPassword =
                                                  !_obscureCurrentPassword,
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  const SizedBox(
                                    width: 150,
                                    child: Text(
                                      'NEW PASSWORD',
                                      maxLines: 1,
                                      softWrap: false,
                                      overflow: TextOverflow.visible,
                                      style: TextStyle(fontSize: 11),
                                    ),
                                  ),
                                  Expanded(
                                    child: TextField(
                                      controller: _newPasswordController,
                                      obscureText: _obscureNewPassword,
                                      decoration: InputDecoration(
                                        isDense: true,
                                        border: const OutlineInputBorder(),
                                        helperText: 'At least 8 characters',
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _obscureNewPassword
                                                ? Icons.visibility_off
                                                : Icons.visibility,
                                            size: 18,
                                          ),
                                          onPressed: () {
                                            setDialogState(
                                              () => _obscureNewPassword =
                                                  !_obscureNewPassword,
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  const SizedBox(
                                    width: 150,
                                    child: Text(
                                      'CONFIRM PASSWORD',
                                      maxLines: 1,
                                      softWrap: false,
                                      overflow: TextOverflow.visible,
                                      style: TextStyle(fontSize: 11),
                                    ),
                                  ),
                                  Expanded(
                                    child: TextField(
                                      controller: _confirmPasswordController,
                                      obscureText: _obscureConfirmPassword,
                                      decoration: InputDecoration(
                                        isDense: true,
                                        border: const OutlineInputBorder(),
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _obscureConfirmPassword
                                                ? Icons.visibility_off
                                                : Icons.visibility,
                                            size: 18,
                                          ),
                                          onPressed: () {
                                            setDialogState(
                                              () => _obscureConfirmPassword =
                                                  !_obscureConfirmPassword,
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Submit button
                        ElevatedButton(
                          onPressed:
                              _isChangingPassword
                                  ? null
                                  : () async {
                                    if (_currentPasswordController
                                        .text
                                        .isEmpty) {
                                      setDialogState(
                                        () =>
                                            errorMessage =
                                                'Please enter your current password',
                                      );
                                      return;
                                    }
                                    if (_newPasswordController.text.length <
                                        8) {
                                      setDialogState(
                                        () =>
                                            errorMessage =
                                                'New password must be at least 8 characters',
                                      );
                                      return;
                                    }
                                    if (_newPasswordController.text !=
                                        _confirmPasswordController.text) {
                                      setDialogState(
                                        () =>
                                            errorMessage =
                                                'Passwords do not match',
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
                          child:
                              _isChangingPassword
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

  Future<void> _editAddress({_SavedAddress? existing, int? index}) async {
    final labelCtrl = TextEditingController(text: existing?.label ?? '');
    final addressCtrl = TextEditingController(text: existing?.address ?? '');
    double? lat = existing?.lat;
    double? lng = existing?.lng;
    var isDefault = existing?.isDefault ?? _addresses.isEmpty;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Text(existing == null ? 'Add address' : 'Edit address'),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: labelCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Label (e.g. Home, Office)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: addressCtrl,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'Delivery address',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.map),
                            tooltip: 'Pick from map',
                            onPressed: () async {
                              final result = await showMapPicker(
                                context: context,
                                initialLatitude: lat,
                                initialLongitude: lng,
                                initialAddress:
                                    addressCtrl.text.isNotEmpty
                                        ? addressCtrl.text
                                        : null,
                              );
                              if (result != null) {
                                setDialogState(() {
                                  addressCtrl.text = result.address;
                                  lat = result.latitude;
                                  lng = result.longitude;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                      if (lat != null && lng != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Pin: ${lat!.toStringAsFixed(5)}, ${lng!.toStringAsFixed(5)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: isDefault,
                        onChanged: (v) =>
                            setDialogState(() => isDefault = v ?? false),
                        title: const Text('Set as default'),
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    if (addressCtrl.text.trim().isEmpty) return;
                    Navigator.pop(ctx, true);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    final label = labelCtrl.text.trim();
    final address = addressCtrl.text.trim();
    labelCtrl.dispose();
    addressCtrl.dispose();
    if (saved != true || address.isEmpty) return;

    setState(() {
      final entry = _SavedAddress(
        id: existing?.id ?? 'addr_${DateTime.now().millisecondsSinceEpoch}',
        label: label.isEmpty ? 'Address' : label,
        address: address,
        lat: lat,
        lng: lng,
        isDefault: isDefault,
      );
      var next = List<_SavedAddress>.from(_addresses);
      if (index != null && index >= 0 && index < next.length) {
        next[index] = entry;
      } else {
        next.add(entry);
      }
      if (entry.isDefault) {
        next = next
            .map((a) => a.id == entry.id ? a : a.copyWith(isDefault: false))
            .toList();
      } else if (!next.any((a) => a.isDefault) && next.isNotEmpty) {
        next[0] = next[0].copyWith(isDefault: true);
      }
      _addresses = next;
    });
  }

  void _removeAddress(int index) {
    setState(() {
      final next = List<_SavedAddress>.from(_addresses)..removeAt(index);
      if (next.isNotEmpty && !next.any((a) => a.isDefault)) {
        next[0] = next[0].copyWith(isDefault: true);
      }
      _addresses = next;
    });
  }

  void _setDefaultAddress(int index) {
    setState(() {
      _addresses = [
        for (var i = 0; i < _addresses.length; i++)
          _addresses[i].copyWith(isDefault: i == index),
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'My Profile',
          style: CustomerFonts.poppins(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadProfile,
            tooltip: 'Refresh profile',
          ),
        ],
      ),
      body: CustomerAccountShell(
        currentTab: CustomerPageTab.profile,
        body: Column(
        children: [
          Expanded(
            child:
                _isLoading
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
                          constraints: const BoxConstraints(maxWidth: 760),
                          child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Profile Header with Loyalty Points
                          Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(
                                color: Colors.black.withValues(alpha: 0.08),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _profileData?['fullName'] ??
                                              'Customer',
                                          style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _profileData?['email'] ?? '',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        // Loyalty Points Display
                                        Row(
                                          children: [
                                            // Restaurant Points
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 5,
                                                  ),
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: [
                                                    Colors.orange.shade400,
                                                    Colors.deepOrange.shade500,
                                                  ],
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(
                                                    Icons.restaurant,
                                                    color: Colors.white,
                                                    size: 14,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    '${_profileData?['restaurantLoyaltyPoints'] ?? 0}',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            // Catering Points
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 5,
                                                  ),
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: [
                                                    Colors.purple.shade400,
                                                    Colors.deepPurple.shade500,
                                                  ],
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(
                                                    Icons.event,
                                                    color: Colors.white,
                                                    size: 14,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    '${_profileData?['cateringLoyaltyPoints'] ?? 0}',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            // Total Points
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 5,
                                                  ),
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: [
                                                    Colors.amber.shade400,
                                                    Colors.orange.shade600,
                                                  ],
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(
                                                    Icons.star,
                                                    color: Colors.white,
                                                    size: 14,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    '${(_profileData?['restaurantLoyaltyPoints'] ?? 0) + (_profileData?['cateringLoyaltyPoints'] ?? 0)}',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Profile Information Section
                          Text(
                            'Profile Information',
                            style: CustomerFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _fullNameController,
                            textCapitalization: TextCapitalization.words,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[A-Za-z\s]'),
                              ),
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Full Name',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.person),
                              hintText: 'Letters only',
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            maxLength: 11,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(11),
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Contact Number',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.phone),
                              hintText: 'Up to 11 digits',
                              counterText: '',
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Delivery Addresses Section
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Delivery Addresses',
                                  style: CustomerFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () => _editAddress(),
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Add'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (_addresses.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Text(
                                'No saved addresses yet. Add one for faster checkout.',
                                style: TextStyle(color: Colors.grey.shade700),
                              ),
                            )
                          else
                            ...List.generate(_addresses.length, (index) {
                              final addr = _addresses[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  side: BorderSide(
                                    color: addr.isDefault
                                        ? const Color(0xFFFFC024)
                                        : Colors.grey.shade300,
                                    width: addr.isDefault ? 1.5 : 1,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    12,
                                    10,
                                    4,
                                    10,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        Icons.location_on,
                                        color: addr.isDefault
                                            ? const Color(0xFFF4511E)
                                            : Colors.grey.shade600,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    addr.label,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                ),
                                                if (addr.isDefault) ...[
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 2,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                        0xFFFFC024,
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                        10,
                                                      ),
                                                    ),
                                                    child: const Text(
                                                      'Default',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              addr.address,
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey.shade800,
                                              ),
                                            ),
                                            if (addr.lat != null &&
                                                addr.lng != null)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  top: 4,
                                                ),
                                                child: Text(
                                                  'Pin: ${addr.lat!.toStringAsFixed(5)}, ${addr.lng!.toStringAsFixed(5)}',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      PopupMenuButton<String>(
                                        onSelected: (value) {
                                          if (value == 'edit') {
                                            _editAddress(
                                              existing: addr,
                                              index: index,
                                            );
                                          } else if (value == 'default') {
                                            _setDefaultAddress(index);
                                          } else if (value == 'remove') {
                                            _removeAddress(index);
                                          }
                                        },
                                        itemBuilder: (context) => [
                                          const PopupMenuItem(
                                            value: 'edit',
                                            child: Text('Edit'),
                                          ),
                                          if (!addr.isDefault)
                                            const PopupMenuItem(
                                              value: 'default',
                                              child: Text('Set as default'),
                                            ),
                                          const PopupMenuItem(
                                            value: 'remove',
                                            child: Text('Remove'),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          const SizedBox(height: 24),

                          // Save Profile Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isSaving ? null : _saveProfile,
                              icon:
                                  _isSaving
                                      ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                      : const Icon(Icons.save),
                              label: Text(
                                _isSaving ? 'Saving...' : 'Save Profile',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFF4511E),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Security Section
                          Text(
                            'Security',
                            style: CustomerFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ListTile(
                            leading: const Icon(
                              Icons.lock,
                              color: Color(0xFFF4511E),
                            ),
                            title: const Text('Change Password'),
                            subtitle: const Text(
                              'Update your account password',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: _showChangePasswordDialog,
                          ),
                          ListTile(
                            leading: const Icon(
                              Icons.delete_forever,
                              color: Colors.red,
                            ),
                            title: const Text(
                              'Delete Account',
                              style: TextStyle(color: Colors.red),
                            ),
                            subtitle: const Text(
                              'Permanently deactivate your login (order history is kept)',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: _showDeleteAccountDialog,
                          ),
                          const SizedBox(height: 32),

                          // Account Info
                          Text(
                            'Account Information',
                            style: CustomerFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ListTile(
                            leading: const Icon(Icons.badge),
                            title: const Text('Customer ID'),
                            subtitle: Text(_profileData?['id'] ?? 'N/A'),
                          ),
                          ListTile(
                            leading: const Icon(Icons.calendar_today),
                            title: const Text('Member Since'),
                            subtitle: Text(
                              _formatDate(_profileData?['createdAt']),
                            ),
                          ),
                        ],
                          ),
                        ),
                      ),
                    ),
          ),
        ],
      ),
      ),
    );
  }

  Future<void> _showDeleteAccountDialog() async {
    await DialogOpenGuard.runOnce(
      _showDeleteAccountDialogBody,
      key: 'customer-delete-account',
    );
  }

  Future<void> _showDeleteAccountDialogBody() async {
    final confirmCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Delete account?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'This deactivates your login. Past orders are kept for records. Type DELETE to confirm.',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Type DELETE',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
    final typed = confirmCtrl.text.trim();
    confirmCtrl.dispose();
    if (ok != true) return;
    if (typed.toUpperCase() != 'DELETE') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Confirmation text must be DELETE')),
      );
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('customer_token');
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/api/customer/account/delete'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'confirm': 'DELETE'}),
      );
      if (response.statusCode != 200) {
        final data = jsonDecode(response.body);
        throw Exception(data['error'] ?? 'Failed to delete account');
      }
      await prefs.remove('customer_token');
      await prefs.remove('customer_data');
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const CustomerWebsiteScreen()),
        (_) => false,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your account has been deleted')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
    }
  }

  void _navigateFromTopBar(CustomerPageTab tab) {
    if (tab == CustomerPageTab.profile) return;
    final route = switch (tab) {
      CustomerPageTab.home => const CustomerWebsiteScreen(),
      CustomerPageTab.orders => const MyOrdersPage(),
      CustomerPageTab.caterings => const MyCateringsPage(),
      CustomerPageTab.tracking => const MyOrderTrackingPage(),
      CustomerPageTab.profile => const MyProfilePage(),
    };
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => route));
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'N/A';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.month}/${date.day}/${date.year}';
    } catch (_) {
      return dateStr;
    }
  }
}

class _SavedAddress {
  const _SavedAddress({
    required this.id,
    required this.label,
    required this.address,
    this.lat,
    this.lng,
    this.isDefault = false,
  });

  final String id;
  final String label;
  final String address;
  final double? lat;
  final double? lng;
  final bool isDefault;

  _SavedAddress copyWith({
    String? id,
    String? label,
    String? address,
    double? lat,
    double? lng,
    bool? isDefault,
  }) {
    return _SavedAddress(
      id: id ?? this.id,
      label: label ?? this.label,
      address: address ?? this.address,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'address': address,
    'lat': lat,
    'lng': lng,
    'isDefault': isDefault,
  };

  factory _SavedAddress.fromJson(Map<String, dynamic> m, int index) {
    double? asDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse('$v');
    }

    return _SavedAddress(
      id: (m['id'] ?? 'addr_$index').toString(),
      label: (m['label'] ?? m['name'] ?? 'Address ${index + 1}').toString(),
      address: (m['address'] ?? m['deliveryAddress'] ?? '').toString(),
      lat: asDouble(m['lat'] ?? m['deliveryLat']),
      lng: asDouble(m['lng'] ?? m['deliveryLng']),
      isDefault: m['isDefault'] == true,
    );
  }
}
