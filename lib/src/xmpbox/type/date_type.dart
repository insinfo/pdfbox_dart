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

  /// Parse ISO 8601 date string with support for partial dates and timezones.
  static DateTime? _parseISO8601(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;

    final regex = RegExp(
      r'^(\d{4})'
      r'(?:-(\d{2})'
      r'(?:-(\d{2})'
      r'(?:[Tt\s](\d{2})'
      r'(?::(\d{2})'
      r'(?::(\d{2})'
      r'(?:\.(\d{1,9}))?'
      r')?'
      r')?'
      r'(Z|[+-]\d{2}:?\d{2})?'
      r')?'
      r')?'
      r')?'
      r'$',
    );

    final match = regex.firstMatch(trimmed);
    if (match == null) {
      try {
        return DateTime.parse(trimmed);
      } catch (_) {
        return null;
      }
    }

    int year = int.parse(match.group(1)!);
    int month = match.group(2) != null ? int.parse(match.group(2)!) : 1;
    int day = match.group(3) != null ? int.parse(match.group(3)!) : 1;
    int hour = match.group(4) != null ? int.parse(match.group(4)!) : 0;
    int minute = match.group(5) != null ? int.parse(match.group(5)!) : 0;
    int second = match.group(6) != null ? int.parse(match.group(6)!) : 0;
    int microsecond = 0;

    final fraction = match.group(7);
    if (fraction != null && fraction.isNotEmpty) {
      final padded = fraction.padRight(6, '0');
      microsecond = int.parse(padded.substring(0, 6));
    }

    final timezone = match.group(8);
    if (timezone == null || timezone.isEmpty) {
      return DateTime(year, month, day, hour, minute, second, 0, microsecond);
    }

    if (timezone == 'Z') {
      return DateTime.utc(year, month, day, hour, minute, second, 0, microsecond);
    }

    final tz = timezone.replaceAll(':', '');
    final sign = tz.startsWith('-') ? -1 : 1;
    final tzHours = int.parse(tz.substring(1, 3));
    final tzMinutes = int.parse(tz.substring(3, 5));
    final offset = Duration(
      hours: tzHours * sign,
      minutes: tzMinutes * sign,
    );

    final utc = DateTime.utc(year, month, day, hour, minute, second, 0, microsecond);
    return utc.subtract(offset);
  }

  /// Convert DateTime to ISO 8601 string.
  static String _toISO8601(DateTime date) {
    return date.toIso8601String();
  }
}

