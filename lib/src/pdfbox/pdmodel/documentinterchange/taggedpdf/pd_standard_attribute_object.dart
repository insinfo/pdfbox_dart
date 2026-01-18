import '../../../cos/cos_array.dart';
import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_float.dart';
import '../../../cos/cos_name.dart';
import '../../../cos/cos_number.dart';
import '../../../cos/cos_string.dart';
import '../logicalstructure/pd_attribute_object.dart';
import 'pdf_four_colours.dart';
import '../../graphics/color/pd_gamma.dart';

abstract class PDStandardAttributeObject extends PDAttributeObject {
  static const double unspecified = -1.0;

  PDStandardAttributeObject() : super();

  PDStandardAttributeObject.fromDictionary(COSDictionary dictionary)
      : super.fromDictionary(dictionary);

  bool isSpecified(String name) =>
      cosObject.getDictionaryObject(_key(name)) != null;

  String? getString(String name) => cosObject.getString(_key(name));

  void setString(String name, String? value) {
    final key = _key(name);
    final oldBase = cosObject.getDictionaryObject(key);
    cosObject.setString(key, value);
    final newBase = cosObject.getDictionaryObject(key);
    potentiallyNotifyChanged(oldBase, newBase);
  }

  List<String>? getArrayOfString(String name) {
    final value = cosObject.getDictionaryObject(_key(name));
    if (value is COSArray) {
      final strings = <String>[];
      for (final item in value) {
        if (item is COSName) {
          strings.add(item.name);
        } else if (item is COSString) {
          strings.add(item.string);
        }
      }
      return strings;
    }
    return null;
  }

  void setArrayOfString(String name, List<String> values) {
    final key = _key(name);
    final oldBase = cosObject.getDictionaryObject(key);
    final array = COSArray();
    for (final value in values) {
      array.addString(value);
    }
    cosObject.setItem(key, array);
    final newBase = cosObject.getDictionaryObject(key);
    potentiallyNotifyChanged(oldBase, newBase);
  }

  String? getName(String name, [String? defaultValue]) =>
      cosObject.getNameAsString(_key(name), defaultValue);

  Object? getNameOrArrayOfName(String name, String defaultValue) {
    final value = cosObject.getDictionaryObject(_key(name));
    if (value is COSArray) {
      final names = <String>[];
      for (final item in value) {
        if (item is COSName) {
          names.add(item.name);
        }
      }
      return names;
    }
    if (value is COSName) {
      return value.name;
    }
    return defaultValue;
  }

  void setName(String name, String? value) {
    final key = _key(name);
    final oldBase = cosObject.getDictionaryObject(key);
    cosObject.setName(key, value);
    final newBase = cosObject.getDictionaryObject(key);
    potentiallyNotifyChanged(oldBase, newBase);
  }

  void setArrayOfName(String name, List<String> values) {
    final key = _key(name);
    final oldBase = cosObject.getDictionaryObject(key);
    final array = COSArray();
    for (final value in values) {
      array.addObject(COSName.getPDFName(value));
    }
    cosObject.setItem(key, array);
    final newBase = cosObject.getDictionaryObject(key);
    potentiallyNotifyChanged(oldBase, newBase);
  }

  Object getNumberOrName(String name, String defaultValue) {
    final value = cosObject.getDictionaryObject(_key(name));
    if (value is COSNumber) {
      return value.doubleValue;
    }
    if (value is COSName) {
      return value.name;
    }
    return defaultValue;
  }

  int getInteger(String name, int defaultValue) =>
      cosObject.getInt(_key(name), defaultValue) ?? defaultValue;

  void setInteger(String name, int value) {
    final key = _key(name);
    final oldBase = cosObject.getDictionaryObject(key);
    cosObject.setInt(key, value);
    final newBase = cosObject.getDictionaryObject(key);
    potentiallyNotifyChanged(oldBase, newBase);
  }

  double getNumber(String name, double defaultValue) =>
      cosObject.getFloat(_key(name), defaultValue) ?? defaultValue;

  double? getNumberOptional(String name) => cosObject.getFloat(_key(name));

  Object? getNumberOrArrayOfNumber(String name, double defaultValue) {
    final value = cosObject.getDictionaryObject(_key(name));
    if (value is COSArray) {
      final values = <double>[];
      for (final item in value) {
        if (item is COSNumber) {
          values.add(item.doubleValue);
        }
      }
      return values;
    }
    if (value is COSNumber) {
      return value.doubleValue;
    }
    if (defaultValue == unspecified) {
      return null;
    }
    return defaultValue;
  }

  void setNumber(String name, double value) {
    final key = _key(name);
    final oldBase = cosObject.getDictionaryObject(key);
    cosObject.setFloat(key, value);
    final newBase = cosObject.getDictionaryObject(key);
    potentiallyNotifyChanged(oldBase, newBase);
  }

  void setNumberInt(String name, int value) {
    final key = _key(name);
    final oldBase = cosObject.getDictionaryObject(key);
    cosObject.setInt(key, value);
    final newBase = cosObject.getDictionaryObject(key);
    potentiallyNotifyChanged(oldBase, newBase);
  }

  void setArrayOfNumber(String name, List<double> values) {
    final array = COSArray();
    for (final value in values) {
      array.addObject(COSFloat(value));
    }
    final key = _key(name);
    final oldBase = cosObject.getDictionaryObject(key);
    cosObject.setItem(key, array);
    final newBase = cosObject.getDictionaryObject(key);
    potentiallyNotifyChanged(oldBase, newBase);
  }

  PDGamma? getColor(String name) {
    final value = cosObject.getDictionaryObject(_key(name));
    if (value is COSArray) {
      return PDGamma.fromCOSArray(value);
    }
    return null;
  }

  Object? getColorOrFourColors(String name) {
    final value = cosObject.getDictionaryObject(_key(name));
    if (value is COSArray) {
      if (value.length == 3) {
        return PDGamma.fromCOSArray(value);
      }
      if (value.length == 4) {
        return PDFourColours.fromCOSArray(value);
      }
    }
    return null;
  }

  void setColor(String name, PDGamma? value) {
    final key = _key(name);
    final oldValue = cosObject.getDictionaryObject(key);
    cosObject.setItem(key, value);
    final newValue = value?.cosObject;
    potentiallyNotifyChanged(oldValue, newValue);
  }

  void setFourColors(String name, PDFourColours? value) {
    final key = _key(name);
    final oldValue = cosObject.getDictionaryObject(key);
    cosObject.setItem(key, value);
    final newValue = value?.cosObject;
    potentiallyNotifyChanged(oldValue, newValue);
  }

  COSName _key(String name) => COSName.getPDFName(name);
}
