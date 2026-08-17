import 'package:flutter/material.dart';
import 'package:skin_mate/core/constants/app_colors.dart';
import 'package:skin_mate/core/models/ingredient_model.dart';
import 'package:skin_mate/core/services/supabase_service.dart';
import 'package:skin_mate/core/widgets/risk_badge.dart';

class IngredientForm extends StatefulWidget {
  // null = add mode, non-null = edit mode
  final IngredientModel? ingredient;

  const IngredientForm({
    super.key,
    this.ingredient,
  });

  @override
  State<IngredientForm> createState() => _IngredientFormState();
}

class _IngredientFormState extends State<IngredientForm> {

  // ── Form key ──────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();

  // ── Text controllers — one per field ──────────────────
  late TextEditingController _ingredientIDController;
  late TextEditingController _inciController;
  late TextEditingController _commonNameController;
  late TextEditingController _purposeController;
  late TextEditingController _warningController;
  late TextEditingController _sourceRefController;
  late TextEditingController _skinTypeConcernController;
  late TextEditingController _createdByController;

  // ── Dropdown / toggle state ───────────────────────────
  String _riskLevel    = 'SAFE';   // SAFE | CAUTION | ALLERGEN
  bool   _euRestricted = false;

  // ── Loading / error state ─────────────────────────────
  bool    _isSaving = false;
  String? _errorMessage;

  // ── Is this edit mode? ────────────────────────────────
  bool get _isEditing => widget.ingredient != null;

  // ─────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();

    // Pre-fill fields if editing an existing ingredient
    final ing = widget.ingredient;

    _ingredientIDController   = TextEditingController(text: ing?.ingredientID        ?? '');
    _inciController           = TextEditingController(text: ing?.inci                ?? '');
    _commonNameController     = TextEditingController(text: ing?.commonName           ?? '');
    _purposeController        = TextEditingController(text: ing?.purposeText          ?? '');
    _warningController        = TextEditingController(text: ing?.warningExplanation   ?? '');
    _sourceRefController      = TextEditingController(text: ing?.source               ?? '');
    _skinTypeConcernController= TextEditingController(text: ing?.skinTypeConcern      ?? '');
    _createdByController      = TextEditingController(text: ing?.createdBy            ?? '');

