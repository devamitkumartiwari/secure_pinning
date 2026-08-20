# secure_pinning_dio

Dio integration for
[`secure_pinning`](https://pub.dev/packages/secure_pinning) — an
`Interceptor`-shaped facade that configures Dio's `IOHttpClientAdapter`
for pinned TLS validation, built on `secure_pinning`'s pure-Dart pinning
engine.

## Usage

```dart
import 'package:dio/dio.dart';
import 'package:secure_pinning_dio/secure_pinning_dio.dart';

final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
dio.interceptors.add(
  SecurePinningInterceptor.forHost(
    dio,
    'api.example.com',
    pins: ['base64-spki-hash-1', 'base64-spki-hash-2'], // include a backup pin
  ),
);

final response = await dio.get('/');
```

For multi-host apps, backup-pin rotation, non-default hash algorithms, or
migrating from a leaf-hash-based pinning setup, construct a full
`SecurePinningConfig` instead of using `.forHost()`:

```dart
import 'package:dio/dio.dart';
import 'package:secure_pinning_dio/secure_pinning_dio.dart';

final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
dio.interceptors.add(
  SecurePinningInterceptor(
    dio,
    SecurePinningConfig(
      host: 'api.example.com',
      pins: ['base64-spki-hash-1', 'base64-spki-hash-2'],
    ),
  ),
);
```

`SecurePinningInterceptor` must be added before any request is made on
`dio` — it installs a pinned `IOHttpClientAdapter` at construction time.
If `dio.httpClientAdapter` is replaced afterward, pinning is no longer
enforced, and every request fails with a
`SecurePinningConfigurationException` explaining why (rather than
silently connecting unpinned).

See [`secure_pinning`](https://pub.dev/packages/secure_pinning) for the
full `SecurePinningConfig`/`PinningMode` API and the typed exception
hierarchy thrown on a pinning failure.
