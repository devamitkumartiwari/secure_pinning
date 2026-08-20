## 0.0.2

- `SecurePinningPlugin.swift`: a real, working iOS/macOS implementation of
  the native `SecurePinning.check()` probe API — the previous release had
  only the Pigeon-generated message codec and no buildable Xcode/SPM
  project. Built on `URLSession`/Security.framework/CryptoKit only, no
  third-party dependencies.
- Restructured to Flutter's shared-Darwin-source layout
  (`darwin/secure_pinning_apple/`, `sharedDarwinSource: true`) and added
  Swift Package Manager support (`Package.swift`) alongside the existing
  CocoaPods podspec.
- iOS deployment target raised to 16.0 (macOS unchanged at 12.0).

## 0.0.1

- Initial release.
- Pigeon-generated platform channel schema for `secure_pinning`'s native
  `SecurePinning.check()` probe API.
