import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config.dart';

/// Feedback for restaurant orders or completed catering inquiries.
Future<bool> showCustomerOrderFeedbackDialog(
  BuildContext context, {
  required String kind,
  required String reference,
  required String label,
  required Future<String?> Function() getToken,
}) async {
  final token = await getToken();
  if (token == null || token.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to submit feedback.')),
      );
    }
    return false;
  }

  var stars = 5;
  final remarksCtrl = TextEditingController();

  final submit = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setModal) => AlertDialog(
          title: Text('Feedback · $label'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('How was this transaction?'),
                const SizedBox(height: 8),
                Row(
                  children: List.generate(5, (i) {
                    final selected = i < stars;
                    return IconButton(
                      visualDensity: VisualDensity.compact,
                      splashRadius: 20,
                      onPressed: () => setModal(() => stars = i + 1),
                      icon: Icon(
                        selected ? Icons.star : Icons.star_border,
                        color: selected ? Colors.amber : null,
                      ),
                    );
                  }),
                ),
                TextField(
                  controller: remarksCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Remarks',
                    hintText: 'Optional comments',
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
        ),
      );
    },
  );

  if (submit != true || !context.mounted) {
    remarksCtrl.dispose();
    return false;
  }

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );

  try {
    final response = await http.post(
      Uri.parse('${apiBaseUrl}/api/customer/order-feedback'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'kind': kind,
        'reference': reference,
        'rating': stars,
        'comment': remarksCtrl.text.trim(),
      }),
    );
    remarksCtrl.dispose();

    if (context.mounted) Navigator.of(context).pop();

    if (response.statusCode == 201) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Feedback submitted. Thank you!')),
        );
      }
      return true;
    }

    final data = response.body.isNotEmpty ? jsonDecode(response.body) : {};
    final msg = data is Map ? '${data['error'] ?? 'Could not submit feedback'}' : 'Could not submit feedback';
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
    return false;
  } catch (e) {
    remarksCtrl.dispose();
    if (context.mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
    return false;
  }
}
