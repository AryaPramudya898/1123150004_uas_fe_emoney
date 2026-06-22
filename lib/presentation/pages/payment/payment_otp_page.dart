import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/deeplink_callback_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../blocs/payment/payment_bloc.dart';
import '../../blocs/auth/otp_bloc.dart';
import '../../widgets/app_button.dart';

/// Halaman verifikasi TOTP (Authenticator App) sebelum transaksi diproses.
/// Halaman ini hanya meminta kode 6 digit dari Google Authenticator.
class PaymentOtpPage extends StatefulWidget {
  final Map<String, dynamic> flowData;
  const PaymentOtpPage({super.key, required this.flowData});

  @override
  State<PaymentOtpPage> createState() => _PaymentOtpPageState();
}

class _PaymentOtpPageState extends State<PaymentOtpPage> {
  final _controller = TextEditingController();
  bool _verifying = false;

  void _verify() {
    final code = _controller.text.trim();
    if (code.length != 6) return;
    setState(() => _verifying = true);

    final flow = widget.flowData;
    final kind = flow['kind'] as String? ?? '';

    if (kind == 'connect') {
      context.read<OtpBloc>().add(OtpVerifyTotp(code));
    } else if (kind == 'transfer' || kind == 'payment' || kind == 'deeplink') {
      context.read<PaymentBloc>().add(PaymentTransferRequested(
            amount: (flow['amount'] as num).toDouble(),
            description: flow['note'] as String? ??
                flow['description'] as String? ??
                'Transfer',
            otpCode: code,
            otpType: 'totp',
          ));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final flow = widget.flowData;
    final kind = flow['kind'] as String? ?? '';
    final amount = (flow['amount'] as num? ?? 0).toDouble();

    return BlocListener<OtpBloc, OtpState>(
      listener: (context, state) {
        if (state is OtpTotpEnabled || state is OtpVerified) {
          // Kirim callback sukses ke merchant jika ada callbackUrl
          final callbackUrl = flow['callbackUrl'] as String?;
          if (callbackUrl != null && callbackUrl.isNotEmpty) {
            DeeplinkCallbackService.notifyConnectSuccess(
              callbackUrl: callbackUrl,
            );
          }
          context.go('/success', extra: {
            'title': 'Koneksi Berhasil',
            'subtitle': 'Akun Anda berhasil terhubung dengan ${flow['merchantName']}',
            'amount': 0.0,
            'lines': [
              ['Aplikasi', flow['merchantName'] as String? ?? 'Sepatu Ku'],
              ['Status', 'Terhubung'],
            ],
          });
        } else if (state is OtpInvalid) {
          setState(() => _verifying = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.red,
            ),
          );
        } else if (state is OtpError) {
          setState(() => _verifying = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: AppColors.red),
          );
        }
      },
      child: BlocListener<PaymentBloc, PaymentState>(
        listener: (context, state) {
          if (state is PaymentTransferSuccess) {
            final result = state.result;

            // Kirim callback sukses ke merchant jika ada callbackUrl
            final callbackUrl = flow['callbackUrl'] as String?;
            if (callbackUrl != null && callbackUrl.isNotEmpty) {
              DeeplinkCallbackService.notifySuccess(
                callbackUrl: callbackUrl,
                reference: flow['reference'] as String?,
                transactionId: result.transactionId,
              );
            }
            context.go('/success', extra: {
              'title': 'Transfer berhasil',
              'subtitle': result.description,
              'amount': result.amount,
              'lines': [
                ['Jumlah', CurrencyFormatter.format(result.amount)],
                ['Saldo setelah', CurrencyFormatter.format(result.balanceAfter)],
                ['Ref', 'DKG${result.transactionId}'],
              ],
            });
          } else if (state is PaymentInvalidOtp) {
            setState(() => _verifying = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Kode tidak valid. Cek kembali kode dari authenticator.'),
                backgroundColor: AppColors.red,
              ),
            );
          } else if (state is PaymentInsufficientBalance) {
            setState(() => _verifying = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Saldo Anda tidak mencukupi untuk melakukan transaksi ini.'),
                backgroundColor: AppColors.red,
              ),
            );
          } else if (state is PaymentError) {
            setState(() => _verifying = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: AppColors.red),
            );
          }
        },
        child: Scaffold(
          backgroundColor: AppColors.bg,
          body: SafeArea(
            child: Column(
              children: [
                // Header
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(4, 8, 16, 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_rounded, color: AppColors.ink),
                        onPressed: () => context.go('/home'),
                      ),
                      const Text(
                        'Verifikasi Keamanan',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 24),

                        // Icon
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.phonelink_lock_rounded,
                              size: 36,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        const Text(
                          'Kode Authenticator',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 8),

                        Text(
                          kind == 'connect'
                              ? 'Buka Google Authenticator atau aplikasi authenticator Anda,\nlalu masukkan kode 6 digit untuk menghubungkan akun dengan ${flow['merchantName']}.'
                              : 'Buka Google Authenticator atau aplikasi authenticator Anda,\nlalu masukkan kode 6 digit untuk transaksi ${CurrencyFormatter.format(amount)}.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13.5,
                            color: AppColors.slate500,
                            height: 1.5,
                          ),
                        ),

                        // Badge metode
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primarySurface,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.qr_code_rounded,
                                size: 14,
                                color: AppColors.primary,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Google Authenticator / TOTP',
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),

                        // OTP Input
                        TextField(
                          controller: _controller,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          textAlign: TextAlign.center,
                          autofocus: true,
                          style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 12,
                            color: AppColors.ink,
                          ),
                          decoration: InputDecoration(
                            counterText: '',
                            hintText: '• • • • • •',
                            hintStyle: const TextStyle(
                              fontSize: 24,
                              color: AppColors.slate300,
                              letterSpacing: 10,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: AppColors.line2),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: AppColors.primary, width: 2),
                            ),
                            contentPadding: const EdgeInsets.symmetric(vertical: 18),
                          ),
                          onChanged: (val) {
                            if (val.length == 6) {
                              _verify();
                            }
                          },
                        ),
                        const SizedBox(height: 24),

                        AppButton(
                          label: _verifying
                              ? 'Memverifikasi...'
                              : (kind == 'connect' ? 'Verifikasi & Hubungkan' : 'Verifikasi & Bayar'),
                          onPressed: _verifying ? null : _verify,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
