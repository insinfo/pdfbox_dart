import 'dart:typed_data';

/// Represents the permissions granted by a PDF encryption dictionary.
///
/// Mirrors the behaviour of Apache PDFBox's `AccessPermission`, exposing the
/// bit flags defined in ISO 32000-1, Table 20. Bit positions are one-based and
/// match the Java implementation to keep parity when porting security handlers.
class AccessPermission {
  /// Constructs a new permission object. When [permissions] is omitted the
  /// default owner permissions are assumed.
  AccessPermission([int? permissions])
      : _permissions =
            _normalisePermissions(permissions ?? _defaultPermissions);

  /// Constructs a permission object from the four permission bytes contained in
  /// an encryption dictionary (`/P`).
  factory AccessPermission.fromBytes(Uint8List bytes) {
    if (bytes.length != 4) {
      throw ArgumentError.value(bytes.length, 'bytes.length',
          'Permission array must contain exactly 4 bytes');
    }
    var value = 0;
    for (final current in bytes) {
      value = (value << 8) | (current & 0xff);
    }
    return AccessPermission(value);
  }

  static const int _defaultPermissions = ~3; // bits 1 and 2 must be zero
  static const int _printBit = 3;
  static const int _modifyBit = 4;
  static const int _extractBit = 5;
  static const int _modifyAnnotationsBit = 6;
  static const int _fillInFormBit = 9;
  static const int _extractForAccessibilityBit = 10;
  static const int _assembleDocumentBit = 11;
  static const int _faithfulPrintBit = 12;

  int _permissions;
  bool _readOnly = false;

  static int _normalisePermissions(int value) => value & 0xffffffff;

  /// Permissions granted to the owner password holder.
  static AccessPermission ownerAccessPermission() {
    final permission = AccessPermission(_defaultPermissions);
    permission
      ..setCanPrint(true)
      ..setCanModify(true)
      ..setCanExtractContent(true)
      ..setCanModifyAnnotations(true)
      ..setCanFillInForm(true)
      ..setCanExtractForAccessibility(true)
      ..setCanAssembleDocument(true)
      ..setCanPrintFaithful(true);
    permission.setReadOnly();
    return permission;
  }

  /// Marks this instance read-only, preventing further flag modifications.
  void setReadOnly() => _readOnly = true;

  /// Returns `true` when all permission bits allow full access.
  bool get isOwnerPermission =>
      canPrint &&
      canModify &&
      canExtractContent &&
      canModifyAnnotations &&
      canFillInForm &&
      canExtractForAccessibility &&
      canAssembleDocument &&
      canPrintFaithful;

  /// Raw permission bits as stored in the encryption dictionary.
  int get permissionBytes => _permissions;

  /// Returns the permission bits formatted for public-key encryption flows.
  int get permissionBytesForPublicKey {
    setPermissionBit(1, true);
    setPermissionBit(7, false);
    setPermissionBit(8, false);
    for (var bit = 13; bit <= 32; bit++) {
      setPermissionBit(bit, false);
    }
    return _permissions;
  }

  bool get canPrint => _isPermissionBitOn(_printBit);

  void setCanPrint(bool allow) => setPermissionBit(_printBit, allow);

  bool get canModify => _isPermissionBitOn(_modifyBit);

  void setCanModify(bool allow) => setPermissionBit(_modifyBit, allow);

  bool get canExtractContent => _isPermissionBitOn(_extractBit);

  void setCanExtractContent(bool allow) => setPermissionBit(_extractBit, allow);

  bool get canModifyAnnotations => _isPermissionBitOn(_modifyAnnotationsBit);

  void setCanModifyAnnotations(bool allow) =>
      setPermissionBit(_modifyAnnotationsBit, allow);

  bool get canFillInForm => _isPermissionBitOn(_fillInFormBit);

  void setCanFillInForm(bool allow) => setPermissionBit(_fillInFormBit, allow);

  bool get canExtractForAccessibility =>
      _isPermissionBitOn(_extractForAccessibilityBit);

  void setCanExtractForAccessibility(bool allow) =>
      setPermissionBit(_extractForAccessibilityBit, allow);

  bool get canAssembleDocument => _isPermissionBitOn(_assembleDocumentBit);

  void setCanAssembleDocument(bool allow) =>
      setPermissionBit(_assembleDocumentBit, allow);

  bool get canPrintFaithful => _isPermissionBitOn(_faithfulPrintBit);

  void setCanPrintFaithful(bool allow) =>
      setPermissionBit(_faithfulPrintBit, allow);

  bool _isPermissionBitOn(int bit) => (_permissions & (1 << (bit - 1))) != 0;

  bool setPermissionBit(int bit, bool value) {
    if (_readOnly) {
      return _isPermissionBitOn(bit);
    }
    var permissions = _permissions;
    if (value) {
      permissions |= 1 << (bit - 1);
    } else {
      permissions &= ~(1 << (bit - 1));
    }
    _permissions = _normalisePermissions(permissions);
    return _isPermissionBitOn(bit);
  }

  /// Returns `true` when no further modifications to the permission bits are
  /// allowed.
  bool get isReadOnly => _readOnly;

  /// Indicates whether any revision 3 specific permission bits are enabled.
  ///
  /// This mirrors PDFBox' `AccessPermission.hasAnyRevision3PermissionSet()` and
  /// is used when selecting the appropriate security handler revision.
  bool hasAnyRevision3PermissionSet() {
    return canFillInForm ||
        canExtractForAccessibility ||
        canAssembleDocument ||
        canPrintFaithful;
  }
}
