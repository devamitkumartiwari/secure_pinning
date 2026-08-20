# Contributing to secure_pinning

## Architecture, in one paragraph

Most Flutter HTTP traffic runs on `dart:io`'s own TLS stack, not on OkHttp (Android) or NSURLSession (iOS/macOS). Because of that, the **pure-Dart engine** in `lib/src/engine/` — driven by `HttpClient.badCertificateCallback` — is the primary mechanism that protects `package:http` and Dio traffic on every platform except Web. The **native engines** in `secure_pinning_android` and `secure_pinning_apple` are not that mechanism today; they power the standalone `SecurePinning.check()` probe API and are the foundation for future native-adapter interception (`cronet_http`/`cupertino_http`) once that becomes the default transport. Read the plan's "Core Architectural Insight" section before proposing a change to either engine — a PR that assumes the native engine guards a Dio request by default is working from the wrong mental model.

## Security stance on CA/root pinning

Pinning a CA or root certificate (rather than a leaf certificate's SPKI hash) effectively trusts *any* certificate that CA issues — a real security footgun. `PinningMode.legacyCaHash` exists for compatibility but requires an explicit `acknowledgedRisk` justification string at every call site. PRs that make CA-level pinning the default, or that remove the justification requirement, will not be merged without a documented, reviewed reason.

## Development setup

This repo is not a Melos/pub-workspace monorepo — the core `secure_pinning`
package lives at the repository root, and each package under `packages/*`
is developed independently. Cross-package links are wired via
`dependency_overrides` (`path:`) in each package's `pubspec.yaml`, so
`flutter pub get` resolves against the in-repo source without anything
needing to be published first.

To work on the root `secure_pinning` package:

```
flutter pub get
flutter analyze
flutter test
```

To work on any other package, `cd packages/<name>` and run the same three
commands there.

Regenerate Pigeon-derived platform channel code after editing `packages/secure_pinning_platform_interface/pigeons/messages.dart`:

```
cd packages/secure_pinning_platform_interface && dart run pigeon --input pigeons/messages.dart
```

Before submitting a PR that touches the Pigeon schema, regenerate and then
run `git diff --exit-code` on the three generated files
(`packages/secure_pinning_platform_interface/lib/src/messages.g.dart`,
`packages/secure_pinning_android/android/.../Messages.g.kt`,
`packages/secure_pinning_apple/ios/.../Messages.g.swift`) to confirm
nothing drifted — never hand-edit a `.g.dart`/`.g.kt`/`.g.swift` file.

## Testing expectations

New pinning logic (positive match, mismatch, expired cert, self-signed cert, hostname mismatch, chain/backup-pin behavior) must be covered by a test against `tools/test_server`'s local mock HTTPS server — not against a live external host. See the plan's "Testing Strategy" section for the fixture set.

## Package boundaries

- `secure_pinning` core has zero third-party dependencies. Do not add one without discussing it first — `package:http` and `dio` integrations belong in `secure_pinning_http`/`secure_pinning_dio`.
- Platform packages (`secure_pinning_android`, `secure_pinning_apple`, etc.) implement only `secure_pinning_platform_interface`'s abstract class. They are not meant to be imported directly by app code.
