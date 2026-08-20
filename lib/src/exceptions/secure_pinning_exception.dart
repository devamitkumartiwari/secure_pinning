import 'package:secure_pinning_platform_interface/secure_pinning_platform_interface.dart'
    show PinningErrorCode;

/// Base type for every exception this package throws. One consistent
/// hierarchy across every platform and integration surface (raw client,
/// `secure_pinning_http`, `secure_pinning_dio`) — never a raw
/// `PlatformException`/`HandshakeException`/`TlsException` leaks to caller
/// code.
sealed class SecurePinningException implements Exception {
  const SecurePinningException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// The certificate presented by the server did not satisfy the configured
/// pin set. This is the expected, common failure mode of certificate
/// pinning — a real MITM, a rotated-but-unlisted cert, or a misconfigured
/// pin will all surface here.
final class SecurePinningValidationException extends SecurePinningException {
  const SecurePinningValidationException({
    required this.code,
    required this.host,
    required String message,
  }) : super(message);

  final PinningErrorCode code;
  final String host;
}

enum TimeoutPhase { connect, read }

final class SecurePinningTimeoutException extends SecurePinningException {
  const SecurePinningTimeoutException({
    required this.phase,
    required String message,
  }) : super(message);

  final TimeoutPhase phase;
}

/// The [SecurePinningConfig] itself is invalid — e.g. an empty pin list, or
/// a chain position the calling engine can't honor. Thrown at configuration
/// time or at the start of a call, never mid-request.
final class SecurePinningConfigurationException extends SecurePinningException {
  const SecurePinningConfigurationException(super.message);
}

/// Raised on a platform where certificate pinning is not available —
/// permanently on Web, or on a platform whose native probe engine is
/// currently a stub. Check [SecurePinning.isPlatformSupported] to avoid
/// this in production rather than catching it reactively.
final class SecurePinningUnsupportedPlatformException
    extends SecurePinningException {
  const SecurePinningUnsupportedPlatformException(this.platform)
      : super('secure_pinning is not supported on $platform.');

  final String platform;
}

/// A connectivity failure unrelated to certificate validation (DNS
/// failure, connection refused, etc.).
final class SecurePinningNetworkException extends SecurePinningException {
  const SecurePinningNetworkException(super.message, {this.cause});

  final Object? cause;
}
