## 0.0.1

- Initial release.
- `SecurePinningInterceptor`, an `Interceptor`-shaped facade that
  configures Dio's `IOHttpClientAdapter` for pinned TLS validation at
  construction time, built on `secure_pinning`'s pure-Dart pinning engine.
- `SecurePinningInterceptor.forHost()` convenience constructor for
  single-host, SPKI + SHA-256 + default-timeout setups.
- `callFollowingErrorInterceptor` option controlling whether a pinning
  rejection still propagates to the next error interceptor in the chain.
- Typed exception mapping via `onError` — TLS handshake and socket
  failures surface as `secure_pinning`'s typed exceptions.
- Detects and rejects requests if `dio.httpClientAdapter` is replaced
  after the interceptor is installed, since pinning would silently stop
  being enforced otherwise.
