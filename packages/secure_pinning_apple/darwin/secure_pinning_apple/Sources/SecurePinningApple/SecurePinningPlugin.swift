import Foundation
import Security
import CryptoKit

#if os(iOS)
  import Flutter
#elseif os(macOS)
  import FlutterMacOS

  // FlutterMacOS's FlutterError doesn't conform to Swift's Error the way
  // Flutter (iOS)'s does — needed here to use it with Result<T, Error>/throw.
  extension FlutterError: Error {}
#else
  #error("Unsupported platform.")
#endif

/// iOS/macOS implementation of `SecurePinningHostApi` — the native probe
/// behind `SecurePinning.check()`/`SecurePinning.isPlatformSupported()`.
/// Built on `URLSession`/Security.framework only, no third-party HTTP
/// client.
public class SecurePinningPlugin: NSObject, FlutterPlugin, SecurePinningHostApi {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let api = SecurePinningPlugin()
    #if os(iOS)
      SecurePinningHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: api)
    #elseif os(macOS)
      SecurePinningHostApiSetup.setUp(binaryMessenger: registrar.messenger, api: api)
    #endif
  }

  func isPlatformSupported(completion: @escaping (Result<Bool, Error>) -> Void) {
    completion(.success(true))
  }

  func check(
    request: PinningCheckRequest,
    completion: @escaping (Result<PinningCheckResult, Error>) -> Void
  ) {
    guard let url = URL(string: request.url), let host = url.host else {
      completion(
        .failure(
          FlutterError(
            code: "invalid_configuration", message: "\(request.url) is not a valid URL.",
            details: nil)))
      return
    }

    var urlRequest = URLRequest(
      url: url,
      timeoutInterval: TimeInterval(request.connectTimeoutMs) / 1000.0)
    urlRequest.httpMethod = request.httpMethod ?? "GET"
    for (key, value) in request.headers ?? [:] {
      urlRequest.setValue(value, forHTTPHeaderField: key)
    }

    let delegate = PinningProbeDelegate(host: host, pinSet: request.pinSet)
    let config = URLSessionConfiguration.ephemeral
    config.timeoutIntervalForRequest = TimeInterval(request.readTimeoutMs) / 1000.0
    let session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)

    session.dataTask(with: urlRequest) { _, _, error in
      session.finishTasksAndInvalidate()
      if let capturedError = delegate.infrastructureError {
        completion(.failure(capturedError))
      } else if let result = delegate.result {
        completion(.success(result))
      } else if let error = error {
        completion(
          .failure(
            FlutterError(
              code: "tls_handshake_failure",
              message: "The native certificate check failed: \(error.localizedDescription)",
              details: nil)))
      } else {
        completion(
          .failure(
            FlutterError(
              code: "unknown", message: "The native certificate check produced no result.",
              details: nil)))
      }
    }.resume()
  }
}

/// Captures the presented certificate chain from the TLS handshake (bypassing
/// system chain-of-trust evaluation, mirroring `SecurityContext(withTrustedRoots:
/// false)` in the pure-Dart engine) and runs the pin match ourselves.
private final class PinningProbeDelegate: NSObject, URLSessionDelegate {
  init(host: String, pinSet: PinSet) {
    self.host = host
    self.pinSet = pinSet
  }

  let host: String
  let pinSet: PinSet
  private(set) var result: PinningCheckResult?
  private(set) var infrastructureError: Error?

  func urlSession(
    _ session: URLSession,
    didReceive challenge: URLAuthenticationChallenge,
    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
  ) {
    guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
      let trust = challenge.protectionSpace.serverTrust
    else {
      completionHandler(.performDefaultHandling, nil)
      return
    }

    guard let chain = SecTrustCopyCertificateChain(trust) as? [SecCertificate], !chain.isEmpty
    else {
      infrastructureError = FlutterError(
        code: "tls_handshake_failure", message: "The server presented no certificate chain.",
        details: nil)
      completionHandler(.cancelAuthenticationChallenge, nil)
      return
    }

    if !Self.hostnameAndValidity(ok: chain[0], host: host) {
      result = PinningCheckResult(
        isTrusted: false,
        errorCode: .hostnameMismatch,
        errorDetail: "The presented certificate's hostname/validity did not match \(host)."
      )
      completionHandler(.cancelAuthenticationChallenge, nil)
      return
    }

    let normalizedPins = Set(pinSet.pins.map { $0.replacingOccurrences(of: ":", with: "").uppercased() })
    let candidates: [SecCertificate]
    switch pinSet.chainPosition {
    case .leafOnly:
      candidates = [chain[0]]
    case .anyInChain:
      candidates = chain
    case .specificIndex:
      guard let index = pinSet.specificChainIndex, Int(index) >= 0, Int(index) < chain.count else {
        infrastructureError = FlutterError(
          code: "invalid_configuration",
          message: "specificChainIndex is out of range for the presented chain.", details: nil)
        completionHandler(.cancelAuthenticationChallenge, nil)
        return
      }
      candidates = [chain[Int(index)]]
    }

    for cert in candidates {
      let der = SecCertificateCopyData(cert) as Data
      let candidateBytes: Data
      switch pinSet.mode {
      case .legacyLeafHash:
        candidateBytes = der
      case .spki, .legacyCaHash:
        guard let spki = try? DerReader.extractSubjectPublicKeyInfo(der) else { continue }
        candidateBytes = spki
      }
      let hash = Self.hashHex(candidateBytes, algorithm: pinSet.algorithm)
      if normalizedPins.contains(hash) {
        result = PinningCheckResult(isTrusted: true, matchedPinFingerprint: hash)
        // Accept the handshake so the caller's HTTP request (if any)
        // completes normally — our own pin check above is the real trust
        // decision, not the system chain-of-trust evaluator.
        completionHandler(.useCredential, URLCredential(trust: trust))
        return
      }
    }

    let errorCode: PinningErrorCode =
      pinSet.mode == .legacyLeafHash ? .leafHashMismatch : .spkiMismatch
    result = PinningCheckResult(
      isTrusted: false,
      errorCode: errorCode,
      errorDetail: "None of the presented certificate(s) matched the configured pin set."
    )
    completionHandler(.cancelAuthenticationChallenge, nil)
  }

