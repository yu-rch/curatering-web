import 'package:flutter/material.dart';

import '../data_store.dart';

/// Ant Design–inspired tokens + Curatering brand colors.
abstract final class AntdTokens {
  static bool get _dark => DataStore.isDarkMode.value;

  static const Color brandPrimary = Color(0xFFFFC024);
  static const Color brandOnPrimary = Color(0xFF1E1E1E);
  static const Color blue = Color(0xFF1677FF);
  static const Color menuBg = Color(0xFF1F1F1F);
  static const Color error = Color(0xFFFF4D4F);
  static const Color success = Color(0xFF52C41A);
  static const Color warning = Color(0xFFFAAD14);
  static const Color info = Color(0xFF1677FF);
  static const Color messageBarBg = Color(0xFF1F1F1F);

  static Color get staffBg =>
      _dark ? const Color(0xFF141414) : const Color(0xFFF5F7FA);
  static Color get pageBg => staffBg;
  static Color get cardBg => _dark ? const Color(0xFF1F1F1F) : Colors.white;
  static Color get tableHeaderBg =>
      _dark ? const Color(0xFF2A2A2A) : const Color(0xFFFAFAFA);
  static Color get modalBg => cardBg;
  static Color get borderSubtle =>
      _dark ? const Color(0xFF434343) : const Color(0xFFE8E8E8);
  static Color get border =>
      _dark ? const Color(0xFF595959) : const Color(0xFFD9D9D9);
  static Color get labelMuted =>
      _dark ? const Color(0xFFD9D9D9) : const Color(0xFF8C8C8C);
  static Color get valueDark =>
      _dark ? const Color(0xFFFAFAFA) : const Color(0xFF262626);
  static Color get textSecondary =>
      _dark ? const Color(0xFFE0E0E0) : const Color(0xFF595959);
  static Color get fillTertiary =>
      _dark ? const Color(0xFF2F2F2F) : const Color(0xFFF5F5F5);

  static const double radiusSm = 6;
  static const double radiusMd = 10;
  static const double radiusLg = 14;
}
