import 'package:flutter/material.dart';
import 'package:skin_mate/core/constants/app_colors.dart';
import 'package:skin_mate/core/models/ingredient_model.dart';
import 'package:skin_mate/core/services/supabase_service.dart';
import 'package:skin_mate/core/widgets/loading_spinner.dart';
import 'package:skin_mate/core/widgets/risk_badge.dart';
import 'ingredient_form.dart';

class IngredientsScreen extends StatefulWidget {
  const IngredientsScreen({super.key});

  @override
  State<IngredientsScreen> createState() => _IngredientsScreenState();
}

class _IngredientsScreenState extends State<IngredientsScreen> {

  // ── State ─────────────────────────────────────────────
  bool    _loading = true;
  String? _error;

  List<IngredientModel> _allIngredients = [];
  List<IngredientModel> _filtered       = [];

  final _searchController = TextEditingController();

  String? _riskFilter;

  int  _sortColumnIndex = 0;
  bool _sortAscending   = true;

  // ── Pagination ────────────────────────────────────────
  int _currentPage  = 0;
  int _rowsPerPage  = 15;

  static const List<int> _rowsPerPageOptions = [10, 15, 25, 50];

  // Slice of _filtered shown on the current page
  List<IngredientModel> get _pageItems {
    final start = _currentPage * _rowsPerPage;
    final end   = (start + _rowsPerPage).clamp(0, _filtered.length);
    return _filtered.sublist(start, end);
  }

  int get _totalPages => (_filtered.length / _rowsPerPage).ceil();

  // ─────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadIngredients();
    _searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────
  // LOAD
  // ─────────────────────────────────────────────────────
  Future<void> _loadIngredients() async {
    setState(() { _loading = true; _error = null; });

    try {
      final rows = await SupabaseService.client
          .from('INGREDIENT')
          .select()
          .order('scientific_name_inci', ascending: true);

      final list = IngredientModel.fromJsonList(rows as List);

      setState(() {
        _allIngredients = list;
        _loading        = false;
      });

      _applyFilters();
    } catch (e) {
      setState(() {
        _error   = 'Failed to load ingredients.\n$e';
        _loading = false;
      });
    }
  }

  // ─────────────────────────────────────────────────────
  // FILTER
  // ─────────────────────────────────────────────────────
  void _applyFilters() {
    final query = _searchController.text.trim().toLowerCase();
    List<IngredientModel> result = _allIngredients;

    if (_riskFilter != null) {
      result = result.where((i) => i.riskLevel.toUpperCase() == _riskFilter).toList();
    }

    if (query.isNotEmpty) {
      result = result.where((i) {
        final inci   = i.inci.toLowerCase();
        final common = (i.commonName ?? '').toLowerCase();
        return inci.contains(query) || common.contains(query);
      }).toList();
    }

    setState(() {
      _filtered    = result;
      _currentPage = 0; // reset to first page on filter change
    });
  }

