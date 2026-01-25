import '../../cos/cos_array.dart';
import '../../cos/cos_dictionary.dart';
import '../../cos/cos_name.dart';
import '../common/pd_rectangle.dart';
import 'fdf_annotation.dart';

/// This represents a Caret FDF annotation.
class FDFAnnotationCaret extends FDFAnnotation {
  /// COS Model value for SubType entry.
  static const String SUBTYPE = 'Caret';

  /// Default constructor.
  FDFAnnotationCaret() : super() {
    annot.setName(COSName.subtype, SUBTYPE);
  }

  /// Constructor.
  ///
  /// [a] An existing FDF Annotation.
  FDFAnnotationCaret.fromDictionary(COSDictionary a) : super.fromDictionary(a);

  /// This will set the fringe rectangle. Giving the difference between the annotations rectangle and where the drawing
  /// occurs.
  ///
  /// [fringe] the fringe
  void setFringe(PDRectangle fringe) {
    annot.setItem(COSName.rd, fringe.toCOSArray());
  }

  /// This will retrieve the fringe. Giving the difference between the annotations rectangle and where the drawing
  /// occurs.
  ///
  /// Returns the rectangle difference
  PDRectangle? getFringe() {
    COSArray? rd = annot.getCOSArray(COSName.rd);
    return rd != null ? PDRectangle.fromCOSArray(rd) : null;
  }

  /// This will set the symbol that shall be associated with the caret.
  ///
  /// [symbol] the symbol
  void setSymbol(String symbol) {
    String newSymbol = "None";
    if ("paragraph" == symbol) {
      newSymbol = "P";
    }
    annot.setString(COSName.sy, newSymbol);
  }

  /// This will retrieve the symbol that shall be associated with the caret.
  ///
  /// Returns the symbol
  String? getSymbol() {
    return annot.getString(COSName.sy);
  }
}
