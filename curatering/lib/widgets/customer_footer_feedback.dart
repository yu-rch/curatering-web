import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../pages/customer_login.dart';
import '../utils/order_display_utils.dart';

Future<void> showCustomerFooterFeedback(
  BuildContext context, {
  required bool isLoggedIn,
  required Future<void> Function() onLogin,
}) async {
  if (!isLoggedIn) {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Feedback'),
        content: const Text('Please log in to share feedback on a completed order.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await showDialog(
                context: context,
                builder: (context) => const CustomerLoginPage(),
              );
              await onLogin();
            },
            child: const Text('Log in'),
          ),
        ],
      ),
    );
    return;
  }

  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('customer_token');
  if (token == null || token.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to submit feedback')),
      );
    }
    return;
  }

  List<Map<String, dynamic>> eligible = const [];
  try {
    final res = await http.get(
      Uri.parse('$apiBaseUrl/api/restaurant/orders'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    ).timeout(const Duration(seconds: 12));

    if (res.statusCode != 200) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load your orders')),
        );
      }
      return;
    }

    final data = jsonDecode(res.body);
    final orders = data['orders'] as List<dynamic>? ?? const [];
    eligible = orders
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .where((o) {
          final status = (o['status'] ?? '').toString().toLowerCase();
          if (status != 'delivered') return false;
          final stars = o['feedback_stars'];
          return stars == null;
        })
        .toList();
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load your orders')),
      );
    }
    return;
  }

  if (eligible.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No delivered restaurant orders available for feedback'),
        ),
      );
    }
    return;
  }

  if (!context.mounted) return;

  var selected = eligible.first;
  var stars = 5;
  final ctl = TextEditingController();

  final submitted = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setModalState) {
        final o = selected;
        return AlertDialog(
          title: Text('Feedback · ${uiOrderNo(o['order_no'], id: o['id'])}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (eligible.length > 1) ...[
                  DropdownButtonFormField<Map<String, dynamic>>(
                    initialValue: selected,
                    decoration: const InputDecoration(
                      labelText: 'Order',
                      isDense: true,
                    ),
                    items: eligible
                        .map(
                          (ord) => DropdownMenuItem(
                            value: ord,
                            child: Text(uiOrderNo(ord['order_no'], id: ord['id'])),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setModalState(() => selected = v);
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                const Text('How was this restaurant order?'),
                const SizedBox(height: 8),
                Row(
                  children: List.generate(5, (idx) {
                    final selectedStar = idx < stars;
                    return IconButton(
                      visualDensity: VisualDensity.compact,
                      splashRadius: 20,
                      onPressed: () => setModalState(() => stars = idx + 1),
                      icon: Icon(
                        selectedStar ? Icons.star : Icons.star_border,
                        color: selectedStar ? Colors.amber : null,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: ctl,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Remarks',
                    hintText: 'Optional comments about your completed order',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Submit'),
            ),
          ],
        );
      },
    ),
  );

  final remarks = ctl.text.trim();
  ctl.dispose();

  if (submitted != true || !context.mounted) return;

  final orderId = (selected['id'] ?? selected['order_no']).toString();
  try {
    final res = await http.post(
      Uri.parse('$apiBaseUrl/api/restaurant/orders/$orderId/feedback'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'stars': stars, 'remarks': remarks}),
    );

    if (!context.mounted) return;

    if (res.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thank you for your feedback')),
      );
    } else {
      String msg = 'Failed to submit feedback';
      try {
        final err = jsonDecode(res.body);
        if (err is Map && err['error'] != null) {
          msg = err['error'].toString();
        }
      } catch (_) {}
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to submit feedback')),
      );
    }
  }
}
