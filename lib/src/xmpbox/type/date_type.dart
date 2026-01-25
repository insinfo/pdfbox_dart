import 'abstract_simple_property.dart';

/// Object representation of a Date XMP type.
/// Ported from org.apache.xmpbox.type.DateType
class DateType extends AbstractSimpleProperty {
  DateTime? _dateValue;

  /// Property Date type constructor.
  ///
  /// [metadata] The metadata to attach to this property
  /// [namespaceURI] the namespace URI to associate to this property
  /// [prefix] The prefix to set for this property
  /// [propertyName] The local Name of this property
  /// [value] The value to set
  DateType(
    dynamic metadata,
    String namespaceURI,
    String prefix,
    String propertyName,
    Object? value,
  ) : super(metadata, namespaceURI, prefix, propertyName, value);

  @override
  DateTime? get value => _dateValue;

  @override
  void setValue(Object? value) {
    if (value == null) {
      _dateValue = null;
    } else if (value is DateTime) {
      _dateValue = value;
    } else if (value is String) {
      _dateValue = _parseISO8601(value);
    } else {
      throw ArgumentError("Value given is not allowed for the Date type: ${value.runtimeType}, value: $value");
    }
  }

  @override
  String? get stringValue {
    if (_dateValue == null) {
      return null;
    }
    return _toISO8601(_dateValue!);
  }

  /// Parse ISO 8601 date string.
  /// TODO: Full ISO 8601 parsing with timezone support
  static DateTime? _parseISO8601(String value) {
    try {
      return DateTime.parse(value);
    } catch (e) {
      // Try alternative formats
      // TODO: Support more XMP date formats
      return null;
    }
  }

  /// Convert DateTime to ISO 8601 string.
  static String _toISO8601(DateTime date) {
    return date.toIso8601String();
  }
}

