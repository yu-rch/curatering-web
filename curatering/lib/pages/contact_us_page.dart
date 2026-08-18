import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../services/website_content_store.dart';
import '../widgets/centered_viewport_scroll.dart';
import '../widgets/website_rich_text.dart';
import '../widgets/contact_address_map.dart';
import '../utils/maps_launcher.dart';
import '../widgets/customer_website_topbar.dart';

// Font constants
const String _primaryFont = 'Inter';

//Responsive Helpers
bool isMobile(BuildContext context) => MediaQuery.of(context).size.width < 700;

bool isTablet(BuildContext context) =>
    MediaQuery.of(context).size.width >= 700 &&
    MediaQuery.of(context).size.width < 1100;

bool isDesktop(BuildContext context) =>
    MediaQuery.of(context).size.width >= 1100;

EdgeInsets websitePagePadding(BuildContext context, {double vertical = 24}) {
  final horizontal =
      isDesktop(context)
          ? 40.0
          : isTablet(context)
          ? 24.0
          : 16.0;
  return EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical);
}

class ContactUsPage extends StatefulWidget {
  const ContactUsPage({
    super.key,
    this.contentEditable = false,
    this.showStaffChrome = true,
  });

  final bool contentEditable;
  final bool showStaffChrome;

  @override
  State<ContactUsPage> createState() => _ContactUsPageState();
}

class _ContactUsPageState extends State<ContactUsPage> {
  final _feedbackFormKey = GlobalKey<FormState>();
  final _mailFormKey = GlobalKey<FormState>();
  final _emailSectionKey = GlobalKey();
  final _feedbackSectionKey = GlobalKey();
  final _faqSectionKey = GlobalKey();
  final _feedbackNameController = TextEditingController();
  final _feedbackEmailController = TextEditingController();
  final _feedbackMessageController = TextEditingController();
  bool _isSubmittingFeedback = false;
  int _feedbackRating = 0;

  // Separate "Mail us" form (feedback form is for ratings).
  final _mailNameController = TextEditingController();
  final _mailEmailController = TextEditingController();
  final _mailMessageController = TextEditingController();
  bool _isSubmittingMail = false;

  @override
  void initState() {
    super.initState();
    WebsiteContentStore.instance.addListener(_onContent);
    WebsiteContentStore.instance.ensureLoaded().then((_) {
      if (mounted) setState(() {});
    });
  }

  void _onContent() {
    if (mounted) setState(() {});
  }

