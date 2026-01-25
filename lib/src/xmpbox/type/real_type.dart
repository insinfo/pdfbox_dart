import 'abstract_simple_property.dart';

/// Object representation of a Real (floating point) XMP type.
/// Ported from org.apache.xmpbox.type.RealType
class RealType extends AbstractSimpleProperty {
  double _realValue = 0.0;

  /// Property Real type constructor.
  ///
  /// [metadata] The metadata to attach to this property
  /// [namespaceURI] the namespace URI to associate to this property
  /// [prefix] The prefix to set for this property
  /// [propertyName] The local Name of this property
  /// [value] The value to set
  RealType(
    dynamic metadata,
    String namespaceURI,
    String prefix,
    String propertyName,
    Object? value,
  ) : super(metadata, namespaceURI, prefix, propertyName, value);

  @override
  double get value => _realValue;

  @override
  void setValue(Object? value) {
    if (value is double) {
      _realValue = value;
    } else if (value is int) {
      _realValue = value.toDouble();
    } else if (value is String) {
      _realValue = double.parse(value);
    } else if (value != null) {
      throw ArgumentError("Value given is not allowed for the Real type: $value");
    }
  }

  @override
  String get stringValue => _realValue.toString();
}

