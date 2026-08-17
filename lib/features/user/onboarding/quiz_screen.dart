import 'package:flutter/material.dart';
import 'package:skin_mate/core/services/supabase_service.dart';
import 'skin_profile_screen.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen>
    with TickerProviderStateMixin {

  static const Color _cream      = Color(0xFFF9F3EC);
  static const Color _softBrown  = Color(0xFFB07B6B);
  static const Color _dustyPink  = Color(0xFFE8A0A0);
  static const Color _darkBrown  = Color(0xFF4A2C2A);
  static const Color _lightPink  = Color(0xFFF5D5D5);
  static const Color _mutedBrown = Color(0xFF9A7070);
  static const Color _white      = Color(0xFFFFFFFF);
  static const Color _selected   = Color(0xFFEDD5CC);

  bool    _isLoading    = true;
  bool    _isSubmitting = false;
  String? _error;
  int     _currentIndex = 0;

  List<Map<String, dynamic>>              _questions         = [];
  Map<String, List<Map<String, dynamic>>> _optionsByQuestion = {};
  final Map<String, String>               _selectedOptions   = {};

  late AnimationController _slideController;
  late Animation<Offset>   _slideAnim;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 280),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(1, 0),
      end:   Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve:  Curves.easeOut,
    ));
    _fetchQuestions();
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _fetchQuestions() async {
    try {
      final questionsRaw = await SupabaseService.client
          .from('QUIZ_QUESTION')
          .select()
          .order('question_order', ascending: true);

      final optionsRaw = await SupabaseService.client
          .from('QUIZ_ANSWER_OPTION')
          .select();

      final Map<String, List<Map<String, dynamic>>> grouped = {};
      for (final opt in List<Map<String, dynamic>>.from(optionsRaw)) {
        final qid = opt['questionID'] as String;
        grouped.putIfAbsent(qid, () => []).add(opt);
      }

      setState(() {
        _questions         = List<Map<String, dynamic>>.from(questionsRaw);
        _optionsByQuestion = grouped;
        _isLoading         = false;
      });

      _slideController.forward();
    } catch (e) {
      setState(() {
        _error     = 'Failed to load questions. Please try again.\n$e';
        _isLoading = false;
      });
    }
  }

  void _goNext() {
    final qid = _questions[_currentIndex]['questionID'] as String;
    if (!_selectedOptions.containsKey(qid)) {
      _showSnack('Please select an answer to continue');
      return;
    }
    if (_currentIndex < _questions.length - 1) {
      _slideController.reset();
      setState(() => _currentIndex++);
      _slideController.forward();
    } else {
      _submitQuiz();
    }
  }

  void _goBack() {
    if (_currentIndex > 0) {
      _slideController.reset();
      setState(() => _currentIndex--);
      _slideController.forward();
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:         Text(msg),
      backgroundColor: _softBrown,
      behavior:        SnackBarBehavior.floating,
      duration:        const Duration(seconds: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  Future<void> _submitQuiz() async {
    setState(() => _isSubmitting = true);
    try {
      final userId = SupabaseService.currentUserId!;

      final responses = _questions.map((q) {
        final qid = q['questionID'] as String;
        return {
          'userID':      userId,
          'questionID':  qid,
          'optionID':    _selectedOptions[qid],
          'answered_at': DateTime.now().toIso8601String(),
        };
      }).toList();
      await SupabaseService.client.from('QUIZ_RESPONSE').insert(responses);

      final profile = _computeSkinProfile();
      debugPrint('🔍 SKIN PROFILE: $profile');

      final profileInsert = await SupabaseService.client
          .from('RESULT_SKIN_PROFILE')
          .insert({
            'userID':       userId,
            'skin_type':    profile['skin_type'],
            'skin_subtype': profile['skin_subtype'],
            'created_at':   DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      final resultId = profileInsert['resultID'] as String;

      final concerns = profile['concerns'] as List<String>;
      if (concerns.isNotEmpty) {
        await SupabaseService.client.from('SKIN_CONCERN').insert(
          concerns.map((tag) => {
            'resultID':    resultId,
            'concern_tag': tag,
          }).toList(),
        );
      }

      if (!mounted) return;
      _goToResult(profile);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _showSnack('Error saving quiz: $e');
    }
  }

  Map<String, dynamic> _computeSkinProfile() {
    String       skinType    = 'Normal';
    String       skinSubtype = 'Normal-Sensitive';
    List<String> concerns    = [];

    for (final q in _questions) {
      final qid      = q['questionID'] as String;
      final optionId = _selectedOptions[qid];
      if (optionId == null) continue;

      final options  = _optionsByQuestion[qid] ?? [];
      final selected = options.firstWhere(
        (o) => o['optionID'] == optionId,
        orElse: () => {},
      );
      if (selected.isEmpty) continue;

      final mapsToField = selected['maps_to_field'] as String? ?? '';

      if (mapsToField.contains('skin_type:')) {
        skinType = mapsToField.split('skin_type:').last.trim();
      }
      if (mapsToField.contains('skin_subtype:')) {
        skinSubtype = mapsToField.split('skin_subtype:').last.trim();
      }
      if (mapsToField.contains('skin_concern:')) {
        final c = mapsToField.split('skin_concern:').last.trim();
        if (c != 'None') concerns.add(c);
      }
      if (mapsToField.contains('ingredient_flag:')) {
        concerns.add(mapsToField.split('ingredient_flag:').last.trim());
      }
    }

    return {
      'skin_type':    skinType,
      'skin_subtype': skinSubtype,
      'concerns':     concerns,
    };
  }

  void _goToResult(Map<String, dynamic> profile) {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => SkinProfileScreen(profile: profile),
      ),
    );
  }

  void _showInfoModal(String qid, List<Map<String, dynamic>> options) {
    showModalBottomSheet(
      context:            context,
      isScrollControlled: true,
      backgroundColor:    Colors.transparent,
      builder: (_) => _InfoModal(
        questionId: qid,
        softBrown:  _softBrown,
        darkBrown:  _darkBrown,
        cream:      _cream,
        lightPink:  _lightPink,
        dustyPink:  _dustyPink,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cream,
      body: SafeArea(
        child: _isLoading
            ? _buildLoading()
            : _error != null
                ? _buildError()
                : _buildQuiz(),
      ),
    );
  }

  Widget _buildLoading() => const Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircularProgressIndicator(color: Color(0xFFB07B6B)),
        SizedBox(height: 16),
        Text('Loading your quiz...',
          style: TextStyle(color: Color(0xFF9A7070), fontSize: 14)),
      ],
    ),
  );

  Widget _buildError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFB07B6B), size: 48),
          const SizedBox(height: 16),
          Text(_error!, textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF4A2C2A), fontSize: 14)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              setState(() { _isLoading = true; _error = null; });
              _fetchQuestions();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _softBrown, foregroundColor: _white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12))),
            child: const Text('Try Again'),
          ),
        ],
      ),
    ),
  );

  Widget _buildQuiz() {
    if (_questions.isEmpty) {
      return const Center(
        child: Text('No questions found. Check your database.'));
    }

    final current   = _questions[_currentIndex];
    final qid       = current['questionID'] as String;
    final options   = _optionsByQuestion[qid] ?? [];
    final isFirst   = _currentIndex == 0;
    final isLast    = _currentIndex == _questions.length - 1;
    final hasAnswer = _selectedOptions.containsKey(qid);

    return Column(
      children: [

        Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value:           (_currentIndex + 1) / _questions.length,
                  backgroundColor: _lightPink,
                  valueColor:      AlwaysStoppedAnimation<Color>(_softBrown),
                  minHeight:       7,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Question ${_currentIndex + 1} of ${_questions.length}',
                style: TextStyle(
                  fontSize: 12, color: _mutedBrown,
                  fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),

        Expanded(
          child: SlideTransition(
            position: _slideAnim,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width:  70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: _lightPink, shape: BoxShape.circle),
                      child: const Center(
                        child: Text('🧖‍♀️',
                          style: TextStyle(fontSize: 30))),
                    ),
                  ),

                  const SizedBox(height: 18),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          current['question_text'] as String? ?? '',
                          style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w700,
                            color: _darkBrown, height: 1.4),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _showInfoModal(qid, options),
                        child: Container(
                          width:  26, height: 26,
                          decoration: BoxDecoration(
                            color:  _lightPink,
                            shape:  BoxShape.circle,
                            border: Border.all(
                              color: _dustyPink, width: 1.2),
                          ),
                          child: Center(
                            child: Text('i',
                              style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700,
                                color: _softBrown,
                                fontStyle: FontStyle.italic)),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 22),
                  ...options.map((opt) {
                    final optId      = opt['optionID']    as String;
                    final answerText = opt['answer_text'] as String? ?? '';
                    final isSelected = _selectedOptions[qid] == optId;

                    return GestureDetector(
                      onTap: () =>
                          setState(() => _selectedOptions[qid] = optId),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin:   const EdgeInsets.only(bottom: 10),
                        padding:  const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 13),
                        decoration: BoxDecoration(
                          color: isSelected ? _selected : _white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? _softBrown
                                : const Color(0xFFE0D0C8),
                            width: isSelected ? 1.8 : 1.0,
                          ),
                          boxShadow: isSelected ? [] : [
                            BoxShadow(
                              color:      Colors.black.withOpacity(0.04),
                              blurRadius: 6,
                              offset:     const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(answerText,
                                style: TextStyle(
                                  fontSize:   14,
                                  color:      isSelected
                                      ? _darkBrown
                                      : const Color(0xFF5A3A3A),
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  height: 1.35,
                                )),
                            ),
                            const SizedBox(width: 12),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: 22, height: 22,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected ? _softBrown : _white,
                                border: Border.all(
                                  color: isSelected
                                      ? _softBrown
                                      : const Color(0xFFCCB0A8),
                                  width: 1.8,
                                ),
                              ),
                              child: isSelected
                                  ? const Icon(Icons.check,
                                      size: 13, color: Colors.white)
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),

        Container(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
          decoration: BoxDecoration(
            color: _cream,
            border: Border(
              top: BorderSide(
                color: _lightPink.withOpacity(0.8), width: 1)),
          ),
          child: Row(
            mainAxisAlignment: isFirst
                ? MainAxisAlignment.end
                : MainAxisAlignment.spaceBetween,
            children: [

              if (!isFirst)
                _NavButton(
                  icon:      Icons.chevron_left,
                  onTap:     _isSubmitting ? null : _goBack,
                  bgColor:   _lightPink,
                  iconColor: _softBrown,
                ),

              _isSubmitting
                  ? Container(
                      width: 52, height: 52,
                      decoration: BoxDecoration(
                        color: _softBrown, shape: BoxShape.circle),
                      child: const Center(
                        child: SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5)),
                      ),
                    )
                  : Opacity(
                      opacity: hasAnswer ? 1.0 : 0.45,
                      child: _NavButton(
                        icon:      isLast ? Icons.check : Icons.chevron_right,
                        onTap:     _goNext,
                        bgColor:   _softBrown,
                        iconColor: _white,
                      ),
                    ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData      icon;
  final VoidCallback? onTap;
  final Color         bgColor;
  final Color         iconColor;

  const _NavButton({
    required this.icon,
    required this.onTap,
    required this.bgColor,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52, height: 52,
        decoration: BoxDecoration(
          color: bgColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color:      Colors.black.withOpacity(0.10),
              blurRadius: 8,
              offset:     const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(icon, color: iconColor, size: 26),
      ),
    );
  }
}

class _InfoModal extends StatelessWidget {
  final String questionId;
  final Color  softBrown, darkBrown, cream, lightPink, dustyPink;

  static const Map<String, List<Map<String, String>>> _info = {
    'Q001': [
      { 'title': 'Dry Skin',
        'desc': 'Your skin is probably dry. It lost too much natural oil, so it feels stretched or a bit uncomfortable.' },
      { 'title': 'Normal Skin',
        'desc': 'Your skin is normal / balanced. Not too oily, not too dry — this is the ideal condition.' },
      { 'title': 'Combination Skin',
        'desc': 'Your skin is combination. Oily in the T-zone (forehead + nose), but normal or dry on cheeks.' },
      { 'title': 'Oily Skin',
        'desc': 'Your skin is oily. It produces excess oil across the whole face, not just certain areas.' },
    ],
    'Q002': [
      { 'title': 'Sensitive Skin',
        'desc': 'Your skin is sensitive. It gets irritated quickly, so you need gentle products and low-strength actives.' },
      { 'title': 'Normal-Sensitive',
        'desc': 'Your skin is slightly sensitive / normal. Generally okay, but strong ingredients can sometimes cause mild irritation.' },
      { 'title': 'Resilient Skin',
        'desc': 'Your skin is resilient / tolerant. It can handle stronger actives like Vitamin C or retinol without much issue.' },
    ],
    'Q003': [
      { 'title': 'Comedonal Acne',
        'desc': 'This is comedonal acne. Pores are blocked with oil and dead skin, but not inflamed.' },
      { 'title': 'Inflammatory Acne',
        'desc': 'This is inflammatory acne. Bacteria and irritation cause redness, swelling, and pain.' },
      { 'title': 'Hormonal (Cystic) Acne',
        'desc': 'This is hormonal (cystic) acne. Usually deeper, more painful, and often linked to hormone changes.' },
      { 'title': 'Clear Skin',
        'desc': 'Your skin is clear / acne-free. No active breakouts.' },
    ],
    'Q004': [
      { 'title': 'Fine Lines',
        'desc': 'Early signs of aging — small wrinkles, usually around the eyes, from facial expressions and sun exposure.' },
      { 'title': 'Loss of Firmness',
        'desc': 'Skin is starting to sag or feel less tight due to reduced collagen.' },
      { 'title': 'Texture Issues',
        'desc': 'Skin texture looks rough or bumpy, often linked to oil production or clogged pores.' },
      { 'title': 'Hyperpigmentation',
        'desc': 'Areas of uneven skin tone, like dark marks from acne, sun exposure, or past irritation.' },
    ],
    'Q005': [
      { 'title': 'High Sun Exposure',
        'desc': 'Your skin gets a lot of UV rays, which can cause tanning, dark spots, and faster aging.' },
      { 'title': 'Heavy Pollution',
        'desc': 'Your skin is exposed to dirt, smoke, and pollutants, which can clog pores and make skin look dull or irritated.' },
      { 'title': 'Dry / Air-conditioned Air',
        'desc': 'Your skin loses moisture easily, leading to dryness, tightness, or flaky skin.' },
    ],
    'Q006': [
      { 'title': 'Harsh Preservatives',
        'desc': 'Ingredients that may irritate sensitive skin. Examples: Parabens, Formaldehyde-releasers (DMDM Hydantoin, Imidazolidinyl Urea).' },
      { 'title': 'Sensitisers',
        'desc': 'Ingredients that can cause redness. Examples: Fragrance/Parfum, Alcohol Denat., Essential oils.' },
      { 'title': 'Pore-Cloggers',
        'desc': 'Ingredients that may block pores. Examples: Coconut oil, Isopropyl Myristate, Lanolin.' },
      { 'title': 'Chemical UV Filters',
        'desc': 'UV filters that may irritate some skin types. Examples: Oxybenzone, Avobenzone, Octinoxate.' },
      { 'title': 'Environmental Concerns',
        'desc': 'Ingredients linked to environmental concerns. Examples: Microplastics, animal-derived ingredients.' },
    ],
  };

  const _InfoModal({
    required this.questionId,
    required this.softBrown,
    required this.darkBrown,
    required this.cream,
    required this.lightPink,
    required this.dustyPink,
  });

  @override
  Widget build(BuildContext context) {
    final cards = _info[questionId] ?? [];

    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: BoxDecoration(
        color:        cream,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40, height: 4,
            decoration: BoxDecoration(
              color:        dustyPink.withOpacity(0.5),
              borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 8, 0),
            child: Row(
              children: [
                Text('What does this mean?',
                  style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w700,
                    color: darkBrown)),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: softBrown, size: 22)),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding:   const EdgeInsets.fromLTRB(20, 12, 20, 24),
              itemCount: cards.length,
              itemBuilder: (_, i) {
                final c = cards[i];
                return Container(
                  margin:  const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color:        Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: dustyPink.withOpacity(0.3)),
                    boxShadow: [
                      BoxShadow(
                        color:      Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset:     const Offset(0, 2)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c['title']!,
                        style: TextStyle(
                          fontSize:   14,
                          fontWeight: FontWeight.w700,
                          color:      darkBrown)),
                      const SizedBox(height: 5),
                      Text(c['desc']!,
                        style: TextStyle(
                          fontSize: 12,
                          color:    softBrown.withOpacity(0.8),
                          height:   1.5)),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}