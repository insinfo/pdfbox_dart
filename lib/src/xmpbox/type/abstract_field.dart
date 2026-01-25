import 'attribute.dart';

/// Abstract Object representation of a XMP 'field' (-> Properties and specific Schemas).
/// Ported from org.apache.xmpbox.type.AbstractField
abstract class AbstractField {
  // Reference to XMPMetadata is dynamic to avoid circular dependency.
  // TODO: Properly type this when XMPMetadata is implemented.
  final dynamic metadata;
  
  String _propertyName;
  final Map<String, Attribute> _attributes = {};

  /// Constructor of a XMP Field.
  ///
  /// [metadata] The metadata to attach to this field
  /// [propertyName] the local name to set for this field
  AbstractField(this.metadata, this._propertyName);

  /// Get the propertyName (or localName).
  String get propertyName => _propertyName;

  /// Set the propertyName.
  set propertyName(String value) => _propertyName = value;

  /// Set a new attribute for this entity.
  void setAttribute(Attribute value) {
    _attributes[value.name] = value;
  }

  /// Check if an attribute is declared for this entity.
  bool containsAttribute(String qualifiedName) {
    return _attributes.containsKey(qualifiedName);
  }

  /// Get an attribute with its name in this entity.
  Attribute? getAttribute(String qualifiedName) {
    return _attributes[qualifiedName];
  }

  /// Get attributes list defined for this entity.
  List<Attribute> getAllAttributes() {
    return List.from(_attributes.values);
  }

  /// Remove an attribute of this entity.
  void removeAttribute(String qualifiedName) {
    _attributes.remove(qualifiedName);
  }

  /// Get the namespace URI of this entity.
  String get namespace;

  /// Get the prefix of this entity.
  String get prefix;
}

