// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:skin_mate/core/services/supabase_service.dart';
import 'package:skin_mate/core/constants/app_colors.dart';
import 'package:skin_mate/features/user/scanner/scanner_screen.dart';
import 'package:skin_mate/features/user/explore/search_screen.dart';
import 'package:skin_mate/features/user/diary/diary_screen.dart';
import 'package:skin_mate/features/user/profile/profile_screen.dart';
import 'package:skin_mate/features/user/scanner/scan_result_screen.dart';
import 'package:skin_mate/features/user/notifications/notifications_screen.dart';
import 'package:skin_mate/features/user/favourites/favourites_screen.dart';
import 'package:skin_mate/features/user/scanner/scan_history_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// HOME SCREEN — main shell with bottom nav
// ─────────────────────────────────────────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;


  final List<Widget> _screens = [
    const _HomeTab(),      // 0 — Home
    const ScannerScreen(), // 1 — Scan
    const SearchScreen(),  // 2 — Explore
    const DiaryScreen(),   // 3 — Diary
    const ProfileScreen(), // 4 — Profile
  ];

  void _onTabTapped(int index) {
    HapticFeedback.selectionClick();
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ─────────────────────────────────────────────────────
  // BOTTOM NAVIGATION BAR
  // ─────────────────────────────────────────────────────
  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.divider, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset:     const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon:       Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                label:      'Home',
                index:      0,
                current:    _currentIndex,
                onTap:      _onTabTapped,
              ),
              _NavItem(
                icon:       Icons.search_outlined,
                activeIcon: Icons.search_rounded,
                label:      'Explore',
                index:      2,
                current:    _currentIndex,
                onTap:      _onTabTapped,
              ),
              _NavItem(
                icon:       Icons.document_scanner_outlined,
                activeIcon: Icons.document_scanner_rounded,
                label:      'Scan',
                index:      1,
                current:    _currentIndex,
                onTap:      _onTabTapped,
                isScanButton: true,
              ),
              _NavItem(
                icon:       Icons.book_outlined,
                activeIcon: Icons.book_rounded,
                label:      'Diary',
                index:      3,
                current:    _currentIndex,
                onTap:      _onTabTapped,
              ),
              _NavItem(
                icon:       Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                label:      'Profile',
                index:      4,
                current:    _currentIndex,
                onTap:      _onTabTapped,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NAV ITEM
// ─────────────────────────────────────────────────────────────────────────────
class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String   label;
  final int      index;
  final int      current;
  final void Function(int) onTap;
  final bool isScanButton;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.index,
    required this.current,
    required this.onTap,
    this.isScanButton = false,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = current == index;

    if (isScanButton) {
      return GestureDetector(
        onTap: () => onTap(index),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width:  52,
              height: 52,
              decoration: BoxDecoration(
                color:  isActive ? AppColors.primaryDark : AppColors.primary,
                shape:  BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color:      AppColors.primary.withOpacity(0.4),
                    blurRadius: isActive ? 16 : 8,
                    offset:     const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                isActive ? activeIcon : icon,
                color: AppColors.surface,
                size:  24,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize:   10,
                fontWeight: FontWeight.w600,
                color:      isActive ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width:  40,
              height: 32,
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.primary.withOpacity(0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isActive ? activeIcon : icon,
                color: isActive ? AppColors.primary : AppColors.textSecondary,
                size:  22,
              ),
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize:   10,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                color:      isActive ? AppColors.primary : AppColors.textSecondary,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HOME TAB BODY
// ─────────────────────────────────────────────────────────────────────────────
class _HomeTab extends StatefulWidget {
  const _HomeTab();

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  bool    _loading     = true;
  String  _userName    = 'there';
  String? _skinType;
  List<Map<String, dynamic>> _recentScans = [];

  static const List<Map<String, dynamic>> _tips = [
    {
      'emoji': '🌿',
      'title': 'Patch test new products',
      'body':  'Always test a new skincare product on a small area of skin for 24–48 hours before applying it to your face.',
    },
    {
      'emoji': '💧',
      'title': 'Hydration matters',
      'body':  'Drinking enough water keeps your skin barrier functioning well. Aim for 8 glasses a day.',
    },
    {
      'emoji': '☀️',
      'title': 'SPF every day',
      'body':  'UV rays cause up to 90% of visible skin ageing. Apply SPF 30+ even on cloudy days.',
    },
    {
      'emoji': '🧴',
      'title': 'Layer light to heavy',
      'body':  'Apply skincare from thinnest to thickest consistency: toner → serum → moisturiser → oil.',
    },
    {
      'emoji': '🌙',
      'title': 'Night is repair time',
      'body':  'Your skin regenerates while you sleep. Use richer moisturisers and actives like retinol at night.',
    },
    {
      'emoji': '🫧',
      'title': 'Less is more',
      'body':  'Overloading your skin with too many products can disrupt its natural balance. Start simple.',
    },
  ];

  late Map<String, dynamic> _todayTip;

  @override
  void initState() {
    super.initState();
    final dayOfYear = DateTime.now().difference(
      DateTime(DateTime.now().year, 1, 1),
    ).inDays;
    _todayTip = _tips[dayOfYear % _tips.length];
    _loadData();
  }

  Future<void> _loadData() async {
  setState(() => _loading = true);

  try {
    final userID = SupabaseService.client.auth.currentUser?.id;
    if (userID == null) return;

    final userRow = await SupabaseService.client
        .from('USER')
        .select('name')
        .eq('userID', userID)
        .maybeSingle();
    _userName = (userRow?['name'] as String?)?.split(' ').first ?? 'there';

    final skinRow = await SupabaseService.client
        .from('RESULT_SKIN_PROFILE')
        .select('skin_type')
        .eq('userID', userID)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    _skinType = skinRow?['skin_type'] as String?;

    // ── Fetch recent scans — no product join, use what's in table ──
    final scans = await SupabaseService.client
        .from('SCAN_HISTORY')
        .select('scanID, scanned_at, image_url, scan_method, risk_level, ai_result')
        .eq('userID', userID)
        .order('scanned_at', ascending: false)
        .limit(3);

    debugPrint('SCANS FETCHED: ${(scans as List).length}');
    debugPrint('SCANS DATA: $scans');

    final List<Map<String, dynamic>> enriched = [];
    for (final scan in scans) {
      // Use ai_result as product name fallback since there's no product_name
      final riskLevel = scan['risk_level'] as String?;

      enriched.add({
        'scanID':       scan['scanID'],
        'scanned_at':   scan['scanned_at'],
        'scan_method':  scan['scan_method'] ?? 'ocr',
        'image_url':    scan['image_url'],
       'product_name': scan['scan_method'] == 'barcode'
    ? 'Barcode Scan'
    : 'Camera Scan',
        'risk_level':   riskLevel,
      });
    }

    if (mounted) {
      setState(() {
        _recentScans = enriched;
        _loading     = false;
      });
    }
  } catch (e) {
    debugPrint('HomeTab loadData error: $e');
    if (mounted) setState(() => _loading = false);
  }
}
  void _openNotifications() {
    HapticFeedback.selectionClick();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
  }

  void _openHistory() {
    HapticFeedback.selectionClick();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ScanHistoryScreen()),
    );
  }

  void _openFavourites() {
    HapticFeedback.selectionClick();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FavouritesScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.primary,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          _buildSliverAppBar(),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 20),
                _buildQuickActionsRow(),
                const SizedBox(height: 24),
                _buildTipCard(),
                const SizedBox(height: 24),
                _buildQuickScanButton(context),
                const SizedBox(height: 28),
                _buildSectionHeader('Recent Scans', 'Your last 3 product scans'),
                const SizedBox(height: 12),
                if (_loading)
                  _buildSkeletonList()
                else if (_recentScans.isEmpty)
                  _buildEmptyScans(context)
                else
                  ..._recentScans.map((scan) => _buildScanCard(context, scan)),
                const SizedBox(height: 8),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
  final hour = DateTime.now().hour;
  final greeting = hour < 12
      ? 'Good morning'
      : hour < 17
          ? 'Good afternoon'
          : 'Good evening';

  return SliverAppBar(
    expandedHeight: 140,
    pinned:         true,
    backgroundColor: AppColors.primaryDark,
    elevation:      0,
    actions: [
      Padding(
        padding: const EdgeInsets.only(right: 16, top: 8),
        child: GestureDetector(
          onTap: _openNotifications,
          child: Container(
            width:  38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.surface.withOpacity(0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_none_rounded,
              color: AppColors.surface,
              size:  20,
            ),
          ),
        ),
      ),
    ],
    flexibleSpace: FlexibleSpaceBar(
      titlePadding: const EdgeInsets.fromLTRB(20, 0, 64, 16),
      title: Column(
        mainAxisSize:       MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$greeting, $_userName',
            style: TextStyle(
              fontSize:      18,
              fontWeight:    FontWeight.w800,
              color:         AppColors.surface,
              letterSpacing: -0.3,
            ),
          ),
          if (_skinType != null)
            Text(
              '$_skinType skin · SkinMate',
              style: TextStyle(
                fontSize: 11,
                color:    AppColors.surface.withOpacity(0.6),
              ),
            ),
        ],
      ),
      background: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin:  Alignment.topLeft,
            end:    Alignment.bottomRight,
            colors: [
              AppColors.primaryDark,
              AppColors.primary.withOpacity(0.8),
            ],
          ),
        ),
        child: Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(right: 24, top: 12),
            child: Opacity(
              opacity: 0.12,
              child: Icon(
                Icons.face_retouching_natural_rounded,
                size:  120,
                color: AppColors.surface,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

  Widget _buildQuickActionsRow() {
  return Row(
    children: [
      Expanded(
        child: _QuickActionButton(
          icon:  Icons.history_rounded,
          label: 'Scan History',
          onTap: _openHistory,
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: _QuickActionButton(
          icon:  Icons.favorite_border_rounded,
          label: 'Favourites',
          onTap: _openFavourites,
        ),
      ),
    ],
  );
}

  Widget _buildTipCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin:  Alignment.topLeft,
          end:    Alignment.bottomRight,
          colors: [
            AppColors.cardBackground,
            AppColors.secondaryLight.withOpacity(0.6),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color:        AppColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lightbulb_rounded, size: 12, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      'Tip of the Day',
                      style: TextStyle(
                        fontSize:   11,
                        fontWeight: FontWeight.w700,
                        color:      AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(_todayTip['emoji'] as String,
                  style: const TextStyle(fontSize: 24)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _todayTip['title'] as String,
            style: TextStyle(
              fontSize:   15,
              fontWeight: FontWeight.w800,
              color:      AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _todayTip['body'] as String,
            style: TextStyle(
                fontSize: 13, color: AppColors.textSecondary, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickScanButton(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ScannerScreen()),
        );
      },
      child: Container(
        width:   double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color:        AppColors.primaryDark,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color:      AppColors.primaryDark.withOpacity(0.35),
              blurRadius: 20,
              offset:     const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width:  52,
              height: 52,
              decoration: BoxDecoration(
                color:        AppColors.primary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.document_scanner_rounded,
                  color: AppColors.surface, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Scan a Product',
                    style: TextStyle(
                      fontSize:   16,
                      fontWeight: FontWeight.w800,
                      color:      AppColors.surface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Check ingredients instantly with AI',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppColors.surface.withOpacity(0.55)),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                color: AppColors.surface.withOpacity(0.5), size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize:      17,
            fontWeight:    FontWeight.w800,
            color:         AppColors.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        Text(subtitle,
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _buildScanCard(BuildContext context, Map<String, dynamic> scan) {
  final scannedAt = DateTime.tryParse(scan['scanned_at'] as String? ?? '');
  final timeAgo   = scannedAt != null ? _timeAgo(scannedAt) : '';
  final method    = scan['scan_method']  as String? ?? 'ocr';
  final imageUrl  = scan['image_url']    as String?;
  final name      = scan['product_name'] as String? ?? 'Scanned product';
  final scanId    = scan['scanID']       as String;
  final risk      = scan['risk_level']   as String?;

  // Risk badge color
  Color riskColor = AppColors.primary;
  if (risk == 'ALLERGEN')    riskColor = const Color(0xFFE63946);
  if (risk == 'CAUTION')     riskColor = const Color(0xFFF6AE2D);
  if (risk == 'SAFE')        riskColor = const Color(0xFF52B788);

  return GestureDetector(
    onTap: () {
      HapticFeedback.selectionClick();
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => ScanResultScreen(scanId: scanId)),
      );
    },
    child: Container(
      margin:  const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
              color:      Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset:     const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          // Image or placeholder
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width:  52,
              height: 52,
              color:  AppColors.cardBackground,
              child: imageUrl != null
                  ? Image.network(imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _thumbnailPlaceholder())
                  : _thumbnailPlaceholder(),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                      fontSize:   14,
                      fontWeight: FontWeight.w600,
                      color:      AppColors.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      method == 'barcode'
                          ? Icons.qr_code_rounded
                          : Icons.document_scanner_outlined,
                      size:  12,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      method == 'barcode' ? 'Barcode' : 'OCR',
                      style: TextStyle(
                          fontSize: 11, color: AppColors.textSecondary),
                    ),
                    const SizedBox(width: 8),
                    if (risk != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color:        riskColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          risk,
                          style: TextStyle(
                            fontSize:   9,
                            fontWeight: FontWeight.w700,
                            color:      riskColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(timeAgo,
                        style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary)),
                  ],
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded,
              color: AppColors.textSecondary.withOpacity(0.4), size: 20),
        ],
      ),
    ),
  );
}
  Widget _thumbnailPlaceholder() => Center(
        child: Icon(Icons.inventory_2_outlined,
            color: AppColors.primaryMuted, size: 22),
      );

  Widget _buildSkeletonList() {
    return Column(
      children: List.generate(
        3,
        (_) => Container(
          margin:  const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color:        AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border:       Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width:  52,
                height: 52,
                decoration: BoxDecoration(
                  color:        AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 13,
                      width:  140,
                      decoration: BoxDecoration(
                        color:        AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 10,
                      width:  90,
                      decoration: BoxDecoration(
                        color:        AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyScans(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color:        AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(Icons.document_scanner_outlined,
              color: AppColors.primaryMuted.withOpacity(0.4), size: 40),
          const SizedBox(height: 12),
          Text(
            'No scans yet',
            style: TextStyle(
                fontSize:   15,
                fontWeight: FontWeight.w600,
                color:      AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            'Scan your first product to see\ningredient analysis here.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 13, color: AppColors.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ScannerScreen()),
            ),
            icon:  Icon(Icons.add_rounded, size: 16, color: AppColors.primary),
            label: Text('Scan now',
                style: TextStyle(
                    color:      AppColors.primary,
                    fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              side:  BorderSide(color: AppColors.primary.withOpacity(0.5)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1)  return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours   < 24) return '${diff.inHours}h ago';
    if (diff.inDays    == 1) return 'Yesterday';
    if (diff.inDays    < 7)  return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// QUICK ACTION BUTTON (History / Favourites)
// ─────────────────────────────────────────────────────────────────────────────
class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String   label;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color:        AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border:       Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color:      Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset:     const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.primary, size: 24),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize:   12,
                fontWeight: FontWeight.w600,
                color:      AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}