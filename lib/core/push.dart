import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'api_client.dart';

/// Unread count for the notification bell, refreshed from the server.
final unreadNotifications = ValueNotifier<int>(0);

Future<void> refreshUnread(ApiClient api) async {
  try {
    final data = await api.get('notifications');
    unreadNotifications.value = (data['unread'] as num?)?.toInt() ?? 0;
  } catch (e) {
    // The bell keeps its last count when the server cannot be reached or notifications are not set up.
    debugPrint('Could not load notifications: $e');
  }
}

/// Push notifications through Firebase Cloud Messaging. Stays off when the app is built without
/// the Firebase config file (android/app/google-services.json), and in tests.
class Push {
  /// Shows a notification that arrives while the app is open.
  static void Function(String title, String body)? onForeground;

  /// Opens the notifications page when the member taps a push notification.
  static void Function()? onOpened;

  static bool _started = false;
  static ApiClient? _api;

  /// Registers this phone for push after sign-in. Safe to call more than once.
  static Future<void> start(ApiClient api) async {
    _api = api;
    unawaited(refreshUnread(api));
    try {
      if (!_started) {
        await Firebase.initializeApp();
        final messaging = FirebaseMessaging.instance;
        await messaging.requestPermission();
        // FCM registration tokens work with the server's HTTP v1 sending (includes/member-notify.php);
        // the newer register()/onRegistered gives installation IDs for a different sending method.
        // ignore: deprecated_member_use
        messaging.onTokenRefresh.listen(_register);
        FirebaseMessaging.onMessage.listen((m) {
          if (_api != null) refreshUnread(_api!);
          final n = m.notification;
          if (n != null) onForeground?.call(n.title ?? '', n.body ?? '');
        });
        FirebaseMessaging.onMessageOpenedApp.listen((_) => onOpened?.call());
        if (await messaging.getInitialMessage() != null) onOpened?.call();
        _started = true;
      }
      // ignore: deprecated_member_use
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _register(token);
    } catch (e) {
      debugPrint('Push notifications are off: $e');
    }
  }

  static Future<void> _register(String token) async {
    final api = _api;
    if (api == null || api.token == null) return;
    try {
      await api.post('register_device', {'fcm_token': token, 'platform': defaultTargetPlatform.name});
    } on ApiException catch (e) {
      debugPrint('Could not register for push: ${e.message}');
    }
  }
}
