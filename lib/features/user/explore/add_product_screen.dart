// user/explore/add_product_screen.dart
import 'package:flutter/material.dart';
import 'package:skin_mate/core/services/supabase_service.dart';
import 'package:skin_mate/core/constants/app_colors.dart';

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();

  final _brandController = TextEditingController();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _imageUrlController = TextEditingController();

  String? _selectedCategory;
  String? _selectedSkinTarget;
  bool _isSubmitting = false;

  static const _categories = [
    'Moisturiser', 'Cleanser', 'Serum', 'Sunscreen',
    'Toner', 'Eye Cream', 'Mask',
  ];

  static const _skinTargets = [
    'Oily', 'Dry', 'Combination', 'Normal', 'Sensitive',
  ];

  @override
  void dispose() {
    _brandController.dispose();
    _nameController.dispose();
    _descController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final userId = SupabaseService.client.auth.currentUser?.id;

      await SupabaseService.client.from('PRODUCT').insert({
        'brand_name': _brandController.text.trim(),
        'product_name': _nameController.text.trim(),
        'product_description': _descController.text.trim().isEmpty
            ? null
            : _descController.text.trim(),
        'product_image_url': _imageUrlController.text.trim().isEmpty
            ? null
            : _imageUrlController.text.trim(),
        'category_tag': _selectedCategory,
        'skin_type_target': _selectedSkinTarget,
        'submitted_by': userId,
        'status': 'pending', // for moderation review
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Thanks! Product submitted for review.'),
          backgroundColor: AppColors.primaryDark,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: const BackButton(color: AppColors.textPrimary),
        title: const Text(
          'Add a Product',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 17,
          ),
        ),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            _label('Brand name'),
            _textField(_brandController, hint: 'e.g. CeraVe',
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Brand name is required' : null),
            const SizedBox(height: 16),

            _label('Product name'),
            _textField(_nameController, hint: 'e.g. Hydrating Cleanser',
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Product name is required' : null),
            const SizedBox(height: 16),

            _label('Category'),
            _dropdown(
              value: _selectedCategory,
              items: _categories,
              hint: 'Select a category',
              onChanged: (v) => setState(() => _selectedCategory = v),
            ),
            const SizedBox(height: 16),

            _label('Skin type target (optional)'),
            _dropdown(
              value: _selectedSkinTarget,
              items: _skinTargets,
              hint: 'Select skin type',
              onChanged: (v) => setState(() => _selectedSkinTarget = v),
            ),
            const SizedBox(height: 16),

            _label('Image URL (optional)'),
            _textField(_imageUrlController, hint: 'https://...'),
            const SizedBox(height: 16),

            _label('Description (optional)'),
            _textField(_descController, hint: 'Short description...', maxLines: 4),
            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryDark,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Submit Product',
                        style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700,
                color: AppColors.textSecondary)),
      );

  Widget _textField(TextEditingController c,
      {String? hint, int maxLines = 1, String? Function(String?)? validator}) {
    return TextFormField(
      controller: c,
      maxLines: maxLines,
      validator: validator,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        filled: true,
        fillColor: AppColors.cardBackground,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
      ),
    );
  }

  Widget _dropdown({
    required String? value,
    required List<String> items,
    required String hint,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          hint: Text(hint, style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary),
          items: items
              .map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary))))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}