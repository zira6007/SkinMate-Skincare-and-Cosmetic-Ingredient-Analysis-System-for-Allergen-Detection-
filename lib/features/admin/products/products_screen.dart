import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:skin_mate/core/constants/app_colors.dart';
import 'package:skin_mate/core/models/product_model.dart';
import 'package:skin_mate/core/services/supabase_service.dart';
import 'package:skin_mate/core/widgets/loading_spinner.dart';
import 'product_form.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen>
    with AutomaticKeepAliveClientMixin {
  // ── Keep alive when switching admin tabs ─────────────
  @override
  bool get wantKeepAlive => true;

  // ── Pagination ───────────────────────────────────────
  int _currentPage = 0;
  int _rowsPerPage  = 25;

  static const List<int> _rowsPerPageOptions = [10, 25, 50, 100];

  List<ProductModel> get _pageItems {
    final start = _currentPage * _rowsPerPage;
    final end   = (start + _rowsPerPage).clamp(0, _filtered.length);
    return _filtered.sublist(start, end);
  }

  int get _totalPages =>
      _filtered.isEmpty ? 1 : (_filtered.length / _rowsPerPage).ceil();

  // ── State ─────────────────────────────────────────────
  bool   _loading = true;
  String? _error;

  List<ProductModel> _allProducts = [];
  List<ProductModel> _filtered    = [];

  /// Cached category list — recomputed only on load, not every build.
  List<String> _cachedCategories = [];

  final _searchController = TextEditingController();

  // Filter: null = all, true = active only, false = inactive only
  bool?   _activeFilter;
  String? _categoryFilter;

  // Sort
  int  _sortColumnIndex = 2;
  bool _sortAscending   = true;

  // Track which rows are currently being toggled
  final Set<String> _togglingIds = {};

  // ─────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadProducts();
    _searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────
  // LOAD PRODUCTS
  // ─────────────────────────────────────────────────────
  Future<void> _loadProducts() async {
    setState(() {
      _loading = true;
      _error   = null;
    });

    try {
      final rows = await SupabaseService.client
          .from('PRODUCT')
          .select()
          .order('brand_name', ascending: true);

      final list = ProductModel.fromJsonList(rows as List);

      final cats = list
          .map((p) => p.categoryTag?.toLowerCase())
          .whereType<String>()
          .toSet()
          .toList()
        ..sort();

      setState(() {
        _allProducts      = list;
        _cachedCategories = cats;
        _loading          = false;
      });

      _applyFilters();
    } catch (e) {
      setState(() {
        _error   = 'Failed to load products.\n$e';
        _loading = false;
      });
    }
  }

  // ─────────────────────────────────────────────────────
  // APPLY FILTERS — always resets to page 0 unless told not to
  // ─────────────────────────────────────────────────────
  void _applyFilters({bool resetPage = true}) {
    final query = _searchController.text.trim().toLowerCase();

    List<ProductModel> result = _allProducts;

    if (_activeFilter != null) {
      result = result.where((p) => p.isActive == _activeFilter).toList();
    }

    if (_categoryFilter != null) {
      result = result
          .where((p) => p.categoryTag?.toLowerCase() == _categoryFilter)
          .toList();
    }

    if (query.isNotEmpty) {
      result = result.where((p) {
        return p.brandName.toLowerCase().contains(query) ||
            p.productName.toLowerCase().contains(query) ||
            (p.barcode ?? '').contains(query);
      }).toList();
    }

    setState(() {
      _filtered    = result;
      if (resetPage) _currentPage = 0;
    });
  }

  // ─────────────────────────────────────────────────────
  // SORT
  // ─────────────────────────────────────────────────────
  void _sort(int columnIndex, bool ascending) {
    _filtered.sort((a, b) {
      int compare;
      switch (columnIndex) {
        case 1:  compare = a.productID.compareTo(b.productID); break;
        case 2:  compare = a.brandName.compareTo(b.brandName); break;
        case 3:  compare = a.productName.compareTo(b.productName); break;
        case 4:  compare = (a.categoryTag ?? '').compareTo(b.categoryTag ?? ''); break;
        case 5:  compare = (a.skinTypeTarget ?? '').compareTo(b.skinTypeTarget ?? ''); break;
        case 6:  compare = (a.countryOrigin ?? '').compareTo(b.countryOrigin ?? ''); break;
        case 7:  compare = a.rating.compareTo(b.rating); break;
        case 8:  compare = (a.barcode ?? '').compareTo(b.barcode ?? ''); break;
        default: compare = 0;
      }
      return ascending ? compare : -compare;
    });

    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending   = ascending;
      _currentPage     = 0;
    });
  }

  // ─────────────────────────────────────────────────────
  // TOGGLE is_active
  // ─────────────────────────────────────────────────────
  Future<void> _toggleActive(ProductModel product) async {
    setState(() => _togglingIds.add(product.productID));

    try {
      final newValue = !product.isActive;

      await SupabaseService.client
          .from('PRODUCT')
          .update({'is_active': newValue})
          .eq('productID', product.productID);

      if (!mounted) return;

      setState(() {
        final idx = _allProducts.indexWhere((p) => p.productID == product.productID);
        if (idx != -1) {
          _allProducts[idx] = product.copyWith(isActive: newValue);
        }
        _togglingIds.remove(product.productID);
      });

      _applyFilters(resetPage: false);

      if (_currentPage >= _totalPages) {
        setState(() => _currentPage = (_totalPages - 1).clamp(0, _totalPages - 1));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _togglingIds.remove(product.productID));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Update failed: $e'),
        backgroundColor: AppColors.allergenColor,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  // ─────────────────────────────────────────────────────
  // OPEN PRODUCT FORM
  // ─────────────────────────────────────────────────────
  Future<void> _openForm({ProductModel? product}) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ProductForm(product: product)),
    );
    if (saved == true) _loadProducts();
  }

  // ─────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _loading
          ? const LoadingSpinner(message: 'Loading products...')
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
          Text(_error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _loadProducts,
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
              '${_filtered.length} of ${_allProducts.length} products',
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

  // ─────────────────────────────────────────────────────
  // HEADER
  // ─────────────────────────────────────────────────────
  Widget _buildHeader() {
    final activeCount   = _allProducts.where((p) => p.isActive).length;
    final inactiveCount = _allProducts.length - activeCount;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Product Management',
                style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary, letterSpacing: -0.3)),
              Row(
                children: [
                  const Text('Manage products in the database · ',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  Text('$activeCount active',
                    style: const TextStyle(
                      fontSize: 13, color: AppColors.safeColor,
                      fontWeight: FontWeight.w600)),
                  Text(' · $inactiveCount inactive',
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                ],
              ),
            ],
          ),
        ),
        ElevatedButton.icon(
          onPressed: () => _openForm(),
          icon:  const Icon(Icons.add_rounded, size: 18),
          label: const Text('Add Product'),
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

  // ─────────────────────────────────────────────────────
  // TOOLBAR
  // ─────────────────────────────────────────────────────
  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 320, height: 40,
            child: TextField(
              controller: _searchController,
              style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search by brand, name, or barcode...',
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

          if (_cachedCategories.isNotEmpty)
            _dropdownFilter<String?>(
              value: _categoryFilter,
              hint: 'All categories',
              items: [
                const DropdownMenuItem(value: null, child: Text('All categories')),
                ..._cachedCategories.map((cat) => DropdownMenuItem(
                  value: cat,
                  child: Text(cat[0].toUpperCase() + cat.substring(1),
                    style: const TextStyle(fontSize: 13)),
                )),
              ],
              onChanged: (val) {
                setState(() => _categoryFilter = val);
                _applyFilters();
              },
            ),

          _dropdownFilter<bool?>(
            value: _activeFilter,
            hint: 'All statuses',
            items: const [
              DropdownMenuItem(value: null,  child: Text('All statuses')),
              DropdownMenuItem(value: true,  child: Text('Active only')),
              DropdownMenuItem(value: false, child: Text('Inactive only')),
            ],
            onChanged: (val) {
              setState(() => _activeFilter = val);
              _applyFilters();
            },
          ),

          IconButton(
            onPressed: _loadProducts,
            icon: const Icon(Icons.refresh_rounded),
            color: AppColors.textSecondary,
            tooltip: 'Refresh',
          ),

          if (_searchController.text.isNotEmpty ||
              _categoryFilter != null ||
              _activeFilter != null)
            TextButton.icon(
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _categoryFilter = null;
                  _activeFilter   = null;
                });
                _applyFilters();
              },
              icon:  const Icon(Icons.clear_all_rounded, size: 16),
              label: const Text('Clear filters'),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            ),
        ],
      ),
    );
  }

  Widget _dropdownFilter<T>({
    required T value,
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
            color: AppColors.textSecondary, size: 18),
          style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
          items: items,
          onChanged: onChanged,
        ),
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
                  _rowsPerPage = val;
                  _currentPage = 0;
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

          // ── Navigation ──
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

  List<Widget> _buildPagePills() {
    if (_totalPages <= 1) return [];

    final Set<int> indices = {};
    indices.add(0);
    indices.add(_totalPages - 1);
    for (int i = _currentPage - 1; i <= _currentPage + 1; i++) {
      if (i >= 0 && i < _totalPages) indices.add(i);
    }

    final sorted = indices.toList()..sort();
    final pills  = <Widget>[];
    int? prev;

    for (final idx in sorted) {
      if (prev != null && idx - prev > 1) {
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
        width: 30, height: 30,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          border: isActive ? null : Border.all(color: AppColors.border),
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
  // DATA TABLE — only renders current page rows
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
              columnSpacing:   20,
              headingRowHeight: 46,
              dataRowMinHeight: 60,
              dataRowMaxHeight: 72,
              headingRowColor: WidgetStateProperty.all(
                AppColors.secondaryLight.withOpacity(0.5)),
              dividerThickness: 0.5,
              columns: [
                // 0 — Image (not sortable)
                const DataColumn(
                  label: Text('Image',
                    style: TextStyle(fontWeight: FontWeight.w700,
                      fontSize: 13, color: AppColors.textPrimary)),
                ),
                // 1 — Product ID
                DataColumn(
                  label: const Text('Product ID',
                    style: TextStyle(fontWeight: FontWeight.w700,
                      fontSize: 13, color: AppColors.textPrimary)),
                  onSort: _sort,
                ),
                // 2 — Brand
                DataColumn(
                  label: const Text('Brand',
                    style: TextStyle(fontWeight: FontWeight.w700,
                      fontSize: 13, color: AppColors.textPrimary)),
                  onSort: _sort,
                ),
                // 3 — Product Name
                DataColumn(
                  label: const Text('Product Name',
                    style: TextStyle(fontWeight: FontWeight.w700,
                      fontSize: 13, color: AppColors.textPrimary)),
                  onSort: _sort,
                ),
                // 4 — Category
                DataColumn(
                  label: const Text('Category',
                    style: TextStyle(fontWeight: FontWeight.w700,
                      fontSize: 13, color: AppColors.textPrimary)),
                  onSort: _sort,
                ),
                // 5 — Skin Type
                DataColumn(
                  label: const Text('Skin Type',
                    style: TextStyle(fontWeight: FontWeight.w700,
                      fontSize: 13, color: AppColors.textPrimary)),
                  onSort: _sort,
                ),
                // 6 — Country Origin
                DataColumn(
                  label: const Text('Country Origin',
                    style: TextStyle(fontWeight: FontWeight.w700,
                      fontSize: 13, color: AppColors.textPrimary)),
                  onSort: _sort,
                ),
                // 7 — Rating
                DataColumn(
                  label: const Text('Rating',
                    style: TextStyle(fontWeight: FontWeight.w700,
                      fontSize: 13, color: AppColors.textPrimary)),
                  onSort: _sort,
                ),
                // 8 — Barcode
                DataColumn(
                  label: const Text('Barcode',
                    style: TextStyle(fontWeight: FontWeight.w700,
                      fontSize: 13, color: AppColors.textPrimary)),
                  onSort: _sort,
                ),
                // 9 — Description (not sortable)
                const DataColumn(
                  label: Text('Description',
                    style: TextStyle(fontWeight: FontWeight.w700,
                      fontSize: 13, color: AppColors.textPrimary)),
                ),
                // 10 — Active (not sortable)
                const DataColumn(
                  label: Text('Active',
                    style: TextStyle(fontWeight: FontWeight.w700,
                      fontSize: 13, color: AppColors.textPrimary)),
                ),
                // 11 — Actions (not sortable)
                const DataColumn(
                  label: Text('Actions',
                    style: TextStyle(fontWeight: FontWeight.w700,
                      fontSize: 13, color: AppColors.textPrimary)),
                ),
              ],
              // ← Only renders the current page slice
              rows: _pageItems.map((p) => _buildRow(p)).toList(),
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  // SINGLE ROW
  // ─────────────────────────────────────────────────────
  DataRow _buildRow(ProductModel product) {
    final isToggling = _togglingIds.contains(product.productID);

    return DataRow(
      onSelectChanged: (_) => _openForm(product: product),
      color: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected) ||
            states.contains(WidgetState.hovered)) {
          return AppColors.background;
        }
        if (!product.isActive) return AppColors.background.withOpacity(0.5);
        return null;
      }),
      cells: [
        // ── Image ─────────────────────────────────────
        DataCell(_buildThumbnail(product.imageUrl)),

        // ── Product ID ────────────────────────────────
        DataCell(
          Text(product.productID,
            style: const TextStyle(
              fontFamily: 'Courier New', fontSize: 11,
              color: AppColors.textSecondary)),
        ),

        // ── Brand ─────────────────────────────────────
        DataCell(
          Text(product.brandName,
            style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600,
              color: product.isActive
                  ? AppColors.textPrimary : AppColors.textSecondary)),
        ),

        // ── Product Name ──────────────────────────────
        DataCell(
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 200),
            child: Text(product.productName,
              style: TextStyle(
                fontSize: 13,
                color: product.isActive
                    ? AppColors.textPrimary : AppColors.textSecondary),
              overflow: TextOverflow.ellipsis,
              maxLines: 2),
          ),
        ),

        // ── Category ──────────────────────────────────
        DataCell(
          product.categoryTag != null
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryLight,
                    borderRadius: BorderRadius.circular(10)),
                  child: Text(
                    product.categoryTag![0].toUpperCase() +
                        product.categoryTag!.substring(1),
                    style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600,
                      color: AppColors.primary)),
                )
              : const Text('—',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        ),

        // ── Skin Type ─────────────────────────────────
        DataCell(
          product.skinTypeTarget != null
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border)),
                  child: Text(product.skinTypeTarget!,
                    style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary)),
                )
              : const Text('—',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        ),

        // ── Country Origin ────────────────────────────
        DataCell(
          Text(product.countryOrigin ?? '—',
            style: TextStyle(
              fontSize: 13,
              color: product.countryOrigin != null
                  ? AppColors.textPrimary : AppColors.textSecondary)),
        ),

        // ── Rating ────────────────────────────────────
        DataCell(
          product.rating > 0
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star_rounded,
                      size: 14, color: Color(0xFFFABF00)),
                    const SizedBox(width: 4),
                    Text(product.rating.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                  ],
                )
              : const Text('—',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        ),

        // ── Barcode ───────────────────────────────────
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (product.hasBarcode) ...[
                const Icon(Icons.qr_code_rounded,
                  size: 13, color: AppColors.textSecondary),
                const SizedBox(width: 5),
              ],
              Text(product.barcode ?? '—',
                style: const TextStyle(
                  fontFamily: 'Courier New', fontSize: 12,
                  color: AppColors.textSecondary)),
            ],
          ),
        ),

        // ── Description ───────────────────────────────
        DataCell(
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(product.description ?? '—',
              style: const TextStyle(
                fontSize: 12, color: AppColors.textSecondary),
              overflow: TextOverflow.ellipsis,
              maxLines: 2),
          ),
        ),

        // ── Active toggle ─────────────────────────────
        DataCell(
          isToggling
              ? const SizedBox(
                  width: 22, height: 22,
                  child: CircularProgressIndicator(
                    color: AppColors.primary, strokeWidth: 2))
              : Switch(
                  value: product.isActive,
                  activeColor: AppColors.safeColor,
                  inactiveThumbColor: AppColors.textSecondary.withOpacity(0.4),
                  inactiveTrackColor: AppColors.border,
                  onChanged: (_) => _toggleActive(product),
                ),
        ),

        // ── Actions ───────────────────────────────────
        DataCell(
          Tooltip(
            message: 'Edit',
            child: InkWell(
              onTap: () => _openForm(product: product),
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
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────
  // PRODUCT IMAGE THUMBNAIL
  // ─────────────────────────────────────────────────────
  Widget _buildThumbnail(String? imageUrl) {
    return Container(
      width: 46, height: 46,
      decoration: BoxDecoration(
        color: AppColors.secondaryLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: imageUrl != null && imageUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: imageUrl,
                width: 46, height: 46,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _placeholderIcon(),
                placeholder: (_, __) => const Center(
                  child: SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(
                      color: AppColors.primary, strokeWidth: 1.5),
                  ),
                ),
              )
            : _placeholderIcon(),
      ),
    );
  }

  Widget _placeholderIcon() => const Center(
    child: Icon(Icons.inventory_2_outlined,
      color: AppColors.textSecondary, size: 20),
  );

  // ─────────────────────────────────────────────────────
  // EMPTY STATE
  // ─────────────────────────────────────────────────────
  Widget _buildEmpty() {
    final hasFilters = _searchController.text.isNotEmpty ||
        _categoryFilter != null ||
        _activeFilter != null;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasFilters ? Icons.search_off_rounded : Icons.inventory_2_outlined,
            color: AppColors.textSecondary.withOpacity(0.3),
            size:  52,
          ),
          const SizedBox(height: 14),
          Text(
            hasFilters ? 'No products match your search' : 'No products yet',
            style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w600,
              color: AppColors.textSecondary.withOpacity(0.6)),
          ),
          const SizedBox(height: 6),
          Text(
            hasFilters
                ? 'Try a different term or clear filters'
                : 'Click "Add Product" to add your first product',
            style: TextStyle(
              fontSize: 12, color: AppColors.textSecondary.withOpacity(0.45)),
          ),
          if (hasFilters) ...[
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _categoryFilter = null;
                  _activeFilter   = null;
                });
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

  final IconData     icon;
  final String       tooltip;
  final bool         enabled;
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
          child: Icon(icon,
            size: 16,
            color: enabled ? AppColors.textSecondary : AppColors.textHint),
        ),
      ),
    );
  }
}