import 'abstract_simple_property.dart';

/// Object representation of an Integer XMP type.
/// Ported from org.apache.xmpbox.type.IntegerType
class IntegerType extends AbstractSimpleProperty {
  int _integerValue = 0;

  /// Property Integer type constructor.
  ///
  /// [metadata] The metadata to attach to this property
  /// [namespaceURI] the namespace URI to associate to this property
  /// [prefix] The prefix to set for this property
  /// [propertyName] The local Name of this property
  /// [value] The value to set
  IntegerType(
    dynamic metadata,
    String namespaceURI,
    String prefix,
    String propertyName,
    Object? value,
  ) : super(metadata, namespaceURI, prefix, propertyName, value);

  @override
  int get value => _integerValue;

  @override
  void setValue(Object? value) {
    if (value is int) {
      _integerValue = value;
    } else if (value is String) {
      _integerValue = int.parse(value);
    } else if (value != null) {
      throw ArgumentError("Value given is not allowed for the Integer type: $value");
    }
  }

  @override
  String get stringValue => _integerValue.toString();
}

