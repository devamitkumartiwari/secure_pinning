## 0.0.2

- No functional changes — bumps the `secure_pinning` dependency
  constraint to `^0.0.2` to match that package's current release.

## 0.0.1

- Initial release.
- `SecurePinningHttpClient`, a pinned `http.BaseClient` with full verb and
  streaming support (`get`, `post`, `put`, `patch`, `delete`, `head`,
  `read`, `readBytes`, `send`), built on `secure_pinning`'s pure-Dart
  pinning engine.
- `SecurePinningHttpClient.forHost()` convenience constructor for
  single-host, SPKI + SHA-256 + default-timeout setups.
- Typed exception mapping — TLS handshake and socket failures surface as
  `secure_pinning`'s typed exceptions, never a raw
  `HandshakeException`/`SocketException`.