    // Set dropdown and checkbox from existing values
    _riskLevel    = ing?.riskLevel ?? 'SAFE';
    _euRestricted = ing?.euRestricted?.toLowerCase() == 'true' ||
                    ing?.euRestricted?.toLowerCase() == 'yes';
  }

  @override
  void dispose() {
    _ingredientIDController.dispose();
    _inciController.dispose();
    _commonNameController.dispose();
    _purposeController.dispose();
    _warningController.dispose();
    _sourceRefController.dispose();
    _skinTypeConcernController.dispose();
    _createdByController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────
  // SAVE — INSERT or UPDATE
  // ─────────────────────────────────────────────────────
  Future<void> _save() async {
    // Validate all fields first
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving     = true;
      _errorMessage = null;
    });

    try {
      // Capture real-time timestamp at the moment of saving
      final now = DateTime.now().toIso8601String();

      // Build the data map to send to Supabase
      final data = {
        'scientific_name_inci': _inciController.text.trim(),
        'common_name':          _commonNameController.text.trim().isEmpty
            ? null
            : _commonNameController.text.trim(),
        'risk_level':           _riskLevel,
        'purpose_text':         _purposeController.text.trim().isEmpty
            ? null
            : _purposeController.text.trim(),
        'warning_explanation':  _warningController.text.trim().isEmpty
            ? null
            : _warningController.text.trim(),
        'eu_restricted':        _euRestricted ? 'Yes' : 'No',
        'source':               _sourceRefController.text.trim().isEmpty
            ? null
            : _sourceRefController.text.trim(),
        'skin_type_concern':    _skinTypeConcernController.text.trim().isEmpty
            ? null
            : _skinTypeConcernController.text.trim(),
        'created_by':           _createdByController.text.trim().isEmpty
            ? null
            : _createdByController.text.trim(),
        'updated_at':           now, // always set to real-time on save
      };

      if (_isEditing) {
        // ── UPDATE existing row ───────────────────────
        await SupabaseService.client
            .from('INGREDIENT')
            .update(data)
            .eq('ingredientID', widget.ingredient!.ingredientID);
      } else {
        // ── INSERT new row ────────────────────────────
        // Include ingredientID from the text field for new records
        await SupabaseService.client
            .from('INGREDIENT')
            .insert({
              'ingredientID': _ingredientIDController.text.trim(),
              ...data,
            });
      }

      if (!mounted) return;

      // Show success snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing
                ? 'Ingredient updated successfully'
                : 'Ingredient added successfully',
          ),
          backgroundColor: AppColors.safeColor,
          behavior:        SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
        ),
      );

      // Pop back to IngredientsScreen, returning true = saved
      Navigator.pop(context, true);

    } catch (e) {
      setState(() {
        _isSaving     = false;
        _errorMessage = 'Failed to save: $e';
      });
    }
  }

  // ─────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: Row(
        children: [
          // ── Centered form card ───────────────────────
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 28),
                child: ConstrainedBox(
                  // Max width 680px — keeps form readable on wide screens
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: Column(
                    children: [
                      _buildFormCard(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  // APP BAR
  // ─────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation:       0,
      leading: IconButton(
        icon:    const Icon(Icons.arrow_back_rounded),
        color:   AppColors.textPrimary,
        onPressed: () => Navigator.pop(context, false),
        tooltip: 'Back',
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isEditing ? 'Edit Ingredient' : 'Add Ingredient',
            style: const TextStyle(
              fontSize:   16,
              fontWeight: FontWeight.w700,
              color:      AppColors.textPrimary,
            ),
          ),
          if (_isEditing)
            Text(
              widget.ingredient!.inci,
              style: const TextStyle(
                fontSize: 11,
                color:    AppColors.textSecondary,
              ),
            ),
        ],
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          color:  AppColors.border,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  // FORM CARD
  // ─────────────────────────────────────────────────────
  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset:     const Offset(0, 4),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Section: Identity ────────────────────────
            _sectionLabel('Identity'),
            const SizedBox(height: 14),

            // Ingredient ID (required for add, read-only for edit)
            _fieldLabel('Ingredient ID', required: !_isEditing),
            const SizedBox(height: 6),
            _buildTextField(
              controller: _ingredientIDController,
              hint:       'e.g. ING001',
              action:     TextInputAction.next,
              readOnly:   _isEditing, // can't change PK once created
              validator: !_isEditing
                  ? (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Ingredient ID is required';
                      }
                      return null;
                    }
                  : null,
            ),

            const SizedBox(height: 16),

            // ── Section: Basic info ──────────────────────
            _sectionLabel('Basic Information'),
            const SizedBox(height: 14),

            // INCI name (required)
            _fieldLabel('INCI / Scientific Name', required: true),
            const SizedBox(height: 6),
            _buildTextField(
              controller: _inciController,
              hint:       'e.g. Sodium Hyaluronate',
              action:     TextInputAction.next,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'INCI name is required';
                }
                if (v.trim().length < 2) {
                  return 'Name must be at least 2 characters';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Common name (optional)
            _fieldLabel('Common / Marketing Name'),
            const SizedBox(height: 6),
            _buildTextField(
              controller: _commonNameController,
              hint:       'e.g. Hyaluronic Acid',
              action:     TextInputAction.next,
            ),

            const SizedBox(height: 24),

            // ── Section: Risk Classification ─────────────
            _sectionLabel('Risk Classification'),
            const SizedBox(height: 14),

            // Risk level dropdown
            _fieldLabel('Risk Level', required: true),
            const SizedBox(height: 6),
            _buildRiskDropdown(),

            const SizedBox(height: 14),

            // EU restricted checkbox
            _buildEuCheckbox(),

            const SizedBox(height: 24),

            // ── Section: Details ──────────────────────────
            _sectionLabel('Ingredient Details'),
            const SizedBox(height: 14),

            // Purpose text
            _fieldLabel('Purpose / Function'),
            const SizedBox(height: 6),
            _buildTextField(
              controller: _purposeController,
              hint:       'e.g. Humectant, draws moisture to skin',
              action:     TextInputAction.next,
              maxLines:   2,
            ),

            const SizedBox(height: 16),

            // Warning explanation
            _fieldLabel('Warning / Explanation'),
            const SizedBox(height: 6),
            _buildTextField(
              controller: _warningController,
              hint:       'e.g. May sting on broken or sensitive skin',
              action:     TextInputAction.next,
              maxLines:   3,
            ),

            const SizedBox(height: 16),

            // Source reference
            _fieldLabel('Data Source'),
            const SizedBox(height: 6),
            _buildTextField(
              controller: _sourceRefController,
              hint:       'e.g. PubChem CID 753, EWG Score 1',
              action:     TextInputAction.next,
            ),

            const SizedBox(height: 16),

            // Skin type / concern
            _fieldLabel('Skin Type / Concern'),
            const SizedBox(height: 6),
            _buildTextField(
              controller: _skinTypeConcernController,
              hint:       'e.g. Sensitive, Oily, Acne-Prone',
              action:     TextInputAction.next,
              maxLines:   2,
            ),

            const SizedBox(height: 24),

            // ── Section: Record Info ──────────────────────
            _sectionLabel('Record Information'),
            const SizedBox(height: 14),

            // Created by
            _fieldLabel('Created By'),
            const SizedBox(height: 6),
            _buildTextField(
              controller: _createdByController,
              hint:       'e.g. admin, Dr. Sarah',
              action:     TextInputAction.done,
            ),

            const SizedBox(height: 12),

            // Updated at — read-only, shows real-time on save
            _buildUpdatedAtInfo(),

            const SizedBox(height: 24),

            // ── Error banner ──────────────────────────────
            if (_errorMessage != null)
              Container(
                width:   double.infinity,
                margin:  const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color:        AppColors.allergenBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.allergenColor.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                      color: AppColors.allergenColor, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color:   AppColors.allergenText,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // ── Action buttons ────────────────────────────
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  // UPDATED AT INFO ROW
  // Shows when the record was last updated (or will be set on save)
  // ─────────────────────────────────────────────────────
  Widget _buildUpdatedAtInfo() {
    final existing = widget.ingredient?.updatedAt;

    // Format the existing updatedAt if available
    String displayText;
    if (existing != null) {
      displayText =
          '${existing.year}-'
          '${existing.month.toString().padLeft(2, '0')}-'
          '${existing.day.toString().padLeft(2, '0')}  '
          '${existing.hour.toString().padLeft(2, '0')}:'
          '${existing.minute.toString().padLeft(2, '0')}:'
          '${existing.second.toString().padLeft(2, '0')}';
    } else {
      displayText = 'Will be set automatically on save';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color:        AppColors.background,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.schedule_rounded,
            size:  16,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Updated At',
                style: TextStyle(
                  fontSize:   11,
                  fontWeight: FontWeight.w600,
                  color:      AppColors.textLabel,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                displayText,
                style: const TextStyle(
                  fontSize: 12,
                  color:    AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color:        AppColors.secondaryLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Auto',
              style: TextStyle(
                fontSize:   10,
                fontWeight: FontWeight.w700,
                color:      AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  // RISK LEVEL DROPDOWN
  // ─────────────────────────────────────────────────────
  Widget _buildRiskDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color:        AppColors.background,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: AppColors.borderFocused,
          width: 1.5,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value:      _riskLevel,
          isExpanded: true,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppColors.primary,
          ),
          style: const TextStyle(
            fontSize: 13,
            color:    AppColors.textPrimary,
          ),
          items: ['SAFE', 'CAUTION', 'ALLERGEN'].map((level) {
            return DropdownMenuItem(
              value: level,
              child: Row(
                children: [
                  RiskBadge(flag: level, size: RiskBadgeSize.small),
                  const SizedBox(width: 10),
                  Text(
                    level == 'SAFE'
                        ? 'Safe — generally non-irritating'
                        : level == 'CAUTION'
                            ? 'Caution — may affect certain skin types'
                            : 'Allergen — known sensitiser or banned substance',
                    style: const TextStyle(
                      fontSize: 13,
                      color:    AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) setState(() => _riskLevel = val);
          },
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  // EU RESTRICTED CHECKBOX
  // ─────────────────────────────────────────────────────
  Widget _buildEuCheckbox() {
    return InkWell(
      onTap: () => setState(() => _euRestricted = !_euRestricted),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _euRestricted
              ? AppColors.cautionBg
              : AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _euRestricted
                ? AppColors.cautionColor.withOpacity(0.4)
                : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width:  22,
              height: 22,
              decoration: BoxDecoration(
                color:        _euRestricted
                    ? AppColors.cautionColor
                    : Colors.white,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                  color: _euRestricted
                      ? AppColors.cautionColor
                      : AppColors.border,
                  width: 1.5,
                ),
              ),
              child: _euRestricted
                  ? const Icon(Icons.check_rounded,
                      size: 14, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'EU Cosmetics Regulation — Restricted or Banned',
                    style: TextStyle(
                      fontSize:   13,
                      fontWeight: FontWeight.w600,
                      color:      AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    'Check this if the ingredient is restricted or banned under EU Annex regulations',
                    style: TextStyle(
                      fontSize: 11,
                      color:    AppColors.textSecondary.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            if (_euRestricted)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color:        AppColors.cautionBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.cautionColor.withOpacity(0.4)),
                ),
                child: const Text(
                  'EU Restricted',
                  style: TextStyle(
                    fontSize:   10,
                    fontWeight: FontWeight.w700,
                    color:      AppColors.cautionText,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  // ACTION BUTTONS — Cancel + Save
  // ─────────────────────────────────────────────────────
  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [

        // Cancel
        OutlinedButton(
          onPressed: () => Navigator.pop(context, false),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textSecondary,
            side: const BorderSide(color: AppColors.border),
            padding: const EdgeInsets.symmetric(
              horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Cancel'),
        ),

        const SizedBox(width: 12),

        // Save button
        SizedBox(
          height: 44,
          child: ElevatedButton.icon(
            onPressed: _isSaving ? null : _save,
            icon: _isSaving
                ? const SizedBox(
                    width:  16,
                    height: 16,
                    child:  CircularProgressIndicator(
                      color:       Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Icon(
                    _isEditing
                        ? Icons.save_rounded
                        : Icons.add_rounded,
                    size: 18,
                  ),
            label: Text(
              _isSaving
                  ? 'Saving...'
                  : _isEditing
                      ? 'Save Changes'
                      : 'Add Ingredient',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor:         AppColors.primary,
              foregroundColor:         Colors.white,
              disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
              padding: const EdgeInsets.symmetric(
                horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────
  // SHARED TEXT FIELD
  // ─────────────────────────────────────────────────────
  Widget _buildTextField({
    required TextEditingController controller,
    required String                hint,
    TextInputAction                action   = TextInputAction.next,
    int                            maxLines = 1,
    bool                           readOnly = false,
    String? Function(String?)?     validator,
  }) {
    return TextFormField(
      controller:      controller,
      maxLines:        maxLines,
      textInputAction: action,
      readOnly:        readOnly,
      style: TextStyle(
        fontSize: 13,
        color:    readOnly
            ? AppColors.textSecondary
            : AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        hintText:  hint,
        hintStyle: TextStyle(
          fontSize: 13,
          color:    AppColors.textHint,
        ),
        filled:    true,
        fillColor: readOnly
            ? AppColors.background.withOpacity(0.6)
            : AppColors.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide:   BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: BorderSide(
            color: readOnly
                ? AppColors.border.withOpacity(0.5)
                : AppColors.border,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: BorderSide(
            color: readOnly
                ? AppColors.border.withOpacity(0.5)
                : AppColors.borderFocused,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(
            color: AppColors.allergenColor, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(
            color: AppColors.allergenColor, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14, vertical: 12),
        errorStyle: const TextStyle(fontSize: 11),
        suffixIcon: readOnly
            ? const Icon(Icons.lock_outline_rounded,
                size: 14, color: AppColors.textHint)
            : null,
      ),
      validator: validator,
    );
  }

  // ─────────────────────────────────────────────────────
  // HELPER WIDGETS
  // ─────────────────────────────────────────────────────

  Widget _sectionLabel(String text) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text.toUpperCase(),
          style: TextStyle(
            fontSize:      10,
            fontWeight:    FontWeight.w700,
            letterSpacing: 0.08,
            color:         AppColors.textSecondary.withOpacity(0.6),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: 1,
          color:  AppColors.border,
        ),
      ],
    );
  }

  Widget _fieldLabel(String text, {bool required = false}) {
    return Row(
      children: [
        Text(
          text,
          style: const TextStyle(
            fontSize:   12,
            fontWeight: FontWeight.w600,
            color:      AppColors.textLabel,
          ),
        ),
        if (required) ...[
          const SizedBox(width: 3),
          const Text(
            '*',
            style: TextStyle(
              color:      AppColors.allergenColor,
              fontSize:   12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }
}