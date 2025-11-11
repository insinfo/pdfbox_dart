import 'package:image/image.dart' as img;

import '../../../cos/cos_array.dart';
import '../../../cos/cos_base.dart';
import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_name.dart';
import '../../../cos/cos_object.dart';

import '../../pd_resources.dart';

import 'pd_cal_gray.dart';
import 'pd_cal_rgb.dart';
import 'pd_color.dart';
import 'pd_device_cmyk.dart';
import 'pd_device_gray.dart';
import 'pd_device_n.dart';
import 'pd_device_rgb.dart';
import 'pd_icc_based.dart';
import 'pd_indexed_color_space.dart';
import 'pd_lab.dart';
import 'pd_pattern_color_space.dart';
import 'pd_raster.dart';
import 'pd_separation.dart';

/// Base contract for color spaces used by the PDF graphics model.
abstract class PDColorSpace implements COSObjectable {
  /// Returns the PDF name of this color space.
  String get name;

  /// Returns the number of components required by this color space.
  int get numberOfComponents;

  /// Returns the default decode array for the given component precision.
  List<double> getDefaultDecode(int bitsPerComponent);

  /// Returns the initial color defined by the color space.
  PDColor getInitialColor();

  /// Converts the given component array to an RGB triple scaled to 0..1.
  List<double> toRGB(List<double> value);

  /// Converts the supplied raster to a new RGB image.
  img.Image toRGBImage(PDRaster raster) {
    if (raster.componentsPerPixel != numberOfComponents) {
      throw ArgumentError(
        'Raster component count ${raster.componentsPerPixel} does not match '
        '$numberOfComponents for $name.',
      );
    }

    final image = img.Image(width: raster.width, height: raster.height);
    final components = List<double>.filled(numberOfComponents, 0.0);

    for (var y = 0; y < raster.height; ++y) {
      for (var x = 0; x < raster.width; ++x) {
        raster.getPixel(x, y, components);
        final rgb = toRGB(components);
        image.setPixelRgba(
          x,
          y,
          _toChannel(rgb, 0),
          _toChannel(rgb, 1),
          _toChannel(rgb, 2),
          255,
        );
      }
    }

    return image;
  }

  /// Returns a raw image in the colour space when available; otherwise `null`.
  img.Image? toRawImage(PDRaster raster) => null;

  /// Ensures the provided [components] list matches the component count by
  /// trimming or padding with zero values.
  List<double> normalizeComponents(Iterable<double> components) {
    final normalized =
        List<double>.filled(numberOfComponents, 0.0, growable: false);
    var index = 0;
    for (final component in components) {
      if (index >= normalized.length) {
        break;
      }
      normalized[index] = component;
      index++;
    }
    return normalized;
  }

  /// Resolves a colour space defined by a COS object, mirroring PDFBox logic.
  static PDColorSpace create(
    COSBase colorSpace, {
    PDResources? resources,
    bool wasDefault = false,
  }) {
    final resolved = colorSpace is COSObject ? colorSpace.object : colorSpace;
    if (resolved is COSName) {
      return _createFromName(resolved,
          resources: resources, wasDefault: wasDefault);
    }
    if (resolved is COSArray) {
      return _createFromArray(resolved,
          resources: resources, wasDefault: wasDefault);
    }
    if (resolved is COSDictionary) {
      // ICCBased colour spaces may be stored as dictionaries, but PDFBox
      // handles them through an array indirection. Defer until implemented.
      throw UnsupportedError(
          'Dictionary-based colour spaces are not supported yet: $resolved');
    }
    throw UnsupportedError(
        'Unsupported colour space definition: ${resolved.runtimeType}');
  }

