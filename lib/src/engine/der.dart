/// Minimal DER/ASN.1 reader — just enough to walk an X.509 certificate's
/// top-level structure and locate the `subjectPublicKeyInfo` field for SPKI
/// pinning, without a general-purpose ASN.1 parsing dependency.
///
/// Certificate ::= SEQUENCE {
///     tbsCertificate       TBSCertificate,
///     signatureAlgorithm   AlgorithmIdentifier,
///     signatureValue       BIT STRING }
///
/// TBSCertificate ::= SEQUENCE {
///     version         [0]  EXPLICIT Version DEFAULT v1,  -- tag 0xA0, optional
///     serialNumber         INTEGER,
///     signature            AlgorithmIdentifier,
///     issuer               Name,
///     validity             Validity,
///     subject              Name,
///     subjectPublicKeyInfo SubjectPublicKeyInfo,
///     ... }
///
/// See RFC 5280 §4.1.
library;

import 'dart:typed_data';

const int _tagContextConstructed0 = 0xA0;

class _DerTlv {
  const _DerTlv({
    required this.tag,
    required this.contentStart,
    required this.contentLength,
  });

  final int tag;
  final int contentStart;
  final int contentLength;

  int get nextOffset => contentStart + contentLength;
}

_DerTlv _readTlv(Uint8List data, int offset) {
  if (offset + 2 > data.length) {
    throw const FormatException(
        'Truncated DER data while reading a TLV header.');
  }
  final tag = data[offset];
  final firstLengthByte = data[offset + 1];
  int contentLength;
  int lengthOfLength;
  if (firstLengthByte & 0x80 == 0) {
    contentLength = firstLengthByte;
    lengthOfLength = 1;
  } else {
    final numLengthBytes = firstLengthByte & 0x7F;
    if (numLengthBytes == 0 || numLengthBytes > 4) {
      throw const FormatException('Unsupported DER length encoding.');
    }
    if (offset + 2 + numLengthBytes > data.length) {
      throw const FormatException(
          'Truncated DER data while reading a long-form length.');
    }
    contentLength = 0;
    for (var i = 0; i < numLengthBytes; i++) {
      contentLength = (contentLength << 8) | data[offset + 2 + i];
    }
    lengthOfLength = 1 + numLengthBytes;
  }
  final contentStart = offset + 1 + lengthOfLength;
  if (contentStart + contentLength > data.length) {
    throw const FormatException(
        'DER TLV content length exceeds the available data.');
  }
  return _DerTlv(
      tag: tag, contentStart: contentStart, contentLength: contentLength);
}

/// Returns the full DER TLV (tag + length + content) of the
/// `subjectPublicKeyInfo` field of an X.509 certificate — this is the
/// exact byte range conventionally hashed for SPKI pinning (matching
/// `openssl x509 -pubkey | openssl asn1parse ...`-derived SPKI hashes).
///
/// Throws [FormatException] if [certificateDer] is not a well-formed X.509
/// certificate.
Uint8List extractSubjectPublicKeyInfoDer(Uint8List certificateDer) {
  final certificateSequence = _readTlv(certificateDer, 0);
  final tbsCertificate =
      _readTlv(certificateDer, certificateSequence.contentStart);

  var offset = tbsCertificate.contentStart;

  final maybeVersion = _readTlv(certificateDer, offset);
  if (maybeVersion.tag == _tagContextConstructed0) {
    offset = maybeVersion.nextOffset;
  }

  // serialNumber, signature (AlgorithmIdentifier), issuer, validity, subject
  // — five fields to skip over before subjectPublicKeyInfo.
  for (var i = 0; i < 5; i++) {
    offset = _readTlv(certificateDer, offset).nextOffset;
  }

  final subjectPublicKeyInfo = _readTlv(certificateDer, offset);
  return Uint8List.sublistView(
    certificateDer,
    offset,
    subjectPublicKeyInfo.nextOffset,
  );
}
