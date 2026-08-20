import 'package:secure_pinning_platform_interface/secure_pinning_platform_interface.dart'
    show PinningErrorCode;

/// Base type for every exception this package throws. One consistent
/// hierarchy across every platform and integration surface (raw client,
/// `secure_pinning_http`, `secure_pinning_dio`) — never a raw
/// `PlatformException`/`HandshakeException`/`TlsException` leaks to caller
/// code.
sealed class SecurePinningException implements Exception {
  const SecurePinningException(this.message);

  /// Human-readable, non-sensitive description of what went wrong.
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// The certificate presented by the server did not satisfy the configured
/// pin set. This is the expected, common failure mode of certificate
/// pinning — a real MITM, a rotated-but-unlisted cert, or a misconfigured
/// pin will all surface here.
final class SecurePinningValidationException extends SecurePinningException {
  /// [code] and [host] identify why and where validation failed;
  /// [message] is the human-readable description.
  const SecurePinningValidationException({
    required this.code,
    required this.host,
    required String message,
  }) : super(message);

  /// Machine-readable reason the certificate was rejected.
  final PinningErrorCode code;

  /// The host the failed connection was to.
  final String host;
}

/// Which phase of a request timed out.
enum TimeoutPhase {
  /// The TLS connection itself did not establish in time.
  connect,

  /// The connection established, but no response arrived in time.
  read,
}

/// A `SecurePinningConfig.connectTimeout` or `SecurePinningConfig.readTimeout`
/// was exceeded.
final class SecurePinningTimeoutException extends SecurePinningException {
  /// [phase] identifies which timeout fired; [message] is the
  /// human-readable description.
  const SecurePinningTimeoutException({
    required this.phase,
    required String message,
  }) : super(message);

  /// Which phase of the request timed out.
  final TimeoutPhase phase;
}

/// The [SecurePinningConfig] itself is invalid — e.g. an empty pin list, or
/// a chain position the calling engine can't honor. Thrown at configuration
/// time or at the start of a call, never mid-request.
final class SecurePinningConfigurationException extends SecurePinningException {
  /// [message] explains what's wrong with the configuration.
  const SecurePinningConfigurationException(super.message);
}

/// Raised on a platform where certificate pinning is not available —
/// permanently on Web, or on a platform whose native probe engine is
/// currently a stub. Check [SecurePinning.isPlatformSupported] to avoid
/// this in production rather than catching it reactively.
final class SecurePinningUnsupportedPlatformException
    extends SecurePinningException {
  /// [platform] names the unsupported platform, e.g. `'web'`.
  const SecurePinningUnsupportedPlatformException(this.platform)
    : super('secure_pinning is not supported on $platform.');

  /// The unsupported platform's name, as used in the exception message.
  final String platform;
}

/// A connectivity failure unrelated to certificate validation (DNS
/// failure, connection refused, etc.).
final class SecurePinningNetworkException extends SecurePinningException {
  /// [message] describes the failure; [cause] is the underlying error
  /// that triggered it, if any.
  const SecurePinningNetworkException(super.message, {this.cause});

  /// The underlying error (e.g. a `SocketException`) that caused this
  /// failure, if known.
  final Object? cause;
}
