import '../../cos/cos_array.dart';
import 'package:pdfbox_dart/src/utils/xml/xml.dart';
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
    annot.setItem(COSName.subtype, COSName.caret);
  }

  /// Constructor.
  ///
  /// [a] An existing FDF Annotation.
  FDFAnnotationCaret.fromDictionary(COSDictionary a) : super.fromDictionary(a);

  /// Constructor from XML Element.
  FDFAnnotationCaret.fromXml(XmlElement element) : super.fromXml(element) {
    annot.setItem(COSName.subtype, COSName.caret);
    String? symbol = element.getAttribute('symbol');
    if (symbol != null) {
      setSymbol(symbol);
    }
    String? fringe = element.getAttribute('fringe');
    if (fringe != null && fringe.isNotEmpty) {
      List<double> fringes = [];
      for (String s in fringe.split(',')) {
        fringes.add(double.parse(s));
      }
      if (fringes.length == 4) {
        setFringe(PDRectangle(fringes[0], fringes[1], fringes[2], fringes[3]));
      }
    }
  }

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

