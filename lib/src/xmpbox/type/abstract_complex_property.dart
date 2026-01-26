import 'abstract_field.dart';
import 'cardinality.dart';
import 'complex_property_container.dart';

/// Abstract class for complex XMP properties (arrays and structures).
/// Ported from org.apache.xmpbox.type.AbstractComplexProperty
abstract class AbstractComplexProperty extends AbstractField {
  final ComplexPropertyContainer _container = ComplexPropertyContainer();
  final Map<String, String> _namespaceToPrefix = {};

  AbstractComplexProperty(dynamic metadata, String? propertyName)
      : super(metadata, propertyName ?? '');

  void addNamespace(String namespace, String prefix) {
    _namespaceToPrefix[namespace] = prefix;
  }

  String? getNamespacePrefix(String namespace) {
    return _namespaceToPrefix[namespace];
  }

  Map<String, String> getAllNamespacesWithPrefix() {
    return _namespaceToPrefix;
  }

  /// Add a property to the current structure.
  void addProperty(AbstractField obj) {
    // Each property name in an XMP packet shall be unique within that packet
    // Multiple values are represented using an XMP array value
    // Thus delete existing elements of a property, except for arrays ("li")
    if (this is! ArrayProperty) {
      _container.removePropertiesByName(obj.propertyName);
    }
    _container.addProperty(obj);
  }

  /// Remove a property.
  void removeProperty(AbstractField property) {
    _container.removeProperty(property);
  }

  /// Return the container of this complex property.
  ComplexPropertyContainer getContainer() => _container;

  List<AbstractField> getAllProperties() {
    return _container.getAllProperties();
  }

  AbstractField? getProperty(String fieldName) {
    List<AbstractField>? list = _container.getPropertiesByLocalName(fieldName);
    if (list == null || list.isEmpty) {
      return null;
    }
    return list.first;
  }

  ArrayProperty? getArrayProperty(String fieldName) {
    List<AbstractField>? list = _container.getPropertiesByLocalName(fieldName);
    if (list == null || list.isEmpty) {
      return null;
    }
    return list.first as ArrayProperty?;
  }

  AbstractField? getFirstEquivalentProperty(String localName, Type type) {
    return _container.getFirstEquivalentProperty(localName, type);
  }
}

/// XMP array property base.
abstract class ArrayProperty extends AbstractComplexProperty {
  final Cardinality cardinality;

  ArrayProperty(dynamic metadata, String? propertyName, this.cardinality)
      : super(metadata, propertyName);

  void addItem(AbstractField item) => getContainer().addProperty(item);

  void removeItem(AbstractField item) => getContainer().removeProperty(item);

  List<AbstractField> getItems() => getContainer().getAllProperties();

  int get length => getContainer().getAllProperties().length;

  bool get isEmpty => getContainer().getAllProperties().isEmpty;
}

