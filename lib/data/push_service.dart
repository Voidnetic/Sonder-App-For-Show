import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'api_client.dart';

/// Firebase settings for the Android app (Firebase project sonder-bb41b, app com.mhcorps.sonder).
/// None of these are secret: they ship inside every copy of the app and only identify it to Firebase.
/// A build can override them with --dart-define=FIREBASE_API_KEY=... etc.
const _apiKey = String.fromEnvironment('FIREBASE_API_KEY', defaultValue: 'AIzaSyC1NewaUSNiufoTUrWjcE_Hs09FrE8Gi7c');
const _appId = String.fromEnvironment(
  'FIREBASE_APP_ID',
  defaultValue: '1:1075648757478:android:9f91ad9a3d4ed79c73c527',
);
const _senderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID', defaultValue: '1075648757478');
const _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID', defaultValue: 'sonder-bb41b');

/// Shows in-app banners for notifications that arrive while Sonder is open.
final GlobalKey<ScaffoldMessengerState> rootMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// Push notifications (friend requests, new moments, chat, "your moment is unlocked").
/// Does nothing on builds without the Firebase settings, so the app works the same without them.
class PushService {
  static bool _ready = false;
  static String? _token;

  static bool get isConfigured =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android && _apiKey.isNotEmpty && _appId.isNotEmpty;

  /// Called once at startup. Never throws.
  static Future<void> init() async {
    if (!isConfigured) return;
    try {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: _apiKey,
          appId: _appId,
          messagingSenderId: _senderId,
          projectId: _projectId,
        ),
      );
    } catch (e) {
      debugPrint('Push notifications are off: $e');
      return;
    }
    _ready = true;

    FirebaseMessaging.onMessage.listen((message) {
      final n = message.notification;
      if (n == null) return;
      rootMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(
            [n.title, n.body].whereType<String>().join('\n'),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      );
    });
    // getToken/onTokenRefresh give the registration token the server's FCM HTTP v1 "token" field expects.
    // firebase_messaging 17 deprecates them in favour of installation IDs; switch once the server sends to those.
    // ignore: deprecated_member_use
    FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      _token = token;
      if (SonderApi.instance.currentUser.value != null) unawaited(_send(token));
    });

    // Register whenever someone signs in, and forget the phone before they sign out.
    SonderApi.instance.currentUser.addListener(_onUserChanged);
    SonderApi.instance.beforeLogout = unregister;
    _onUserChanged();
  }

  static void _onUserChanged() {
    if (SonderApi.instance.currentUser.value != null) unawaited(_register());
  }

  static Future<void> _register() async {
    try {
      // Android 13+ shows the "Allow notifications?" prompt here, once.
      final settings = await FirebaseMessaging.instance.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;
      // ignore: deprecated_member_use
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      _token = token;
      await _send(token);
    } catch (e) {
      debugPrint('Could not register for push notifications: $e');
    }
  }

  static Future<void> _send(String token) async {
    try {
      await SonderApi.instance.registerDevice(token);
    } catch (e) {
      debugPrint('Could not register for push notifications: $e');
    }
  }

  static Future<void> unregister() async {
    final token = _token;
    if (!_ready || token == null) return;
    try {
      await SonderApi.instance.unregisterDevice(token);
    } catch (_) {
      // Best effort; the server also drops tokens Firebase reports as dead.
    }
  }
}
