// Pigeon schema — the single source of truth for the secure_pinning platform
// channel. Run `dart run pigeon --input pigeons/messages.dart` (from this
// package's directory) after editing this file; never hand-edit the
// generated `.g.dart`/`.g.kt`/`.g.swift` outputs.
//
// See docs/SECURITY_MODEL.md for what each PinningMode/ChainPosition means
// and when to use it.

import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/messages.g.dart',
    kotlinOut: '../secure_pinning_android/android/src/main/kotlin/com/therivanta/securepinning/android/Messages.g.kt',
    kotlinOptions: KotlinOptions(
      package: 'com.therivanta.securepinning.android',
    ),
    swiftOut: '../secure_pinning_apple/ios/secure_pinning_apple/Sources/SecurePinningApple/Messages.g.swift',
    dartPackageName: 'secure_pinning_platform_interface',
  ),
)
/// How pinned values in a [PinSet] should be interpreted and compared.
///
/// This is the wire-format counterpart of the `secure_pinning` package's
/// user-facing `PinningMode` sealed class (deliberately named differently
/// to avoid a same-name collision between the two — this enum is an
/// internal platform-channel detail, not part of the public API most
/// users see).
///
/// [spki] (Subject Public Key Info hash) is the safe, OWASP-recommended
/// default — it survives certificate renewal as long as the key pair is
/// unchanged. [legacyLeafHash] hashes the whole leaf certificate; it
/// breaks on any renewal, even a same-key one, and exists only for
/// migration compatibility with plugins that pin the full leaf
/// certificate instead of just its public key. [legacyCaHash] pins a
/// CA/root certificate, which effectively trusts *any* certificate that
/// CA issues — a real security footgun. Dart-facing code requires an
/// explicit `acknowledgedRisk` string to select this mode.
enum WirePinningMode { spki, legacyLeafHash, legacyCaHash }

/// The hash algorithm a pin was computed with.
enum HashAlgorithm {
  /// SHA-256 — the recommended default.
  sha256,

  /// SHA-1 — supported for compatibility with pins computed by older
  /// tooling; prefer [sha256] for new pin sets.
  sha1,
}

/// Which certificate(s) in the chain a pin is checked against.
///
/// [leafOnly] is the default and the only option supported by
/// secure_pinning's pure-Dart engine (`dart:io` does not expose the full
/// chain). [anyInChain] and [specificIndex] are native-probe-only.
enum ChainPosition { leafOnly, anyInChain, specificIndex }

/// Machine-readable reason a [PinningCheckResult] was not trusted.
enum PinningErrorCode {
  /// The presented certificate's SPKI hash matched none of the
  /// configured pins.
  spkiMismatch,

  /// The presented certificate's whole-certificate hash matched none of
  /// the configured pins (legacy leaf-hash mode).
  leafHashMismatch,

  /// No certificate in the chain satisfied the configured pin set
  /// (native-probe-only chain positions).
  chainValidationFailed,

  /// The certificate's subject does not match the requested hostname.
  hostnameMismatch,

  /// The presented certificate has expired.
  certificateExpired,

  /// The presented certificate is self-signed and not otherwise pinned.
  selfSignedCertificate,

  /// The TLS connection did not establish within the configured connect
  /// timeout.
  connectTimeout,

  /// No response arrived within the configured read timeout.
  readTimeout,

  /// The device has no network connectivity.
  noInternet,

  /// The TLS handshake failed for a reason other than a pin mismatch.
  tlsHandshakeFailure,

  /// The current platform does not support the native probe API.
  unsupportedPlatform,

  /// The supplied [PinSet] or [PinningCheckRequest] was invalid.
  invalidConfiguration,

  /// An error occurred that doesn't map to any other [PinningErrorCode].
  unknown,
}

/// Wire-format bundle of the pin values a [PinningCheckRequest] should be
/// validated against, plus how to interpret and compare them.
class PinSet {
  /// All fields are required except [specificChainIndex], which only
  /// applies when [chainPosition] is [ChainPosition.specificIndex].
  PinSet({
    required this.pins,
    required this.mode,
    required this.algorithm,
    required this.chainPosition,
    this.specificChainIndex,
  });

  /// Pin values as base64 (SPKI) or hex (legacy hash) strings. At least one
  /// is required by Dart-side validation; two or more are recommended so a
  /// backup pin survives a key/cert rotation.
  List<String> pins;

  /// How [pins] should be interpreted and compared.
  WirePinningMode mode;

  /// The hash algorithm [pins] were computed with.
  HashAlgorithm algorithm;

  /// Which certificate(s) in the chain [pins] are checked against.
  ChainPosition chainPosition;

  /// Used only when [chainPosition] is [ChainPosition.specificIndex].
  int? specificChainIndex;
}

/// A single native probe request — see [SecurePinningHostApi.check].
class PinningCheckRequest {
  /// [url], [pinSet], [connectTimeoutMs], and [readTimeoutMs] are
  /// required; the rest are optional.
  PinningCheckRequest({
    required this.url,
    required this.pinSet,
    required this.connectTimeoutMs,
    required this.readTimeoutMs,
    this.headers,
    this.httpMethod,
    this.clientCertificate,
  });

  /// The URL to probe.
  String url;

  /// The pins to validate the connection against.
  PinSet pinSet;

  /// Extra headers to send with the probe request, if any.
  Map<String, String>? headers;

  /// Defaults to GET/HEAD on the native side if omitted.
  String? httpMethod;

  /// Maximum time to wait for the TLS connection to establish, in
  /// milliseconds.
  int connectTimeoutMs;

  /// Maximum time to wait for a response after the connection is
  /// established, in milliseconds.
  int readTimeoutMs;

  /// Reserved for mTLS/client-certificate authentication (planned v1.x).
  /// Unused in v0.9 — present now so adding mTLS later is not a schema
  /// break.
  Uint8List? clientCertificate;
}

/// The outcome of a [SecurePinningHostApi.check] call. A pin mismatch is
/// returned as data via [isTrusted]/[errorCode] — it is not thrown as an
/// exception, since it's an expected, frequently-occurring result.
class PinningCheckResult {
  /// [isTrusted] is required; the rest are populated depending on the
  /// outcome — see each field's doc comment.
  PinningCheckResult({
    required this.isTrusted,
    this.errorCode,
    this.errorDetail,
    this.matchedPinFingerprint,
  });

  /// Whether the connection satisfied the configured pin set.
  bool isTrusted;

  /// Non-null when [isTrusted] is false. A pin mismatch is an expected,
  /// frequently-occurring *result*, not a thrown exception — see
  /// CONTRIBUTING.md.
  PinningErrorCode? errorCode;

  /// Human-readable, non-sensitive diagnostic detail.
  String? errorDetail;

  /// Set on success, for diagnostics/logging.
  String? matchedPinFingerprint;
}

@HostApi()
abstract class SecurePinningHostApi {
  /// Validates [request] independently of any specific HTTP request — a
  /// standalone probe connection, not a hook into the app's real Dio/http
  /// traffic; see the "Core Architectural Insight" section of the project
  /// plan for why.
  @async
  PinningCheckResult check(PinningCheckRequest request);

  /// Cheap capability probe — true on Android/iOS/macOS; false on
  /// Windows/Linux (stubbed) and Web (permanently unsupported). Never
  /// throws.
  @async
  bool isPlatformSupported();
}
