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
  defaultValue: 'https://curatering-web-production-4978.up.railway.app',
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
    _apiBaseUrl.isEmpty
        ? 'https://curatering-web-production-4978.up.railway.app'
        : _apiBaseUrl;
