import '../../../utils/xml/xml.dart';
import '../../cos/cos_array.dart';
import '../../cos/cos_dictionary.dart';
import '../../cos/cos_float.dart';
import '../../cos/cos_name.dart';
import 'fdf_annotation.dart';

/// This represents a Line FDF annotation.
class FDFAnnotationLine extends FDFAnnotation {
  /// COS Model value for SubType entry.
  static const String SUBTYPE = 'Line';

  /// Default constructor.
  FDFAnnotationLine() : super() {
    annot.setItem(COSName.subtype, COSName.line);
  }

  /// Constructor.
  ///
  /// [a] An existing FDF Annotation.
  FDFAnnotationLine.fromDictionary(COSDictionary a) : super.fromDictionary(a);

  /// Constructor from XML Element.
  FDFAnnotationLine.fromXml(XmlElement element) : super.fromXml(element) {
    annot.setItem(COSName.subtype, COSName.line);
    String? start = element.getAttribute('start');
    if (start != null) {
        setStartPoint(start);
    }
    String? end = element.getAttribute('end');
    if (end != null) {
        setEndPoint(end);
    }
    String? head = element.getAttribute('head');    
    String? tail = element.getAttribute('tail');
    if (head != null || tail != null) {
        setLineEndingStyle(head, tail);
    }
    String? color = element.getAttribute('interior-color');
    if (color != null && color.isNotEmpty) {
         List<double> colorList = [];
         for(String s in color.split(',')) {
             colorList.add(double.parse(s));
         }
         setInteriorColor(colorList);
    }
  }

  /// Constant for a line ending style.
  static const String LE_NONE = 'None';
  static const String LE_SQUARE = 'Square';
  static const String LE_CIRCLE = 'Circle';
  static const String LE_DIAMOND = 'Diamond';
  static const String LE_OPEN_ARROW = 'OpenArrow';
  static const String LE_CLOSED_ARROW = 'ClosedArrow';
  static const String LE_BUTT = 'Butt';
  static const String LE_R_OPEN_ARROW = 'ROpenArrow';
  static const String LE_R_CLOSED_ARROW = 'RClosedArrow';
  static const String LE_SLASH = 'Slash'; 

  void setStartPoint(String start) { // Expecting "x,y"
    List<String> split = start.split(',');
    if (split.length == 2) {
       List<double> line = getLine() ?? [0,0,0,0];
       line[0] = double.parse(split[0]);
       line[1] = double.parse(split[1]);
       setLine(line);
    }
  }

  void setEndPoint(String end) {
      List<String> split = end.split(',');
      if (split.length == 2) {
          List<double> line = getLine() ?? [0,0,0,0];
          line[2] = double.parse(split[0]);
          line[3] = double.parse(split[1]);
          setLine(line);
      }
  }

  void setLineEndingStyle(String? head, String? tail) {
      COSArray array = COSArray();
      array.add(COSName.getPDFName(head ?? LE_NONE));
      array.add(COSName.getPDFName(tail ?? LE_NONE));
      annot.setItem(COSName.le, array);
  }

  void setInteriorColor(List<double>? color) {
    if (color != null) {
      annot.setItem(COSName.ic, COSArray(color.map((e) => COSFloat(e)).toList()));
    } else {
      annot.removeItem(COSName.ic);
    }
  }

  void setLine(List<double> line) {
    annot.setItem(COSName.l, COSArray(line.map((e) => COSFloat(e)).toList()));
  }

  List<double>? getLine() {
    COSArray? array = annot.getCOSArray(COSName.l);
    if (array != null) {
      return array.toDoubleList();
    }
    return null;
  }
  String getStartPointEndingStyle() {
      COSArray? array = annot.getCOSArray(COSName.le);
      if (array != null && array.length > 0) {
        var item = array[0];
        if (item is COSName) {
          return item.name;
        }
      }
      return LE_NONE;
  }

  String getEndPointEndingStyle() {
      COSArray? array = annot.getCOSArray(COSName.le);
      if (array != null && array.length > 1) {
        var item = array[1];
        if (item is COSName) {
          return item.name;
        }
      }
      return LE_NONE;
  }

  List<double>? getInteriorColor() {
      COSArray? array = annot.getCOSArray(COSName.ic);
      if (array != null) {
        return array.toDoubleList();
      }
      return null;
  }
}

