import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:secure_pinning/secure_pinning.dart';

/// An `Interceptor`-shaped facade for pinning a Dio instance's traffic.
///
/// A plain Dio `Interceptor`'s `onRequest`/`onResponse` hooks run *after*
/// the TLS handshake has already happened — they cannot influence trust
/// evaluation. The actually-correct integration point is
/// [IOHttpClientAdapter.createHttpClient], which this class configures on
/// [dio] at construction time; the `Interceptor`-shaped API is kept for
/// migration ergonomics (`dio.interceptors.add(...)`) and for mapping
/// pinning failures into secure_pinning's typed exception hierarchy via
/// [onError].
class SecurePinningInterceptor extends Interceptor {
  SecurePinningInterceptor(
    this.dio,
    this.config, {
    this.callFollowingErrorInterceptor = false,
  }) {
    _adapter = IOHttpClientAdapter(
      createHttpClient: () => SecurePinning.createHttpClient(config),
    );
    dio.httpClientAdapter = _adapter;
  }

  /// One-line convenience: pins a single host with SPKI + SHA-256 +
  /// default timeouts.
  factory SecurePinningInterceptor.forHost(
    Dio dio,
    String host, {
    required List<String> pins,
    bool callFollowingErrorInterceptor = false,
  }) {
    return SecurePinningInterceptor(
      dio,
      SecurePinningConfig(host: host, pins: pins),
      callFollowingErrorInterceptor: callFollowingErrorInterceptor,
    );
  }

  final Dio dio;
  final SecurePinningConfig config;

  /// Whether a pinning-related rejection still propagates to the next
  /// error interceptor in the chain (`true`), or terminates the chain
  /// here (`false`, the default).
  final bool callFollowingErrorInterceptor;

  late final IOHttpClientAdapter _adapter;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (!identical(dio.httpClientAdapter, _adapter)) {
      handler.reject(
        DioException(
          requestOptions: options,
          error: const SecurePinningConfigurationException(
            'dio.httpClientAdapter was replaced after SecurePinningInterceptor '
            'was installed (e.g. by swapping in a native-backed adapter like '
            'cronet_http/cupertino_http). Pinning is no longer active for '
            'this Dio instance — re-add SecurePinningInterceptor after any '
            'adapter change, or wait for native-adapter support (planned '
            'v1.x).',
          ),
        ),
        callFollowingErrorInterceptor,
      );
      return;
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final mapped = _mapPinningError(err.error);
    if (mapped == null) {
      handler.next(err);
      return;
    }
    handler.next(err.copyWith(error: mapped));
  }

  SecurePinningException? _mapPinningError(Object? error) {
    if (error is SecurePinningException) {
      return error;
    }
    if (error is HandshakeException) {
      // dart:io's HttpClient.badCertificateCallback only returns a bool —
      // it cannot report *why* a certificate was rejected, so a pinning
      // mismatch and any other handshake failure both surface here as a
      // generic HandshakeException.
      return SecurePinningValidationException(
        code: PinningErrorCode.tlsHandshakeFailure,
        host: dio.options.baseUrl.isNotEmpty
            ? Uri.parse(dio.options.baseUrl).host
            : '',
        message: 'TLS handshake failed — the presented certificate likely '
            'did not match the configured pin set. ${error.message}',
      );
    }
    if (error is SocketException) {
      return SecurePinningNetworkException(error.message, cause: error);
    }
    return null;
  }
}
