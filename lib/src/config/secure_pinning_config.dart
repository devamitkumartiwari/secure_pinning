import 'package:secure_pinning_platform_interface/secure_pinning_platform_interface.dart'
    show ChainPosition, HashAlgorithm;

import '../exceptions/secure_pinning_exception.dart';
import 'pinning_mode.dart';

/// Configuration shared by every integration surface (raw client,
/// `secure_pinning_http`, `secure_pinning_dio`, and the native probe API).
///
/// Safe-by-default: an app that supplies only [host] and [pins] gets SPKI
/// pinning, SHA-256, and reasonable timeouts automatically.
class SecurePinningConfig {
  /// Validates [host]/[pins]/[mode] immediately — throws
  /// [SecurePinningConfigurationException] rather than deferring the
  /// failure to the first request.
  SecurePinningConfig({
    required this.host,
    required this.pins,
    this.mode = const PinningMode.spki(),
    this.algorithm = HashAlgorithm.sha256,
    this.chainPosition = ChainPosition.leafOnly,
    this.connectTimeout = const Duration(seconds: 10),
    this.readTimeout = const Duration(seconds: 15),
  }) {
    _validate();
  }

  /// The hostname requests are pinned to, e.g. `'api.example.com'`.
  final String host;

  /// Pin values as hex strings (colon-tolerant: `"AA:BB:CC"` and
  /// `"AABBCC"` are equivalent, case-insensitive). At least one is
  /// required; two or more are recommended so a backup pin survives a
  /// key/certificate rotation without an app update.
  final List<String> pins;

  /// How [pins] should be interpreted and compared. Defaults to
  /// [PinningMode.spki].
  final PinningMode mode;

  /// The hash algorithm [pins] were computed with. Defaults to
  /// [HashAlgorithm.sha256].
  final HashAlgorithm algorithm;

  /// Which certificate(s) in the chain [pins] are checked against.
  /// Defaults to [ChainPosition.leafOnly] — the only value the pure-Dart
  /// engine supports.
  final ChainPosition chainPosition;

  /// Maximum time to wait for the TLS connection to establish.
  final Duration connectTimeout;

  /// Maximum time to wait for a response after the connection is
  /// established. See [SecurePinning.enforceReadTimeout] for how this is
  /// applied.
  final Duration readTimeout;

  /// [pins], normalized to uppercase hex with any `:` separators removed.
  late final List<String> normalizedPins = pins
      .map(_normalizeFingerprint)
      .toList(growable: false);

  void _validate() {
    if (host.isEmpty) {
      throw const SecurePinningConfigurationException(
        'host must not be empty.',
      );
    }
    if (pins.isEmpty) {
      throw const SecurePinningConfigurationException(
        'pins must contain at least one entry. Provide at least two — a '
        'current pin and a backup — so a future rotation does not require '
        'an app update.',
      );
    }
    final mode = this.mode;
    if (mode is LegacyCaHashPinningMode &&
        mode.acknowledgedRisk.trim().isEmpty) {
      throw const SecurePinningConfigurationException(
        'PinningMode.legacyCaHash requires a non-empty acknowledgedRisk '
        'explaining why CA-level pinning was chosen. Pinning a CA/root '
        'certificate trusts *any* certificate that CA issues — see '
        'docs/SECURITY_MODEL.md before using this mode.',
      );
    }
  }

  static String _normalizeFingerprint(String raw) =>
      raw.replaceAll(':', '').toUpperCase();
}
