import 'access_permission.dart';
import 'protection_policy.dart';

/// Password based protection policy matching PDFBox's standard handler.
class StandardProtectionPolicy extends ProtectionPolicy {
  StandardProtectionPolicy(
    String ownerPassword,
    String userPassword,
    AccessPermission permissions,
  )   : _ownerPassword = ownerPassword,
        _userPassword = userPassword,
        _permissions = permissions;

  AccessPermission _permissions;
  String _ownerPassword;
  String _userPassword;

  AccessPermission get permissions => _permissions;

  set permissions(AccessPermission value) => _permissions = value;

  /// Java style getter retained for easier porting.
  AccessPermission getPermissions() => permissions;

  /// Java style setter retained for easier porting.
  void setPermissions(AccessPermission value) => permissions = value;

  String get ownerPassword => _ownerPassword;

  set ownerPassword(String value) => _ownerPassword = value;

  String get userPassword => _userPassword;

  set userPassword(String value) => _userPassword = value;

  /// Java compatibility helper matching the original API.
  String getOwnerPassword() => ownerPassword;

  /// Java compatibility helper matching the original API.
  void setOwnerPassword(String value) => ownerPassword = value;

  /// Java compatibility helper matching the original API.
  String getUserPassword() => userPassword;

  /// Java compatibility helper matching the original API.
  void setUserPassword(String value) => userPassword = value;
}
