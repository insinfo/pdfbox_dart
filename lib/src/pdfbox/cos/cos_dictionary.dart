import 'dart:collection';

import 'cos_array.dart';
import 'cos_base.dart';
import 'cos_boolean.dart';
import 'cos_float.dart';
import 'cos_integer.dart';
import 'cos_name.dart';
import 'cos_null.dart';
import 'cos_number.dart';
import 'cos_object.dart';
import 'cos_string.dart';
import '../util/pdf_date.dart';

class COSDictionary extends COSBase {
  final Map<COSName, COSBase> _items = LinkedHashMap<COSName, COSBase>();

  COSBase? operator [](COSName key) => _items[key];

  void operator []=(COSName key, COSObjectable? value) {
    setItem(key, value);
  }

  void setItem(COSName key, COSObjectable? value) {
    if (value == null) {
      _items.remove(key);
      return;
    }
    _items[key] = value.cosObject;
  }

  void setBoolean(COSName key, bool? value) {
    if (value == null) {
      _items.remove(key);
      return;
    }
    _items[key] = COSBoolean.valueOf(value);
  }

  void setInt(COSName key, int? value) {
    if (value == null) {
      _items.remove(key);
      return;
    }
    _items[key] = COSInteger(value);
  }

  void setFloat(COSName key, double? value) {
    if (value == null) {
      _items.remove(key);
      return;
    }
    _items[key] = COSFloat(value);
  }

  void setName(COSName key, String? name) {
    if (name == null) {
      _items.remove(key);
      return;
    }
    _items[key] = COSName(name);
  }

  void removeItem(COSName key) {
    _items.remove(key);
  }

  bool containsKey(COSName key) => _items.containsKey(key);

  COSBase? getItem(COSName key) => _items[key];

  COSBase? getDictionaryObject(COSName key, [COSName? alternate]) {
    final value = _items[key] ?? (alternate != null ? _items[alternate] : null);
    if (value is COSObject) {
      return value.object;
    }
    return value;
  }

  COSBase? getDictionaryObjectAny(Iterable<COSName> keys) {
    for (final key in keys) {
      final value = getDictionaryObject(key);
      if (value != null) {
        return value;
      }
    }
    return null;
  }

  COSArray? getCOSArray(COSName key) {
    final value = getDictionaryObject(key);
    return value is COSArray ? value : null;
  }

  COSDictionary? getCOSDictionary(COSName key) {
    final value = getDictionaryObject(key);
    return value is COSDictionary ? value : null;
  }

  COSName? getCOSName(COSName key) {
    final value = getDictionaryObject(key);
    return value is COSName ? value : null;
  }

  int? getInt(COSName key, [int? defaultValue]) {
    final value = getDictionaryObject(key);
    if (value is COSNumber) {
      return value.intValue;
    }
    if (defaultValue != null) {
      return defaultValue;
    }
    return null;
  }

  double? getFloat(COSName key, [double? defaultValue]) {
    final value = getDictionaryObject(key);
    if (value is COSNumber) {
      return value.doubleValue;
    }
    return defaultValue;
  }

  bool? getBoolean(COSName key, [bool? defaultValue]) {
    final value = getDictionaryObject(key);
    if (value is COSBoolean) {
      return value.value;
    }
    if (defaultValue != null) {
      return defaultValue;
    }
    return null;
  }

  String? getNameAsString(COSName key, [String? defaultValue]) {
    final value = getDictionaryObject(key);
    if (value is COSName) {
      return value.name;
    }
    if (defaultValue != null) {
      return defaultValue;
    }
    return null;
  }

  Iterable<MapEntry<COSName, COSBase>> get entries => _items.entries;

  bool get isEmpty => _items.isEmpty;

  bool get isNotEmpty => _items.isNotEmpty;

  void clear() {
    _items.clear();
  }

  bool getFlag(COSName key, int flag) {
    final current = getInt(key) ?? 0;
    return (current & flag) == flag && flag != 0;
  }

  void setFlag(COSName key, int flag, bool value) {
    if (flag == 0) {
      return;
    }
    var current = getInt(key) ?? 0;
    if (value) {
      current |= flag;
    } else {
      current &= ~flag;
    }
    if (current == 0) {
      _items.remove(key);
    } else {
      _items[key] = COSInteger(current);
    }
  }

  COSDictionary clone() {
    final copy = COSDictionary();
    for (final entry in _items.entries) {
      final value = entry.value;
      if (value is COSDictionary) {
        copy._items[entry.key] = value.clone();
      } else if (value is COSArray) {
        final arrayCopy = COSArray();
        for (final item in value) {
          arrayCopy.addObject(item);
        }
        copy._items[entry.key] = arrayCopy;
      } else {
        copy._items[entry.key] = value;
      }
    }
    return copy;
  }

  void addAll(COSDictionary other) {
    for (final entry in other._items.entries) {
      _items[entry.key] = entry.value;
    }
  }

  void setNull(COSName key) {
    _items[key] = COSNull.instance;
  }

  void setString(COSName key, String? value) {
    if (value == null) {
      _items.remove(key);
      return;
    }
    _items[key] = COSString(value);
  }

  String? getString(COSName key, [String? defaultValue]) {
    final value = getDictionaryObject(key);
    if (value is COSString) {
      return value.string;
    }
    if (value is COSName) {
      return value.name;
    }
    return defaultValue;
  }

  void setDate(COSName key, DateTime? value) {
    if (value == null) {
      _items.remove(key);
      return;
    }
    final formatted = PdfDate.format(value);
    if (formatted == null) {
      _items.remove(key);
      return;
    }
    _items[key] = COSString(formatted);
  }

  DateTime? getDate(COSName key) {
    final value = getDictionaryObject(key);
    if (value is COSString) {
      return PdfDate.parse(value.string);
    }
    return null;
  }
}
