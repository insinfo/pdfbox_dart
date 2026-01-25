/// Simple representation of an XMP attribute.
/// Ported from org.apache.xmpbox.type.Attribute
class Attribute {
  String? _nsURI;
  String _name;
  String _value;

  /// Constructor of a new Attribute.
  ///
  /// [nsURI] namespaceURI of this attribute (could be null)
  /// [localName] localName of this attribute
  /// [value] value given to this attribute
  Attribute(this._nsURI, this._name, this._value);

  /// Get the localName of this attribute.
  String get name => _name;

  /// Set the localName of this attribute.
  set name(String value) => _name = value;

  /// Get the namespace URI of this attribute.
  String? get namespace => _nsURI;

  /// Set the namespace URI of this attribute.
  set nsURI(String? value) => _nsURI = value;

  /// Get value of this attribute.
  String get value => _value;

  /// Set value of this attribute.
  set value(String val) => _value = val;

  @override
  String toString() => '[attr:{$_nsURI}$_name=$_value]';
}

