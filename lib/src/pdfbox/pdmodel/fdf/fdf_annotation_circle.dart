import 'package:pdfbox_dart/src/utils/xml/xml.dart';
import '../../cos/cos_array.dart';
import '../../cos/cos_dictionary.dart';
import '../../cos/cos_float.dart';
import '../../cos/cos_name.dart';
import '../common/pd_rectangle.dart';
import 'fdf_annotation.dart';

/// This represents a Circle FDF annotation.
class FDFAnnotationCircle extends FDFAnnotation {
  /// COS Model value for SubType entry.
  static const String SUBTYPE = 'Circle';

  /// Default constructor.
  FDFAnnotationCircle() : super() {
    annot.setItem(COSName.subtype, COSName.circle);
  }

  /// Constructor.
  ///
  /// [a] An existing FDF Annotation.
  FDFAnnotationCircle.fromDictionary(COSDictionary a) : super.fromDictionary(a);

  /// Constructor from XML Element.
  FDFAnnotationCircle.fromXml(XmlElement element) : super.fromXml(element) {
    annot.setItem(COSName.subtype, COSName.circle);
    String? intervalColor = element.getAttribute('interior-color');
    if (intervalColor != null) {
      if (intervalColor.isNotEmpty) {
        List<double> color = [];
        for (String s in intervalColor.split(',')) {
          color.add(double.parse(s));
        }
        setInteriorColor(color);
      }
    }
    String? fringe = element.getAttribute('fringe');
    if (fringe != null) {
      if (fringe.isNotEmpty) {
        List<double> fringes = [];
        for (String s in fringe.split(',')) {
          fringes.add(double.parse(s));
        }
        if (fringes.length == 4) {
          setFringe(PDRectangle(fringes[0], fringes[1], fringes[2], fringes[3]));
        }
      }
    }
  }

  /// This will set interior color of the drawn area.
  ///
  /// [color] The interior color of the circle.
  void setInteriorColor(List<double>? color) {
    if (color != null) {
      annot.setItem(COSName.ic, COSArray(color.map((e) => COSFloat(e)).toList()));
    } else {
      annot.removeItem(COSName.ic);
    }
  }

  /// This will retrieve the interior color of the drawn area.
  ///
  /// Returns object representing the color.
  List<double>? getInteriorColor() {
    COSArray? array = annot.getCOSArray(COSName.ic);
    if (array != null) {
      return array.toDoubleList();
    }
    return null;
  }

  /// This will set the fringe rectangle. Giving the difference between the annotations rectangle and where the drawing
  /// occurs. (To take account of any effects applied through the BE entry for example)
  ///
  /// [fringe] the fringe
  void setFringe(PDRectangle fringe) {
    annot.setItem(COSName.rd, fringe.toCOSArray());
  }

  /// This will get the fringe. Giving the difference between the annotations rectangle and where the drawing occurs.
  /// (To take account of any effects applied through the BE entry for example)
  ///
  /// Returns the rectangle difference
  PDRectangle? getFringe() {
    COSArray? rd = annot.getCOSArray(COSName.rd);
    return rd != null ? PDRectangle.fromCOSArray(rd) : null;
  }
}

