import 'dart:io';

import 'package:secure_pinning/secure_pinning.dart' show SecurePinningException;
import 'package:secure_pinning_http/secure_pinning_http.dart';

Future<void> main() async {
  final client = SecurePinningHttpClient.forHost(
    'api.example.com',
    // Replace with your own host's real SPKI pins — compute them with:
    //   openssl s_client -connect HOST:443 -servername HOST < /dev/null 2>/dev/null \
    //     | openssl x509 -pubkey -noout \
    //     | openssl pkey -pubin -outform der \
    //     | openssl dgst -sha256 -binary \
    //     | openssl enc -base64
    // Always include a backup pin so a future key rotation doesn't brick
    // the app.
    pins: ['base64-spki-hash-1', 'base64-spki-hash-2'],
  );

  try {
    final response = await client.get(Uri.https('api.example.com', '/'));
    stdout.writeln(
      'HTTP ${response.statusCode} — ${response.bodyBytes.length} bytes',
    );
  } on SecurePinningException catch (error) {
    stdout.writeln('Pinning failed: $error');
  } finally {
    client.close();
  }
}
