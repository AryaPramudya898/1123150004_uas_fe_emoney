import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../widgets/feature_icon.dart';

class ConnectedAppsPage extends StatefulWidget {
  const ConnectedAppsPage({super.key});

  @override
  State<ConnectedAppsPage> createState() => _ConnectedAppsPageState();
}

class _ConnectedAppsPageState extends State<ConnectedAppsPage> {
  bool _isLoading = true;
  List<Map<String, String>> _connectedApps = [];

  @override
  void initState() {
    super.initState();
    _loadConnectedApps();
  }

  Future<void> _loadConnectedApps() async {
    setState(() => _isLoading = true);
    try {
      const storage = FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true));
      final all = await storage.readAll();
      final list = <Map<String, String>>[];
      all.forEach((key, value) {
        if (key.startsWith('connected_app_')) {
          final id = key.substring('connected_app_'.length);
          list.add({'id': id, 'name': value});
        }
      });
      setState(() {
        _connectedApps = list;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _disconnect(String id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Putuskan Sambungan?',
          style: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
            fontSize: 17,
          ),
        ),
        content: Text(
          'Apakah Anda yakin ingin memutuskan sambungan Coach E-Money dengan aplikasi "$name"? Anda perlu menghubungkan kembali jika ingin bertransaksi dari aplikasi tersebut.',
          style: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            color: AppColors.slate500,
            fontSize: 13.5,
            height: 1.5,
          ),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Batal',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                color: AppColors.slate400,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              elevation: 0,
            ),
            child: const Text(
              'Putuskan',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        const storage = FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true));
        await storage.delete(key: 'connected_app_$id');
        await _loadConnectedApps();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Berhasil memutuskan sambungan dengan $name',
                      style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13),
                    ),
                  ),
                ],
              ),
              backgroundColor: AppColors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal memutuskan sambungan: $e'),
              backgroundColor: AppColors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
          'Aplikasi Terhubung',
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: AppColors.ink,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _connectedApps.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: const BoxDecoration(
                            color: AppColors.violetSurface,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.link_off_rounded,
                            color: AppColors.violet,
                            size: 40,
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Tidak Ada Aplikasi Terhubung',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Anda belum menghubungkan akun Coach E-Money Anda dengan aplikasi pihak ketiga mana pun.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 13.5,
                            color: AppColors.slate500,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _connectedApps.length,
                  itemBuilder: (context, index) {
                    final app = _connectedApps[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: AppColors.shadowSoft,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          const FeatureIcon(
                            icon: Icons.storefront_rounded,
                            tone: 'blue',
                            size: 44,
                            iconSize: 22,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  app['name'] ?? 'Aplikasi',
                                  style: const TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.ink,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Terhubung',
                                  style: TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    fontSize: 12,
                                    color: AppColors.green,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () => _disconnect(app['id']!, app['name']!),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.red,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Putuskan',
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
