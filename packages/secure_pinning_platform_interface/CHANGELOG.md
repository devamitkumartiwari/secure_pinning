## 0.0.1

- Initial release.
- Pigeon-generated platform channel schema (`PinningCheckRequest`,
  `PinSet`, `PinningCheckResult`, `WirePinningMode`, `HashAlgorithm`,
  `ChainPosition`, `PinningErrorCode`) shared by every native platform
  implementation.
- `SecurePinningPlatform`, the `PlatformInterface`-based contract each
  platform package implements for the native `SecurePinning.check()`
  probe API.
