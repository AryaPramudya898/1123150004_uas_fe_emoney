import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/biometric_service.dart';
import '../../../injection/injection_container.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../blocs/payment/payment_bloc.dart';
import '../../widgets/feature_icon.dart';
import '../../widgets/pin_pad.dart';


class PinPage extends StatefulWidget {
  final Map<String, dynamic> flowData;
  const PinPage({super.key, required this.flowData});

  @override
  State<PinPage> createState() => _PinPageState();
}

class _PinPageState extends State<PinPage> {
  String _pin = '';
  bool _busy = false;
  bool _hasError = false;
  bool _isBioEnabled = false;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    final service = sl<BiometricService>();
    final isAvailable = await service.isBiometricAvailable();
    final isEnabled = await service.isBiometricEnabled();
    if (mounted) {
      setState(() {
        _isBioEnabled = isAvailable && isEnabled;
      });
    }
  }

  Future<void> _authenticateBiometric() async {
    final service = sl<BiometricService>();
    final success = await service.authenticate();
    if (success && mounted) {
      _onComplete('');
    }
  }

  void _onComplete(String pin) {
    // PIN validasi lokal — PIN apapun 6 digit diterima untuk sekarang.
    // Setelah PIN benar → navigasi ke OTP verification page.
    context.go('/payment-otp', extra: widget.flowData);
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<PaymentBloc, PaymentState>(
      listener: (context, state) {
        if (state is PaymentTransferSuccess) {
          final result = state.result;
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
        } else if (state is PaymentTopupSuccess) {
          context.go('/success', extra: {
            'title': 'Top up berhasil',
            'subtitle': 'Saldo kamu bertambah',
            'amount': state.amount,
            'lines': [
              ['Jumlah', CurrencyFormatter.format(state.amount)],
              ['Saldo sekarang', CurrencyFormatter.format(state.balance)],
            ],
          });
        } else if (state is PaymentInvalidOtp) {
          setState(() { _busy = false; _hasError = true; _pin = ''; });
          Future.delayed(const Duration(milliseconds: 800), () {
            if (mounted) setState(() => _hasError = false);
          });
        } else if (state is PaymentError) {
          setState(() => _busy = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: AppColors.red),
          );
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.ink),
                  onPressed: () => context.go('/home'),
                ),
              ),
              if (_busy) ...[
                const Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: AppColors.primary),
                      SizedBox(height: 18),
                      Text('Memproses transaksi…',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.slate600,
                          )),
                    ],
                  ),
                ),
              ] else ...[
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
                    child: Column(
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color: AppColors.primarySurface,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Center(child: Icon(Icons.lock_outline_rounded, size: 26, color: AppColors.primary)),
                        ),
                        const SizedBox(height: 16),
                        const Text('Masukkan PIN',
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                            )),
                        const SizedBox(height: 6),
                        const Text('Masukkan 6 digit PIN keamanan kamu',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13.5, color: AppColors.slate500)),
                        const Spacer(),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 80),
                          transform: _hasError ? (Matrix4.identity()..translate(10.0)) : Matrix4.identity(),
                          child: PinPad(
                            value: _pin,
                            onChanged: (v) => setState(() => _pin = v),
                            onComplete: _onComplete,
                            onBioPressed: _isBioEnabled ? _authenticateBiometric : null,
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text.rich(TextSpan(
                          text: 'Lupa PIN? ',
                          style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 12.5, color: AppColors.slate400),
                          children: [
                            TextSpan(
                              text: 'Reset',
                              style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
                            ),
                          ],
                        )),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
