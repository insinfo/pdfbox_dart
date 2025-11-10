import 'pd_panose_classification.dart';

/// Represents the 12-byte Panose entry within a font descriptor.
class PDPanose {
  static const int length = 12;

  PDPanose(List<int> bytes)
      : assert(bytes.length == length,
            'Panose data must contain $length bytes.'),
        _bytes = List<int>.unmodifiable(bytes);

  final List<int> _bytes;

  /// The font family class and subclass from the OS/2 table.
  int get familyClass {
    final high = _bytes[0] & 0xff;
    final low = _bytes[1] & 0xff;
    return (high << 8) | low;
  }

  /// Ten-byte PANOSE classification sequence.
  PDPanoseClassification get panose =>
      PDPanoseClassification(_bytes.sublist(2, length));

  /// Returns the raw Panose bytes.
  List<int> get bytes => _bytes;
}
