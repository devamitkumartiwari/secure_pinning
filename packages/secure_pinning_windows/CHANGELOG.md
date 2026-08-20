## 1.0.0

- Initial release.
- `SecurePinning.createHttpClient()`, `secure_pinning_http`, and
  `secure_pinning_dio` already work on Windows today, since they run on
  the pure-Dart engine, not this package.
- The native `SecurePinning.check()` probe is stubbed on this platform for
  now — a real implementation via Schannel/CNG is planned.