  static PDColorSpace _createFromName(
    COSName name, {
    PDResources? resources,
    bool wasDefault = false,
  }) {
    final resourceValue = resources?.getColorSpaceObject(name);
    if (resourceValue != null && resourceValue != name) {
      return create(resourceValue, resources: resources);
    }

    if (name == COSName.deviceGray) {
      if (!wasDefault) {
        final defaultCS =
            resources?.getDefaultColorSpaceObject(COSName.defaultGray);
        if (defaultCS != null) {
          return create(defaultCS, resources: resources, wasDefault: true);
        }
      }
      return PDDeviceGray.instance;
    }

    if (name == COSName.deviceRGB) {
      if (!wasDefault) {
        final defaultCS =
            resources?.getDefaultColorSpaceObject(COSName.defaultRGB);
        if (defaultCS != null) {
          return create(defaultCS, resources: resources, wasDefault: true);
        }
      }
      return PDDeviceRGB.instance;
    }

    if (name == COSName.deviceCMYK) {
      if (!wasDefault) {
        final defaultCS =
            resources?.getDefaultColorSpaceObject(COSName.defaultCMYK);
        if (defaultCS != null) {
          return create(defaultCS, resources: resources, wasDefault: true);
        }
      }
      return PDDeviceCMYK.instance;
    }

    if (name == COSName.pattern) {
      return PDPatternColorSpace();
    }

    if (name == COSName.calGray) {
      return PDCalGray();
    }

    if (name == COSName.calRGB) {
      return PDCalRGB();
    }

    if (name == COSName.lab) {
      return PDLab();
    }

    throw UnsupportedError('Unsupported colour space: $name');
  }

  static PDColorSpace _createFromArray(
    COSArray array, {
    PDResources? resources,
    bool wasDefault = false,
  }) {
    if (array.isEmpty) {
      throw StateError('Colour space array is empty');
    }
    final first = array.getObject(0);
    if (first is! COSName) {
      throw StateError('First entry in colour space array must be a name');
    }

    if (first == COSName.pattern) {
      PDColorSpace? underlying;
      if (array.length > 1) {
        final base = array.getObject(1);
        underlying = create(base, resources: resources);
      }
      return PDPatternColorSpace(underlying: underlying);
    }

    if (first == COSName.indexed) {
      if (array.length < 4) {
        throw StateError('Indexed colour space requires four operands');
      }
      final base = create(array.getObject(1), resources: resources);
      final highValue = PDIndexedColorSpace.readHighValue(array.getObject(2));
      final lookup = PDIndexedColorSpace.extractLookup(array.getObject(3));
      return PDIndexedColorSpace(
        array: array,
        base: base,
        highValue: highValue,
        lookup: lookup,
      );
    }

    if (first == COSName.separation) {
      return PDSeparation.fromCOSArray(array, resources: resources);
    }

    if (first == COSName.deviceN) {
      return PDDeviceN.fromCOSArray(array, resources: resources);
    }

    if (first == COSName.calGray) {
      return PDCalGray.fromCOSArray(array);
    }

    if (first == COSName.calRGB) {
      return PDCalRGB.fromCOSArray(array);
    }

    if (first == COSName.lab) {
      return PDLab.fromCOSArray(array);
    }

    if (first == COSName.iccBased) {
      return PDICCBased.fromArray(array, resources: resources);
    }

    // Allow array-form device colour spaces (rare in practice).
    if (first == COSName.deviceGray ||
        first == COSName.deviceRGB ||
        first == COSName.deviceCMYK) {
      return _createFromName(first,
          resources: resources, wasDefault: wasDefault);
    }

    throw UnsupportedError('Unsupported colour space array: $array');
  }
}

int _toChannel(List<double> rgb, int index) {
  if (index >= rgb.length) {
    return 0;
  }
  final value = rgb[index].clamp(0.0, 1.0);
  final scaled = (value * 255.0).round();
  if (scaled < 0) {
    return 0;
  }
  if (scaled > 255) {
    return 255;
  }
  return scaled;
}

/// Device colour spaces directly specify colours without profiles.
abstract class PDDeviceColorSpace extends PDColorSpace {
  @override
  COSBase get cosObject => COSName(name);

  @override
  String toString() => name;
}
