import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Payload yang diterima dari deeplink pembayaran merchant.
///
/// Format URL yang didukung:
///   dompetkampus://pay?merchant_id=...&merchant_name=...&amount=...
///                      &description=...&reference=...&callback=...
///   https://dompetkampus.app/pay?merchant_id=...&...  (App Link, opsional)
@immutable
class DeeplinkPaymentData {
  final String merchantId;
  final String merchantName;
  final double amount;
  final String description;
  final String? reference;
  final String? callbackUrl;

  const DeeplinkPaymentData({
    required this.merchantId,
    required this.merchantName,
    required this.amount,
    required this.description,
    this.reference,
    this.callbackUrl,
  });

  factory DeeplinkPaymentData.fromUri(Uri uri) {
    final q = uri.queryParameters;

    final merchantId   = q['merchant_id'];
    final merchantName = q['merchant_name'];
    final amountStr    = q['amount'];

    if (merchantId == null || merchantId.trim().isEmpty) {
      throw const FormatException('Link pembayaran tidak valid: merchant_id tidak ditemukan.');
    }
    if (merchantName == null || merchantName.trim().isEmpty) {
      throw const FormatException('Link pembayaran tidak valid: merchant_name tidak ditemukan.');
    }
    if (amountStr == null || amountStr.trim().isEmpty) {
      throw const FormatException('Link pembayaran tidak valid: amount tidak ditemukan.');
    }

    final amount = double.tryParse(amountStr);
    if (amount == null || amount <= 0) {
      throw const FormatException('Link pembayaran tidak valid: amount harus berupa angka > 0.');
    }

    return DeeplinkPaymentData(
      merchantId:   merchantId,
      merchantName: merchantName,
      amount:       amount,
      description:  q['description']?.trim().isNotEmpty == true
          ? q['description']!.trim()
          : 'Pembayaran ke $merchantName',
      reference:   q['reference'],
      callbackUrl: q['callback'],
    );
  }
}

/// Payload yang diterima dari deeplink menghubungkan wallet.
/// Format URL yang didukung:
///   dompetkampus://connect?merchant_id=...&merchant_name=...&callback=...
@immutable
class DeeplinkConnectData {
  final String merchantId;
  final String merchantName;
  final String callbackUrl;

  const DeeplinkConnectData({
    required this.merchantId,
    required this.merchantName,
    required this.callbackUrl,
  });

  factory DeeplinkConnectData.fromUri(Uri uri) {
    final q = uri.queryParameters;
    final merchantId = q['merchant_id'];
    final merchantName = q['merchant_name'];
    final callbackUrl = q['callback'];

    if (merchantId == null || merchantId.trim().isEmpty) {
      throw const FormatException('Link koneksi tidak valid: merchant_id tidak ditemukan.');
    }
    if (merchantName == null || merchantName.trim().isEmpty) {
      throw const FormatException('Link koneksi tidak valid: merchant_name tidak ditemukan.');
    }
    if (callbackUrl == null || callbackUrl.trim().isEmpty) {
      throw const FormatException('Link koneksi tidak valid: callback tidak ditemukan.');
    }

    return DeeplinkConnectData(
      merchantId: merchantId,
      merchantName: merchantName,
      callbackUrl: callbackUrl,
    );
  }
}

/// Mendengarkan deeplink pembayaran dan mengarahkan ke halaman /pay.
///
/// ## Dua skenario yang ditangani berbeda:
///
/// **Cold-start** (app dibuka via deeplink dari keadaan mati):
///   `getInitialLink()` dipanggil sebelum `runApp()` sehingga GoRouter
///   belum ter-mount. URI disimpan di [_pendingPayload] dan TIDAK langsung
///   dinavigasi. SplashPage mengambilnya via [consumePending()] setelah
///   autentikasi selesai.
///
/// **In-app** (deeplink masuk saat app sudah berjalan):
///   GoRouter sudah ter-mount → `router.go('/pay')` atau `/connect-wallet` langsung dijalankan.
class DeeplinkService {
  final GoRouter _router;
  final AppLinks _appLinks;
  StreamSubscription<Uri>? _subscription;

  // Payload yang menunggu diproses setelah SplashPage selesai auth check.
  // Bisa berupa DeeplinkPaymentData, DeeplinkConnectData atau String (pesan error).
  static Object? _pendingPayload;

