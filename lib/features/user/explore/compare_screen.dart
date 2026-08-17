import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:skin_mate/core/constants/app_colors.dart';

// ─────────────────────────────────────────────────────────
// DATA MODELS
// ─────────────────────────────────────────────────────────

class ProductData {
  final String productID;
  final String brandName;
  final String productName;
  final String? imageUrl;
  final String? category;
  final double? avgRating;
  final List<IngredientRow> ingredients;

  const ProductData({
    required this.productID,
    required this.brandName,
    required this.productName,
    this.imageUrl,
    this.category,
    this.avgRating,
    required this.ingredients,
  });
}

class IngredientRow {
  final String ingredientID;
  final String scientificName;
  final String? commonName;
  final String? riskLevel; // 'SAFE' | 'CAUTION' | 'ALLERGEN'
  final String? purposeText;
  final String? warningExplanation;
  final int position;

  const IngredientRow({
    required this.ingredientID,
    required this.scientificName,
    this.commonName,
    this.riskLevel,
    this.purposeText,
    this.warningExplanation,
    required this.position,
  });

  String get displayName =>
      (commonName != null && commonName!.isNotEmpty) ? commonName! : scientificName;
  String get flag => (riskLevel ?? 'SAFE').toUpperCase();
}

// ─────────────────────────────────────────────────────────
// COMPARE SCREEN
// ─────────────────────────────────────────────────────────

class CompareScreen extends StatefulWidget {
  final String productIdA;
  final String productIdB;

  const CompareScreen({
    super.key,
    required this.productIdA,
    required this.productIdB,
  });

  @override
  State<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends State<CompareScreen>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;

  ProductData? _productA;
  ProductData? _productB;
  String? _aiVerdict;
  bool _loadingProducts = true;
  bool _loadingAI = false;
  String? _error;

  late AnimationController _verdictAnim;
  late Animation<double> _verdictFade;

  String _filterMode = 'all'; // 'all' | 'unique' | 'flagged'

  @override
  void initState() {
    super.initState();
    _verdictAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _verdictFade =
        CurvedAnimation(parent: _verdictAnim, curve: Curves.easeInOut);
    _loadBoth();
  }

  @override
  void dispose() {
    _verdictAnim.dispose();
    super.dispose();
  }

  // ── Supabase fetching ──────────────────────────────────

  Future<ProductData> _fetchProduct(String productID) async {
    // 1. Fetch product row
    final productRes = await _supabase
        .from('PRODUCT')
        .select('productID, brand_name, product_name, product_image_url, category_tag, avg_rating')
        .eq('productID', productID)
        .single();

    // 2. Fetch PRODUCT_INGREDIENT rows
    final piRes = await _supabase
        .from('PRODUCT_INGREDIENT')
        .select('position_on_label, ingredientID')
        .eq('productID', productID)
        .order('position_on_label', ascending: true);

    final piList = piRes as List;

    if (piList.isEmpty) {
      return ProductData(
        productID: productRes['productID'] as String,
        brandName: productRes['brand_name'] as String? ?? '',
        productName: productRes['product_name'] as String? ?? '',
        imageUrl: productRes['product_image_url'] as String?,
        category: productRes['category_tag'] as String?,
        avgRating: (productRes['avg_rating'] as num?)?.toDouble(),
        ingredients: [],
      );
    }

    // Build position map: ingredientID -> position
    final posMap = <String, int>{};
    for (final r in piList) {
      final id = r['ingredientID'] as String?;
      if (id != null) posMap[id] = (r['position_on_label'] as int?) ?? 0;
    }

    final ingredientIDs = posMap.keys.toList();

    // 3. Fetch ingredient details
    final ingRes = await _supabase
        .from('INGREDIENT')
        .select('ingredientID, scientific_name_inci, common_name, risk_level, purpose_text, warning_explanation')
        .inFilter('ingredientID', ingredientIDs);

    final ingMap = <String, Map<String, dynamic>>{
      for (final r in ingRes as List) r['ingredientID'] as String: r,
    };

    final ingredients = ingredientIDs
        .where((id) => ingMap.containsKey(id))
        .map((id) {
          final ing = ingMap[id]!;
          return IngredientRow(
            ingredientID: id,
            scientificName: ing['scientific_name_inci'] as String? ?? id,
            commonName: ing['common_name'] as String?,
            riskLevel: ing['risk_level'] as String?,
            purposeText: ing['purpose_text'] as String?,
            warningExplanation: ing['warning_explanation'] as String?,
            position: posMap[id] ?? 0,
          );
        })
        .toList()
      ..sort((a, b) => a.position.compareTo(b.position));

    return ProductData(
      productID: productRes['productID'] as String,
      brandName: productRes['brand_name'] as String? ?? '',
      productName: productRes['product_name'] as String? ?? '',
      imageUrl: productRes['product_image_url'] as String?,
      category: productRes['category_tag'] as String?,
      avgRating: (productRes['avg_rating'] as num?)?.toDouble(),
      ingredients: ingredients,
    );
  }

