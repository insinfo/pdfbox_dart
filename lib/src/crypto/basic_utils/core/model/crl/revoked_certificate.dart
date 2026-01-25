import 'crl_entry_extensions_data.dart';

class RevokedCertificate {
  /// The serialNumber of the certificate
  BigInt? serialNumber;

  /// The revocation time
  DateTime? revocationDate;

  /// The extensions
  CrlEntryExtensionsData? extensions;
}
