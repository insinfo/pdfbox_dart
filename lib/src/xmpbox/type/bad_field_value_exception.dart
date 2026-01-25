/// Exception for bad field values in XMP.
/// Ported from org.apache.xmpbox.type.BadFieldValueException
class BadFieldValueException implements Exception {
  final String message;

  BadFieldValueException(this.message);

  @override
  String toString() => 'BadFieldValueException: $message';
}