  // ─────────────────────────────────────────────────────
  // SORT
  // Column indices:
  //  0 = Ingredient ID   6 = EU Restricted
  //  1 = INCI Name       7 = Source
  //  2 = Common Name     8 = Skin Type / Concern
  //  3 = Risk Level      9 = Created By
  //  4 = Purpose        10 = Updated At
  //  5 = Warning        11 = Actions (no sort)
  // ─────────────────────────────────────────────────────
  void _sort(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending   = ascending;
    });

    _filtered.sort((a, b) {
      int compare;
      switch (columnIndex) {
        case 0:  compare = a.ingredientID.compareTo(b.ingredientID); break;
        case 1:  compare = a.inci.compareTo(b.inci); break;
        case 2:  compare = (a.commonName ?? '').compareTo(b.commonName ?? ''); break;
        case 3:  compare = a.riskLevel.compareTo(b.riskLevel); break;
        case 4:  compare = (a.purposeText ?? '').compareTo(b.purposeText ?? ''); break;
        case 5:  compare = (a.warningExplanation ?? '').compareTo(b.warningExplanation ?? ''); break;
        case 6:  compare = (a.euRestricted ?? '').compareTo(b.euRestricted ?? ''); break;
        case 7:  compare = (a.source ?? '').compareTo(b.source ?? ''); break;
        case 8:  compare = (a.skinTypeConcern ?? '').compareTo(b.skinTypeConcern ?? ''); break;
        case 9:  compare = (a.createdBy ?? '').compareTo(b.createdBy ?? ''); break;
        case 10: compare = (a.updatedAt ?? DateTime(0)).compareTo(b.updatedAt ?? DateTime(0)); break;
        default: compare = 0;
      }
      return ascending ? compare : -compare;
    });

    setState(() => _currentPage = 0);
  }

  // ─────────────────────────────────────────────────────
  // OPEN FORM
  // ─────────────────────────────────────────────────────
  Future<void> _openForm({IngredientModel? ingredient}) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => IngredientForm(ingredient: ingredient)),
    );
    if (saved == true) _loadIngredients();
  }

  // ─────────────────────────────────────────────────────
  // DELETE
  // ─────────────────────────────────────────────────────
  Future<void> _deleteIngredient(IngredientModel ingredient) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete ingredient?',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
        content: Text(
          'This will permanently delete "${ingredient.displayName}" '
          'and all its risk profiles.\n\nThis cannot be undone.',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.allergenColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await SupabaseService.client
          .from('INGREDIENT')
          .delete()
          .eq('ingredientID', ingredient.ingredientID);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('"${ingredient.displayName}" deleted successfully'),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));

      _loadIngredients();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Delete failed: $e'),
        backgroundColor: AppColors.allergenColor,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  // ─────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _loading
          ? const LoadingSpinner(message: 'Loading ingredients...')
          : _error != null
              ? _buildError()
              : _buildContent(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: AppColors.primary, size: 48),
          const SizedBox(height: 16),
          Text(_error!, textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _loadIngredients,
            icon:  const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 20),
          _buildToolbar(),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              '${_filtered.length} of ${_allIngredients.length} ingredients',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
          Expanded(child: _filtered.isEmpty ? _buildEmpty() : _buildTable()),
          if (_filtered.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildPaginationBar(),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ingredient Management',
                style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary, letterSpacing: -0.3)),
              Text('View, add, edit and delete ingredients in the knowledge base',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            ],
          ),
        ),
        ElevatedButton.icon(
          onPressed: () => _openForm(),
          icon:  const Icon(Icons.add_rounded, size: 18),
          label: const Text('Add Ingredient'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            elevation: 0,
          ),
        ),
      ],
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: SizedBox(
              height: 40,
              child: TextField(
                controller: _searchController,
                style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Search by INCI name or common name...',
                  hintStyle: const TextStyle(fontSize: 13, color: AppColors.textHint),
                  prefixIcon: const Icon(Icons.search_rounded,
                    color: AppColors.textSecondary, size: 18),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded,
                            size: 16, color: AppColors.textSecondary),
                          onPressed: () {
                            _searchController.clear();
                            _applyFilters();
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(9),
                    borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: AppColors.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: _riskFilter,
                icon: const Icon(Icons.keyboard_arrow_down_rounded,
                  color: AppColors.textSecondary, size: 18),
                style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All risk levels')),
                  ...[
                    ('SAFE',     AppColors.safeColor,     '✓  Safe'),
                    ('CAUTION',  AppColors.cautionColor,  '⚠  Caution'),
                    ('ALLERGEN', AppColors.allergenColor, '✗  Allergen'),
                  ].map((t) => DropdownMenuItem(
                    value: t.$1,
                    child: Row(children: [
                      Container(width: 8, height: 8,
                        decoration: BoxDecoration(color: t.$2, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Text(t.$3),
                    ]),
                  )),
                ],
                onChanged: (val) {
                  setState(() => _riskFilter = val);
                  _applyFilters();
                },
              ),
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            onPressed: _loadIngredients,
            icon: const Icon(Icons.refresh_rounded),
            color: AppColors.textSecondary,
            tooltip: 'Refresh',
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  // PAGINATION BAR
  // ─────────────────────────────────────────────────────
  Widget _buildPaginationBar() {
    final startItem = _filtered.isEmpty ? 0 : _currentPage * _rowsPerPage + 1;
    final endItem   = ((_currentPage + 1) * _rowsPerPage).clamp(0, _filtered.length);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // ── Rows per page ──
          const Text('Rows per page:',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(width: 8),
          DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _rowsPerPage,
              isDense: true,
              style: const TextStyle(
                fontSize: 12, color: AppColors.textPrimary,
                fontWeight: FontWeight.w600),
              items: _rowsPerPageOptions
                  .map((n) => DropdownMenuItem(value: n, child: Text('$n')))
                  .toList(),
              onChanged: (val) {
                if (val == null) return;
                setState(() {
                  _rowsPerPage  = val;
                  _currentPage  = 0;
                });
              },
            ),
          ),

          const Spacer(),

          // ── Range label ──
          Text(
            '$startItem–$endItem of ${_filtered.length}',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(width: 16),

          // ── Navigation buttons ──
          _PageButton(
            icon: Icons.first_page_rounded,
            tooltip: 'First page',
            enabled: _currentPage > 0,
            onTap: () => setState(() => _currentPage = 0),
          ),
          const SizedBox(width: 4),
          _PageButton(
            icon: Icons.chevron_left_rounded,
            tooltip: 'Previous page',
            enabled: _currentPage > 0,
            onTap: () => setState(() => _currentPage--),
          ),

          // ── Page number pills ──
          const SizedBox(width: 6),
          ..._buildPagePills(),
          const SizedBox(width: 6),

          _PageButton(
            icon: Icons.chevron_right_rounded,
            tooltip: 'Next page',
            enabled: _currentPage < _totalPages - 1,
            onTap: () => setState(() => _currentPage++),
          ),
          const SizedBox(width: 4),
          _PageButton(
            icon: Icons.last_page_rounded,
            tooltip: 'Last page',
            enabled: _currentPage < _totalPages - 1,
            onTap: () => setState(() => _currentPage = _totalPages - 1),
          ),
        ],
      ),
    );
  }

  /// Renders up to 5 page-number pills with ellipsis when needed.
  List<Widget> _buildPagePills() {
    if (_totalPages <= 1) return [];

    final pills = <Widget>[];

    // Build the set of page indices to show
    final Set<int> indices = {};
    indices.add(0);
    indices.add(_totalPages - 1);
    for (int i = _currentPage - 1; i <= _currentPage + 1; i++) {
      if (i >= 0 && i < _totalPages) indices.add(i);
    }

    final sorted = indices.toList()..sort();
    int? prev;

    for (final idx in sorted) {
      if (prev != null && idx - prev > 1) {
        // Ellipsis gap
        pills.add(const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text('…',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ));
      }
      pills.add(_buildPagePill(idx));
      prev = idx;
    }

    return pills;
  }

  Widget _buildPagePill(int pageIndex) {
    final isActive = pageIndex == _currentPage;

    return GestureDetector(
      onTap: () => setState(() => _currentPage = pageIndex),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width:  30,
        height: 30,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          border: isActive
              ? null
              : Border.all(color: AppColors.border),
        ),
        alignment: Alignment.center,
        child: Text(
          '${pageIndex + 1}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            color: isActive ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  // DATA TABLE
  // ─────────────────────────────────────────────────────
  Widget _buildTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(
            child: DataTable(
              sortColumnIndex: _sortColumnIndex,
              sortAscending:   _sortAscending,
              columnSpacing:   24,
              headingRowHeight: 46,
              dataRowMinHeight: 52,
              dataRowMaxHeight: 64,
              headingRowColor: WidgetStateProperty.all(
                AppColors.secondaryLight.withOpacity(0.5)),
              dividerThickness: 0.5,

              // ── Columns ───────────────────────────────
              columns: [
                // 0
                DataColumn(
                  label: const Text('Ingredient ID',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary)),
                  onSort: (col, asc) => _sort(col, asc),
                ),
                // 1
                DataColumn(
                  label: const Text('INCI Name',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary)),
                  onSort: (col, asc) => _sort(col, asc),
                ),
                // 2
                DataColumn(
                  label: const Text('Common Name',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary)),
                  onSort: (col, asc) => _sort(col, asc),
                ),
                // 3
                DataColumn(
                  label: const Text('Risk Level',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary)),
                  onSort: (col, asc) => _sort(col, asc),
                ),
                // 4
                DataColumn(
                  label: const Text('Purpose',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary)),
                  onSort: (col, asc) => _sort(col, asc),
                ),
                // 5
                DataColumn(
                  label: const Text('Warning',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary)),
                  onSort: (col, asc) => _sort(col, asc),
                ),
                // 6
                DataColumn(
                  label: const Text('EU Restricted',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary)),
                  onSort: (col, asc) => _sort(col, asc),
                ),
                // 7
                DataColumn(
                  label: const Text('Source',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary)),
                  onSort: (col, asc) => _sort(col, asc),
                ),
                // 8
                DataColumn(
                  label: const Text('Skin Type / Concern',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary)),
                  onSort: (col, asc) => _sort(col, asc),
                ),
                // 9
                DataColumn(
                  label: const Text('Created By',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary)),
                  onSort: (col, asc) => _sort(col, asc),
                ),
                // 10
                DataColumn(
                  label: const Text('Updated At',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary)),
                  onSort: (col, asc) => _sort(col, asc),
                ),
                // 11 — no sort
                const DataColumn(
                  label: Text('Actions',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary)),
                ),
              ],

              // Only render the current page slice
              rows: _pageItems.map((ing) => _buildRow(ing)).toList(),
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  // ROW
  // ─────────────────────────────────────────────────────
  DataRow _buildRow(IngredientModel ing) {
    final updatedAt = ing.updatedAt != null
        ? '${ing.updatedAt!.year}-'
          '${ing.updatedAt!.month.toString().padLeft(2, '0')}-'
          '${ing.updatedAt!.day.toString().padLeft(2, '0')}'
        : '—';

    return DataRow(
      color: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.hovered)) return AppColors.background;
        return null;
      }),
      cells: [

        // 0 — Ingredient ID
        DataCell(
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: Text(
              ing.ingredientID,
              style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700,
                color: AppColors.primary, fontFamily: 'monospace'),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),

        // 1 — INCI Name
        DataCell(
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(
              ing.inci,
              style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600,
                color: AppColors.textPrimary),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ),

        // 2 — Common Name
        DataCell(
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Text(
              ing.commonName ?? '—',
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),

        // 3 — Risk Level
        DataCell(RiskBadge(flag: ing.riskLevel, size: RiskBadgeSize.small)),

        // 4 — Purpose
        DataCell(
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 200),
            child: Text(
              ing.purposeText ?? '—',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ),

        // 5 — Warning
        DataCell(
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(
              ing.warningExplanation ?? '—',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ),

        // 6 — EU Restricted
        DataCell(
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 100),
            child: Text(
              ing.euRestricted ?? '—',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),

        // 7 — Source
        DataCell(
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Text(
              ing.source ?? '—',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),

        // 8 — Skin Type / Concern
        DataCell(
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 200),
            child: Text(
              ing.skinTypeConcern ?? '—',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ),

        // 9 — Created By
        DataCell(
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: Text(
              ing.createdBy ?? '—',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),

        // 10 — Updated At
        DataCell(
          Text(
            updatedAt,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ),

        // 11 — Actions
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Tooltip(
                message: 'Edit',
                child: InkWell(
                  onTap: () => _openForm(ingredient: ing),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppColors.secondaryLight,
                      borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.edit_outlined,
                      size: 15, color: AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: 'Delete',
                child: InkWell(
                  onTap: () => _deleteIngredient(ing),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppColors.allergenBg,
                      borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.delete_outline_rounded,
                      size: 15, color: AppColors.allergenColor),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────
  // EMPTY STATE
  // ─────────────────────────────────────────────────────
  Widget _buildEmpty() {
    final hasFilters = _searchController.text.isNotEmpty || _riskFilter != null;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasFilters ? Icons.search_off_rounded : Icons.science_outlined,
            color: AppColors.textSecondary.withOpacity(0.3),
            size:  52,
          ),
          const SizedBox(height: 14),
          Text(
            hasFilters ? 'No ingredients match your search' : 'No ingredients yet',
            style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w600,
              color: AppColors.textSecondary.withOpacity(0.6)),
          ),
          const SizedBox(height: 6),
          Text(
            hasFilters
                ? 'Try a different search term or clear the filters'
                : 'Click "Add Ingredient" to add your first ingredient',
            style: TextStyle(
              fontSize: 12, color: AppColors.textSecondary.withOpacity(0.45)),
          ),
          if (hasFilters) ...[
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () {
                _searchController.clear();
                setState(() => _riskFilter = null);
                _applyFilters();
              },
              icon:  const Icon(Icons.clear_all_rounded, size: 16),
              label: const Text('Clear filters'),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
// HELPER — icon navigation button
// ─────────────────────────────────────────────────────
class _PageButton extends StatelessWidget {
  const _PageButton({
    required this.icon,
    required this.tooltip,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String   tooltip;
  final bool     enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(7),
        child: Container(
          width: 30, height: 30,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(7),
            color: enabled ? Colors.white : AppColors.background,
          ),
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 16,
            color: enabled ? AppColors.textSecondary : AppColors.textHint,
          ),
        ),
      ),
    );
  }
}