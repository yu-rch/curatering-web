import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config.dart';
import '../widgets/customer_website_topbar.dart';

class RestaurantFeedbackPublicPage extends StatefulWidget {
  const RestaurantFeedbackPublicPage({super.key, required this.token});

  final String token;

  @override
  State<RestaurantFeedbackPublicPage> createState() =>
      _RestaurantFeedbackPublicPageState();
}

class _RestaurantFeedbackPublicPageState
    extends State<RestaurantFeedbackPublicPage> {
  bool _loading = true;
  bool _submitting = false;
  String? _error;
  String? _orderId;
  bool _submitted = false;
  int _stars = 5;
  final _remarks = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _remarks.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final res = await http.get(
        Uri.parse('$apiBaseUrl/api/restaurant/feedback/${widget.token}'),
      );
      final data = jsonDecode(res.body);
      if (res.statusCode != 200) {
        throw Exception(data['error'] ?? 'Invalid feedback link');
      }
      final order = Map<String, dynamic>.from(data['order'] as Map? ?? {});
      setState(() {
        _orderId = order['order_id']?.toString();
        _submitted = order['feedback_submitted'] == true;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      final res = await http.post(
        Uri.parse('$apiBaseUrl/api/restaurant/feedback/${widget.token}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'stars': _stars, 'remarks': _remarks.text.trim()}),
      );
      if (res.statusCode != 200) {
        final data = jsonDecode(res.body);
        throw Exception(data['error'] ?? 'Failed to submit feedback');
      }
      setState(() => _submitted = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: Column(
        children: [
          const CustomerWebsiteTopBar(showCartAndCustomerAuth: false),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Card(
                  margin: const EdgeInsets.all(24),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: _buildContent(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Text(_error!, style: const TextStyle(color: Colors.red));
    }
    if (_submitted) {
      return const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, color: Colors.green, size: 48),
          SizedBox(height: 12),
          Text('Thank you for your feedback.'),
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Feedback for $_orderId',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text('How was your restaurant order?'),
        const SizedBox(height: 8),
        Row(
          children: List.generate(5, (idx) {
            final selected = idx < _stars;
            return IconButton(
              onPressed: () => setState(() => _stars = idx + 1),
              icon: Icon(
                selected ? Icons.star : Icons.star_border,
                color: selected ? Colors.amber : null,
              ),
            );
          }),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _remarks,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Remarks',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: _submitting ? null : _submit,
            child:
                _submitting
                    ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Text('Submit feedback'),
          ),
        ),
      ],
    );
  }
}
