import 'dart:collection';

import '../../cos/cos_boolean.dart';
import '../../cos/cos_dictionary.dart';
import '../../cos/cos_float.dart';
import '../../cos/cos_integer.dart';
import '../../cos/cos_name.dart';
import '../../cos/cos_string.dart';
import '../../cos/cos_base.dart' show COSBase, COSObjectable;

/// Map implementation that keeps a [COSDictionary] in sync with its entries.
class COSDictionaryMap<K, V> extends MapBase<K, V> {
  COSDictionaryMap(this._actuals, this._dictionary);

  final Map<K, V> _actuals;
  final COSDictionary _dictionary;

  @override
  V? operator [](Object? key) => _actuals[key];

  @override
  void operator []=(K key, V value) {
    final cosName = _toCOSName(key);
    final cosValue = _toCOSValue(value);
    _dictionary.setItem(cosName, cosValue);
    _actuals[key] = value;
  }

  @override
  void clear() {
    _dictionary.clear();
    _actuals.clear();
  }

  @override
  Iterable<K> get keys => _actuals.keys;

  @override
  V? remove(Object? key) {
    if (key is! K) {
      return null;
    }
    final cosName = _toCOSName(key);
    _dictionary.removeItem(cosName);
    return _actuals.remove(key);
  }

  @override
  void addAll(Map<K, V> other) {
    throw UnsupportedError('putAll is not supported for COSDictionaryMap');
  }

  COSName _toCOSName(K key) {
    if (key is String) {
      return COSName.getPDFName(key);
    }
    throw ArgumentError('Dictionary keys must be strings, got ${key.runtimeType}');
  }

  COSBase _toCOSValue(V value) {
    if (value is COSObjectable) {
      return value.cosObject;
    }
    throw ArgumentError('Dictionary values must implement COSObjectable');
  }

  @override
  bool containsKey(Object? key) => _actuals.containsKey(key);

  @override
  bool containsValue(Object? value) => _actuals.containsValue(value);

  @override
  int get length => _actuals.length;

  /// Converts a map of [COSObjectable] entries into a [COSDictionary].
  static COSDictionary convert(Map<String, dynamic> map) {
    final dictionary = COSDictionary();
    map.forEach((key, value) {
      if (value is! COSObjectable) {
        throw ArgumentError('Value for key "$key" does not implement COSObjectable');
      }
      dictionary.setItem(COSName.getPDFName(key), value);
    });
    return dictionary;
  }

  /// Creates a [COSDictionaryMap] containing only primitive COS types.
  static COSDictionaryMap<String, Object?> convertBasicTypesToMap(
    COSDictionary dictionary,
  ) {
    final actual = <String, Object?>{};
    for (final key in dictionary.keys) {
      final cosName = key.name;
      final value = dictionary.getDictionaryObject(key);
      if (value is COSString) {
        actual[cosName] = value.string;
      } else if (value is COSInteger) {
        actual[cosName] = value.intValue;
      } else if (value is COSName) {
        actual[cosName] = value.name;
      } else if (value is COSFloat) {
        actual[cosName] = value.value;
      } else if (value is COSBoolean) {
        actual[cosName] = value.value;
      } else {
        throw ArgumentError('Cannot convert COS object of type ${value.runtimeType}');
      }
    }
    return COSDictionaryMap<String, Object?>(actual, dictionary);
  }
}
