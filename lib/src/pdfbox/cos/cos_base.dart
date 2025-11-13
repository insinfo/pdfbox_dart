import 'dart:collection';

import 'cos_object_key.dart';

abstract class COSVisitor {
  void visit(COSBase object);
}

abstract class COSObjectable {
  COSBase get cosObject;
}


abstract class COSBase implements COSObjectable {
  bool _isDirect = false;
  COSObjectKey? _key;
  bool _needsUpdate = false;

  @override
  COSBase get cosObject => this;

  bool get isDirect => _isDirect;

  set isDirect(bool value) => _isDirect = value;

  COSObjectKey? get key => _key;

  set key(COSObjectKey? value) => _key = value;

  void accept(COSVisitor visitor) => visitor.visit(this);

  bool get needsUpdate => _needsUpdate;

  set needsUpdate(bool value) => _needsUpdate = value;

  /// Marks this COS object as modified.
  void markDirty() => _needsUpdate = true;

  /// Clears the modified flag on this object only.
  void markClean() => _needsUpdate = false;

  /// Clears the modified flag on this object and all reachable descendants.
  void markCleanDeep([Set<COSBase>? visited]) {
    final tracker = visited ?? LinkedHashSet<COSBase>.identity();
    if (!tracker.add(this)) {
      return;
    }
    _needsUpdate = false;
    cleanDescendants(tracker);
  }

  /// Returns `true` when this object or any reachable descendant is dirty.
  bool needsUpdateDeep([Set<COSBase>? visited]) {
    final tracker = visited ?? LinkedHashSet<COSBase>.identity();
    if (!tracker.add(this)) {
      return false;
    }
    if (_needsUpdate) {
      return true;
    }
    return hasDirtyDescendant(tracker);
  }

  /// Allows subclasses to clear the modified flag on nested objects.
  void cleanDescendants(Set<COSBase> visited) {}

  /// Allows subclasses to detect dirty nested objects.
  bool hasDirtyDescendant(Set<COSBase> visited) => false;
}
