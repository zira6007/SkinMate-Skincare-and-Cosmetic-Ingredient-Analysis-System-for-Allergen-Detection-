// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:skin_mate/features/user/onboarding/quiz_screen.dart';

class WelcomeScreen extends StatefulWidget {
  final String userName;

  const WelcomeScreen({
    super.key,
    this.userName = 'Mate', 
  });

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  static const Color _cream      = Color(0xFFF9F3EC);
  static const Color _softBrown  = Color(0xFFB07B6B);
  static const Color _darkBrown  = Color(0xFF4A2C2A);
  static const Color _lightPink  = Color(0xFFF5D5D5);
  static const Color _mutedBrown = Color(0xFF9A7070);

  late AnimationController _entryController;
  late Animation<double>   _fadeAnim;
  late Animation<Offset>   _slideAnim;
  late AnimationController _pulseController;
  late Animation<double>   _pulseAnim;
  late AnimationController _waveController;
  late Animation<double>   _waveAnim;

  @override
  void initState() {
    super.initState();

    _entryController = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(
      parent: _entryController,
      curve:  Curves.easeOut,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06), 
      end:   Offset.zero,           
    ).animate(CurvedAnimation(
      parent: _entryController,
      curve:  Curves.easeOut,
    ));

    _pulseController = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(); 

    _pulseAnim = Tween<double>(
      begin: 0.85, 
      end:   1.35, 
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve:  Curves.easeOut,
    ));

   
    _waveController = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true); 
    _waveAnim = Tween<double>(
      begin: -6.0, 
      end:    6.0, 
    ).animate(CurvedAnimation(
      parent: _waveController,
      curve:  Curves.easeInOut,
    ));

    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) _entryController.forward();
    });
  }

  @override
  void dispose() {

    _entryController.dispose();
    _pulseController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  void _goToQuiz() {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        
        pageBuilder: (_, animation, __) => const QuizScreen(),
        transitionsBuilder: (_, animation, __, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1, 0),
              end:   Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve:  Curves.easeOut,
            )),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: _cream,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: SizedBox(
              width:  double.infinity,
              height: screenHeight,
              child: Column(
                children: [

                  
                  const Spacer(flex: 2),

                  AnimatedBuilder(
                    animation: _waveAnim,
                    builder: (_, __) {
                      return Transform.translate(
                        offset: Offset(0, _waveAnim.value),
                        child: SizedBox(
                          height: 100,
                          width:  double.infinity,
                          child:  CustomPaint(
                            painter: _WavePainter(),
                          ),
                        ),
                      );
                    },
                  ),

                  const Spacer(flex: 1),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 36),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        Text(
                          'Hello ${widget.userName}!',
                          style: const TextStyle(
                            fontSize:      34,
                            fontWeight:    FontWeight.w800,
                            color:         _darkBrown,
                            letterSpacing: -0.5,
                            height:        1.1,
                          ),
                        ),

                        const SizedBox(height: 10),
                        const Text(
                          "Let's find your perfect match. "
                          "2 minutes to analyze your skin.",
                          style: TextStyle(
                            fontSize:   15,
                            color:      _mutedBrown,
                            fontWeight: FontWeight.w400,
                            height:     1.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(flex: 1),

                  _buildNextButton(),

                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNextButton() {
    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (_, child) {
        return Stack(
          alignment: Alignment.center,
          children: [

            Container(
              width:  80 * _pulseAnim.value, 
              height: 80 * _pulseAnim.value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _softBrown.withOpacity(
                    (1 - _pulseController.value) * 0.4,
                  ),
                  width: 1.5,
                ),
              ),
            ),

            Container(
              width:  80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _lightPink.withOpacity(0.6),
                border: Border.all(
                  color: _softBrown.withOpacity(0.25),
                  width: 1.5,
                ),
              ),
            ),


            GestureDetector(
              onTap: _goToQuiz,
              child: Container(
                width:  60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _softBrown,
                  boxShadow: [
                    BoxShadow(
                      color:      _softBrown.withOpacity(0.35),
                      blurRadius: 16,
                      offset:     const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.chevron_right,
                  color: Colors.white,
                  size:  30,
                ),
              ),
            ),

          ],
        );
      },
    );
  }
}

class _WavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color       = const Color(0xFF4A2C2A) 
      ..strokeWidth = 1.5
      ..style       = PaintingStyle.stroke
      ..strokeCap   = StrokeCap.round;

    final path = Path();

    path.moveTo(0, size.height * 0.55);

    path.cubicTo(
      size.width * 0.20, size.height * 0.05, 
      size.width * 0.38, size.height * 1.05,
      size.width * 0.55, size.height * 0.50, 
    );


    path.cubicTo(
      size.width * 0.70, size.height * 0.05, 
      size.width * 0.85, size.height * 0.90, 
      size.width * 1.05, size.height * 0.40, 
    );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}