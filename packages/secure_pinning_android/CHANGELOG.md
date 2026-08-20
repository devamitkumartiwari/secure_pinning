## 0.0.2

- `SecurePinningPlugin.kt` and `android/build.gradle.kts` (`minSdk` 24,
  `compileSdk`/`targetSdk` 37): a real, working Android implementation of
  the native `SecurePinning.check()` probe API — the previous release had
  only the Pigeon-generated message codec and no buildable Android
  project. Built on `javax.net.ssl`/`java.security` only, no third-party
  HTTP client; verified end-to-end on a physical device against a live
  TLS connection.

## 0.0.1

- Initial release.
- Pigeon-generated platform channel schema for `secure_pinning`'s native
  `SecurePinning.check()` probe API.
