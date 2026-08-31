import 'package:flutter/material.dart';

import '../pages/customer_contact_section.dart' deferred as contact;
import '../services/website_content_store.dart';

/// Loads the contact tab in a separate deferred chunk.
class LazyCustomerContactSection extends StatefulWidget {
  const LazyCustomerContactSection({
    super.key,
    required this.store,
    required this.contentEditable,
    required this.pickB64,
  });

  final WebsiteContentStore store;
  final bool contentEditable;
  final Future<String?> Function() pickB64;

  @override
  State<LazyCustomerContactSection> createState() =>
      _LazyCustomerContactSectionState();
}

class _LazyCustomerContactSectionState extends State<LazyCustomerContactSection> {
  bool _ready = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    contact.loadLibrary().then((_) {
      if (mounted) setState(() => _ready = true);
    }).catchError((Object e) {
      if (mounted) setState(() => _error = e);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return const Center(child: Text('Failed to load contact page.'));
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
    return contact.CustomerContactSection(
      store: widget.store,
      contentEditable: widget.contentEditable,
      pickB64: widget.pickB64,
    );
  }
}
