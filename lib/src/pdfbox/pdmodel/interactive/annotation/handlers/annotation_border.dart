import '../../../../cos/cos_array.dart';
import '../../../../cos/cos_number.dart';
import '../pd_annotation.dart';
import '../pd_border_style_dictionary.dart';

/// Class to collect all sort of border info about annotations.
class AnnotationBorder {
  List<double>? dashArray;
  bool underline = false;
  double width = 0;

  /// Return border info. BorderStyle must be provided as parameter because
  /// method is not available in the base class.
  static AnnotationBorder getAnnotationBorder(
      PDAnnotation annotation, PDBorderStyleDictionary? borderStyle) {
    final ab = AnnotationBorder();
    if (borderStyle == null) {
      final border = annotation.border;
      if (border.length >= 3) {
        final base = border.getObject(2);
        if (base is COSNumber) {
          ab.width = base.doubleValue;
        }
      }
      if (border.length > 3) {
        final base3 = border.getObject(3);
        if (base3 is COSArray) {
          ab.dashArray = base3.toDoubleList();
        }
      }
    } else {
      ab.width = borderStyle.width;
      final style = borderStyle.style;
      if (style == PDBorderStyleDictionary.styleDashed) {
        final list = borderStyle.dashPattern;
        if (list != null) {
          ab.dashArray = list;
        }
      }
      if (style == PDBorderStyleDictionary.styleUnderline) {
        ab.underline = true;
      }
    }
    if (ab.dashArray != null) {
      bool allZero = true;
      for (final f in ab.dashArray!) {
        if (f != 0) {
          allZero = false;
          break;
        }
      }
      if (allZero) {
        ab.dashArray = null;
      }
    }
    return ab;
  }
}
