import 'decryption_material.dart';

/// Carries the password used by the standard security handler.
class StandardDecryptionMaterial extends DecryptionMaterial {
  /// Creates a new decryption material with the supplied [password].
  const StandardDecryptionMaterial(this.password);

  /// Password used to unlock the document.
  final String password;
}
