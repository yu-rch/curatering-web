import 'package:flutter/material.dart';

import '../pages/customer_inquire_form.dart' deferred as inquire;

/// Loads the inquire / theme-design form in a separate deferred chunk.
class LazyCustomerInquireForm extends StatefulWidget {
  const LazyCustomerInquireForm({super.key, this.staffThemeStudioMode = false});

  final bool staffThemeStudioMode;

  @override
  State<LazyCustomerInquireForm> createState() =>
      _LazyCustomerInquireFormState();
}

class _LazyCustomerInquireFormState extends State<LazyCustomerInquireForm> {
  bool _ready = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    inquire.loadLibrary().then((_) {
      if (mounted) setState(() => _ready = true);
    }).catchError((Object e) {
      if (mounted) setState(() => _error = e);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Failed to load inquiry form. Please refresh.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );
    }
    if (!_ready) {
      return const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return inquire.CustomerInquireForm(
      staffThemeStudioMode: widget.staffThemeStudioMode,
    );
  }
}
