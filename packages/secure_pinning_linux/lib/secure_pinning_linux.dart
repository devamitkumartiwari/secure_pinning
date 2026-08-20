/// Linux platform implementation of `secure_pinning`'s native probe API
/// (currently stubbed). See [SecurePinningLinux].
library;

import 'package:secure_pinning_platform_interface/secure_pinning_platform_interface.dart';

/// Linux implementation of [SecurePinningPlatform]. The native probe API
/// (`SecurePinning.check()`) is stubbed here for v0.9 — a real
/// implementation via OpenSSL is planned for v1.x (see the project plan's
/// "Phased Roadmap"). This does not affect
/// `SecurePinning.createHttpClient()`, `secure_pinning_http`, or
/// `secure_pinning_dio`, which already work on Linux today via the
/// pure-Dart engine.
class SecurePinningLinux extends SecurePinningPlatform {
  /// Use [registerWith] to install this implementation rather than
  /// constructing it directly.
  SecurePinningLinux();

  /// Registers this as the active [SecurePinningPlatform] implementation.
  /// Called automatically by Flutter's plugin registrar — not meant to
  /// be called directly by app code.
  static void registerWith() {
    SecurePinningPlatform.instance = SecurePinningLinux();
  }

  @override
  Future<PinningCheckResult> check(PinningCheckRequest request) async {
    return PinningCheckResult(
      isTrusted: false,
      errorCode: PinningErrorCode.unsupportedPlatform,
      errorDetail:
          'The native SecurePinning.check() probe API is not yet '
          'implemented on Linux (planned for a future release). Use '
          'SecurePinning.createHttpClient(), secure_pinning_http, or '
          'secure_pinning_dio instead — those already work on Linux.',
    );
  }

  @override
  Future<bool> isPlatformSupported() async => false;
}
