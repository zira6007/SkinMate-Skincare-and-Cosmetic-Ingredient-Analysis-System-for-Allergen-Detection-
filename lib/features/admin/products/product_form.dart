import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:skin_mate/core/constants/app_colors.dart';
import 'package:skin_mate/core/models/ingredient_model.dart';
import 'package:skin_mate/core/models/product_model.dart';
import 'package:skin_mate/core/services/storage_service.dart';
import 'package:skin_mate/core/services/supabase_service.dart';
import 'package:skin_mate/core/widgets/risk_badge.dart';

class ProductForm extends StatefulWidget {
  final ProductModel? product;
  const ProductForm({super.key, this.product});

  @override
  State<ProductForm> createState() => _ProductFormState();
}

class _ProductFormState extends State<ProductForm> {

  final _formKey = GlobalKey<FormState>();

  // ── Text controllers ───────────────────────────────────
  late TextEditingController _productIdController;
  late TextEditingController _brandController;
  late TextEditingController _productNameController;
  late TextEditingController _barcodeController;
  late TextEditingController _descController;
  late TextEditingController _skinTypeController;
  late TextEditingController _countryOriginController;
  late TextEditingController _ratingController;

  // ── Dropdown ───────────────────────────────────────────
  String? _categoryTag;

  static const List<String> _categories = [
    'moisturiser', 'cleanser', 'serum', 'toner',
    'sunscreen', 'exfoliant', 'treatment', 'essence',
    'mask', 'eye cream', 'lip care', 'body care', 'cosmetic',
  ];

  // ── Image ──────────────────────────────────────────────
  XFile?     _pickedImage;
  Uint8List? _pickedImageBytes;
  String?    _existingImageUrl;
  bool       _uploadingImage = false;

  // ── Ingredient multi-select ────────────────────────────
  List<IngredientModel> _allIngredients      = [];
  Set<String>           _selectedIngredients = {};
  bool                  _loadingIngredients  = true;
  String                _ingSearch           = '';

  // ── Saving state ───────────────────────────────────────
  bool    _isSaving = false;
  String? _errorMessage;

  bool get _isEditing => widget.product != null;

  // ─────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _productIdController     = TextEditingController(text: p?.productID      ?? '');
    _brandController         = TextEditingController(text: p?.brandName      ?? '');
    _productNameController   = TextEditingController(text: p?.productName    ?? '');
    _barcodeController       = TextEditingController(text: p?.barcode        ?? '');
    _descController          = TextEditingController(text: p?.description    ?? '');
    _skinTypeController      = TextEditingController(text: p?.skinTypeTarget ?? '');
    _countryOriginController = TextEditingController(text: p?.countryOrigin  ?? '');
    _ratingController        = TextEditingController(
        text: p != null ? p.rating.toStringAsFixed(1) : '');
    _categoryTag             = p?.categoryTag;
    _existingImageUrl        = p?.imageUrl;

