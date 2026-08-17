// ignore_for_file: deprecated_member_use

import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:skin_mate/features/user/scanner/scan_result_screen.dart';
import 'package:uuid/uuid.dart';
import 'package:skin_mate/core/services/supabase_service.dart';
import 'package:skin_mate/core/constants/app_colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum RiskLevel { low, moderate, high }

enum IngredientCategory { safe, irritant, allergen }

RiskLevel _scoreToLevel(int score) {
  if (score <= 30) return RiskLevel.low;
  if (score <= 70) return RiskLevel.moderate;
  return RiskLevel.high;
}

String _levelLabel(RiskLevel level) {
  switch (level) {
    case RiskLevel.low:      return 'Low Risk';
    case RiskLevel.moderate: return 'Moderate Risk';
    case RiskLevel.high:     return 'High Risk';
  }
}

Color _levelColor(RiskLevel level) {
  switch (level) {
    case RiskLevel.low:      return AppColors.safeColor;
    case RiskLevel.moderate: return AppColors.cautionColor;
    case RiskLevel.high:     return AppColors.allergenColor;
  }
}

// ─── Data classes ─────────────────────────────────────────────────────────────

class _IngredientClassification {
  final String             name;
  final IngredientCategory category;
  final String             reason;
  final String?            skinTypeNote;

  const _IngredientClassification({
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

class _IngredientRisk {
  final String  ingredientName;
  final int     riskScore;
  final String? skinType;
  final String? skinConcern;
  final String? interactionNote;
  final String? recommendation;

  const _IngredientRisk({
    required this.ingredientName,
    required this.riskScore,
    this.skinType,
    this.skinConcern,
    this.interactionNote,
    this.recommendation,
  });
}

class _RiskAssessment {
  final int                             totalScore;
  final RiskLevel                       level;
  final List<_IngredientRisk>           flaggedIngredients;
  final List<_IngredientClassification> classifications;
  final String                          claudeExplanation;

  const _RiskAssessment({
    required this.totalScore,
    required this.level,
    required this.flaggedIngredients,
    required this.classifications,
    required this.claudeExplanation,
  });
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen>
    with SingleTickerProviderStateMixin {

  bool             _isProcessing  = false;
  String           _statusText    = '';
  String?          _errorMessage;
  File?            _pickedImage;
  _RiskAssessment? _lastAssessment;

  late AnimationController _pulseController;

  final _picker         = ImagePicker();
  final _barcodeScanner = BarcodeScanner();
  final _uuid           = const Uuid();

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _barcodeScanner.close();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────
  // IMAGE PICKER
  // ─────────────────────────────────────────────────────
  Future<void> _pickImage(ImageSource source) async {
    setState(() {
      _errorMessage   = null;
      _pickedImage    = null;
      _lastAssessment = null;
    });

    final picked = await _picker.pickImage(source: source, imageQuality: 90);
    if (picked == null) return;

    final file = File(picked.path);
    setState(() => _pickedImage = file);
    await _processScan(file);
  }

  // ─────────────────────────────────────────────────────
  // EDGE FUNCTION CALLER
  // ─────────────────────────────────────────────────────
  Future<Map<String, dynamic>> _callEdgeFunction(
    Map<String, dynamic> body,
  ) async {
    final response = await SupabaseService.client.functions.invoke(
      'claude-proxy',
      body: body,
    );

    final data = response.data as Map<String, dynamic>?;

    if (data == null || data['ok'] != true) {
      final msg = data?['error'] as String?
          ?? 'Claude service error. Please try again.';
      throw Exception(msg);
    }

    return data['data'] as Map<String, dynamic>? ?? {};
  }

  // ─────────────────────────────────────────────────────
  // UPLOAD IMAGE TO SUPABASE STORAGE
  // ─────────────────────────────────────────────────────
  Future<String?> _uploadScanImage(File imageFile, String scanId) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final path  = 'scans/$scanId.jpg';

      await SupabaseService.client.storage
          .from('scan-images')
          .uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert:      true,
            ),
          );

      return SupabaseService.client.storage
          .from('scan-images')
          .getPublicUrl(path);
    } catch (e) {
      // Non-fatal — scan still saves, just without a thumbnail
      debugPrint('Image upload failed: $e');
      return null;
    }
  }

