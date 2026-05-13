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
        final response = await ApiClient.instance.getJson('/api/cart');

        if (response['success'] == true && response['cart'] != null) {
          final List<dynamic> cartItems = response['cart'];
          final cartJson = jsonEncode(cartItems);
          await prefs.setString(_cartKey, cartJson);
          await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());

          final localCount = CartStore.instance.items.length;
          if (cartItems.isEmpty && localCount > 0) {
            // Server has no cart but this device still has items (e.g. after logout/login).
            // Push local cart up instead of wiping it.
            await syncToServer();
            return;
          }

          CartStore.instance.clearCart();
          for (final item in cartItems) {
            CartStore.instance.addItem(
              CartItem.fromJson(item).dish,
              selectedSauce: CartItem.fromJson(item).selectedSauce,
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
        await ApiClient.instance.postJson('/api/cart/clear');
      }

      CartStore.instance.clearCart();
    } catch (e) {
      print('Error clearing cart: $e');
    }
  }
}
