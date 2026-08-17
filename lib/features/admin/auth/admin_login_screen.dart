// ignore_for_file: unused_field

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:skin_mate/core/services/auth_service.dart';
import 'package:skin_mate/core/services/supabase_service.dart';
import 'package:skin_mate/features/admin/admin_shell.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen>
    with SingleTickerProviderStateMixin {

  // ── SkinMate colours ──────────────────────────────────
  static const Color _cream      = Color(0xFFF9F3EC);
  static const Color _softBrown  = Color(0xFFB07B6B);
  static const Color _darkBrown  = Color(0xFF4A2C2A);
  static const Color _lightPink  = Color(0xFFF5D5D5);
  static const Color _sidebarBg  = Color(0xFF3D2420);
  static const Color _mutedBrown = Color(0xFF9A7070);
  static const Color _white      = Color(0xFFFFFFFF);
  static const Color _cardBg     = Color(0xFFEDE0D8);

  // ── Controllers ───────────────────────────────────────
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey            = GlobalKey<FormState>();

  // ── State ─────────────────────────────────────────────
  bool    _isLoading       = false;
  bool    _obscurePassword = true;
  String? _errorMessage;

  // ── Animation ─────────────────────────────────────────
  late AnimationController _animController;
  late Animation<double>   _fadeAnim;
  late Animation<Offset>   _slideAnim;

  // ─────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve:  Curves.easeOut,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end:   Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve:  Curves.easeOut,
    ));
    _animController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────
  // HANDLE SIGN IN
  // ─────────────────────────────────────────────────────
  Future<void> _handleSignIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading    = true;
      _errorMessage = null;
    });

    try {
      // Step 1: Sign in with Supabase Auth
      final response = await AuthService.signIn(
        email:    _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;

      if (response.session == null) {
        setState(() => _errorMessage = 'Login failed. Please try again.');
        return;
      }

      // Step 2: Check is_admin in USER table
      // Even if login succeeds, non-admins must be blocked
      final adminCheck = await SupabaseService.client
          .from('USER')
          .select('is_admin')
          .eq('userID', response.session!.user.id)
          .single();

      if (!mounted) return;

      final isAdmin = adminCheck['is_admin'] as bool? ?? false;

      if (!isAdmin) {
        // Step 3: Not admin — sign out immediately and show error
        await AuthService.signOut();
        setState(() {
          _errorMessage =
              'This account does not have admin access.\n'
              'Please use a regular account to log in via the app.';
        });
        return;
      }

      // Step 4: Admin confirmed — navigate to AdminShell
      // AuthGate in main.dart will also detect this,
      // but we navigate directly for a faster response
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AdminShell()),
      );

    } on AuthException catch (e) {
      setState(() => _errorMessage = _friendlyError(e.message));
    } catch (e) {
      setState(() => _errorMessage = 'Something went wrong. Check your connection.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─────────────────────────────────────────────────────
  // FRIENDLY ERROR MESSAGES
  // ─────────────────────────────────────────────────────
  String _friendlyError(String raw) {
    if (raw.contains('Invalid login credentials')) {
      return 'Incorrect email or password. Please try again.';
    }
    if (raw.contains('Email not confirmed')) {
      return 'Please verify your email address first.';
    }
    if (raw.contains('too many requests')) {
      return 'Too many attempts. Please wait a moment.';
    }
    return raw;
  }

  // ─────────────────────────────────────────────────────
  // BUILD — centered card layout for web
  // ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      // Two-tone background: dark left, cream right
      body: Row(
        children: [

          // ── Left decorative panel (dark brown) ────────
          // Only shows on wider screens (>700px)
          if (screenWidth > 700)
            _buildLeftPanel(),

          // ── Right login form panel ─────────────────────
          Expanded(
            child: Container(
              color: _cream,
              child: Center(
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: _buildLoginCard(screenWidth),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  // LEFT DECORATIVE PANEL
  // Dark brand panel shown on wider screens
  // ─────────────────────────────────────────────────────
  Widget _buildLeftPanel() {
    return Container(
      width: 380,
      color: _sidebarBg,
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // Logo
            Container(
              width:  56,
              height: 56,
              decoration: BoxDecoration(
                color:  _softBrown,
                shape:  BoxShape.circle,
              ),
              child: const Center(
                child: Text(
                  'S',
                  style: TextStyle(
                    fontSize:   28,
                    fontWeight: FontWeight.w800,
                    color:      _white,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),

            const Text(
              'SkinMate\nAdmin Panel',
              style: TextStyle(
                fontSize:      34,
                fontWeight:    FontWeight.w800,
                color:         _white,
                height:        1.2,
                letterSpacing: -0.5,
              ),
            ),

            const SizedBox(height: 16),

            Text(
              'Manage ingredients, products,\n'
              'and monitor user analytics.',
              style: TextStyle(
                fontSize: 15,
                color:    _white.withOpacity(0.5),
                height:   1.6,
              ),
            ),

            const SizedBox(height: 48),

            // Feature pills
            ...[
              '📊  Dashboard & analytics',
              '🧪  Ingredient management',
              '📦  Product management',
              '💬  Feedback & reports',
            ].map((text) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width:  6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: _softBrown,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    text,
                    style: TextStyle(
                      fontSize: 14,
                      color:    _white.withOpacity(0.65),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  // LOGIN CARD
  // White card with form — centered on the right panel
  // ─────────────────────────────────────────────────────
  Widget _buildLoginCard(double screenWidth) {
    return Container(
      width:   400,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color:        _white,
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

            // ── Card header ─────────────────────────────
            Row(
              children: [
                Container(
                  width:  38,
                  height: 38,
                  decoration: BoxDecoration(
                    color:        _lightPink,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.admin_panel_settings_rounded,
                    color: _softBrown,
                    size:  20,
                  ),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Admin Login',
                      style: TextStyle(
                        fontSize:   18,
                        fontWeight: FontWeight.w800,
                        color:      _darkBrown,
                      ),
                    ),
                    Text(
                      'SkinMate Dashboard',
                      style: TextStyle(
                        fontSize: 12,
                        color:    _mutedBrown,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 32),

            // ── Email field ─────────────────────────────
            _FieldLabel('Email address'),
            const SizedBox(height: 6),
            TextFormField(
              controller:   _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofocus:    true, // auto-focus on web
              style: const TextStyle(
                color: _darkBrown, fontSize: 14),
              decoration: _inputDecor('Enter admin email'),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Please enter your email';
                }
                if (!v.contains('@')) {
                  return 'Please enter a valid email';
                }
                return null;
              },
            ),

            const SizedBox(height: 18),

            // ── Password field ──────────────────────────
            _FieldLabel('Password'),
            const SizedBox(height: 6),
            TextFormField(
              controller:      _passwordController,
              obscureText:     _obscurePassword,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _handleSignIn(),
              style: const TextStyle(
                color: _darkBrown, fontSize: 14),
              decoration: _inputDecor('Enter password').copyWith(
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: _softBrown,
                    size:  18,
                  ),
                  onPressed: () => setState(
                    () => _obscurePassword = !_obscurePassword,
                  ),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) {
                  return 'Please enter your password';
                }
                return null;
              },
            ),

            const SizedBox(height: 10),

            // ── Error banner ────────────────────────────
            if (_errorMessage != null) ...[
              const SizedBox(height: 4),
              Container(
                width:   double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color:        const Color(0xFFFFEDED),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline,
                      color: Colors.red, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color:    Colors.red,
                          fontSize: 12,
                          height:   1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // ── Sign In button ──────────────────────────
            SizedBox(
              width:  double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleSignIn,
                style: ElevatedButton.styleFrom(
                  backgroundColor:         _softBrown,
                  foregroundColor:         _white,
                  disabledBackgroundColor: _softBrown.withOpacity(0.55),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width:  20,
                        height: 20,
                        child:  CircularProgressIndicator(
                          color:       _white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.lock_open_rounded, size: 16),
                          SizedBox(width: 8),
                          Text(
                            'Sign In to Dashboard',
                            style: TextStyle(
                              fontSize:   14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 20),

            // ── Footer note ─────────────────────────────
            Center(
              child: Text(
                'Admin access only.\n'
                'Regular users should use the SkinMate app.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color:    _mutedBrown.withOpacity(0.7),
                  height:   1.6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  // SHARED INPUT DECORATION
  // ─────────────────────────────────────────────────────
  InputDecoration _inputDecor(String hint) {
    return InputDecoration(
      hintText:  hint,
      hintStyle: TextStyle(color: _mutedBrown.withOpacity(0.5), fontSize: 13),
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
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16, vertical: 14),
      errorStyle: const TextStyle(fontSize: 11),
    );
  }
}

// ─────────────────────────────────────────────────────────
// FIELD LABEL
// ─────────────────────────────────────────────────────────
class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize:   12,
        fontWeight: FontWeight.w600,
        color:      Color(0xFF7A5555),
        letterSpacing: 0.2,
      ),
    );
  }
}