import 'dart:math';

/// Utility methods for encoding and decoding PDF date strings.
class PdfDate {
  PdfDate._();

  /// Formats [date] using the PDF date syntax `D:YYYYMMDDHHmmSSOHH'mm'`.
  static String? format(DateTime? date) {
    if (date == null) {
      return null;
    }

    final buffer = StringBuffer('D:')
      ..write(_pad(date.year, 4))
      ..write(_pad(date.month, 2))
      ..write(_pad(date.day, 2))
      ..write(_pad(date.hour, 2))
      ..write(_pad(date.minute, 2))
      ..write(_pad(date.second, 2));

    final offset = date.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final totalMinutes = offset.inMinutes.abs();
    final hours = min(totalMinutes ~/ 60, 23);
    final minutes = totalMinutes % 60;

    buffer
      ..write(sign)
      ..write(_pad(hours, 2))
      ..write("'")
      ..write(_pad(minutes, 2))
      ..write("'");

    return buffer.toString();
  }

  /// Parses a PDF date string and returns a [DateTime] in UTC.
  static DateTime? parse(String? value) {
    if (value == null) {
      return null;
    }

    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    var content = trimmed;
    if (content.startsWith('D:')) {
      content = content.substring(2);
    }

    final match = _pdfDatePattern.firstMatch(content);
    if (match == null) {
      // Fall back to ISO 8601 parsing if possible.
      return DateTime.tryParse(trimmed)?.toUtc();
    }

    int _parseGroup(int index, int defaultValue) {
      final group = match.group(index);
      if (group == null || group.isEmpty) {
        return defaultValue;
      }
      return int.parse(group);
    }

    final year = _parseGroup(1, 0);
    final month = _parseGroup(2, 1);
    final day = _parseGroup(3, 1);
    final hour = _parseGroup(4, 0);
    final minute = _parseGroup(5, 0);
    final second = _parseGroup(6, 0);

    final tz = match.group(7);
    var offsetMinutes = 0;
    if (tz != null && tz.toUpperCase() != 'Z') {
      final sign = tz.startsWith('-') ? -1 : 1;
      if (tz.length >= 7) {
        final hours = int.parse(tz.substring(1, 3));
        final minutes = int.parse(tz.substring(4, 6));
        offsetMinutes = sign * (hours * 60 + minutes);
      }
    }

    try {
      final utcDate = DateTime.utc(year, month, day, hour, minute, second);
      return utcDate.subtract(Duration(minutes: offsetMinutes));
    } on ArgumentError {
      return null;
    }
  }

  static String _pad(int value, int width) => value.abs().toString().padLeft(width, '0');

  static final RegExp _pdfDatePattern = RegExp(
    r"^(\d{4})(\d{2})?(\d{2})?(\d{2})?(\d{2})?(\d{2})?((?:[+\-]\d{2}'\d{2}')|Z)?$",
  );
}
