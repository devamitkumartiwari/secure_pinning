# secure_pinning example

A runnable demo of `secure_pinning`, `secure_pinning_http`, and
`secure_pinning_dio` side by side.

The app has a host field, a pins field, and three buttons — each button
runs the same GET request through a different integration surface:

- **Raw HttpClient** — [SecurePinning.createHttpClient], the lowest-level
  entry point.
- **package:http** — [SecurePinningHttpClient] from `secure_pinning_http`.
- **Dio** — [SecurePinningInterceptor] from `secure_pinning_dio`.

## Running

```
flutter run
```

## Pointing it at your own host

The pins shipped in `lib/main.dart` are placeholders and will fail to
validate against `example.com` — the demo is meant to show the three
integration surfaces and their typed-exception behavior on a mismatch, not
to be a working pin out of the box. To try it against a real pinned
connection, compute your host's SPKI pin (as a **hex string** — not
base64) and paste it into the pins field (or edit the default in
`lib/main.dart`):

```sh
openssl s_client -connect HOST:443 -servername HOST < /dev/null 2>/dev/null \
  | openssl x509 -pubkey -noout \
  | openssl pkey -pubin -outform der \
  | openssl dgst -sha256 -hex \
  | awk '{print $NF}'
```

Always include a second, backup pin (e.g. an issuing CA's SPKI hash) so a
future key rotation on the server doesn't leave the app permanently unable
to connect.
