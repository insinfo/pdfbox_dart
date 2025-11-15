import 'pd_encryption.dart';
import 'access_permission.dart';

/// Minimal port of PDFBox's `StandardSecurityHandler` focused on permission
/// extraction. Full encryption support will be layered on top of this helper.
class StandardSecurityHandler {
  /// Computes the access permissions granted by the supplied [encryption]
  /// dictionary. When the dictionary omits the `/P` entry full owner
  /// permissions are returned.
  static AccessPermission permissionsFromEncryption(PDEncryption encryption) {
    final permissions = encryption.permissions;
    final accessPermission = permissions != null
        ? AccessPermission(permissions)
        : AccessPermission.ownerAccessPermission();
    accessPermission.setReadOnly();
    return accessPermission;
  }
}