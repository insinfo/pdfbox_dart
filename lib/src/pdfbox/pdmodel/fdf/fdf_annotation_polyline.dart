import 'package:pdfbox_dart/src/utils/xml/xml.dart';
import '../../cos/cos_array.dart';
import '../../cos/cos_dictionary.dart';
import '../../cos/cos_float.dart';
import '../../cos/cos_name.dart';
import 'fdf_annotation.dart';
import 'fdf_annotation_line.dart';

/// This represents a Polyline FDF annotation.
class FDFAnnotationPolyline extends FDFAnnotation {
  /// COS Model value for SubType entry.
  static const String SUBTYPE = 'Polyline';

  /// Default constructor.
  FDFAnnotationPolyline() : super() {
    annot.setItem(COSName.subtype, COSName.polyline);
  }

  /// Constructor.
  ///
  /// [a] An existing FDF Annotation.
  FDFAnnotationPolyline.fromDictionary(COSDictionary a) : super.fromDictionary(a);

  /// Constructor from XML Element.
  FDFAnnotationPolyline.fromXml(XmlElement element) : super.fromXml(element) {
    annot.setItem(COSName.subtype, COSName.polyline);
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
    String? head = element.getAttribute('head');
    String? tail = element.getAttribute('tail');
    if (head != null || tail != null) {
        setStartPointEndingStyle(head ?? FDFAnnotationLine.LE_NONE);
        setEndPointEndingStyle(tail ?? FDFAnnotationLine.LE_NONE);
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

  /// This will set the coordinates of the the vertices.
  ///
  /// [vertices] array of floats [x1, y1, x2, y2, ...] vertex coordinates in default user space.
  void setVertices(List<double> vertices) {
    annot.setItem(COSName.vertices, COSArray(vertices.map((e) => COSFloat(e)).toList()));
  }

  /// This will get the coordinates of the the vertices.
  ///
  /// Returns array of floats [x1, y1, x2, y2, ...] vertex coordinates in default user space.
  List<double>? getVertices() {
    COSArray? array = annot.getCOSArray(COSName.vertices);
    return array?.toDoubleList();
  }

  /// This will set the line ending style for the start point, see the LE_ constants for the possible values.
  ///
  /// [style] The new style.
  void setStartPointEndingStyle(String style) {
    String actualStyle = style;
    COSArray? array = annot.getCOSArray(COSName.le);
    if (array == null) {
      array = COSArray();
      array.add(COSName(actualStyle));
      array.add(COSName(FDFAnnotationLine.LE_NONE));
      annot.setItem(COSName.le, array);
    } else {
      array[0] = COSName(actualStyle);
    }
  }

  /// This will retrieve the line ending style for the start point, possible values shown in the LE_ constants section.
  ///
  /// Returns The ending style for the start point.
  String getStartPointEndingStyle() {
    COSArray? array = annot.getCOSArray(COSName.le);
    if (array != null && array.length > 0) {
      var item = array[0];
      if (item is COSName) {
        return item.name;
      }
    }
    return FDFAnnotationLine.LE_NONE;
  }

  /// This will set the line ending style for the end point, see the LE_ constants for the possible values.
  ///
  /// [style] The new style.
  void setEndPointEndingStyle(String style) {
    String actualStyle = style;
    COSArray? array = annot.getCOSArray(COSName.le);
    if (array == null) {
      array = COSArray();
      array.add(COSName(FDFAnnotationLine.LE_NONE));
      array.add(COSName(actualStyle));
      annot.setItem(COSName.le, array);
    } else {
      array[1] = COSName(actualStyle);
    }
  }

  /// This will retrieve the line ending style for the end point, possible values shown in the LE_ constants section.
  ///
  /// Returns The ending style for the end point.
  String getEndPointEndingStyle() {
    COSArray? array = annot.getCOSArray(COSName.le);
    if (array != null && array.length > 1) {
      var item = array[1];
      if (item is COSName) {
        return item.name;
      }
    }
    return FDFAnnotationLine.LE_NONE;
  }

  /// This will set interior color of the line endings defined in the LE entry.
  ///
  /// [color] The interior color of the line endings.
  void setInteriorColor(List<double>? color) {
    if (color != null) {
      annot.setItem(COSName.ic, COSArray(color.map((e) => COSFloat(e)).toList()));
    } else {
      annot.removeItem(COSName.ic);
    }
  }

  /// This will retrieve the interior color of the line endings defined in the LE entry.
  ///
  /// Returns object representing the color.
  List<double>? getInteriorColor() {
    COSArray? array = annot.getCOSArray(COSName.ic);
    return array?.toDoubleList();
  }
}

