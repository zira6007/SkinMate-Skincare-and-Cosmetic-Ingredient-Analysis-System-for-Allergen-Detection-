import 'package:flutter/material.dart';
import 'package:skin_mate/core/constants/app_colors.dart';
import 'package:skin_mate/core/services/supabase_service.dart';
import 'package:skin_mate/core/widgets/loading_spinner.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {

  // ── State ─────────────────────────────────────────────
  bool    _loading = true;
  String? _error;

  // Full list from Supabase
  List<Map<String, dynamic>> _allFeedback      = [];
  // Filtered list shown in UI
  List<Map<String, dynamic>> _filteredFeedback = [];

  // Summary stats
  double _avgRating    = 0.0;
  int    _totalCount   = 0;
  int    _pendingCount = 0;

  // Filters
  String? _statusFilter; // null | 'pending' | 'reviewed' | 'resolved'
  int?    _ratingFilter; // null | 1 | 2 | 3 | 4 | 5

  // Track which items are being updated (for per-row spinners)
  final Set<String> _updatingIds = {};

  // Track which items have the note field expanded
  final Set<String> _expandedNoteIds = {};

  // Note text controllers — one per feedback item
  final Map<String, TextEditingController> _noteControllers = {};

  // ─────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadFeedback();
  }

  @override
  void dispose() {
    for (final c in _noteControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ─────────────────────────────────────────────────────
  // LOAD ALL FEEDBACK + ISSUE TAGS
  // ─────────────────────────────────────────────────────
  Future<void> _loadFeedback() async {
  setState(() { _loading = true; _error = null; });

  try {
    final rows = await SupabaseService.client
        .from('REPORT_FEEDBACK')
        .select()                          // ← no more '*, FEEDBACK_ISSUE(*)'
        .order('created_at', ascending: false);

    final list = List<Map<String, dynamic>>.from(rows as List);

    double totalRating = 0;
    int    pending     = 0;

    for (final row in list) {
      totalRating += (row['rate'] as num? ?? 0).toDouble();
      final status = (row['status'] as String? ?? 'pending').toLowerCase();
      if (status == 'pending') pending++;
    }

    final avg = list.isEmpty ? 0.0 : totalRating / list.length;

    for (final row in list) {
      final id = row['report_id'] as String;
      _noteControllers.putIfAbsent(
        id,
        () => TextEditingController(text: row['admin_note'] as String? ?? ''),
      );
    }

    setState(() {
      _allFeedback  = list;
      _totalCount   = list.length;
      _pendingCount = pending;
      _avgRating    = avg;
      _loading      = false;
    });

    _applyFilters();
  } catch (e) {
    setState(() {
      _error   = 'Failed to load feedback.\n$e';
      _loading = false;
    });
  }
}
  // ─────────────────────────────────────────────────────
  // APPLY FILTERS
  // ─────────────────────────────────────────────────────
  void _applyFilters() {
    List<Map<String, dynamic>> result = _allFeedback;

    if (_statusFilter != null) {
      result = result.where((r) {
        final status = (r['status'] as String? ?? 'pending').toLowerCase();
        return status == _statusFilter;
      }).toList();
    }

    if (_ratingFilter != null) {
      result = result.where((r) {
        final rate = (r['rate'] as num? ?? 0).toInt();
        return rate == _ratingFilter;
      }).toList();
    }

    setState(() => _filteredFeedback = result);
  }

  // ─────────────────────────────────────────────────────
  // UPDATE STATUS
  // ─────────────────────────────────────────────────────
  Future<void> _updateStatus(String reportId, String newStatus) async {
    setState(() => _updatingIds.add(reportId));

    try {
      await SupabaseService.client
          .from('REPORT_FEEDBACK')
          .update({'status': newStatus})
          .eq('report_id', reportId);

      if (!mounted) return;

      // Update local state without full reload
      setState(() {
        final idx = _allFeedback.indexWhere(
            (r) => r['report_id'] == reportId);
        if (idx != -1) {
          _allFeedback[idx] = Map.from(_allFeedback[idx])
            ..['status'] = newStatus;
        }
        _updatingIds.remove(reportId);
      });

      // Recompute pending count
      final pending = _allFeedback.where((r) {
        return (r['status'] as String? ?? 'pending').toLowerCase() == 'pending';
      }).length;
      setState(() => _pendingCount = pending);

      _applyFilters();

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Feedback marked as $newStatus'),
        backgroundColor: newStatus == 'resolved'
            ? AppColors.safeColor : AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _updatingIds.remove(reportId));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:         Text('Update failed: $e'),
        backgroundColor: AppColors.allergenColor,
        behavior:        SnackBarBehavior.floating,
      ));
    }
  }

  // ─────────────────────────────────────────────────────
  // SAVE ADMIN NOTE
  // ─────────────────────────────────────────────────────
  Future<void> _saveNote(String reportId) async {
    final note = _noteControllers[reportId]?.text.trim() ?? '';
    setState(() => _updatingIds.add('note_$reportId'));

    try {
      await SupabaseService.client
          .from('REPORT_FEEDBACK')
          .update({'admin_note': note.isEmpty ? null : note})
          .eq('report_id', reportId);

      if (!mounted) return;
      setState(() => _updatingIds.remove('note_$reportId'));

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:         const Text('Note saved'),
        backgroundColor: AppColors.safeColor,
        behavior:        SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _updatingIds.remove('note_$reportId'));
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
          ? const LoadingSpinner(message: 'Loading feedback...')
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
          const Icon(Icons.error_outline,
              color: AppColors.primary, size: 48),
          const SizedBox(height: 16),
          Text(_error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.textPrimary, fontSize: 13)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _loadFeedback,
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
    return RefreshIndicator(
      onRefresh: _loadFeedback,
      color:     AppColors.primary,
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            // Summary cards
            _buildSummaryCards(),
            const SizedBox(height: 20),
            // Filter toolbar
            _buildFilterBar(),
            const SizedBox(height: 8),
            // Result count
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                '${_filteredFeedback.length} of $_totalCount feedback items',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
            // Feedback list
            Expanded(
              child: _filteredFeedback.isEmpty
                  ? _buildEmpty()
                  : ListView.separated(
                      physics:      const AlwaysScrollableScrollPhysics(),
                      itemCount:    _filteredFeedback.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 12),
                      itemBuilder: (_, i) =>
                          _buildFeedbackCard(_filteredFeedback[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  // HEADER
  // ─────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Feedback & Reports',
                style: TextStyle(
                  fontSize:      22,
                  fontWeight:    FontWeight.w800,
                  color:         AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              Text(
                'User-submitted feedback and issue reports',
                style: TextStyle(
                    fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: _loadFeedback,
          icon:    const Icon(Icons.refresh_rounded),
          color:   AppColors.textSecondary,
          tooltip: 'Refresh',
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────
  // SUMMARY CARDS ROW
  // ─────────────────────────────────────────────────────
  Widget _buildSummaryCards() {
    return LayoutBuilder(builder: (_, constraints) {
      final cols = constraints.maxWidth > 700 ? 3 : 1;
      return GridView.count(
        crossAxisCount:   cols,
        shrinkWrap:       true,
        physics:          const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 14,
        mainAxisSpacing:  14,
        childAspectRatio: cols == 3 ? 3.2 : 3.5,
        children: [
          _summaryCard(
            icon:    Icons.star_rounded,
            color:   AppColors.cautionColor,
            label:   'Average Rating',
            value:   _avgRating.toStringAsFixed(1),
            suffix:  '/ 5.0',
            subWidget: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(5, (i) => Icon(
                i < _avgRating.round()
                    ? Icons.star_rounded
                    : Icons.star_outline_rounded,
                color: AppColors.cautionColor,
                size:  14,
              )),
            ),
          ),
          _summaryCard(
            icon:  Icons.feedback_rounded,
            color: AppColors.primary,
            label: 'Total Feedback',
            value: _totalCount.toString(),
          ),
          _summaryCard(
            icon:    Icons.pending_actions_rounded,
            color:   _pendingCount > 0
                ? AppColors.allergenColor
                : AppColors.safeColor,
            label:   'Pending Review',
            value:   _pendingCount.toString(),
            suffix:  _pendingCount == 0 ? ' ✓ All resolved' : ' need attention',
          ),
        ],
      );
    });
  }

  Widget _summaryCard({
    required IconData icon,
    required Color    color,
    required String   label,
    required String   value,
    String?           suffix,
    Widget?           subWidget,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset:     const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color:        color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(value,
                      style: const TextStyle(
                        fontSize:   22,
                        fontWeight: FontWeight.w800,
                        color:      AppColors.textPrimary,
                        height:     1.1,
                      )),
                    if (suffix != null) ...[
                      const SizedBox(width: 4),
                      Text(suffix,
                        style: const TextStyle(
                          fontSize: 11,
                          color:    AppColors.textSecondary)),
                    ],
                  ],
                ),
                Text(label,
                  style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
                if (subWidget != null) ...[
                  const SizedBox(height: 2),
                  subWidget,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  // FILTER BAR
  // ─────────────────────────────────────────────────────
  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Wrap(
        spacing:    10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [

          // Status filter
          _filterDrop<String?>(
            value: _statusFilter,
            hint:  'All statuses',
            items: [
              const DropdownMenuItem(value: null, child: Text('All statuses')),
              ...[
                ('pending',  '🕐 Pending'),
                ('reviewed', '👁 Reviewed'),
                ('resolved', '✓  Resolved'),
              ].map((t) => DropdownMenuItem(
                value: t.$1,
                child: Row(children: [
                  _statusDot(t.$1),
                  const SizedBox(width: 8),
                  Text(t.$2),
                ]),
              )),
            ],
            onChanged: (v) {
              setState(() => _statusFilter = v);
              _applyFilters();
            },
          ),

          // Star rating filter
          _filterDrop<int?>(
            value: _ratingFilter,
            hint:  'All ratings',
            items: [
              const DropdownMenuItem(value: null, child: Text('All ratings')),
              ...List.generate(5, (i) {
                final stars = 5 - i;
                return DropdownMenuItem(
                  value: stars,
                  child: Row(
                    children: [
                      ...List.generate(stars, (_) => const Icon(
                        Icons.star_rounded,
                        color: AppColors.cautionColor,
                        size:  14,
                      )),
                      const SizedBox(width: 4),
                      Text('$stars star${stars == 1 ? '' : 's'}',
                        style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                );
              }),
            ],
            onChanged: (v) {
              setState(() => _ratingFilter = v);
              _applyFilters();
            },
          ),

          // Clear filters
          if (_statusFilter != null || _ratingFilter != null)
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _statusFilter = null;
                  _ratingFilter = null;
                });
                _applyFilters();
              },
              icon:  const Icon(Icons.clear_all_rounded, size: 16),
              label: const Text('Clear'),
              style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary),
            ),
        ],
      ),
    );
  }

  Widget _filterDrop<T>({
    required T                         value,
    required String                    hint,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?>          onChanged,
  }) {
    return Container(
      height:  40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color:        AppColors.background,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          icon:  const Icon(Icons.keyboard_arrow_down_rounded,
            color: AppColors.textSecondary, size: 18),
          style: const TextStyle(
            fontSize: 13, color: AppColors.textPrimary),
          items:     items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  // FEEDBACK CARD
  // One card per feedback row
  // ─────────────────────────────────────────────────────
  Widget _buildFeedbackCard(Map<String, dynamic> row) {
    final reportId  = row['report_id']    as String;
    final rate      = (row['rate']        as num?    ?? 0).toInt();
    final comment   = row['rate_comment'] as String? ?? '';
    final issComment = row['issues_comment'] as String? ?? '';
    final dateSend  = row['created_at']    as String?;
    final status    = (row['status']      as String? ?? 'pending').toLowerCase();
    final adminNote = row['admin_note']   as String? ?? '';
    final tag = row['issue_tag'] as String?;
final issues = (tag != null && tag.isNotEmpty) ? [tag] : <String>[];

    final isUpdating     = _updatingIds.contains(reportId);
    final isNoteSaving   = _updatingIds.contains('note_$reportId');
    final isNoteExpanded = _expandedNoteIds.contains(reportId);

    // Ensure controller exists
    _noteControllers.putIfAbsent(
        reportId, () => TextEditingController(text: adminNote));

    return Container(
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: status == 'resolved'
              ? AppColors.safeColor.withOpacity(0.3)
              : status == 'reviewed'
                  ? AppColors.primary.withOpacity(0.2)
                  : AppColors.border,
        ),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset:     const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Card header ────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // Star rating
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: List.generate(5, (i) => Icon(
                        i < rate
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: AppColors.cautionColor,
                        size:  18,
                      )),
                    ),
                    const SizedBox(height: 2),
                    Text('$rate / 5',
                      style: const TextStyle(
                        fontSize:   11,
                        color:      AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      )),
                  ],
                ),

                const SizedBox(width: 16),
                const Spacer(),

                // Date
                if (dateSend != null)
                  Text(
                    _formatDate(dateSend),
                    style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary),
                  ),

                const SizedBox(width: 10),

                // Status badge
                _buildStatusBadge(status),
              ],
            ),
          ),

          // ── Comment ────────────────────────────────────
          if (comment.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
              child: Text(
                comment,
                style: const TextStyle(
                  fontSize: 13,
                  color:    AppColors.textPrimary,
                  height:   1.5,
                ),
              ),
            ),

          // ── Issue tags ────────────────────────────────
          if (issues.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
              child: Wrap(
                spacing:    6,
                runSpacing: 6,
                children: issues.map((tag) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color:        AppColors.allergenBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.allergenColor.withOpacity(0.25)),
                  ),
                  child: Text(tag,
                    style: const TextStyle(
                      fontSize:   11,
                      color:      AppColors.allergenText,
                      fontWeight: FontWeight.w500,
                    )),
                )).toList(),
              ),
            ),

          // ── Issues comment ────────────────────────────
          if (issComment.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color:        AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '"$issComment"',
                  style: TextStyle(
                    fontSize:  12,
                    color:     AppColors.textSecondary,
                    fontStyle: FontStyle.italic,
                    height:    1.5,
                  ),
                ),
              ),
            ),

          // ── Admin note ────────────────────────────────
          if (adminNote.isNotEmpty && !isNoteExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
              child: Row(
                children: [
                  const Icon(Icons.sticky_note_2_outlined,
                    size: 13, color: AppColors.primary),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      'Note: $adminNote',
                      style: const TextStyle(
                        fontSize:  11,
                        color:     AppColors.primary,
                        fontStyle: FontStyle.italic,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

          // ── Expandable note field ─────────────────────
          if (isNoteExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Admin Note',
                    style: TextStyle(
                      fontSize:   11,
                      fontWeight: FontWeight.w600,
                      color:      AppColors.textLabel,
                    )),
                  const SizedBox(height: 5),
                  TextFormField(
                    controller: _noteControllers[reportId],
                    maxLines:   3,
                    style: const TextStyle(
                      fontSize: 12, color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Add internal note...',
                      hintStyle: const TextStyle(
                        fontSize: 12, color: AppColors.textHint),
                      filled:    true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(9),
                        borderSide: const BorderSide(
                          color: AppColors.border)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(9),
                        borderSide: const BorderSide(
                          color: AppColors.border)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(9),
                        borderSide: const BorderSide(
                          color:  AppColors.primary, width: 1.5)),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: SizedBox(
                      height: 32,
                      child: ElevatedButton(
                        onPressed: isNoteSaving
                            ? null
                            : () => _saveNote(reportId),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        child: isNoteSaving
                            ? const SizedBox(
                                width: 14, height: 14,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2))
                            : const Text('Save Note',
                                style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // ── Action row ────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
            child: Row(
              children: [

                // Note toggle button
                _actionButton(
                  icon:    isNoteExpanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.sticky_note_2_outlined,
                  label:   isNoteExpanded ? 'Hide Note' : 'Add Note',
                  color:   AppColors.primary,
                  bgColor: AppColors.secondaryLight,
                  onTap: () {
                    setState(() {
                      if (isNoteExpanded) {
                        _expandedNoteIds.remove(reportId);
                      } else {
                        _expandedNoteIds.add(reportId);
                      }
                    });
                  },
                ),

                const SizedBox(width: 8),

                // Status action buttons
                if (status == 'pending') ...[
                  _actionButton(
                    icon:    Icons.visibility_outlined,
                    label:   'Mark Reviewed',
                    color:   AppColors.primary,
                    bgColor: AppColors.lightPink,
                    loading: isUpdating,
                    onTap: () => _updateStatus(reportId, 'reviewed'),
                  ),
                  const SizedBox(width: 8),
                  _actionButton(
                    icon:    Icons.check_circle_outline_rounded,
                    label:   'Resolve',
                    color:   AppColors.safeColor,
                    bgColor: AppColors.safeBg,
                    loading: isUpdating,
                    onTap: () => _updateStatus(reportId, 'resolved'),
                  ),
                ] else if (status == 'reviewed') ...[
                  _actionButton(
                    icon:    Icons.check_circle_outline_rounded,
                    label:   'Resolve',
                    color:   AppColors.safeColor,
                    bgColor: AppColors.safeBg,
                    loading: isUpdating,
                    onTap: () => _updateStatus(reportId, 'resolved'),
                  ),
                  const SizedBox(width: 8),
                  _actionButton(
                    icon:    Icons.undo_rounded,
                    label:   'Reopen',
                    color:   AppColors.cautionColor,
                    bgColor: AppColors.cautionBg,
                    loading: isUpdating,
                    onTap: () => _updateStatus(reportId, 'pending'),
                  ),
                ] else if (status == 'resolved') ...[
                  _actionButton(
                    icon:    Icons.undo_rounded,
                    label:   'Reopen',
                    color:   AppColors.cautionColor,
                    bgColor: AppColors.cautionBg,
                    loading: isUpdating,
                    onTap: () => _updateStatus(reportId, 'pending'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Small action button ────────────────────────────────
  Widget _actionButton({
    required IconData      icon,
    required String        label,
    required Color         color,
    required Color         bgColor,
    required VoidCallback  onTap,
    bool                   loading = false,
  }) {
    return InkWell(
      onTap:        loading ? null : onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color:        bgColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: loading
              ? [SizedBox(
                  width: 13, height: 13,
                  child: CircularProgressIndicator(
                    color: color, strokeWidth: 1.8))]
              : [
                  Icon(icon, size: 14, color: color),
                  const SizedBox(width: 5),
                  Text(label,
                    style: TextStyle(
                      fontSize:   12,
                      fontWeight: FontWeight.w600,
                      color:      color,
                    )),
                ],
        ),
      ),
    );
  }

  // ── Status badge widget ────────────────────────────────
  Widget _buildStatusBadge(String status) {
    Color bg, fg;
    IconData icon;
    String label;

    switch (status) {
      case 'resolved':
        bg = AppColors.safeBg; fg = AppColors.safeText;
        icon  = Icons.check_circle_rounded; label = 'Resolved'; break;
      case 'reviewed':
        bg = AppColors.secondaryLight; fg = AppColors.primary;
        icon  = Icons.visibility_rounded; label = 'Reviewed'; break;
      default:
        bg = AppColors.cautionBg; fg = AppColors.cautionText;
        icon  = Icons.pending_rounded; label = 'Pending'; break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color:        bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(label,
            style: TextStyle(
              fontSize:   11,
              fontWeight: FontWeight.w700,
              color:      fg,
            )),
        ],
      ),
    );
  }

  // ── Status dot for dropdown ────────────────────────────
  Widget _statusDot(String status) {
    final color = status == 'resolved'
        ? AppColors.safeColor
        : status == 'reviewed'
            ? AppColors.primary
            : AppColors.cautionColor;
    return Container(
      width: 8, height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  // ── Format ISO date string ─────────────────────────────
  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final months = ['Jan','Feb','Mar','Apr','May','Jun',
                      'Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return iso.substring(0, 10);
    }
  }

  // ── Reference to AppColors.lightPink ──────────────────
  Color get lightPink => AppColors.secondaryLight;

  // ─────────────────────────────────────────────────────
  // EMPTY STATE
  // ─────────────────────────────────────────────────────
  Widget _buildEmpty() {
    final hasFilters =
        _statusFilter != null || _ratingFilter != null;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasFilters
                ? Icons.filter_list_off_rounded
                : Icons.feedback_outlined,
            color: AppColors.textSecondary.withOpacity(0.3),
            size:  52,
          ),
          const SizedBox(height: 14),
          Text(
            hasFilters ? 'No feedback matches filters'
                       : 'No feedback yet',
            style: TextStyle(
              fontSize:   15,
              fontWeight: FontWeight.w600,
              color:      AppColors.textSecondary.withOpacity(0.6),
            ),
          ),
          if (hasFilters) ...[
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _statusFilter = null;
                  _ratingFilter = null;
                });
                _applyFilters();
              },
              icon:  const Icon(Icons.clear_all_rounded, size: 16),
              label: const Text('Clear filters'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary),
            ),
          ],
        ],
      ),
    );
  }
}