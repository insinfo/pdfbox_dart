import '../../cos/cos_dictionary.dart';
import '../../cos/cos_name.dart';
import 'pd_true_type_font.dart';
import 'pdfont.dart';
import 'pd_type0_font.dart';
import 'pd_type1_font.dart';
import 'pd_type3_font.dart';

class PDFontFactory {
  static PDFont createFont(COSDictionary dictionary) {
    final subtype = dictionary.getCOSName(COSName.subtype);
    if (subtype == COSName.type0) {
      return PDType0Font(dictionary);
    } else if (subtype == COSName.type1) {
      return PDType1Font(dictionary);
    } else if (subtype == COSName.trueType) {
      return PDTrueTypeFont(dictionary);
    } else if (subtype == COSName.type3) {
      return PDType3Font(dictionary);
    } else if (subtype == COSName.cidFontType0) {
        // return PDCIDFontType0(dictionary);
        throw UnimplementedError('PDCIDFontType0 not implemented');
    } else if (subtype == COSName.cidFontType2) {
        // return PDCIDFontType2(dictionary);
        throw UnimplementedError('PDCIDFontType2 not implemented as standalone font');
    }
    
    // Fallback or error
    throw UnimplementedError('Font subtype $subtype not supported');
  }
}
