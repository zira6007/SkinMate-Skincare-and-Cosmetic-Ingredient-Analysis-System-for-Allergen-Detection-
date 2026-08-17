// user/diary/diary_entry_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:skin_mate/core/constants/app_colors.dart';
import 'package:skin_mate/core/services/supabase_service.dart';

class DiaryEntryScreen extends StatefulWidget {
  /// Pass an existing SKIN_DIARY row to view/edit it; null to create a new entry.
  final Map<String, dynamic>? existingEntry;

  const DiaryEntryScreen({super.key, this.existingEntry});

  @override
  State<DiaryEntryScreen> createState() => _DiaryEntryScreenState();
}

class _DiaryEntryScreenState extends State<DiaryEntryScreen> {
  late DateTime _selectedDate;

  int _oiliness = 2;
  int _redness = 2;
  int _breakout = 2;
  int _hydration = 2;

  final TextEditingController _notesCtrl = TextEditingController();

  File? _newPhotoFile;
  String? _existingPhotoUrl;

  // Product tagging
  final TextEditingController _productSearchCtrl = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  final Map<String, Map<String, dynamic>> _selectedProducts = {}; // productID -> row
  bool _searching = false;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingEntry;

    if (existing != null) {
      _selectedDate = DateTime.parse(existing['log_date'] as String);
      _oiliness = existing['oiliness'] as int? ?? 2;
      _redness = existing['redness'] as int? ?? 2;
      _breakout = existing['breakout'] as int? ?? 2;
      _hydration = existing['hydration'] as int? ?? 2;
      _notesCtrl.text = existing['notes'] as String? ?? '';
      _existingPhotoUrl = existing['photo_url'] as String?;
      _loadExistingProductTags(existing['diaryID'] as String);
    } else {
      _selectedDate = DateTime.now();
    }
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    _productSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadExistingProductTags(String diaryId) async {
    try {
      final tags = await SupabaseService.client
          .from('DIARY_PRODUCT_TAG')
          .select('productID, PRODUCT(productID, product_name, image_url)')
          .eq('diaryID', diaryId);

      for (final t in (tags as List)) {
        final product = Map<String, dynamic>.from(t['PRODUCT'] as Map);
        _selectedProducts[product['productID'] as String] = product;
      }
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) {
      setState(() => _newPhotoFile = File(picked.path));
    }
  }

