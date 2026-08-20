# secure_pinning_platform_interface

Common platform interface and Pigeon-generated platform channel schema
for the [`secure_pinning`](https://pub.dev/packages/secure_pinning)
certificate-pinning plugin. Not meant for direct use by applications —
depend on [`secure_pinning`](https://pub.dev/packages/secure_pinning)
instead. This package exists so platform implementations
(`secure_pinning_android`, `secure_pinning_apple`, etc.) share one
consistent, typed contract rather than each defining its own.
