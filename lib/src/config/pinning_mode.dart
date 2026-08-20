/// How pinned values should be interpreted and compared. See
/// `docs/SECURITY_MODEL.md` for the tradeoffs between these.
sealed class PinningMode {
  const PinningMode();

  /// Subject Public Key Info hash — the safe default. Survives certificate
  /// renewal as long as the key pair is unchanged.
  const factory PinningMode.spki() = SpkiPinningMode;

  /// Whole leaf-certificate hash. Breaks on any certificate renewal, even
  /// a same-key one. Exists for migration compatibility with plugins that
  /// pin the full leaf certificate instead of just its public key —
  /// prefer [PinningMode.spki] for new configurations.
  const factory PinningMode.legacyLeafHash() = LegacyLeafHashPinningMode;

  /// Pins a CA/root certificate rather than a leaf. This effectively
  /// trusts *any* certificate issued by that CA — a real security
  /// footgun (see `docs/SECURITY_MODEL.md`). [acknowledgedRisk] must be a
  /// non-empty explanation of why this mode was chosen; it is not
  /// interpreted, only required, as a deliberate friction point.
  ///
  /// Not supported by the pure-Dart engine — requires the native
  /// `SecurePinning.check()` probe API, since validating a CA/root pin
  /// requires walking the full certificate chain.
  const factory PinningMode.legacyCaHash({required String acknowledgedRisk}) =
      LegacyCaHashPinningMode;
}

final class SpkiPinningMode extends PinningMode {
  const SpkiPinningMode();

  @override
  bool operator ==(Object other) => other is SpkiPinningMode;

  @override
  int get hashCode => (SpkiPinningMode).hashCode;
}

final class LegacyLeafHashPinningMode extends PinningMode {
  const LegacyLeafHashPinningMode();

  @override
  bool operator ==(Object other) => other is LegacyLeafHashPinningMode;

  @override
  int get hashCode => (LegacyLeafHashPinningMode).hashCode;
}

final class LegacyCaHashPinningMode extends PinningMode {
  const LegacyCaHashPinningMode({required this.acknowledgedRisk});

  final String acknowledgedRisk;

  @override
  bool operator ==(Object other) =>
      other is LegacyCaHashPinningMode &&
      other.acknowledgedRisk == acknowledgedRisk;

  @override
  int get hashCode => Object.hash(LegacyCaHashPinningMode, acknowledgedRisk);
}
