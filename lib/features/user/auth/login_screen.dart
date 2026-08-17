// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:skin_mate/core/services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  final String? infoMessage;
  const LoginScreen({super.key, this.infoMessage});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {

  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey            = GlobalKey<FormState>();

  bool _isLoading       = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  late AnimationController _animController;
  late Animation<double>   _fadeAnim;
  late Animation<Offset>   _slideAnim;

  static const Color _cream      = Color(0xFFF9F3EC);
  static const Color _softBrown  = Color(0xFFB07B6B);
  static const Color _darkBrown  = Color(0xFF4A2C2A);
  static const Color _lightPink  = Color(0xFFF5D5D5);
  static const Color _white      = Color(0xFFFFFFFF);

  @override
  void initState() {
    super.initState();

    // Set directly — no addPostFrameCallback needed
    _errorMessage = widget.infoMessage;

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end:   Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
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

  Future<void> _handleSignIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading    = true;
      _errorMessage = null;
    });

    try {
      final response = await AuthService.signIn(
        email:    _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;

      if (response.session == null) {
        setState(() => _errorMessage = 'Login failed. Please try again.');
      }
      // If session exists, UserAuthGate handles is_active check and navigation

    } on AuthException catch (e) {
      setState(() => _errorMessage = _friendlyError(e.message));

    } catch (e) {
      setState(() => _errorMessage = 'Something went wrong. Check your connection.');

    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cream,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 8),
                        Text(
                          'Welcome\nBack',
                          style: TextStyle(
                            fontSize:      36,
                            fontWeight:    FontWeight.w800,
                            color:         _darkBrown,
                            height:        1.15,
                            letterSpacing: -0.5,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          "Let's get you in",
                          style: TextStyle(
                            fontSize:   15,
                            color:      Color(0xFF9A7070),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(
                    height: 80,
                    width:  double.infinity,
                    child:  CustomPaint(painter: _WavePainter()),
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [

                          _FieldLabel('Email'),
                          const SizedBox(height: 6),
                          _buildEmailField(),

                          const SizedBox(height: 16),

                          _FieldLabel('Password'),
                          const SizedBox(height: 6),
                          _buildPasswordField(),

                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _handleForgotPassword,
                              style: TextButton.styleFrom(
                                foregroundColor: _softBrown,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4, horizontal: 0,
                                ),
                              ),
                              child: const Text(
                                'Forgot password?',
                                style: TextStyle(
                                  fontSize:   13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 8),

                          if (_errorMessage != null)
                            _ErrorBanner(_errorMessage!),

                          const SizedBox(height: 12),

                          _buildSignInButton(),

                          const SizedBox(height: 32),

                          _buildSignUpLink(),

                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller:      _emailController,
      keyboardType:    TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      style: const TextStyle(color: _darkBrown, fontSize: 14),
      decoration: _inputDecoration('Enter your Email'),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter your email';
        }
        if (!RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$')
            .hasMatch(value.trim())) {
          return 'Please enter a valid email';
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller:       _passwordController,
      obscureText:      _obscurePassword,
      textInputAction:  TextInputAction.done,
      onFieldSubmitted: (_) => _handleSignIn(),
      style: const TextStyle(color: _darkBrown, fontSize: 14),
      decoration: _inputDecoration('Enter your Password').copyWith(
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_off : Icons.visibility,
            color: _softBrown,
            size:  20,
          ),
          onPressed: () {
            setState(() => _obscurePassword = !_obscurePassword);
          },
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your password';
        }
        if (value.length < 6) {
          return 'Password must be at least 6 characters';
        }
        return null;
      },
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText:  hint,
      hintStyle: const TextStyle(color: Color(0xFFBBA0A0), fontSize: 14),
      filled:    true,
      fillColor: _lightPink,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide:   BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide:   BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _softBrown, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.red, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    );
  }

  Widget _buildSignInButton() {
    return SizedBox(
      width:  double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleSignIn,
        style: ElevatedButton.styleFrom(
          backgroundColor:         _softBrown,
          foregroundColor:         _white,
          disabledBackgroundColor: _softBrown.withOpacity(0.6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
                width:  22,
                height: 22,
                child:  CircularProgressIndicator(
                  color:       _white,
                  strokeWidth: 2.5,
                ),
              )
            : const Text(
                'Sign In',
                style: TextStyle(
                  fontSize:      16,
                  fontWeight:    FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
      ),
    );
  }

  Widget _buildSignUpLink() {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "Don't have an account? ",
            style: TextStyle(
              fontSize: 14,
              color:    _darkBrown.withOpacity(0.6),
            ),
          ),
          GestureDetector(
            onTap: _goToSignUp,
            child: const Text(
              'Sign up',
              style: TextStyle(
                fontSize:   14,
                fontWeight: FontWeight.w800,
                color:      _softBrown,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleForgotPassword() {
    showDialog(
      context:           context,
      barrierDismissible: true,
      builder: (_) => const _ResetPasswordDialog(),
    );
  }

  void _goToSignUp() {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => const SignupScreen(),
    ));
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
        fontSize:      13,
        fontWeight:    FontWeight.w600,
        color:         Color(0xFF7A5555),
        letterSpacing: 0.2,
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner(this.message);

  @override
  Widget build(BuildContext context) {
    return Container(
      width:   double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color:        const Color(0xFFFFEDED),
        borderRadius: BorderRadius.circular(10),
        border:       Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.red, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  Reset Password Popup
//  Step 1: enter email -> sends recovery code via Supabase
//  Step 2: enter code + new password + confirm password -> verifies OTP
//          then saves the new password via auth.updateUser()
// ═══════════════════════════════════════════════════════════════════════
class _ResetPasswordDialog extends StatefulWidget {
  const _ResetPasswordDialog();

  @override
  State<_ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<_ResetPasswordDialog> {
  final _emailFormKey = GlobalKey<FormState>();
  final _resetFormKey = GlobalKey<FormState>();

  final _emailCtrl           = TextEditingController();
  final _otpCtrl             = TextEditingController();
  final _newPasswordCtrl     = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  int  _step           = 1;
  bool _newVisible     = false;
  bool _confirmVisible = false;
  bool _saving         = false;
  String? _errorMessage;

  static const Color _softBrown = Color(0xFFB07B6B);
  static const Color _darkBrown = Color(0xFF4A2C2A);
  static const Color _lightPink = Color(0xFFF5D5D5);
  static const Color _white     = Color(0xFFFFFFFF);

  @override
  void dispose() {
    _emailCtrl.dispose();
    _otpCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (!_emailFormKey.currentState!.validate()) return;

    setState(() {
      _saving       = true;
      _errorMessage = null;
    });

    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        _emailCtrl.text.trim(),
      );

      if (mounted) {
        setState(() {
          _step   = 2;
          _saving = false;
        });
      }
    } on AuthException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage =
          'Could not send reset code. Please check the email and try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _verifyAndSave() async {
    if (!_resetFormKey.currentState!.validate()) return;

    setState(() {
      _saving       = true;
      _errorMessage = null;
    });

    try {
      await Supabase.instance.client.auth.verifyOTP(
        email: _emailCtrl.text.trim(),
        token: _otpCtrl.text.trim(),
        type:  OtpType.recovery,
      );

      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _newPasswordCtrl.text),
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:         const Text('Password updated successfully'),
            backgroundColor: _softBrown,
            behavior:        SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } on AuthException catch (e) {
      setState(() => _errorMessage = _friendlyOtpError(e.message));
    } catch (e) {
      setState(() => _errorMessage = 'Could not update password. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _friendlyOtpError(String raw) {
    if (raw.contains('Token has expired') || raw.contains('invalid')) {
      return 'That code is invalid or expired. Please request a new one.';
    }
    return raw;
  }

  InputDecoration _decoration(String hint, {Widget? suffixIcon}) {
    return InputDecoration(
      hintText:   hint,
      hintStyle:  const TextStyle(color: Color(0xFFBBA0A0), fontSize: 14),
      filled:     true,
      fillColor:  _lightPink,
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide:   BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide:   BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _softBrown, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.red, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFFF9F3EC),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: _step == 1 ? _buildEmailStep() : _buildResetStep(),
      ),
    );
  }

  Widget _buildEmailStep() {
    return Form(
      key: _emailFormKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Reset Password',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: _darkBrown),
          ),
          const SizedBox(height: 4),
          const Text(
            "Enter your account email and we'll send you a reset code.",
            style: TextStyle(fontSize: 13, color: Color(0xFF9A7070)),
          ),
          const SizedBox(height: 18),

          const Text(
            'Email',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF7A5555)),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller:   _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: _darkBrown, fontSize: 14),
            decoration: _decoration('Enter your account email'),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return 'Please enter your email';
              if (!RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
                return 'Please enter a valid email';
              }
              return null;
            },
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            _ErrorBanner(_errorMessage!),
          ],

          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: _darkBrown.withOpacity(0.6),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: _saving ? null : _sendCode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:         _softBrown,
                    foregroundColor:         _white,
                    disabledBackgroundColor: _softBrown.withOpacity(0.6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(color: _white, strokeWidth: 2.5),
                        )
                      : const Text('Send Code',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResetStep() {
    return Form(
      key: _resetFormKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: _saving
                    ? null
                    : () => setState(() { _step = 1; _errorMessage = null; }),
                icon: const Icon(Icons.arrow_back, color: _darkBrown, size: 20),
                padding:     EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              const Text(
                'Enter Code',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: _darkBrown),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'We sent a code to ${_emailCtrl.text.trim()}.',
            style: const TextStyle(fontSize: 13, color: Color(0xFF9A7070)),
          ),
          const SizedBox(height: 18),

          const Text('Verification Code',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF7A5555))),
          const SizedBox(height: 6),
          TextFormField(
            controller:   _otpCtrl,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: _darkBrown, fontSize: 14),
            decoration: _decoration('Enter the code from your email'),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return 'Please enter the verification code';
              return null;
            },
          ),
          const SizedBox(height: 14),

          const Text('New Password',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF7A5555))),
          const SizedBox(height: 6),
          TextFormField(
            controller:  _newPasswordCtrl,
            obscureText: !_newVisible,
            style: const TextStyle(color: _darkBrown, fontSize: 14),
            decoration: _decoration(
              'Enter new password',
              suffixIcon: IconButton(
                icon: Icon(
                  _newVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: _softBrown, size: 20,
                ),
                onPressed: () => setState(() => _newVisible = !_newVisible),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Please enter a new password';
              if (value.length < 6) return 'Password must be at least 6 characters';
              return null;
            },
          ),
          const SizedBox(height: 14),

          const Text('Confirm New Password',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF7A5555))),
          const SizedBox(height: 6),
          TextFormField(
            controller:  _confirmPasswordCtrl,
            obscureText: !_confirmVisible,
            style: const TextStyle(color: _darkBrown, fontSize: 14),
            decoration: _decoration(
              'Re-enter new password',
              suffixIcon: IconButton(
                icon: Icon(
                  _confirmVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: _softBrown, size: 20,
                ),
                onPressed: () => setState(() => _confirmVisible = !_confirmVisible),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Please confirm your password';
              if (value != _newPasswordCtrl.text) return 'Passwords do not match';
              return null;
            },
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            _ErrorBanner(_errorMessage!),
          ],

          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: _darkBrown.withOpacity(0.6),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: _saving ? null : _verifyAndSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:         _softBrown,
                    foregroundColor:         _white,
                    disabledBackgroundColor: _softBrown.withOpacity(0.6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(color: _white, strokeWidth: 2.5),
                        )
                      : const Text('Save',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color       = const Color(0xFFD4A090)
      ..strokeWidth = 1.8
      ..style       = PaintingStyle.stroke
      ..strokeCap   = StrokeCap.round;

    final path = Path();
    path.moveTo(0, size.height * 0.6);
    path.cubicTo(
      size.width * 0.20, size.height * 0.1,
      size.width * 0.35, size.height * 1.0,
      size.width * 0.55, size.height * 0.5,
    );
    path.cubicTo(
      size.width * 0.70, size.height * 0.1,
      size.width * 0.85, size.height * 0.8,
      size.width * 1.05, size.height * 0.4,
    );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
