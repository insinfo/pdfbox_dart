import '../../../cos/cos_array.dart';
import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_float.dart';
import '../../../cos/cos_name.dart';
import '../../pd_document.dart';
import 'pd_annotation_markup.dart';

/// This is the class that represents a Caret annotation.
class PDAnnotationCaret extends PDAnnotationMarkup {
  /// The type of annotation.
  static const String subType = 'Caret';

  /// Constructor.
  PDAnnotationCaret([COSDictionary? field]) : super(field ?? COSDictionary()) {
    if (field == null) {
      dictionary.setName(COSName.subtype, subType);
    }
  }

  /// This will set the difference between the annotations "outer" rectangle defined by
  /// /Rect and boundaries of the underlying.
  void setRectDifferences(double differenceLeft,
      [double? differenceTop,
      double? differenceRight,
      double? differenceBottom]) {
    if (differenceTop == null &&
        differenceRight == null &&
        differenceBottom == null) {
      setRectDifferences(
          differenceLeft, differenceLeft, differenceLeft, differenceLeft);
      return;
    }
    final margins = COSArray();
    margins.add(COSFloat(differenceLeft));
    margins.add(COSFloat(differenceTop ?? 0));
    margins.add(COSFloat(differenceRight ?? 0));
    margins.add(COSFloat(differenceBottom ?? 0));
    dictionary.setItem(COSName.rd, margins);
  }

  /// This will get the margin between the annotations "outer" rectangle defined by
  /// /Rect and the boundaries of the underlying caret.
  List<double> getRectDifferences() {
    final margin = dictionary.getCOSArray(COSName.rd);
    return margin != null ? margin.toDoubleList() : <double>[];
  }

  // TODO: setCustomAppearanceHandler, constructAppearances
  void constructAppearances([PDDocument? document]) {
    // Implement PDCaretAppearanceHandler logic when handlers are ported
  }
}
