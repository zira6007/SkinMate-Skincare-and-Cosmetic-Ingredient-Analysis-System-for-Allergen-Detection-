// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:skin_mate/core/services/supabase_service.dart';
import 'package:skin_mate/core/constants/app_colors.dart';

class _ScanResultItem {
  final String  scanResultId;
  final String  ingredientId;
  final String  ingredientName;
  final String  flag;
  final double? riskScore;
  final String? agentReasoning;
  final bool    conflictsWithSkin;

  const _ScanResultItem({
    required this.scanResultId,
    required this.ingredientId,
    required this.ingredientName,
    required this.flag,
    this.riskScore,
    this.agentReasoning,
    this.conflictsWithSkin = false,
  });
}

class ScanResultScreen extends StatefulWidget {
  final String scanId;
  const ScanResultScreen({super.key, required this.scanId});

  @override
  State<ScanResultScreen> createState() => _ScanResultScreenState();
}

class _ScanResultScreenState extends State<ScanResultScreen>
    with SingleTickerProviderStateMixin {

  bool    _loading = true;
  String? _error;

  String? _productName;
  String? _productImageUrl;
  String? _scanMethod;

  String? _skinType;
  String? _skinSubtype;

  List<_ScanResultItem>    _results  = [];
  final Map<String, bool>  _expanded = {};

  late AnimationController _fadeController;
  late Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _loadAll();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() { _loading = true; _error = null; });

    try {
      final userId = SupabaseService.client.auth.currentUser?.id;
      if (userId == null) throw Exception('No user session.');

      // 1. SCAN_HISTORY — "scanID" is quoted camelCase
      final scanRow = await SupabaseService.client
          .from('SCAN_HISTORY')
          .select( 'scan_method, image_url')
          .eq('scanID', widget.scanId)
          .maybeSingle();

      _scanMethod     = scanRow?['scan_method'] as String?;
      _productImageUrl = scanRow?['image_url'] as String?;

      // 2. Skin profile
      final skinRow = await SupabaseService.client
          .from('RESULT_SKIN_PROFILE')
          .select('skin_type, skin_subtype')
          .eq('userID', userId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      _skinType    = skinRow?['skin_type']    as String?;
      _skinSubtype = skinRow?['skin_subtype'] as String?;

      // 3. SCAN_RESULT — "scanID" is quoted camelCase
      final scanResults = await SupabaseService.client
          .from('SCAN_RESULT')
          .select('scan_result_id, ingredientID, flag, risk_score, agent_reasoning')
          .eq('scanID', widget.scanId);

      if ((scanResults as List).isEmpty) {
        setState(() { _results = []; _loading = false; });
        _fadeController.forward();
        return;
      }

      // 4. INGREDIENT details
      final ingredientIds = scanResults
          .map((r) => r['ingredientID'] as String)
          .toSet().toList();

      final ingredientRows = await SupabaseService.client
          .from('INGREDIENT')
          .select('ingredientID, common_name,  skin_type_concern')
          .inFilter('ingredientID', ingredientIds);

      final Map<String, Map<String, dynamic>> ingredientMap = {
        for (final row in ingredientRows as List)
          row['ingredientID'] as String: row as Map<String, dynamic>,
      };

      // 5. Build items + skin conflict check
      final items = <_ScanResultItem>[];
      for (final row in scanResults) {
        final ingredientId   = row['ingredientID']    as String;
        final flag           = (row['flag']           as String?)?.toUpperCase() ?? 'SAFE';
        final riskScore      = (row['risk_score']     as num?)?.toDouble();
        final agentReasoning = row['agent_reasoning'] as String?;

        final ingredient = ingredientMap[ingredientId];
        final name       = ingredient?['common_name'] as String? ?? ingredientId;

        bool conflictsWithSkin = false;
        if (_skinType != null && ingredient != null) {
          final unsuitable = ingredient['skin_type_concern'];
          if (unsuitable is List) {
            conflictsWithSkin = unsuitable
                .map((e) => e.toString().toLowerCase())
                .contains(_skinType!.toLowerCase());
          } else if (unsuitable is String && unsuitable.isNotEmpty) {
            conflictsWithSkin =
                unsuitable.toLowerCase().contains(_skinType!.toLowerCase());
          }
        }

        items.add(_ScanResultItem(
          scanResultId:      row['scan_result_id'] as String,
          ingredientId:      ingredientId,
          ingredientName:    name,
          flag:              flag,
          riskScore:         riskScore,
          agentReasoning:    agentReasoning,
          conflictsWithSkin: conflictsWithSkin,
        ));
      }

      items.sort((a, b) {
        if (a.conflictsWithSkin != b.conflictsWithSkin) {
          return a.conflictsWithSkin ? -1 : 1;
        }
        return _flagOrder(a.flag).compareTo(_flagOrder(b.flag));
      });

      if (mounted) {
        setState(() { _results = items; _loading = false; });
        _fadeController.forward();
      }

    } catch (e) {
      if (mounted) {
        setState(() {
          _error   = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  int _flagOrder(String flag) {
    switch (flag) {
      case 'ALLERGEN': return 0;
      case 'CAUTION':  return 1;
      default:         return 2;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _loading
          ? _buildLoading()
          : _error != null
              ? _buildError()
              : FadeTransition(opacity: _fadeAnim, child: _buildResult()),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: 16),
          Text('Loading your results…',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: AppColors.primary, size: 48),
            const SizedBox(height: 16),
            Text(_error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadAll,
              icon:  const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.surface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResult() {
    return CustomScrollView(
      slivers: [
        _buildSliverHeader(),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              const SizedBox(height: 20),
              _buildRiskSummaryCard(),
              const SizedBox(height: 16),
              if (_skinType != null) _buildSkinBanner(),
              if (_skinType != null) const SizedBox(height: 16),
              Row(
                children: [
                  Text('Ingredients',
                    style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    )),
                  const Spacer(),
                  Text('${_results.length} detected',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
              const SizedBox(height: 12),
              if (_results.isEmpty)
                _buildEmptyResults()
              else
                ...(_results.map((item) => _buildIngredientCard(item))),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildSliverHeader() {
    return SliverAppBar(
      expandedHeight:  _productImageUrl != null ? 240 : 120,
      pinned:          true,
      backgroundColor: AppColors.primaryDark,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_rounded, color: AppColors.surface),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        title: Text(
          _productName ?? 'Scan Results',
          style: TextStyle(
            fontSize: 16, fontWeight: FontWeight.w700,
            color: AppColors.surface,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        background: _productImageUrl != null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    _productImageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        Container(color: AppColors.primaryDark),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end:   Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          AppColors.primaryDark.withOpacity(0.85),
                        ],
                      ),
                    ),
                  ),
                  if (_scanMethod != null)
                    Positioned(
                      top: 16, right: 16,
                      child: _ScanMethodBadge(method: _scanMethod!),
                    ),
                ],
              )
            : Container(
                color: AppColors.primaryDark,
                child: _scanMethod != null
                    ? Align(
                        alignment: Alignment.topRight,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(0, 16, 16, 0),
                          child: _ScanMethodBadge(method: _scanMethod!),
                        ),
                      )
                    : null,
              ),
      ),
    );
  }

  Widget _buildRiskSummaryCard() {
    final allergenCount = _results.where((r) => r.flag == 'ALLERGEN').length;
    final cautionCount  = _results.where((r) => r.flag == 'CAUTION').length;
    final safeCount     = _results.where((r) => r.flag == 'SAFE').length;
    final conflictCount = _results.where((r) => r.conflictsWithSkin).length;

    final Color    overallColor;
    final String   overallLabel;
    final IconData overallIcon;

    if (allergenCount > 0) {
      overallColor = AppColors.allergenColor;
      overallLabel = allergenCount == 1
          ? '1 allergen detected'
          : '$allergenCount allergens detected';
      overallIcon  = Icons.dangerous_rounded;
    } else if (cautionCount > 0) {
      overallColor = AppColors.cautionColor;
      overallLabel = cautionCount == 1
          ? '1 ingredient needs caution'
          : '$cautionCount ingredients need caution';
      overallIcon  = Icons.warning_amber_rounded;
    } else {
      overallColor = AppColors.safeColor;
      overallLabel = 'All ingredients look safe';
      overallIcon  = Icons.check_circle_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color:        AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: overallColor.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color:      overallColor.withOpacity(0.08),
            blurRadius: 20,
            offset:     const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color:        overallColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(overallIcon, color: overallColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(overallLabel,
                      style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800,
                        color: overallColor,
                      )),
                    Text('${_results.length} ingredients analysed',
                      style: TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: AppColors.divider, height: 1),
          const SizedBox(height: 14),
         Wrap(
  spacing: 8,
  runSpacing: 8,
  children: [
    _buildCountPill(safeCount,     'Safe',     AppColors.safeColor),
    _buildCountPill(cautionCount,  'Caution',  AppColors.cautionColor),
    _buildCountPill(allergenCount, 'Allergen', AppColors.allergenColor),
    if (conflictCount > 0)
      _buildCountPill(conflictCount, 'Skin conflict',
          const Color(0xFF9B59B6)),
  ],
),
        ],
      ),
    );
  }

  Widget _buildCountPill(int count, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color:        color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border:       Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$count',
            style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(width: 4),
          Text(label,
            style: TextStyle(fontSize: 11, color: color.withOpacity(0.8))),
        ],
      ),
    );
  }

  Widget _buildSkinBanner() {
    final conflictCount = _results.where((r) => r.conflictsWithSkin).length;
    final subtitle = _skinSubtype != null
        ? '$_skinType · $_skinSubtype'
        : _skinType!;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        const Color(0xFFF3EBFF),
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(color: const Color(0xFFD5B8FF)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.face_retouching_natural_rounded,
            color: Color(0xFF9B59B6), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Personalised for your skin type',
                  style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700,
                    color: Color(0xFF6C3483),
                  )),
                const SizedBox(height: 2),
                Text(
                  conflictCount > 0
                      ? '$subtitle — $conflictCount ingredient${conflictCount > 1 ? 's' : ''} may not suit your skin'
                      : '$subtitle — no specific conflicts found',
                  style: const TextStyle(
                    fontSize: 12, color: Color(0xFF8E44AD), height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIngredientCard(_ScanResultItem item) {
    final isExpanded   = _expanded[item.scanResultId] ?? false;
    final hasReasoning = item.agentReasoning != null &&
        item.agentReasoning!.trim().isNotEmpty;
    final flagColor    = AppColors.riskColor(item.flag);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color:        AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: item.conflictsWithSkin
              ? const Color(0xFFD5B8FF)
              : flagColor.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset:     const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: hasReasoning
                ? () => setState(
                    () => _expanded[item.scanResultId] = !isExpanded)
                : null,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 3, height: 36,
                    decoration: BoxDecoration(
                      color:        flagColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.ingredientName,
                          style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          )),
                        if (item.conflictsWithSkin) ...[
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              const Icon(
                                Icons.face_retouching_natural_rounded,
                                size: 11, color: Color(0xFF9B59B6)),
                              const SizedBox(width: 3),
                              Text('May not suit $_skinType skin',
                                style: const TextStyle(
                                  fontSize: 11, color: Color(0xFF9B59B6))),
                            ],
                          ),
                        ],
                        if (item.riskScore != null) ...[
                          const SizedBox(height: 4),
                          _RiskScoreBar(score: item.riskScore!),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  _RiskBadge(flag: item.flag),
                  if (hasReasoning) ...[
                    const SizedBox(width: 6),
                    AnimatedRotation(
                      turns:    isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(Icons.keyboard_arrow_down_rounded,
                        color: AppColors.textSecondary, size: 20),
                    ),
                  ],
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild:  const SizedBox(width: double.infinity),
            secondChild: _buildReasoning(item.agentReasoning ?? ''),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }

  Widget _buildReasoning(String text) {
    return Container(
      width:   double.infinity,
      padding: const EdgeInsets.fromLTRB(30, 0, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(color: AppColors.divider, height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 22, height: 22,
                decoration: BoxDecoration(
                  color:        AppColors.secondaryLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(Icons.psychology_rounded,
                  size: 13, color: AppColors.primary),
              ),
              const SizedBox(width: 7),
              Text('AI Analysis',
                style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary, letterSpacing: 0.3,
                )),
            ],
          ),
          const SizedBox(height: 8),
          Text(text,
            style: TextStyle(
              fontSize: 13, color: AppColors.textPrimary, height: 1.55)),
        ],
      ),
    );
  }

  Widget _buildEmptyResults() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color:        AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(Icons.inbox_outlined,
            color: AppColors.textSecondary.withOpacity(0.4), size: 40),
          const SizedBox(height: 12),
          Text('No ingredients found',
            style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            )),
          const SizedBox(height: 6),
          Text(
            'The AI could not detect any ingredients\nin this image. Try a clearer photo.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13, color: AppColors.textSecondary, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _RiskBadge extends StatelessWidget {
  final String flag;
  const _RiskBadge({required this.flag});

  @override
  Widget build(BuildContext context) {
    final String   label;
    final IconData icon;

    switch (flag.toUpperCase()) {
      case 'ALLERGEN':
        label = 'Allergen';
        icon  = Icons.dangerous_rounded;
        break;
      case 'CAUTION':
        label = 'Caution';
        icon  = Icons.warning_amber_rounded;
        break;
      default:
        label = 'Safe';
        icon  = Icons.check_circle_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color:        AppColors.riskBgColor(flag),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.riskColor(flag)),
          const SizedBox(width: 4),
          Text(label,
            style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700,
              color: AppColors.riskTextColor(flag),
            )),
        ],
      ),
    );
  }
}

class _RiskScoreBar extends StatelessWidget {
  final double score; // expected range: 0–100
  const _RiskScoreBar({required this.score});

  @override
  Widget build(BuildContext context) {
    final fraction = (score / 100).clamp(0.0, 1.0);
    final flag = score >= 70 ? 'ALLERGEN' : score >= 40 ? 'CAUTION' : 'SAFE';
    final color = AppColors.riskColor(flag);

    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value:           fraction,
              backgroundColor: AppColors.cardBackground,
              valueColor:      AlwaysStoppedAnimation<Color>(color),
              minHeight:       4,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text('${score.toInt()}%',
          style: TextStyle(
            fontSize: 10, color: color, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _ScanMethodBadge extends StatelessWidget {
  final String method;
  const _ScanMethodBadge({required this.method});

  @override
  Widget build(BuildContext context) {
    final isBarcode = method == 'barcode';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color:        Colors.black.withOpacity(0.45),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isBarcode ? Icons.qr_code_rounded : Icons.document_scanner_rounded,
            color: AppColors.surface, size: 12,
          ),
          const SizedBox(width: 5),
          Text(
            isBarcode ? 'Barcode scan' : 'OCR scan',
            style: TextStyle(
              fontSize: 11, color: AppColors.surface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}