## 0.0.2

- Drop the `secure_pinning_windows`, `secure_pinning_linux`, and
  `secure_pinning_web` dependencies. `package:http`/Dio/raw-`HttpClient`
  pinning is unaffected on Windows and Linux (it's pure-Dart, never gated
  by a platform package) — only the native `SecurePinning.check()` probe,
  which was stubbed on those two anyway, no longer has even a stub
  registered there. Web was already permanently unsupported for
  everything and remains so.

## 0.0.1

- Initial release.
- Three pinning modes: `PinningMode.spki` (public-key hash, the default),
  `PinningMode.legacyLeafHash` (whole-certificate hash, for compatibility
  with plugins that pin the full leaf certificate instead of just its
  public key), and `PinningMode.legacyCaHash` (CA/root pinning, gated
  behind a required `acknowledgedRisk` justification).
- A pure-Dart validation engine that hooks `dart:io`'s
  `HttpClient.badCertificateCallback` directly — validates the real
  connection your request uses, with no separate preflight round trip.
- SHA-256 and SHA-1 hash algorithm support.
- Backup-pin support and configurable connect/read timeouts.
- A typed exception hierarchy (`SecurePinningValidationException`,
  `SecurePinningTimeoutException`, `SecurePinningConfigurationException`,
  `SecurePinningUnsupportedPlatformException`,
  `SecurePinningNetworkException`) consistent across every platform and
  integration surface.
- A native probe API (`SecurePinning.check()` and
  `SecurePinning.isPlatformSupported()`) for one-off checks and for
  validating `PinningMode.legacyCaHash`, which requires walking the full
  certificate chain.
- Zero third-party dependencies beyond `crypto`.
