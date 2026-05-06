import 'package:supabase_flutter/supabase_flutter.dart';
import '../config.dart';

class SupabaseService {
  SupabaseService._();

  static final SupabaseService instance = SupabaseService._();

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  }

  SupabaseClient get client => Supabase.instance.client;

  // Get current user
  User? get currentUser => client.auth.currentUser;

  // Get current session
  Session? get currentSession => client.auth.currentSession;

  // Sign in with email/password
  Future<AuthResponse> signIn(String email, String password) async {
    return await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  // Sign out
  Future<void> signOut() async {
    await client.auth.signOut();
  }

  // Query table
  SupabaseQueryBuilder from(String table) {
    return client.from(table);
  }

  // Insert into table
  Future<Map<String, dynamic>> insert(String table, Map<String, dynamic> data) async {
    final response = await client.from(table).insert(data).select().single();
    return response;
  }

  // Update table
  Future<Map<String, dynamic>> update(
    String table,
    Map<String, dynamic> data, {
    required dynamic eq,
    required String column,
  }) async {
    final response = await client
        .from(table)
        .update(data)
        .eq(column, eq)
        .select()
        .single();
    return response;
  }

  // Delete from table
  Future<void> delete(String table, {required dynamic eq, required String column}) async {
    await client.from(table).delete().eq(column, eq);
  }
}
