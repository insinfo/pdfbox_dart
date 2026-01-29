import '../../../cos/cos_array.dart';
import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_float.dart';
import '../../../cos/cos_name.dart';
import '../../pd_document.dart';
import '../../graphics/color/pd_color.dart';
import '../../graphics/color/pd_color_space.dart';
import '../../graphics/color/pd_device_rgb.dart';
import 'pd_annotation_markup.dart';

/// This is the class that represents a line annotation. Introduced in PDF 1.3 specification.
class PDAnnotationLine extends PDAnnotationMarkup {
  /// Constant for annotation intent of Arrow.
  static const String itLineArrow = 'LineArrow';

  /// Constant for annotation intent of a dimension line.
  static const String itLineDimension = 'LineDimension';

  /// Constant for a square line ending.
  static const String leSquare = 'Square';

  /// Constant for a circle line ending.
  static const String leCircle = 'Circle';

  /// Constant for a diamond line ending.
  static const String leDiamond = 'Diamond';

  /// Constant for a open arrow line ending.
  static const String leOpenArrow = 'OpenArrow';

  /// Constant for a closed arrow line ending.
  static const String leClosedArrow = 'ClosedArrow';

  /// Constant for no line ending.
  static const String leNone = 'None';

  /// Constant for a butt line ending.
  static const String leButt = 'Butt';

  /// Constant for a reversed open arrow line ending.
  static const String leROpenArrow = 'ROpenArrow';

  /// Constant for a reversed closed arrow line ending.
  static const String leRClosedArrow = 'RClosedArrow';

  /// Constant for a slash line ending.
  static const String leSlash = 'Slash';

  /// The type of annotation.
  static const String subType = 'Line';

  /// Constructor.
  PDAnnotationLine([COSDictionary? field])
      : super(field ?? COSDictionary()) {
    if (field == null) {
      dictionary.setName(COSName.subtype, subType);
      // Dictionary value L is mandatory, fill in with arbitrary value
      setLine(<double>[0, 0, 0, 0]);
    }
  }

  /// This will set start and end coordinates of the line (or leader line if LL entry is set).
  void setLine(List<double> l) {
    final array = COSArray();
    for (final f in l) {
      array.add(COSFloat(f));
    }
    dictionary.setItem(COSName.l, array);
  }

  /// This will retrieve the start and end coordinates of the line (or leader line if LL entry is set).
  List<double>? getLine() {
    final l = dictionary.getCOSArray(COSName.l);
    return l?.toDoubleList();
  }

  /// This will set the line ending style for the start point.
  void setStartPointEndingStyle(String? style) {
    final actualStyle = style ?? leNone;
    var array = dictionary.getCOSArray(COSName.le);
    if (array == null || array.isEmpty) {
      array = COSArray();
      array.add(COSName(actualStyle));
      array.add(COSName(leNone));
      dictionary.setItem(COSName.le, array);
    } else {
      array.setName(0, actualStyle);
    }
  }

  /// This will retrieve the line ending style for the start point.
  String getStartPointEndingStyle() {
    final array = dictionary.getCOSArray(COSName.le);
    if (array != null && array.length >= 2) {
      return array.getName(0, leNone) ?? leNone;
    }
    return leNone;
  }

  /// This will set the line ending style for the end point.
  void setEndPointEndingStyle(String? style) {
    final actualStyle = style ?? leNone;
    var array = dictionary.getCOSArray(COSName.le);
    if (array == null || array.length < 2) {
      array = COSArray();
      array.add(COSName(leNone));
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
      return array.getName(1, leNone) ?? leNone;
    }
    return leNone;
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

  /// This will set if the contents are shown as a caption to the line.
  void setCaption(bool cap) {
    dictionary.setBoolean(COSName.cap, cap);
  }

  /// This will retrieve whether the text specified by the /Contents or /RC entries shall be shown as a caption.
  bool hasCaption() {
    return dictionary.getBoolean(COSName.cap, false) ?? false;
  }

  /// This will retrieve the length of the leader line.
  double getLeaderLineLength() {
    return dictionary.getFloat(COSName.ll, 0.0) ?? 0.0;
  }

  /// This will set the length of the leader line.
  void setLeaderLineLength(double leaderLineLength) {
    dictionary.setFloat(COSName.ll, leaderLineLength);
  }

  /// This will retrieve the length of the leader line extensions.
  double getLeaderLineExtensionLength() {
    return dictionary.getFloat(COSName.lle, 0.0) ?? 0.0;
  }

  /// This will set the length of the leader line extensions.
  void setLeaderLineExtensionLength(double leaderLineExtensionLength) {
    dictionary.setFloat(COSName.lle, leaderLineExtensionLength);
  }

  /// This will retrieve the length of the leader line offset.
  double getLeaderLineOffsetLength() {
    return dictionary.getFloat(COSName.llo, 0.0) ?? 0.0;
  }

  /// This will set the length of the leader line offset.
  void setLeaderLineOffsetLength(double leaderLineOffsetLength) {
    dictionary.setFloat(COSName.llo, leaderLineOffsetLength);
  }

  /// This will retrieve the caption positioning.
  String? getCaptionPositioning() {
    return dictionary.getNameAsString(COSName.cp);
  }

  /// This will set the caption positioning. Allowed values are: "Inline" and "Top"
  void setCaptionPositioning(String captionPositioning) {
    dictionary.setName(COSName.cp, captionPositioning);
  }

  /// This will set the horizontal offset of the caption.
  void setCaptionHorizontalOffset(double offset) {
    var array = dictionary.getCOSArray(COSName.co);
    if (array == null) {
      array = COSArray();
      array.add(COSFloat(offset));
      array.add(COSFloat(0.0));
      dictionary.setItem(COSName.co, array);
    } else {
      array.set(0, COSFloat(offset));
    }
  }

  /// This will retrieve the horizontal offset of the caption.
  double getCaptionHorizontalOffset() {
    final array = dictionary.getCOSArray(COSName.co);
    return array != null ? array.toDoubleList()[0] : 0.0;
  }

  /// This will set the vertical offset of the caption.
  void setCaptionVerticalOffset(double offset) {
    var array = dictionary.getCOSArray(COSName.co);
    if (array == null) {
      array = COSArray();
      array.add(COSFloat(0.0));
      array.add(COSFloat(offset));
      dictionary.setItem(COSName.co, array);
    } else {
      array.set(1, COSFloat(offset));
    }
  }

  /// This will retrieve the vertical offset of the caption.
  double getCaptionVerticalOffset() {
    final array = dictionary.getCOSArray(COSName.co);
    return array != null ? array.toDoubleList()[1] : 0.0;
  }

  // TODO: setCustomAppearanceHandler, constructAppearances
  void constructAppearances([PDDocument? document]) {
    // Implement PDLineAppearanceHandler logic when handlers are ported
  }
}
