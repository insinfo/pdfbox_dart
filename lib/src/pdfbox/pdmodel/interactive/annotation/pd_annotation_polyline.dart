import '../../../cos/cos_array.dart';
import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_float.dart';
import '../../../cos/cos_name.dart';
import '../../pd_document.dart';
import '../../graphics/color/pd_color.dart';
import '../../graphics/color/pd_color_space.dart';
import '../../graphics/color/pd_device_rgb.dart';
import 'pd_annotation_markup.dart';
import 'pd_annotation_line.dart';

/// This is the class that represents a polyline annotation.
class PDAnnotationPolyline extends PDAnnotationMarkup {
  /// The type of annotation.
  static const String subType = 'PolyLine';

  /// Constructor.
  PDAnnotationPolyline([COSDictionary? dict])
      : super(dict ?? COSDictionary()) {
    if (dict == null) {
      dictionary.setName(COSName.subtype, subType);
    }
  }

  /// This will set the line ending style for the start point.
  void setStartPointEndingStyle(String? style) {
    final actualStyle = style ?? PDAnnotationLine.leNone;
    var array = dictionary.getCOSArray(COSName.le);
    if (array == null || array.isEmpty) {
      array = COSArray();
      array.add(COSName(actualStyle));
      array.add(COSName(PDAnnotationLine.leNone));
      dictionary.setItem(COSName.le, array);
    } else {
      array.setName(0, actualStyle);
    }
  }

  /// This will retrieve the line ending style for the start point.
  String getStartPointEndingStyle() {
    final array = dictionary.getCOSArray(COSName.le);
    if (array != null && array.length >= 2) {
      return array.getName(0, PDAnnotationLine.leNone) ?? PDAnnotationLine.leNone;
    }
    return PDAnnotationLine.leNone;
  }

  /// This will set the line ending style for the end point.
  void setEndPointEndingStyle(String? style) {
    final actualStyle = style ?? PDAnnotationLine.leNone;
    var array = dictionary.getCOSArray(COSName.le);
    if (array == null || array.length < 2) {
      array = COSArray();
      array.add(COSName(PDAnnotationLine.leNone));
      array.add(COSName(actualStyle));
      dictionary.setItem(COSName.le, array);
    } else {
      array.setName(1, actualStyle);
    }
  }

  /// This will retrieve the line ending style for the end point.
  String getEndPointEndingStyle() {
    final array = dictionary.getCOSArray(COSName.le);
    if (array != null && array.length >= 2) {
      return array.getName(1, PDAnnotationLine.leNone) ?? PDAnnotationLine.leNone;
    }
    return PDAnnotationLine.leNone;
  }

  /// This will set interior color of the line endings defined in the LE entry.
  void setInteriorColor(PDColor ic) {
    dictionary.setItem(COSName.ic, ic.cosObject);
  }

  /// This will retrieve the interior color of the line endings defined in the LE entry.
  PDColor? getInteriorColor() {
    final array = dictionary.getCOSArray(COSName.ic);
    if (array != null) {
      PDColorSpace cs = PDDeviceRGB.instance;
      return PDColor.fromCOSArray(array, cs);
    }
    return null;
  }

  /// This will retrieve the numbers that shall represent the alternating horizontal and vertical coordinates.
  List<double>? getVertices() {
    final vertices = dictionary.getCOSArray(COSName.vertices);
    return vertices?.toDoubleList();
  }

  /// This will set the numbers that shall represent the alternating horizontal and vertical coordinates.
  void setVertices(List<double> points) {
    final array = COSArray();
    for (final p in points) {
      array.add(COSFloat(p));
    }
    dictionary.setItem(COSName.vertices, array);
  }

  // TODO: setCustomAppearanceHandler, constructAppearances
  void constructAppearances([PDDocument? document]) {
    // Implement PDPolylineAppearanceHandler logic when handlers are ported
  }
}
