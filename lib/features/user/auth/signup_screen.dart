// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:skin_mate/core/services/auth_service.dart';
import 'package:skin_mate/features/user/onboarding/welcome_screen.dart';
import 'login_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen>
    with SingleTickerProviderStateMixin {

  final _nameController            = TextEditingController();
  final _emailController           = TextEditingController();
  final _passwordController        = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool    _isLoading          = false;
  bool    _obscurePassword    = true;
  bool    _obscureConfirm     = true;
  String? _errorMessage;

  late AnimationController _animController;
  late Animation<double>   _fadeAnim;
  late Animation<Offset>   _slideAnim;

  static const Color _cream      = Color(0xFFF9F3EC);
  static const Color _softBrown  = Color(0xFFB07B6B);
  static const Color _darkBrown  = Color(0xFF4A2C2A);
  static const Color _lightPink  = Color(0xFFF5D5D5);
  static const Color _mutedBrown = Color(0xFF9A7070);
  static const Color _white      = Color(0xFFFFFFFF);

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
      begin: const Offset(0, 0.07),
      end:   Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve:  Curves.easeOut,
    ));

    _animController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading    = true;
      _errorMessage = null;
    });

    try {
      final response = await AuthService.signUp(
        email:    _emailController.text.trim(),
        password: _passwordController.text,
        name:     _nameController.text.trim(),
      );

      if (!mounted) return;

      if (response.user != null) {
        _goToQuiz();
      } else {
        setState(() {
          _errorMessage = 'Sign up failed. Please try again.';
        });
      }

    } on AuthException catch (e) {
      setState(() => _errorMessage = _friendlyError(e.message));

    } catch (e) {
      setState(() {
        _errorMessage = 'Something went wrong. Check your connection.';
      });

    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _friendlyError(String raw) {
    if (raw.contains('already registered') ||
        raw.contains('User already registered')) {
      return 'This email is already in use. Try signing in instead.';
    }
    if (raw.contains('Password should be')) {
      return 'Password must be at least 6 characters.';
    }
    if (raw.contains('Unable to validate email')) {
      return 'Please enter a valid email address.';
    }
    if (raw.contains('too many requests')) {
      return 'Too many attempts. Please wait a moment and try again.';
    }
    return raw;
  }

  void _goToQuiz() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => WelcomeScreen(
          userName: _nameController.text.trim(),
        ),
      ),
    );
  }

  void _goToLogin() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
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
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  const Padding(
                    padding: EdgeInsets.fromLTRB(28, 10, 28, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Create\nAccount',
                          style: TextStyle(
                            fontSize:      34,
                            fontWeight:    FontWeight.w800,
                            color:         _darkBrown,
                            height:        1.15,
                            letterSpacing: -0.5,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Please sign up to continue',
                          style: TextStyle(
                            fontSize:   14,
                            color:      _mutedBrown,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(
                    height: 72,
                    width:  double.infinity,
                    child:  CustomPaint(
                      painter: _WavePainter(),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [

                          _FieldLabel('Name'),
                          const SizedBox(height: 6),
                          _buildNameField(),

                          const SizedBox(height: 14),

                          _FieldLabel('Email'),
                          const SizedBox(height: 6),
                          _buildEmailField(),

                          const SizedBox(height: 14),

                          _FieldLabel('Password'),
                          const SizedBox(height: 6),
                          _buildPasswordField(),

                          const SizedBox(height: 14),

                          _FieldLabel('Confirm Password'),
                          const SizedBox(height: 6),
                          _buildConfirmPasswordField(),

                          const SizedBox(height: 10),

                          _PasswordHint(),

                          const SizedBox(height: 10),

                          if (_errorMessage != null)
                            _ErrorBanner(_errorMessage!),

                          const SizedBox(height: 14),

                          _buildGetStartedButton(),

                          const SizedBox(height: 28),

                          _buildSignInLink(),

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

  Widget _buildNameField() {
    return TextFormField(
      controller:      _nameController,
      keyboardType:    TextInputType.name,
      textCapitalization: TextCapitalization.words,
      textInputAction: TextInputAction.next,
      style: const TextStyle(color: _darkBrown, fontSize: 14),
      decoration: _inputDecoration('Enter your Username'),

      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter your name';
        }
        if (value.trim().length < 2) {
          return 'Name must be at least 2 characters';
        }
        return null;
      },
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
        final emailRegex = RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$');
        if (!emailRegex.hasMatch(value.trim())) {
          return 'Please enter a valid email address';
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller:      _passwordController,
      obscureText:     _obscurePassword,
      textInputAction: TextInputAction.next,
      style: const TextStyle(color: _darkBrown, fontSize: 14),
      decoration: _inputDecoration('Enter your Password').copyWith(
        suffixIcon: _EyeToggle(
          obscure:  _obscurePassword,
          onToggle: () =>
              setState(() => _obscurePassword = !_obscurePassword),
        ),
      ),

      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter a password';
        }
        if (value.length < 6) {
          return 'Password must be at least 6 characters';
        }
        if (!RegExp(r'[a-zA-Z]').hasMatch(value)) {
          return 'Password must contain at least one letter';
        }
        return null;
      },
    );
  }

  Widget _buildConfirmPasswordField() {
    return TextFormField(
      controller:      _confirmPasswordController,
      obscureText:     _obscureConfirm,
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => _handleSignUp(),
      style: const TextStyle(color: _darkBrown, fontSize: 14),
      decoration: _inputDecoration('Confirm your Password').copyWith(
        suffixIcon: _EyeToggle(
          obscure:  _obscureConfirm,
          onToggle: () =>
              setState(() => _obscureConfirm = !_obscureConfirm),
        ),
      ),

      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please confirm your password';
        }
        if (value != _passwordController.text) {
          return 'Passwords do not match';
        }
        return null;
      },
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText:  hint,
      hintStyle: const TextStyle(
        color:    Color(0xFFBBA0A0),
        fontSize: 14,
      ),
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
        borderSide:   const BorderSide(color: Colors.red, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide:   const BorderSide(color: Colors.red, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 18, vertical: 16,
      ),
      errorStyle: const TextStyle(fontSize: 11),
    );
  }

  Widget _buildGetStartedButton() {
    return SizedBox(
      width:  double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleSignUp,
        style: ElevatedButton.styleFrom(
          backgroundColor:         _softBrown,
          foregroundColor:         _white,
          disabledBackgroundColor: _softBrown.withOpacity(0.55),
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
                'Get Started',
                style: TextStyle(
                  fontSize:      16,
                  fontWeight:    FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
      ),
    );
  }

  Widget _buildSignInLink() {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Already have an account? ',
            style: TextStyle(
              fontSize: 14,
              color:    _darkBrown.withOpacity(0.6),
            ),
          ),
          GestureDetector(
            onTap: _goToLogin,
            child: const Text(
              'Sign In',
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

class _EyeToggle extends StatelessWidget {
  final bool     obscure;
  final VoidCallback onToggle;
  const _EyeToggle({required this.obscure, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        color: const Color(0xFFB07B6B),
        size:  20,
      ),
      onPressed: onToggle,
    );
  }
}

class _PasswordHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.info_outline,
          size:  13,
          color: const Color(0xFFB07B6B).withOpacity(0.7),
        ),
        const SizedBox(width: 5),
        Text(
          'At least 6 characters with a letter',
          style: TextStyle(
            fontSize: 11,
            color:    const Color(0xFF9A7070).withOpacity(0.8),
          ),
        ),
      ],
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
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
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
    path.moveTo(0, size.height * 0.65);

    path.cubicTo(
      size.width * 0.18, size.height * 0.05,
      size.width * 0.38, size.height * 1.1,
      size.width * 0.58, size.height * 0.5,
    );

    path.cubicTo(
      size.width * 0.72, size.height * 0.05,
      size.width * 0.88, size.height * 0.85,
      size.width * 1.05, size.height * 0.4,
    );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}