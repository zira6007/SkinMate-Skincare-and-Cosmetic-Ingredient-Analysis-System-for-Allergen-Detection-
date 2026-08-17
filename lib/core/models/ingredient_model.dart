import 'package:flutter/material.dart';
import 'package:skin_mate/core/constants/app_colors.dart';

class IngredientModel {

  // ── Fields ────────────────────────────────────────────

  /// Primary key — e.g. "ING001"
  final String ingredientID;

  /// INCI scientific name — e.g. "Sodium Hyaluronate"
  final String inci;

  /// Common/marketing name — e.g. "Hyaluronic Acid"
  final String? commonName;

  /// Risk classification — "SAFE", "CAUTION", or "ALLERGEN"
  final String riskLevel;

  /// What this ingredient does — e.g. "Humectant, draws moisture"
  final String? purposeText;

  /// Warning text — e.g. "May sting on broken skin"
  final String? warningExplanation;

  /// Whether restricted by EU Cosmetics Regulation (stored as text in DB)
  final String? euRestricted;

  /// Data source — e.g. "PubChem CID 753", "EWG Score 1"
  final String? source;

  /// Skin types or concerns this ingredient affects
  /// e.g. "Sensitive, Acne-Prone"
  final String? skinTypeConcern;

  /// Who created this record — e.g. admin user ID or name
  final String? createdBy;

  /// When this record was last updated
  final DateTime? updatedAt;

  // ── Constructor ───────────────────────────────────────
  const IngredientModel({
    required this.ingredientID,
    required this.inci,
    required this.riskLevel,
    this.commonName,
    this.purposeText,
    this.warningExplanation,
    this.euRestricted,
    this.source,
    this.skinTypeConcern,
    this.createdBy,
    this.updatedAt,
  });

  // ── fromJson ──────────────────────────────────────────
  factory IngredientModel.fromJson(Map<String, dynamic> json) {
    return IngredientModel(
      ingredientID:       json['ingredientID']         as String? ?? '',
      inci:               json['scientific_name_inci'] as String? ?? '',
      commonName:         json['common_name']          as String?,
      riskLevel:          json['risk_level']           as String? ?? 'SAFE',
      purposeText:        json['purpose_text']         as String?,
      warningExplanation: json['warning_explanation']  as String?,
      euRestricted:       json['eu_restricted']        as String?,
      source:             json['source']               as String?,
      skinTypeConcern:    json['skin_type_concern']    as String?,
      createdBy:          json['created_by']           as String?,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  // ── fromJsonList ──────────────────────────────────────
  static List<IngredientModel> fromJsonList(List<dynamic> list) {
    return list
        .map((row) => IngredientModel.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  // ── toJson ────────────────────────────────────────────
  // Used when admin adds or edits an ingredient
  Map<String, dynamic> toJson() {
    return {
      'ingredientID':         ingredientID,
      'scientific_name_inci': inci,
      'common_name':          commonName,
      'risk_level':           riskLevel,
      'purpose_text':         purposeText,
      'warning_explanation':  warningExplanation,
      'eu_restricted':        euRestricted,
      'source':               source,
      'skin_type_concern':    skinTypeConcern,
      'created_by':           createdBy,
      'updated_at':           updatedAt?.toIso8601String(),
    };
  }

  // ── Computed properties ───────────────────────────────

  /// Display name — common name if available, else INCI name
  String get displayName => commonName?.isNotEmpty == true
      ? commonName!
      : inci;

  /// True if this ingredient is classified as an allergen
  bool get isAllergen => riskLevel.toUpperCase() == 'ALLERGEN';

  /// True if this ingredient needs caution
  bool get isCaution  => riskLevel.toUpperCase() == 'CAUTION';

  /// True if this ingredient is safe
  bool get isSafe     => riskLevel.toUpperCase() == 'SAFE';

  /// Colour matching the risk level — from AppColors
  Color get riskColor => AppColors.riskColor(riskLevel);

  /// Background colour for risk badges
  Color get riskBgColor => AppColors.riskBgColor(riskLevel);

  /// Text colour for risk badges
  Color get riskTextColor => AppColors.riskTextColor(riskLevel);

  Null get sourceRef => null;

  @override
  String toString() =>
      'IngredientModel($ingredientID: $inci [$riskLevel])';
}


// ─────────────────────────────────────────────────────────
// INGREDIENT RISK MODEL
// Maps an INGREDIENT_SKIN_RISK table row.
// This is the RAG knowledge base — links ingredients to
// specific skin types with risk scores and explanations.
//
// Used by: scan result screen, product detail screen,
//          Flask agent to retrieve risk context
// ─────────────────────────────────────────────────────────
class IngredientRiskModel {

  final String ingredientID;

  /// Skin type this risk applies to — e.g. "Sensitive", "Oily"
  final String skinType;

  /// Skin concern — e.g. "Acne-Prone", "Rosacea"
  final String? skinConcern;

  /// Risk score 1-5
  ///   1 = beneficial / no risk
  ///   2 = low risk
  ///   3 = moderate risk / use with care
  ///   4 = high risk / likely to cause reaction
  ///   5 = avoid / banned or severe allergen
  final int riskScore;

  /// Agent reasoning — why this ingredient is risky for this skin type
  /// e.g. "Glycolic acid is photosensitising on sensitive skin at >5%"
  final String? interactionNote;

  /// What to do — e.g. "Use with SPF, patch test first"
  final String? recommendation;

  const IngredientRiskModel({
    required this.ingredientID,
    required this.skinType,
    required this.riskScore,
    this.skinConcern,
    this.interactionNote,
    this.recommendation,
  });

  factory IngredientRiskModel.fromJson(Map<String, dynamic> json) {
    return IngredientRiskModel(
      ingredientID:    json['ingredientID']     as String? ?? '',
      skinType:        json['skin_type']        as String? ?? '',
      skinConcern:     json['skin_concern']     as String?,
      riskScore:       (json['risk_score']      as num?    ?? 1).toInt(),
      interactionNote: json['interaction_note'] as String?,
      recommendation:  json['recommendation']   as String?,
    );
  }

  /// Flag string derived from risk score
  String get flag {
    if (riskScore >= 4) return 'ALLERGEN';
    if (riskScore == 3) return 'CAUTION';
    return 'SAFE';
  }

  /// Colour for this risk score
  Color get color => AppColors.riskScoreColor(riskScore);

  @override
  String toString() =>
      'IngredientRiskModel($ingredientID x $skinType: score=$riskScore)';
}