  /// Evaluates [cert] against [host] and its own validity period only, by
  /// making it its own trust anchor — this deliberately isolates
  /// hostname/expiry checks from chain-of-trust, since we make our own
  /// trust decision via pin matching, not the system's root store.
  private static func hostnameAndValidity(ok cert: SecCertificate, host: String) -> Bool {
    var trust: SecTrust?
    let policy = SecPolicyCreateSSL(true, host as CFString)
    guard SecTrustCreateWithCertificates(cert, policy, &trust) == errSecSuccess,
      let trust = trust
    else {
      return false
    }
    SecTrustSetAnchorCertificates(trust, [cert] as CFArray)
    SecTrustSetAnchorCertificatesOnly(trust, true)
    var error: CFError?
    return SecTrustEvaluateWithError(trust, &error)
  }

  private static func hashHex(_ data: Data, algorithm: HashAlgorithm) -> String {
    let digestBytes: [UInt8]
    switch algorithm {
    case .sha256:
      digestBytes = Array(SHA256.hash(data: data))
    case .sha1:
      digestBytes = Array(Insecure.SHA1.hash(data: data))
    }
    return digestBytes.map { String(format: "%02X", $0) }.joined()
  }
}

/// Minimal DER/ASN.1 reader — ports `lib/src/engine/der.dart`'s
/// `extractSubjectPublicKeyInfoDer` so the SPKI hash matches exactly what
/// the pure-Dart engine and `openssl x509 -pubkey | openssl pkey -pubin
/// -outform der` compute. Security.framework doesn't expose the SPKI DER
/// directly (`SecKeyCopyExternalRepresentation` only returns raw key
/// material), so this walks the certificate's ASN.1 structure ourselves.
private enum DerReader {
  private struct Tlv {
    let tag: UInt8
    let contentStart: Int
    let contentLength: Int
    var nextOffset: Int { contentStart + contentLength }
  }

  private static let tagContextConstructed0: UInt8 = 0xA0

  private static func readTlv(_ data: Data, _ offset: Int) throws -> Tlv {
    guard offset + 2 <= data.count else {
      throw NSError(domain: "SecurePinningApple", code: 1, userInfo: nil)
    }
    let bytes = [UInt8](data)
    let tag = bytes[offset]
    let firstLengthByte = bytes[offset + 1]
    var contentLength: Int
    var lengthOfLength: Int
    if firstLengthByte & 0x80 == 0 {
      contentLength = Int(firstLengthByte)
      lengthOfLength = 1
    } else {
      let numLengthBytes = Int(firstLengthByte & 0x7F)
      guard numLengthBytes > 0, numLengthBytes <= 4, offset + 2 + numLengthBytes <= data.count
      else {
        throw NSError(domain: "SecurePinningApple", code: 2, userInfo: nil)
      }
      contentLength = 0
      for i in 0..<numLengthBytes {
        contentLength = (contentLength << 8) | Int(bytes[offset + 2 + i])
      }
      lengthOfLength = 1 + numLengthBytes
    }
    let contentStart = offset + 1 + lengthOfLength
    guard contentStart + contentLength <= data.count else {
      throw NSError(domain: "SecurePinningApple", code: 3, userInfo: nil)
    }
    return Tlv(tag: tag, contentStart: contentStart, contentLength: contentLength)
  }

  static func extractSubjectPublicKeyInfo(_ certificateDer: Data) throws -> Data {
    let certificateSequence = try readTlv(certificateDer, 0)
    let tbsCertificate = try readTlv(certificateDer, certificateSequence.contentStart)

    var offset = tbsCertificate.contentStart

    let maybeVersion = try readTlv(certificateDer, offset)
    if maybeVersion.tag == tagContextConstructed0 {
      offset = maybeVersion.nextOffset
    }

    // serialNumber, signature (AlgorithmIdentifier), issuer, validity,
    // subject — five fields to skip over before subjectPublicKeyInfo.
    for _ in 0..<5 {
      offset = try readTlv(certificateDer, offset).nextOffset
    }

    let subjectPublicKeyInfo = try readTlv(certificateDer, offset)
    return certificateDer.subdata(in: offset..<subjectPublicKeyInfo.nextOffset)
  }
}
