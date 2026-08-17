// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:skin_mate/core/constants/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// NOTIFICATION MODEL
// ─────────────────────────────────────────────────────────────────────────────

enum _NotifType { scan, tip, diary, general }

class _AppNotification {
  final String id;
  final String title;
  final String body;
  final DateTime time;
  final _NotifType type;
  bool isRead;

  _AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.time,
    required this.type,
    this.isRead = false,
  });

  factory _AppNotification.fromRow(Map<String, dynamic> row) {
    return _AppNotification(
      id:     row['notificationID'] as String,   // ← your PK column
      title:  row['title'] as String,
      body:   row['body'] as String,
      time:   DateTime.parse(row['created_at'] as String).toLocal(),
      type:   _NotifType.values.firstWhere(
                (e) => e.name == (row['type'] as String? ?? 'general'),
                orElse: () => _NotifType.general,
              ),
      isRead: row['is_read'] as bool? ?? false,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NOTIFICATIONS SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _supabase = Supabase.instance.client;

  List<_AppNotification> _notifications = [];
  bool _isLoading = true;
  String? _error;

  RealtimeChannel? _channel;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  // ── Data ──────────────────────────────────────────────────────────────────

  Future<void> _loadNotifications() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      setState(() {
        _error = 'Not signed in.';
        _isLoading = false;
      });
      return;
    }

    try {
      final data = await _supabase
          .from('NOTIFICATIONS')               // ← your exact table name
          .select()
          .eq('userID', userId)                // ← your exact column name
          .order('created_at', ascending: false);

      if (!mounted) return;
      setState(() {
        _notifications = (data as List)
            .map((row) => _AppNotification.fromRow(row as Map<String, dynamic>))
            .toList();
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      print('SUPABASE ERROR: $e');
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _subscribeRealtime() {
  final userId = _supabase.auth.currentUser?.id;
  if (userId == null) return;

  _channel = _supabase
      .channel('NOTIFICATIONS_$userId')
      .onPostgresChanges(
        event:    PostgresChangeEvent.insert,
        schema:   'public',
        table:    'NOTIFICATIONS',
        callback: (_) => _loadNotifications(),  // no filter param at all
      )
      .subscribe();
}

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _markRead(String id) async {
    setState(() {
      final idx = _notifications.indexWhere((n) => n.id == id);
      if (idx != -1) _notifications[idx].isRead = true;
    });
    await _supabase
        .from('NOTIFICATIONS')
        .update({'is_read': true})
        .eq('notificationID', id);            // ← your PK column
  }

  Future<void> _dismiss(String id) async {
    HapticFeedback.lightImpact();
    setState(() => _notifications.removeWhere((n) => n.id == id));
    await _supabase
        .from('NOTIFICATIONS')
        .delete()
        .eq('notificationID', id);            // ← your PK column
  }

  void _deleteAll() {
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Clear all notifications?',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        content: Text(
          'This will permanently remove all your notifications.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final userId = _supabase.auth.currentUser?.id;
              if (userId == null) return;

              setState(() => _notifications.clear());

              await _supabase
                  .from('NOTIFICATIONS')
                  .delete()
                  .eq('userID', userId);      // ← your FK column
            },
            child: const Text(
              'Delete All',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _timeLabel(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} mins ago';
    if (diff.inHours < 24)   return '${diff.inHours}h ago';
    if (diff.inDays == 1)    return 'Yesterday';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  IconData _iconFor(_NotifType type) {
    switch (type) {
      case _NotifType.scan:    return Icons.document_scanner_outlined;
      case _NotifType.tip:     return Icons.lightbulb_outline_rounded;
      case _NotifType.diary:   return Icons.book_outlined;
      case _NotifType.general: return Icons.notifications_outlined;
    }
  }

  Color _iconColorFor(_NotifType type) {
    switch (type) {
      case _NotifType.scan:    return AppColors.primary;
      case _NotifType.tip:     return const Color(0xFFFFB800);
      case _NotifType.diary:   return AppColors.primaryDark;
      case _NotifType.general: return AppColors.primaryMuted;
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: _buildBody(),
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
            child: Icon(
              Icons.chevron_left_rounded,
              color: AppColors.textPrimary,
              size: 22,
            ),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Notifications',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        actions: [
          if (_notifications.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: TextButton(
                onPressed: _deleteAll,
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.cardBackground,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(color: AppColors.border),
                  ),
                ),
                child: Text(
                  'Delete All',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.divider),
        ),
      );

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded,
                size: 48, color: AppColors.primaryMuted.withOpacity(0.4)),
            const SizedBox(height: 12),
            Text(
              'Failed to load notifications.',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _error = null;
                });
                _loadNotifications();
              },
              child: Text(
                'Try again',
                style: TextStyle(color: AppColors.primary),
              ),
            ),
          ],
        ),
      );
    }

    if (_notifications.isEmpty) return _buildEmpty();
    return _buildList();
  }

  Widget _buildList() {
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _loadNotifications,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        itemCount: _notifications.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) => _buildNotifCard(_notifications[i]),
      ),
    );
  }

  Widget _buildNotifCard(_AppNotification n) {
    return Dismissible(
      key: Key(n.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _dismiss(n.id),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.redAccent.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(
          Icons.delete_outline_rounded,
          color: Colors.redAccent,
          size: 22,
        ),
      ),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          if (!n.isRead) _markRead(n.id);
          // TODO: navigate based on n.type
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: n.isRead
                  ? AppColors.border
                  : AppColors.primary.withOpacity(0.35),
              width: n.isRead ? 1 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon badge
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _iconColorFor(n.type).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _iconFor(n.type),
                  size: 18,
                  color: _iconColorFor(n.type),
                ),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            n.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: n.isRead
                                  ? FontWeight.w600
                                  : FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _timeLabel(n.time),
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    if (!n.isRead) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'New',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      n.body,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.5,
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

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: 52,
            color: AppColors.primaryMuted.withOpacity(0.35),
          ),
          const SizedBox(height: 12),
          Text(
            'No notifications yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "You're all caught up!",
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}