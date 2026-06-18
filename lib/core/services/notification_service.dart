import 'dart:developer';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../presentation/blocs/auth/auth_bloc.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static bool _initialized = false;

  static Future<void> initialize(BuildContext context) async {
    if (_initialized) return;
    _initialized = true;

    try {
      log('[FCM] Initializing notifications...');

      // 1. Request notification permission (necessary for Android 13+)
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      log('[FCM] Permission status: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        // 2. Get FCM token
        String? token = await _messaging.getToken();
        if (token != null) {
          log('[FCM] Token obtained: $token');
          if (context.mounted) {
            context.read<AuthBloc>().add(AuthUpdateFcmToken(token));
          }
        }

        // 3. Listen to token refreshes
        _messaging.onTokenRefresh.listen((newToken) {
          log('[FCM] Token refreshed: $newToken');
          if (context.mounted) {
            context.read<AuthBloc>().add(AuthUpdateFcmToken(newToken));
          }
        });
      }

      // 4. Handle foreground notifications (show snackbar when app is open)
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        log('[FCM] Foreground message received: ${message.notification?.title}');
        if (context.mounted && message.notification != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.notifications_active, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          message.notification!.title ?? 'Notifikasi',
                          style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          message.notification!.body ?? '',
                          style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              behavior: SnackBarBehavior.floating,
              backgroundColor: const Color(0xFF0E1726), // Match theme dark color
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      });
    } catch (e) {
      log('[FCM] Error initializing: $e');
      _initialized = false;
    }
  }
}
