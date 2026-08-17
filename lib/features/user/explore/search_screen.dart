import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:skin_mate/core/services/supabase_service.dart';
import 'package:skin_mate/core/constants/app_colors.dart';
import 'package:skin_mate/features/user/explore/product_detail_screen.dart';
import 'package:skin_mate/features/user/explore/compare_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MODEL
// ─────────────────────────────────────────────────────────────────────────────

class Product {
  final String id;
  final String brandName;
  final String productName;
  final String? imageUrl;
  final String? category;
  final double? avgRating;
  final bool isFavourite;

  const Product({
    required this.id,
    required this.brandName,
    required this.productName,
    this.imageUrl,
    this.category,
    this.avgRating,
    this.isFavourite = false,
  });

  factory Product.fromJson(Map<String, dynamic> json, {bool isFavourite = false}) =>
      Product(
        id: json['productID']?.toString() ?? '',
        brandName: json['brand_name']?.toString() ?? '',
        productName: json['product_name']?.toString() ?? '',
        imageUrl: json['product_image_url']?.toString(),
        category: json['category_tag']?.toString(),
        avgRating: (json['avg_rating'] as num?)?.toDouble(),
        isFavourite: isFavourite,
      );

  Product copyWith({bool? isFavourite}) => Product(
        id: id,
        brandName: brandName,
        productName: productName,
        imageUrl: imageUrl,
        category: category,
        avgRating: avgRating,
        isFavourite: isFavourite ?? this.isFavourite,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// CONSTANTS
// ─────────────────────────────────────────────────────────────────────────────

const List<String> _kCategories = [
  'All',
  'Moisturiser',
  'Cleanser',
  'Serum',
  'Sunscreen',
  'Toner',
  'Eye Cream',
  'Mask',
  'Cosmetic',
];

// ─────────────────────────────────────────────────────────────────────────────
// SEARCH SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  final _debouncer = _Debouncer(milliseconds: 350);

  String _query = '';
  String _selectedCategory = 'All';
  List<Product> _products = [];
  bool _isLoading = false;
  String? _error;

  // Favourites
  Set<String> _favouriteIds = {};

  // Compare selection — max 2
  final Set<String> _selectedIds = {};
  bool get _compareMode => _selectedIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _fetchProducts();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Search & filter ───────────────────────────────────────────────────────

  void _onSearchChanged() {
    _debouncer.run(() {
      final trimmed = _searchController.text.trim();
      if (trimmed != _query) {
        setState(() => _query = trimmed);
        _fetchProducts();
      }
    });
  }

  Future<void> _fetchFavouriteIds() async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) {
      _favouriteIds = {};
      return;
    }

