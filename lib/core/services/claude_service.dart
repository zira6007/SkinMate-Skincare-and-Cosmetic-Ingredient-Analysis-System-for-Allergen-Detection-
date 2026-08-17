// lib/core/services/claude_service.dart
// ─────────────────────────────────────────────────────────────────────────────
// All Claude calls go through your Supabase Edge Function.
// The API key never leaves the server — Flutter just calls Supabase.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';
import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:skin_mate/core/services/supabase_service.dart';

// ── Result types ──────────────────────────────────────────────────────────────

enum IngredientCategory { safe, irritant, allergen }

class IngredientClassification {
  final String             name;
  final IngredientCategory category;
  final String             reason;
  final String?            skinTypeNote;

  const IngredientClassification({
    required this.name,
    required this.category,
    required this.reason,
    this.skinTypeNote,
  });

  String get flag {
    switch (category) {
      case IngredientCategory.allergen: return 'ALLERGEN';
      case IngredientCategory.irritant: return 'CAUTION';
      case IngredientCategory.safe:     return 'SAFE';
    }
  }

  int get defaultRiskScore {
    switch (category) {
      case IngredientCategory.allergen: return 80;
      case IngredientCategory.irritant: return 45;
      case IngredientCategory.safe:     return 5;
    }
  }
}

class OcrResult {
  final List<String> ingredientNames;
  final bool         found;

  const OcrResult({required this.ingredientNames, required this.found});
}

// ── Service ───────────────────────────────────────────────────────────────────

class ClaudeService {
  ClaudeService._();
  static final ClaudeService instance = ClaudeService._();

  // ── Compress image before sending (sharp text, manageable payload) ─────────
  Future<File> compressForOcr(File file) async {
    final dir  = await getTemporaryDirectory();
    final path = '${dir.path}/ocr_${DateTime.now().millisecondsSinceEpoch}.jpg';

    final result = await FlutterImageCompress.compressAndGetFile(
      file.path, path,
      quality:   97,
      minWidth:  1600,
      minHeight: 1600,
    );
    return result != null ? File(result.path) : file;
  }

  // ── Step 1: OCR — extract ingredient list from label image ────────────────
  Future<OcrResult> extractIngredients(File imageFile) async {
    final bytes       = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);

    final response = await SupabaseService.client.functions.invoke(
      'claude-proxy',
      body: {
        'action':      'ocr',
        'base64Image': base64Image,
      },
    );

    _checkEdgeFunctionResponse(response);

    final data  = response.data as Map<String, dynamic>;
    final inner = data['data'] as Map<String, dynamic>;

    final found              = (inner['found'] as bool?) ?? false;
    final List<dynamic> raw  = (inner['ingredients'] as List?) ?? [];
    final ingredients        = raw
        .map((e) => (e as String).trim())
        .where((s) => s.isNotEmpty)
        .toList();

