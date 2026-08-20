import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart' as http_io;
import 'package:secure_pinning/secure_pinning.dart';

/// A pinned `http.BaseClient` — full verb + streaming support (`get`,
/// `post`, `put`, `patch`, `delete`, `head`, `read`, `readBytes`, `send`,
/// all inherited for free from [http.BaseClient]) built on
/// [SecurePinning.createHttpClient].
class SecurePinningHttpClient extends http.BaseClient {
  /// Full configuration. Pass [customClient] to wrap an existing
  /// `http.BaseClient` instead of constructing one internally — useful
  /// for testing/mocking or chaining with other client-level middleware.
  /// When [customClient] is supplied, [config]'s pinning is not applied by
  /// this constructor (the custom client is responsible for its own TLS
  /// configuration); use this only when you already have a client with
  /// pinning wired in some other way and want [config]'s timeouts/typed
  /// exceptions applied around it.
  SecurePinningHttpClient(this.config, {http.BaseClient? customClient})
    : _inner =
          customClient ??
          http_io.IOClient(SecurePinning.createHttpClient(config));

  /// One-line convenience: pins a single host with SPKI + SHA-256 +
  /// default timeouts. Use the primary constructor with a full
  /// [SecurePinningConfig] for multi-host apps, backup-pin rotation
  /// beyond the defaults, or legacy-mode migration.
  factory SecurePinningHttpClient.forHost(
    String host, {
    required List<String> pins,
  }) {
    return SecurePinningHttpClient(SecurePinningConfig(host: host, pins: pins));
  }

  /// The configuration this client validates connections against.
  final SecurePinningConfig config;
  final http.BaseClient _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    try {
      return await SecurePinning.enforceReadTimeout(
        _inner.send(request),
        config.readTimeout,
      );
    } on SecurePinningException {
      rethrow;
    } on HandshakeException catch (error) {
      // dart:io's HttpClient.badCertificateCallback only returns a bool —
      // it cannot report *why* a certificate was rejected, so a pinning
      // mismatch and any other handshake failure both surface here as a
      // generic HandshakeException. This is a known limitation of the
      // pure-Dart engine path (see SecurePinningEngine's doc comment).
      throw SecurePinningValidationException(
        code: PinningErrorCode.tlsHandshakeFailure,
        host: request.url.host,
        message:
            'TLS handshake failed for ${request.url.host} — the '
            'presented certificate likely did not match the configured '
            'pin set. ${error.message}',
      );
    } on SocketException catch (error) {
      throw SecurePinningNetworkException(
        'Network error contacting ${request.url.host}: ${error.message}',
        cause: error,
      );
    }
  }

  @override
  void close() => _inner.close();
}
