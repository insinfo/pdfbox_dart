import 'abstract_field.dart';

/// Container for complex properties (arrays and structures).
/// Ported from org.apache.xmpbox.type.ComplexPropertyContainer
class ComplexPropertyContainer {
  final List<AbstractField> _properties = [];

  ComplexPropertyContainer();

  /// Give the first property found in this container with type and localname expected.
  AbstractField? getFirstEquivalentProperty(String localName, Type type) {
    List<AbstractField>? list = getPropertiesByLocalName(localName);
    if (list != null) {
      for (AbstractField abstractField in list) {
        if (abstractField.runtimeType == type) {
          return abstractField;
        }
      }
    }
    return null;
  }

  /// Add a property to the current structure.
  void addProperty(AbstractField obj) {
    removeProperty(obj);
    _properties.add(obj);
  }

  /// Return all children associated to this property.
  List<AbstractField> getAllProperties() {
    return _properties;
  }

  /// Return all properties with this specified localName.
  List<AbstractField>? getPropertiesByLocalName(String localName) {
    List<AbstractField> list = _properties
        .where((field) => field.propertyName == localName)
        .toList();
    return list.isEmpty ? null : list;
  }

  /// Check if two properties are equal.
  bool isSameProperty(AbstractField prop1, AbstractField prop2) {
    if (prop1.runtimeType == prop2.runtimeType) {
      String pn1 = prop1.propertyName;
      String pn2 = prop2.propertyName;
      if (pn1 == pn2) {
        return prop1 == prop2;
      }
    }
    return false;
  }

  /// Check if a XMPFieldObject is in the complex property.
  bool containsProperty(AbstractField property) {
    for (AbstractField tmp in _properties) {
      if (isSameProperty(tmp, property)) {
        return true;
      }
    }
    return false;
  }

  /// Remove a property.
  void removeProperty(AbstractField property) {
    _properties.remove(property);
  }

  /// Remove all properties with a specified LocalName.
  void removePropertiesByName(String localName) {
    if (_properties.isEmpty) {
      return;
    }
    List<AbstractField>? propList = getPropertiesByLocalName(localName);
    if (propList == null) {
      return;
    }
    for (var prop in propList) {
      _properties.remove(prop);
    }
  }
}

