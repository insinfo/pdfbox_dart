import '../../../cos/cos_array.dart';
import '../../../cos/cos_base.dart';
import '../../../cos/cos_name.dart';

/// Supported blend modes for extended graphics states.
///
/// The implementation currently tracks the PDF names and selection logic. The
/// actual compositing maths will be implemented alongside the rendering
/// pipeline.
enum BlendMode {
  normal('Normal'),
  multiply('Multiply'),
  screen('Screen'),
  overlay('Overlay'),
  darken('Darken'),
  lighten('Lighten'),
  colorDodge('ColorDodge'),
  colorBurn('ColorBurn'),
  hardLight('HardLight'),
  softLight('SoftLight'),
  difference('Difference'),
  exclusion('Exclusion'),
  hue('Hue'),
  saturation('Saturation'),
  color('Color'),
  luminosity('Luminosity');

  const BlendMode(this.pdfName);

  /// Name used when encoding the blend mode in COS objects.
  final String pdfName;

  /// Resolves a blend mode from the raw COS representation.
  static BlendMode fromCOSBase(COSBase? base) {
    if (base is COSName) {
      return _fromName(base.name);
    }
    if (base is COSArray) {
      for (final entry in base) {
        if (entry is COSName) {
          final mode = _fromName(entry.name);
          if (mode != BlendMode.normal) {
            return mode;
          }
        }
      }
    }
    return BlendMode.normal;
  }

  /// Returns the canonical PDF name for this blend mode.
  COSName toCOSName() => COSName.get(pdfName);

  static BlendMode _fromName(String name) {
    switch (name) {
      case 'Multiply':
        return BlendMode.multiply;
      case 'Screen':
        return BlendMode.screen;
      case 'Overlay':
        return BlendMode.overlay;
      case 'Darken':
        return BlendMode.darken;
      case 'Lighten':
        return BlendMode.lighten;
      case 'ColorDodge':
        return BlendMode.colorDodge;
      case 'ColorBurn':
        return BlendMode.colorBurn;
      case 'HardLight':
        return BlendMode.hardLight;
      case 'SoftLight':
        return BlendMode.softLight;
      case 'Difference':
        return BlendMode.difference;
      case 'Exclusion':
        return BlendMode.exclusion;
      case 'Hue':
        return BlendMode.hue;
      case 'Saturation':
        return BlendMode.saturation;
      case 'Color':
        return BlendMode.color;
      case 'Luminosity':
        return BlendMode.luminosity;
      case 'Compatible':
      case 'Normal':
      default:
        return BlendMode.normal;
    }
  }
}
