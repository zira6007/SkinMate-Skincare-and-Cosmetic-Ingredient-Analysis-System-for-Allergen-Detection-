// ignore_for_file: unused_field, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:skin_mate/core/services/supabase_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // ── SkinMate colours ──────────────────────────────────
  static const Color _cream      = Color(0xFFF9F3EC);
  static const Color _softBrown  = Color(0xFFB07B6B);
  static const Color _darkBrown  = Color(0xFF4A2C2A);
  static const Color _lightPink  = Color(0xFFF5D5D5);
  static const Color _sidebarBg  = Color(0xFF3D2420);
  static const Color _mutedBrown = Color(0xFF9A7070);
  static const Color _white      = Color(0xFFFFFFFF);
  static const Color _cardBg     = Color(0xFFEDE0D8);

  // ── Chart accent colours ───────────────────────────────
  static const Color _safe      = Color(0xFF52B788); // green
  static const Color _caution   = Color(0xFFF6AE2D); // amber
  static const Color _allergen  = Color(0xFFE63946); // red

  static const List<Color> _skinTypeColors = [
    Color(0xFFB07B6B),
    Color(0xFFE8A87C),
    Color(0xFF8B5E52),
    Color(0xFFD4A373),
    Color(0xFF6D4C41),
    Color(0xFFF0C9A0),
  ];

  // ── State ─────────────────────────────────────────────
  bool _loading = true;
  String? _error;

  // Stat card data
  int _totalUsers       = 0;
  int _totalScans       = 0;
  int _totalProducts    = 0;
  int _totalIngredients = 0;

  // Bar chart — top 5 flagged ingredients
  // List of {name, count}
  List<Map<String, dynamic>> _topFlagged = [];

  // Line chart — scans per day last 7 days
  // List of {date, count} sorted oldest → newest
  List<Map<String, dynamic>> _scanActivity = [];

  // Donut — risk breakdown {SAFE, CAUTION, ALLERGEN}
  Map<String, int> _riskBreakdown = {};

  // Donut — skin type distribution
  Map<String, int> _skinTypeDistribution = {};

  // Tooltip state for donuts
  int _riskTouchedIndex     = -1;
  int _skinTypeTouchedIndex = -1;

  // ─────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  // ─────────────────────────────────────────────────────
  // LOAD ALL DATA
  // ─────────────────────────────────────────────────────
  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error   = null;
    });

    try {
      await Future.wait([
        _loadStatCards(),
        _loadTopFlaggedIngredients(),
        _loadScanActivity(),
        _loadRiskBreakdown(),
        _loadSkinTypeDistribution(),
      ]);
    } catch (e) {
      setState(() => _error = 'Failed to load dashboard data.\n$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── 1. Stat cards ──────────────────────────────────────
  Future<void> _loadStatCards() async {
  final users = await SupabaseService.client
      .from('USER')
      .select('userID')
       .eq('is_active', 'true');

  final scans = await SupabaseService.client
      .from('SCAN_HISTORY')
      .select('*');

  final products = await SupabaseService.client
      .from('PRODUCT')
      .select('*');

  final ingredients = await SupabaseService.client
      .from('INGREDIENT')
      .select('*');

  if (mounted) {
    setState(() {
      _totalUsers       = (users as List).length;
      _totalScans       = (scans as List).length;
      _totalProducts    = (products as List).length;
      _totalIngredients = (ingredients as List).length;
    });
  }
}
  // ── 2. Top 5 flagged ingredients ───────────────────────
  Future<void> _loadTopFlaggedIngredients() async {
    // Get all ALLERGEN or CAUTION scan results with ingredientID
    final data = await SupabaseService.client
        .from('SCAN_RESULT')
        .select('ingredientID, flag')
        .inFilter('flag', ['ALLERGEN', 'CAUTION']);

    // Group by ingredientID, count occurrences
    final Map<String, int> counts = {};
    for (final row in data as List) {
      final id = row['ingredientID'] as String? ?? 'Unknown';
      counts[id] = (counts[id] ?? 0) + 1;
    }

    // Sort by count desc, take top 5
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top5 = sorted.take(5).toList();

    // Fetch common names for the top 5 ingredient IDs
    if (top5.isEmpty) {
      if (mounted) setState(() => _topFlagged = []);
      return;
    }

    final ids = top5.map((e) => e.key).toList();
    final ingredients = await SupabaseService.client
        .from('INGREDIENT')
        .select('ingredientID, common_name')
        .inFilter('ingredientID', ids);

    final Map<String, String> nameMap = {
      for (final row in ingredients as List)
        row['ingredientID'] as String: row['common_name'] as String? ?? row['ingredientID'] as String,
    };

    if (mounted) {
      setState(() {
        _topFlagged = top5.map((e) => {
          'name':  nameMap[e.key] ?? e.key,
          'count': e.value,
        }).toList();
      });
    }
  }

  // ── 3. Scan activity last 7 days ───────────────────────
  Future<void> _loadScanActivity() async {
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 6));
    final cutoff = DateTime(sevenDaysAgo.year, sevenDaysAgo.month, sevenDaysAgo.day);

    final data = await SupabaseService.client
        .from('SCAN_HISTORY')
        .select('scanned_at')
        .gte('scanned_at', cutoff.toIso8601String());

    // Group by date string (YYYY-MM-DD)
    final Map<String, int> dayCounts = {};

    // Pre-populate last 7 days with 0
    for (int i = 6; i >= 0; i--) {
      final day = DateTime.now().subtract(Duration(days: i));
      final key = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      dayCounts[key] = 0;
    }

    for (final row in data as List) {
      final ts  = DateTime.parse(row['scanned_at'] as String).toLocal();
      final key = '${ts.year}-${ts.month.toString().padLeft(2, '0')}-${ts.day.toString().padLeft(2, '0')}';
      if (dayCounts.containsKey(key)) {
        dayCounts[key] = (dayCounts[key] ?? 0) + 1;
      }
    }

    // Convert to sorted list
    final sorted = dayCounts.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    if (mounted) {
      setState(() {
        _scanActivity = sorted.map((e) => {
          'date':  e.key,
          'count': e.value,
        }).toList();
      });
    }
  }

  // ── 4. Risk level breakdown ────────────────────────────
  Future<void> _loadRiskBreakdown() async {
    final data = await SupabaseService.client
        .from('SCAN_RESULT')
        .select('flag');

    final Map<String, int> counts = {'SAFE': 0, 'CAUTION': 0, 'ALLERGEN': 0};
    for (final row in data as List) {
      final flag = (row['flag'] as String?)?.toUpperCase() ?? 'SAFE';
      if (counts.containsKey(flag)) counts[flag] = counts[flag]! + 1;
    }

    if (mounted) setState(() => _riskBreakdown = counts);
  }

  // ── 5. Skin type distribution ──────────────────────────
  Future<void> _loadSkinTypeDistribution() async {
    final data = await SupabaseService.client
        .from('RESULT_SKIN_PROFILE')
        .select('skin_type');

    final Map<String, int> counts = {};
    for (final row in data as List) {
      final type = (row['skin_type'] as String?) ?? 'Unknown';
      counts[type] = (counts[type] ?? 0) + 1;
    }

    if (mounted) setState(() => _skinTypeDistribution = counts);
  }

  // ─────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cream,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _softBrown))
          : _error != null
              ? _buildError()
              : _buildDashboard(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: _softBrown, size: 48),
          const SizedBox(height: 16),
          Text(_error!, textAlign: TextAlign.center,
              style: const TextStyle(color: _darkBrown, fontSize: 14)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _loadAll,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _softBrown, foregroundColor: _white),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    return RefreshIndicator(
      onRefresh: _loadAll,
      color: _softBrown,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Header ────────────────────────────────────
            _buildHeader(),
            const SizedBox(height: 28),

            // ── 1. Stat cards ──────────────────────────────
            _buildStatCards(),
            const SizedBox(height: 28),

            // ── 2 + 3. Bar + Line charts (side by side) ───
            LayoutBuilder(builder: (context, constraints) {
              final wide = constraints.maxWidth > 900;
              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildBarChart()),
                    const SizedBox(width: 20),
                    Expanded(child: _buildLineChart()),
                  ],
                );
              }
              return Column(children: [
                _buildBarChart(),
                const SizedBox(height: 20),
                _buildLineChart(),
              ]);
            }),
            const SizedBox(height: 20),

            // ── 4 + 5. Two donuts ─────────────────────────
            LayoutBuilder(builder: (context, constraints) {
              final wide = constraints.maxWidth > 700;
              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildRiskDonut()),
                    const SizedBox(width: 20),
                    Expanded(child: _buildSkinTypeDonut()),
                  ],
                );
              }
              return Column(children: [
                _buildRiskDonut(),
                const SizedBox(height: 20),
                _buildSkinTypeDonut(),
              ]);
            }),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  // HEADER
  // ─────────────────────────────────────────────────────
  Widget _buildHeader() {
    final now = DateTime.now();
    final months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    final dateStr = '${now.day} ${months[now.month - 1]} ${now.year}';

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Dashboard',
                style: TextStyle(
                  fontSize:   26,
                  fontWeight: FontWeight.w800,
                  color:      _darkBrown,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                'Analytics overview · $dateStr',
                style: const TextStyle(fontSize: 13, color: _mutedBrown),
              ),
            ],
          ),
        ),
        // Refresh button
        IconButton(
          onPressed: _loadAll,
          icon: const Icon(Icons.refresh_rounded),
          color: _softBrown,
          tooltip: 'Refresh data',
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────
  // 1. STAT CARDS
  // ─────────────────────────────────────────────────────
  Widget _buildStatCards() {
    final cards = [
      _StatCardData(
        label: 'Total Users',
        value: _totalUsers,
        icon:  Icons.people_alt_rounded,
        color: const Color(0xFF5B8DEF),
      ),
      _StatCardData(
        label: 'Total Scans',
        value: _totalScans,
        icon:  Icons.qr_code_scanner_rounded,
        color: _softBrown,
      ),
      _StatCardData(
        label: 'Products',
        value: _totalProducts,
        icon:  Icons.inventory_2_rounded,
        color: const Color(0xFF52B788),
      ),
      _StatCardData(
        label: 'Ingredients',
        value: _totalIngredients,
        icon:  Icons.science_rounded,
        color: const Color(0xFFF6AE2D),
      ),
    ];

    return LayoutBuilder(builder: (context, constraints) {
      final crossCount = constraints.maxWidth > 700 ? 4 : 2;
      return GridView.builder(
        shrinkWrap:    true,
        physics:       const NeverScrollableScrollPhysics(),
        gridDelegate:  SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount:     crossCount,
          mainAxisSpacing:    14,
          crossAxisSpacing:   14,
          childAspectRatio:   1.8,
        ),
        itemCount:  cards.length,
        itemBuilder: (_, i) => _buildStatCard(cards[i]),
      );
    });
  }

  Widget _buildStatCard(_StatCardData card) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color:        _white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset:     const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color:        card.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(card.icon, color: card.color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  card.value.toString(),
                  style: const TextStyle(
                    fontSize:   24,
                    fontWeight: FontWeight.w800,
                    color:      _darkBrown,
                    height:     1.1,
                  ),
                ),
                Text(
                  card.label,
                  style: const TextStyle(
                    fontSize: 12,
                    color:    _mutedBrown,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  // CHART CARD WRAPPER
  // ─────────────────────────────────────────────────────
  Widget _chartCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color:        _white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset:     const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color:        _lightPink,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: _softBrown, size: 17),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700,
                      color: _darkBrown,
                    )),
                    Text(subtitle, style: const TextStyle(
                      fontSize: 11, color: _mutedBrown,
                    )),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  // 2. BAR CHART — Top 5 flagged ingredients
  // ─────────────────────────────────────────────────────
  Widget _buildBarChart() {
    return _chartCard(
      title:    'Top Flagged Ingredients',
      subtitle: 'ALLERGEN + CAUTION flags combined',
      icon:     Icons.warning_amber_rounded,
      child: _topFlagged.isEmpty
          ? _emptyState('No flagged ingredients yet')
          : SizedBox(
              height: 220,
              child: BarChart(
                BarChartData(
                  alignment:     BarChartAlignment.spaceAround,
                  maxY:          (_topFlagged.map((e) => e['count'] as int).reduce((a, b) => a > b ? a : b) * 1.3),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => _darkBrown,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        return BarTooltipItem(
                          '${_topFlagged[groupIndex]['name']}\n',
                          const TextStyle(color: _white, fontWeight: FontWeight.w700, fontSize: 12),
                          children: [
                            TextSpan(
                              text: '${rod.toY.toInt()} flags',
                              style: const TextStyle(color: _lightPink, fontSize: 11),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= _topFlagged.length) return const SizedBox();
                          final name = _topFlagged[idx]['name'] as String;
                          // Truncate long names
                          final label = name.length > 10 ? '${name.substring(0, 10)}…' : name;
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(label,
                              style: const TextStyle(fontSize: 9, color: _mutedBrown),
                              textAlign: TextAlign.center,
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (value, meta) => Text(
                          value.toInt().toString(),
                          style: const TextStyle(fontSize: 10, color: _mutedBrown),
                        ),
                      ),
                    ),
                    topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: _lightPink.withOpacity(0.5),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: List.generate(_topFlagged.length, (i) {
                    final count = (_topFlagged[i]['count'] as int).toDouble();
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY:              count,
                          width:            32,
                          borderRadius:     const BorderRadius.vertical(top: Radius.circular(6)),
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end:   Alignment.topCenter,
                            colors: [
                              _softBrown.withOpacity(0.6),
                              _softBrown,
                            ],
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
    );
  }

  // ─────────────────────────────────────────────────────
  // 3. LINE CHART — Scan activity last 7 days
  // ─────────────────────────────────────────────────────
  Widget _buildLineChart() {
    return _chartCard(
      title:    'Scan Activity',
      subtitle: 'Last 7 days',
      icon:     Icons.show_chart_rounded,
      child: _scanActivity.isEmpty
          ? _emptyState('No scan data yet')
          : SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => _darkBrown,
                      getTooltipItems: (spots) => spots.map((spot) {
                        final idx  = spot.x.toInt();
                        final date = idx < _scanActivity.length
                            ? _scanActivity[idx]['date'] as String
                            : '';
                        // Show only MM-DD
                        final label = date.length >= 10 ? date.substring(5) : date;
                        return LineTooltipItem(
                          '$label\n${spot.y.toInt()} scans',
                          const TextStyle(color: _white, fontSize: 11),
                        );
                      }).toList(),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: _lightPink.withOpacity(0.5),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles:   true,
                        reservedSize: 32,
                        interval:     1,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= _scanActivity.length) return const SizedBox();
                          final date = _scanActivity[idx]['date'] as String;
                          // Show DD only
                          final day = date.length >= 10 ? date.substring(8) : '';
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(day,
                              style: const TextStyle(fontSize: 10, color: _mutedBrown),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles:   true,
                        reservedSize: 28,
                        getTitlesWidget: (value, meta) => Text(
                          value.toInt().toString(),
                          style: const TextStyle(fontSize: 10, color: _mutedBrown),
                        ),
                      ),
                    ),
                    topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: List.generate(
                        _scanActivity.length,
                        (i) => FlSpot(
                          i.toDouble(),
                          (_scanActivity[i]['count'] as int).toDouble(),
                        ),
                      ),
                      isCurved:        true,
                      color:           _softBrown,
                      barWidth:        2.5,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, bar, index) =>
                            FlDotCirclePainter(
                              radius:         4,
                              color:          _white,
                              strokeWidth:    2,
                              strokeColor:    _softBrown,
                            ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end:   Alignment.bottomCenter,
                          colors: [
                            _softBrown.withOpacity(0.2),
                            _softBrown.withOpacity(0.0),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  // ─────────────────────────────────────────────────────
  // 4. DONUT — Risk level breakdown
  // ─────────────────────────────────────────────────────
  Widget _buildRiskDonut() {
    final total = _riskBreakdown.values.fold(0, (a, b) => a + b);

    final sections = <PieChartSectionData>[];
    final entries  = [
      MapEntry('SAFE',     _safe),
      MapEntry('CAUTION',  _caution),
      MapEntry('ALLERGEN', _allergen),
    ];

    for (int i = 0; i < entries.length; i++) {
      final key   = entries[i].key;
      final color = entries[i].value;
      final count = _riskBreakdown[key] ?? 0;
      if (count == 0) continue;

      final isTouched = i == _riskTouchedIndex;
      sections.add(PieChartSectionData(
        value:      count.toDouble(),
        color:      color,
        radius:     isTouched ? 60 : 52,
        title:      isTouched ? '${(count / total * 100).toStringAsFixed(1)}%' : '',
        titleStyle: const TextStyle(
          color: _white, fontSize: 11, fontWeight: FontWeight.w700),
        borderSide: isTouched
            ? const BorderSide(color: _white, width: 2)
            : BorderSide.none,
      ));
    }

    return _chartCard(
      title:    'Risk Level Breakdown',
      subtitle: 'Based on all scan results',
      icon:     Icons.donut_large_rounded,
      child: total == 0
          ? _emptyState('No scan results yet')
          : Column(
              children: [
                SizedBox(
                  height: 190,
                  child: PieChart(
                    PieChartData(
                      sections:          sections,
                      centerSpaceRadius: 48,
                      sectionsSpace:     3,
                      pieTouchData: PieTouchData(
                        touchCallback: (event, response) {
                          setState(() {
                            if (!event.isInterestedForInteractions ||
                                response == null ||
                                response.touchedSection == null) {
                              _riskTouchedIndex = -1;
                              return;
                            }
                            _riskTouchedIndex =
                                response.touchedSection!.touchedSectionIndex;
                          });
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _buildDonutLegend([
                  _LegendItem('Safe',     _safe,     _riskBreakdown['SAFE'] ?? 0,     total),
                  _LegendItem('Caution',  _caution,  _riskBreakdown['CAUTION'] ?? 0,  total),
                  _LegendItem('Allergen', _allergen, _riskBreakdown['ALLERGEN'] ?? 0, total),
                ]),
              ],
            ),
    );
  }

  // ─────────────────────────────────────────────────────
  // 5. DONUT — Skin type distribution
  // ─────────────────────────────────────────────────────
  Widget _buildSkinTypeDonut() {
    final total   = _skinTypeDistribution.values.fold(0, (a, b) => a + b);
    final entries = _skinTypeDistribution.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final sections = <PieChartSectionData>[];
    for (int i = 0; i < entries.length; i++) {
      final count     = entries[i].value;
      final color     = _skinTypeColors[i % _skinTypeColors.length];
      final isTouched = i == _skinTypeTouchedIndex;
      sections.add(PieChartSectionData(
        value:      count.toDouble(),
        color:      color,
        radius:     isTouched ? 60 : 52,
        title:      isTouched ? '${(count / total * 100).toStringAsFixed(1)}%' : '',
        titleStyle: const TextStyle(
          color: _white, fontSize: 11, fontWeight: FontWeight.w700),
        borderSide: isTouched
            ? const BorderSide(color: _white, width: 2)
            : BorderSide.none,
      ));
    }

    return _chartCard(
      title:    'Skin Type Distribution',
      subtitle: 'From completed skin quizzes',
      icon:     Icons.face_retouching_natural_rounded,
      child: total == 0
          ? _emptyState('No skin profiles yet')
          : Column(
              children: [
                SizedBox(
                  height: 190,
                  child: PieChart(
                    PieChartData(
                      sections:          sections,
                      centerSpaceRadius: 48,
                      sectionsSpace:     3,
                      pieTouchData: PieTouchData(
                        touchCallback: (event, response) {
                          setState(() {
                            if (!event.isInterestedForInteractions ||
                                response == null ||
                                response.touchedSection == null) {
                              _skinTypeTouchedIndex = -1;
                              return;
                            }
                            _skinTypeTouchedIndex =
                                response.touchedSection!.touchedSectionIndex;
                          });
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _buildDonutLegend([
                  for (int i = 0; i < entries.length; i++)
                    _LegendItem(
                      entries[i].key,
                      _skinTypeColors[i % _skinTypeColors.length],
                      entries[i].value,
                      total,
                    ),
                ]),
              ],
            ),
    );
  }

  // ─────────────────────────────────────────────────────
  // LEGEND BUILDER (shared by both donuts)
  // ─────────────────────────────────────────────────────
  Widget _buildDonutLegend(List<_LegendItem> items) {
    return Wrap(
      spacing:   16,
      runSpacing: 8,
      children: items.map((item) {
        final pct = item.total > 0
            ? (item.count / item.total * 100).toStringAsFixed(1)
            : '0';
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10, height: 10,
              decoration: BoxDecoration(
                color:  item.color,
                shape:  BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              '${item.label} ($pct%)',
              style: const TextStyle(fontSize: 11, color: _mutedBrown),
            ),
          ],
        );
      }).toList(),
    );
  }

  // ─────────────────────────────────────────────────────
  // EMPTY STATE
  // ─────────────────────────────────────────────────────
  Widget _emptyState(String message) {
    return SizedBox(
      height: 120,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined,
                color: _mutedBrown.withOpacity(0.4), size: 32),
            const SizedBox(height: 8),
            Text(message,
              style: TextStyle(
                fontSize: 12,
                color:    _mutedBrown.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// HELPER DATA CLASSES
// ─────────────────────────────────────────────────────────
class _StatCardData {
  final String  label;
  final int     value;
  final IconData icon;
  final Color   color;
  const _StatCardData({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
}

class _LegendItem {
  final String label;
  final Color  color;
  final int    count;
  final int    total;
  const _LegendItem(this.label, this.color, this.count, this.total);
}