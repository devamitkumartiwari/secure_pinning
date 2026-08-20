# secure_pinning

Certificate pinning for Flutter — Android, iOS, and macOS today; Windows and Linux stubbed for a future release; Web is permanently unsupported (browsers never expose TLS certificate bytes to page JavaScript).

## Why another certificate-pinning plugin?

Most Flutter HTTP traffic (`package:http`'s default client, Dio's default adapter) runs on `dart:io`'s own TLS stack, not on OkHttp or NSURLSession. `secure_pinning`'s core mechanism validates the actual connection your request uses — no separate preflight connection, no double round-trip — via `dart:io`'s `HttpClient.badCertificateCallback`. See [`docs/SECURITY_MODEL.md`](docs/SECURITY_MODEL.md) for the full design rationale, SPKI vs. leaf vs. CA pinning tradeoffs, and what certificate pinning does and doesn't protect against.

## Features

- **Three pinning modes** — [`PinningMode.spki`](lib/src/config/pinning_mode.dart) (public-key hash, survives certificate renewal, the default), `PinningMode.legacyLeafHash` (whole-certificate hash, for compatibility with plugins that pin the full leaf certificate instead of just its public key), and `PinningMode.legacyCaHash` (CA/root pinning, gated behind a required `acknowledgedRisk` justification).
- **Validates the real connection** — the pure-Dart engine hooks `dart:io`'s `HttpClient.badCertificateCallback` directly, so `package:http` and Dio traffic is checked on the actual request with no separate preflight round trip.
- **SHA-256 and SHA-1** hash algorithm support (`HashAlgorithm`).
- **Backup-pin support** — list multiple pins so a future key rotation doesn't require an app update.
- **Configurable connect/read timeouts**, enforced even where `dart:io` has no native read-timeout concept.
- **A typed exception hierarchy** — `SecurePinningValidationException`, `SecurePinningTimeoutException`, `SecurePinningConfigurationException`, `SecurePinningUnsupportedPlatformException`, `SecurePinningNetworkException` — consistent across every platform and integration surface, never a raw `HandshakeException`/`PlatformException`.
- **`package:http` and Dio integrations** ([`secure_pinning_http`](packages/secure_pinning_http), [`secure_pinning_dio`](packages/secure_pinning_dio)) as separate opt-in packages — pull in only what you use.
- **A native probe API** (`SecurePinning.check()` + `SecurePinning.isPlatformSupported()`) for one-off/out-of-band checks, and the only path that can validate `PinningMode.legacyCaHash` (which requires walking the full certificate chain).
- **Federated plugin architecture** — the core `secure_pinning` package has zero third-party dependencies beyond `crypto`; native platform code lives in its own package per platform.
- **Platform coverage** — Android, iOS, and macOS supported today; Windows and Linux stubbed for a future release; Web is permanently unsupported (browsers never expose TLS certificate bytes to page JavaScript).

## Packages

