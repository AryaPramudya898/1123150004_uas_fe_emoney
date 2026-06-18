import 'dart:developer' as developer;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../presentation/blocs/auth/auth_bloc.dart';

// Handler untuk pesan background (harus top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  developer.log('[FCM] Background message received: ${message.notification?.title}');
}

// Alias log shorthand
void _log(String msg) => developer.log(msg);

/// Plugin untuk menampilkan notifikasi lokal (foreground & background)
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

/// Android Notification Channel — harus sama dengan yang di AndroidManifest.xml
const AndroidNotificationChannel _channel = AndroidNotificationChannel(
  'emoney_topup_channel',       // id
  'Transaksi E-Money',          // name
  description: 'Notifikasi untuk top up, transfer, dan transaksi lainnya',
  importance: Importance.high,
  playSound: true,
  enableVibration: true,
);

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static bool _permissionRequested = false;
  static bool _listenerSetup = false;
  static bool _localNotifInit = false;

  /// Inisialisasi flutter_local_notifications dan buat Android channel
  static Future<void> _initLocalNotifications() async {
    if (_localNotifInit) return;
    _localNotifInit = true;

    // Buat notification channel di Android
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    // Init plugin
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings =
        InitializationSettings(android: androidSettings);
    await flutterLocalNotificationsPlugin.initialize(initSettings);

    _log('[FCM] flutter_local_notifications initialized');
  }

  /// Tampilkan notifikasi lokal (gunakan ini untuk foreground & background)
  static Future<void> showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'emoney_topup_channel',
      'Transaksi E-Money',
      channelDescription: 'Notifikasi untuk top up, transfer, dan transaksi lainnya',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
    );

    const NotificationDetails details = NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPlugin.show(
      notification.hashCode,
      notification.title,
      notification.body,
      details,
    );
    _log('[FCM] Local notification shown: ${notification.title}');
  }

  /// Minta izin notifikasi dan daftarkan FCM token ke backend.
  /// Gunakan [authBloc] (bukan BuildContext) agar tidak ada masalah mounted.
  static Future<void> registerToken(AuthBloc authBloc) async {
    // Init local notifications & Android channel
    await _initLocalNotifications();

    // Set foreground presentation options
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    if (!_permissionRequested) {
      _permissionRequested = true;
      try {
        NotificationSettings settings = await _messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
        _log('[FCM] Permission status: ${settings.authorizationStatus}');
      } catch (e) {
        _log('[FCM] Error requesting permission: $e');
      }
    }

    try {
      String? token = await _messaging.getToken();
      if (token != null) {
        _log('[FCM] Token obtained: ${token.substring(0, 20)}...');
        authBloc.add(AuthUpdateFcmToken(token));
        _log('[FCM] AuthUpdateFcmToken event dispatched');
      } else {
        _log('[FCM] WARNING: getToken() returned null');
      }
    } catch (e) {
      _log('[FCM] Error getting token: $e');
    }

    // Setup token refresh listener sekali saja
    if (!_listenerSetup) {
      _listenerSetup = true;
      _messaging.onTokenRefresh.listen((newToken) {
        _log('[FCM] Token refreshed: ${newToken.substring(0, 20)}...');
        authBloc.add(AuthUpdateFcmToken(newToken));
      });
    }
  }

  /// Setup listener pesan foreground — tampilkan sebagai notifikasi sistem HP.
  static void setupForegroundListener() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _log('[FCM] Foreground message received: ${message.notification?.title}');
      // Tampilkan sebagai notifikasi sistem (bukan hanya Snackbar)
      showLocalNotification(message);
    });
  }
}