  Future<void> _searchProducts(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _searching = true);
    try {
      final rows = await SupabaseService.client
          .from('PRODUCT')
          .select('productID, product_name, image_url')
          .ilike('product_name', '%${query.trim()}%')
          .limit(10);

      if (mounted) {
        setState(() {
          _searchResults = List<Map<String, dynamic>>.from(rows as List);
          _searching = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _toggleProduct(Map<String, dynamic> product) {
    final id = product['productID'] as String;
    setState(() {
      if (_selectedProducts.containsKey(id)) {
        _selectedProducts.remove(id);
      } else {
        _selectedProducts[id] = product;
      }
    });
  }

  String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<String?> _uploadPhoto(String userId) async {
    if (_newPhotoFile == null) return _existingPhotoUrl;

    final ext = _newPhotoFile!.path.split('.').last;
    final path = '$userId/${DateTime.now().millisecondsSinceEpoch}.$ext';

    await SupabaseService.client.storage
        .from('diary-images')
        .upload(path, _newPhotoFile!);

    return SupabaseService.client.storage.from('diary-images').getPublicUrl(path);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final userId = SupabaseService.client.auth.currentUser?.id;
      if (userId == null) return;

      final photoUrl = await _uploadPhoto(userId);

      final payload = {
        'userID': userId,
        'log_date': _dateKey(_selectedDate),
        'oiliness': _oiliness,
        'redness': _redness,
        'breakout': _breakout,
        'hydration': _hydration,
        'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        'photo_url': photoUrl,
      };

      String diaryId;
      final existing = widget.existingEntry;

      if (existing != null) {
        diaryId = existing['diaryID'] as String;
        await SupabaseService.client
            .from('SKIN_DIARY')
            .update(payload)
            .eq('diaryID', diaryId);

        // Replace product tags
        await SupabaseService.client
            .from('DIARY_PRODUCT_TAG')
            .delete()
            .eq('diaryID', diaryId);
      } else {
        final inserted = await SupabaseService.client
            .from('SKIN_DIARY')
            .insert(payload)
            .select('diaryID')
            .single();
        diaryId = inserted['diaryID'] as String;
      }

      if (_selectedProducts.isNotEmpty) {
        final tagRows = _selectedProducts.keys
            .map((productId) => {
                  'diaryID': diaryId,
                  'productID': productId,
                })
            .toList();
        await SupabaseService.client.from('DIARY_PRODUCT_TAG').insert(tagRows);
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: const BackButton(color: Colors.black87),
        title: Text(widget.existingEntry == null ? 'New Diary Entry' : 'Edit Diary Entry',
            style: const TextStyle(
                color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 17)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('Date'),
            InkWell(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                      style: const TextStyle(fontSize: 14),
                    ),
                    const Icon(Icons.calendar_today_outlined, size: 18),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            _ratingSelector('Oiliness', _oiliness, (v) => setState(() => _oiliness = v)),
            const SizedBox(height: 14),
            _ratingSelector('Redness', _redness, (v) => setState(() => _redness = v)),
            const SizedBox(height: 14),
            _ratingSelector('Breakout', _breakout, (v) => setState(() => _breakout = v)),
            const SizedBox(height: 14),
            _ratingSelector('Hydration', _hydration, (v) => setState(() => _hydration = v)),
            const SizedBox(height: 20),

            _label('Notes'),
            TextFormField(
              controller: _notesCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'How did your skin feel today?',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppColors.border),
                ),
              ),
            ),
            const SizedBox(height: 20),

            _label('Photo'),
            GestureDetector(
              onTap: _pickPhoto,
              child: Container(
                width: double.infinity,
                height: 160,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: _newPhotoFile != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(_newPhotoFile!, fit: BoxFit.cover, width: double.infinity),
                      )
                    : (_existingPhotoUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(_existingPhotoUrl!,
                                fit: BoxFit.cover, width: double.infinity),
                          )
                        : const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add_a_photo_outlined, size: 28),
                                SizedBox(height: 6),
                                Text('Tap to add a photo', style: TextStyle(fontSize: 12)),
                              ],
                            ),
                          )),
              ),
            ),
            const SizedBox(height: 20),

            _label('Products used today'),
            TextFormField(
              controller: _productSearchCtrl,
              onChanged: _searchProducts,
              decoration: InputDecoration(
                hintText: 'Search products...',
                prefixIcon: const Icon(Icons.search, size: 18),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppColors.border),
                ),
              ),
            ),
            if (_searching)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: SizedBox(
                    height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            if (_searchResults.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: _searchResults.map((p) {
                    final id = p['productID'] as String;
                    final selected = _selectedProducts.containsKey(id);
                    return ListTile(
                      dense: true,
                      title: Text(p['product_name'] as String? ?? '',
                          style: const TextStyle(fontSize: 13)),
                      trailing: Icon(
                        selected ? Icons.check_circle : Icons.add_circle_outline,
                        color: selected ? AppColors.primary : Colors.black38,
                      ),
                      onTap: () => _toggleProduct(p),
                    );
                  }).toList(),
                ),
              ),
            if (_selectedProducts.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _selectedProducts.values
                    .map((p) => Chip(
                          label: Text(p['product_name'] as String? ?? '',
                              style: const TextStyle(fontSize: 11)),
                          onDeleted: () => _toggleProduct(p),
                          backgroundColor: AppColors.secondaryLight,
                        ))
                    .toList(),
              ),
            ],
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryDark,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Save Entry',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black87)),
      );

  Widget _ratingSelector(String label, int value, ValueChanged<int> onChanged) {
    const labels = {1: 'Low', 2: 'Mild', 3: 'Moderate', 4: 'High'};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        Row(
          children: List.generate(4, (i) {
            final v = i + 1;
            final selected = value == v;
            return Expanded(
              child: GestureDetector(
                onTap: () => onChanged(v),
                child: Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: selected ? AppColors.primary : AppColors.border),
                  ),
                  child: Text(
                    labels[v]!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}