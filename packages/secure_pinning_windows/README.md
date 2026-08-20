# secure_pinning_windows

Windows implementation of
[`secure_pinning`](https://pub.dev/packages/secure_pinning). Pure-Dart-
engine paths (`SecurePinning.createHttpClient()`, `secure_pinning_http`,
`secure_pinning_dio`) already work today; the native `SecurePinning.check()`
probe is stubbed on this platform pending a Schannel/CNG implementation.
Not meant for direct use by applications — depend on
[`secure_pinning`](https://pub.dev/packages/secure_pinning) instead.
