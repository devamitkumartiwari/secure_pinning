# secure_pinning_http

`package:http` integration for
[`secure_pinning`](https://pub.dev/packages/secure_pinning) — a
`BaseClient` wrapper with full verb and streaming support, built on
`secure_pinning`'s pure-Dart pinning engine.

## Usage

```dart
import 'package:secure_pinning_http/secure_pinning_http.dart';

final client = SecurePinningHttpClient.forHost(
  'api.example.com',
  pins: ['base64-spki-hash-1', 'base64-spki-hash-2'], // include a backup pin
);
final response = await client.get(Uri.https('api.example.com', '/'));
```

`SecurePinningHttpClient` is a full `http.BaseClient` — `get`, `post`,
`put`, `patch`, `delete`, `head`, `read`, `readBytes`, and streaming via
`send()` all work as usual, validated against the pinned connection.

For multi-host apps, backup-pin rotation, non-default hash algorithms, or
migrating from a leaf-hash-based pinning setup, construct a full
`SecurePinningConfig` instead of using `.forHost()`:

```dart
import 'package:secure_pinning_http/secure_pinning_http.dart';

final client = SecurePinningHttpClient(
  SecurePinningConfig(
    host: 'api.example.com',
    pins: ['base64-spki-hash-1', 'base64-spki-hash-2'],
  ),
);
```

See [`secure_pinning`](https://pub.dev/packages/secure_pinning) for the
full `SecurePinningConfig`/`PinningMode` API and the typed exception
hierarchy thrown on a pinning failure.
