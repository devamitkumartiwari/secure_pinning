/// Certificate pinning for Flutter with zero third-party dependencies in
/// this package: SPKI (public key) pinning by default, a pure-Dart engine
/// that validates the real connection your app uses, and a typed
/// exception hierarchy consistent across every platform.
///
/// See `secure_pinning_http` and `secure_pinning_dio` for `package:http`
/// and Dio integrations built on top of this package.
library;

export 'package:secure_pinning_platform_interface/secure_pinning_platform_interface.dart'
    show ChainPosition, HashAlgorithm, PinningCheckResult, PinningErrorCode;

export 'src/config/pinning_mode.dart';
export 'src/config/secure_pinning_config.dart';
export 'src/engine/secure_pinning_engine.dart';
export 'src/exceptions/secure_pinning_exception.dart';
export 'src/raw/secure_pinning.dart';