  void _scrollTo(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      alignment: 0.08,
    );
  }

  @override
  void dispose() {
    WebsiteContentStore.instance.removeListener(_onContent);
    _feedbackNameController.dispose();
    _feedbackEmailController.dispose();
    _feedbackMessageController.dispose();
    _mailNameController.dispose();
    _mailEmailController.dispose();
    _mailMessageController.dispose();
    super.dispose();
  }

  Future<void> _submitFeedback() async {
    if (!_feedbackFormKey.currentState!.validate()) return;

    setState(() => _isSubmittingFeedback = true);
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/api/contact-feedback'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': _feedbackNameController.text.trim(),
          'email': _feedbackEmailController.text.trim(),
          'rating': _feedbackRating,
          'message': _feedbackMessageController.text.trim(),
        }),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final decoded = jsonDecode(response.body);
        throw Exception(decoded['error'] ?? 'Failed to submit feedback.');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Feedback submitted. Thank you!'),
          backgroundColor: Colors.green,
        ),
      );
      _feedbackNameController.clear();
      _feedbackEmailController.clear();
      _feedbackMessageController.clear();
      setState(() => _feedbackRating = 0);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to submit feedback. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmittingFeedback = false);
    }
  }

  Future<void> _submitMail() async {
    final form = _mailFormKey.currentState;
    if (form == null || !form.validate()) return;

    setState(() => _isSubmittingMail = true);
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/api/contact-feedback'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': _mailNameController.text.trim(),
          'email': _mailEmailController.text.trim(),
          'message': _mailMessageController.text.trim(),
          // Intentionally omit `rating` for the mail form.
        }),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final decoded = jsonDecode(response.body);
        throw Exception(decoded['error'] ?? 'Failed to send message.');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message sent. Thank you!'),
          backgroundColor: Colors.green,
        ),
      );

      _mailNameController.clear();
      _mailEmailController.clear();
      _mailMessageController.clear();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to send message. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmittingMail = false);
    }
  }

  Future<void> _launchPhone(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _launchMap(String address) async {
    await openOsmMap(address);
  }

  @override
  Widget build(BuildContext context) {
    final w = WebsiteContentStore.instance;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CustomerWebsiteTopBar(
            showCartAndCustomerAuth: !widget.contentEditable,
          ),
          Expanded(
            child: CenteredViewportScroll(
              padding: websitePagePadding(context, vertical: 12),
              mainAxisAlignment: MainAxisAlignment.start,
              child:
                  isDesktop(context)
                      ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'GET IN TOUCH',
                                  style: GoogleFonts.getFont(
                                    _primaryFont,
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF1E1E1E),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                WebsiteRichText(
                                  value: w.contactPageIntro,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                    height: 1.35,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    ActionChip(
                                      avatar: const Icon(Icons.email_outlined, size: 16),
                                      label: const Text('Email us'),
                                      onPressed: () => _scrollTo(_emailSectionKey),
                                    ),
                                    ActionChip(
                                      avatar: const Icon(Icons.rate_review_outlined, size: 16),
                                      label: const Text('Feedback'),
                                      onPressed: () => _scrollTo(_feedbackSectionKey),
                                    ),
                                    ActionChip(
                                      avatar: const Icon(Icons.help_outline, size: 16),
                                      label: const Text('FAQ'),
                                      onPressed: () => _scrollTo(_faqSectionKey),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                KeyedSubtree(
                                  key: _emailSectionKey,
                                  child: _buildEmailUsHero(w),
                                ),
                                const SizedBox(height: 12),
                                KeyedSubtree(
                                  key: _feedbackSectionKey,
                                  child: _buildFeedbackModule(),
                                ),
                                const SizedBox(height: 20),
                                KeyedSubtree(
                                  key: _faqSectionKey,
                                  child: _buildFaqSection(w),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(child: _buildContactInfo(w)),
                        ],
                      )
                      : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'GET IN TOUCH',
                            style: GoogleFonts.getFont(
                              _primaryFont,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1E1E1E),
                            ),
                          ),
                          const SizedBox(height: 8),
                          WebsiteRichText(
                            value: w.contactPageIntro,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ActionChip(
                                avatar: const Icon(Icons.email_outlined, size: 16),
                                label: const Text('Email us'),
                                onPressed: () => _scrollTo(_emailSectionKey),
                              ),
                              ActionChip(
                                avatar: const Icon(Icons.rate_review_outlined, size: 16),
                                label: const Text('Feedback'),
                                onPressed: () => _scrollTo(_feedbackSectionKey),
                              ),
                              ActionChip(
                                avatar: const Icon(Icons.help_outline, size: 16),
                                label: const Text('FAQ'),
                                onPressed: () => _scrollTo(_faqSectionKey),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          KeyedSubtree(
                            key: _emailSectionKey,
                            child: _buildEmailUsHero(w),
                          ),
                          const SizedBox(height: 12),
                          KeyedSubtree(
                            key: _feedbackSectionKey,
                            child: _buildFeedbackModule(),
                          ),
                          const SizedBox(height: 16),
                          _buildContactInfo(w),
                          const SizedBox(height: 20),
                          KeyedSubtree(
                            key: _faqSectionKey,
                            child: _buildFaqSection(w),
                          ),
                        ],
                      ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailUsHero(WebsiteContentStore w) {
    return Card(
      elevation: 0,
      color: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _mailFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFC024),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(
                      Icons.mail_outline,
                      color: Color(0xFF1E1E1E),
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mail us',
                          style: GoogleFonts.getFont(
                            _primaryFont,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'We reply within one business day.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.75),
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _mailNameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                validator: (v) {
                  final t = v?.trim() ?? '';
                  if (t.isEmpty) return 'Name is required';
                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _mailEmailController,
                decoration: const InputDecoration(
                  labelText: 'Email Address',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  final t = v?.trim() ?? '';
                  if (t.isEmpty) return 'Email is required';
                  if (!t.contains('@')) return 'Please enter a valid email';
                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _mailMessageController,
                decoration: const InputDecoration(
                  labelText: 'Message',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                maxLines: 4,
                validator: (v) {
                  final t = v?.trim() ?? '';
                  if (t.length < 3) return 'Please enter your message';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isSubmittingMail ? null : _submitMail,
                  icon: _isSubmittingMail
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_outlined),
                  label: Text(
                    _isSubmittingMail ? 'SENDING…' : 'SEND MESSAGE',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Direct email: ${w.contactEmail}',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFaqSection(WebsiteContentStore w) {
    final items = w.faqItems;
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Frequently asked questions',
          style: GoogleFonts.getFont(
            _primaryFont,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1E1E1E),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Quick answers — editable from the website CMS.',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 10),
        ...items.map((item) {
          final q = item.question.trim();
          final a = item.answer.trim();
          if (q.isEmpty && a.isEmpty) return const SizedBox.shrink();
          return Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 14),
              childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              title: Text(
                q.isEmpty ? 'Question' : q,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E1E1E),
                ),
              ),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    a.isEmpty ? '—' : a,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildFeedbackModule() {
    final twoCol = !isMobile(context);
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Form(
          key: _feedbackFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Share your feedback',
                style: GoogleFonts.getFont(
                  _primaryFont,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E1E1E),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Tell us what worked well or what we can improve.',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 10),
              if (twoCol)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _feedbackNameField()),
                    const SizedBox(width: 10),
                    Expanded(child: _feedbackEmailField()),
                  ],
                )
              else ...[
                _feedbackNameField(),
                const SizedBox(height: 8),
                _feedbackEmailField(),
              ],
              const SizedBox(height: 8),
              if (twoCol)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _feedbackRatingField()),
                    const SizedBox(width: 10),
                    Expanded(child: _feedbackMessageField()),
                  ],
                )
              else ...[
                _feedbackRatingField(),
                const SizedBox(height: 8),
                _feedbackMessageField(),
              ],
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isSubmittingFeedback ? null : _submitFeedback,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1E1E1E),
                    side: const BorderSide(color: Color(0xFF1E1E1E)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon:
                      _isSubmittingFeedback
                          ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.rate_review_outlined, size: 18),
                  label: Text(
                    _isSubmittingFeedback ? 'SUBMITTING...' : 'SUBMIT FEEDBACK',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _feedbackNameField() {
    return TextFormField(
      controller: _feedbackNameController,
      decoration: const InputDecoration(
        labelText: 'Name',
        border: OutlineInputBorder(),
        isDense: true,
      ),
    );
  }

  Widget _feedbackEmailField() {
    return TextFormField(
      controller: _feedbackEmailController,
      decoration: const InputDecoration(
        labelText: 'Email Address',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      keyboardType: TextInputType.emailAddress,
      validator: (value) {
        final text = value?.trim() ?? '';
        if (text.isNotEmpty && !text.contains('@')) {
          return 'Please enter a valid email';
        }
        return null;
      },
    );
  }

  Widget _feedbackRatingField() {
    return FormField<int>(
      validator: (_) {
        if (_feedbackRating < 1) return 'Rating is required';
        return null;
      },
      builder: (state) {
        return InputDecorator(
          decoration: InputDecoration(
            labelText: 'Rating *',
            border: const OutlineInputBorder(),
            isDense: true,
            errorText: state.errorText,
          ),
          child: Row(
            children: List.generate(5, (index) {
              final star = index + 1;
              return IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: '$star star${star == 1 ? '' : 's'}',
                onPressed:
                    _isSubmittingFeedback
                        ? null
                        : () {
                          setState(() => _feedbackRating = star);
                          state.didChange(star);
                        },
                icon: Icon(
                  star <= _feedbackRating ? Icons.star : Icons.star_border,
                  color: Colors.amber.shade700,
                  size: 26,
                ),
              );
            }),
          ),
        );
      },
    );
  }

  Widget _feedbackMessageField() {
    return TextFormField(
      controller: _feedbackMessageController,
      decoration: const InputDecoration(
        labelText: 'Feedback',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      maxLines: 4,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter your feedback';
        }
        return null;
      },
    );
  }

  Widget _buildContactInfo(WebsiteContentStore w) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Contact Information',
          style: GoogleFonts.getFont(
            _primaryFont,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1E1E1E),
          ),
        ),
        const SizedBox(height: 8),
        _ContactCard(
          icon: Icons.place,
          title: 'Address',
          subtitle: w.contactAddress,
          onTap: () => _launchMap(w.contactAddress),
        ),
        const SizedBox(height: 6),
        ContactAddressMap(address: w.contactAddress, height: 120),
        const SizedBox(height: 8),
        _ContactCard(
          icon: Icons.phone,
          title: 'Phone',
          subtitle: w.contactPhone,
          onTap: () => _launchPhone(w.contactPhone),
        ),
        const SizedBox(height: 8),
        _ContactCard(
          icon: Icons.email,
          title: 'Email us',
          subtitle: w.contactEmail,
          emphasize: true,
          onTap: () => _scrollTo(_emailSectionKey),
        ),
        const SizedBox(height: 8),
        _ContactCard(
          icon: Icons.schedule,
          title: 'Business Hours',
          subtitle: w.contactHours,
          onTap: null,
        ),
        const SizedBox(height: 8),
        _ContactCard(
          icon: Icons.facebook,
          title: 'Facebook',
          subtitle: w.contactFacebook,
          onTap: () {
            final url = w.contactFacebookUrl.trim().isNotEmpty
                ? w.contactFacebookUrl.trim()
                : 'https://www.facebook.com/3tavs';
            launchUrl(Uri.parse(url));
          },
        ),
      ],
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.emphasize = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final accent = emphasize ? const Color(0xFFFFC024) : const Color(0xFF1E1E1E);
    return Card(
      elevation: emphasize ? 2 : 1,
      margin: EdgeInsets.zero,
      color: emphasize ? const Color(0xFFFFF8E6) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: emphasize
            ? const BorderSide(color: Color(0xFFFFC024), width: 1.5)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 10,
            vertical: emphasize ? 12 : 8,
          ),
          child: Row(
            children: [
              Container(
                width: emphasize ? 40 : 32,
                height: emphasize ? 40 : 32,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: emphasize ? 0.35 : 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  icon,
                  color: const Color(0xFF1E1E1E),
                  size: emphasize ? 20 : 16,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: emphasize ? 14 : 12,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1E1E1E),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: emphasize ? 13 : 12,
                        fontWeight:
                            emphasize ? FontWeight.w600 : FontWeight.normal,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(
                  Icons.arrow_forward_ios,
                  size: emphasize ? 14 : 12,
                  color: Colors.grey.shade500,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
