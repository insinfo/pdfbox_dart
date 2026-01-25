import 'abstract_simple_property.dart';

/// Object representation of a Boolean XMP type.
/// Ported from org.apache.xmpbox.type.BooleanType
class BooleanType extends AbstractSimpleProperty {
  static const String TRUE = "True";
  static const String FALSE = "False";

  bool _booleanValue = false;

  /// Property Boolean type constructor.
  ///
  /// [metadata] The metadata to attach to this property
  /// [namespaceURI] the namespace URI to associate to this property
  /// [prefix] The prefix to set for this property
  /// [propertyName] The local Name of this property
  /// [value] The value to set
  BooleanType(
    dynamic metadata,
    String namespaceURI,
    String prefix,
    String propertyName,
    Object? value,
  ) : super(metadata, namespaceURI, prefix, propertyName, value);

  @override
  bool get value => _booleanValue;

  @override
  void setValue(Object? value) {
    if (value is bool) {
      _booleanValue = value;
    } else if (value is String) {
      String s = value.trim().toUpperCase();
      if (s == "TRUE") {
        _booleanValue = true;
      } else if (s == "FALSE") {
        _booleanValue = false;
      } else {
        throw ArgumentError("Not a valid boolean value: '$value'");
      }
    } else if (value != null) {
      throw ArgumentError("Value given is not allowed for the Boolean type.");
    }
  }

  @override
  String get stringValue => _booleanValue ? TRUE : FALSE;
}

