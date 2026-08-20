# secure_pinning_web

Web implementation of
[`secure_pinning`](https://pub.dev/packages/secure_pinning). Certificate
pinning is not possible in a browser (JavaScript is never given access to
TLS certificate bytes), so this package exists only to give
`secure_pinning`'s Web target a well-defined, clearly-labeled
"unsupported" result instead of a missing platform implementation. Not
meant for direct use by applications — depend on
[`secure_pinning`](https://pub.dev/packages/secure_pinning) instead.
