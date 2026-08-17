// user/diary/diary_screen.dart

import 'package:flutter/material.dart';
import 'package:skin_mate/core/constants/app_colors.dart';
import 'package:skin_mate/core/services/supabase_service.dart';
import 'package:skin_mate/core/widgets/loading_spinner.dart';
import 'package:skin_mate/features/user/diary/diary_entry_screen.dart';

class DiaryScreen extends StatefulWidget {
  const DiaryScreen({super.key});

  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  bool _loading = true;

  DateTime _visibleMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _selectedDate;

  // log_date (yyyy-mm-dd string) -> diary row
  Map<String, Map<String, dynamic>> _entriesByDate = {};

  // Tagged products for the currently selected entry
  List<Map<String, dynamic>> _selectedProducts = [];
  bool _loadingProducts = false;

  @override
  void initState() {
    super.initState();
    _loadMonth();
  }

  String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _loadMonth() async {
    setState(() {
      _loading = true;
      _selectedDate = null;
      _selectedProducts = [];
    });

    try {
      final userId = SupabaseService.client.auth.currentUser?.id;
      if (userId == null) {
        setState(() => _loading = false);
        return;
      }

      final firstDay = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
      final lastDay = DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0);

      final rows = await SupabaseService.client
          .from('SKIN_DIARY')
          .select()
          .eq('userID', userId)
          .gte('log_date', _dateKey(firstDay))
          .lte('log_date', _dateKey(lastDay))
          .order('log_date', ascending: true);

      final map = <String, Map<String, dynamic>>{};
      for (final row in (rows as List)) {
        final r = Map<String, dynamic>.from(row);
        // log_date comes back as e.g. "2026-04-12"
        final key = (r['log_date'] as String).substring(0, 10);
        map[key] = r;
      }

      if (mounted) {
        setState(() {
          _entriesByDate = map;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _selectDate(DateTime date) async {
    final key = _dateKey(date);
    setState(() {
      _selectedDate = date;
      _selectedProducts = [];
    });

    final entry = _entriesByDate[key];
    if (entry == null) return;

    setState(() => _loadingProducts = true);
    try {
      final tags = await SupabaseService.client
          .from('DIARY_PRODUCT_TAG')
          .select('productID, PRODUCT(product_name, image_url)')
          .eq('diaryID', entry['diaryID']);

      final products = (tags as List)
          .map((t) => Map<String, dynamic>.from(t['PRODUCT'] as Map))
          .toList();

      if (mounted) {
        setState(() {
          _selectedProducts = products;
          _loadingProducts = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingProducts = false);
    }
  }

  void _changeMonth(int delta) {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
    });
    _loadMonth();
  }

  Future<void> _openEntry({Map<String, dynamic>? existing}) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => DiaryEntryScreen(existingEntry: existing),
      ),
    );
    if (changed == true) _loadMonth();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('Skin Diary',
            style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w600,
                fontSize: 17)),
        centerTitle: true,
      ),
      body: _loading
          ? const LoadingSpinner(message: 'Loading diary...')
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMonthHeader(),
                  const SizedBox(height: 12),
                  _buildCalendarCard(),
                  const SizedBox(height: 20),
                  if (_selectedDate != null) _buildEntryPreview(),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primaryDark,
        onPressed: () => _openEntry(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildMonthHeader() {
    const months = [
      'January','February','March','April','May','June',
      'July','August','September','October','November','December'
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => _changeMonth(-1),
        ),
        Text(
          '${months[_visibleMonth.month - 1]} ${_visibleMonth.year}',
          style: const TextStyle(
              fontSize: 17, fontWeight: FontWeight.w700, color: Colors.black87),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: () => _changeMonth(1),
        ),
      ],
    );
  }

  Widget _buildCalendarCard() {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: AppColors.border,
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 12,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Column(
      children: [
        _buildWeekdayRow(),
        const SizedBox(height: 8),
        _buildCalendarGrid(),
      ],
    ),
  );
}



  Widget _buildWeekdayRow() {
    const labels = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];
    return Row(
      children: labels
          .map((l) => Expanded(
                child: Center(
                  child: Text(l,
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.black54)),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildCalendarGrid() {
    final firstDay = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    final daysInMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0).day;
    // Monday = 1 ... Sunday = 7  -> leading blanks before day 1
    final leadingBlanks = firstDay.weekday - 1;

    final totalCells = leadingBlanks + daysInMonth;
    final rows = (totalCells / 7).ceil();

    final today = DateTime.now();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: rows * 7,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
      ),
      itemBuilder: (_, index) {
        final dayNum = index - leadingBlanks + 1;
        if (dayNum < 1 || dayNum > daysInMonth) {
          return const SizedBox.shrink();
        }

        final date = DateTime(_visibleMonth.year, _visibleMonth.month, dayNum);
        final key = _dateKey(date);
        final hasEntry = _entriesByDate.containsKey(key);
        final isSelected = _selectedDate != null && _dateKey(_selectedDate!) == key;
        final isToday = _dateKey(today) == key;

        return GestureDetector(
          onTap: () => _selectDate(date),
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withOpacity(0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: isToday
                  ? Border.all(color: AppColors.primary, width: 1)
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('$dayNum',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                        color: Colors.black87)),
                const SizedBox(height: 2),
                if (hasEntry)
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _ratingLabel(int? value) {
    switch (value) {
      case 1: return 'Low';
      case 2: return 'Mild';
      case 3: return 'Moderate';
      case 4: return 'High';
      default: return '—';
    }
  }

  Widget _buildEntryPreview() {
    final key = _dateKey(_selectedDate!);
    final entry = _entriesByDate[key];

    if (entry == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Text(
              'No entry for ${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _openEntry(),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add entry for this day'),
            ),
          ],
        ),
      );
    }

    final photoUrl = entry['photo_url'] as String?;
    final notes = entry['notes'] as String? ?? '';

    return GestureDetector(
      onTap: () => _openEntry(existing: entry),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (photoUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      photoUrl,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 56,
                        height: 56,
                        color: AppColors.cardBackground,
                        child: const Icon(Icons.image_not_supported_outlined),
                      ),
                    ),
                  )
                else
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.photo_camera_outlined),
                  ),
                const SizedBox(width: 14),
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _ratingChip('Oiliness', entry['oiliness'] as int?),
                      _ratingChip('Redness', entry['redness'] as int?),
                      _ratingChip('Breakout', entry['breakout'] as int?),
                      _ratingChip('Hydration', entry['hydration'] as int?),
                    ],
                  ),
                ),
              ],
            ),
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(notes, style: const TextStyle(fontSize: 13, height: 1.4)),
            ],
            const SizedBox(height: 12),
            const Text('Products used',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            if (_loadingProducts)
              const SizedBox(
                  height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
            else if (_selectedProducts.isEmpty)
              const Text('No products tagged',
                  style: TextStyle(fontSize: 12, color: Colors.black54))
            else
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _selectedProducts
                    .map((p) => Chip(
                          label: Text(p['product_name'] as String? ?? '',
                              style: const TextStyle(fontSize: 11)),
                          backgroundColor: AppColors.cardBackground,
                        ))
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _ratingChip(String label, int? value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.secondaryLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('$label: ${_ratingLabel(value)}',
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }
}