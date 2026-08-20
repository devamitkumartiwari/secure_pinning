import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:secure_pinning_platform_interface/secure_pinning_platform_interface.dart';

import '../config/pinning_mode.dart';
import '../config/secure_pinning_config.dart';
import '../engine/secure_pinning_engine.dart';
import '../exceptions/secure_pinning_exception.dart';

/// Entry points that don't require `secure_pinning_http` or
/// `secure_pinning_dio` — usable on their own for anyone building on raw
/// sockets or a custom HTTP stack.
abstract final class SecurePinning {
  /// Returns a `dart:io` [HttpClient] whose TLS handshakes are validated
  /// against [config] via the pure-Dart engine (see
  /// [SecurePinningEngine]) — this is the lowest-level, most robust
  /// integration point, and what [SecurePinningHttpClient] and the Dio
  /// integration are built on.
  ///
  /// [SecurePinningConfig.connectTimeout] is applied as
  /// [HttpClient.connectionTimeout]. `dart:io` has no built-in
  /// "read timeout" concept the way OkHttp/URLSession do — enforcing
  /// [SecurePinningConfig.readTimeout] is the caller's responsibility;
  /// use [enforceReadTimeout] to wrap a response future/stream.
  static HttpClient createHttpClient(SecurePinningConfig config) {
    if (kIsWeb) {
      throw const SecurePinningUnsupportedPlatformException('web');
    }
    final context = SecurityContext(withTrustedRoots: false);
    final client = HttpClient(context: context)
      ..connectionTimeout = config.connectTimeout
      ..badCertificateCallback = (cert, host, port) {
        return SecurePinningEngine.validateCertificate(
            cert, host, port, config);
      };
    return client;
  }

  /// Races [future] against [readTimeout], throwing
  /// [SecurePinningTimeoutException] if it fires first. `dart:io`
  /// `HttpClient` does not enforce a read timeout natively (unlike
  /// `connectionTimeout`), so integration wrappers (`secure_pinning_http`,
  /// `secure_pinning_dio`) call this around the response
  /// future/stream rather than relying on the client to self-enforce it.
  static Future<T> enforceReadTimeout<T>(
      Future<T> future, Duration readTimeout) {
    return future.timeout(
      readTimeout,
      onTimeout: () => throw const SecurePinningTimeoutException(
        phase: TimeoutPhase.read,
        message: 'Timed out waiting for a response.',
      ),
    );
  }

  /// Validates [url] against [config] independently of any specific HTTP
  /// request — a standalone probe connection, not a hook into
  /// `package:http`/Dio traffic; see CONTRIBUTING.md's "Architecture, in
  /// one paragraph" section for why.
  ///
  /// A pin mismatch is returned as data
  /// (`PinningCheckResult.isTrusted == false`), not thrown — only genuine
  /// infrastructure failures (DNS failure, malformed config) throw a
  /// [SecurePinningException].
  static Future<PinningCheckResult> check({
    required String url,
    required SecurePinningConfig config,
    Map<String, String>? headers,
    String? httpMethod,
  }) async {
    if (kIsWeb) {
      throw const SecurePinningUnsupportedPlatformException('web');
    }
    final request = PinningCheckRequest(
      url: url,
      pinSet: PinSet(
        pins: config.normalizedPins,
        mode: switch (config.mode) {
          SpkiPinningMode() => WirePinningMode.spki,
          LegacyLeafHashPinningMode() => WirePinningMode.legacyLeafHash,
          LegacyCaHashPinningMode() => WirePinningMode.legacyCaHash,
        },
        algorithm: config.algorithm,
        chainPosition: config.chainPosition,
      ),
      connectTimeoutMs: config.connectTimeout.inMilliseconds,
      readTimeoutMs: config.readTimeout.inMilliseconds,
      headers: headers,
      httpMethod: httpMethod,
    );
    try {
      return await SecurePinningPlatform.instance.check(request);
    } on SecurePinningException {
      rethrow;
    } catch (error) {
      throw SecurePinningNetworkException(
        'The native certificate check failed: $error',
        cause: error,
      );
    }
  }

  /// Cheap capability probe — true on Android/iOS/macOS; false on
  /// Windows/Linux (native probe engine currently stubbed) and Web
  /// (permanently unsupported). Never throws.
  static Future<bool> isPlatformSupported() async {
    if (kIsWeb) {
      return false;
    }
    try {
      return await SecurePinningPlatform.instance.isPlatformSupported();
    } catch (_) {
      return false;
    }
  }
}