  Future<void> _loadBoth() async {
    setState(() {
      _loadingProducts = true;
      _error = null;
      _aiVerdict = null;
    });
    try {
      final results = await Future.wait([
        _fetchProduct(widget.productIdA),
        _fetchProduct(widget.productIdB),
      ]);
      setState(() {
        _productA = results[0];
        _productB = results[1];
        _loadingProducts = false;
      });
      _runAIAnalysis();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loadingProducts = false;
      });
    }
  }

  // ── Agentic AI via Anthropic API ───────────────────────

  Future<void> _runAIAnalysis() async {
    if (_productA == null || _productB == null) return;
    setState(() {
      _loadingAI = true;
      _aiVerdict = null;
    });

    try {
      final response = await http.post(
        Uri.parse('https://api.anthropic.com/v1/messages'),
        headers: {
          'Content-Type': 'application/json',
          'anthropic-version': '2023-06-01',
        },
        body: jsonEncode({
          'model': 'claude-sonnet-4-6',
          'max_tokens': 1000,
          'system':
              'You are a skincare ingredient expert. Analyse the two products and give a concise, structured verdict. '
              'Return ONLY a JSON object — no markdown, no backticks, no preamble. '
              'Keys: "winner" ("A"|"B"|"tie"), "headline" (string ≤12 words), '
              '"summary" (string, 2-3 sentences), "pros_a" ([string]), "cons_a" ([string]), '
              '"pros_b" ([string]), "cons_b" ([string]), "verdict_tip" (string ≤20 words).',
          'messages': [
            {'role': 'user', 'content': _buildAnalysisPrompt(_productA!, _productB!)},
          ],
        }),
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data.containsKey('error')) throw Exception(data['error']['message']);

      final text = (data['content'] as List)
          .where((b) => b['type'] == 'text')
          .map((b) => b['text'] as String)
          .join('');

      setState(() {
        _aiVerdict = text;
        _loadingAI = false;
      });
      _verdictAnim.forward(from: 0);
    } catch (e) {
      setState(() {
        _aiVerdict = null;
        _loadingAI = false;
      });
    }
  }

  String _buildAnalysisPrompt(ProductData a, ProductData b) {
    String ingList(ProductData p) => p.ingredients.isEmpty
        ? '(no ingredient data)'
        : p.ingredients
            .map((i) =>
                '${i.position}. ${i.displayName}'
                '${i.flag != 'SAFE' ? ' [${i.flag}]' : ''}'
                '${i.purposeText != null ? ' — ${i.purposeText}' : ''}')
            .join('\n');

    return '''Compare these two skincare products:

PRODUCT A: ${a.brandName} – ${a.productName} (rating: ${a.avgRating ?? 'N/A'})
Category: ${a.category ?? 'N/A'}
Ingredients:
${ingList(a)}

PRODUCT B: ${b.brandName} – ${b.productName} (rating: ${b.avgRating ?? 'N/A'})
Category: ${b.category ?? 'N/A'}
Ingredients:
${ingList(b)}

Compare ingredient safety, efficacy, and suitability for general skin health. Declare an overall winner.''';
  }

  // ── Ingredient list helpers ────────────────────────────

  List<String> get _allIngredientIDs {
    final ids = <String>{};
    if (_productA != null) ids.addAll(_productA!.ingredients.map((i) => i.ingredientID));
    if (_productB != null) ids.addAll(_productB!.ingredients.map((i) => i.ingredientID));
    return ids.toList();
  }

  List<String> _filteredIDs() {
    if (_productA == null || _productB == null) return [];
    final aIDs = _productA!.ingredients.map((i) => i.ingredientID).toSet();
    final bIDs = _productB!.ingredients.map((i) => i.ingredientID).toSet();

    switch (_filterMode) {
      case 'unique':
        return _allIngredientIDs
            .where((id) => !(aIDs.contains(id) && bIDs.contains(id)))
            .toList();
      case 'flagged':
        return _allIngredientIDs.where((id) {
          final aIng = _productA!.ingredients.where((i) => i.ingredientID == id).firstOrNull;
          final bIng = _productB!.ingredients.where((i) => i.ingredientID == id).firstOrNull;
          return (aIng != null && (aIng.flag == 'CAUTION' || aIng.flag == 'ALLERGEN')) ||
              (bIng != null && (bIng.flag == 'CAUTION' || bIng.flag == 'ALLERGEN'));
        }).toList();
      default:
        return _allIngredientIDs;
    }
  }

  // ── Ingredient detail bottom sheet ────────────────────

  void _showIngredientDetail(IngredientRow? aIng, IngredientRow? bIng) {
    HapticFeedback.selectionClick();
    final ing = aIng ?? bIng!;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.85,
        builder: (_, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Text(ing.displayName,
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary)),
              if (ing.commonName != null && ing.commonName!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(ing.scientificName,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                ),
              const SizedBox(height: 12),
              _riskBadge(ing.flag),
              const SizedBox(height: 16),
              if (ing.purposeText != null && ing.purposeText!.isNotEmpty) ...[
                _sheetSection('Purpose', ing.purposeText!),
                const SizedBox(height: 12),
              ],
              if (ing.warningExplanation != null && ing.warningExplanation!.isNotEmpty) ...[
                _sheetSection('Warning', ing.warningExplanation!, isWarning: true),
                const SizedBox(height: 12),
              ],
              const Text('Found in',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textLabel,
                      fontSize: 13)),
              const SizedBox(height: 8),
              Row(children: [
                _foundInChip('Product A', aIng != null,
                    aIng != null ? 'Position #${aIng.position}' : null),
                const SizedBox(width: 8),
                _foundInChip('Product B', bIng != null,
                    bIng != null ? 'Position #${bIng.position}' : null),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _riskBadge(String flag) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.riskBgColor(flag),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.riskColor(flag).withOpacity(0.35)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 7, height: 7,
              decoration: BoxDecoration(
                  color: AppColors.riskColor(flag), shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(
            flag == 'SAFE' ? 'Safe' : flag == 'CAUTION' ? 'Caution' : 'Allergen',
            style: TextStyle(
                color: AppColors.riskTextColor(flag),
                fontWeight: FontWeight.w700,
                fontSize: 13),
          ),
        ]),
      );

  Widget _sheetSection(String label, String content, {bool isWarning = false}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: TextStyle(
                fontWeight: FontWeight.w700,
                color: isWarning ? AppColors.allergenColor : AppColors.textLabel,
                fontSize: 13)),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: isWarning ? AppColors.allergenBg : AppColors.cardBackground,
              borderRadius: BorderRadius.circular(10)),
          child: Text(content,
              style: TextStyle(
                  color: isWarning ? AppColors.allergenText : AppColors.textPrimary,
                  fontSize: 13,
                  height: 1.5)),
        ),
      ]);

  Widget _foundInChip(String label, bool present, String? subtitle) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: present ? AppColors.safeBg : AppColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: present
                    ? AppColors.safeColor.withOpacity(0.4)
                    : AppColors.border),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(
                  present
                      ? Icons.check_circle_rounded
                      : Icons.remove_circle_outline_rounded,
                  size: 14,
                  color: present ? AppColors.safeColor : AppColors.textHint),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: present ? AppColors.safeText : AppColors.textHint)),
            ]),
            if (present && subtitle != null) ...[
              const SizedBox(height: 2),
              Text(subtitle,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary)),
            ],
          ]),
        ),
      );

  // ── BUILD ──────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: _loadingProducts
          ? _buildLoader('Loading products…')
          : _error != null
              ? _buildError()
              : _buildContent(),
    );
  }

  PreferredSizeWidget _buildAppBar() => AppBar(
        backgroundColor: AppColors.surfaceDark,
        foregroundColor: AppColors.textOnDark,
        elevation: 0,
        centerTitle: true,
        title: const Text('Compare Products',
            style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                letterSpacing: 0.3,
                color: AppColors.textOnDark)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded,
                color: AppColors.primaryLight, size: 20),
            tooltip: 'Re-analyse',
            onPressed: _loadBoth,
          ),
        ],
      );

  Widget _buildLoader(String msg) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: 16),
          Text(msg,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 14)),
        ]),
      );

  Widget _buildError() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline_rounded,
                color: AppColors.allergenColor, size: 48),
            const SizedBox(height: 16),
            const Text('Something went wrong',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 18)),
            const SizedBox(height: 8),
            Text(_error ?? '',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadBoth,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textWhite),
            ),
          ]),
        ),
      );

  Widget _buildContent() => CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildProductHeaders()),
          SliverToBoxAdapter(child: _buildAIVerdictPanel()),
          SliverPersistentHeader(
              pinned: true,
              delegate: _FilterTabDelegate(child: _buildFilterTabs())),
          SliverToBoxAdapter(child: _buildIngredientColumnHeader()),
          ..._buildIngredientRows(),
          const SliverToBoxAdapter(child: SizedBox(height: 48)),
        ],
      );

  // ── Product header cards ───────────────────────────────

  Widget _buildProductHeaders() => Container(
        color: AppColors.surfaceDark,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: Row(children: [
          Expanded(child: _buildProductCard(_productA!, 'A')),
          const SizedBox(width: 10),
          Column(children: [
            const SizedBox(height: 4),
            Container(
              width: 34, height: 34,
              decoration: const BoxDecoration(
                  color: AppColors.primary, shape: BoxShape.circle),
              child: const Center(
                child: Text('VS',
                    style: TextStyle(
                        color: AppColors.textWhite,
                        fontWeight: FontWeight.w900,
                        fontSize: 11)),
              ),
            ),
          ]),
          const SizedBox(width: 10),
          Expanded(child: _buildProductCard(_productB!, 'B')),
        ]),
      );

  Widget _buildProductCard(ProductData p, String label) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.primaryDark,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.primary.withOpacity(0.4)),
        ),
        child: Column(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: p.imageUrl != null
                ? Image.network(p.imageUrl!,
                    height: 80,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _imagePlaceholder())
                : _imagePlaceholder(),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(20)),
            child: Text('Product $label',
                style: const TextStyle(
                    color: AppColors.textWhite,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5)),
          ),
          const SizedBox(height: 6),
          Text(p.brandName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: AppColors.textOnDark,
                  fontSize: 10,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(p.productName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.textWhite,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  height: 1.3)),
          const SizedBox(height: 6),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (p.avgRating != null) ...[
              const Icon(Icons.star_rounded,
                  size: 12, color: AppColors.cautionColor),
              const SizedBox(width: 2),
              Text(p.avgRating!.toStringAsFixed(1),
                  style: const TextStyle(
                      color: AppColors.textOnDark,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
            ],
            const Icon(Icons.science_outlined,
                size: 11, color: AppColors.primaryLight),
            const SizedBox(width: 2),
            Text('${p.ingredients.length} ing.',
                style: const TextStyle(
                    color: AppColors.primaryLight, fontSize: 10)),
          ]),
        ]),
      );

  Widget _imagePlaceholder() => Container(
        height: 80,
        color: AppColors.primaryMuted.withOpacity(0.25),
        child: const Center(
            child: Icon(Icons.inventory_2_outlined,
                color: AppColors.primaryLight, size: 32)),
      );

  // ── AI Verdict panel ───────────────────────────────────

  Widget _buildAIVerdictPanel() {
    if (_loadingAI) {
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border)),
        child: const Row(children: [
          SizedBox(
              width: 18, height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.primary)),
          SizedBox(width: 12),
          Expanded(
            child: Text('AI is analysing ingredients…',
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 13)),
          ),
        ]),
      );
    }

    if (_aiVerdict == null) return const SizedBox.shrink();

    Map<String, dynamic>? parsed;
    try {
      final clean =
          _aiVerdict!.replaceAll('```json', '').replaceAll('```', '').trim();
      parsed = jsonDecode(clean) as Map<String, dynamic>;
    } catch (_) {
      return const SizedBox.shrink();
    }

    final winner = parsed['winner'] as String? ?? 'tie';
    final headline = parsed['headline'] as String? ?? '';
    final summary = parsed['summary'] as String? ?? '';
    final prosA = List<String>.from(parsed['pros_a'] ?? []);
    final consA = List<String>.from(parsed['cons_a'] ?? []);
    final prosB = List<String>.from(parsed['pros_b'] ?? []);
    final consB = List<String>.from(parsed['cons_b'] ?? []);
    final tip = parsed['verdict_tip'] as String? ?? '';

    final winnerColor =
        winner == 'tie' ? AppColors.cautionColor : AppColors.safeColor;
    final winnerLabel = winner == 'tie'
        ? '🤝 It\'s a Tie'
        : winner == 'A'
            ? '🏆 Product A Wins'
            : '🏆 Product B Wins';

    return FadeTransition(
      opacity: _verdictFade,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
                color: AppColors.primaryDark.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 4))
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
                color: AppColors.primaryDark,
                borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.auto_awesome_rounded,
                    color: AppColors.primaryLight, size: 16),
              ),
              const SizedBox(width: 10),
              const Text('AI Ingredient Analysis',
                  style: TextStyle(
                      color: AppColors.textOnDark,
                      fontWeight: FontWeight.w700,
                      fontSize: 14)),
              const Spacer(),
              GestureDetector(
                onTap: _runAIAnalysis,
                child: const Icon(Icons.refresh_rounded,
                    color: AppColors.primaryLight, size: 18),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                      color: winnerColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: winnerColor.withOpacity(0.4))),
                  child: Text(winnerLabel,
                      style: TextStyle(
                          color: winnerColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 13)),
                ),
              ),
              const SizedBox(height: 10),
              Text(headline,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      height: 1.3)),
              const SizedBox(height: 8),
              Text(summary,
                  style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.5)),
              const SizedBox(height: 16),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                    child: _buildProConBlock('Product A', prosA, consA, winner == 'A')),
                const SizedBox(width: 10),
                Expanded(
                    child: _buildProConBlock('Product B', prosB, consB, winner == 'B')),
              ]),
              if (tip.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(10)),
                  child: Row(children: [
                    const Icon(Icons.tips_and_updates_outlined,
                        color: AppColors.primary, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(tip,
                          style: const TextStyle(
                              color: AppColors.textLabel,
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              height: 1.4)),
                    ),
                  ]),
                ),
              ],
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _buildProConBlock(
      String label, List<String> pros, List<String> cons, bool isWinner) =>
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isWinner ? AppColors.safeBg.withOpacity(0.5) : AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: isWinner
                  ? AppColors.safeColor.withOpacity(0.3)
                  : AppColors.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(label,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12)),
            if (isWinner) ...[
              const SizedBox(width: 4),
              const Icon(Icons.emoji_events_rounded,
                  size: 13, color: AppColors.safeColor),
            ]
          ]),
          const SizedBox(height: 6),
          ...pros.map((p) => _proConItem(p, true)),
          ...cons.map((c) => _proConItem(c, false)),
        ]),
      );

  Widget _proConItem(String text, bool isPro) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(isPro ? Icons.check_circle_rounded : Icons.cancel_rounded,
              size: 12,
              color: isPro ? AppColors.safeColor : AppColors.allergenColor),
          const SizedBox(width: 4),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    color: isPro ? AppColors.safeText : AppColors.allergenText,
                    fontSize: 11,
                    height: 1.4)),
          ),
        ]),
      );

  // ── Filter tabs ────────────────────────────────────────

  Widget _buildFilterTabs() => Container(
        color: AppColors.background,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          _filterTab('all', 'All'),
          const SizedBox(width: 8),
          _filterTab('unique', 'Unique only'),
          const SizedBox(width: 8),
          _filterTab('flagged', 'Flagged'),
        ]),
      );

  Widget _filterTab(String mode, String label) {
    final active = _filterMode == mode;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _filterMode = mode);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: active ? AppColors.primary : AppColors.border),
        ),
        child: Text(label,
            style: TextStyle(
                color: active ? AppColors.textWhite : AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
      ),
    );
  }

  // ── Ingredient column header ───────────────────────────

  Widget _buildIngredientColumnHeader() => Container(
        color: AppColors.cardBackground,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(children: [
          const Expanded(
              child: Text('Product A',
                  style: TextStyle(
                      color: AppColors.textLabel,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      letterSpacing: 0.5))),
          Container(
            width: 26,
            alignment: Alignment.center,
            child: const Text('#',
                style: TextStyle(color: AppColors.textHint, fontSize: 10)),
          ),
          const Expanded(
              child: Text('Product B',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      color: AppColors.textLabel,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      letterSpacing: 0.5))),
        ]),
      );

  // ── Ingredient rows ────────────────────────────────────

  List<Widget> _buildIngredientRows() {
    if (_productA == null || _productB == null) return [];

    final filteredIDs = _filteredIDs();

    if (filteredIDs.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Text(
                _productA!.ingredients.isEmpty && _productB!.ingredients.isEmpty
                    ? 'No ingredient data found for these products.'
                    : 'No ingredients match this filter.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13, height: 1.5),
              ),
            ),
          ),
        )
      ];
    }

    final aMap = {for (var i in _productA!.ingredients) i.ingredientID: i};
    final bMap = {for (var i in _productB!.ingredients) i.ingredientID: i};

    return [
      SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final id = filteredIDs[index];
            final aIng = aMap[id];
            final bIng = bMap[id];
            return GestureDetector(
              onTap: () => _showIngredientDetail(aIng, bIng),
              child: _IngredientCompareRow(
                ingredientID: id,
                aIngredient: aIng,
                bIngredient: bIng,
                isUnique: !(aIng != null && bIng != null),
                rowIndex: index,
              ),
            );
          },
          childCount: filteredIDs.length,
        ),
      ),
    ];
  }
}

