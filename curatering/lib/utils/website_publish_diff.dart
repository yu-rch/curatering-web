import 'dart:convert';

/// Human-readable labels for CMS publish diff (draft vs live).
const Map<String, String> kWebsitePublishFieldLabels = {
  'homeHeroImageBase64': 'Homepage hero image',
  'latestEventTitle': 'Homepage — latest event title',
  'latestEventSubtitle': 'Homepage — latest event subtitle',
  'latestEventBody': 'Homepage — latest event body',
  'redBannerText': 'Homepage — banner text',
  'latestEventSectionLabel': 'Homepage — latest event section label',
  'popularDishesSectionLabel': 'Homepage — popular dishes section',
  'popularDishesSubtitle': 'Homepage — popular dishes subtitle',
  'eventDesignsSectionLabel': 'Homepage — event designs section',
  'eventDesignsSubtitle': 'Homepage — event designs subtitle',
  'latestEventCollageBase64': 'Homepage — latest event collage',
  'popularDishImageBase64': 'Homepage — popular dish images',
  'eventDesignImageBase64': 'Homepage — event design images',
  'homeLayout': 'Homepage — section layout & visibility',
  'ownerBlurb': 'Brand — owner blurb',
  'kitchenPanelTitle': 'Homepage — kitchen panel',
  'kitchenPanelSubtitle': 'Homepage — kitchen panel subtitle',
  'cateringPanelTitle': 'Homepage — catering panel',
  'cateringPanelSubtitle': 'Homepage — catering panel subtitle',
  'sitePrimaryColor': 'Brand — primary color',
  'siteAccentColor': 'Brand — accent color',
  'headerLogoBase64': 'Brand — header logo',
  'loginLogoBase64': 'Brand — login logo',
  'restaurantPageTitle': 'Restaurant page',
  'restaurantPageSubtitle': 'Restaurant page subtitle',
  'cateringPageTitle': 'Catering page',
  'cateringPageSubtitle': 'Catering page subtitle',
  'inquiryPageTitle': 'Inquiry page',
  'inquiryPageSubtitle': 'Inquiry page subtitle',
  'galleryTitle': 'Gallery page',
  'galleryIntro': 'Gallery intro',
  'galleryCategories': 'Gallery categories & images',
  'contactTitle': 'Contact page title',
  'contactBannerText': 'Contact banner',
  'contactReachUsLabel': 'Contact — reach us label',
  'contactPageIntro': 'Contact page intro',
  'contactFacebookUrl': 'Contact — Facebook URL',
  'contactFacebook': 'Contact — Facebook label',
  'contactAddress': 'Contact — address',
  'contactHours': 'Contact — hours',
  'contactPhone': 'Contact — phone',
  'contactEmail': 'Contact — email',
  'footerCopyright': 'Footer copyright',
  'footerPrivacyLabel': 'Footer privacy label',
  'footerPrivacyBody': 'Footer privacy text',
  'navBrandLabel': 'Navigation brand label',
  'navItems': 'Navigation menu items',
  'customPages': 'Custom pages',
  'pageExtraSections': 'Page extra sections',
  'faqItems': 'FAQ items',
  'mobileUi': 'Mobile app layout',
};

List<String> describeWebsitePublishChanges({
  required Map<String, dynamic> draft,
  Map<String, dynamic>? publishedBaseline,
}) {
  if (publishedBaseline == null || publishedBaseline.isEmpty) {
    return const ['Draft edits (live baseline unavailable)'];
  }

  final changed = <String>[];
  for (final entry in kWebsitePublishFieldLabels.entries) {
    final a = jsonEncode(draft[entry.key]);
    final b = jsonEncode(publishedBaseline[entry.key]);
    if (a != b) changed.add(entry.value);
  }
  return changed.isEmpty ? const ['No detectable changes from live site'] : changed;
}
