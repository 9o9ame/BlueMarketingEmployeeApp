import 'package:local_auth/local_auth.dart';

/// Biometrics are a local app-unlock step, not a replacement for Laravel Sanctum.
class BiometricUnlock {
  BiometricUnlock({LocalAuthentication? authentication})
      : _auth = authentication ?? LocalAuthentication();

  final LocalAuthentication _auth;

  Future<bool> available() async {
    try {
      if (!await _auth.canCheckBiometrics) return false;
      return (await _auth.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> verify() async {
    try {
      if (!await available()) return false;
      return await _auth.authenticate(
        localizedReason: 'Unlock your BlueMarketing employee session',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }
}
