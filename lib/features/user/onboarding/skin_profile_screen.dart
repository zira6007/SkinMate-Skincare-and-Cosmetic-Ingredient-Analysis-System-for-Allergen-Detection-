import 'package:flutter/material.dart';
//import 'package:skin_mate/core/services/supabase_service.dart';
import 'package:skin_mate/features/user/home/home_screen.dart';
import 'package:skin_mate/features/user/onboarding/quiz_screen.dart';
import 'package:skin_mate/core/constants/app_colors.dart'; 

class SkinProfileScreen extends StatefulWidget {
  final Map<String, dynamic> profile;

  const SkinProfileScreen({
    super.key,
    required this.profile,
  });

  @override
  State<SkinProfileScreen> createState() => _SkinProfileScreenState();
}

class _SkinProfileScreenState extends State<SkinProfileScreen>
    with SingleTickerProviderStateMixin {


  late AnimationController _animController;
  late Animation<double>   _fadeAnim;
  late Animation<Offset>   _slideAnim;
  late List<String> _recommended;
  late List<String> _caution;
  late List<String> _avoid;

  // ─────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();

    // Entry animation
    _animController = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve:  Curves.easeOut,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end:   Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve:  Curves.easeOut,
    ));

    _animController.forward();

    // Compute ingredient suggestions from skin profile
    _computeIngredients();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }


  void _computeIngredients() {
    final skinType    = widget.profile['skin_type']    as String? ?? '';
    final skinSubtype = widget.profile['skin_subtype'] as String? ?? '';
    final concerns    = List<String>.from(
      widget.profile['concerns'] as List? ?? [],
    );

    final Set<String> recommended = {};
    final Set<String> caution     = {};
    final Set<String> avoid       = {};

    // ── Base recommendations by skin type ─────────────
    switch (skinType.toLowerCase()) {
      case 'dry':
        recommended.addAll([
          'Hyaluronic Acid', 'Glycerin', 'Ceramides',
          'Squalane', 'Panthenol',
        ]);
        caution.addAll(['Retinol', 'AHA Exfoliants']);
        avoid.addAll(['Alcohol Denat.', 'SLS/SLES']);
        break;

      case 'oily':
        recommended.addAll([
          'Niacinamide', 'Salicylic Acid (BHA)',
          'Zinc PCA', 'Hyaluronic Acid',
        ]);
        caution.addAll(['Heavy Oils', 'Petrolatum']);
        avoid.addAll(['Comedogenic oils', 'Isopropyl Myristate']);
        break;

      case 'combination':
        recommended.addAll([
          'Niacinamide', 'Hyaluronic Acid',
          'Salicylic Acid (BHA)', 'Glycerin',
        ]);
        caution.addAll(['Retinol', 'Vitamin C']);
        avoid.addAll(['Comedogenic oils']);
        break;

      case 'normal':
      default:
        recommended.addAll([
          'Niacinamide', 'Vitamin C',
          'Hyaluronic Acid', 'SPF 30+',
        ]);
        caution.addAll(['Retinol (start low)']);
        avoid.addAll(['Harsh Preservatives']);
        break;
    }

    // ── Add by skin subtype ───────────────────────────
    if (skinSubtype.toLowerCase().contains('sensitive')) {
      recommended.addAll(['Ceramides', 'Centella Asiatica', 'Allantoin']);
      caution.addAll(['Retinol', 'Vitamin C']);
      avoid.addAll(['Fragrance/Parfum', 'Essential Oils', 'Alcohol Denat.']);
    }

    // ── Add by concerns ───────────────────────────────
    for (final concern in concerns) {
      final c = concern.toLowerCase();

      if (c.contains('acne') || c.contains('breakout')) {
        recommended.addAll(['Salicylic Acid (BHA)', 'Niacinamide', 'Azelaic Acid']);
        caution.add('Benzoyl Peroxide');
        avoid.add('Comedogenic oils');
      }

      if (c.contains('hyperpigment') || c.contains('dark spot')) {
        recommended.addAll(['Vitamin C', 'Alpha-Arbutin', 'Niacinamide', 'Tranexamic Acid']);
        caution.add('Kojic Acid');
      }

      if (c.contains('aging') || c.contains('fine line') || c.contains('wrinkle')) {
        recommended.addAll(['Retinol', 'Peptides', 'Vitamin C']);
        caution.add('Strong AHA (>10%)');
      }

      if (c.contains('texture') || c.contains('pore')) {
        recommended.addAll(['BHA', 'Niacinamide', 'AHA']);
        caution.add('Physical Scrubs');
      }

      if (c.contains('avoid_fragrance') || c.contains('sensitiser')) {
        avoid.addAll(['Fragrance/Parfum', 'Linalool', 'Limonene']);
      }

      if (c.contains('avoid_parabens') || c.contains('avoid_preserv')) {
        avoid.addAll(['Methylparaben', 'Propylparaben', 'DMDM Hydantoin']);
      }

      if (c.contains('avoid_comedogenic') || c.contains('avoid_pore')) {
        avoid.addAll(['Coconut Oil', 'Lanolin', 'Isopropyl Myristate']);
      }
    }

    // Remove duplicates between lists — recommended takes priority
    caution.removeAll(recommended);
    avoid.removeAll(recommended);
    avoid.removeAll(caution);

    setState(() {
      _recommended = recommended.toList();
      _caution     = caution.toList();
      _avoid       = avoid.toList();
    });
  }


  void _retakeQuiz() {
    Navigator.pushReplacement(
    context,
    MaterialPageRoute(builder: (_) => const QuizScreen()),
    );
  }

  // ─────────────────────────────────────────────────────
  // CONTINUE TO HOME
  // ─────────────────────────────────────────────────────
  void _continueToHome() {
    
     Navigator.pushReplacement(
       context,
       MaterialPageRoute(builder: (_) => const HomeScreen()),
     );
  }

  // ─────────────────────────────────────────────────────
  // CHANGE SECTION — retake quiz to update that section
  // ─────────────────────────────────────────────────────
  void _handleChange(String section) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Change $section?',
          style: const TextStyle(
            color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 16),
        ),
        content: Text(
          'You will need to retake the skin quiz to update your $section.',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
              style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _retakeQuiz();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Retake Quiz'),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final skinType    = widget.profile['skin_type']    as String? ?? 'Unknown';
    final skinSubtype = widget.profile['skin_subtype'] as String? ?? 'Unknown';
    final concerns    = List<String>.from(
      widget.profile['concerns'] as List? ?? [],
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: Column(
              children: [

                // ── Scrollable content ───────────────────
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [

                        // ── Header ─────────────────────────
                        const Text(
                          "Here's your concluded\nskin profile",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize:      22,
                            fontWeight:    FontWeight.w800,
                            color:         AppColors.textPrimary,
                            height:        1.3,
                            letterSpacing: -0.3,
                          ),
                        ),

                        const SizedBox(height: 24),

                        // ── Section 1: Skin Type ────────────
                        _buildSection(
                          title:   'Skin Type',
                          child:   _buildSkinTypeCard(skinType),
                          onChange: () => _handleChange('Skin Type'),
                        ),

                        const SizedBox(height: 16),

                        // ── Section 2: Skin Subtype ─────────
                        _buildSection(
                          title:   'Skin Subtype',
                          child:   _buildSubtypeCard(skinSubtype),
                          onChange: () => _handleChange('Skin Subtype'),
                        ),

                        const SizedBox(height: 16),

                        // ── Section 3: Skin Concern ─────────
                        _buildSection(
                          title:   'Skin Concern',
                          child:   _buildConcernCard(concerns),
                          onChange: () => _handleChange('Skin Concern'),
                        ),

                        const SizedBox(height: 16),

                        // ── Section 4: Ingredients Summary ──
                        _buildSection(
                          title:   'Ingredients Summary',
                          child:   _buildIngredientsCard(),
                          onChange: () => _handleChange('Ingredients Summary'),
                        ),

                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),

                // ── Bottom buttons ───────────────────────
                _buildBottomButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildSection({
    required String       title,
    required Widget       child,
    required VoidCallback onChange,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        // Section title — centered like wireframe
        Center(
          child: Text(
            title,
            style: const TextStyle(
              fontSize:   16,
              fontWeight: FontWeight.w700,
              color:      AppColors.textPrimary,
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Grey card with content + Change button
        Container(
          width:       double.infinity,
          padding:     const EdgeInsets.all(14),
          decoration:  BoxDecoration(
            color:        AppColors.secondaryCard,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // Change button row — top right of each card
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: onChange,
                    child: Row(
                      children: [
                        Text(
                          'Change',
                          style: TextStyle(
                            fontSize:   12,
                            color:      AppColors.textPrimary.withOpacity(0.7),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.edit_outlined,
                          size:  14,
                          color: AppColors.textPrimary.withOpacity(0.7),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 4),

              // Actual content
              child,
            ],
          ),
        ),
      ],
    );
  }


  Widget _buildSkinTypeCard(String skinType) {
    final descriptions = {
      'Dry':         'Your skin is dry. It lacks moisture, often feeling tight or flaky.',
      'Oily':        'Your skin is oily. It produces excess sebum across the face.',
      'Combination': 'Your skin is combination. Oily in the T-zone (forehead + nose), but normal or dry on cheeks.',
      'Normal':      'Your skin is normal / balanced. Not too oily, not too dry.',
      'Sensitive':   'Your skin is sensitive. It reacts easily to products and environment.',
    };

    return Container(
      width:       double.infinity,
      padding:     const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration:  BoxDecoration(
        color:        AppColors.cardBackground,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            skinType,
            style: const TextStyle(
              fontSize:   15,
              fontWeight: FontWeight.w700,
              color:      AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            descriptions[skinType] ??
                'Your skin type is $skinType.',
            style: TextStyle(
              fontSize: 13,
              color:    AppColors.textPrimary.withOpacity(0.75),
              height:   1.45,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildSubtypeCard(String skinSubtype) {
    return Container(
      width:   double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color:        AppColors.cardBackground,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        skinSubtype,
        style: const TextStyle(
          fontSize:   15,
          fontWeight: FontWeight.w700,
          color:      AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildConcernCard(List<String> concerns) {
    if (concerns.isEmpty) {
      return Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        decoration: BoxDecoration(
          color:        AppColors.cardBackground,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          'No specific concerns detected.',
          style: TextStyle(
            fontSize: 13,
            color:    AppColors.textPrimary.withOpacity(0.7),
          ),
        ),
      );
    }

    // Filter out ingredient_flag concerns (those go to ingredients)
    final displayConcerns = concerns
        .where((c) => !c.startsWith('avoid_'))
        .toList();

    return Container(
      width:   double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color:        AppColors.cardBackground,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: displayConcerns.isEmpty
            ? [Text('No specific concerns.',
                style: TextStyle(fontSize: 13,
                  color: AppColors.textPrimary.withOpacity(0.7)))]
            : displayConcerns.map((concern) =>
                _BulletItem(text: concern, color: AppColors.textPrimary),
              ).toList(),
      ),
    );
  }


  Widget _buildIngredientsCard() {
    return Container(
      width:   double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color:        AppColors.cardBackground,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Recommended ✅ ────────────────────────────
          if (_recommended.isNotEmpty) ...[
            const Row(
              children: [
                Text(
                  'Recommended Ingredients ',
                  style: TextStyle(
                    fontSize:   13,
                    fontWeight: FontWeight.w600,
                    color:      AppColors.textPrimary,
                  ),
                ),
                Text('✅', style: TextStyle(fontSize: 13)),
              ],
            ),
            const SizedBox(height: 4),
            ..._recommended.map((ing) =>
              _BulletItem(text: ing, color: AppColors.textPrimary)),
            const SizedBox(height: 10),
          ],

          // ── Caution ⚠️ ────────────────────────────────
          if (_caution.isNotEmpty) ...[
            const Row(
              children: [
                Text(
                  'Use with Caution ',
                  style: TextStyle(
                    fontSize:   13,
                    fontWeight: FontWeight.w600,
                    color:      AppColors.textPrimary,
                  ),
                ),
                Text('⚠️', style: TextStyle(fontSize: 13)),
              ],
            ),
            const SizedBox(height: 4),
            ..._caution.map((ing) =>
              _BulletItem(text: ing, color: AppColors.textPrimary)),
            const SizedBox(height: 10),
          ],

          // ── Avoid ❌ ──────────────────────────────────
          if (_avoid.isNotEmpty) ...[
            const Row(
              children: [
                Text(
                  'Avoid if Possible ',
                  style: TextStyle(
                    fontSize:   13,
                    fontWeight: FontWeight.w600,
                    color:      AppColors.textPrimary,
                  ),
                ),
                Text('❌', style: TextStyle(fontSize: 13)),
              ],
            ),
            const SizedBox(height: 4),
            ..._avoid.map((ing) =>
              _BulletItem(text: ing, color: AppColors.textPrimary)),
          ],

          // Empty state
          if (_recommended.isEmpty && _caution.isEmpty && _avoid.isEmpty)
            Text(
              'No ingredient recommendations available.',
              style: TextStyle(
                fontSize: 13,
                color:    AppColors.textPrimary.withOpacity(0.7),
              ),
            ),
        ],
      ),
    );
  }


  Widget _buildBottomButtons() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(
          top: BorderSide(
            color: AppColors.lightPink.withOpacity(0.8),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [

          // Retake Skin Quiz — text button on left
          Expanded(
            child: TextButton(
              onPressed: _retakeQuiz,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text(
                'Retake Skin Quiz',
                style: TextStyle(
                  fontSize:   14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Continue — filled button on right
          Expanded(
            child: ElevatedButton(
              onPressed: _continueToHome,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondaryCard,
                foregroundColor: AppColors.textPrimary,
                elevation:       0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Continue',
                style: TextStyle(
                  fontSize:   14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class _BulletItem extends StatelessWidget {
  final String text;
  final Color  color;
  const _BulletItem({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '• ',
            style: TextStyle(
              fontSize:   13,
              color:      color.withOpacity(0.8),
              fontWeight: FontWeight.w600,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color:    color.withOpacity(0.85),
                height:   1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}