    try {
      final rows = await SupabaseService.client
          .from('FAVOURITE')
          .select('productID')
          .eq('userID', userId);

      _favouriteIds = (rows as List)
          .map((r) => r['productID'].toString())
          .toSet();
    } catch (_) {
      // Non-fatal — favourites just won't be pre-marked
    }
  }

  Future<void> _fetchProducts() async {
  setState(() {
    _isLoading = true;
    _error = null;
  });

  try {
    var q = SupabaseService.client
        .from('PRODUCT')
        .select('productID, brand_name, product_name, product_image_url, category_tag, avg_rating');

    if (_query.isNotEmpty) {
      q = q.or('product_name.ilike.%$_query%,brand_name.ilike.%$_query%'); // ← changed
    }

    if (_selectedCategory != 'All') {
      q = q.ilike('category_tag', _selectedCategory);
    }

    final data = await q
    .order('brand_name', ascending: true)
    .order('product_name', ascending: true);
    await _fetchFavouriteIds();

      if (!mounted) return;
      setState(() {
        _products = (data as List)
            .map((e) => Product.fromJson(
                  e,
                  isFavourite: _favouriteIds.contains(e['productID'].toString()),
                ))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _onCategorySelected(String category) {
    HapticFeedback.selectionClick();
    setState(() => _selectedCategory = category);
    _fetchProducts();
  }

  // ── Favourite logic ───────────────────────────────────────────────────────

  Future<void> _toggleFavourite(Product product) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please log in to save favourites.'),
          backgroundColor: AppColors.primaryDark,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    HapticFeedback.lightImpact();
    final wasFavourite = product.isFavourite;

    // Optimistic update
    setState(() {
      final idx = _products.indexWhere((p) => p.id == product.id);
      if (idx != -1) {
        _products[idx] = product.copyWith(isFavourite: !wasFavourite);
      }
      if (wasFavourite) {
        _favouriteIds.remove(product.id);
      } else {
        _favouriteIds.add(product.id);
      }
    });

    try {
      if (wasFavourite) {
        await SupabaseService.client
            .from('FAVOURITE')
            .delete()
            .eq('userID', userId)
            .eq('productID', product.id);
      } else {
        await SupabaseService.client.from('FAVOURITE').insert({
          'userID': userId,
          'productID': product.id,
        });
      }
    } catch (e) {
      if (!mounted) return;
      // Revert on failure
      setState(() {
        final idx = _products.indexWhere((p) => p.id == product.id);
        if (idx != -1) {
          _products[idx] = product.copyWith(isFavourite: wasFavourite);
        }
        if (wasFavourite) {
          _favouriteIds.add(product.id);
        } else {
          _favouriteIds.remove(product.id);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update favourite: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  // ── Compare logic ─────────────────────────────────────────────────────────

  void _toggleSelect(String id) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else if (_selectedIds.length < 2) {
        _selectedIds.add(id);
      } else {
        // Replace oldest selection
        _selectedIds.remove(_selectedIds.first);
        _selectedIds.add(id);
      }
    });
  }

  void _navigateToCompare() {
    if (_selectedIds.length < 2) return;
    HapticFeedback.mediumImpact();
    final ids = _selectedIds.toList();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CompareScreen(
          productIdA: ids[0],
          productIdB: ids[1],
        ),
      ),
    );
  }

  void _navigateToDetail(Product product) {
    HapticFeedback.selectionClick();
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ProductDetailScreen(productID: product.id),
    ));
  }

  // ── Info dialog ──────────────────────────────────────────────────────────

  void _showCompareInfoDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              'Comparing products',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ],
        ),
        content: Text(
          'Long-press on any product card to select it for comparison. '
          'Select two products, then tap "Compare" to see them side by side — '
          'including ingredients, risk levels, and how each matches your skin profile.',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Got it',
              style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSearchBar(),
          const SizedBox(height: 4),
          _buildCategoryChips(),
          Expanded(child: _buildBody()),
        ],
      ),
      floatingActionButton: _compareMode ? _buildCompareFAB() : null,
    );
  }

  PreferredSizeWidget _buildAppBar() => AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Search Products',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.info_outline_rounded, color: AppColors.primaryMuted, size: 20),
            tooltip: 'How to compare',
            onPressed: _showCompareInfoDialog,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.divider),
        ),
      );

  Widget _buildSearchBar() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
        child: TextField(
          controller: _searchController,
          textInputAction: TextInputAction.search,
          style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Search by product or brand…',
            hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            suffixIcon: Icon(Icons.search_rounded, color: AppColors.primaryMuted),
            filled: true,
            fillColor: AppColors.cardBackground,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
        ),
      );

  Widget _buildCategoryChips() => SizedBox(
        height: 38,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _kCategories.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final cat = _kCategories[i];
            final selected = cat == _selectedCategory;
            return GestureDetector(
              onTap: () => _onCategorySelected(cat),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: selected ? AppColors.primaryDark : AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected ? AppColors.primaryDark : AppColors.border,
                  ),
                ),
                child: Text(
                  cat,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.w400,
                    color: selected ? AppColors.surface : AppColors.textPrimary,
                  ),
                ),
              ),
            );
          },
        ),
      );

  
  Widget _buildBody() {
    if (_isLoading) {
      return _buildSkeletonList();
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline,
                color: Colors.redAccent.withOpacity(0.7), size: 40),
            const SizedBox(height: 8),
            Text('Something went wrong',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(_error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _fetchProducts,
              icon: Icon(Icons.refresh_rounded,
                  size: 16, color: AppColors.primary),
              label: Text('Retry',
                  style: TextStyle(color: AppColors.primary)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                    color: AppColors.primary.withOpacity(0.5)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      );
    }
    if (_products.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded,
                size: 52,
                color: AppColors.primaryMuted.withOpacity(0.35)),
            const SizedBox(height: 10),
            Text(
              _query.isEmpty
                  ? 'No products found.'
                  : 'No results for "$_query".',
              style: TextStyle(
                  color: AppColors.textSecondary, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      itemCount: _products.length,
      separatorBuilder: (_, __) => const SizedBox(height: 0),
      itemBuilder: (context, i) {
        final p = _products[i];
        return _ProductCard(
          product: p,
          isSelected: _selectedIds.contains(p.id),
          compareMode: _compareMode,
          onTap: () => _navigateToDetail(p),
          onLongPress: () => _toggleSelect(p.id),
          onCheckboxChanged: (_) => _toggleSelect(p.id),
          onFavouriteToggle: () => _toggleFavourite(p),
        );
      },
    );
  }

  Widget _buildSkeletonList() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (_, __) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 11,
                    width: 80,
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Container(
                    height: 13,
                    width: 160,
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompareFAB() {
    final ready = _selectedIds.length == 2;
    return FloatingActionButton.extended(
      onPressed: ready ? _navigateToCompare : null,
      backgroundColor: ready ? AppColors.primaryDark : AppColors.primaryMuted,
      icon: const Icon(Icons.compare_arrows_rounded, color: Colors.white),
      label: Text(
        ready ? 'Compare (2)' : 'Select 1 more…',
        style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PRODUCT CARD
// ─────────────────────────────────────────────────────────────────────────────

class _ProductCard extends StatelessWidget {
  final Product product;
  final bool isSelected;
  final bool compareMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final ValueChanged<bool?> onCheckboxChanged;
  final VoidCallback onFavouriteToggle;

  const _ProductCard({
    required this.product,
    required this.isSelected,
    required this.compareMode,
    required this.onTap,
    required this.onLongPress,
    required this.onCheckboxChanged,
    required this.onFavouriteToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: compareMode ? () => onCheckboxChanged(null) : onTap,
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.07)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 52,
                height: 52,
                color: AppColors.cardBackground,
                child: product.imageUrl != null
                    ? Image.network(
                        product.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _PlaceholderIcon(),
                      )
                    : _PlaceholderIcon(),
              ),
            ),
            const SizedBox(width: 12),
            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.brandName,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    product.productName,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (product.avgRating != null) ...[
                    const SizedBox(height: 4),
                    _StarRating(rating: product.avgRating!),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Right control
            compareMode
                ? Checkbox(
                    value: isSelected,
                    onChanged: onCheckboxChanged,
                    activeColor: AppColors.primaryDark,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4)),
                  )
                : GestureDetector(
                    onTap: onFavouriteToggle,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        product.isFavourite
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        size: 20,
                        color: product.isFavourite
                            ? AppColors.allergenColor
                            : AppColors.textSecondary.withOpacity(0.5),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STAR RATING
// ─────────────────────────────────────────────────────────────────────────────

class _StarRating extends StatelessWidget {
  final double rating;
  const _StarRating({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ...List.generate(5, (i) {
          if (i < rating.floor()) {
            return const Icon(Icons.star_rounded,
                size: 13, color: Color(0xFFFFB800));
          } else if (i < rating) {
            return const Icon(Icons.star_half_rounded,
                size: 13, color: Color(0xFFFFB800));
          } else {
            return const Icon(Icons.star_border_rounded,
                size: 13, color: Color(0xFFFFB800));
          }
        }),
        const SizedBox(width: 4),
        Text(
          rating.toStringAsFixed(1),
          style: TextStyle(
              fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PLACEHOLDER THUMBNAIL
// ─────────────────────────────────────────────────────────────────────────────

class _PlaceholderIcon extends StatelessWidget {
  const _PlaceholderIcon();

  @override
  Widget build(BuildContext context) => Center(
        child: Icon(Icons.inventory_2_outlined,
            size: 24, color: AppColors.primaryMuted),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// DEBOUNCER
// ─────────────────────────────────────────────────────────────────────────────

class _Debouncer {
  final int milliseconds;
  Timer? _timer;
  _Debouncer({required this.milliseconds});

  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: milliseconds), action);
  }
}