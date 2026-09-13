import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../auth/auth_session.dart';
import '../config.dart';
import 'api_client.dart';

/// Fallback when the server has never saved a catering rate.
const double kDefaultCateringInquiryPricePerGuest = 500;

/// Live catering inquiry price per guest (PHP), backed by `system_settings`.
class CateringPricingStore extends ChangeNotifier {
  CateringPricingStore._();
  static final CateringPricingStore instance = CateringPricingStore._();

  double _pricePerGuest = kDefaultCateringInquiryPricePerGuest;
  bool _loading = false;
  bool _loaded = false;
  String? _error;

  double get pricePerGuest => _pricePerGuest;
  bool get isLoading => _loading;
  bool get isLoaded => _loaded;
  String? get error => _error;

  String formatPesoAmount([double? price]) =>
      '₱${(price ?? _pricePerGuest).toStringAsFixed(0)}';

  /// Marketing / package-card style label.
  String formatPerPaxLabel({bool usePhpWord = true}) {
    final amount = _pricePerGuest.toStringAsFixed(0);
    return usePhpWord ? 'Php $amount per pax' : '₱$amount per pax';
  }

  /// Rewrites lines like "Php 500 per pax" / "₱500 per pax" to the live rate.
  String rewriteDisplayLine(String line) {
    return line.replaceAllMapped(
      RegExp(
        r'(?:Php|₱)\s*\d+(?:\.\d+)?\s*per\s*pax',
        caseSensitive: false,
      ),
      (_) => formatPerPaxLabel(),
    );
  }

  Future<void> ensureLoaded() async {
    if (_loaded || _loading) return;
    await load();
  }

  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final res = await http
          .get(Uri.parse('$apiBaseUrl/api/catering/price-per-guest'))
          .timeout(const Duration(seconds: 20));
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw ApiError(
          message: 'Failed to load catering price (${res.statusCode})',
          statusCode: res.statusCode,
        );
      }
      final decoded = jsonDecode(res.body);
      final n = decoded is Map
          ? (decoded['pricePerGuest'] as num?)?.toDouble()
          : null;
      if (n != null && n > 0) {
        _pricePerGuest = n;
      }
      _loaded = true;
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<double> savePricePerGuest(double price) async {
    if (price <= 0) {
      throw ApiError(message: 'Price must be greater than zero');
    }
    final token = AuthSession.instance.token;
    final res = await http
        .put(
          Uri.parse('$apiBaseUrl/api/catering/price-per-guest'),
          headers: {
            'Content-Type': 'application/json',
            if (token != null && token.isNotEmpty)
              'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'pricePerGuest': price}),
        )
        .timeout(const Duration(seconds: 20));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      var msg = 'Failed to save catering price (${res.statusCode})';
      try {
        final decoded = jsonDecode(res.body);
        if (decoded is Map && decoded['error'] != null) {
          msg = decoded['error'].toString();
        }
      } catch (_) {}
      throw ApiError(message: msg, statusCode: res.statusCode);
    }
    double saved = price;
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map && decoded['pricePerGuest'] is num) {
        saved = (decoded['pricePerGuest'] as num).toDouble();
      }
    } catch (_) {}
    _pricePerGuest = saved;
    _loaded = true;
    notifyListeners();
    return saved;
  }
}
