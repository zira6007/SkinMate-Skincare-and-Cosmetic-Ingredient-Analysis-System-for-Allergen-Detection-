// user/explore/product_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:skin_mate/core/constants/app_colors.dart';
import 'package:skin_mate/core/services/supabase_service.dart';
import 'package:skin_mate/core/widgets/loading_spinner.dart';
import 'package:skin_mate/features/user/explore/widgets/product_ai_assistant_sheet.dart';

class ProductDetailScreen extends StatefulWidget {
  final String productID;
  const ProductDetailScreen({super.key, required this.productID});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  bool _loading = true;
  String? _error;

  Map<String, dynamic>? _product;

  // Each item: { ...INGREDIENT fields, 'position_on_label': int }
  List<Map<String, dynamic>> _ingredients = [];

  // User's skin context
  String? _userSkinType;
  List<String> _userConcerns = [];

  // ingredientID -> list of relevant INGREDIENT_SKIN_RISK rows for this user
  Map<String, List<Map<String, dynamic>>> _riskMap = {};

  // Ingredient ids whose card is expanded
  final Set<String> _expandedIds = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // ── 1. Product ───────────────────────────────────────
      final product = await SupabaseService.client
          .from('PRODUCT')
          .select()
          .eq('productID', widget.productID)
          .maybeSingle();

      if (product == null) {
        setState(() {
          _error = 'Product not found.';
          _loading = false;
        });
        return;
      }

      // ── 2. Product ingredients joined with INGREDIENT ─────
      final piRows = await SupabaseService.client
          .from('PRODUCT_INGREDIENT')
          .select('position_on_label, INGREDIENT(*)')
          .eq('productID', widget.productID)
          .order('position_on_label', ascending: true);

      final ingredients = (piRows as List).map((row) {
        final ing = Map<String, dynamic>.from(row['INGREDIENT'] as Map);
        ing['position_on_label'] = row['position_on_label'];
        return ing;
      }).toList();

      final ingredientIds = ingredients
          .map((i) => i['ingredientID'] as String?)
          .whereType<String>()
          .toList();

      // ── 3. Current user's skin profile + concerns ─────────
      final userId = SupabaseService.client.auth.currentUser?.id;
      String? skinType;
      List<String> concerns = [];

      if (userId != null) {
        final skinProfile = await SupabaseService.client
            .from('RESULT_SKIN_PROFILE')
            .select('resultID, skin_type')
            .eq('userID', userId)
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();

        if (skinProfile != null) {
          skinType = skinProfile['skin_type'] as String?;
          final resultId = skinProfile['resultID'] as String?;

          if (resultId != null) {
            final concernRows = await SupabaseService.client
                .from('SKIN_CONCERN')
                .select('concern_tag')
                .eq('resultID', resultId);

            concerns = (concernRows as List)
                .map((r) => r['concern_tag'] as String? ?? '')
                .where((s) => s.isNotEmpty)
                .toList();
          }
        }
      }

      // ── 4. Cross-reference INGREDIENT_SKIN_RISK ───────────
      Map<String, List<Map<String, dynamic>>> riskMap = {};

      if (ingredientIds.isNotEmpty && (skinType != null || concerns.isNotEmpty)) {
        final riskRows = await SupabaseService.client
            .from('INGREDIENT_SKIN_RISK')
            .select()
            .inFilter('ingredientID', ingredientIds);

        for (final row in (riskRows as List)) {
          final r = Map<String, dynamic>.from(row);
          final ingId = r['ingredientID'] as String?;
          final rowSkinType = r['skin_type'] as String?;
          final rowConcern = r['skin_concern'] as String?;

          final matchesSkinType =
              rowSkinType != null && skinType != null && rowSkinType.toLowerCase() == skinType.toLowerCase();
          final matchesConcern =
              rowConcern != null && concerns.any((c) => c.toLowerCase() == rowConcern.toLowerCase());

          if (ingId != null && (matchesSkinType || matchesConcern)) {
            riskMap.putIfAbsent(ingId, () => []).add(r);
          }
        }
      }

