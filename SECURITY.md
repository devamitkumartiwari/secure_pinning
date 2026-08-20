# Security Policy

`secure_pinning` is a security-relevant library — certificate-pinning defects can silently weaken or disable the protection an app believes it has. Please report suspected vulnerabilities privately rather than opening a public issue.

## Reporting a vulnerability

Email **security@therivanta.com** with:

- A description of the issue and its potential impact (e.g. a bypass that lets an untrusted certificate validate, a concurrency bug that can validate the wrong host's pin, a crash that fails open instead of closed).
- Steps to reproduce, including package version and platform (Android/iOS/macOS/Windows/Linux).
- Any proof-of-concept code, if available.

We aim to acknowledge reports within 3 business days and to ship a fix or mitigation before any public disclosure. Please give us a reasonable window to do so before disclosing publicly.

## Supported versions

Security fixes are backported to the latest minor release of the current major version. Pre-1.0 (`0.x`) releases receive fixes on the latest `0.x` release only.

## Scope

In scope: `secure_pinning` and every package in this monorepo (`secure_pinning_http`, `secure_pinning_dio`, `secure_pinning_platform_interface`, `secure_pinning_android`, `secure_pinning_apple`, `secure_pinning_windows`, `secure_pinning_linux`, `secure_pinning_web`).

Out of scope: vulnerabilities in apps that consume this library but misuse it (e.g. disabling pinning in production, hardcoding a single pin with no rotation plan) — see [`docs/SECURITY_MODEL.md`](docs/SECURITY_MODEL.md) for correct usage guidance.
