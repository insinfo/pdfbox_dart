import '../../cos/cos_array.dart';
import '../../cos/cos_base.dart';
import '../../cos/cos_dictionary.dart';
import '../../cos/cos_name.dart';
import '../../cos/cos_object.dart';
import '../../cos/cos_string.dart';
import 'pd_destination_or_action.dart';
import 'pd_page_destination.dart';

/// Base type for destinations used in actions and name trees.
abstract class PDDestination implements PDDestinationOrAction {
  const PDDestination();

  @override
  COSBase get cosObject;

  /// Factory that chooses an appropriate destination wrapper for the
  /// underlying COS representation.
  static PDDestination? fromCOS(COSBase? base) {
    if (base == null) {
      return null;
    }
    if (base is COSObject) {
      return fromCOS(base.object);
    }
    if (base is COSName || base is COSString) {
      return PDNamedDestination(base);
    }
    if (base is COSArray) {
      final pageDestination = PDPageDestination.fromArray(base);
      if (pageDestination != null) {
        return pageDestination;
      }
      return PDExplicitDestination(base);
    }
    if (base is COSDictionary) {
      final array = base.getCOSArray(COSName.d);
      if (array != null) {
        final pageDestination = PDPageDestination.fromArray(array);
        return pageDestination ?? PDExplicitDestination(array);
      }
      final name = base.getDictionaryObject(COSName.d);
      if (name is COSBase) {
        return fromCOS(name);
      }
    }
    return null;
  }
}

/// Destination that refers to an explicit array describing the view.
class PDExplicitDestination extends PDDestination {
  PDExplicitDestination(this._array);

  final COSArray _array;

  COSArray get array => _array;

  /// Returns the explicit array length.
  int get length => _array.length;

  @override
  COSArray get cosObject => _array;
}

/// Destination that resolves to a named entry (COSString or COSName).
class PDNamedDestination extends PDDestination {
  PDNamedDestination(this._base)
      : assert(_base is COSName || _base is COSString,
            'Named destinations must be COSName or COSString');

  final COSBase _base;

  String get name {
    final local = _base;
    if (local is COSName) {
      return local.name;
    }
    return (local as COSString).string;
  }

  @override
  COSBase get cosObject => _base;
}
