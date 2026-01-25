import 'package:pdfbox_dart/src/utils/xml/xml.dart';
import '../../cos/cos_array.dart';
import '../../cos/cos_dictionary.dart';
import '../../cos/cos_float.dart';
import '../../cos/cos_name.dart';
import 'fdf_annotation.dart';

/// This represents a Polygon FDF annotation.
class FDFAnnotationPolygon extends FDFAnnotation {
  /// COS Model value for SubType entry.
  static const String SUBTYPE = 'Polygon';

  /// Default constructor.
  FDFAnnotationPolygon() : super() {
    annot.setItem(COSName.subtype, COSName.polygon);
  }

  /// Constructor.
  ///
  /// [a] An existing FDF Annotation.
  FDFAnnotationPolygon.fromDictionary(COSDictionary a) : super.fromDictionary(a);

  /// Constructor from XML Element.
  FDFAnnotationPolygon.fromXml(XmlElement element) : super.fromXml(element) {
    annot.setItem(COSName.subtype, COSName.polygon);
    String? vertices = element.getAttribute('vertices');
    if (vertices != null) {
      if (vertices.isNotEmpty) {
        List<double> values = [];
        for (String s in vertices.split(',')) {
          values.add(double.parse(s));
        }
        setVertices(values);
      }
    }
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
  }

  /// This will set the coordinates of the vertices.
  ///
  /// [vertices] array of floats [x1, y1, x2, y2, ...] vertex coordinates in default user space.
  void setVertices(List<double> vertices) {
    annot.setItem(COSName.vertices, COSArray(vertices.map((e) => COSFloat(e)).toList()));
  }

  /// This will get the coordinates of the vertices.
  ///
  /// Returns array of floats [x1, y1, x2, y2, ...] vertex coordinates in default user space.
  List<double>? getVertices() {
    COSArray? array = annot.getCOSArray(COSName.vertices);
    return array?.toDoubleList();
  }

  /// This will set interior color of the drawn area.
  ///
  /// [color] The interior color of the drawn area.
  void setInteriorColor(List<double>? color) {
    if (color != null) {
      annot.setItem(COSName.ic, COSArray(color.map((e) => COSFloat(e)).toList()));
    } else {
      annot.removeItem(COSName.ic);
    }
  }

  /// This will get interior color of the drawn area.
  ///
  /// Returns object representing the color.
  List<double>? getInteriorColor() {
    COSArray? array = annot.getCOSArray(COSName.ic);
    return array?.toDoubleList();
  }
}

