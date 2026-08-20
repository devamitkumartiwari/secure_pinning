import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'messages.g.dart';
import 'method_channel_secure_pinning.dart';

/// The interface platform packages (secure_pinning_android,
/// secure_pinning_apple, etc.) must implement.
///
/// This powers only `SecurePinning.check()`/`SecurePinning.isPlatformSupported()`
/// — the native probe API. It does not guard `package:http`/Dio traffic;
/// that's the pure-Dart engine in the `secure_pinning` package. See
/// CONTRIBUTING.md.
abstract class SecurePinningPlatform extends PlatformInterface {
  /// Platform packages call this via `super()` when constructing their
  /// own implementation, so [PlatformInterface] can verify [instance] was
  /// set to a genuine platform implementation rather than an arbitrary
  /// object.
  SecurePinningPlatform() : super(token: _token);

  static final Object _token = Object();

  static SecurePinningPlatform _instance = MethodChannelSecurePinning();

  /// The active platform implementation. Defaults to the method-channel
  /// implementation; platform packages override this at startup.
  static SecurePinningPlatform get instance => _instance;

  /// Sets the active platform implementation. Only platform packages
  /// should call this — [PlatformInterface.verifyToken] rejects anything
  /// that isn't a genuine [SecurePinningPlatform] subclass.
  static set instance(SecurePinningPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Runs the native probe check described by [request]. Platform
  /// packages must override this; the default throws
  /// [UnimplementedError].
  Future<PinningCheckResult> check(PinningCheckRequest request) {
    throw UnimplementedError('check() has not been implemented.');
  }

  /// Reports whether this platform's native probe engine is available.
  /// Platform packages must override this; the default throws
  /// [UnimplementedError].
  Future<bool> isPlatformSupported() {
    throw UnimplementedError('isPlatformSupported() has not been implemented.');
  }
}
