import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class AuthService {

  static SupabaseClient get _client => SupabaseService.client;

  static Future<AuthResponse> signUp({
  required String email,
  required String password,
  required String name,
}) async {
  final authResponse = await _client.auth.signUp(
    email:    email,
    password: password,
  );

  debugPrint('Auth user created: ${authResponse.user?.id}');

  if (authResponse.user != null) {
    try {
      await _client.from('USER').insert({
        'userID':     authResponse.user!.id,
        'name':       name,
        'email':      email,
        'is_admin':   false,
        'created_at': DateTime.now().toIso8601String(),
      });
      debugPrint('✅ USER row inserted successfully');

    } catch (e) {
      
      debugPrint('❌ USER insert failed: $e');
    }
  }

  return authResponse;
}


  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    final authResponse = await _client.auth.signInWithPassword(
      email:    email,
      password: password,
    );
    return authResponse;
  }

  
  static Future<void> signOut() async {
    await _client.auth.signOut();
  }

  static User? getCurrentUser() {
    return _client.auth.currentUser;
  }

  static Future<bool> isAdmin() async {

    final userId = SupabaseService.currentUserId;

    if (userId == null) return false;

    try {
      final response = await _client
          .from('USER')
          .select('is_admin')
          .eq('userID', userId)
          .single(); 

      return response['is_admin'] ?? false;
    } catch (e) {
      return false;
    }
  }

  static Future<Map<String, dynamic>?> getUserProfile() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return null;

    try {
      final response = await _client
          .from('USER')
          .select()
          .eq('userID', userId)
          .single();

      return response;
    } catch (e) {
      return null;
    }
  }

  static Future<void> updateProfile({
    String? name,
    String? gender,
    int?    age,
    String? country,
    String? avatarUrl,
  }) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;

    final updates = <String, dynamic>{};
    if (name      != null) updates['name']       = name;
    if (gender    != null) updates['gender']     = gender;
    if (age       != null) updates['age']        = age;
    if (country   != null) updates['country']    = country;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;

    if (updates.isEmpty) return;

    await _client
        .from('USER')
        .update(updates)
        .eq('userID', userId);
  }

  static Future<bool> hasCompletedQuiz() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return false;

    try {
      final response = await _client
          .from('RESULT_SKIN_PROFILE')
          .select('resultID')
          .eq('userID', userId)
          .limit(1);

      return response.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
}