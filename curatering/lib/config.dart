import 'package:flutter/foundation.dart';

const String _supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: '',
);

const String _supabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue: '',
);

const String _apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://curatering.up.railway.app',
);

/// Supabase project URL (root, not `/rest/v1/`).
String get supabaseUrl {
  if (_supabaseUrl.isNotEmpty) return _supabaseUrl;
  if (kDebugMode) {
    debugPrint(
      'SUPABASE_URL not set — pass --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co',
    );
  }
  return '';
}

String get supabaseAnonKey {
  if (_supabaseAnonKey.isNotEmpty) return _supabaseAnonKey;
  if (kDebugMode) {
    debugPrint(
      'SUPABASE_ANON_KEY not set — pass --dart-define=SUPABASE_ANON_KEY=...',
    );
  }
  return '';
}

String get apiBaseUrl =>
    _apiBaseUrl.isEmpty ? 'https://curatering.up.railway.app' : _apiBaseUrl;
