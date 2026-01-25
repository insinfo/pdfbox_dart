import '../../../cos/cos_base.dart';
import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_name.dart';
import 'pd_attribute_object.dart';

class PDDefaultAttributeObject extends PDAttributeObject {
  PDDefaultAttributeObject() : super();

  PDDefaultAttributeObject.fromDictionary(COSDictionary dictionary)
      : super.fromDictionary(dictionary);

  List<String> getAttributeNames() {
    final names = <String>[];
    for (final entry in cosObject.entries) {
      final key = entry.key;
      if (key != COSName.o) {
        names.add(key.name);
      }
    }
    return names;
  }

  COSBase? getAttributeValue(String attrName) {
    return cosObject.getDictionaryObject(COSName.getPDFName(attrName));
  }

  COSBase getAttributeValueOrDefault(String attrName, COSBase defaultValue) {
    return getAttributeValue(attrName) ?? defaultValue;
  }

  void setAttribute(String attrName, COSBase attrValue) {
    final oldValue = getAttributeValue(attrName);
    cosObject.setItem(COSName.getPDFName(attrName), attrValue);
    potentiallyNotifyChanged(oldValue, attrValue);
  }

  @override
  String toString() {
    final parts = <String>[];
    for (final name in getAttributeNames()) {
      parts.add('$name=${getAttributeValue(name)}');
    }
    return '${super.toString()}, attributes={${parts.join(', ')}}';
  }
}

