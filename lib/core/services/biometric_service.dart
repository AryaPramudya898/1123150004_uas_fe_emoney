import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  
  static const String _biometricEnabledKey = 'biometric_enabled';
  static const String _savedEmailKey = 'biometric_email';
  static const String _savedPasswordKey = 'biometric_password';

  // Check if the device has biometric hardware and it is enabled
  Future<bool> isBiometricAvailable() async {
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await _auth.isDeviceSupported();
      return canAuthenticate;
    } catch (_) {
      return false;
    }
  }

  // Check if biometric login is enabled by the user in settings
  Future<bool> isBiometricEnabled() async {
    final value = await _secureStorage.read(key: _biometricEnabledKey);
    return value == 'true';
  }

  // Set biometric login enabled status
  Future<void> setBiometricEnabled(bool enabled) async {
    await _secureStorage.write(key: _biometricEnabledKey, value: enabled.toString());
  }

  // Save credentials for biometric login
  Future<void> saveCredentials(String email, String password) async {
    await _secureStorage.write(key: _savedEmailKey, value: email);
    await _secureStorage.write(key: _savedPasswordKey, value: password);
  }

  // Get saved credentials
  Future<Map<String, String>?> getSavedCredentials() async {
    final email = await _secureStorage.read(key: _savedEmailKey);
    final password = await _secureStorage.read(key: _savedPasswordKey);
    if (email != null && password != null) {
      return {'email': email, 'password': password};
    }
    return null;
  }

  // Clear credentials
  Future<void> clearCredentials() async {
    await _secureStorage.delete(key: _savedEmailKey);
    await _secureStorage.delete(key: _savedPasswordKey);
    await _secureStorage.delete(key: _biometricEnabledKey);
  }

  // Perform authentication
  Future<bool> authenticate() async {
    try {
      final bool didAuthenticate = await _auth.authenticate(
        localizedReason: 'Pindai sidik jari atau wajah Anda untuk masuk',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      return didAuthenticate;
    } on PlatformException catch (_) {
      return false;
    }
  }
}
