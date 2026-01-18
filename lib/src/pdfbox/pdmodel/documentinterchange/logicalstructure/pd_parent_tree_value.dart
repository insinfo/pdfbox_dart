import '../../../cos/cos_array.dart';
import '../../../cos/cos_base.dart';
import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_integer.dart';
import '../../../cos/cos_null.dart';
import '../../../cos/cos_object.dart';
import 'pd_structure_element.dart';

class PDParentTreeValue implements COSObjectable {
  final COSBase _base;

  PDParentTreeValue(this._base);

  PDParentTreeValue.fromArray(COSArray array) : _base = array;

  PDParentTreeValue.fromDictionary(COSDictionary dictionary) : _base = dictionary;

  bool get isArray => _base is COSArray;

  bool get isDictionary => _base is COSDictionary;

  COSArray? get array {
    final base = _base;
    return base is COSArray ? base : null;
  }

  COSDictionary? get dictionary {
    final base = _base;
    return base is COSDictionary ? base : null;
  }

  /// Returns the value at the given MCID when this parent tree value is an array.
  ///
  /// According to the spec, the index in the array equals the MCID. Entries can be
  /// structure element dictionaries or null.
  Object? getAtMcid(int mcid) {
    final arr = array;
    if (arr == null) {
      return null;
    }
    if (mcid < 0 || mcid >= arr.length) {
      return null;
    }
    final base = arr.getObject(mcid);
    final resolved = base is COSObject ? base.object : base;
    if (resolved is COSNull) {
      return null;
    }
    if (resolved is COSDictionary) {
      return PDStructureElement(resolved);
    }
    if (resolved is COSInteger) {
      return resolved.intValue;
    }
    return resolved;
  }

  @override
  COSBase get cosObject => _base;

  @override
  String toString() => _base.toString();
}
