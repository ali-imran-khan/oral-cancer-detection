import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  SupabaseClient get client => Supabase.instance.client;

  Future<AuthResponse> signUp(String email, String password, {String? displayName}) async {
    final response = await client.auth.signUp(
      email: email,
      password: password,
      data: displayName != null && displayName.isNotEmpty
          ? {'display_name': displayName}
          : null,
    );
    return response;
  }

  Future<AuthResponse> signIn(String email, String password) async {
    return await client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    await client.auth.signOut();
  }

  Future<void> resetPassword(String email) async {
    await client.auth.resetPasswordForEmail(email);
  }
}
