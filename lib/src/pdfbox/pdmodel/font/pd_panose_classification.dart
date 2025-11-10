/// Represents a 10-byte PANOSE classification.
class PDPanoseClassification {
  static const int length = 10;

  PDPanoseClassification(List<int> bytes)
      : assert(bytes.length == length,
            'Panose classification must contain $length bytes.'),
        _bytes = List<int>.unmodifiable(bytes);

  final List<int> _bytes;

  int get familyKind => _bytes[0];
  int get serifStyle => _bytes[1];
  int get weight => _bytes[2];
  int get proportion => _bytes[3];
  int get contrast => _bytes[4];
  int get strokeVariation => _bytes[5];
  int get armStyle => _bytes[6];
  int get letterform => _bytes[7];
  int get midline => _bytes[8];
  int get xHeight => _bytes[9];

  /// Returns the raw classification bytes.
  List<int> get bytes => _bytes;

  @override
  String toString() {
    return '{ FamilyKind = ${familyKind}, SerifStyle = ${serifStyle}, Weight = ${weight}, '
        'Proportion = ${proportion}, Contrast = ${contrast}, '
        'StrokeVariation = ${strokeVariation}, ArmStyle = ${armStyle}, '
        'Letterform = ${letterform}, Midline = ${midline}, XHeight = ${xHeight} }';
  }
}
