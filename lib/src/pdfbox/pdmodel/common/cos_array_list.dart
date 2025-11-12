import 'dart:collection';

import '../../cos/cos_array.dart';
import '../../cos/cos_boolean.dart';
import '../../cos/cos_dictionary.dart';
import '../../cos/cos_float.dart';
import '../../cos/cos_integer.dart';
import '../../cos/cos_name.dart';
import '../../cos/cos_null.dart';
import '../../cos/cos_string.dart';
import '../../cos/cos_base.dart' show COSBase, COSObjectable;

/// List implementation that mirrors its content into a backing [COSArray].
/// Useful for PDF structures that may switch between single objects and arrays.
class COSArrayList<E> extends ListBase<E> {
  COSArrayList()
      : array = COSArray(),
        actual = <E>[];

  COSArrayList.withArray(List<E> actualList, COSArray cosArray)
      : array = cosArray,
        actual = actualList,
        _isFiltered = actualList.length != cosArray.length;

  COSArrayList.deferred(this._parentDict, this._dictKey)
      : array = COSArray(),
        actual = <E>[];

  COSArrayList.single(
    E actualObject,
    COSBase item,
    COSDictionary parent,
    COSName key,
  )   : array = COSArray(),
        actual = <E>[actualObject],
        _parentDict = parent,
        _dictKey = key {
    array.addObject(item);
  }

  final COSArray array;
  final List<E> actual;
  bool _isFiltered = false;
  COSDictionary? _parentDict;
  COSName? _dictKey;

  bool get isFiltered => _isFiltered;

  @override
  int get length => actual.length;

  @override
  set length(int value) =>
      throw UnsupportedError('Setting length directly is not supported');

  @override
  E operator [](int index) => actual[index];

  @override
  void operator []=(int index, E value) {
    _ensureWritable('set');
    final cosValue = _toCOSValue(value);
    if (_parentDict != null && index == 0 && actual.isNotEmpty) {
      _parentDict!.setItem(_dictKey!, cosValue);
      _parentDict = null;
    }
    array[index] = cosValue;
    actual[index] = value;
  }

  @override
  void add(E value) {
    _ensureWritable('add');
    _ensureArrayAttached();
    actual.add(value);
    array.add(_toCOSValue(value));
  }

  @override
  void insert(int index, E value) {
    _ensureWritable('insert');
    _ensureArrayAttached();
    actual.insert(index, value);
    array.insert(index, _toCOSValue(value));
  }

  @override
  void addAll(Iterable<E> iterable) {
    final values = iterable.toList();
    if (values.isEmpty) {
      return;
    }
    _ensureWritable('addAll');
    _ensureArrayAttached();
    actual.addAll(values);
    for (final value in values) {
      array.add(_toCOSValue(value));
    }
  }

  @override
  void insertAll(int index, Iterable<E> iterable) {
    final values = iterable.toList();
    if (values.isEmpty) {
      return;
    }
    _ensureWritable('insertAll');
    _ensureArrayAttached();
    actual.insertAll(index, values);
    var offset = index;
    for (final value in values) {
      array.insert(offset, _toCOSValue(value));
      offset += 1;
    }
  }

  @override
  bool remove(Object? value) {
    _ensureWritable('remove');
    if (value is! E) {
      return false;
    }
    final index = actual.indexOf(value);
    if (index < 0) {
      return false;
    }
    removeAt(index);
    return true;
  }

  @override
  E removeAt(int index) {
    _ensureWritable('removeAt');
    array.removeAt(index);
    return actual.removeAt(index);
  }

  @override
  void clear() {
    _ensureWritable('clear');
    if (_parentDict != null) {
      _parentDict!.setItem(_dictKey!, null);
    }
    actual.clear();
    array.clear();
  }

  COSArray toCOSArray() => array;

  void _ensureWritable(String operation) {
    if (_isFiltered) {
      throw UnsupportedError('$operation on a filtered list is not permitted');
    }
  }

  void _ensureArrayAttached() {
    if (_parentDict != null) {
      _parentDict!.setItem(_dictKey!, array);
      _parentDict = null;
    }
  }

  COSBase _toCOSValue(E value) {
    if (value is String) {
      return COSString(value);
    }
    if (value is COSObjectable) {
      return value.cosObject;
    }
    throw ArgumentError('Unsupported element type: ${value.runtimeType}');
  }

  static COSArray? converterToCOSArray(List<dynamic>? list) {
    if (list == null) {
      return null;
    }
    if (list is COSArrayList) {
      return list.array;
    }
    final array = COSArray();
    for (final element in list) {
      if (element is String) {
        array.add(COSString(element));
      } else if (element is int) {
        array.add(COSInteger(element));
      } else if (element is double) {
        array.add(COSFloat(element));
      } else if (element is bool) {
        array.add(COSBoolean.valueOf(element));
      } else if (element is COSObjectable) {
        array.add(element);
      } else if (element == null) {
        array.add(COSNull.instance);
      } else {
        throw ArgumentError(
          "Cannot convert element of type ${element.runtimeType} to COSBase",
        );
      }
    }
    return array;
  }
}
