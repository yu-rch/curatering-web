import 'dart:convert';

import 'package:http/http.dart' as http;

import '../auth/auth_session.dart';
import '../config.dart';

/// Staff JWT POS API (`/api/cashier/pos/*`) — mirrors mobile `/api/mobile/pos/*`.
class CashierPosApi {
  CashierPosApi._();
  static final CashierPosApi instance = CashierPosApi._();

  Future<Map<String, String>> _headers() async {
    final token = AuthSession.instance.token;
    if (token == null || token.isEmpty) {
      throw Exception('Not logged in');
    }
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  Future<dynamic> _post(String path, [Map<String, dynamic>? body]) async {
    final res = await http.post(
      Uri.parse('$apiBaseUrl$path'),
      headers: await _headers(),
      body: jsonEncode(body ?? {}),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(_errorMessage(res));
    }
    if (res.body.isEmpty) return null;
    return jsonDecode(res.body);
  }

  Future<dynamic> _patch(String path, Map<String, dynamic> body) async {
    final res = await http.patch(
      Uri.parse('$apiBaseUrl$path'),
      headers: await _headers(),
      body: jsonEncode(body),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(_errorMessage(res));
    }
    if (res.body.isEmpty) return null;
    return jsonDecode(res.body);
  }

  String _errorMessage(http.Response res) {
    try {
      final m = jsonDecode(res.body);
      if (m is Map && m['error'] != null) return m['error'].toString();
    } catch (_) {}
    return 'Request failed (${res.statusCode})';
  }

  List<Map<String, dynamic>> _asOrderList(dynamic data) {
    if (data is List) {
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    if (data is Map && data['orders'] is List) {
      return (data['orders'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    return const [];
  }

  Future<List<Map<String, dynamic>>> listOnlineOrders() async {
    final data = await _post('/api/cashier/pos/online-orders/list');
    return _asOrderList(data);
  }

  Future<void> reviewOnlineOrder(
    dynamic orderId, {
    required String action,
    double? amountReceived,
    double? supplementalAmountReceived,
  }) async {
    await _patch('/api/cashier/pos/online-orders/$orderId/review', {
      'action': action,
      if (amountReceived != null) 'amount_received': amountReceived,
      if (supplementalAmountReceived != null)
        'supplemental_amount_received': supplementalAmountReceived,
    });
  }

  Future<void> patchFulfillment(
    dynamic orderId, {
    required String fulfillmentStage,
    String deliveryTrackingUrl = '',
  }) async {
    await _patch('/api/cashier/pos/online-orders/$orderId/fulfillment', {
      'fulfillment_stage': fulfillmentStage,
      'delivery_tracking_url': deliveryTrackingUrl,
    });
  }

  Future<void> remindBalance(dynamic orderId) async {
    await _post('/api/cashier/pos/online-orders/$orderId/remind-balance');
  }

  Future<Map<String, dynamic>> submitWalkInOrder({
    required String paymentMethod,
    required double amountReceived,
    required List<Map<String, dynamic>> items,
    String note = '',
    String posCustomerLabel = '',
    String? paymentProofBase64,
    String? paymentReferenceInitial,
  }) async {
    final res = await http.post(
      Uri.parse('$apiBaseUrl/api/cashier/pos/walkin-order'),
      headers: await _headers(),
      body: jsonEncode({
        'payment_method': paymentMethod,
        'amount_received': amountReceived,
        'note': note,
        'pos_customer_label': posCustomerLabel,
        if (paymentReferenceInitial != null)
          'payment_reference_initial': paymentReferenceInitial,
        if (paymentProofBase64 != null) 'payment_proof': paymentProofBase64,
        'items': items,
      }),
    );
    if (res.statusCode != 201) throw Exception(_errorMessage(res));
    return Map<String, dynamic>.from(jsonDecode(res.body) as Map);
  }

  Future<List<Map<String, dynamic>>> walkInQueue(String filter) async {
    final data = await _post('/api/cashier/pos/walkin-queue', {
      'filter': filter,
    });
    return _asOrderList(data);
  }

  Future<void> claimWalkIn(dynamic orderId) async {
    await _patch('/api/cashier/pos/walkin-orders/$orderId/claim', {});
  }

  Future<void> cancelWalkIn(dynamic orderId) async {
    await _patch('/api/cashier/pos/walkin-orders/$orderId/cancel', {});
  }

  Future<List<Map<String, dynamic>>> orderHistory() async {
    final data = await _post('/api/cashier/pos/order-history');
    return _asOrderList(data);
  }

  Future<List<Map<String, dynamic>>> loadMenu() async {
    final res = await http.get(Uri.parse('$apiBaseUrl/api/mobile/menu'));
    if (res.statusCode != 200) throw Exception(_errorMessage(res));
    final data = jsonDecode(res.body);
    if (data is Map && data['dishes'] is List) {
      return (data['dishes'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    return const [];
  }
}
