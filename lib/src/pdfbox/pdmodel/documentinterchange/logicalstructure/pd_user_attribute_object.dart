import '../../../cos/cos_array.dart';
import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_name.dart';
import 'pd_attribute_object.dart';
import 'pd_user_property.dart';

class PDUserAttributeObject extends PDAttributeObject {
  static const String ownerUserProperties = 'UserProperties';

  PDUserAttributeObject() : super() {
    setOwner(ownerUserProperties);
  }

  PDUserAttributeObject.fromDictionary(COSDictionary dictionary)
      : super.fromDictionary(dictionary);

  List<PDUserProperty> getOwnerUserProperties() {
    final array = cosObject.getCOSArray(COSName.p);
    if (array == null) {
      return <PDUserProperty>[];
    }
    final properties = <PDUserProperty>[];
    for (final entry in array) {
      if (entry is COSDictionary) {
        properties.add(PDUserProperty.fromDictionary(entry, this));
      }
    }
    return properties;
  }

  void setUserProperties(List<PDUserProperty> userProperties) {
    final array = COSArray();
    for (final property in userProperties) {
      array.add(property);
    }
    cosObject.setItem(COSName.p, array);
  }

  void addUserProperty(PDUserProperty userProperty) {
    final array = cosObject.getCOSArray(COSName.p) ?? COSArray();
    if (array.isEmpty) {
      cosObject.setItem(COSName.p, array);
    }
    array.add(userProperty);
    notifyChanged();
  }

  void removeUserProperty(PDUserProperty? userProperty) {
    if (userProperty == null) {
      return;
    }
    final array = cosObject.getCOSArray(COSName.p);
    if (array == null) {
      return;
    }
    if (array.remove(userProperty.cosObject)) {
      notifyChanged();
    }
  }

  void userPropertyChanged(PDUserProperty userProperty) {}

  @override
  String toString() =>
      '${super.toString()}, userProperties=${getOwnerUserProperties()}';
}

