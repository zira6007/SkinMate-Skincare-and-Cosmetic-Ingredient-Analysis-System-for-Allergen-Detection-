// TODO Implement this library.// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:skin_mate/core/services/supabase_service.dart';
import 'package:skin_mate/core/constants/app_colors.dart';
import 'package:skin_mate/features/user/explore/search_screen.dart';
import 'package:skin_mate/features/user/explore/product_detail_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FAVOURITES SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class FavouritesScreen extends StatefulWidget {
  const FavouritesScreen({super.key});

  @override
  State<FavouritesScreen> createState() => _FavouritesScreenState();
}

class _FavouritesScreenState extends State<FavouritesScreen> {
  final _searchController = TextEditingController();

  List<Product> _all     = [];   // full list from Supabase
  List<Product> _filtered = [];  // shown after search filter
  bool   _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchFavourites();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Data ──────────────────────────────────────────────────────────────────

  Future<void> _fetchFavourites() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final userId = SupabaseService.client.auth.currentUser?.id;
      if (userId == null) {
        setState(() {
          _all = [];
          _filtered = [];
          _isLoading = false;
        });
        return;
      }

      // Join FAVOURITE → PRODUCT in one query
      final rows = await SupabaseService.client
          .from('FAVOURITE')
          .select(
            'productID, PRODUCT(productID, brand_name, product_name, product_image_url, category_tag, avg_rating)',
          )
          .eq('userID', userId);

      final products = (rows as List)
          .map((row) {
            final p = row['PRODUCT'] as Map<String, dynamic>?;
            if (p == null) return null;
            return Product.fromJson(p, isFavourite: true);
          })
          .whereType<Product>()
          .toList();

      if (!mounted) return;
      setState(() {
        _all      = products;
        _filtered = products;
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

  // ── Search filter ─────────────────────────────────────────────────────────

  void _onSearchChanged() {
    final q = _searchController.text.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _all
          : _all
              .where((p) =>
                  p.productName.toLowerCase().contains(q) ||
                  p.brandName.toLowerCase().contains(q))
              .toList();
    });
  }

  // ── Remove favourite ──────────────────────────────────────────────────────

  Future<void> _removeFavourite(Product product) async {
    HapticFeedback.lightImpact();
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) return;

    // Optimistic remove
    setState(() {
      _all.removeWhere((p) => p.id == product.id);
      _filtered.removeWhere((p) => p.id == product.id);
    });

    try {
      await SupabaseService.client
          .from('FAVOURITE')
          .delete()
          .eq('userID', userId)
          .eq('productID', product.id);
    } catch (e) {
      // Revert
      if (!mounted) return;
      setState(() {
        _all.add(product);
        _filtered.add(product);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to remove: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  // ── Navigate ──────────────────────────────────────────────────────────────

  void _openDetail(Product product) {
    HapticFeedback.selectionClick();
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => ProductDetailScreen(productID: product.id)),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildSearchBar(),
          const SizedBox(height: 4),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() => AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(Icons.chevron_left_rounded,
                color: AppColors.textPrimary, size: 22),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Favourites',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
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
            hintText: 'Search',
            hintStyle:
                TextStyle(color: AppColors.textSecondary, fontSize: 14),
            suffixIcon:
                Icon(Icons.search_rounded, color: AppColors.primaryMuted),
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
              borderSide:
                  BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
        ),
      );

  Widget _buildBody() {
    if (_isLoading) return _buildSkeleton();

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
              onPressed: _fetchFavourites,
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

    if (_filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.favorite_border_rounded,
                size: 52,
                color: AppColors.primaryMuted.withOpacity(0.35)),
            const SizedBox(height: 12),
            Text(
              _searchController.text.isEmpty
                  ? 'No favourites yet'
                  : 'No results found',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _searchController.text.isEmpty
                  ? 'Save products you love from the Explore tab.'
                  : 'Try a different search term.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.5),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchFavourites,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        itemCount: _filtered.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) => _buildCard(_filtered[i]),
      ),
    );
  }

  Widget _buildCard(Product p) {
    return GestureDetector(
      onTap: () => _openDetail(p),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // ── Thumbnail ──────────────────────────────────────────────────
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 56,
                height: 56,
                color: AppColors.cardBackground,
                child: p.imageUrl != null
                    ? Image.network(
                        p.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _PlaceholderThumbnail(),
                      )
                    : _PlaceholderThumbnail(),
              ),
            ),
            const SizedBox(width: 12),
            // ── Text ───────────────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.brandName,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    p.productName,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (p.avgRating != null) ...[
                    const SizedBox(height: 4),
                    _StarRating(rating: p.avgRating!),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            // ── Heart button ───────────────────────────────────────────────
            GestureDetector(
              onTap: () => _removeFavourite(p),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.favorite_rounded,
                  size: 22,
                  color: AppColors.allergenColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeleton() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      itemCount: 4,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, __) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
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
                  const SizedBox(height: 8),
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
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────────────────

class _PlaceholderThumbnail extends StatelessWidget {
  const _PlaceholderThumbnail();

  @override
  Widget build(BuildContext context) => Center(
        child: Icon(Icons.inventory_2_outlined,
            size: 24, color: AppColors.primaryMuted),
      );
}

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
          style:
              TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}