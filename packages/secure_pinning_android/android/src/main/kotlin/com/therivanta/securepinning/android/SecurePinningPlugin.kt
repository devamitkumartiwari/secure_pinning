package com.therivanta.securepinning.android

import io.flutter.embedding.engine.plugins.FlutterPlugin
import java.net.URL
import java.security.MessageDigest
import java.security.SecureRandom
import java.security.cert.X509Certificate
import javax.net.ssl.HttpsURLConnection
import javax.net.ssl.HostnameVerifier
import javax.net.ssl.SSLContext
import javax.net.ssl.SSLSession
import javax.net.ssl.X509TrustManager

/**
 * Android implementation of [SecurePinningHostApi] — the native probe
 * behind `SecurePinning.check()`/`SecurePinning.isPlatformSupported()`.
 * Built on `javax.net.ssl`/`java.security` only (both in the Android SDK),
 * no third-party HTTP client.
 */
class SecurePinningPlugin : FlutterPlugin, SecurePinningHostApi {
  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    SecurePinningHostApi.setUp(binding.binaryMessenger, this)
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    SecurePinningHostApi.setUp(binding.binaryMessenger, null)
  }

  override fun isPlatformSupported(callback: (Result<Boolean>) -> Unit) {
    callback(Result.success(true))
  }

  override fun check(
    request: PinningCheckRequest,
    callback: (Result<PinningCheckResult>) -> Unit,
  ) {
    // PinningCheckRequest is validated Dart-side before this ever arrives;
    // the blocking TLS handshake below must not run on the platform thread.
    Thread {
      callback(runCatching { runCheck(request) })
    }.start()
  }

  private fun runCheck(request: PinningCheckRequest): PinningCheckResult {
    // We evaluate trust ourselves below (mirrors SecurityContext(withTrustedRoots:
    // false) in the pure-Dart engine) — this trust manager only lets the
    // handshake complete so we can inspect the presented chain.
    val acceptAllTrustManager =
      object : X509TrustManager {
        override fun checkClientTrusted(chain: Array<out X509Certificate>?, authType: String?) = Unit

        override fun checkServerTrusted(chain: Array<out X509Certificate>?, authType: String?) = Unit

        override fun getAcceptedIssuers(): Array<X509Certificate> = arrayOf()
      }
    val sslContext =
      SSLContext.getInstance("TLS").apply {
        init(null, arrayOf(acceptAllTrustManager), SecureRandom())
      }

    val url = URL(request.url)
    val connection = url.openConnection() as HttpsURLConnection
    var hostnameMismatch = false
    connection.sslSocketFactory = sslContext.socketFactory
    // Keep hostname verification independent of pin matching, so a
    // hostname mismatch is reported distinctly from a pin mismatch rather
    // than silently accepted alongside the trust-all manager above.
    val defaultVerifier = HttpsURLConnection.getDefaultHostnameVerifier()
    connection.hostnameVerifier =
      HostnameVerifier { hostname: String, session: SSLSession ->
        val ok = defaultVerifier.verify(hostname, session)
        if (!ok) hostnameMismatch = true
        true
      }
    connection.connectTimeout = request.connectTimeoutMs.toInt()
    connection.readTimeout = request.readTimeoutMs.toInt()
    connection.requestMethod = request.httpMethod ?: "GET"
    request.headers?.forEach { (key, value) -> connection.setRequestProperty(key, value) }

    try {
      connection.connect()
    } catch (error: Exception) {
      throw FlutterError(
        "tls_handshake_failure",
        "The native certificate check failed: ${error.message}",
        null,
      )
    }

    try {
      if (hostnameMismatch) {
        return PinningCheckResult(
          isTrusted = false,
          errorCode = PinningErrorCode.HOSTNAME_MISMATCH,
          errorDetail = "The presented certificate's hostname did not match ${url.host}.",
        )
      }

      val chain = connection.serverCertificates.filterIsInstance<X509Certificate>()
      val pinSet = request.pinSet
      val normalizedPins = pinSet.pins.map { it.replace(":", "").uppercase() }
      val candidates =
        when (pinSet.chainPosition) {
          ChainPosition.LEAF_ONLY -> chain.take(1)
          ChainPosition.ANY_IN_CHAIN -> chain
          ChainPosition.SPECIFIC_INDEX -> {
            val index = pinSet.specificChainIndex?.toInt()
            if (index == null || index !in chain.indices) {
              throw FlutterError(
                "invalid_configuration",
                "specificChainIndex is out of range for the presented chain.",
                null,
              )
            }
            listOf(chain[index])
          }
        }

      for (cert in candidates) {
        val candidateDer =
          when (pinSet.mode) {
            WirePinningMode.LEGACY_LEAF_HASH -> cert.encoded
            WirePinningMode.SPKI, WirePinningMode.LEGACY_CA_HASH -> cert.publicKey.encoded
          }
        val hash = hashHex(candidateDer, pinSet.algorithm)
        if (normalizedPins.contains(hash)) {
          return PinningCheckResult(isTrusted = true, matchedPinFingerprint = hash)
        }
      }

      val errorCode =
        when (pinSet.mode) {
          WirePinningMode.LEGACY_LEAF_HASH -> PinningErrorCode.LEAF_HASH_MISMATCH
          WirePinningMode.SPKI -> PinningErrorCode.SPKI_MISMATCH
          WirePinningMode.LEGACY_CA_HASH -> PinningErrorCode.CHAIN_VALIDATION_FAILED
        }
      return PinningCheckResult(
        isTrusted = false,
        errorCode = errorCode,
        errorDetail = "None of the presented certificate(s) matched the configured pin set.",
      )
    } finally {
      connection.disconnect()
    }
  }

  private fun hashHex(bytes: ByteArray, algorithm: HashAlgorithm): String {
    val digestName = if (algorithm == HashAlgorithm.SHA256) "SHA-256" else "SHA-1"
    val digest = MessageDigest.getInstance(digestName).digest(bytes)
    return digest.joinToString("") { "%02X".format(it) }
  }
}
