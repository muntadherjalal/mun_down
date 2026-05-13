import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Handles biometric (FaceID / Fingerprint) authentication
/// for the Private Vault feature.
class BiometricHelper {
  BiometricHelper._();

  static final _auth = LocalAuthentication();

  /// Returns `true` if the device supports biometric authentication.
  static Future<bool> get isAvailable async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isDeviceSupported = await _auth.isDeviceSupported();
      return canCheck || isDeviceSupported;
    } on PlatformException {
      return false;
    }
  }

  /// Returns the list of enrolled biometric types.
  static Future<List<BiometricType>> get enrolledBiometrics async {
    try {
      return await _auth.getAvailableBiometrics();
    } on PlatformException {
      return [];
    }
  }

  /// Prompts biometric authentication.
  ///
  /// Returns `true` if authentication succeeds, `false` otherwise.
  /// [reason] is the message shown to the user in the system prompt.
  static Future<bool> authenticate({
    String reason = 'Authenticate to access this file',
  }) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false, // Allow PIN/pattern fallback
          useErrorDialogs: true,
          stickyAuth: true,
        ),
      );
    } on PlatformException {
      return false;
    }
  }
}
