import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:secure_pinning_platform_interface/secure_pinning_platform_interface.dart';

/// Web implementation of [SecurePinningPlatform] — permanently
/// unsupported. Browsers never expose TLS certificate bytes to page
/// JavaScript, so there is no mechanism to implement here, now or later.
/// This is a deliberate, documented "no" (see the root README), not a
/// "coming soon" placeholder.
class SecurePinningWeb extends SecurePinningPlatform {
  static void registerWith(Registrar registrar) {
    SecurePinningPlatform.instance = SecurePinningWeb();
  }

  @override
  Future<PinningCheckResult> check(PinningCheckRequest request) async {
    return PinningCheckResult(
      isTrusted: false,
      errorCode: PinningErrorCode.unsupportedPlatform,
      errorDetail: 'Certificate pinning is not supported on Flutter Web: '
          'browsers do not expose certificate/TLS details to page '
          'JavaScript. This is a permanent platform constraint, not a '
          'temporary gap.',
    );
  }

  @override
  Future<bool> isPlatformSupported() async => false;
}
