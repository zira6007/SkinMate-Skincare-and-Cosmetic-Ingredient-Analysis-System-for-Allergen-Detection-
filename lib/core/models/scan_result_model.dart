import 'package:flutter/material.dart';
import 'package:skin_mate/core/constants/app_colors.dart';

// ─────────────────────────────────────────────────────────────
// ScanResultModel — unchanged
// ─────────────────────────────────────────────────────────────
class ScanResultModel {
  final String  scanResultID;
  final String  scanID;
  final String  ingredientID;
  final int     riskScore;
  final String  flag;
  final String? agentReasoning;
  final String? recommendation;
  final String? ingredientName;
  final String? ingredientInci;

  const ScanResultModel({
    required this.scanResultID,
    required this.scanID,
    required this.ingredientID,
    required this.riskScore,
    required this.flag,
    this.agentReasoning,
    this.recommendation,
    this.ingredientName,
    this.ingredientInci,
  });

  factory ScanResultModel.fromJson(Map<String, dynamic> json) {
    final ingredientMap = json['INGREDIENT'] as Map<String, dynamic>?;
    return ScanResultModel(
      scanResultID:   json['scanResultID']    as String? ?? '',
      scanID:         json['scanID']          as String? ?? '',
      ingredientID:   json['ingredientID']    as String? ?? '',
      riskScore:      (json['risk_score']     as num?    ?? 1).toInt(),
      flag:           json['flag']            as String? ?? 'SAFE',
      agentReasoning: json['agent_reasoning'] as String?,
      recommendation: json['recommendation']  as String?,
      ingredientName: ingredientMap?['common_name']          as String?
                      ?? json['common_name']                 as String?,
      ingredientInci: ingredientMap?['scientific_name_inci'] as String?
                      ?? json['scientific_name_inci']        as String?,
    );
  }

  static List<ScanResultModel> fromJsonList(List<dynamic> list) =>
      list.map((r) => ScanResultModel.fromJson(r as Map<String, dynamic>)).toList();

  bool   get isAllergen => flag.toUpperCase() == 'ALLERGEN';
  bool   get isCaution  => flag.toUpperCase() == 'CAUTION';
  bool   get isSafe     => flag.toUpperCase() == 'SAFE';

  String get displayName {
    if (ingredientName != null && ingredientName!.isNotEmpty) return ingredientName!;
    if (ingredientInci != null && ingredientInci!.isNotEmpty) return ingredientInci!;
    return ingredientID;
  }

  Color get flagColor   => AppColors.riskColor(flag);
  Color get flagBgColor => AppColors.riskBgColor(flag);

  @override
  String toString() => 'ScanResultModel($ingredientID: $flag score=$riskScore)';
}


// ─────────────────────────────────────────────────────────────
// ScanHistoryModel — rewritten, no product fields
// ─────────────────────────────────────────────────────────────
class ScanHistoryModel {
  final String  scanID;
  final String  userID;
  final DateTime? scannedAt;
  final String? scanMethod;
  final String? imageUrl;      // SCAN_HISTORY.image_url
  final String? ocrRawText;   // SCAN_HISTORY.ocr_raw_text (if you have it)
  final List<ScanResultModel> results;

  const ScanHistoryModel({
    required this.scanID,
    required this.userID,
    this.scannedAt,
    this.scanMethod,
    this.imageUrl,
    this.ocrRawText,
    this.results = const [],
  });

  factory ScanHistoryModel.fromJson(Map<String, dynamic> json) {
    final rawResults = json['SCAN_RESULT'] as List<dynamic>?;

    return ScanHistoryModel(
      scanID:     json['scanID']       as String? ?? '',
      userID:     json['userID']       as String? ?? '',
      scannedAt: json['scanned_at'] != null
    ? DateTime.parse(json['scanned_at']).toLocal()  // ← add .toLocal()
    : null,
      scanMethod: json['scan_method']  as String?,
      imageUrl:   json['image_url']    as String?,
      ocrRawText: json['ocr_raw_text'] as String?,
      results:    rawResults != null
                    ? ScanResultModel.fromJsonList(rawResults)
                    : [],
    );
  }

  static List<ScanHistoryModel> fromJsonList(List<dynamic> list) =>
      list.map((r) => ScanHistoryModel.fromJson(r as Map<String, dynamic>)).toList();

  // ── Computed ──────────────────────────────────────────
  String get overallFlag {
    if (results.any((r) => r.isAllergen)) return 'ALLERGEN';
    if (results.any((r) => r.isCaution))  return 'CAUTION';
    return 'SAFE';
  }

  int get allergenCount => results.where((r) => r.isAllergen).length;
  int get cautionCount  => results.where((r) => r.isCaution).length;

  /// Label shown on the card — falls back gracefully
  String get displayProductName {
    if (ocrRawText != null && ocrRawText!.isNotEmpty) {
      // Show a trimmed snippet of the OCR text as the title
      final snippet = ocrRawText!.replaceAll('\n', ' ').trim();
      return snippet.length > 60 ? '${snippet.substring(0, 60)}…' : snippet;
    }
    return isBarcodeMethod ? 'Barcode Scan' : 'Camera Scan';
  }

  /// Thumbnail shown on the card
  String? get displayImageUrl => imageUrl;

  bool get isBarcodeMethod => scanMethod?.toUpperCase() == 'BARCODE';

  @override
  String toString() => 'ScanHistoryModel($scanID: $overallFlag, ${results.length} results)';
}