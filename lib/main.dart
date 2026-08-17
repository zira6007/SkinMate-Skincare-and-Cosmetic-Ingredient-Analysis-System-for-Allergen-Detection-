// lib/main.dart
import 'package:flutter/foundation.dart'; // for kIsWeb
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/services/supabase_service.dart';

// User imports
import 'features/user/auth/login_screen.dart';
import 'features/user/home/home_screen.dart';

// Admin imports
import 'features/admin/auth/admin_login_screen.dart';
import 'features/admin/auth/admin_change_password_screen.dart';
import 'features/admin/admin_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.init();
  runApp(const SkinMateApp());
}

class SkinMateApp extends StatelessWidget {
  const SkinMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: kIsWeb ? 'SkinMate Admin' : 'SkinMate',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          // Different seed colour per platform — just cosmetic
          seedColor: kIsWeb
              ? const Color(0xFFB07B6B) // brown for admin web
              : const Color(0xFF1D9E75), // green for user app
        ),
        useMaterial3: true,
      ),
      // Key decision: web → AdminAuthGate, mobile → UserAuthGate
      home: kIsWeb ? const AdminAuthGate() : const UserAuthGate(),
    );
  }
}

// ──────────────────────────────────────────────────────────
// ADMIN AUTH GATE (web only)
// ──────────────────────────────────────────────────────────
class AdminAuthGate extends StatelessWidget {
  const AdminAuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: SupabaseService.authStream,
      builder: (context, snapshot) {
        final session = snapshot.data?.session;

        if (session == null) return const AdminLoginScreen();

        return FutureBuilder<Map<String, dynamic>>(
          future: SupabaseService.client
              .from('USER')
              .select('is_admin, must_change_password')
              .eq('userID', session.user.id)
              .single(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final isAdmin  = snap.data?['is_admin'] ?? false;
            final mustChange = snap.data?['must_change_password'] ?? false;

            // Not an admin → kick out immediately
            if (!isAdmin) {
              SupabaseService.client.auth.signOut();
              return const AdminLoginScreen();
            }

            // Admin but first login → force password change
            if (mustChange) return const AdminChangePasswordScreen();

            // All clear → dashboard
            return const AdminShell();
          },
        );
      },
    );
  }
}

// ──────────────────────────────────────────────────────────
// USER AUTH GATE (mobile only)
// ──────────────────────────────────────────────────────────
class UserAuthGate extends StatelessWidget {
  const UserAuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: SupabaseService.authStream,
      builder: (context, snapshot) {
        final session = snapshot.data?.session;

        if (session == null) return const LoginScreen();

        return FutureBuilder<Map<String, dynamic>?>(
          future: SupabaseService.client
              .from('USER')
              .select('is_admin, is_active')
              .eq('userID', session.user.id)
              .maybeSingle(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final data     = snap.data;
            final isAdmin  = data?['is_admin']  ?? false;
            final isActive = data?['is_active'] ?? true;

            // Deactivated account → sign out immediately
            if (isActive == false) {
              SupabaseService.client.auth.signOut();
              return const LoginScreen();
            }

            // Admin on mobile → kick out
            if (isAdmin) {
              SupabaseService.client.auth.signOut();
              return const LoginScreen();
            }

            return const HomeScreen();
          },
        );
      },
    );
  }
}