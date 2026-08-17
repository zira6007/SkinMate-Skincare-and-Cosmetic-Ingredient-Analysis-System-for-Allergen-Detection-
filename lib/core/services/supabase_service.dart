import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseService {

  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> init() async {
    await dotenv.load(fileName: '.env');

    final url     = dotenv.env['SUPABASE_URL'] ?? '';
    final anonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';

    if (url.isEmpty || anonKey.isEmpty) {
      throw Exception(
        'SUPABASE_URL or SUPABASE_ANON_KEY is missing in .env file'
      );
    }

    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
    );

    try {
      final response = await Supabase.instance.client
          .from('PRODUCT')
          .select();
      debugPrint('✅ Supabase connected — PRODUCT rows: ${response.length}');
    } catch (e) {
      debugPrint('✅ Supabase connected but PRODUCT table error: $e');
    }

  } 
  static User? get currentUser => client.auth.currentUser;

  static String? get currentUserId => client.auth.currentUser?.id;

  static bool get isLoggedIn => client.auth.currentUser != null;

  static Stream<AuthState> get authStream =>
      client.auth.onAuthStateChange;

} 