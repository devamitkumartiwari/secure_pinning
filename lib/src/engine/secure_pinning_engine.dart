import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:secure_pinning_platform_interface/secure_pinning_platform_interface.dart'
    show ChainPosition, HashAlgorithm;

import '../config/pinning_mode.dart';
import '../config/secure_pinning_config.dart';
import '../exceptions/secure_pinning_exception.dart';
import 'der.dart';

/// The pure-Dart validation engine behind [SecurePinning.createHttpClient]'s
/// `HttpClient.badCertificateCallback`.
///
/// `dart:io`'s TLS stack (BoringSSL) is what actually carries most Flutter
/// HTTP traffic — `package:http`'s default client and Dio's default
/// `IOHttpClientAdapter` both use it — not OkHttp/NSURLSession. Wiring
/// validation into `badCertificateCallback` runs it on the real connection
/// for the real request, with no separate preflight round-trip and no
/// shared mutable state between concurrent calls (each `HttpClient`
/// captures one immutable [SecurePinningConfig]). See CONTRIBUTING.md.
///
/// Limitation: `dart:io` exposes only the leaf certificate to
/// `badCertificateCallback`, not the full chain, so this engine only
/// supports [ChainPosition.leafOnly] and [PinningMode.spki] /
/// [PinningMode.legacyLeafHash]. [PinningMode.legacyCaHash] and non-leaf
/// [ChainPosition]s require the native `SecurePinning.check()` probe API.
abstract final class SecurePinningEngine {
  /// Validates [cert] for [host]/[port] against [config]. Suitable for
  /// direct use as an `HttpClient.badCertificateCallback`.
  static bool validateCertificate(
    X509Certificate cert,
    String host,
    int port,
    SecurePinningConfig config,
  ) {
    return validateDer(certificateDer: cert.der, config: config);
  }

  /// The underlying logic, taking raw DER bytes directly rather than a
  /// live [X509Certificate] — this seam lets tests exercise every match/
  /// mismatch/algorithm/mode combination against fixture certificates
  /// without needing a live TLS handshake.
  static bool validateDer({
    required Uint8List certificateDer,
    required SecurePinningConfig config,
  }) {
    if (config.chainPosition != ChainPosition.leafOnly) {
      throw const SecurePinningConfigurationException(
        'The pure-Dart engine only supports ChainPosition.leafOnly (dart:io '
        'does not expose the full certificate chain to '
        'badCertificateCallback). Use the native SecurePinning.check() '
        'probe API for ChainPosition.anyInChain/specificIndex.',
      );
    }

    final mode = config.mode;
    final String candidateHash = switch (mode) {
      SpkiPinningMode() => _hashHex(
          extractSubjectPublicKeyInfoDer(certificateDer),
          config.algorithm,
        ),
      LegacyLeafHashPinningMode() => _hashHex(certificateDer, config.algorithm),
      LegacyCaHashPinningMode() =>
        throw const SecurePinningConfigurationException(
          'PinningMode.legacyCaHash targets a CA/root certificate, which '
          'requires walking the full certificate chain and is not '
          'supported by the pure-Dart engine. Use the native '
          'SecurePinning.check() probe API instead.',
        ),
    };

    return config.normalizedPins.contains(candidateHash);
  }

  static String _hashHex(Uint8List bytes, HashAlgorithm algorithm) {
    final digest = switch (algorithm) {
      HashAlgorithm.sha256 => crypto.sha256.convert(bytes),
      HashAlgorithm.sha1 => crypto.sha1.convert(bytes),
    };
    return digest.toString().toUpperCase();
  }
}
