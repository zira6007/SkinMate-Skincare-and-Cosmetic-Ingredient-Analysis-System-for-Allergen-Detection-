// ignore_for_file: unused_field

import 'package:flutter/material.dart';
import 'package:skin_mate/features/admin/admin_shell.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:skin_mate/core/services/supabase_service.dart';

class AdminChangePasswordScreen extends StatefulWidget {
  const AdminChangePasswordScreen({super.key});

  @override
  State<AdminChangePasswordScreen> createState() =>
      _AdminChangePasswordScreenState();
}

class _AdminChangePasswordScreenState
    extends State<AdminChangePasswordScreen> {
  // ── SkinMate colours ──────────────────────────────────
  static const Color _cream     = Color(0xFFF9F3EC);
  static const Color _softBrown = Color(0xFFB07B6B);
  static const Color _darkBrown = Color(0xFF4A2C2A);
  static const Color _lightPink = Color(0xFFF5D5D5);
  static const Color _mutedBrown = Color(0xFF9A7070);
  static const Color _white     = Color(0xFFFFFFFF);
  static const Color _sidebarBg = Color(0xFF3D2420);

  final _formKey        = GlobalKey<FormState>();
  final _newPassCtrl    = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  bool    _isLoading       = false;
  bool    _obscureNew      = true;
  bool    _obscureConfirm  = true;
  String? _errorMessage;
  String? _successMessage;

  @override
  void dispose() {
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleChangePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading    = true;
      _errorMessage = null;
    });

    try {
      final userId = SupabaseService.client.auth.currentUser?.id;
      if (userId == null) throw Exception('No user session.');

      // Step 1: Update password in Supabase Auth
      await SupabaseService.client.auth.updateUser(
        UserAttributes(password: _newPassCtrl.text),
      );

      // Step 2: Clear the must_change_password flag
       await SupabaseService.client
        .from('USER')
        .update({'must_change_password': false})
        .eq('userID', userId);

      // Step 3: Navigate directly to AdminShell ← THIS WAS MISSING
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const AdminShell()),
    );

  } on AuthException catch (e) {
    setState(() => _errorMessage = e.message);
  } catch (e) {
    setState(() => _errorMessage = 'Something went wrong. Please try again.');
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cream,
      body: Center(
        child: Container(
          width: 420,
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: _white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color:      Colors.black.withOpacity(0.08),
                blurRadius: 40,
                offset:     const Offset(0, 8),
              ),
            ],
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ── Header ────────────────────────────────
                Row(
                  children: [
                    Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(
                        color: _lightPink,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.lock_reset_rounded,
                        color: _softBrown, size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Set New Password',
                          style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800,
                            color: _darkBrown,
                          ),
                        ),
                        Text(
                          'Required on first login',
                          style: TextStyle(fontSize: 12, color: _mutedBrown),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // ── Info banner ───────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: _lightPink.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _lightPink),
                  ),
                  child: const Text(
                    'Your account was created by a system administrator. '
                    'Please set a personal password before continuing.',
                    style: TextStyle(
                      fontSize: 12, color: _darkBrown, height: 1.5),
                  ),
                ),

                const SizedBox(height: 24),

                // ── New password ──────────────────────────
                _FieldLabel('New Password'),
                const SizedBox(height: 6),
                TextFormField(
                  controller:  _newPassCtrl,
                  obscureText: _obscureNew,
                  style: const TextStyle(color: _darkBrown, fontSize: 14),
                  decoration: _inputDecor('Enter new password').copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureNew
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: _softBrown, size: 18,
                      ),
                      onPressed: () =>
                          setState(() => _obscureNew = !_obscureNew),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Please enter a password';
                    if (v.length < 8) return 'Must be at least 8 characters';
                    return null;
                  },
                ),

                const SizedBox(height: 18),

                // ── Confirm password ──────────────────────
                _FieldLabel('Confirm Password'),
                const SizedBox(height: 6),
                TextFormField(
                  controller:  _confirmPassCtrl,
                  obscureText: _obscureConfirm,
                  style: const TextStyle(color: _darkBrown, fontSize: 14),
                  decoration: _inputDecor('Re-enter new password').copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirm
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: _softBrown, size: 18,
                      ),
                      onPressed: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Please confirm your password';
                    if (v != _newPassCtrl.text) return 'Passwords do not match';
                    return null;
                  },
                ),

                // ── Error banner ──────────────────────────
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 11),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEDED),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline,
                            color: Colors.red, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: Colors.red, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // ── Submit button ─────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleChangePassword,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _softBrown,
                      foregroundColor: _white,
                      disabledBackgroundColor: _softBrown.withOpacity(0.55),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(
                              color: _white, strokeWidth: 2.5),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_rounded, size: 16),
                              SizedBox(width: 8),
                              Text(
                                'Set Password & Continue',
                                style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                  ),
                ),

                const SizedBox(height: 16),

                // ── Sign out link ─────────────────────────
                Center(
                  child: TextButton(
                    onPressed: () =>
                        SupabaseService.client.auth.signOut(),
                    child: Text(
                      'Sign out',
                      style: TextStyle(
                        fontSize: 12, color: _mutedBrown),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecor(String hint) {
    return InputDecoration(
      hintText:  hint,
      hintStyle: TextStyle(
        color: _mutedBrown.withOpacity(0.5), fontSize: 13),
      filled:    true,
      fillColor: _lightPink.withOpacity(0.4),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide:   BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide:   BorderSide(color: _lightPink, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide:   const BorderSide(color: _softBrown, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide:   const BorderSide(color: Colors.red, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide:   const BorderSide(color: Colors.red, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      errorStyle: const TextStyle(fontSize: 11),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12, fontWeight: FontWeight.w600,
        color: Color(0xFF7A5555), letterSpacing: 0.2,
      ),
    );
  }
}