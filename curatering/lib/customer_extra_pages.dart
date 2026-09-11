import 'package:flutter/material.dart';

import 'config/site_routes.dart';
import 'pages/checkout_page.dart';
import 'pages/custom_cms_page.dart';
import 'pages/guest_order_tracking_page.dart';
import 'pages/inquire_page.dart';
import 'pages/my_caterings_page.dart';
import 'pages/my_order_tracking_page.dart';
import 'pages/my_orders_page.dart';
import 'pages/my_profile_page.dart';
import 'pages/restaurant_feedback_public_page.dart';

/// Secondary customer routes (gallery / catering-menu / restaurant /
/// contact-us load via their own deferred libraries in
/// [customer_page_loader.dart]).
Widget customerExtraPageFor(
  String path, {
  bool contentEditable = false,
  bool showStaffChrome = false,
}) {
  final route = stripLegacyCustomerPrefix(normalizeRoutePath(path));
  if (route.startsWith('/p/') && route.length > 3) {
    return CustomCmsPage(slug: route.substring(3));
  }
  switch (route) {
    case '/inquire':
      return InquirePage(
        contentEditable: contentEditable,
        showStaffChrome: showStaffChrome,
      );
    case '/my-inquiries':
      return const MyCateringsPage();
    case '/my-orders':
      return const MyOrdersPage();
    case '/my-profile':
      return const MyProfilePage();
    case '/my-tracking':
      return const MyOrderTrackingPage();
    case '/track-order':
      return const GuestOrderTrackingPage();
    case '/checkout':
      return const CheckoutPage();
    case '/restaurant-feedback':
      return RestaurantFeedbackPublicPage(
        token: Uri.base.queryParameters['token'] ?? '',
      );
    default:
      return const SizedBox.shrink();
  }
}
