import 'package:flutter/material.dart';

import 'pages/catering_menu_page.dart';
import 'pages/checkout_page.dart';
import 'pages/contact_us_page.dart';
import 'pages/custom_cms_page.dart';
import 'pages/gallery_page.dart';
import 'pages/guest_order_tracking_page.dart';
import 'pages/inquire_page.dart';
import 'pages/my_caterings_page.dart';
import 'pages/my_order_tracking_page.dart';
import 'pages/my_orders_page.dart';
import 'pages/my_profile_page.dart';
import 'pages/restaurant_feedback_public_page.dart';
import 'pages/restaurant_order_page.dart';

/// Secondary customer pages loaded after the homepage JS chunk.
Widget customerExtraPageFor(String path) {
  if (path.startsWith('/p/') && path.length > 3) {
    return CustomCmsPage(slug: path.substring(3));
  }
  switch (path) {
    case '/gallery':
      return const GalleryPage(contentEditable: false, showStaffChrome: false);
    case '/contact-us':
      return const ContactUsPage(contentEditable: false, showStaffChrome: false);
    case '/inquire':
      return const InquirePage(contentEditable: false, showStaffChrome: false);
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
    case '/restaurant':
      return const RestaurantOrderPage(
        contentEditable: false,
        showStaffChrome: false,
      );
    case '/restaurant-feedback':
      return RestaurantFeedbackPublicPage(
        token: Uri.base.queryParameters['token'] ?? '',
      );
    case '/catering-menu':
      return const CateringMenuPage(
        contentEditable: false,
        showStaffChrome: false,
      );
    default:
      return const SizedBox.shrink();
  }
}