    return OcrResult(
      ingredientNames: ingredients,
      found:           found && ingredients.isNotEmpty,
    );
  }

  // ── Step 2: Classify ingredients (safe / irritant / allergen) ─────────────
  Future<List<IngredientClassification>> classifyIngredients({
    required List<String> ingredientNames,
    required String       skinType,
    required String       skinConcern,
  }) async {
    if (ingredientNames.isEmpty) return [];

    final response = await SupabaseService.client.functions.invoke(
      'claude-proxy',
      body: {
        'action':      'classify',
        'ingredients': ingredientNames,
        'skinType':    skinType,
        'skinConcern': skinConcern,
      },
    );

    _checkEdgeFunctionResponse(response);

    final data  = response.data as Map<String, dynamic>;
    final inner = data['data'] as List<dynamic>;

    return inner.map((item) {
      final map    = item as Map<String, dynamic>;
      final catStr = ((map['category'] as String?) ?? 'safe').toLowerCase();

      final category = catStr == 'allergen'
          ? IngredientCategory.allergen
          : catStr == 'irritant'
              ? IngredientCategory.irritant
              : IngredientCategory.safe;

      return IngredientClassification(
        name:         (map['name']          as String? ?? '').trim(),
        category:     category,
        reason:       (map['reason']        as String? ?? '').trim(),
        skinTypeNote: map['skin_type_note'] as String?,
      );
    }).toList();
  }

  // ── Step 4: Generate personalised plain-text explanation ──────────────────
  //
  // Accepts scanner_screen's native types directly so the call site needs no
  // manual conversion.  The named parameters mirror the scanner's local fields:
  //   ingredientNames    — full detected list (count derived internally)
  //   classifications    — agentic IngredientClassification list
  //   flagged            — list of _IngredientRisk-like maps OR typed objects
  //   totalScore / level — rule-engine output
  //   skinType / skinConcern — user profile
  //
  // Two overloads are provided so both call sites work without casting:
  //   • generateExplanation(...)         — typed, used by scanner_screen
  //   • generateExplanationFromMaps(...) — map-based, kept for other callers
  // ──────────────────────────────────────────────────────────────────────────
  Future<String> generateExplanation({
    required List<String>                   ingredientNames,
    required List<IngredientClassification> classifications,
    required List<_IngredientRiskLike>      flagged,
    required int                            totalScore,
    required String                         levelLabel,
    required String                         skinType,
    required String                         skinConcern,
  }) async {
    final allergens = classifications
        .where((c) => c.category == IngredientCategory.allergen)
        .map((c) => c.name)
        .toList();

    final irritants = classifications
        .where((c) => c.category == IngredientCategory.irritant)
        .map((c) => c.name)
        .toList();

    final flaggedSummary = flagged.isEmpty
        ? 'None detected.'
        : flagged.map((f) {
            final note = f.interactionNote != null ? ' — ${f.interactionNote}' : '';
            return '• ${f.ingredientName} (score: ${f.riskScore})$note';
          }).join('\n');

    return _invokeExplain(
      ingredientCount: ingredientNames.length,
      allergens:       allergens,
      irritants:       irritants,
      flaggedSummary:  flaggedSummary,
      totalScore:      totalScore,
      levelLabel:      levelLabel,
      skinType:        skinType,
      skinConcern:     skinConcern,
    );
  }

  /// Map-based variant — kept for callers that already hold
  /// `List<Map<String, dynamic>>` flagged ingredients.
  Future<String> generateExplanationFromMaps({
    required int                            ingredientCount,
    required List<IngredientClassification> classifications,
    required List<Map<String, dynamic>>     flaggedIngredients,
    required int                            totalScore,
    required String                         levelLabel,
    required String                         skinType,
    required String                         skinConcern,
  }) async {
    final allergens = classifications
        .where((c) => c.category == IngredientCategory.allergen)
        .map((c) => c.name)
        .toList();

    final irritants = classifications
        .where((c) => c.category == IngredientCategory.irritant)
        .map((c) => c.name)
        .toList();

    final flaggedSummary = flaggedIngredients.isEmpty
        ? 'None detected.'
        : flaggedIngredients.map((f) {
            final note = (f['interactionNote'] as String?) != null
                ? ' — ${f['interactionNote']}'
                : '';
            return '• ${f['ingredientName']} (score: ${f['riskScore']})$note';
          }).join('\n');

    return _invokeExplain(
      ingredientCount: ingredientCount,
      allergens:       allergens,
      irritants:       irritants,
      flaggedSummary:  flaggedSummary,
      totalScore:      totalScore,
      levelLabel:      levelLabel,
      skinType:        skinType,
      skinConcern:     skinConcern,
    );
  }

  // ── Shared Edge Function invocation for "explain" ─────────────────────────
  Future<String> _invokeExplain({
    required int         ingredientCount,
    required List<String> allergens,
    required List<String> irritants,
    required String      flaggedSummary,
    required int         totalScore,
    required String      levelLabel,
    required String      skinType,
    required String      skinConcern,
  }) async {
    final response = await SupabaseService.client.functions.invoke(
      'claude-proxy',
      body: {
        'action':          'explain',
        'ingredientCount': ingredientCount,
        'allergens':       allergens,
        'irritants':       irritants,
        'flaggedSummary':  flaggedSummary,
        'totalScore':      totalScore,
        'levelLabel':      levelLabel,
        'skinType':        skinType,
        'skinConcern':     skinConcern,
      },
    );

    _checkEdgeFunctionResponse(response);

    final data = response.data as Map<String, dynamic>;
    return (data['data'] as String?) ?? '';
  }

  // ── Throw a clean error if the Edge Function returned a failure ────────────
  void _checkEdgeFunctionResponse(dynamic response) {
    final data = response.data as Map<String, dynamic>?;
    if (data == null || data['ok'] != true) {
      final msg = data?['error'] as String? ?? 'Claude service error. Please try again.';
      throw Exception(msg);
    }
  }
}

// ── Thin interface so generateExplanation() accepts scanner_screen's
//    _IngredientRisk without a hard dependency on scanner_screen.dart ─────────
abstract class _IngredientRiskLike {
  String  get ingredientName;
  int     get riskScore;
  String? get interactionNote;
}