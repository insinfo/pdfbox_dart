import '../../../cos/cos_array.dart';
import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_float.dart';
import '../../../cos/cos_name.dart';
import '../../common/pd_rectangle.dart';
import '../../graphics/color/pd_color.dart';
import '../../graphics/color/pd_color_space.dart';
import '../../graphics/color/pd_device_rgb.dart';
import 'pd_annotation_markup.dart';
import 'pd_border_effect_dictionary.dart';

/// This is the class that represents a rectangular or elliptical annotation introduced in PDF 1.3 specification.
abstract class PDAnnotationSquareCircle extends PDAnnotationMarkup {
  /// Creates a Circle or Square annotation of the specified sub type.
  PDAnnotationSquareCircle.create(String subType)
      : super(COSDictionary()) {
    setSubtype(subType);
  }

  /// Constructor.
  PDAnnotationSquareCircle(COSDictionary dict) : super(dict);

  void setSubtype(String subType) {
    dictionary.setName(COSName.subtype, subType);
  }

  // abstract void constructAppearances();
  void constructAppearances();

  /// This will set interior color of the drawn area color is in DeviceRGB colorspace.
  void setInteriorColor(PDColor ic) {
    dictionary.setItem(COSName.ic, ic.cosObject);
  }

  /// This will retrieve the interior color of the drawn area color is in DeviceRGB color space.
  PDColor? getInteriorColor() {
    return getColor(COSName.ic);
  }

  /// Helper to get color from dictionary.
  PDColor? getColor(COSName key) {
    final array = dictionary.getCOSArray(key);
    if (array != null) {
      // TODO: Support other color spaces (CMYK, Gray) based on component count
      PDColorSpace cs = PDDeviceRGB.instance; 
      return PDColor.fromCOSArray(array, cs);
    }
    return null;
  }

  /// This will set the border effect dictionary.
  void setBorderEffect(PDBorderEffectDictionary be) {
    dictionary.setItem(COSName.be, be);
  }

  /// This will retrieve the border effect dictionary.
  PDBorderEffectDictionary? getBorderEffect() {
    final dict = dictionary.getCOSDictionary(COSName.be);
    return dict != null ? PDBorderEffectDictionary(dict) : null;
  }

  /// This will set the rectangle difference.
  void setRectDifference(PDRectangle rd) {
    dictionary.setItem(COSName.rd, rd.toCOSArray());
  }

  /// This will get the rectangle difference.
  PDRectangle? getRectDifference() {
    final array = dictionary.getCOSArray(COSName.rd);
    return array != null ? PDRectangle.fromCOSArray(array) : null;
  }

  /// This will set the difference between the annotations "outer" rectangle defined by /Rect and the border.
  void setRectDifferences(double diffLeft,
      [double? diffTop, double? diffRight, double? diffBottom]) {
    if (diffTop == null && diffRight == null && diffBottom == null) {
      setRectDifferences(diffLeft, diffLeft, diffLeft, diffLeft);
      return;
    }
    final margins = COSArray();
    margins.add(COSFloat(diffLeft));
    margins.add(COSFloat(diffTop ?? 0));
    margins.add(COSFloat(diffRight ?? 0));
    margins.add(COSFloat(diffBottom ?? 0));
    dictionary.setItem(COSName.rd, margins);
  }

  /// This will get the differences between the annotations "outer" rectangle defined by /Rect and the border.
  List<double> getRectDifferences() {
    final margin = dictionary.getCOSArray(COSName.rd);
    return margin != null ? margin.toDoubleList() : [];
  }
}
