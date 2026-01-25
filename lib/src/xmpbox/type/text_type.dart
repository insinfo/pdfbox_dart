import 'abstract_simple_property.dart';

/// Object representation of a Text XMP type.
/// Ported from org.apache.xmpbox.type.TextType
class TextType extends AbstractSimpleProperty {
  String? _textValue;

  /// Property Text type constructor.
  ///
  /// [metadata] The metadata to attach to this property
  /// [namespaceURI] the namespace URI to associate to this property
  /// [prefix] The prefix to set for this property
  /// [propertyName] The local Name of this property
  /// [value] The value to set
  TextType(
    dynamic metadata,
    String namespaceURI,
    String prefix,
    String propertyName,
    Object? value,
  ) : super(metadata, namespaceURI, prefix, propertyName, value);

  @override
  void setValue(Object? value) {
    if (value != null && value is! String) {
      throw ArgumentError("Value given is not allowed for the Text type: '$value'");
    }
    _textValue = value as String?;
  }

  @override
  String? get stringValue => _textValue;

  @override
  Object? get value => _textValue;
}

