import 'messages.g.dart';
import 'secure_pinning_platform.dart';

/// Default [SecurePinningPlatform] implementation, backed by the
/// Pigeon-generated [SecurePinningHostApi]. Android/iOS/macOS register a
/// native implementation of the host API at startup; on Windows/Linux/Web,
/// where no native implementation is registered, calls fail with a clear
/// [PigeonError] rather than hanging — platform packages for those targets
/// override this default with an explicit `unsupportedPlatform` result
/// instead of relying on that failure mode. See secure_pinning_web/windows/
/// linux for those overrides.
class MethodChannelSecurePinning extends SecurePinningPlatform {
  final SecurePinningHostApi _hostApi = SecurePinningHostApi();

  @override
  Future<PinningCheckResult> check(PinningCheckRequest request) {
    return _hostApi.check(request);
  }

  @override
  Future<bool> isPlatformSupported() {
    return _hostApi.isPlatformSupported();
  }
}