| Package | Purpose |
|---|---|
| **`secure_pinning`** (this repo's root package) | Core: config, validation engine, raw `HttpClient` factory, typed exceptions, native probe API. Zero third-party dependencies. |
| [`secure_pinning_http`](packages/secure_pinning_http) | `package:http`-compatible `BaseClient` wrapper. |
| [`secure_pinning_dio`](packages/secure_pinning_dio) | Dio interceptor-shaped integration. |
| [`secure_pinning_platform_interface`](packages/secure_pinning_platform_interface) | Pigeon-generated platform channel schema. |
| [`secure_pinning_android`](packages/secure_pinning_android) | Android (Kotlin/`javax.net.ssl`) native probe engine. |
| [`secure_pinning_apple`](packages/secure_pinning_apple) | iOS + macOS (Swift/Security.framework) native probe engine, one shared package. |
| [`secure_pinning_windows`](packages/secure_pinning_windows) | Stub today; real implementation planned. |
| [`secure_pinning_linux`](packages/secure_pinning_linux) | Stub today; real implementation planned. |
| [`secure_pinning_web`](packages/secure_pinning_web) | Permanent stub — certificate pinning is not possible in a browser. |

## Installation

Add whichever integration package(s) match your HTTP stack — you don't
need all of them:

```
flutter pub add secure_pinning_http   # package:http
flutter pub add secure_pinning_dio    # Dio
flutter pub add secure_pinning        # raw HttpClient / native probe only, no HTTP client wrapper
```

`secure_pinning_http` and `secure_pinning_dio` both depend on
`secure_pinning` automatically — you don't need to add it yourself unless
you're using the raw client or the native probe API directly.

## Getting your pins

Every usage example below needs at least one SPKI pin for the host you're
pinning, as a **hex string** (colon-tolerant, case-insensitive — not
base64). Compute it with:

```sh
openssl s_client -connect HOST:443 -servername HOST < /dev/null 2>/dev/null \
  | openssl x509 -pubkey -noout \
  | openssl pkey -pubin -outform der \
  | openssl dgst -sha256 -hex \
  | awk '{print $NF}'
```

Always include a **second, backup pin** (e.g. the SPKI hash of the
issuing CA, or a planned replacement key) — a single pin means any future
key rotation on the server locks your app out until an update ships.

## Usage

The easiest path for most apps is `secure_pinning_http` or
`secure_pinning_dio` — pick whichever matches your existing HTTP stack.
Both are thin wrappers with one required call to get pinning working.

### `package:http`

```dart
import 'package:secure_pinning_http/secure_pinning_http.dart';

final client = SecurePinningHttpClient.forHost(
  'api.example.com',
  pins: ['hex-spki-hash-1', 'hex-spki-hash-2'], // include a backup pin
);
final response = await client.get(Uri.https('api.example.com', '/'));
```

`SecurePinningHttpClient` is a full `http.BaseClient` — `get`, `post`,
`put`, `patch`, `delete`, `head`, `read`, `readBytes`, and streaming via
`send()` all work as usual, validated against the pinned connection.

### Dio

```dart
import 'package:dio/dio.dart';
import 'package:secure_pinning_dio/secure_pinning_dio.dart';

final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
dio.interceptors.add(
  SecurePinningInterceptor.forHost(
    dio,
    'api.example.com',
    pins: ['hex-spki-hash-1', 'hex-spki-hash-2'],
  ),
);

final response = await dio.get('/');
```

Add `SecurePinningInterceptor` before making any request on `dio` — it
installs a pinned `IOHttpClientAdapter` at construction time.

### Raw `HttpClient` / a custom stack

If you're not using `package:http` or Dio, `SecurePinning.createHttpClient`
gives you a pinned `dart:io` `HttpClient` directly:

```dart
import 'package:secure_pinning/secure_pinning.dart';

final config = SecurePinningConfig(
  host: 'api.example.com',
  pins: ['hex-spki-hash-1', 'hex-spki-hash-2'],
);
final client = SecurePinning.createHttpClient(config);

final request = await client.getUrl(Uri.https('api.example.com', '/'));
final response = await SecurePinning.enforceReadTimeout(
  request.close(),
  config.readTimeout,
);
```

`enforceReadTimeout` is needed because `dart:io`'s `HttpClient` has no
built-in read-timeout concept the way OkHttp/URLSession do — both
integration packages above already call it internally.

### One-off checks and CA/root pinning

`SecurePinning.check()` validates a pin set against a URL independently
of any HTTP request — useful for a startup connectivity check, or as the
only way to validate `PinningMode.legacyCaHash` (CA-level pinning
requires walking the full certificate chain, which the pure-Dart engine
above can't do):

```dart
import 'package:secure_pinning/secure_pinning.dart';

final result = await SecurePinning.check(
  url: 'https://api.example.com',
  config: SecurePinningConfig(
    host: 'api.example.com',
    pins: ['hex-spki-hash-1', 'hex-spki-hash-2'],
  ),
);
print(result.isTrusted ? 'Trusted' : 'Rejected: ${result.errorCode}');
```

A pin mismatch here is returned as data (`result.isTrusted == false`),
not thrown — only genuine infrastructure failures (DNS failure,
malformed config) throw. This is the only supported platform surface —
check `SecurePinning.isPlatformSupported()` first if you need to know
whether it's available (Android/iOS/macOS today; Windows/Linux stubbed;
Web unsupported).

### Handling failures

All three integrations above throw the same typed exception hierarchy on
a pinning or connectivity failure — catch `SecurePinningException` (or a
specific subtype) instead of a raw `HandshakeException`/`SocketException`:

```dart
try {
  final response = await client.get(Uri.https('api.example.com', '/'));
} on SecurePinningValidationException catch (e) {
  // The presented certificate didn't match the configured pins.
} on SecurePinningTimeoutException catch (e) {
  // Connect or read timed out.
} on SecurePinningException catch (e) {
  // Any other pinning-related failure — see e.message.
}
```

See each package's README for its full API, and [`example`](example) for
a runnable app covering the raw client, `package:http`, Dio, and native
probe integrations side by side.

## Using the example app

1. `cd example && flutter pub get`
2. `flutter run` and pick a connected device or simulator.
3. Enter a **Host** and **Pins** — the shipped values are placeholders that
   won't validate; see [`example/README.md`](example/README.md) for the
   `openssl` one-liner to compute real SPKI pins for your own host.
4. Pick a pinning mode from the segmented selector (**SPKI**, **Legacy leaf
   hash**, or **Legacy CA hash** — selecting CA hash reveals a required
   "acknowledged risk" field).
5. Tap **Raw HttpClient**, **package:http**, **Dio**, or **Native probe
   (check())** to run a pinned request through that integration surface.
   Results (or the typed exception thrown) appear in the log below —
   note that CA hash only actually validates through the native probe
   button; the other three correctly reject it with
   `SecurePinningConfigurationException`, since the pure-Dart engine can't
   walk the full certificate chain that CA-level pinning requires.

## License

Apache-2.0 — see [LICENSE](LICENSE).
