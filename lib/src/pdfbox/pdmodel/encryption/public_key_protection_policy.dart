import 'package:pdfbox_dart/src/dependencies/x509_plus/x509.dart';

import 'protection_policy.dart';
import 'public_key_recipient.dart';

/// Protection policy for the public key security handler.
class PublicKeyProtectionPolicy extends ProtectionPolicy {
  final List<PublicKeyRecipient> _recipients = <PublicKeyRecipient>[];
  X509Certificate? _decryptionCertificate;

  /// Adds a new recipient definition.
  void addRecipient(PublicKeyRecipient recipient) {
    _recipients.add(recipient);
  }

  /// Removes an existing recipient definition.
  bool removeRecipient(PublicKeyRecipient recipient) {
    return _recipients.remove(recipient);
  }

  /// Returns an immutable view of the configured recipients.
  Iterable<PublicKeyRecipient> get recipients => List.unmodifiable(_recipients);

  /// Java compatibility helper matching the original API.
  Iterator<PublicKeyRecipient> getRecipientsIterator() => _recipients.iterator;

  /// Number of configured recipients.
  int get numberOfRecipients => _recipients.length;

  /// Java compatibility helper matching the original API.
  int getNumberOfRecipients() => numberOfRecipients;

  X509Certificate? get decryptionCertificate => _decryptionCertificate;

  set decryptionCertificate(X509Certificate? value) {
    _decryptionCertificate = value;
  }

  /// Java compatibility helper matching the original API.
  X509Certificate? getDecryptionCertificate() => decryptionCertificate;

  /// Java compatibility helper matching the original API.
  void setDecryptionCertificate(X509Certificate? value) =>
      decryptionCertificate = value;
}
