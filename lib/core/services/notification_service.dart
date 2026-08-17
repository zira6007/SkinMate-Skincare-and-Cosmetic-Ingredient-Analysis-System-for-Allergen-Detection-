// lib/core/services/notification_service.dart

import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  static final _fcm = FirebaseMessaging.instance;
  static final _local = FlutterLocalNotificationsPlugin();
  static final _supabase = Supabase.instance.client;

  static Future<void> init() async {
    // 1. Request permissions
    await _fcm.requestPermission();

    // 2. Init local notifications
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _local.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );

    // 3. Save FCM token to Supabase
    final token = await _fcm.getToken();
    if (token != null) await _saveToken(token);

    // Refresh token if it changes
    _fcm.onTokenRefresh.listen(_saveToken);

    // 4. Handle foreground messages → show banner + persist
    FirebaseMessaging.onMessage.listen((message) {
      _showLocalNotification(message);
      _saveToDatabase(message);
    });
  }

  // ── Save FCM token → USER_FCM_TOKENS ─────────────────────────────────────
  static Future<void> _saveToken(String token) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    await _supabase.from('USER_FCM_TOKENS').upsert(
      {
        'userID': userId,          // matches your "userID" column
        'token': token,
        'platform': Platform.isAndroid ? 'android' : 'ios',
        'updated_at': DateTime.now().toIso8601String(),
      },
      onConflict: 'token',
    );
  }

  // ── Show local banner while app is in foreground ──────────────────────────
  static Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    await _local.show(
      notification.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'skinmate_channel',
          'SkinMate Notifications',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  // ── Persist incoming push → NOTIFICATIONS ────────────────────────────────
  static Future<void> _saveToDatabase(RemoteMessage message) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    await _supabase.from('NOTIFICATIONS').insert({
      'user_id': userId,
      'title': message.notification?.title ?? '',
      'body':  message.notification?.body  ?? '',
      'type':  message.data['type'] ?? 'general',
    });
  }
}