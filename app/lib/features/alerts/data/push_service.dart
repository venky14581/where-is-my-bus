import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Registers this device for alerts and shows them while the app is open.
abstract interface class PushService {
  /// Asks for notification permission and saves this device's token under
  /// the student. Safe to call repeatedly.
  Future<void> register(String uid);

  /// Removes this device from the student, before signing out.
  Future<void> unregister(String uid);
}

/// Firebase Cloud Messaging on Android and iOS. Does nothing on the web,
/// which needs a VAPID key and service worker that are not set up, and fails
/// quietly on the emulators' demo project, which FCM does not know.
class FcmPushService implements PushService {
  FcmPushService(this._db);

  static const _channel = AndroidNotificationChannel(
    'alerts',
    'Bus alerts',
    description: 'Your bus is coming, delays, breakdowns and announcements.',
    importance: Importance.high,
  );

  final FirebaseFirestore _db;
  final _local = FlutterLocalNotificationsPlugin();
  String? _token;
  String? _registeredUid;
  StreamSubscription<String>? _refresh;
  StreamSubscription<RemoteMessage>? _foreground;

  bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Future<void> register(String uid) async {
    if (!_supported || _registeredUid == uid) return;
    try {
      final messaging = FirebaseMessaging.instance;
      final permission = await messaging.requestPermission();
      if (permission.authorizationStatus == AuthorizationStatus.denied) return;
      await _setUpForegroundDisplay();
      final token = await messaging.getToken();
      if (token == null) return;
      await _save(uid, token);
      _registeredUid = uid;
      _refresh?.cancel();
      _refresh = messaging.onTokenRefresh.listen((fresh) => _save(uid, fresh));
    } catch (e) {
      // No push on this build (for example the emulators' demo project).
      // The in-app alerts list still works.
      debugPrint('Push registration skipped: $e');
    }
  }

  Future<void> _save(String uid, String token) async {
    final old = _token;
    _token = token;
    if (old != null && old != token) {
      await _db.doc('users/$uid/devices/$old').delete().catchError((_) {});
    }
    await _db.doc('users/$uid/devices/$token').set({
      'platform': defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Android does not show notifications that arrive while the app is open,
  /// so show them as local notifications.
  Future<void> _setUpForegroundDisplay() async {
    if (_foreground != null) return;
    await _local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    await _local
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);
    _foreground = FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification == null) return;
      _local.show(
        id: message.hashCode,
        title: notification.title,
        body: notification.body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(_channel.id, _channel.name,
              channelDescription: _channel.description, importance: Importance.high, priority: Priority.high),
          iOS: const DarwinNotificationDetails(),
        ),
      );
    });
  }

  @override
  Future<void> unregister(String uid) async {
    final token = _token;
    _registeredUid = null;
    await _refresh?.cancel();
    _refresh = null;
    if (!_supported || token == null) return;
    await _db.doc('users/$uid/devices/$token').delete().catchError((_) {});
  }
}