// ─────────────────────────────────────────────────────────
// INGREDIENT COMPARE ROW
// ─────────────────────────────────────────────────────────

class _IngredientCompareRow extends StatelessWidget {
  final String ingredientID;
  final IngredientRow? aIngredient;
  final IngredientRow? bIngredient;
  final bool isUnique;
  final int rowIndex;

  const _IngredientCompareRow({
    required this.ingredientID,
    required this.aIngredient,
    required this.bIngredient,
    required this.isUnique,
    required this.rowIndex,
  });

  @override
  Widget build(BuildContext context) {
    final isEven = rowIndex % 2 == 0;
    final base = isEven ? AppColors.surface : AppColors.background;
    final bg = isUnique ? AppColors.selectedHighlight.withOpacity(0.4) : base;

    return Container(
      color: bg,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Expanded(
            child: _buildCell(aIngredient,
                crossAlign: CrossAxisAlignment.start,
                textAlign: TextAlign.left)),
        const SizedBox(width: 8),
        SizedBox(width: 26, child: _buildCenterBadge()),
        const SizedBox(width: 8),
        Expanded(
            child: _buildCell(bIngredient,
                crossAlign: CrossAxisAlignment.end,
                textAlign: TextAlign.right)),
      ]),
    );
  }

  Widget _buildCenterBadge() {
    if (isUnique) {
      return Container(
        width: 26, height: 26,
        decoration: BoxDecoration(
            color: AppColors.selectedHighlight,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primaryMuted.withOpacity(0.4))),
        child: const Center(
            child: Icon(Icons.star_outline_rounded,
                size: 12, color: AppColors.primary)),
      );
    }
    final pos = aIngredient?.position ?? bIngredient?.position ?? 0;
    return Container(
      width: 26, height: 26,
      decoration: const BoxDecoration(
          color: AppColors.divider, shape: BoxShape.circle),
      child: Center(
        child: Text('$pos',
            style: const TextStyle(
                color: AppColors.textLabel,
                fontSize: 9,
                fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildCell(IngredientRow? ing, {
    required CrossAxisAlignment crossAlign,
    required TextAlign textAlign,
  }) {
    if (ing == null) {
      return SizedBox(
        height: 44,
        child: Align(
          alignment: crossAlign == CrossAxisAlignment.start
              ? Alignment.centerLeft
              : Alignment.centerRight,
          child: Container(
            width: 24, height: 2,
            decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(1)),
          ),
        ),
      );
    }

    final flag = ing.flag;

    return Column(
      crossAxisAlignment: crossAlign,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(ing.displayName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: textAlign,
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.3)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
              color: AppColors.riskBgColor(flag),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.riskColor(flag).withOpacity(0.3))),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 5, height: 5,
                decoration: BoxDecoration(
                    color: AppColors.riskColor(flag), shape: BoxShape.circle)),
            const SizedBox(width: 4),
            Text(_flagLabel(flag),
                style: TextStyle(
                    color: AppColors.riskTextColor(flag),
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4)),
          ]),
        ),
        const SizedBox(height: 2),
        const Text('tap for details',
            style: TextStyle(
                color: AppColors.textHint,
                fontSize: 9,
                fontStyle: FontStyle.italic)),
      ],
    );
  }

  String _flagLabel(String flag) {
    switch (flag) {
      case 'SAFE': return 'Safe';
      case 'CAUTION': return 'Caution';
      case 'ALLERGEN': return 'Allergen';
      default: return flag;
    }
  }
}

// ─────────────────────────────────────────────────────────
// SLIVER PERSISTENT HEADER DELEGATE
// ─────────────────────────────────────────────────────────

class _FilterTabDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  const _FilterTabDelegate({required this.child});

  @override double get minExtent => 50;
  @override double get maxExtent => 50;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) =>
      Container(
        decoration: BoxDecoration(
          color: AppColors.background,
          border: overlapsContent
              ? const Border(
                  bottom: BorderSide(color: AppColors.border, width: 1))
              : null,
        ),
        child: child,
      );

  @override
  bool shouldRebuild(_FilterTabDelegate old) => old.child != child;
}