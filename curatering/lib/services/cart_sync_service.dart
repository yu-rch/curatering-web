import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';
import 'cart_store.dart';

/// Service for synchronizing cart between mobile and web platforms
class CartSyncService {
  static CartSyncService? _instance;
  static CartSyncService get instance => _instance ??= CartSyncService._();

  CartSyncService._();

  static const String _cartKey = 'cart';
  static const String _lastSyncKey = 'cart_last_sync';
  static const String _deviceIdKey = 'device_id';

  /// Sync cart from server to local storage
  Future<void> syncFromServer() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('customer_token');

      if (token != null && token.isNotEmpty) {
        ApiClient.instance.setCustomerBearer(token);
        final response = await ApiClient.instance.getJson('/api/cart');

        List<dynamic> cartItems = [];
        if (response['success'] == true && response['cart'] != null) {
          cartItems = response['cart'] as List<dynamic>;
        }

        // Tray draft (customer_tray_drafts) — shared with mobile
        try {
          final trayResponse = await ApiClient.instance.getJson('/api/tray-draft');
          if (trayResponse['success'] == true && trayResponse['items'] is List) {
            final trayItems = trayResponse['items'] as List<dynamic>;
            if (trayItems.isNotEmpty) {
              cartItems = trayItems;
            }
          }
        } catch (_) {
          /* cart endpoint may still have data */
        }

        if (cartItems.isNotEmpty || response['success'] == true) {
          final cartJson = jsonEncode(cartItems);
          await prefs.setString(_cartKey, cartJson);
          await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());

          final localCount = CartStore.instance.items.length;
          if (cartItems.isEmpty && localCount > 0) {
            await syncToServer();
            return;
          }

          CartStore.instance.clearCart();
          for (final item in cartItems) {
            final parsed = CartItem.fromJson(item as Map<String, dynamic>);
            CartStore.instance.addItem(
              parsed.dish,
              selectedSauce: parsed.selectedSauce,
            );
          }
        }
      }
    } catch (e) {
      print('Error syncing cart from server: $e');
    }
  }

  /// Sync local cart to server
  Future<void> syncToServer() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('customer_token');

      if (token != null && token.isNotEmpty) {
        ApiClient.instance.setCustomerBearer(token);
        final cartItems = CartStore.instance.items;

        if (cartItems.isNotEmpty) {
          final cartData = cartItems.map((item) => item.toJson()).toList();
          await ApiClient.instance.postJson(
            '/api/cart/sync',
            body: {
              'cart': cartData,
              'deviceId': await _getDeviceId(),
              'timestamp': DateTime.now().toIso8601String(),
            },
          );
          await ApiClient.instance.putJson(
            '/api/tray-draft',
            body: {'items': cartData},
          );

          await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());
        }
      }
    } catch (e) {
      print('Error syncing cart to server: $e');
    }
  }

  /// Get or generate device ID for tracking
  Future<String> _getDeviceId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? deviceId = prefs.getString(_deviceIdKey);

      if (deviceId == null || deviceId.isEmpty) {
        deviceId = 'device_${DateTime.now().millisecondsSinceEpoch}';
        await prefs.setString(_deviceIdKey, deviceId);
      }

      return deviceId;
    } catch (e) {
      return 'device_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  /// Check if sync is needed based on last sync time
  Future<bool> needsSync() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSync = prefs.getString(_lastSyncKey);

      if (lastSync == null) return true;

      final lastSyncTime = DateTime.parse(lastSync);
      final now = DateTime.now();

      // Sync if more than 5 minutes have passed
      return now.difference(lastSyncTime).inMinutes > 5;
    } catch (e) {
      return true;
    }
  }

  /// Initialize sync service and perform initial sync if needed
  Future<void> initialize() async {
    try {
      final needsSync = await this.needsSync();

      if (needsSync) {
        // Try to sync from server first (server takes precedence)
        await syncFromServer();

        // Then sync any local changes back to server
        await syncToServer();
      }
    } catch (e) {
      print('Error initializing cart sync: $e');
    }
  }

  /// Force full sync between local and server
  Future<void> forceSync() async {
    await syncFromServer();
    await syncToServer();
  }

  /// Clear cart on all platforms
  Future<void> clearCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cartKey);
      await prefs.remove(_lastSyncKey);

      // Clear on server
      final token = prefs.getString('customer_token');
      if (token != null && token.isNotEmpty) {
        ApiClient.instance.setCustomerBearer(token);
        await ApiClient.instance.postJson('/api/cart/clear');
        try {
          await ApiClient.instance.delete('/api/tray-draft');
        } catch (_) {
          /* tray may already be empty */
        }
      }

      CartStore.instance.clearCart();
    } catch (e) {
      print('Error clearing cart: $e');
    }
  }
}
