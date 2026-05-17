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

const String _googleMapsApiKey = String.fromEnvironment(
  'GOOGLE_MAPS_API_KEY',
  defaultValue: '',
);

// Runtime getters with fallbacks for dev mode (String.fromEnvironment doesn't work in JIT mode)
String get supabaseUrl =>
    _supabaseUrl.isEmpty
        ? 'https://ffgifzwwqdjeyyedaciu.supabase.co/rest/v1/'
        : _supabaseUrl;

String get supabaseAnonKey =>
    _supabaseAnonKey.isEmpty
        ? 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZmZ2lmend3cWRqZXl5ZWRhY2l1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU4MjQ3MDMsImV4cCI6MjA5MTQwMDcwM30.wmkpsHXTQVjwYYYCDQ5d5hEeSMM9dv4C26vV9pWrMG0'
        : _supabaseAnonKey;

String get apiBaseUrl =>
    _apiBaseUrl.isEmpty ? 'https://curatering.up.railway.app' : _apiBaseUrl;

/// Same key as [web/index.html] Maps script — enable Geocoding API in Google Cloud.
String get googleMapsApiKey {
  if (_googleMapsApiKey.isNotEmpty) return _googleMapsApiKey;
  // Local/dev fallback when not passed via --dart-define (matches web/index.html).
  return 'AIzaSyAfyCaQ7PYtpqGgJIX7MvoWfoTFp-6cY0M';
}
