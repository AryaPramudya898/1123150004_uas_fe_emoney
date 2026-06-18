import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../domain/repositories/auth_repository.dart';
import '../../../domain/usecases/auth/update_profile_usecase.dart';
import '../../../domain/usecases/auth/send_change_email_otp_usecase.dart';
import '../../../domain/usecases/auth/update_email_usecase.dart';
import '../../../injection/injection_container.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../widgets/app_avatar.dart';

class PersonalDataPage extends StatefulWidget {
  const PersonalDataPage({super.key});

  @override
  State<PersonalDataPage> createState() => _PersonalDataPageState();
}

class _PersonalDataPageState extends State<PersonalDataPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  bool _isLoading = false;
  bool _isGoogleUser = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();

    // Trigger check for auth state to load user from local storage
    context.read<AuthBloc>().add(AuthCheckRequested());

    // Detect if logged in via Google Provider
    final providers = FirebaseAuth.instance.currentUser?.providerData ?? [];
    _isGoogleUser = providers.any((info) => info.providerId == 'google.com');

    // Fetch latest user data in background to refresh local cache (in case the cached user JSON is older and lacks created_at)
    sl<AuthRepository>().getMe().then((updatedUser) {
      if (mounted) {
        context.read<AuthBloc>().add(AuthUserUpdated(updatedUser));
      }
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String _formatJoinedDate(String? createdAt) {
    if (createdAt == null) return '-';
    try {
      final parsed = DateTime.parse(createdAt).toLocal();
      return DateFormatter.formatShort(parsed);
    } catch (_) {
      return '-';
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final updateProfileUsecase = sl<UpdateProfileUsecase>();
      final updatedUser = await updateProfileUsecase(_nameController.text.trim());

      if (mounted) {
        // Update global Auth state
        context.read<AuthBloc>().add(AuthUserUpdated(updatedUser));

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white),
                SizedBox(width: 10),
                Text('Profil berhasil diperbarui'),
              ],
            ),
            backgroundColor: AppColors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/akun');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(child: Text(e.toString())),
              ],
            ),
            backgroundColor: AppColors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showChangeEmailDialog(BuildContext context, String currentEmail) {
    final emailController = TextEditingController();
    final otpController = TextEditingController();
    int step = 1; // 1: Input Email, 2: Input OTP
    bool dialogLoading = false;
    String? dialogError;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (builderContext, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    step == 1 ? 'Ubah Alamat Email' : 'Verifikasi OTP',
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: AppColors.ink,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.slate400),
                    onPressed: dialogLoading ? null : () => Navigator.pop(dialogContext),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (dialogError != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.redSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.red.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: AppColors.red, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              dialogError!,
                              style: const TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                color: AppColors.red,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  if (step == 1) ...[
                    const Text(
                      'Masukkan alamat email baru Anda. Kami akan mengirimkan kode OTP untuk memverifikasinya.',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 13,
                        height: 1.4,
                        color: AppColors.slate600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppColors.ink,
                      ),
                      decoration: InputDecoration(
                        hintText: 'emailbaru@domain.com',
                        prefixIcon: const Icon(Icons.mail_outline_rounded, color: AppColors.slate400),
                        filled: true,
                        fillColor: AppColors.bg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ] else ...[
                    Text(
                      'Masukkan 6 digit kode verifikasi yang telah dikirim ke ${emailController.text.trim()}',
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 13,
                        height: 1.4,
                        color: AppColors.slate600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: otpController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 6,
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                        letterSpacing: 6,
                        color: AppColors.ink,
                      ),
                      decoration: InputDecoration(
                        hintText: '000000',
                        counterText: '',
                        filled: true,
                        fillColor: AppColors.bg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ],
                ],
              ),
              actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              actions: [
                GestureDetector(
                  onTap: dialogLoading
                      ? null
                      : () async {
                          final email = emailController.text.trim();
                          if (step == 1) {
                            if (email.isEmpty || !email.contains('@')) {
                              setDialogState(() {
                                dialogError = 'Masukkan email yang valid';
                              });
                              return;
                            }
                            if (email == currentEmail) {
                              setDialogState(() {
                                dialogError = 'Email baru tidak boleh sama dengan email sekarang';
                              });
                              return;
                            }

                            setDialogState(() {
                              dialogLoading = true;
                              dialogError = null;
                            });

                            try {
                              await sl<SendChangeEmailOtpUsecase>().call(email);
                              setDialogState(() {
                                step = 2;
                                dialogLoading = false;
                              });
                            } catch (e) {
                              setDialogState(() {
                                dialogError = e.toString().replaceAll('Exception: ', '');
                                dialogLoading = false;
                              });
                            }
                          } else {
                            final code = otpController.text.trim();
                            if (code.length != 6) {
                              setDialogState(() {
                                dialogError = 'OTP harus terdiri dari 6 digit';
                              });
                              return;
                            }

                            setDialogState(() {
                              dialogLoading = true;
                              dialogError = null;
                            });

                            try {
                              final updatedUser = await sl<UpdateEmailUsecase>().call(email, code);
                              if (context.mounted) {
                                context.read<AuthBloc>().add(AuthUserUpdated(updatedUser));
                                Navigator.pop(dialogContext); // Close dialog
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Row(
                                      children: [
                                        Icon(Icons.check_circle_rounded, color: Colors.white),
                                        SizedBox(width: 8),
                                        Text('Alamat email berhasil diperbarui'),
                                      ],
                                    ),
                                    backgroundColor: AppColors.green,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            } catch (e) {
                              setDialogState(() {
                                dialogError = e.toString().replaceAll('Exception: ', '');
                                dialogLoading = false;
                              });
                            }
                          }
                        },
                  child: Container(
                     width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: dialogLoading ? null : AppColors.primaryGradient,
                      color: dialogLoading ? AppColors.slate300 : null,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: dialogLoading ? null : AppColors.shadowPrimary,
                    ),
                    child: Center(
                      child: dialogLoading
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              step == 1 ? 'Kirim OTP' : 'Verifikasi & Simpan',
                              style: const TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated && !_isInitialized) {
          _nameController.text = state.user.name;
          _isInitialized = true;
        }
      },
      builder: (context, state) {
        if (state is! AuthAuthenticated) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final user = state.user;

        return Scaffold(
          backgroundColor: AppColors.bg,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.ink, size: 20),
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/akun');
                }
              },
            ),
            title: const Text(
              'Data Pribadi',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: AppColors.ink,
              ),
            ),
            centerTitle: true,
          ),
          body: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // Avatar Section
                  Container(
                    width: double.infinity,
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Column(
                      children: [
                        Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            AppAvatar(
                              name: user.name,
                              size: 100,
                              imageUrl: FirebaseAuth.instance.currentUser?.photoURL,
                            ),
                            if (_isGoogleUser)
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black12,
                                      blurRadius: 4,
                                      offset: Offset(0, 2),
                                    )
                                  ],
                                ),
                                child: Image.network(
                                  'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/1024px-Google_%22G%22_logo.svg.png',
                                  width: 20,
                                  height: 20,
                                  errorBuilder: (context, error, stackTrace) => const Text(
                                    'G',
                                    style: TextStyle(
                                      fontFamily: 'PlusJakartaSans',
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.primary,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          user.name,
                          style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _isGoogleUser
                                ? AppColors.primarySurface
                                : AppColors.greenSurface,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _isGoogleUser ? 'Masuk dengan Google' : 'Masuk dengan Email',
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _isGoogleUser ? AppColors.primary : AppColors.green,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Fields Section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        // Name Input Card
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: AppColors.shadowSoft,
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Nama Lengkap',
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.slate500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _nameController,
                                style: const TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.ink,
                                  fontSize: 15,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Masukkan nama lengkap',
                                  prefixIcon: const Icon(Icons.person_outline_rounded, color: AppColors.slate400),
                                  filled: true,
                                  fillColor: AppColors.bg,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Nama tidak boleh kosong';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Email Card
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: AppColors.shadowSoft,
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Alamat Email',
                                    style: TextStyle(
                                      fontFamily: 'PlusJakartaSans',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.slate500,
                                    ),
                                  ),
                                  TextButton(
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: const Size(0, 0),
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    onPressed: () => _showChangeEmailDialog(context, user.email),
                                    child: const Text(
                                      'Ubah',
                                      style: TextStyle(
                                        fontFamily: 'PlusJakartaSans',
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                initialValue: user.email,
                                enabled: false,
                                style: const TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.slate600,
                                  fontSize: 15,
                                ),
                                decoration: InputDecoration(
                                  prefixIcon: const Icon(Icons.mail_outline_rounded, color: AppColors.slate400),
                                  filled: true,
                                  fillColor: AppColors.bg.withValues(alpha: 0.8),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Explanation Box
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.primarySurface.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppColors.primaryBorder.withValues(alpha: 0.5),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.info_outline_rounded,
                                      size: 18,
                                      color: AppColors.primary,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _isGoogleUser
                                            ? 'Mengganti email akan memperbarui email utama Anda. Anda tetap dapat masuk menggunakan Google, dan email baru yang digunakan untuk login.'
                                            : 'Perubahan alamat email memerlukan verifikasi OTP yang akan dikirimkan langsung ke alamat email baru Anda.',
                                        style: const TextStyle(
                                          fontFamily: 'PlusJakartaSans',
                                          fontSize: 11,
                                          height: 1.4,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.primaryDark,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Joined Date Card
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: AppColors.shadowSoft,
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Bergabung Sejak',
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.slate500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                initialValue: _formatJoinedDate(user.createdAt),
                                enabled: false,
                                style: const TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.slate600,
                                  fontSize: 15,
                                ),
                                decoration: InputDecoration(
                                  prefixIcon: const Icon(Icons.calendar_today_outlined, color: AppColors.slate400),
                                  filled: true,
                                  fillColor: AppColors.bg.withValues(alpha: 0.8),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Save Button
                        GestureDetector(
                          onTap: _isLoading ? null : _saveProfile,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              gradient: _isLoading ? null : AppColors.primaryGradient,
                              color: _isLoading ? AppColors.slate300 : null,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: _isLoading ? null : AppColors.shadowPrimary,
                            ),
                            child: Center(
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(
                                      'Simpan Perubahan',
                                      style: TextStyle(
                                        fontFamily: 'PlusJakartaSans',
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
