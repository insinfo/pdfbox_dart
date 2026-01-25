import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_name.dart';
import '../../common/cos_objectable.dart';

/// This class represents a PDF /BE entry the border effect dictionary.
class PDBorderEffectDictionary implements COSObjectable {
  /*
   * The various values of the effect applied to the border as defined in the PDF 1.6 reference Table 8.14
   */

  /// Constant for the name for no effect.
  static const String STYLE_SOLID = "S";

  /// Constant for the name of a cloudy effect.
  static const String STYLE_CLOUDY = "C";

  final COSDictionary _dictionary;

  /// Constructor.
  PDBorderEffectDictionary([COSDictionary? dict])
      : _dictionary = dict ?? COSDictionary();

  /// returns the dictionary.
  @override
  COSDictionary get cosObject => _dictionary;

  /// This will set the intensity of the applied effect.
  ///
  /// [i] the intensity of the effect values 0 to 2
  void setIntensity(double i) {
    _dictionary.setFloat(COSName.get("I"), i);
  }

  /// This will retrieve the intensity of the applied effect.
  ///
  /// Returns the intensity value 0 to 2
  double getIntensity() {
    return _dictionary.getFloat(COSName.get("I"), 0.0) ?? 0.0;
  }

  /// This will set the border effect, see the STYLE_* constants for valid values.
  ///
  /// [s] the border effect to use
  void setStyle(String s) {
    _dictionary.setName(COSName.get("S"), s);
  }

  /// This will retrieve the border effect, see the STYLE_* constants for valid values.
  ///
  /// Returns the effect of the border or [STYLE_SOLID] if none is found.
  String getStyle() {
    return _dictionary.getNameAsString(COSName.get("S"), STYLE_SOLID) ?? STYLE_SOLID;
  }
}
