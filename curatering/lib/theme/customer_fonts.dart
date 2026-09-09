import 'package:flutter/material.dart';

/// Customer-facing font styles loaded via CSS in [web/index.html].
/// Avoids bundling the heavy `google_fonts` Dart package into deferred JS chunks.
abstract final class CustomerFonts {
  static const _fallback = ['system-ui', 'Segoe UI', 'Roboto', 'sans-serif'];

  static TextStyle poppins({
    TextStyle? textStyle,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? fontSize,
    Color? color,
    double? height,
    double? letterSpacing,
    TextDecoration? decoration,
  }) {
    return (textStyle ?? const TextStyle()).copyWith(
      fontFamily: 'Poppins',
      fontFamilyFallback: _fallback,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      fontSize: fontSize,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
      decoration: decoration,
    );
  }

  static TextStyle inter({
    TextStyle? textStyle,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? fontSize,
    Color? color,
    double? height,
    double? letterSpacing,
  }) {
    // Prefer Poppins on the customer site so we can omit the Inter webfont.
    return poppins(
      textStyle: textStyle,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      fontSize: fontSize,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle pacifico({
    TextStyle? textStyle,
    FontWeight? fontWeight,
    double? fontSize,
    Color? color,
    double? height,
    double? letterSpacing,
  }) {
    return (textStyle ?? const TextStyle()).copyWith(
      fontFamily: 'Pacifico',
      fontFamilyFallback: _fallback,
      fontWeight: fontWeight,
      fontSize: fontSize,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle playfairDisplay({
    TextStyle? textStyle,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? fontSize,
    Color? color,
    double? height,
    double? letterSpacing,
  }) {
    return (textStyle ?? const TextStyle()).copyWith(
      fontFamily: 'Playfair Display',
      fontFamilyFallback: const ['Georgia', 'serif'],
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      fontSize: fontSize,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle scheherazadeNew({
    TextStyle? textStyle,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? fontSize,
    Color? color,
    double? height,
    double? letterSpacing,
  }) {
    return (textStyle ?? const TextStyle()).copyWith(
      fontFamily: 'Scheherazade New',
      fontFamilyFallback: const ['Georgia', 'serif'],
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      fontSize: fontSize,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle getFont(
    String family, {
    TextStyle? textStyle,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? fontSize,
    Color? color,
    double? height,
    double? letterSpacing,
    TextDecoration? decoration,
  }) {
    final name = family.trim();
    final base = textStyle ?? const TextStyle();
    if (name.isEmpty) return base;
    return base.copyWith(
      fontFamily: name,
      fontFamilyFallback: _fallback,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      fontSize: fontSize,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
      decoration: decoration,
    );
  }
}
