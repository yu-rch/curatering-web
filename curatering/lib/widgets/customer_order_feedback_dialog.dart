import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config.dart';

class CustomerOrderFeedbackResult {
  const CustomerOrderFeedbackResult({
    required this.stars,
    required this.remarks,
  });

  final int stars;
  final String remarks;
}

Future<CustomerOrderFeedbackResult?> showCustomerOrderFeedbackInputDialog(
  BuildContext context, {
  required String title,
  required String question,
}) async {
  var stars = 5;
  final remarksController = TextEditingController();

  final submitted = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setModalState) {
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(question),
                const SizedBox(height: 8),
                Row(
                  children: List.generate(5, (idx) {
                    final selected = idx < stars;
                    return IconButton(
                      visualDensity: VisualDensity.compact,
                      splashRadius: 20,
                      onPressed: () => setModalState(() => stars = idx + 1),
                      icon: Icon(
                        selected ? Icons.star : Icons.star_border,
                        color: selected ? Colors.amber : null,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: remarksController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Remarks',
                    hintText: 'Optional comments',
                    border: OutlineInputBorder(),
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

  final remarks = remarksController.text.trim();
  remarksController.dispose();
  if (submitted != true) return null;
  return CustomerOrderFeedbackResult(stars: stars, remarks: remarks);
}

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

  final result = await showCustomerOrderFeedbackInputDialog(
    context,
    title: 'Feedback · $label',
    question: 'How was this transaction?',
  );
  if (result == null || !context.mounted) return false;

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );

  try {
    final response = await http.post(
      Uri.parse('$apiBaseUrl/api/customer/order-feedback'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'kind': kind,
        'reference': reference,
        'rating': result.stars,
        'comment': result.remarks,
      }),
    );

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
    final msg = data is Map
        ? '${data['error'] ?? 'Could not submit feedback'}'
        : 'Could not submit feedback';
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
    return false;
  } catch (e) {
    if (context.mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
    return false;
  }
}
