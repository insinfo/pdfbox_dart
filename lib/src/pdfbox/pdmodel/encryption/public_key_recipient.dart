import 'package:pdfbox_dart/src/dependencies/x509_plus/x509.dart';

import 'access_permission.dart';

/// Represents a single recipient entry for public key encryption flows.
class PublicKeyRecipient {
  X509Certificate? _certificate;
  AccessPermission? _permission;

  X509Certificate? get certificate => _certificate;

  set certificate(X509Certificate? value) => _certificate = value;

  /// Java compatibility helper retained for future ports.
  X509Certificate? getX509() => certificate;

  /// Java compatibility helper retained for future ports.
  void setX509(X509Certificate? value) => certificate = value;

  AccessPermission? get permission => _permission;

  set permission(AccessPermission? value) => _permission = value;

  /// Java compatibility helper retained for future ports.
  AccessPermission? getPermission() => permission;

  /// Java compatibility helper retained for future ports.
  void setPermission(AccessPermission? value) => permission = value;
}