  // ─────────────────────────────────────────────────────
  // MAIN PIPELINE
  // ─────────────────────────────────────────────────────
  Future<void> _processScan(File imageFile) async {
    setState(() {
      _isProcessing = true;
      _statusText   = 'Scanning product...';
    });

    try {
      final userId = SupabaseService.client.auth.currentUser?.id;
      if (userId == null) throw Exception('No user session');

      final inputImage = InputImage.fromFile(imageFile);
      final barcodes   = await _barcodeScanner.processImage(inputImage);

      String?      productId;
      String       scanMethod      = 'ocr';
      List<String> ingredientNames = [];
      String       claudeText      = '';
      List<_IngredientClassification> classifications = [];

      // Load user skin profile
      _setStatus('Loading your skin profile...');
      final userProfile = await SupabaseService.client
          .from('RESULT_SKIN_PROFILE')
          .select('skin_type, skin_subtype')
          .eq('userID', userId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      final userSkinType    = (userProfile?['skin_type']    as String?) ?? '';
      final userSkinConcern = (userProfile?['skin_subtype'] as String?) ?? '';

      // Check if barcode matches a product in DB
      if (barcodes.isNotEmpty) {
        final code = barcodes.first.rawValue;
        if (code != null) {
  debugPrint('Scanned barcode: $code');
  final result = await SupabaseService.client
      .from('PRODUCT')
      .select('productID')
      .eq('barcode', code)
      .maybeSingle();
  debugPrint('Match found: $result');

          if (result != null) {
            productId  = result['productID'] as String;
            scanMethod = 'barcode';
          }
        }
      }

      // ── BARCODE PATH ───────────────────────────────────────────────────────
      if (productId != null) {
        _setStatus('Fetching ingredient data...');
        final rows = await SupabaseService.client
            .from('PRODUCT_INGREDIENT')
            .select('ingredientID, INGREDIENT(scientific_name_inci, common_name)')
            .eq('productID', productId);

        ingredientNames = (rows as List)
            .map((r) =>
                (r['INGREDIENT']?['common_name'] as String?)
                ?? (r['INGREDIENT']?['scientific_name_inci'] as String?)
                ?? '')
            .where((n) => n.isNotEmpty)
            .toList();

        _setStatus('Classifying ingredients with AI...');
        classifications = await _agentClassifyIngredients(
          ingredientNames: ingredientNames,
          skinType:        userSkinType,
          skinConcern:     userSkinConcern,
        );

        _setStatus('Calculating risk score...');
        final ruleResult = await _runRuleEngine(
          ingredientNames: ingredientNames,
          classifications: classifications,
          userSkinType:    userSkinType,
          userSkinConcern: userSkinConcern,
        );
        setState(() => _lastAssessment = ruleResult);

        _setStatus('Generating personalised explanation...');
        claudeText = await _callExplain(
          ingredientNames: ingredientNames,
          classifications: classifications,
          flagged:         ruleResult.flaggedIngredients,
          totalScore:      ruleResult.totalScore,
          level:           ruleResult.level,
          skinType:        userSkinType,
          skinConcern:     userSkinConcern,
        );

        final finalAssessment = _RiskAssessment(
          totalScore:         ruleResult.totalScore,
          level:              ruleResult.level,
          flaggedIngredients: ruleResult.flaggedIngredients,
          classifications:    classifications,
          claudeExplanation:  claudeText,
        );
        setState(() => _lastAssessment = finalAssessment);

        await _saveAndNavigate(
          userId:             userId,
          scanId:             _uuid.v4(),
          scanMethod:         scanMethod,
          assessment:         finalAssessment,
          allIngredientNames: ingredientNames,
        );

      // ── OCR PATH ───────────────────────────────────────────────────────────
      } else {
        _setStatus('Reading ingredient label...');
        final compressed = await _compressImage(imageFile);

        final ocrResult = await _callOcr(compressed);

        if (!ocrResult['found'] || (ocrResult['ingredients'] as List).isEmpty) {
          throw Exception(
            'Could not read the ingredient list from this image.\n\n'
            'Tips for a better scan:\n'
            '• Lay the product flat and photograph it from directly above\n'
            '• Make sure the ingredient text fills most of the frame\n'
            '• Use bright, even lighting — avoid shadows and glare\n'
            '• Keep the camera still until the image is sharp\n'
            '• If the label is curved, gently flatten it while shooting',
          );
        }

        ingredientNames = List<String>.from(ocrResult['ingredients'] as List);

        _setStatus('Classifying ingredients with AI...');
        classifications = await _agentClassifyIngredients(
          ingredientNames: ingredientNames,
          skinType:        userSkinType,
          skinConcern:     userSkinConcern,
        );

        _setStatus('Calculating risk score...');
        final ruleResult = await _runRuleEngine(
          ingredientNames: ingredientNames,
          classifications: classifications,
          userSkinType:    userSkinType,
          userSkinConcern: userSkinConcern,
        );

        _setStatus('Generating personalised explanation...');
        claudeText = await _callExplain(
          ingredientNames: ingredientNames,
          classifications: classifications,
          flagged:         ruleResult.flaggedIngredients,
          totalScore:      ruleResult.totalScore,
          level:           ruleResult.level,
          skinType:        userSkinType,
          skinConcern:     userSkinConcern,
        );

        final finalAssessment = _RiskAssessment(
          totalScore:         ruleResult.totalScore,
          level:              ruleResult.level,
          flaggedIngredients: ruleResult.flaggedIngredients,
          classifications:    classifications,
          claudeExplanation:  claudeText,
        );
        setState(() => _lastAssessment = finalAssessment);

        await _saveAndNavigate(
          userId:             userId,
          scanId:             _uuid.v4(),
          scanMethod:         scanMethod,
          assessment:         finalAssessment,
          allIngredientNames: ingredientNames,
        );
      }

    } catch (e) {
      setState(() {
        _isProcessing = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  // ─────────────────────────────────────────────────────
  // STEP 1 — OCR
  // ─────────────────────────────────────────────────────
  Future<Map<String, dynamic>> _callOcr(File imageFile) async {
    final bytes       = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);

    return await _callEdgeFunction({
      'action':      'ocr',
      'base64Image': base64Image,
    });
  }

  // ─────────────────────────────────────────────────────
  // STEP 2 — AGENTIC CLASSIFICATION
  // ─────────────────────────────────────────────────────
  Future<List<_IngredientClassification>> _agentClassifyIngredients({
    required List<String> ingredientNames,
    required String       skinType,
    required String       skinConcern,
  }) async {
    if (ingredientNames.isEmpty) return [];

    final result = await _callEdgeFunction({
      'action':      'classify',
      'ingredients': ingredientNames,
      'skinType':    skinType,
      'skinConcern': skinConcern,
    });

    final rawList = result['classifications'] as List? ?? [];

    return rawList.map((item) {
      final map    = item as Map<String, dynamic>;
      final catStr = ((map['category'] as String?) ?? 'safe').toLowerCase();

      final category = catStr == 'allergen'
          ? IngredientCategory.allergen
          : catStr == 'irritant'
              ? IngredientCategory.irritant
              : IngredientCategory.safe;

      return _IngredientClassification(
        name:         (map['name']          as String? ?? '').trim(),
        category:     category,
        reason:       (map['reason']        as String? ?? '').trim(),
        skinTypeNote: map['skin_type_note'] as String?,
      );
    }).toList();
  }

  // ─────────────────────────────────────────────────────
  // STEP 3 — RULE ENGINE
  // ─────────────────────────────────────────────────────
  Future<_RiskAssessment> _runRuleEngine({
    required List<String>                    ingredientNames,
    required List<_IngredientClassification> classifications,
    required String                          userSkinType,
    required String                          userSkinConcern,
  }) async {
    if (ingredientNames.isEmpty) {
      return _RiskAssessment(
        totalScore:         0,
        level:              RiskLevel.low,
        flaggedIngredients: [],
        classifications:    classifications,
        claudeExplanation:  '',
      );
    }

    final byCommon = await SupabaseService.client
        .from('INGREDIENT')
        .select('ingredientID, scientific_name_inci, common_name')
        .inFilter('common_name', ingredientNames);

    final byScientific = await SupabaseService.client
        .from('INGREDIENT')
        .select('ingredientID, scientific_name_inci, common_name')
        .inFilter('scientific_name_inci', ingredientNames);

    final seen    = <String>{};
    final allRows = <Map<String, dynamic>>[];
    for (final row in [...(byCommon as List), ...(byScientific as List)]) {
      final id = row['ingredientID'] as String;
      if (seen.add(id)) allRows.add(row as Map<String, dynamic>);
    }

    final ingredientIds = allRows.map((r) => r['ingredientID'] as String).toList();

    final flagged = <_IngredientRisk>[];
    int totalRaw  = 0;

    if (ingredientIds.isNotEmpty) {
      var query = SupabaseService.client
          .from('INGREDIENT_SKIN_RISK')
          .select(
            'riskID, ingredientID, skin_type, skin_concern, '
            'risk_score, interaction_note, recommendation, '
            'INGREDIENT(scientific_name_inci, common_name)',
          )
          .inFilter('ingredientID', ingredientIds);

      if (userSkinType.isNotEmpty) {
        query = query.or('skin_type.eq.$userSkinType,skin_type.is.null');
      }

      final riskRows = await query;

      for (final row in (riskRows as List)) {
        final dbScore = (row['risk_score'] as int?) ?? 0;
        if (dbScore <= 0) continue;

        final name =
            (row['INGREDIENT']?['common_name']             as String?)
            ?? (row['INGREDIENT']?['scientific_name_inci'] as String?)
            ?? 'Unknown';

        flagged.add(_IngredientRisk(
          ingredientName:  name,
          riskScore:       dbScore,
          skinType:        row['skin_type']        as String?,
          skinConcern:     row['skin_concern']     as String?,
          interactionNote: row['interaction_note'] as String?,
          recommendation:  row['recommendation']   as String?,
        ));
        totalRaw += dbScore;
      }
    }

    final dbFlaggedNames =
        flagged.map((f) => f.ingredientName.toLowerCase()).toSet();

    for (final c in classifications) {
      if (c.category == IngredientCategory.safe) continue;
      if (dbFlaggedNames.contains(c.name.toLowerCase())) continue;

      flagged.add(_IngredientRisk(
        ingredientName:  c.name,
        riskScore:       c.defaultRiskScore,
        interactionNote: c.reason,
        recommendation:  c.skinTypeNote,
      ));
      totalRaw += c.defaultRiskScore;
    }

    return _RiskAssessment(
      totalScore:         totalRaw.clamp(0, 100),
      level:              _scoreToLevel(totalRaw.clamp(0, 100)),
      flaggedIngredients: flagged,
      classifications:    classifications,
      claudeExplanation:  '',
    );
  }

  // ─────────────────────────────────────────────────────
  // STEP 4 — PERSONALISED EXPLANATION
  // ─────────────────────────────────────────────────────
  Future<String> _callExplain({
    required List<String>                    ingredientNames,
    required List<_IngredientClassification> classifications,
    required List<_IngredientRisk>           flagged,
    required int                             totalScore,
    required RiskLevel                       level,
    required String                          skinType,
    required String                          skinConcern,
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
            final note = f.interactionNote != null
                ? ' — ${f.interactionNote}'
                : '';
            return '• ${f.ingredientName} (score: ${f.riskScore})$note';
          }).join('\n');

    final result = await _callEdgeFunction({
      'action':          'explain',
      'ingredientCount': ingredientNames.length,
      'allergens':       allergens,
      'irritants':       irritants,
      'flaggedSummary':  flaggedSummary,
      'totalScore':      totalScore,
      'levelLabel':      _levelLabel(level),
      'skinType':        skinType,
      'skinConcern':     skinConcern,
    });

    return (result['explanation'] as String?) ?? '';
  }

  // ─────────────────────────────────────────────────────
  // SAVE RESULTS + NAVIGATE
  // ─────────────────────────────────────────────────────
  Future<void> _saveAndNavigate({
    required String          userId,
    required String          scanId,
    required String          scanMethod,
    required _RiskAssessment assessment,
    required List<String>    allIngredientNames,
  }) async {
    _setStatus('Saving results...');

    // Upload scanned image to storage
    String? imageUrl;
    if (_pickedImage != null) {
      _setStatus('Uploading scan image...');
      imageUrl = await _uploadScanImage(_pickedImage!, scanId);
    }

    await SupabaseService.client.from('SCAN_HISTORY').insert({
      'scanID':      scanId,
      'userID':      userId,
      'scan_method': scanMethod,
      'image_url':   imageUrl,      // ✅ real URL now
      'scanned_at':  DateTime.now().toUtc().toIso8601String(),
      'risk_score':  assessment.totalScore,
      'risk_level':  _levelLabel(assessment.level),
      'ai_result':   assessment.claudeExplanation,
    });

    _setStatus('Saving ingredient results...');

    final byCommon = await SupabaseService.client
        .from('INGREDIENT')
        .select('ingredientID, common_name, scientific_name_inci')
        .inFilter('common_name', allIngredientNames);

    final byScientific = await SupabaseService.client
        .from('INGREDIENT')
        .select('ingredientID, common_name, scientific_name_inci')
        .inFilter('scientific_name_inci', allIngredientNames);

    final Map<String, String> nameToId = {};
    for (final row in [...(byCommon as List), ...(byScientific as List)]) {
      final id = row['ingredientID'] as String;
      if (row['common_name'] != null) {
        nameToId[(row['common_name'] as String).toLowerCase()] = id;
      }
      if (row['scientific_name_inci'] != null) {
        nameToId[(row['scientific_name_inci'] as String).toLowerCase()] = id;
      }
    }

    final Map<String, _IngredientClassification> classMap = {
      for (final c in assessment.classifications) c.name.toLowerCase(): c,
    };

    final Map<String, _IngredientRisk> flaggedMap = {
      for (final f in assessment.flaggedIngredients)
        f.ingredientName.toLowerCase(): f,
    };

    final scanResultRows = <Map<String, dynamic>>[];
    for (final name in allIngredientNames) {
      final ingredientId = nameToId[name.toLowerCase()];
      if (ingredientId == null) continue;

      final flaggedItem    = flaggedMap[name.toLowerCase()];
      final classification = classMap[name.toLowerCase()];

      final String flag;
      final double riskScore;

      if (flaggedItem != null) {
        riskScore = flaggedItem.riskScore.toDouble();
        flag = riskScore >= 70
            ? 'ALLERGEN'
            : riskScore >= 40
                ? 'CAUTION'
                : 'SAFE';
      } else if (classification != null) {
        flag      = classification.flag;
        riskScore = classification.defaultRiskScore.toDouble();
      } else {
        flag      = 'SAFE';
        riskScore = 0;
      }

      scanResultRows.add({
        'scanID':          scanId,
        'ingredientID':    ingredientId,
        'risk_score':      riskScore,
        'flag':            flag,
        'agent_reasoning': flaggedItem?.interactionNote
                        ?? classification?.reason,
      });
    }

    if (scanResultRows.isNotEmpty) {
      await SupabaseService.client
          .from('SCAN_RESULT')
          .insert(scanResultRows);
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ScanResultScreen(scanId: scanId)),
    );
  }

  // ─────────────────────────────────────────────────────
  // IMAGE COMPRESSION
  // ─────────────────────────────────────────────────────
  Future<File> _compressImage(File file) async {
    final dir  = await getTemporaryDirectory();
    final path = '${dir.path}/scan_${DateTime.now().millisecondsSinceEpoch}.jpg';

    final result = await FlutterImageCompress.compressAndGetFile(
      file.path,
      path,
      quality:   97,
      minWidth:  1600,
      minHeight: 1600,
    );
    return result != null ? File(result.path) : file;
  }

  void _setStatus(String text) => setState(() => _statusText = text);

  // ─────────────────────────────────────────────────────
  // HOW TO SCAN DIALOG
  // ─────────────────────────────────────────────────────
  void _showHowToScan() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 22),
                  const SizedBox(width: 10),
                  Text('How to Scan',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                ],
              ),
              const SizedBox(height: 16),
              _howToStep(
                icon:  Icons.qr_code_scanner_rounded,
                title: 'Scan a Barcode',
                desc:  'Point the camera at the product barcode and hold steady — it is detected automatically.',
              ),
              const SizedBox(height: 14),
              _howToStep(
                icon:  Icons.list_alt_rounded,
                title: 'Capture the Ingredient Label',
                desc:  'No barcode? Take a clear, well-lit photo of the ingredient list on the packaging.',
              ),
              const SizedBox(height: 14),
              _howToStep(
                icon:  Icons.photo_library_rounded,
                title: 'Upload from Gallery',
                desc:  'Already have a photo? Tap "Upload From Gallery" and choose an image of the product label.',
              ),
              const SizedBox(height: 14),
              _howToStep(
                icon:  Icons.shield_outlined,
                title: 'Personalised Risk Assessment',
                desc:  'SkinMate checks every ingredient against your skin type and concern, calculates a risk score (0–100), then provides an AI-powered explanation tailored to you.',
              ),
              const SizedBox(height: 14),
              _howToStep(
                icon:  Icons.tips_and_updates_rounded,
                title: 'Tips for Best Results',
                desc:  'Use good lighting, keep the text sharp and in frame, and avoid glare or shadows on shiny packaging.',
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Got it',
                    style: TextStyle(
                        color:      AppColors.textWhite,
                        fontSize:   15,
                        fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _howToStep({
    required IconData icon,
    required String   title,
    required String   desc,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color:        AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
              const SizedBox(height: 2),
              Text(desc,
                style: TextStyle(fontSize: 12,
                    color: AppColors.textSecondary, height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _isProcessing ? _buildProcessingView() : _buildScanView(),
      ),
    );
  }

  Widget _buildProcessingView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(height: 24),
            Text(_statusText,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize:   15,
                  fontWeight: FontWeight.w600,
                  color:      AppColors.textPrimary)),
            const SizedBox(height: 8),
            Text('Please wait…',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            if (_lastAssessment != null) ...[
              const SizedBox(height: 32),
              _buildRiskBadge(_lastAssessment!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRiskBadge(_RiskAssessment a) {
    final color = _levelColor(a.level);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color:        color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shield_outlined, color: color, size: 22),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_levelLabel(a.level),
                style: TextStyle(
                    fontSize:   14,
                    fontWeight: FontWeight.w700,
                    color:      color)),
              Text('Score: ${a.totalScore} / 100',
                style: TextStyle(fontSize: 12, color: color.withOpacity(0.8))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScanView() {
    return Column(
      children: [
        Expanded(
          child: Container(
            color: AppColors.background,
            child: Center(
              child: Container(
                margin: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                decoration: BoxDecoration(
                  color:        AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(20),
                ),
                clipBehavior: Clip.antiAlias,
                child: _pickedImage != null
                    ? Image.file(_pickedImage!,
                        fit:    BoxFit.cover,
                        width:  double.infinity,
                        height: double.infinity)
                    : const SizedBox.expand(),
              ),
            ),
          ),
        ),
        Container(
          color: AppColors.surface,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Scan The Product',
                            style: TextStyle(
                                fontSize:   22,
                                fontWeight: FontWeight.w800,
                                color:      AppColors.textPrimary)),
                          const SizedBox(height: 4),
                          Text('Point your camera at the product and capture it.',
                            style: TextStyle(
                                fontSize: 13,
                                color:    AppColors.textSecondary,
                                height:   1.4)),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.maybePop(context),
                      child: Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                            color: AppColors.divider,
                            shape: BoxShape.circle),
                        child: Icon(Icons.close_rounded,
                            size: 18, color: AppColors.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (_errorMessage != null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:        AppColors.allergenBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.allergenColor.withOpacity(0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.error_outline_rounded,
                            color: AppColors.allergenColor, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_errorMessage!,
                            style: TextStyle(
                                color:    AppColors.allergenText,
                                fontSize: 12,
                                height:   1.4)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: GestureDetector(
                  onTap: () => _pickImage(ImageSource.gallery),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color:        AppColors.secondaryLight,
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: Text('Upload From Gallery',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize:   15,
                          fontWeight: FontWeight.w600,
                          color:      AppColors.textPrimary)),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(width: 36),
                    GestureDetector(
                      onTap: () => _pickImage(ImageSource.camera),
                      child: Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(
                          shape:  BoxShape.circle,
                          border: Border.all(
                              color: AppColors.border, width: 1.5),
                        ),
                        child: Icon(Icons.barcode_reader,
                            size: 22, color: AppColors.textPrimary),
                      ),
                    ),
                    GestureDetector(
                      onTap: _showHowToScan,
                      child: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          shape:  BoxShape.circle,
                          border: Border.all(
                              color: AppColors.border, width: 1.5),
                        ),
                        child: Icon(Icons.question_mark_rounded,
                            size: 16, color: AppColors.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}