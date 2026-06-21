import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Mengirimkan notifikasi hasil pembayaran kembali ke aplikasi merchant
/// via deeplink callback (custom scheme atau HTTPS).
///
/// Callback bersifat best-effort: jika aplikasi merchant tidak terpasang
/// atau URI tidak valid, kegagalan diabaikan agar tidak mengganggu alur
/// pembayaran di sisi pengguna.
///
/// Format callback yang dikirimkan:
///   {callbackUrl}?status=success&reference={ref}&transaction_id=TXN{txnId}
///   {callbackUrl}?status=failed&reference={ref}&error={message}
///   {callbackUrl}?status=cancelled&reference={ref}
class DeeplinkCallbackService {
  DeeplinkCallbackService._();

  /// Kirim callback sukses setelah transfer berhasil dikonfirmasi.
  static Future<void> notifySuccess({
    required String callbackUrl,
    required String? reference,
    required int transactionId,
  }) async {
    await _launch(callbackUrl, {
      'status': 'success',
      if (reference != null && reference.isNotEmpty) 'reference': reference,
      'transaction_id': 'TXN$transactionId',
    });
  }

  /// Kirim callback gagal karena error backend atau saldo tidak cukup.
  static Future<void> notifyFailed({
    required String callbackUrl,
    required String? reference,
    String? errorMessage,
  }) async {
    await _launch(callbackUrl, {
      'status': 'failed',
      if (reference != null && reference.isNotEmpty) 'reference': reference,
      if (errorMessage != null && errorMessage.isNotEmpty) 'error': errorMessage,
    });
  }

  /// Kirim callback dibatalkan saat pengguna menutup halaman sebelum bayar.
  static Future<void> notifyCancelled({
    required String callbackUrl,
    required String? reference,
  }) async {
    await _launch(callbackUrl, {
      'status': 'cancelled',
      if (reference != null && reference.isNotEmpty) 'reference': reference,
    });
  }

  static Future<void> _launch(
    String baseUrl,
    Map<String, String> params,
  ) async {
    try {
      final base = Uri.parse(baseUrl);
      // Merge query params yang mungkin sudah ada di callbackUrl
      final merged = {...base.queryParameters, ...params};
      final uri = base.replace(queryParameters: merged);

      debugPrint('[DeeplinkCallback] Mengirim callback: $uri');

      // Tidak pakai canLaunchUrl — custom scheme merchant tidak perlu
      // dideklarasikan di <queries> AndroidManifest. Cukup coba launch
      // dan tangkap error jika app merchant tidak terpasang.
      await launchUrl(uri, mode: LaunchMode.externalNonBrowserApplication);
      debugPrint('[DeeplinkCallback] Callback terkirim.');
    } catch (e) {
      // Callback gagal tidak boleh mengganggu alur payment
      debugPrint('[DeeplinkCallback] App merchant tidak tersedia atau URI tidak valid: $e');
    }
  }
}
