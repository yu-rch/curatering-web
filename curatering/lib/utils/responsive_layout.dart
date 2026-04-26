import 'package:flutter/material.dart';

bool isMobileWidth(BuildContext context) => MediaQuery.of(context).size.width < 700;
bool isTabletWidth(BuildContext context) =>
    MediaQuery.of(context).size.width >= 700 && MediaQuery.of(context).size.width < 1100;
bool isDesktopWidth(BuildContext context) => MediaQuery.of(context).size.width >= 1100;

double appContentMaxWidth(BuildContext context) {
  final width = MediaQuery.of(context).size.width;
  if (width >= 1800) return 1680;
  if (width >= 1400) return 1440;
  if (width >= 1100) return 1280;
  return double.infinity;
}

EdgeInsets appPagePadding(BuildContext context, {double vertical = 24}) {
  final horizontal = isDesktopWidth(context)
      ? 40.0
      : isTabletWidth(context)
          ? 24.0
          : 16.0;
  return EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical);
}
