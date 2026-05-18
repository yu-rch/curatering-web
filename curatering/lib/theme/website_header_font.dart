import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Display font for customer-facing headings (replaces Dancing Script).
TextStyle websiteHeaderStyle({
  double fontSize = 42,
  FontWeight? fontWeight,
  Color? color,
  double? height,
  double? letterSpacing,
}) {
  return GoogleFonts.scheherazadeNew(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
  );
}
