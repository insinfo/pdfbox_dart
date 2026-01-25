import '../../cos/cos_array.dart';
import 'package:pdfbox_dart/src/utils/xml/xml.dart';
import '../../cos/cos_dictionary.dart';
import '../../cos/cos_float.dart';
import '../../cos/cos_name.dart';
import '../common/pd_rectangle.dart';
import 'fdf_annotation.dart';

/// This represents a FreeText FDF annotation.
class FDFAnnotationFreeText extends FDFAnnotation {
  /// COS Model value for SubType entry.
  static const String SUBTYPE = 'FreeText';

  /// Default constructor.
  FDFAnnotationFreeText() : super() {
    annot.setItem(COSName.subtype, COSName.freeText);
  }

  /// Constructor.
  ///
  /// [a] An existing FDF Annotation.
  FDFAnnotationFreeText.fromDictionary(COSDictionary a) : super.fromDictionary(a);

  /// Constructor from XML Element.
  FDFAnnotationFreeText.fromXml(XmlElement element) : super.fromXml(element) {
    annot.setItem(COSName.subtype, COSName.freeText);
    String? justification = element.getAttribute('justification');
    if (justification != null) {
      setJustification(justification);
    }
    String? rotation = element.getAttribute('rotation');
    if (rotation != null) {
        setRotation(int.parse(rotation));
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
    // line ending styles, color, etc could be parsed too
  }

  /// This will set the coordinates of the callout line.
  ///
  /// [callout] An array of four or six numbers specifying a callout line attached to the free
  /// text annotation. Six numbers [ x1 y1 x2 y2 x3 y3 ] represent the starting, knee point, and
  /// ending coordinates of the line in default user space, Four numbers [ x1 y1 x2 y2 ] represent
  /// The starting and ending coordinates of the line.
  void setCallout(List<double> callout) {
    annot.setItem(COSName.cl, COSArray(callout.map((e) => COSFloat(e)).toList()));
  }

  /// This will get the coordinates of the callout line.
  ///
  /// Returns An array of four or six numbers specifying a callout line attached to the free text
  /// annotation.
  List<double>? getCallout() {
    COSArray? array = annot.getCOSArray(COSName.cl);
    return array?.toDoubleList();
  }

  /// This will set the form of quadding (justification) of the annotation text.
  ///
  /// [justification] The quadding of the text.
  void setJustification(String justification) {
    int quadding = 0;
    if ("centered" == justification) {
      quadding = 1;
    } else if ("right" == justification) {
      quadding = 2;
    }
    annot.setInt(COSName.q, quadding);
  }

  /// This will get the form of quadding (justification) of the annotation text.
  ///
  /// Returns The quadding of the text.
  String getJustification() {
    return "${annot.getInt(COSName.q, 0)}";
  }

  /// This will set the clockwise rotation in degrees.
  ///
  /// [rotation] The number of degrees of clockwise rotation.
  void setRotation(int rotation) {
    annot.setInt(COSName.rotate, rotation);
  }

  /// This will get the clockwise rotation in degrees.
  ///
  /// Returns The number of degrees of clockwise rotation.
  String? getRotation() {
    return annot.getInt(COSName.rotate)?.toString();
  }

  /// Set the default appearance string.
  ///
  /// [appearance] The new default appearance string.
  void setDefaultAppearance(String appearance) {
    annot.setString(COSName.defaultAppearance, appearance);
  }

  /// Get the default appearance string.
  ///
  /// Returns The default appearance of the annotation.
  String? getDefaultAppearance() {
    return annot.getString(COSName.defaultAppearance);
  }

  /// Set the default style string.
  ///
  /// [style] The new default style string.
  void setDefaultStyle(String style) {
    annot.setString(COSName.ds, style);
  }

  /// Get the default style string.
  ///
  /// Returns The default style of the annotation.
  String? getDefaultStyle() {
    return annot.getString(COSName.ds);
  }

  /// This will set the fringe rectangle. Giving the difference between the annotations rectangle
  /// and where the drawing occurs. (To take account of any effects applied through the BE entry
  /// for example)
  ///
  /// [fringe] the fringe
  void setFringe(PDRectangle fringe) {
    annot.setItem(COSName.rd, fringe.toCOSArray());
  }

  /// This will get the fringe. Giving the difference between the annotations rectangle and where
  /// the drawing occurs. (To take account of any effects applied through the BE entry for example)
  ///
  /// Returns the rectangle difference
  PDRectangle? getFringe() {
    COSArray? rd = annot.getCOSArray(COSName.rd);
    return rd != null ? PDRectangle.fromCOSArray(rd) : null;
  }

  /// This will set the line ending style.
  ///
  /// [style] The new style.
  void setLineEndingStyle(String style) {
    annot.setName(COSName.le, style);
  }

  /// This will retrieve the line ending style.
  ///
  /// Returns The ending style for the start point.
  String? getLineEndingStyle() {
    return annot.getNameAsString(COSName.le);
  }
}

