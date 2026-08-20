import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'messages.g.dart';
import 'method_channel_secure_pinning.dart';

/// The interface platform packages (secure_pinning_android,
/// secure_pinning_apple, etc.) must implement.
///
/// This powers only [SecurePinning.check]/[SecurePinning.isPlatformSupported]
/// — the native probe API. It does not guard `package:http`/Dio traffic;
/// that's the pure-Dart engine in the `secure_pinning` package. See
/// CONTRIBUTING.md.
abstract class SecurePinningPlatform extends PlatformInterface {
  SecurePinningPlatform() : super(token: _token);

  static final Object _token = Object();

  static SecurePinningPlatform _instance = MethodChannelSecurePinning();

  static SecurePinningPlatform get instance => _instance;

  static set instance(SecurePinningPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<PinningCheckResult> check(PinningCheckRequest request) {
    throw UnimplementedError('check() has not been implemented.');
  }

  Future<bool> isPlatformSupported() {
    throw UnimplementedError('isPlatformSupported() has not been implemented.');
  }
}
