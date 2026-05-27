import 'package:flutter/material.dart';

class CustomerOrderFeedbackResult {
  const CustomerOrderFeedbackResult({
    required this.stars,
    required this.remarks,
  });

  final int stars;
  final String remarks;
}

Future<CustomerOrderFeedbackResult?> showCustomerOrderFeedbackDialog(
  BuildContext context, {
  required String title,
  required String question,
}) async {
  var stars = 5;
  final remarksController = TextEditingController();

  final submitted = await showDialog<bool>(
    context: context,
    builder:
        (ctx) => StatefulBuilder(
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
                        hintText:
                            'Optional comments about your completed order',
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
