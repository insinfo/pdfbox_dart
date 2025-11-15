/// Base contract for document protection policies.
///
/// The policy defines the intended key length (in bits) and whether AES
/// should be preferred when multiple algorithms are available.
abstract class ProtectionPolicy {
  static const int _defaultKeyLength = 40;

  int _encryptionKeyLength = _defaultKeyLength;
  bool _preferAes = false;

  /// Updates the key length in bits.
  ///
  /// The PDF specification only permits 40, 128 or 256 bits.
  set encryptionKeyLength(int value) {
    if (value != 40 && value != 128 && value != 256) {
      throw ArgumentError.value(
        value,
        'value',
        'Encryption key length must be 40, 128 or 256 bits',
      );
    }
    _encryptionKeyLength = value;
  }

  /// Java compatibility helper used by existing ports.
  void setEncryptionKeyLength(int value) => encryptionKeyLength = value;

  /// Returns the configured key length in bits.
  int get encryptionKeyLength => _encryptionKeyLength;

  /// Java compatibility helper used by existing ports.
  int getEncryptionKeyLength() => encryptionKeyLength;

  /// When `true`, AES should be preferred for 128-bit keys.
  bool get preferAes => _preferAes;

  set preferAes(bool value) => _preferAes = value;

  /// Java compatibility helper used by existing ports.
  bool isPreferAES() => preferAes;

  /// Java compatibility helper used by existing ports.
  void setPreferAES(bool value) => preferAes = value;
}
