import 'dart:collection';
import 'dart:typed_data';

import 'cos_base.dart';
import 'cos_name.dart';
import 'cos_number.dart';
import 'cos_object.dart';
import 'cos_string.dart';

class COSArray extends COSBase with IterableMixin<COSBase> {
  COSArray([Iterable<COSBase>? initial]) {
    if (initial != null) {
      _items.addAll(initial);
    }
  }

  final List<COSBase> _items = <COSBase>[];

  void add(COSObjectable value) {
    _items.add(value.cosObject);
  }

  void addName(String name) {
    _items.add(COSName(name));
  }

  void addString(String value) {
    _items.add(COSString(value));
  }

  void addBytes(Uint8List value) {
    _items.add(COSString.fromBytes(value));
  }

  void addObject(COSBase value) {
    _items.add(value);
  }

  void insert(int index, COSObjectable value) {
    _items.insert(index, value.cosObject);
  }

  COSBase operator [](int index) => _items[index];

  COSBase getObject(int index) => _items[index];

  void operator []=(int index, COSObjectable value) {
    _items[index] = value.cosObject;
  }

  List<double> toDoubleList() {
    final result = <double>[];
    for (final element in _items) {
      final resolved = _resolve(element);
      if (resolved is COSNumber) {
        result.add(resolved.doubleValue);
      }
    }
    return result;
  }

  double? getDouble(int index) {
    if (index < 0 || index >= _items.length) {
      return null;
    }
    final value = _resolve(_items[index]);
    if (value is COSNumber) {
      return value.doubleValue;
    }
    return null;
  }

  int? getInt(int index, [int? defaultValue]) {
    if (index < 0 || index >= _items.length) {
      return defaultValue;
    }
    final value = _resolve(_items[index]);
    if (value is COSNumber) {
      return value.intValue;
    }
    return defaultValue;
  }

  COSBase _resolve(COSBase value) {
    if (value is COSObject) {
      return value.object;
    }
    return value;
  }

  void removeAt(int index) {
    _items.removeAt(index);
  }

  bool remove(COSBase value) => _items.remove(value);

  void clear() {
    _items.clear();
  }

  int get length => _items.length;

  bool get isEmpty => _items.isEmpty;

  bool get isNotEmpty => _items.isNotEmpty;

  List<COSBase> toList({bool growable = true}) =>
      List<COSBase>.from(_items, growable: growable);

  List<String> toCOSNameStringList() {
    final result = <String>[];
    for (final item in _items) {
      if (item is COSName) {
        result.add(item.name);
      } else if (item is COSString) {
        result.add(item.string);
      }
    }
    return result;
  }

  List<Uint8List> toUint8List() {
    final result = <Uint8List>[];
    for (final item in _items) {
      if (item is COSString) {
        result.add(item.bytes);
      }
    }
    return result;
  }

  static COSArray ofCOSNames(Iterable<String> names) {
    final array = COSArray();
    for (final name in names) {
      array.addName(name);
    }
    return array;
  }

  static COSArray ofCOSStrings(Iterable<String> strings) {
    final array = COSArray();
    for (final value in strings) {
      array.addString(value);
    }
    return array;
  }

  @override
  Iterator<COSBase> get iterator => _items.iterator;
}
