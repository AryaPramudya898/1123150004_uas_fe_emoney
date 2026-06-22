import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/deeplink_callback_service.dart';
import '../../../core/services/deeplink_service.dart';
import '../../../core/services/biometric_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../injection/injection_container.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/feature_icon.dart';

/// Halaman konfirmasi menghubungkan wallet yang dibuka dari deeplink
/// (`dompetkampus://connect?...` atau `https://dompetkampus.app/connect?...`).
class ConnectWalletPage extends StatelessWidget {
  final Object? data;
  const ConnectWalletPage({super.key, this.data});

  void _cancel(BuildContext context, DeeplinkConnectData payload) {
    // Kirim callback cancelled ke app merchant sebelum kembali ke home.
    DeeplinkCallbackService.notifyConnectCancelled(
      callbackUrl: payload.callbackUrl,
    );
    context.go('/home');
  }

  Future<void> _handleConnect(BuildContext context, DeeplinkConnectData payload) async {
    final bioService = sl<BiometricService>();
    final isAvailable = await bioService.isBiometricAvailable();
    final isEnabled = await bioService.isBiometricEnabled();

    final flowData = {
      'kind': 'connect',
      'merchantId': payload.merchantId,
      'merchantName': payload.merchantName,
      'callbackUrl': payload.callbackUrl,
    };

    if (isAvailable && isEnabled) {
      final success = await bioService.authenticate();
      if (success && context.mounted) {
        // Biometrics succeeded: proceed directly to payment-otp
        context.go('/payment-otp', extra: flowData);
        return;
      }
    }

    // Fallback if biometrics is not available, not enabled, or failed/cancelled
    if (context.mounted) {
      context.go('/pin', extra: flowData);
    }
  }

  @override
  Widget build(BuildContext context) {
    final payload = data;

    if (payload is! DeeplinkConnectData) {
      final message = payload is String
          ? payload
          : 'Link koneksi tidak ditemukan atau tidak valid.';
      return _ErrorView(message: message);
    }

    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) {
      // Store payload as pending in DeeplinkService
      DeeplinkService.setPending(payload);
      // Redirect to login page
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/login');
      });
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancel(context, payload);
      },
      child: Scaffold(
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
                    onPressed: () => _cancel(context, payload),
                  ),
                  const Expanded(
                    child: Text('Hubungkan Akun',
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
                    // Visual linking representation
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Coach E-Money Logo
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
                          child: Icon(Icons.link_rounded, size: 36, color: AppColors.primary),
                        ),
                        // Merchant App Logo (Storefront)
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
                      'Hubungkan ke ${payload.merchantName}?',
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Aplikasi "${payload.merchantName}" meminta izin untuk terhubung dengan akun Coach E-Money Anda.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.slate500,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Benefits list
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: AppColors.shadowSoft,
                      ),
                      child: Column(
                        children: [
                          _BenefitRow(
                            icon: Icons.check_circle_outline_rounded,
                            text: 'Pembayaran instan tanpa repot transfer manual',
                          ),
                          const Divider(height: 20),
                          _BenefitRow(
                            icon: Icons.security_rounded,
                            text: 'Aman, setiap transaksi memerlukan autentikasi PIN Anda',
                          ),
                          const Divider(height: 20),
                          _BenefitRow(
                            icon: Icons.history_rounded,
                            text: 'Riwayat transaksi tercatat secara otomatis',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Actions
            Container(
              color: Colors.white,
              padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppButton(
                    label: 'Hubungkan Akun',
                    onPressed: () => _handleConnect(context, payload),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => _cancel(context, payload),
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
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _BenefitRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
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
                  child: Icon(Icons.link_off_rounded, size: 30, color: AppColors.red),
                ),
              ),
              const SizedBox(height: 18),
              const Text('Gagal Menghubungkan Wallet',
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
