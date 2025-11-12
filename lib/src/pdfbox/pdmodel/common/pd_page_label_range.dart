import '../../cos/cos_base.dart' show COSObjectable;
import '../../cos/cos_dictionary.dart';
import '../../cos/cos_name.dart';

/// Represents the range information for page labels (PDF 32000-1:2008, table 159).
class PDPageLabelRange implements COSObjectable {
  PDPageLabelRange([COSDictionary? dictionary])
      : _dictionary = dictionary ?? COSDictionary();

  final COSDictionary _dictionary;

  static const String styleDecimal = 'D';
  static const String styleRomanUpper = 'R';
  static const String styleRomanLower = 'r';
  static const String styleLettersUpper = 'A';
  static const String styleLettersLower = 'a';

  @override
  COSDictionary get cosObject => _dictionary;

  String? get style => _dictionary.getNameAsString(COSName.s);

  set style(String? value) {
    if (value == null) {
      _dictionary.removeItem(COSName.s);
    } else {
      _dictionary.setName(COSName.s, value);
    }
  }

  int get start => _dictionary.getInt(COSName.st, 1) ?? 1;

  set start(int value) {
    if (value <= 0) {
      throw ArgumentError('start must be a positive integer');
    }
    _dictionary.setInt(COSName.st, value);
  }

  String? get prefix => _dictionary.getString(COSName.p);

  set prefix(String? value) {
    if (value == null) {
      _dictionary.removeItem(COSName.p);
    } else {
      _dictionary.setString(COSName.p, value);
    }
  }
}
