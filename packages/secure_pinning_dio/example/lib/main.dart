import 'dart:io';

import 'package:dio/dio.dart';
import 'package:secure_pinning/secure_pinning.dart' show SecurePinningException;
import 'package:secure_pinning_dio/secure_pinning_dio.dart';

Future<void> main() async {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
  dio.interceptors.add(
    SecurePinningInterceptor.forHost(
      dio,
      'api.example.com',
      // Replace with your own host's real SPKI pins — compute them with:
      //   openssl s_client -connect HOST:443 -servername HOST < /dev/null 2>/dev/null \
      //     | openssl x509 -pubkey -noout \
      //     | openssl pkey -pubin -outform der \
      //     | openssl dgst -sha256 -binary \
      //     | openssl enc -base64
      // Always include a backup pin so a future key rotation doesn't
      // brick the app.
      pins: [
        'base64-spki-hash-1',
        'base64-spki-hash-2',
      ],
    ),
  );

  try {
    final response = await dio.get<String>('/');
    stdout.writeln(
      'HTTP ${response.statusCode} — ${(response.data ?? '').length} bytes',
    );
  } on DioException catch (error) {
    final pinningError = error.error;
    if (pinningError is SecurePinningException) {
      stdout.writeln('Pinning failed: $pinningError');
    } else {
      rethrow;
    }
  } finally {
    dio.close();
  }
}
