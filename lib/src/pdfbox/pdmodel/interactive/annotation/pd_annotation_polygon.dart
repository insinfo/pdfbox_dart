import '../../../cos/cos_array.dart';
import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_float.dart';
import '../../../cos/cos_name.dart';
import '../../pd_document.dart';
import '../../graphics/color/pd_color.dart';
import '../../graphics/color/pd_color_space.dart';
import '../../graphics/color/pd_device_rgb.dart';
import 'pd_annotation_markup.dart';
import 'pd_border_effect_dictionary.dart';

/// This is the class that represents a polygon annotation.
class PDAnnotationPolygon extends PDAnnotationMarkup {
  /// The type of annotation.
  static const String subType = 'Polygon';

  /// Constructor.
  PDAnnotationPolygon([COSDictionary? dict])
      : super(dict ?? COSDictionary()) {
    if (dict == null) {
      dictionary.setName(COSName.subtype, subType);
    }
  }

  /// This will set interior color.
  void setInteriorColor(PDColor ic) {
    dictionary.setItem(COSName.ic, ic.cosObject);
  }

  /// This will retrieve the interior color.
  PDColor? getInteriorColor() {
    final array = dictionary.getCOSArray(COSName.ic);
    if (array != null) {
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

  /// This will retrieve the numbers that shall represent the alternating horizontal and vertical coordinates.
  List<double>? getVertices() {
    final array = dictionary.getCOSArray(COSName.vertices);
    return array?.toDoubleList();
  }

  /// This will set the numbers that shall represent the alternating horizontal and vertical coordinates.
  void setVertices(List<double> points) {
    final array = COSArray();
    for (final p in points) {
      array.add(COSFloat(p));
    }
    dictionary.setItem(COSName.vertices, array);
  }

  /// PDF 2.0: This will retrieve the arrays that shall represent the alternating horizontal
  /// and vertical coordinates for path building.
  List<List<double>>? getPath() {
    final array = dictionary.getCOSArray(COSName.path);
    if (array != null) {
      final pathArray = <List<double>>[];
      for (final base2 in array) {
        if (base2 is COSArray) {
          pathArray.add(base2.toDoubleList());
        } else {
          pathArray.add(<double>[]);
        }
      }
      return pathArray;
    }
    return null;
  }

  // TODO: setCustomAppearanceHandler, constructAppearances
  void constructAppearances([PDDocument? document]) {
    // Implement PDPolygonAppearanceHandler logic when handlers are ported
  }
}