      if (mounted) {
        setState(() {
          _product = Map<String, dynamic>.from(product);
          _ingredients = ingredients;
          _userSkinType = skinType;
          _userConcerns = concerns;
          _riskMap = riskMap;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load product.\n$e';
          _loading = false;
        });
      }
    }
  }

  // ─────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────
  

  @override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      backgroundColor: AppColors.background,
      elevation: 0,
      leading: const BackButton(color: AppColors.textPrimary),
      title: const Text(
        'Product Details',
        style: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 17,
        ),
      ),
      centerTitle: true,
    ),
    body: _loading
        ? const LoadingSpinner(message: 'Loading product...')
        : _error != null
            ? _buildError()
            : _buildContent(),
    floatingActionButton: _loading || _error != null
        ? null
        : FloatingActionButton.extended(
            backgroundColor: AppColors.primaryDark,
            icon: const Icon(Icons.auto_awesome, color: Colors.white),
            label: const Text('Ask AI', style: TextStyle(color: Colors.white)),
            onPressed: _openAiAssistant,
          ),
  );
}

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: AppColors.allergenColor, size: 48),
          const SizedBox(height: 16),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final product = _product!;
    final personalWarnings = _buildPersonalWarnings();

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          _buildHeader(product),
          const SizedBox(height: 20),
          if (personalWarnings.isNotEmpty) ...[
            _buildPersonalWarningSection(personalWarnings),
            const SizedBox(height: 20),
          ],
          _buildSectionTitle('Ingredients', '${_ingredients.length} listed'),
          const SizedBox(height: 10),
          if (_ingredients.isEmpty)
            _buildEmptyIngredients()
          else
            ..._ingredients.map(_buildIngredientCard),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  // HEADER
  // ─────────────────────────────────────────────────────
  Widget _buildHeader(Map<String, dynamic> product) {
    final imageUrl = product['product_image_url'] as String?;
    final brand = product['brand_name'] as String? ?? '';
    final name = product['product_name'] as String? ?? 'Unknown product';
    final description = product['product_description'] as String?;
    final skinTarget = product['skin_type_target'] as String?;
    final avgRating = product['avg_rating'];
    final category = product['category_tag'] as String?;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 140,
                height: 140,
                color: AppColors.cardBackground,
                child: imageUrl != null
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.inventory_2_outlined,
                          color: AppColors.primaryMuted,
                          size: 40,
                        ),
                      )
                    : Icon(Icons.inventory_2_outlined,
                        color: AppColors.primaryMuted, size: 40),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (brand.isNotEmpty)
            Text(
              brand.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
          const SizedBox(height: 4),
          Text(
            name,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (category != null) _infoChip(Icons.category_outlined, category),
              if (skinTarget != null)
                _infoChip(
                  Icons.face_retouching_natural_rounded,
                  '$skinTarget skin',
                  highlight: _userSkinType != null &&
                      skinTarget.toLowerCase() == _userSkinType!.toLowerCase(),
                ),
              if (avgRating != null)
                _infoChip(Icons.star_rounded, '${avgRating.toString()} / 5.0'),
            ],
          ),
          if (description != null && description.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              description,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String label, {bool highlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: highlight ? AppColors.primary.withOpacity(0.15) : AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: highlight ? Border.all(color: AppColors.primary.withOpacity(0.4)) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 13,
              color: highlight ? AppColors.primary : AppColors.textSecondary),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: highlight ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  // PERSONALIZED WARNINGS
  // ─────────────────────────────────────────────────────
  List<Map<String, dynamic>> _buildPersonalWarnings() {
    final List<Map<String, dynamic>> warnings = [];

    for (final ing in _ingredients) {
      final id = ing['ingredientID'] as String?;
      if (id == null) continue;

      final risks = _riskMap[id];
      if (risks == null || risks.isEmpty) continue;

      // Pick the highest-scoring risk row for this ingredient
      risks.sort((a, b) =>
          ((b['risk_score'] as int?) ?? 0).compareTo((a['risk_score'] as int?) ?? 0));
      final topRisk = risks.first;

      warnings.add({
        'ingredient': ing,
        'risk': topRisk,
      });
    }

    // Sort overall by risk_score descending
    warnings.sort((a, b) {
      final aScore = (a['risk']['risk_score'] as int?) ?? 0;
      final bScore = (b['risk']['risk_score'] as int?) ?? 0;
      return bScore.compareTo(aScore);
    });

    return warnings;
  }

  void _openAiAssistant() {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ProductAiAssistantSheet(
      product: _product!,
      ingredients: _ingredients,
      userSkinType: _userSkinType,
      userConcerns: _userConcerns,
      personalWarnings: _buildPersonalWarnings().map((w) {
        final ing = w['ingredient'] as Map<String, dynamic>;
        final risk = w['risk'] as Map<String, dynamic>;
        return {
          'ingredient': ing['common_name'] ?? ing['scientific_name_inci'],
          'note': risk['interaction_note'],
          'recommendation': risk['recommendation'],
        };
      }).toList(),
    ),
  );
}

  Widget _buildPersonalWarningSection(List<Map<String, dynamic>> warnings) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.allergenBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.allergenColor.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.allergenColor, size: 18),
              const SizedBox(width: 6),
              Text(
                'For your skin',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.allergenText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _userConcerns.isNotEmpty
                ? 'Based on your skin concerns: ${_userConcerns.join(', ')}'
                : 'Based on your skin type${_userSkinType != null ? ': $_userSkinType' : ''}',
            style: TextStyle(fontSize: 11, color: AppColors.allergenText.withOpacity(0.8)),
          ),
          const SizedBox(height: 12),
          ...warnings.map((w) {
            final ing = w['ingredient'] as Map<String, dynamic>;
            final risk = w['risk'] as Map<String, dynamic>;
            final score = risk['risk_score'] as int? ?? 0;
            final note = risk['interaction_note'] as String?;
            final recommendation = risk['recommendation'] as String?;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppColors.riskScoreColor(score),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          ing['common_name'] as String? ??
                              ing['scientific_name_inci'] as String? ??
                              'Unknown ingredient',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (note != null && note.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(note,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary, height: 1.4)),
                  ],
                  if (recommendation != null && recommendation.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.lightbulb_outline_rounded,
                            size: 14, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            recommendation,
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textPrimary,
                                fontStyle: FontStyle.italic,
                                height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  // INGREDIENT LIST
  // ─────────────────────────────────────────────────────
  Widget _buildSectionTitle(String title, String subtitle) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.2,
          ),
        ),
        Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _buildEmptyIngredients() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Center(
        child: Text(
          'No ingredient data available for this product.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
      ),
    );
  }

  Widget _buildIngredientCard(Map<String, dynamic> ingredient) {
    final id = ingredient['ingredientID'] as String? ?? '';
    final name = ingredient['common_name'] as String? ??
        ingredient['scientific_name_inci'] as String? ??
        'Unknown ingredient';
    final inci = ingredient['scientific_name_inci'] as String?;
    final riskLevel = ingredient['risk_level'] as String? ?? 'UNKNOWN';
    final purpose = ingredient['purpose_text'] as String?;
    final warning = ingredient['warning_explanation'] as String?;
    final position = ingredient['position_on_label'];

    final isExpanded = _expandedIds.contains(id);
    final hasPersonalRisk = _riskMap.containsKey(id);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasPersonalRisk
              ? AppColors.allergenColor.withOpacity(0.3)
              : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedIds.remove(id);
                } else {
                  _expandedIds.add(id);
                }
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  if (position != null)
                    Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$position',
                        style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary),
                      ),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary),
                        ),
                        if (inci != null && inci != name) ...[
                          const SizedBox(height: 2),
                          Text(
                            inci,
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _RiskBadge(riskLevel: riskLevel),
                  const SizedBox(width: 6),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1, color: AppColors.divider),
                  const SizedBox(height: 10),
                  if (purpose != null && purpose.trim().isNotEmpty) ...[
                    Text('Purpose',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textLabel)),
                    const SizedBox(height: 4),
                    Text(purpose,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary, height: 1.4)),
                    const SizedBox(height: 10),
                  ],
                  if (warning != null && warning.trim().isNotEmpty) ...[
                    Text('Why it matters',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textLabel)),
                    const SizedBox(height: 4),
                    Text(warning,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textPrimary, height: 1.4)),
                  ] else if (purpose == null || purpose.trim().isEmpty)
                    Text('No additional information available.',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  RISK BADGE
// ═══════════════════════════════════════════════════════════════════════════
class _RiskBadge extends StatelessWidget {
  final String riskLevel;
  const _RiskBadge({required this.riskLevel});

  @override
  Widget build(BuildContext context) {
    final normalized = riskLevel.toUpperCase();
    final label = switch (normalized) {
      'SAFE' => 'Safe',
      'CAUTION' => 'Caution',
      'ALLERGEN' => 'Allergen',
      _ => 'Unknown',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.riskBgColor(normalized),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.riskTextColor(normalized),
        ),
      ),
    );
  }
}