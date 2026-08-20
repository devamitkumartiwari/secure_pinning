import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:secure_pinning/secure_pinning.dart';

// Reference certificate generated via:
//   openssl req -x509 -newkey rsa:2048 -keyout key.pem -out cert.pem -days 3650 \
//     -nodes -subj "/CN=test.secure-pinning.example"
//   openssl x509 -in cert.pem -outform der -out cert.der
//
// Reference hashes cross-checked independently via OpenSSL (not derived
// from this package's own code, so they're a real correctness check, not
// a tautology):
//   whole-cert SHA-256: openssl dgst -sha256 -hex cert.der
//   SPKI SHA-256:        openssl x509 -in cert.pem -pubkey -noout |
//                         openssl pkey -pubin -outform der |
//                         openssl dgst -sha256 -hex
const _wholeCertSha256Hex =
    '15fe7a62898f2cf1b2eee37b0d0d6cee81ae75cc2937c08a9b0355dbc2f82762';
const _spkiSha256Hex =
    '5e218539bd1028882182b26b43336994799fe541124d2c4c36bab86b26eb87cc';

void main() {
  late Uint8List certificateDer;

  setUpAll(() {
    final fixture = File('test/fixtures/cert.der');
    certificateDer = fixture.readAsBytesSync();
  });

  group('SecurePinningEngine.validateDer — SPKI mode', () {
    test('matches the correct SPKI pin', () {
      final config = SecurePinningConfig(
        host: 'test.secure-pinning.example',
        pins: [_spkiSha256Hex],
      );
      expect(
        SecurePinningEngine.validateDer(
            certificateDer: certificateDer, config: config),
        isTrue,
      );
    });

    test('accepts colon-separated pin input', () {
      final colonSeparated = RegExp('.{2}')
          .allMatches(_spkiSha256Hex)
          .map((m) => m.group(0))
          .join(':');
      final config = SecurePinningConfig(
        host: 'test.secure-pinning.example',
        pins: [colonSeparated],
      );
      expect(
        SecurePinningEngine.validateDer(
            certificateDer: certificateDer, config: config),
        isTrue,
      );
    });

    test('rejects a wrong pin', () {
      final config = SecurePinningConfig(
        host: 'test.secure-pinning.example',
        pins: ['0' * 64],
      );
      expect(
        SecurePinningEngine.validateDer(
            certificateDer: certificateDer, config: config),
        isFalse,
      );
    });

    test('matches when a backup pin is listed alongside a wrong primary pin',
        () {
      final config = SecurePinningConfig(
        host: 'test.secure-pinning.example',
        pins: ['0' * 64, _spkiSha256Hex],
      );
      expect(
        SecurePinningEngine.validateDer(
            certificateDer: certificateDer, config: config),
        isTrue,
      );
    });

    test('does not match the whole-certificate hash (proves SPKI != leaf hash)',
        () {
      final config = SecurePinningConfig(
        host: 'test.secure-pinning.example',
        pins: [_wholeCertSha256Hex],
      );
      expect(
        SecurePinningEngine.validateDer(
            certificateDer: certificateDer, config: config),
        isFalse,
      );
    });
  });

  group('SecurePinningEngine.validateDer — legacy leaf hash mode', () {
    test('matches the correct whole-certificate pin', () {
      final config = SecurePinningConfig(
        host: 'test.secure-pinning.example',
        pins: [_wholeCertSha256Hex],
        mode: const PinningMode.legacyLeafHash(),
      );
      expect(
        SecurePinningEngine.validateDer(
            certificateDer: certificateDer, config: config),
        isTrue,
      );
    });

    test('rejects a wrong pin', () {
      final config = SecurePinningConfig(
        host: 'test.secure-pinning.example',
        pins: ['0' * 64],
        mode: const PinningMode.legacyLeafHash(),
      );
      expect(
        SecurePinningEngine.validateDer(
            certificateDer: certificateDer, config: config),
        isFalse,
      );
    });
  });

  group('SecurePinningEngine.validateDer — unsupported combinations', () {
    test('throws SecurePinningConfigurationException for legacyCaHash', () {
      final config = SecurePinningConfig(
        host: 'test.secure-pinning.example',
        pins: [_wholeCertSha256Hex],
        mode: const PinningMode.legacyCaHash(acknowledgedRisk: 'test'),
      );
      expect(
        () => SecurePinningEngine.validateDer(
            certificateDer: certificateDer, config: config),
        throwsA(isA<SecurePinningConfigurationException>()),
      );
    });

    test(
        'throws SecurePinningConfigurationException for non-leaf chain positions',
        () {
      final config = SecurePinningConfig(
        host: 'test.secure-pinning.example',
        pins: [_spkiSha256Hex],
        chainPosition: ChainPosition.anyInChain,
      );
      expect(
        () => SecurePinningEngine.validateDer(
            certificateDer: certificateDer, config: config),
        throwsA(isA<SecurePinningConfigurationException>()),
      );
    });
  });
}