    _loadIngredients();
  }

  @override
  void dispose() {
    _productIdController.dispose();
    _brandController.dispose();
    _productNameController.dispose();
    _barcodeController.dispose();
    _descController.dispose();
    _skinTypeController.dispose();
    _countryOriginController.dispose();
    _ratingController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────
  // LOAD ALL INGREDIENTS + existing assignments
  // ─────────────────────────────────────────────────────
  Future<void> _loadIngredients() async {
    try {
      final rows = await SupabaseService.client
          .from('INGREDIENT')
          .select('ingredientID, scientific_name_inci, common_name, risk_level')
          .order('scientific_name_inci');

      final list = IngredientModel.fromJsonList(rows as List);

      Set<String> existing = {};
      if (_isEditing) {
        final assignments = await SupabaseService.client
            .from('PRODUCT_INGREDIENT')
            .select('ingredientID')
            .eq('productID', widget.product!.productID);

        existing = (assignments as List)
            .map((r) => r['ingredientID'] as String)
            .toSet();
      }

      setState(() {
        _allIngredients      = list;
        _selectedIngredients = existing;
        _loadingIngredients  = false;
      });
    } catch (e) {
      setState(() => _loadingIngredients = false);
    }
  }

  // ─────────────────────────────────────────────────────
  // PICK IMAGE
  // ─────────────────────────────────────────────────────
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file   = await picker.pickImage(
      source:       ImageSource.gallery,
      maxWidth:     1080,
      imageQuality: 85,
    );
    if (file != null) {
      final bytes = await file.readAsBytes();
      setState(() {
        _pickedImage      = file;
        _pickedImageBytes = bytes;
      });
    }
  }

  // ─────────────────────────────────────────────────────
  // SAVE — INSERT or UPDATE
  // ─────────────────────────────────────────────────────
  Future<void> _save() async {
    if (_isSaving) return;   
    if (!_formKey.currentState!.validate()) return;

    setState(() { _isSaving = true; _errorMessage = null; });

    try {
      String? imageUrl = _existingImageUrl;

      // Upload new image if picked
      if (_pickedImage != null) {
        setState(() => _uploadingImage = true);
        final productID = widget.product?.productID
            ?? _productIdController.text.trim();
        imageUrl = await StorageService.uploadProductImage(
          file:      _pickedImage!,
          productID: productID,
        );
        setState(() => _uploadingImage = false);
      }

      final data = <String, dynamic>{
        'brand_name':          _brandController.text.trim(),
        'product_name':        _productNameController.text.trim(),
        'barcode':             _barcodeController.text.trim().isEmpty
            ? null : _barcodeController.text.trim(),
        'product_description': _descController.text.trim().isEmpty
            ? null : _descController.text.trim(),
        'skin_type_target':    _skinTypeController.text.trim().isEmpty
            ? null : _skinTypeController.text.trim(),
        'country_origin':      _countryOriginController.text.trim().isEmpty
            ? null : _countryOriginController.text.trim(),
        'category_tag':        _categoryTag,
        'avg_rating':          double.tryParse(_ratingController.text) ?? 0.0,
        'is_active':           true,
        if (imageUrl != null) 'product_image_url': imageUrl,
      };

      String productID;

      if (_isEditing) {
        // UPDATE
        await SupabaseService.client
            .from('PRODUCT')
            .update(data)
            .eq('productID', widget.product!.productID);
        productID = widget.product!.productID;
      } else {
        // INSERT — use the manually entered productID
        final enteredID = _productIdController.text.trim();
        final inserted  = await SupabaseService.client
            .from('PRODUCT')
            .insert({...data, 'productID': enteredID})
            .select('productID')
            .single();
        productID = inserted['productID'] as String;
      }

      // Save ingredient assignments (delete-then-upsert)
      await _saveIngredientAssignments(productID);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_isEditing
            ? 'Product updated successfully'
            : 'Product added successfully'),
        backgroundColor: AppColors.safeColor,
        behavior:        SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));

      Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _isSaving     = false;
        _errorMessage = 'Failed to save: $e';
      });
    }
  }

  // ─────────────────────────────────────────────────────
  // SAVE INGREDIENT ASSIGNMENTS
  // Delete-then-upsert pattern:
  //   • .select() after delete forces PostgREST to wait for the
  //     DELETE to fully complete before we proceed to insert.
  //   • .upsert() instead of .insert() is the safety net — even
  //     if any row survived the delete (e.g. RLS blocked it),
  //     the upsert won't crash with a duplicate-key error.
  // ─────────────────────────────────────────────────────
 Future<void> _saveIngredientAssignments(String productID) async {
  // Step 1 — find which ingredients are currently linked
  final existingRows = await SupabaseService.client
      .from('PRODUCT_INGREDIENT')
      .select('ingredientID')
      .eq('productID', productID);

  final existingIds = (existingRows as List)
      .map((r) => r['ingredientID'] as String)
      .toSet();

  // Step 2 — figure out what to remove and what to add
  final toRemove = existingIds.difference(_selectedIngredients);
  final toAdd     = _selectedIngredients.difference(existingIds);

  // Step 3 — delete only ingredients that were unselected
  if (toRemove.isNotEmpty) {
    await SupabaseService.client
        .from('PRODUCT_INGREDIENT')
        .delete()
        .eq('productID', productID)
        .inFilter('ingredientID', toRemove.toList());
  }

  // Step 4 — insert only the brand-new ingredients
  if (toAdd.isNotEmpty) {
    final rows = toAdd.toList().asMap().entries.map((e) => {
      'productID':         productID,
      'ingredientID':      e.value,
      'position_on_label': existingIds.length + e.key + 1,
    }).toList();

    await SupabaseService.client
        .from('PRODUCT_INGREDIENT')
        .insert(rows);
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
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  LayoutBuilder(builder: (_, constraints) {
                    if (constraints.maxWidth > 600) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildLeftColumn()),
                          const SizedBox(width: 20),
                          Expanded(child: _buildRightColumn()),
                        ],
                      );
                    }
                    return Column(children: [
                      _buildLeftColumn(),
                      const SizedBox(height: 20),
                      _buildRightColumn(),
                    ]);
                  }),

                  const SizedBox(height: 20),
                  _buildIngredientSection(),
                  const SizedBox(height: 20),

                  if (_errorMessage != null) _buildError(),
                  _buildActions(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon:  const Icon(Icons.arrow_back_rounded),
        color: AppColors.textPrimary,
        onPressed: () => Navigator.pop(context, false),
      ),
      title: Text(
        _isEditing ? 'Edit Product' : 'Add Product',
        style: const TextStyle(
          fontSize: 16, fontWeight: FontWeight.w700,
          color: AppColors.textPrimary),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: AppColors.border),
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  // LEFT COLUMN — image + basic info
  // ─────────────────────────────────────────────────────
  Widget _buildLeftColumn() {
    return _card(children: [
      _sectionLabel('Product Image'),
      const SizedBox(height: 12),
      _buildImagePicker(),
      const SizedBox(height: 20),
      _sectionLabel('Basic Information'),
      const SizedBox(height: 12),

      _label('Product ID', required: !_isEditing),
      const SizedBox(height: 6),
      _field(
        _productIdController,
        'e.g. PRD_001',
        readOnly: _isEditing,
        validator: (v) {
          if (_isEditing) return null;
          return v!.trim().isEmpty ? 'Required' : null;
        },
      ),
      const SizedBox(height: 14),

      _label('Brand Name', required: true),
      const SizedBox(height: 6),
      _field(_brandController, 'e.g. CeraVe',
          validator: (v) => v!.trim().isEmpty ? 'Required' : null),
      const SizedBox(height: 14),

      _label('Product Name', required: true),
      const SizedBox(height: 6),
      _field(_productNameController, 'e.g. Moisturising Cream',
          validator: (v) => v!.trim().isEmpty ? 'Required' : null),
      const SizedBox(height: 14),

      _label('Barcode (EAN-13)'),
      const SizedBox(height: 6),
      _field(_barcodeController, 'e.g. 0301871239',
          keyboardType: TextInputType.number),
    ]);
  }

  // ─────────────────────────────────────────────────────
  // RIGHT COLUMN — category + details
  // ─────────────────────────────────────────────────────
  Widget _buildRightColumn() {
    return _card(children: [
      _sectionLabel('Classification'),
      const SizedBox(height: 12),

      _label('Category'),
      const SizedBox(height: 6),
      _buildCategoryDropdown(),
      const SizedBox(height: 14),

      _label('Skin Type Target'),
      const SizedBox(height: 6),
      _field(_skinTypeController, 'e.g. Dry, Sensitive, Eczema'),
      const SizedBox(height: 14),

      _label('Country of Origin'),
      const SizedBox(height: 6),
      _field(_countryOriginController, 'e.g. South Korea, France'),
      const SizedBox(height: 14),

      _label('Average Rating'),
      const SizedBox(height: 6),
      _field(_ratingController, '0.0 – 5.0',
          keyboardType: TextInputType.number,
          validator: (v) {
            if (v == null || v.isEmpty) return null;
            final n = double.tryParse(v);
            if (n == null || n < 0 || n > 5) {
              return 'Enter a value between 0 and 5';
            }
            return null;
          }),
      const SizedBox(height: 20),

      _sectionLabel('Description'),
      const SizedBox(height: 12),
      _label('Product Description'),
      const SizedBox(height: 6),
      _field(_descController,
          'Short product description for users...',
          maxLines: 4),
    ]);
  }

  // ─────────────────────────────────────────────────────
  // IMAGE PICKER
  // ─────────────────────────────────────────────────────
  Widget _buildImagePicker() {
    final hasNew      = _pickedImage != null;
    final hasExisting = _existingImageUrl != null && _existingImageUrl!.isNotEmpty;

    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          color:        AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.borderFocused.withOpacity(0.5),
            width: 1.5,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_pickedImageBytes != null)
                Image.memory(
                  _pickedImageBytes!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _imagePlaceholder(),
                )
              else if (hasExisting)
                Image.network(
                  _existingImageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _imagePlaceholder(),
                )
              else
                _imagePlaceholder(),

              if (hasExisting || hasNew)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withOpacity(0.3),
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.edit_rounded, color: Colors.white, size: 28),
                          SizedBox(height: 4),
                          Text('Change image',
                            style: TextStyle(
                              fontSize: 12, color: Colors.white,
                              fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ),

              if (_uploadingImage)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withOpacity(0.5),
                    child: const Center(
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      color: AppColors.secondaryLight,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inventory_2_outlined, color: AppColors.primary, size: 36),
            SizedBox(height: 6),
            Text('Upload image',
              style: TextStyle(
                fontSize: 12, color: AppColors.primary,
                fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  // CATEGORY DROPDOWN
  // ─────────────────────────────────────────────────────
  Widget _buildCategoryDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      decoration: BoxDecoration(
        color:        AppColors.background,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value:      _categoryTag,
          isExpanded: true,
          hint: const Text('Select category',
              style: TextStyle(fontSize: 13, color: AppColors.textHint)),
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: AppColors.textSecondary),
          style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
          items: [
            const DropdownMenuItem(value: null, child: Text('— None —')),
            ..._categories.map((cat) => DropdownMenuItem(
              value: cat,
              child: Text(cat[0].toUpperCase() + cat.substring(1)),
            )),
          ],
          onChanged: (v) => setState(() => _categoryTag = v),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  // INGREDIENT MULTI-SELECT
  // ─────────────────────────────────────────────────────
  Widget _buildIngredientSection() {
    final filtered = _allIngredients.where((ing) {
      if (_ingSearch.isEmpty) return true;
      final q = _ingSearch.toLowerCase();
      return ing.inci.toLowerCase().contains(q) ||
          (ing.commonName ?? '').toLowerCase().contains(q);
    }).toList();

    return _card(children: [
      Row(
        children: [
          Expanded(child: _sectionLabel(
              'Ingredients  (${_selectedIngredients.length} selected)')),
          Text('${_allIngredients.length} total',
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
      const SizedBox(height: 12),

      SizedBox(
        height: 38,
        child: TextField(
          onChanged: (v) => setState(() => _ingSearch = v),
          style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText:  'Search ingredients...',
            hintStyle: const TextStyle(fontSize: 12, color: AppColors.textHint),
            prefixIcon: const Icon(Icons.search_rounded,
                size: 16, color: AppColors.textSecondary),
            filled:    true,
            fillColor: AppColors.background,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide:   BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 8),
          ),
        ),
      ),

      const SizedBox(height: 10),

      if (_loadingIngredients)
        const Center(child: CircularProgressIndicator(
            color: AppColors.primary, strokeWidth: 2))
      else
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 320),
          child: filtered.isEmpty
              ? const Center(
                  child: Text('No ingredients match',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)))
              : ListView.builder(
                  shrinkWrap:  true,
                  itemCount:   filtered.length,
                  itemBuilder: (_, i) {
                    final ing      = filtered[i];
                    final selected = _selectedIngredients.contains(ing.ingredientID);
                    return InkWell(
                      onTap: () {
                        setState(() {
                          if (selected) {
                            _selectedIngredients.remove(ing.ingredientID);
                          } else {
                            _selectedIngredients.add(ing.ingredientID);
                          }
                        });
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        margin: const EdgeInsets.only(bottom: 4),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.secondaryLight : AppColors.background,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: selected
                                ? AppColors.primary.withOpacity(0.4)
                                : AppColors.border,
                          ),
                        ),
                        child: Row(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: 18, height: 18,
                              decoration: BoxDecoration(
                                color: selected
                                    ? AppColors.primary : Colors.white,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                    color: selected
                                        ? AppColors.primary : AppColors.border,
                                    width: 1.5),
                              ),
                              child: selected
                                  ? const Icon(Icons.check_rounded,
                                      size: 11, color: Colors.white)
                                  : null,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    ing.inci,
                                    style: const TextStyle(
                                      fontSize:   12,
                                      fontWeight: FontWeight.w600,
                                      color:      AppColors.textPrimary,
                                    ),
                                  ),
                                  if (ing.commonName != null)
                                    Text(
                                      ing.commonName!,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color:    AppColors.textSecondary,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            RiskBadge(
                              flag: ing.riskLevel,
                              size: RiskBadgeSize.small,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
    ]);
  }

  // ─────────────────────────────────────────────────────
  // ERROR BANNER
  // ─────────────────────────────────────────────────────
  Widget _buildError() {
    return Container(
      width:   double.infinity,
      margin:  const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color:        AppColors.allergenBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.allergenColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline,
              color: AppColors.allergenColor, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(_errorMessage!,
              style: const TextStyle(
                  color: AppColors.allergenText, fontSize: 12))),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  // ACTIONS
  // ─────────────────────────────────────────────────────
  Widget _buildActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        OutlinedButton(
          onPressed: () => Navigator.pop(context, false),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textSecondary,
            side: const BorderSide(color: AppColors.border),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Cancel'),
        ),
        const SizedBox(width: 12),
        SizedBox(
          height: 44,
          child: ElevatedButton.icon(
            onPressed: _isSaving ? null : _save,
            icon: _isSaving
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : Icon(
                    _isEditing ? Icons.save_rounded : Icons.add_rounded,
                    size: 18),
            label: Text(_isSaving
                ? 'Saving...'
                : _isEditing ? 'Save Changes' : 'Add Product'),
            style: ElevatedButton.styleFrom(
              backgroundColor:         AppColors.primary,
              foregroundColor:         Colors.white,
              disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
  // SHARED HELPERS
  // ─────────────────────────────────────────────────────
  Widget _card({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
              color:      Colors.black.withOpacity(0.04),
              blurRadius: 12, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text.toUpperCase(),
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w700,
                letterSpacing: 0.08,
                color: AppColors.textSecondary.withOpacity(0.6))),
        const SizedBox(height: 4),
        Container(height: 1, color: AppColors.border),
      ],
    );
  }

  Widget _label(String text, {bool required = false}) {
    return Row(children: [
      Text(text,
          style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600,
              color: AppColors.textLabel)),
      if (required) ...[
        const SizedBox(width: 3),
        const Text('*', style: TextStyle(
            color: AppColors.allergenColor,
            fontSize: 12, fontWeight: FontWeight.w700)),
      ],
    ]);
  }

  Widget _field(
    TextEditingController controller,
    String hint, {
    TextInputType              keyboardType = TextInputType.text,
    int                        maxLines     = 1,
    bool                       readOnly     = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller:   controller,
      maxLines:     maxLines,
      keyboardType: keyboardType,
      readOnly:     readOnly,
      style: TextStyle(
        fontSize: 13,
        color: readOnly ? AppColors.textSecondary : AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        hintText:  hint,
        hintStyle: const TextStyle(fontSize: 13, color: AppColors.textHint),
        filled:    true,
        fillColor: readOnly
            ? AppColors.border.withOpacity(0.25)
            : AppColors.background,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(11),
            borderSide:   BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(11),
            borderSide: BorderSide(
                color: readOnly
                    ? AppColors.border.withOpacity(0.5)
                    : AppColors.border,
                width: 1)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(11),
            borderSide: BorderSide(
                color: readOnly
                    ? AppColors.border.withOpacity(0.5)
                    : AppColors.borderFocused,
                width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(11),
            borderSide: const BorderSide(
                color: AppColors.allergenColor, width: 1.2)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(11),
            borderSide: const BorderSide(
                color: AppColors.allergenColor, width: 1.5)),
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
}