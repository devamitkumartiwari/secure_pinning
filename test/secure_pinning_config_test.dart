import 'package:flutter_test/flutter_test.dart';
import 'package:secure_pinning/secure_pinning.dart';

void main() {
  group('SecurePinningConfig validation', () {
    test('throws SecurePinningConfigurationException for an empty host', () {
      expect(
        () => SecurePinningConfig(host: '', pins: ['AA']),
        throwsA(isA<SecurePinningConfigurationException>()),
      );
    });

    test('throws SecurePinningConfigurationException for an empty pin list',
        () {
      expect(
        () => SecurePinningConfig(host: 'example.com', pins: const []),
        throwsA(isA<SecurePinningConfigurationException>()),
      );
    });

    test(
        'throws SecurePinningConfigurationException for legacyCaHash with a blank justification',
        () {
      expect(
        () => SecurePinningConfig(
          host: 'example.com',
          pins: ['AA'],
          mode: const PinningMode.legacyCaHash(acknowledgedRisk: '   '),
        ),
        throwsA(isA<SecurePinningConfigurationException>()),
      );
    });

    test('accepts legacyCaHash with a non-empty justification', () {
      final config = SecurePinningConfig(
        host: 'example.com',
        pins: ['AA'],
        mode: const PinningMode.legacyCaHash(
            acknowledgedRisk: 'migrating from a pinned internal CA'),
      );
      expect(config.mode, isA<LegacyCaHashPinningMode>());
    });

    test('defaults to SPKI mode, SHA-256, leaf-only chain position', () {
      final config = SecurePinningConfig(host: 'example.com', pins: ['AA']);
      expect(config.mode, isA<SpkiPinningMode>());
      expect(config.algorithm, HashAlgorithm.sha256);
      expect(config.chainPosition, ChainPosition.leafOnly);
    });

    test('normalizes colon-separated and mixed-case pins consistently', () {
      final config = SecurePinningConfig(
        host: 'example.com',
        pins: ['aa:bb:cc', 'AABBCC'],
      );
      expect(config.normalizedPins, ['AABBCC', 'AABBCC']);
    });
  });
}
