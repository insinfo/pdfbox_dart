import 'abstract_field.dart';

/// Abstract Class of a Simple XMP Property.
/// Ported from org.apache.xmpbox.type.AbstractSimpleProperty
abstract class AbstractSimpleProperty extends AbstractField {
  final String _namespace;
  final String _prefix;
  final Object? _rawValue;

  /// Property specific type constructor (namespaceURI is given).
  ///
  /// [metadata] The metadata to attach to this property
  /// [namespaceURI] the specified namespace URI associated to this property
  /// [prefix] The prefix to set for this property
  /// [propertyName] The local Name of this property
  /// [value] the value to give
  AbstractSimpleProperty(
    dynamic metadata,
    this._namespace,
    this._prefix,
    String propertyName,
    Object? value,
  ) : _rawValue = value,
      super(metadata, propertyName) {
    setValue(value);
  }

  /// Check and set new property value.
  void setValue(Object? value);

  /// Return the property value as a string.
  String? get stringValue;

  /// Return the property value.
  Object? get value;

  /// Return the properties raw value.
  ///
  /// The properties raw value is how it has been
  /// serialized into the XML. Allows to retrieve the
  /// low level date for validation purposes.
  Object? get rawValue => _rawValue;

  @override
  String get namespace => _namespace;

  @override
  String get prefix => _prefix;

  @override
  String toString() => '[${runtimeType.toString()}:$stringValue]';
}

