import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/deeplink_callback_service.dart';
import '../../../core/services/deeplink_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_logo.dart';

class DisconnectWalletPage extends StatelessWidget {
  final Object? data;
  const DisconnectWalletPage({super.key, this.data});

  void _cancel(BuildContext context) {
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final payload = data;

    if (payload is! DeeplinkDisconnectData) {
      final message = payload is String
          ? payload
          : 'Link pemutusan tidak ditemukan atau tidak valid.';
      return _ErrorView(message: message);
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          Container(
            color: AppColors.primary,
            padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 6, 16, 14),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: () => _cancel(context),
                ),
                const Expanded(
                  child: Text('Putuskan Sambungan',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      )),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: AppColors.shadowSoft,
                        ),
                        child: const AppLogo(size: 50),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Icon(Icons.link_off_rounded, size: 36, color: AppColors.red),
                      ),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: AppColors.shadowSoft,
                        ),
                        child: const Icon(Icons.storefront_rounded, size: 50, color: Colors.blue),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Putuskan Hubungan dengan ${payload.merchantName}?',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Tindakan ini akan mematikan koneksi pembayaran instan antara akun Coach E-Money Anda dengan aplikasi "${payload.merchantName}".',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.slate500,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: AppColors.shadowSoft,
                    ),
                    child: Column(
                      children: [
                        _WarningRow(
                          icon: Icons.cancel_outlined,
                          text: 'Anda tidak dapat lagi melakukan pembayaran instan dari aplikasi tersebut.',
                        ),
                        const Divider(height: 20),
                        _WarningRow(
                          icon: Icons.lock_outline,
                          text: 'Proses ini aman dan membutuhkan autentikasi PIN & Google Authenticator Anda.',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            color: Colors.white,
            padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppButton(
                  label: 'Putuskan Sambungan',
                  variant: AppButtonVariant.danger,
                  onPressed: () => context.go('/pin', extra: {
                    'kind': 'disconnect',
                    'merchantId': payload.merchantId,
                    'merchantName': payload.merchantName,
                    'callbackUrl': payload.callbackUrl,
                  }),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => _cancel(context),
                  child: const Text(
                    'Batalkan',
                    style: TextStyle(
                      color: AppColors.slate400,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WarningRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _WarningRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.red),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.slate600,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.redSurface,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Center(
                  child: Icon(Icons.error_outline_rounded, size: 30, color: AppColors.red),
                ),
              ),
              const SizedBox(height: 18),
              const Text('Gagal Memproses Deeplink',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  )),
              const SizedBox(height: 8),
              Text(message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13.5, color: AppColors.slate500, height: 1.5)),
              const SizedBox(height: 28),
              AppButton(
                label: 'Kembali ke Beranda',
                fullWidth: false,
                onPressed: () => context.go('/home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
