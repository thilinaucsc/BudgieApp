import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

/// Face ID, Touch ID and fingerprint unlock. Every call fails safely to false,
/// so the PIN always remains a way in.
class BiometricService {
  BiometricService._();
  static final BiometricService instance = BiometricService._();

  static const settingKey = 'biometric_unlock';

  final _auth = LocalAuthentication();

  Future<bool> isAvailable() async {
    try {
      return await _auth.isDeviceSupported() && await _auth.canCheckBiometrics;
    } catch (e) {
      debugPrint('BiometricService.isAvailable: $e');
      return false;
    }
  }

  Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } catch (e) {
      debugPrint('BiometricService.authenticate: $e');
      return false;
    }
  }
}