  /// Ambil dan hapus pending payload (dipanggil dari SplashPage).
  /// Mengembalikan null jika tidak ada deeplink yang menunggu.
  static Object? consumePending() {
    final payload = _pendingPayload;
    _pendingPayload = null;
    debugPrint('[DeeplinkService] consumePending: $payload');
    return payload;
  }

  static bool get hasPending => _pendingPayload != null;

  DeeplinkService(this._router) : _appLinks = AppLinks();

  Future<void> init() async {
    debugPrint('[DeeplinkService] init() dipanggil');

    // Cold-start: simpan URI sebagai pending, JANGAN navigasi sekarang
    // karena GoRouter belum ter-mount (runApp belum dipanggil).
    try {
      final initialUri = await _appLinks.getInitialLink();
      debugPrint('[DeeplinkService] initialUri (cold-start): $initialUri');
      if (initialUri != null && (_isPaymentLink(initialUri) || _isConnectLink(initialUri))) {
        _storePending(initialUri);
      }
    } catch (e) {
      debugPrint('[DeeplinkService] getInitialLink error: $e');
    }

    // In-app: navigasi via post-frame setelah GoRouter ter-mount.
    _subscription = _appLinks.uriLinkStream.listen(
      _handleInAppUri,
      onError: (e) => debugPrint('[DeeplinkService] stream error: $e'),
      onDone: () => debugPrint('[DeeplinkService] stream DITUTUP (seharusnya tidak terjadi)'),
    );
    debugPrint('[DeeplinkService] uriLinkStream aktif — subscription: $_subscription');
  }

  /// Simpan URI cold-start sebagai pending (belum navigasi).
  void _storePending(Uri uri) {
    try {
      if (_isPaymentLink(uri)) {
        _pendingPayload = DeeplinkPaymentData.fromUri(uri);
      } else if (_isConnectLink(uri)) {
        _pendingPayload = DeeplinkConnectData.fromUri(uri);
      }
      debugPrint('[DeeplinkService] Pending tersimpan: $_pendingPayload');
    } on FormatException catch (e) {
      _pendingPayload = e.message;
      debugPrint('[DeeplinkService] Pending error tersimpan: ${e.message}');
    }
  }

  /// Handle URI in-app: GoRouter sudah mounted, jadwalkan navigasi ke halaman tujuan
  /// di post-frame agar tidak konflik dengan state GoRouter yang sedang update.
  void _handleInAppUri(Uri uri) {
    debugPrint('[DeeplinkService] *** IN-APP URI DITERIMA ***: $uri');
    
    if (_isPaymentLink(uri)) {
      try {
        final data = DeeplinkPaymentData.fromUri(uri);
        debugPrint('[DeeplinkService] Jadwal navigasi /pay — ${data.merchantName} ${data.amount}');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          debugPrint('[DeeplinkService] router.go("/pay") dieksekusi');
          _router.go('/pay', extra: data);
        });
      } on FormatException catch (e) {
        debugPrint('[DeeplinkService] Format error: ${e.message}');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _router.go('/pay', extra: e.message);
        });
      }
    } else if (_isConnectLink(uri)) {
      try {
        final data = DeeplinkConnectData.fromUri(uri);
        debugPrint('[DeeplinkService] Jadwal navigasi /connect-wallet — ${data.merchantName}');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          debugPrint('[DeeplinkService] router.go("/connect-wallet") dieksekusi');
          _router.go('/connect-wallet', extra: data);
        });
      } on FormatException catch (e) {
        debugPrint('[DeeplinkService] Format error: ${e.message}');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _router.go('/connect-wallet', extra: e.message);
        });
      }
    } else {
      debugPrint('[DeeplinkService] Bukan payment atau connect link, diabaikan.');
    }
  }

  bool _isPaymentLink(Uri uri) {
    if (uri.scheme == 'dompetkampus' && uri.host == 'pay') return true;
    if (uri.scheme == 'https' &&
        uri.host == 'dompetkampus.app' &&
        uri.path.startsWith('/pay')) {
      return true;
    }
    return false;
  }

  bool _isConnectLink(Uri uri) {
    if (uri.scheme == 'dompetkampus' && uri.host == 'connect') return true;
    if (uri.scheme == 'https' &&
        uri.host == 'dompetkampus.app' &&
        uri.path.startsWith('/connect')) {
      return true;
    }
    return false;
  }

  void dispose() => _subscription?.cancel();
}
