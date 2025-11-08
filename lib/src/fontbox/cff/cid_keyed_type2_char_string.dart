import '../type1/type1_char_string_reader.dart';
import 'type2_char_string.dart';

/// CID-keyed specialization of [Type2CharString].
class CIDKeyedType2CharString extends Type2CharString {
  CIDKeyedType2CharString(
    Type1CharStringReader font,
    String fontName,
    this.cid,
    int gid,
    List<Object> sequence,
    int defaultWidthX,
    int nominalWidthX,
  ) : super(
          font,
          fontName,
          cid.toRadixString(16).padLeft(4, '0'),
          gid,
          sequence,
          defaultWidthX,
          nominalWidthX,
        );

  final int cid;

  /// Returns the character identifier represented by this charstring.
  int get cidValue => cid;
}
