import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/site_routes.dart';
import '../services/website_content_store.dart';
import 'antd_buttons.dart';
import 'antd_dialog.dart';
import 'customer_footer_feedback.dart';
import 'website_rich_text.dart';

/// Shared customer-site footer (homepage, gallery, and other public pages).
class CustomerSiteFooter extends StatelessWidget {
  const CustomerSiteFooter({
    super.key,
    required this.store,
    this.contentEditable = false,
    this.isCustomerLoggedIn = false,
    this.onLogin,
    this.onSaved,
  });

  final WebsiteContentStore store;
  final bool contentEditable;
  final bool isCustomerLoggedIn;
  final Future<void> Function()? onLogin;
  final VoidCallback? onSaved;

  void _goRoute(BuildContext context, String route) {
    final target = customerRoute(route);
    final current = ModalRoute.of(context)?.settings.name ?? '';
    if (current == target) return;
    Navigator.pushReplacementNamed(context, target);
  }

  Future<void> _launchEmail(String email) async {
    final trimmed = email.trim();
    if (trimmed.isEmpty) return;
    try {
      await launchUrl(Uri(scheme: 'mailto', path: trimmed));
    } catch (e) {
      debugPrint('Failed to open mailto: $e');
    }
  }

  Future<void> _launchFacebook(String facebook) async {
    final trimmed =
        store.contactFacebookUrl.trim().isNotEmpty
            ? store.contactFacebookUrl.trim()
            : facebook.trim();
    final uri =
        trimmed.startsWith('http://') || trimmed.startsWith('https://')
            ? Uri.parse(trimmed)
            : Uri.parse(
              store.contactFacebookUrl.trim().isNotEmpty
                  ? store.contactFacebookUrl.trim()
                  : 'https://www.facebook.com/3tavs',
            );
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Failed to open Facebook: $e');
    }
  }

  /// Strip near-black CMS color tags so privacy body stays readable on white.
  static String readablePrivacyBody(String raw) {
    var s = raw;
    s = s.replaceAll(
      RegExp(r'\[color=#0{3,8}\]', caseSensitive: false),
      '',
    );
    s = s.replaceAll(
      RegExp(r'\[color=#1[Ee]1[Ee]1[Ee]\]', caseSensitive: false),
      '',
    );
    s = s.replaceAll(
      RegExp(r'\[color=#262626\]', caseSensitive: false),
      '',
    );
    s = s.replaceAll(
      RegExp(r'\[color=black\]', caseSensitive: false),
      '',
    );
    s = s.replaceAll('[/color]', '');
    s = s.replaceAll(
      RegExp(r'color\s*:\s*#0{3,8}\s*;?', caseSensitive: false),
      '',
    );
    s = s.replaceAll(
      RegExp(r'color\s*:\s*black\s*;?', caseSensitive: false),
      '',
    );
    return s;
  }

  Widget _pageLink(String label, VoidCallback onPressed) {
    return TextButton(
      onPressed: onPressed,
      child: Text(label, style: const TextStyle(color: Color(0xFFF5F7F9))),
    );
  }

  Widget _col(IconData icon, String text, {VoidCallback? onTap}) {
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 18, color: Colors.white),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white,
              decoration:
                  onTap != null ? TextDecoration.underline : TextDecoration.none,
              decorationColor: Colors.white70,
            ),
          ),
        ),
      ],
    );
    return SizedBox(
      width: 260,
      child:
          onTap == null
              ? row
              : InkWell(onTap: onTap, child: row),
    );
  }

  Widget _row(IconData icon, String text, {VoidCallback? onTap}) {
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 18, color: Colors.white),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: const Color(0xFFF5F7F9),
              decoration:
                  onTap != null ? TextDecoration.underline : TextDecoration.none,
              decorationColor: Colors.white70,
            ),
          ),
        ),
      ],
    );
    return onTap == null
        ? row
        : InkWell(onTap: onTap, child: row);
  }

  @override
  Widget build(BuildContext context) {
    final w = store;
    return Container(
      color: const Color(0xFF242424),
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth > 900;
          final cols = [
            SizedBox(
              width: wide ? null : 220,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextButton(
                    onPressed: () {
                      showAntdModal<void>(
                        context: context,
                        title: w.footerPrivacyLabel,
                        body: WebsiteRichText(
                          value: readablePrivacyBody(w.footerPrivacyBody),
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.55,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                        actions: [
                          AntdPrimaryButton(
                            label: 'Close',
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      );
                    },
                    child: Text(
                      w.footerPrivacyLabel,
                      style: const TextStyle(
                        color: Color(0xFFFFC024),
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                        decorationColor: Color(0xFFFFC024),
                      ),
                    ),
                  ),
                  WebsiteRichText(
                    value: w.footerCopyright,
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1.4,
                      color: Color(0xFFE8EAED),
                    ),
                  ),
                  if (contentEditable)
                    TextButton.icon(
                      onPressed: () async {
                        final value = await showWebsiteRichTextEditor(
                          context: context,
                          title: 'Edit footer copyright',
                          initialValue: w.footerCopyright,
                        );
                        if (value == null || value.isEmpty) return;
                        w.footerCopyright = value;
                        await w.saveDraft();
                        onSaved?.call();
                      },
                      icon: const Icon(Icons.edit, size: 14, color: Colors.white70),
                      label: const Text(
                        'Edit',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _pageLink('Gallery', () => _goRoute(context, '/gallery')),
                _pageLink(
                  'Catering Menu',
                  () => _goRoute(context, '/catering-menu'),
                ),
                _pageLink('Restaurant', () => _goRoute(context, '/restaurant')),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _pageLink('Inquire Now', () => _goRoute(context, '/inquire')),
                _pageLink('Contact Us', () => _goRoute(context, '/contact-us')),
                TextButton(
                  onPressed:
                      () => showCustomerFooterFeedback(
                        context,
                        isLoggedIn: isCustomerLoggedIn,
                        onLogin: onLogin ?? () async {},
                      ),
                  child: const Text(
                    'Feedback',
                    style: TextStyle(color: Color(0xFFF5F7F9)),
                  ),
                ),
              ],
            ),
            _col(
              Icons.facebook,
              w.contactFacebook,
              onTap: () => _launchFacebook(w.contactFacebook),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _row(Icons.place, w.contactAddress),
                _row(Icons.schedule, w.contactHours),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _row(Icons.phone, w.contactPhone),
                _row(
                  Icons.email,
                  w.contactEmail,
                  onTap: () => _launchEmail(w.contactEmail),
                ),
              ],
            ),
          ];
          if (wide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(
                  flex: 2,
                  child: cols[0],
                ),
                const SizedBox(width: 20),
                cols[1],
                const SizedBox(width: 20),
                cols[2],
                const SizedBox(width: 24),
                Flexible(flex: 3, child: cols[3]),
                const SizedBox(width: 16),
                Flexible(flex: 3, child: cols[4]),
                const SizedBox(width: 16),
                Flexible(flex: 2, child: cols[5]),
                const SizedBox(width: 16),
                Image.asset(
                  'lib/assets/main-2.png',
                  height: 72,
                  fit: BoxFit.contain,
                ),
              ],
            );
          }
          return Wrap(
            spacing: 24,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.start,
            children: cols,
          );
        },
      ),
    );
  }
}
