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
  final _feedbackNameController = TextEditingController();
  final _feedbackEmailController = TextEditingController();
  final _feedbackMessageController = TextEditingController();
  bool _isSubmittingFeedback = false;
  int _feedbackRating = 5;

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

  @override
  void dispose() {
    WebsiteContentStore.instance.removeListener(_onContent);
    _feedbackNameController.dispose();
    _feedbackEmailController.dispose();
    _feedbackMessageController.dispose();
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
      setState(() => _feedbackRating = 5);
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

  Future<void> _launchPhone(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _launchEmail(String email) async {
    final uri = Uri.parse('mailto:$email');
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
              padding: websitePagePadding(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  Text(
                    'GET IN TOUCH',
                    style: GoogleFonts.getFont(
                      _primaryFont,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E1E1E),
                    ),
                  ),
                  const SizedBox(height: 16),
                  WebsiteRichText(
                    value: w.contactPageIntro,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 48),

                  if (isDesktop(context))
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 2, child: _buildFeedbackModule()),
                        const SizedBox(width: 48),
                        Expanded(child: _buildContactInfo(w)),
                      ],
                    )
                  else
                    Column(
                      children: [
                        _buildFeedbackModule(),
                        const SizedBox(height: 48),
                        _buildContactInfo(w),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackModule() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Form(
          key: _feedbackFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Share your feedback',
                style: GoogleFonts.getFont(
                  _primaryFont,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E1E1E),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tell us what worked well or what we can improve. Your feedback is reviewed by our team.',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _feedbackNameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _feedbackEmailController,
                decoration: const InputDecoration(
                  labelText: 'Email Address',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isNotEmpty && !text.contains('@')) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Text(
                'Rating',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: List.generate(5, (index) {
                  final star = index + 1;
                  return IconButton(
                    tooltip: '$star star${star == 1 ? '' : 's'}',
                    onPressed:
                        _isSubmittingFeedback
                            ? null
                            : () => setState(() => _feedbackRating = star),
                    icon: Icon(
                      star <= _feedbackRating ? Icons.star : Icons.star_border,
                      color: Colors.amber.shade700,
                      size: 28,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _feedbackMessageController,
                decoration: const InputDecoration(
                  labelText: 'Feedback',
                  border: OutlineInputBorder(),
                ),
                maxLines: 4,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your feedback';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isSubmittingFeedback ? null : _submitFeedback,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1E1E1E),
                    side: const BorderSide(color: Color(0xFF1E1E1E)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon:
                      _isSubmittingFeedback
                          ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.rate_review_outlined),
                  label: Text(
                    _isSubmittingFeedback ? 'SUBMITTING...' : 'SUBMIT FEEDBACK',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContactInfo(WebsiteContentStore w) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Contact Information',
          style: GoogleFonts.playfairDisplay(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1E1E1E),
          ),
        ),
        const SizedBox(height: 24),

        _ContactCard(
          icon: Icons.place,
          title: 'Address',
          subtitle: w.contactAddress,
          onTap: () => _launchMap(w.contactAddress),
        ),
        const SizedBox(height: 10),
        ContactAddressMap(address: w.contactAddress),
        const SizedBox(height: 16),

        _ContactCard(
          icon: Icons.phone,
          title: 'Phone',
          subtitle: w.contactPhone,
          onTap: () => _launchPhone(w.contactPhone),
        ),
        const SizedBox(height: 16),

        _ContactCard(
          icon: Icons.email,
          title: 'Email',
          subtitle: w.contactEmail,
          onTap: () => _launchEmail(w.contactEmail),
        ),
        const SizedBox(height: 16),

        _ContactCard(
          icon: Icons.schedule,
          title: 'Business Hours',
          subtitle: w.contactHours,
          onTap: null,
        ),
        const SizedBox(height: 16),

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
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(icon, color: const Color(0xFF1E1E1E), size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E1E1E),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey.shade400,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
