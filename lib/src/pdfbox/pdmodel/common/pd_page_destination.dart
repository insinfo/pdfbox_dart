import '../../cos/cos_array.dart';
import '../../cos/cos_base.dart';
import '../../cos/cos_float.dart';
import '../../cos/cos_integer.dart';
import '../../cos/cos_name.dart';
import '../../cos/cos_null.dart';
import '../../cos/cos_number.dart';
import '../../cos/cos_object.dart';
import '../../cos/cos_string.dart';
import 'pd_destination.dart';

/// Base class for explicit page destinations (ISO 32000-1, §12.3.2).
class PDPageDestination extends PDExplicitDestination {
  PDPageDestination(COSArray array) : super(array);

  /// Attempts to convert an explicit destination array into a typed page
  /// destination. Returns `null` when the array does not represent a page view.
  static PDPageDestination? fromArray(COSArray array) {
    if (array.isEmpty) {
      return null;
    }
    final typeName = _nameAt(array, 1);
    switch (typeName) {
      case 'XYZ':
        return PDPageXYZDestination(array);
      case 'Fit':
      case 'FitB':
        return PDPageFitDestination(array, typeName!);
      case 'FitH':
      case 'FitBH':
        return PDPageFitHorizontalDestination(array, typeName!);
      case 'FitV':
      case 'FitBV':
        return PDPageFitVerticalDestination(array, typeName!);
      case 'FitR':
        return PDPageFitRectangleDestination(array);
      default:
        return PDPageDestination(array);
    }
  }

  static String? _nameAt(COSArray array, int index) {
    if (index < 0 || index >= array.length) {
      return null;
    }
    final value = _resolve(array.getObject(index));
    if (value is COSName) {
      return value.name;
    }
    if (value is COSString) {
      return value.string;
    }
    return null;
  }

    static COSBase _resolve(COSBase base) =>
      base is COSObject ? base.object : base;

  COSBase? get page => array.length > 0 ? array.getObject(0) : null;

  set page(COSBase? value) {
    if (value == null) {
      if (array.length > 0) {
        array.removeAt(0);
      }
      return;
    }
    if (array.length == 0) {
      array.addObject(value);
    } else {
      array[0] = value;
    }
  }

  int? get pageNumber {
    final first = _resolve(array.length > 0 ? array.getObject(0) : COSNull.instance);
    if (first is COSNumber) {
      return first.intValue;
    }
    return null;
  }

  set pageNumber(int? value) {
    if (value == null) {
      page = null;
      return;
    }
    final cosInt = COSInteger(value);
    if (array.length == 0) {
      array.add(cosInt);
    } else {
      array[0] = cosInt;
    }
  }

  COSArray get array => super.array;

  COSBase _resolvedAt(int index) =>
      index < array.length ? _resolve(array.getObject(index)) : COSNull.instance;

  double? _getNumber(int index) {
    final value = _resolvedAt(index);
    if (value is COSNumber) {
      return value.doubleValue;
    }
    return null;
  }

  void _setNumber(int index, double? value) {
    if (value == null) {
      _setObject(index, COSNull.instance);
      return;
    }
    _setObject(index, COSFloat(value));
  }

  void _setObject(int index, COSBase value) {
    while (array.length <= index) {
      array.addObject(COSNull.instance);
    }
    array[index] = value;
  }
}

class PDPageXYZDestination extends PDPageDestination {
  PDPageXYZDestination(COSArray array) : super(array);

  double? get left => _getNumber(2);

  set left(double? value) => _setNumber(2, value);

  double? get top => _getNumber(3);

  set top(double? value) => _setNumber(3, value);

  double? get zoom => _getNumber(4);

  set zoom(double? value) => _setNumber(4, value);
}

class PDPageFitDestination extends PDPageDestination {
  PDPageFitDestination(COSArray array, this.fitType) : super(array);

  final String fitType;
}

class PDPageFitHorizontalDestination extends PDPageDestination {
  PDPageFitHorizontalDestination(COSArray array, this.fitType) : super(array);

  final String fitType;

  double? get top => _getNumber(2);

  set top(double? value) => _setNumber(2, value);
}

class PDPageFitVerticalDestination extends PDPageDestination {
  PDPageFitVerticalDestination(COSArray array, this.fitType) : super(array);

  final String fitType;

  double? get left => _getNumber(2);

  set left(double? value) => _setNumber(2, value);
}

class PDPageFitRectangleDestination extends PDPageDestination {
  PDPageFitRectangleDestination(COSArray array) : super(array);

  double? get left => _getNumber(2);

  set left(double? value) => _setNumber(2, value);

  double? get bottom => _getNumber(3);

  set bottom(double? value) => _setNumber(3, value);

  double? get right => _getNumber(4);

  set right(double? value) => _setNumber(4, value);

  double? get top => _getNumber(5);

  set top(double? value) => _setNumber(5, value);
}
