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
      if (_items.remove(key) != null) {
        markDirty();
      }
      return;
    }
    final newValue = value.cosObject;
    final current = _items[key];
    if (!identical(current, newValue)) {
      _items[key] = newValue;
      markDirty();
    }
  }

  void setBoolean(COSName key, bool? value) {
    if (value == null) {
      if (_items.remove(key) != null) {
        markDirty();
      }
      return;
    }
    final newValue = COSBoolean.valueOf(value);
    final current = _items[key];
    if (!identical(current, newValue)) {
      _items[key] = newValue;
      markDirty();
    }
  }

  void setInt(COSName key, int? value) {
    if (value == null) {
      if (_items.remove(key) != null) {
        markDirty();
      }
      return;
    }
    final newValue = COSInteger(value);
    final current = _items[key];
    if (!identical(current, newValue)) {
      _items[key] = newValue;
      markDirty();
    }
  }

  void setFloat(COSName key, double? value) {
    if (value == null) {
      if (_items.remove(key) != null) {
        markDirty();
      }
      return;
    }
    final newValue = COSFloat(value);
    final current = _items[key];
    if (current is COSFloat && current.value == newValue.value) {
      return;
    }
    _items[key] = newValue;
    markDirty();
  }

  void setName(COSName key, String? name) {
    if (name == null) {
      if (_items.remove(key) != null) {
        markDirty();
      }
      return;
    }
    final newValue = COSName(name);
    final current = _items[key];
    if (!identical(current, newValue)) {
      _items[key] = newValue;
      markDirty();
    }
  }

  void removeItem(COSName key) {
    if (_items.remove(key) != null) {
      markDirty();
    }
  }

  bool containsKey(COSName key) => _items.containsKey(key);

  COSBase? getItem(COSName key) => _items[key];

  Iterable<COSName> get keys => _items.keys;

  Iterable<COSBase> get values => _items.values;

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
    if (_items.isEmpty) {
      return;
    }
    _items.clear();
    markDirty();
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
      if (_items.remove(key) != null) {
        markDirty();
      }
    } else {
      final newValue = COSInteger(current);
      final existing = _items[key];
      if (!identical(existing, newValue)) {
        _items[key] = newValue;
        markDirty();
      }
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
    copy.markCleanDeep();
    return copy;
  }

  void addAll(COSDictionary other) {
      var mutated = false;
      for (final entry in other._items.entries) {
        final existing = _items[entry.key];
        if (!identical(existing, entry.value)) {
          _items[entry.key] = entry.value;
          mutated = true;
        }
      }
      if (mutated) {
        markDirty();
    }
  }

  void setNull(COSName key) {
      final current = _items[key];
      if (!identical(current, COSNull.instance)) {
        _items[key] = COSNull.instance;
        markDirty();
      }
  }

  void setString(COSName key, String? value) {
    if (value == null) {
        if (_items.remove(key) != null) {
          markDirty();
        }
      return;
    }
    final newValue = COSString(value);
    final current = _items[key];
    if (current is COSString && current == newValue) {
      return;
    }
    _items[key] = newValue;
    markDirty();
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
      if (_items.remove(key) != null) {
        markDirty();
      }
      return;
    }
    final formatted = PdfDate.format(value);
    if (formatted == null) {
      if (_items.remove(key) != null) {
        markDirty();
      }
      return;
    }
    final newValue = COSString(formatted);
    final current = _items[key];
    if (current is COSString && current == newValue) {
      return;
    }
    _items[key] = newValue;
    markDirty();
  }

  DateTime? getDate(COSName key) {
    final value = getDictionaryObject(key);
    if (value is COSString) {
      return PdfDate.parse(value.string);
    }
    return null;
  }

  @override
  void cleanDescendants(Set<COSBase> visited) {
    for (final value in _items.values) {
      final COSBase? resolved = value is COSObject ? value.object : value;
      resolved?.markCleanDeep(visited);
    }
  }

  @override
  bool hasDirtyDescendant(Set<COSBase> visited) {
    for (final value in _items.values) {
      final COSBase? resolved = value is COSObject ? value.object : value;
      if (resolved != null && resolved.needsUpdateDeep(visited)) {
        return true;
      }
    }
    return false;
  }
}
