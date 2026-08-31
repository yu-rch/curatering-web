import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/website_content_store.dart';
import '../widgets/antd_message.dart';
import '../widgets/contact_address_map.dart';
import '../widgets/website_rich_text.dart';
import '../theme/website_header_font.dart';
import '../utils/responsive_layout.dart';

class CustomerContactSection extends StatefulWidget {
  const CustomerContactSection({
    required this.store,
    required this.contentEditable,
    required this.pickB64,
  });

  final WebsiteContentStore store;
  final bool contentEditable;
  final Future<String?> Function() pickB64;

  @override
  State<CustomerContactSection> createState() => _CustomerContactSectionState();
}

class _CustomerContactSectionState extends State<CustomerContactSection> {
  final _helpNameCtrl = TextEditingController();
  final _helpEmailCtrl = TextEditingController();
  final _helpMessageCtrl = TextEditingController();
  bool _submittingHelp = false;

  @override
  void dispose() {
    _helpNameCtrl.dispose();
    _helpEmailCtrl.dispose();
    _helpMessageCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitHelpRequest() async {
    if (_helpNameCtrl.text.trim().isEmpty ||
        _helpEmailCtrl.text.trim().isEmpty ||
        _helpMessageCtrl.text.trim().isEmpty) {
      showAntdMessage(
        context,
        'Please fill in all message fields',
        type: AntdMessageType.error,
      );
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Send message?'),
            content: const Text('Submit this message to Curatering?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Send'),
              ),
            ],
          ),
    );
    if (ok != true) return;

    setState(() => _submittingHelp = true);
    try {
      await ApiClient.instance.postJson(
        '/api/public/help-requests',
        body: {
          'name': _helpNameCtrl.text.trim(),
          'email': _helpEmailCtrl.text.trim(),
          'message': _helpMessageCtrl.text.trim(),
        },
      );
      if (!mounted) return;
      showAntdMessage(context, 'Message sent successfully');
      _helpNameCtrl.clear();
      _helpEmailCtrl.clear();
      _helpMessageCtrl.clear();
    } catch (e) {
      if (!mounted) return;
      showAntdMessage(
        context,
        'Failed to send message',
        type: AntdMessageType.error,
      );
    } finally {
      if (mounted) setState(() => _submittingHelp = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        return SingleChildScrollView(
          padding: appPagePadding(context, vertical: 32),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: appContentMaxWidth(context),
              ),
              child: Column(
                children: [
                  WebsiteRichText(
                    value: widget.store.contactTitle,
                    style: websiteHeaderStyle(
                      fontSize: 42,
                      color: Colors.red.shade400,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFFFC024)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: WebsiteRichText(
                      value: widget.store.contactBannerText,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (widget.store.contactPageIntro.trim().isNotEmpty) ...[
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: WebsiteRichText(
                        value: widget.store.contactPageIntro,
                        style: const TextStyle(fontSize: 15, height: 1.45),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        WebsiteRichText(
                          value: widget.store.contactReachUsLabel,
                          style: websiteHeaderStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1E1E1E),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _contactRow(
                          Icons.facebook,
                          widget.store.contactFacebook,
                          widget.contentEditable,
                          context,
                          (ctx) async {
                            final t = TextEditingController(
                              text: widget.store.contactFacebook,
                            );
                            await showDialog<void>(
                              context: ctx,
                              builder:
                                  (dctx) => AlertDialog(
                                    content: TextField(controller: t),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(dctx),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          widget.store.contactFacebook = t.text;
                                          widget.store.saveDraft();
                                          Navigator.pop(dctx);
                                        },
                                        child: const Text('Save'),
                                      ),
                                    ],
                                  ),
                            );
                          },
                        ),
                        _contactRow(
                          Icons.place,
                          widget.store.contactAddress,
                          widget.contentEditable,
                          context,
                          (ctx) async {
                            final t = TextEditingController(
                              text: widget.store.contactAddress,
                            );
                            await showDialog<void>(
                              context: ctx,
                              builder:
                                  (dctx) => AlertDialog(
                                    content: TextField(
                                      controller: t,
                                      maxLines: 2,
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(dctx),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          widget.store.contactAddress = t.text;
                                          widget.store.saveDraft();
                                          Navigator.pop(dctx);
                                        },
                                        child: const Text('Save'),
                                      ),
                                    ],
                                  ),
                            );
                          },
                        ),
                        if (widget.store.contactAddress.trim().isNotEmpty) ...[
                          const SizedBox(height: 12),
                          ContactAddressMap(
                            address: widget.store.contactAddress,
                          ),
                        ],
                        _contactRow(
                          Icons.schedule,
                          widget.store.contactHours,
                          widget.contentEditable,
                          context,
                          (ctx) async {
                            final t = TextEditingController(
                              text: widget.store.contactHours,
                            );
                            await showDialog<void>(
                              context: ctx,
                              builder:
                                  (dctx) => AlertDialog(
                                    title: const Text('Hours'),
                                    content: TextField(controller: t),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(dctx),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          widget.store.contactHours = t.text;
                                          widget.store.saveDraft();
                                          Navigator.pop(dctx);
                                        },
                                        child: const Text('Save'),
                                      ),
                                    ],
                                  ),
                            );
                          },
                        ),
                        _contactRow(
                          Icons.phone,
                          widget.store.contactPhone,
                          widget.contentEditable,
                          context,
                          (ctx) async {
                            final t = TextEditingController(
                              text: widget.store.contactPhone,
                            );
                            await showDialog<void>(
                              context: ctx,
                              builder:
                                  (dctx) => AlertDialog(
                                    title: const Text('Phone'),
                                    content: TextField(controller: t),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(dctx),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          widget.store.contactPhone = t.text;
                                          widget.store.saveDraft();
                                          Navigator.pop(dctx);
                                        },
                                        child: const Text('Save'),
                                      ),
                                    ],
                                  ),
                            );
                          },
                        ),
                        _contactRow(
                          Icons.email,
                          widget.store.contactEmail,
                          widget.contentEditable,
                          context,
                          (ctx) async {
                            final t = TextEditingController(
                              text: widget.store.contactEmail,
                            );
                            await showDialog<void>(
                              context: ctx,
                              builder:
                                  (dctx) => AlertDialog(
                                    title: const Text('Email'),
                                    content: TextField(controller: t),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(dctx),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          widget.store.contactEmail = t.text;
                                          widget.store.saveDraft();
                                          Navigator.pop(dctx);
                                        },
                                        child: const Text('Save'),
                                      ),
                                    ],
                                  ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Message Us Form
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.grey.shade50,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'MESSAGE US',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Send us a message and we\'ll get back to you.',
                          style: TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _helpNameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Your Name',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _helpEmailCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Email Address',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _helpMessageCtrl,
                          decoration: const InputDecoration(
                            labelText: 'How can we help you?',
                            border: OutlineInputBorder(),
                            alignLabelWithHint: true,
                          ),
                          maxLines: 4,
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed:
                                _submittingHelp ? null : _submitHelpRequest,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFFC024),
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child:
                                _submittingHelp
                                    ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                    : const Text('SEND MESSAGE'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _contactRow(
    IconData icon,
    String text,
    bool edit,
    BuildContext context,
    Future<void> Function(BuildContext ctx) onEdit,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
          if (edit)
            IconButton(
              icon: const Icon(Icons.edit, size: 18),
              onPressed: () => onEdit(context),
            ),
        ],
      ),
    );
  }
}
