import 'package:flutter/material.dart';

import 'customer_fonts.dart';

/// Display font for customer-facing headings (replaces Dancing Script).
TextStyle websiteHeaderStyle({
  double fontSize = 42,
  FontWeight? fontWeight,
  Color? color,
  double? height,
  double? letterSpacing,
}) {
  return CustomerFonts.scheherazadeNew(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
  );
}
