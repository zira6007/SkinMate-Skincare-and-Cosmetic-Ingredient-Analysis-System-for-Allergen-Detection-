import 'package:flutter/material.dart';
import 'package:skin_mate/core/constants/app_colors.dart';
import 'package:skin_mate/core/models/scan_result_model.dart';
import 'package:skin_mate/core/services/supabase_service.dart';
import 'package:skin_mate/core/widgets/loading_spinner.dart';
import 'package:skin_mate/core/widgets/risk_badge.dart';
import 'package:skin_mate/features/user/scanner/scan_result_screen.dart';

class ScanHistoryScreen extends StatefulWidget {
  const ScanHistoryScreen({super.key});

  @override
  State<ScanHistoryScreen> createState() => _ScanHistoryScreenState();
}

class _ScanHistoryScreenState extends State<ScanHistoryScreen> {

  bool    _loading = true;
  String? _error;

  List<ScanHistoryModel> _allScans      = [];
  List<ScanHistoryModel> _filteredScans = [];

  String? _riskFilter;
  String? _methodFilter;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() { _loading = true; _error = null; });

    final userId = SupabaseService.currentUserId;
    if (userId == null) {
      setState(() { _error = 'Not logged in.'; _loading = false; });
      return;
    }

    try {
      final rows = await SupabaseService.client
    .from('SCAN_HISTORY')
    .select('*, SCAN_RESULT(flag, risk_score)')
    .eq('userID', userId)
    .order('scanned_at', ascending: false);

      final scans = ScanHistoryModel.fromJsonList(rows as List);

      setState(() {
        _allScans = scans;
        _loading  = false;
      });

      _applyFilters();
    } catch (e) {
      setState(() {
        _error   = 'Failed to load scan history.\n$e';
        _loading = false;
      });
    }
  }

  void _applyFilters() {
    List<ScanHistoryModel> result = _allScans;

    if (_riskFilter != null) {
      result = result.where((s) => s.overallFlag == _riskFilter).toList();
    }

    if (_methodFilter != null) {
      result = result.where((s) {
        return (s.scanMethod?.toUpperCase() ?? '') == _methodFilter;
      }).toList();
    }

    setState(() => _filteredScans = result);
  }

  // ─────────────────────────────────────────────────────
  // FIX: removed duplicate snackbar, uses correct param name 'scanId'
  // ─────────────────────────────────────────────────────
  void _openResult(ScanHistoryModel scan) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScanResultScreen(scanId: scan.scanID), // ✅ 'scanId' not 'scanID'
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: _loading
          ? const LoadingSpinner(message: 'Loading scan history...')
          : _error != null
              ? _buildError()
              : _buildContent(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation:       0,
      leading: IconButton(
        icon:  const Icon(Icons.arrow_back_rounded),
        color: AppColors.textPrimary,
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        'Scan History',
        style: TextStyle(
          fontSize:   17,
          fontWeight: FontWeight.w700,
          color:      AppColors.textPrimary,
        ),
      ),
      actions: [
        IconButton(
          icon:    const Icon(Icons.refresh_rounded),
          color:   AppColors.textSecondary,
          tooltip: 'Refresh',
          onPressed: _loadHistory,
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: AppColors.border),
      ),
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
            onPressed: _loadHistory,
            icon:  const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        _buildFilterBar(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: Row(
            children: [
              Text(
                '${_filteredScans.length} of ${_allScans.length} scans',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              if (_allScans.isNotEmpty) ...[
                const Spacer(),
                _miniStat(_allergenCount, AppColors.allergenColor, 'allergens'),
                const SizedBox(width: 8),
                _miniStat(_cautionCount,  AppColors.cautionColor,  'cautions'),
                const SizedBox(width: 8),
                _miniStat(_safeCount,     AppColors.safeColor,     'safe'),
              ],
            ],
          ),
        ),
        Expanded(
          child: _filteredScans.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: _loadHistory,
                  color:     AppColors.primary,
                  child: ListView.separated(
                    physics:         const AlwaysScrollableScrollPhysics(),
                    padding:         const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount:       _filteredScans.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder:     (_, i) => _buildScanCard(_filteredScans[i]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _filterChip(
                    label:    'All',
                    selected: _riskFilter == null && _methodFilter == null,
                    onTap: () {
                      setState(() { _riskFilter = null; _methodFilter = null; });
                      _applyFilters();
                    },
                  ),
                  const SizedBox(width: 6),
                  _filterChip(
                    label:   'Allergen',
                    selected: _riskFilter == 'ALLERGEN',
                    color:   AppColors.allergenColor,
                    bgColor: AppColors.allergenBg,
                    onTap: () {
                      setState(() => _riskFilter =
                          _riskFilter == 'ALLERGEN' ? null : 'ALLERGEN');
                      _applyFilters();
                    },
                  ),
                  const SizedBox(width: 6),
                  _filterChip(
                    label:   'Caution',
                    selected: _riskFilter == 'CAUTION',
                    color:   AppColors.cautionColor,
                    bgColor: AppColors.cautionBg,
                    onTap: () {
                      setState(() => _riskFilter =
                          _riskFilter == 'CAUTION' ? null : 'CAUTION');
                      _applyFilters();
                    },
                  ),
                  const SizedBox(width: 6),
                  _filterChip(
                    label:   'Safe',
                    selected: _riskFilter == 'SAFE',
                    color:   AppColors.safeColor,
                    bgColor: AppColors.safeBg,
                    onTap: () {
                      setState(() => _riskFilter =
                          _riskFilter == 'SAFE' ? null : 'SAFE');
                      _applyFilters();
                    },
                  ),
                  const SizedBox(width: 10),
                  Container(width: 1, height: 20, color: AppColors.border),
                  const SizedBox(width: 10),
                  _filterChip(
                    label:   'Barcode',
                    icon:    Icons.qr_code_rounded,
                    selected: _methodFilter == 'BARCODE',
                    onTap: () {
                      setState(() => _methodFilter =
                          _methodFilter == 'BARCODE' ? null : 'BARCODE');
                      _applyFilters();
                    },
                  ),
                  const SizedBox(width: 6),
                  _filterChip(
                    label:   'Camera',
                    icon:    Icons.camera_alt_outlined,
                    selected: _methodFilter == 'CAMERA',
                    onTap: () {
                      setState(() => _methodFilter =
                          _methodFilter == 'CAMERA' ? null : 'CAMERA');
                      _applyFilters();
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip({
    required String       label,
    required bool         selected,
    required VoidCallback onTap,
    Color?                color,
    Color?                bgColor,
    IconData?             icon,
  }) {
    final fg     = selected ? (color ?? Colors.white) : AppColors.textSecondary;
    final bg     = selected ? (bgColor ?? AppColors.primary.withOpacity(0.12)) : AppColors.background;
    final border = selected ? (color ?? AppColors.primary).withOpacity(0.4) : AppColors.border;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color:        bg,
          borderRadius: BorderRadius.circular(20),
          border:       Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12, color: fg),
              const SizedBox(width: 4),
            ],
            Text(label,
              style: TextStyle(
                fontSize:   12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color:      selected ? (color ?? AppColors.primary) : AppColors.textSecondary,
              )),
          ],
        ),
      ),
    );
  }

  Widget _buildScanCard(ScanHistoryModel scan) {
    return GestureDetector(
      onTap: () => _openResult(scan),
      child: Container(
        decoration: BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _borderColor(scan.overallFlag), width: 0.8),
          boxShadow: [
            BoxShadow(
              color:      Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset:     const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildThumbnail(scan.displayImageUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      scan.displayProductName,
                      style: const TextStyle(
                        fontSize:   14,
                        fontWeight: FontWeight.w700,
                        color:      AppColors.textPrimary,
                        height:     1.3,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color:        AppColors.background,
                            borderRadius: BorderRadius.circular(6),
                            border:       Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                scan.isBarcodeMethod
                                    ? Icons.qr_code_rounded
                                    : Icons.camera_alt_outlined,
                                size:  10,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                scan.isBarcodeMethod ? 'Barcode' : 'Camera',
                                style: const TextStyle(
                                  fontSize:   10,
                                  color:      AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (scan.scannedAt != null)
                          Text(
                            _formatDate(scan.scannedAt!),
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.textSecondary),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildRiskSummary(scan),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                children: [
                  RiskBadge(flag: scan.overallFlag),
                  const SizedBox(height: 8),
                  const Icon(Icons.chevron_right_rounded,
                      color: AppColors.textSecondary, size: 18),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _borderColor(String flag) {
    switch (flag.toUpperCase()) {
      case 'ALLERGEN': return AppColors.allergenColor.withOpacity(0.35);
      case 'CAUTION':  return AppColors.cautionColor.withOpacity(0.35);
      default:         return AppColors.border;
    }
  }

  Widget _buildRiskSummary(ScanHistoryModel scan) {
    if (scan.results.isEmpty) {
      return Text(
        scan.ocrRawText != null ? 'OCR scan completed' : 'No results yet',
        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
      );
    }

    final allergens = scan.allergenCount;
    final cautions  = scan.cautionCount;
    final safes     = scan.results.where((r) => r.isSafe).length;

    return Wrap(
      spacing: 6, runSpacing: 4,
      children: [
        if (allergens > 0)
          _riskCount('$allergens allergen${allergens > 1 ? 's' : ''}',
              AppColors.allergenColor, AppColors.allergenBg),
        if (cautions > 0)
          _riskCount('$cautions caution${cautions > 1 ? 's' : ''}',
              AppColors.cautionColor, AppColors.cautionBg),
        if (safes > 0)
          _riskCount('$safes safe', AppColors.safeColor, AppColors.safeBg),
      ],
    );
  }

  Widget _riskCount(String label, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
    );
  }

  Widget _buildThumbnail(String? url) {
    return Container(
      width: 54, height: 54,
      decoration: BoxDecoration(
        color:        AppColors.secondaryLight,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: AppColors.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: url != null && url.isNotEmpty
            ? Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _thumbPlaceholder(),
                loadingBuilder: (_, child, progress) {
                  if (progress == null) return child;
                  return const Center(
                    child: SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          color: AppColors.primary, strokeWidth: 1.5),
                    ),
                  );
                },
              )
            : _thumbPlaceholder(),
      ),
    );
  }

  Widget _thumbPlaceholder() {
    return const Center(
      child: Icon(Icons.inventory_2_outlined,
          color: AppColors.textSecondary, size: 22),
    );
  }

  Widget _miniStat(int count, Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7, height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 3),
        Text('$count $label',
          style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
      ],
    );
  }

  int get _allergenCount => _allScans.where((s) => s.overallFlag == 'ALLERGEN').length;
  int get _cautionCount  => _allScans.where((s) => s.overallFlag == 'CAUTION').length;
  int get _safeCount     => _allScans.where((s) => s.overallFlag == 'SAFE').length;

  String _formatDate(DateTime dt) {
    final now  = DateTime.now();
    final diff = now.difference(dt).inDays;
    if (diff == 0) {
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return 'Today $h:$m';
    }
    if (diff == 1) return 'Yesterday';
    if (diff < 7)  return '$diff days ago';
    final months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  Widget _buildEmpty() {
    final hasFilters = _riskFilter != null || _methodFilter != null;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasFilters ? Icons.filter_list_off_rounded : Icons.qr_code_scanner_outlined,
            color: AppColors.textSecondary.withOpacity(0.3),
            size:  52,
          ),
          const SizedBox(height: 16),
          Text(
            hasFilters ? 'No scans match the filter' : 'No scans yet',
            style: TextStyle(
              fontSize:   16,
              fontWeight: FontWeight.w600,
              color:      AppColors.textSecondary.withOpacity(0.55),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hasFilters
                ? 'Try removing a filter'
                : 'Scan your first product to see it here',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary.withOpacity(0.4)),
          ),
          if (hasFilters) ...[
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () {
                setState(() { _riskFilter = null; _methodFilter = null; });
                _applyFilters();
              },
              icon:  const Icon(Icons.clear_all_rounded, size: 16),
              label: const Text('Clear filters'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side:  const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}