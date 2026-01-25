import '../../cos/cos_array.dart';
import '../../cos/cos_dictionary.dart';
import '../../cos/cos_float.dart';
import '../../cos/cos_name.dart';
import 'fdf_annotation.dart';

/// This represents a Line FDF annotation.
class FDFAnnotationLine extends FDFAnnotation {
  /// COS Model value for SubType entry.
  static const String SUBTYPE = 'Line';

  // Constants from PDAnnotationLine
  static const String LE_SQUARE = "Square";
  static const String LE_CIRCLE = "Circle";
  static const String LE_DIAMOND = "Diamond";
  static const String LE_OPEN_ARROW = "OpenArrow";
  static const String LE_CLOSED_ARROW = "ClosedArrow";
  static const String LE_NONE = "None";
  static const String LE_BUTT = "Butt";
  static const String LE_SLASH = "Slash";

  /// Default constructor.
  FDFAnnotationLine() : super() {
    annot.setName(COSName.subtype, SUBTYPE);
  }

  /// Constructor.
  ///
  /// [a] An existing FDF Annotation.
  FDFAnnotationLine.fromDictionary(COSDictionary a) : super.fromDictionary(a);

  /// This will set start and end coordinates of the line (or leader line if LL entry is set).
  ///
  /// [line] array of 4 floats [x1, y1, x2, y2] line start and end points in default user space.
  void setLine(List<double> line) {
    annot.setItem(COSName.l, COSArray(line.map((e) => COSFloat(e)).toList()));
  }

  /// This will retrieve the start and end coordinates of the line (or leader line if LL entry is set).
  ///
  /// Returns array of floats [x1, y1, x2, y2] line start and end points in default user space.
  List<double>? getLine() {
    COSArray? array = annot.getCOSArray(COSName.l);
    return array?.toDoubleList();
  }

  /// This will set the line ending style for the start point.
  ///
  /// [style] The new style.
  void setStartPointEndingStyle(String style) {
    String actualStyle = style;
    COSArray? array = annot.getCOSArray(COSName.le);
    if (array == null) {
      array = COSArray();
      array.add(COSName(actualStyle));
      array.add(COSName(LE_NONE));
      annot.setItem(COSName.le, array);
    } else {
      array[0] = COSName(actualStyle);
    }
  }

  /// This will retrieve the line ending style for the start point.
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
    return LE_NONE;
  }

  /// This will set the line ending style for the end point.
  ///
  /// [style] The new style.
  void setEndPointEndingStyle(String style) {
    String actualStyle = style;
    COSArray? array = annot.getCOSArray(COSName.le);
    if (array == null) {
      array = COSArray();
      array.add(COSName(LE_NONE));
      array.add(COSName(actualStyle));
      annot.setItem(COSName.le, array);
    } else {
      array[1] = COSName(actualStyle);
    }
  }

  /// This will retrieve the line ending style for the end point.
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
    return LE_NONE;
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

  /// This will set if the contents are shown as a caption to the line.
  ///
  /// [cap] Boolean value.
  void setCaption(bool cap) {
    annot.setBoolean(COSName.cap, cap);
  }

  /// This will retrieve if the contents are shown as a caption or not.
  ///
  /// Returns boolean if the content is shown as a caption.
  bool getCaption() {
    return annot.getBoolean(COSName.cap, false) ?? false;
  }

  /// This will retrieve the length of the leader line.
  ///
  /// Returns the length of the leader line
  double getLeaderLength() {
    return annot.getFloat(COSName.ll, 0.0) ?? 0.0;
  }

  /// This will set the length of the leader line.
  ///
  /// [leaderLength] length of the leader line
  void setLeaderLength(double leaderLength) {
    annot.setFloat(COSName.ll, leaderLength);
  }

  /// This will retrieve the length of the leader line extensions.
  ///
  /// Returns the length of the leader line extensions
  double getLeaderExtend() {
    return annot.getFloat(COSName.lle, 0.0) ?? 0.0;
  }

  /// This will set the length of the leader line extensions.
  ///
  /// [leaderExtend] length of the leader line extensions
  void setLeaderExtend(double leaderExtend) {
    annot.setFloat(COSName.lle, leaderExtend);
  }

  /// This will retrieve the length of the leader line offset.
  ///
  /// Returns the length of the leader line offset
  double getLeaderOffset() {
    return annot.getFloat(COSName.llo, 0.0) ?? 0.0;
  }

  /// This will set the length of the leader line offset.
  ///
  /// [leaderOffset] length of the leader line offset
  void setLeaderOffset(double leaderOffset) {
    annot.setFloat(COSName.llo, leaderOffset);
  }

  /// This will retrieve the caption positioning.
  ///
  /// Returns the caption positioning
  String? getCaptionStyle() {
    return annot.getString(COSName.cp);
  }

  /// This will set the caption positioning. Allowed values are: "Inline" and "Top"
  ///
  /// [captionStyle] caption positioning
  void setCaptionStyle(String captionStyle) {
    annot.setString(COSName.cp, captionStyle);
  }

  /// This will set the horizontal offset of the caption.
  ///
  /// [offset] the horizontal offset of the caption
  void setCaptionHorizontalOffset(double offset) {
    COSArray? array = annot.getCOSArray(COSName.co);
    if (array == null) {
      array = COSArray();
      array.add(COSFloat(offset));
      array.add(COSFloat(0.0));
      annot.setItem(COSName.co, array);
    } else {
      array[0] = COSFloat(offset);
    }
  }

  /// This will retrieve the horizontal offset of the caption.
  ///
  /// Returns the horizontal offset of the caption
  double getCaptionHorizontalOffset() {
    COSArray? array = annot.getCOSArray(COSName.co);
    if (array != null) {
      List<double> floats = array.toDoubleList();
      if (floats.isNotEmpty) return floats[0];
    }
    return 0.0;
  }

  /// This will set the vertical offset of the caption.
  ///
  /// [offset] vertical offset of the caption
  void setCaptionVerticalOffset(double offset) {
    COSArray? array = annot.getCOSArray(COSName.co);
    if (array == null) {
      array = COSArray();
      array.add(COSFloat(0.0));
      array.add(COSFloat(offset));
      annot.setItem(COSName.co, array);
    } else {
      array[1] = COSFloat(offset);
    }
  }

  /// This will retrieve the vertical offset of the caption.
  ///
  /// Returns the vertical offset of the caption
  double getCaptionVerticalOffset() {
    COSArray? array = annot.getCOSArray(COSName.co);
    if (array != null) {
      List<double> floats = array.toDoubleList();
      if (floats.length > 1) return floats[1];
    }
    return 0.0;
  }
}
