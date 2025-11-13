import 'package:image/image.dart' as img;

import '../../../cos/cos_array.dart';
import '../../../cos/cos_base.dart';
import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_name.dart';
import '../../common/function/pdf_function.dart';
import '../../pd_resources.dart';
import 'pd_color.dart';
import 'pd_color_math.dart';
import 'pd_color_space.dart';
import 'pd_device_n_attributes.dart';
import 'pd_device_n_process.dart';
import 'pd_raster.dart';
import 'pd_separation.dart';
import 'pd_special_color_space.dart';

class PDDeviceN extends PDSpecialColorSpace {
  PDDeviceN._(
    this._array,
    this._colorantNames,
    this._alternateColorSpace,
    this._tintTransform,
    this._attributes,
    this._conversionCache,
  ) {
    _initialColor = PDColor(
      List<double>.filled(_colorantNames.length, 1.0, growable: false),
      this,
    );
  }

  factory PDDeviceN.fromCOSArray(
    COSArray array, {
    PDResources? resources,
  }) {
    if (array.length < 4) {
      throw StateError(
        'DeviceN colour space array must contain at least four elements',
      );
    }

    final colorantNames = _parseColorantNames(array.getObject(1));
    final alternate = PDColorSpace.create(
      array.getObject(2),
      resources: resources,
    );
    final tintTransform = PDFunction.create(array.getObject(3));

    PDDeviceNAttributes? attributes;
    if (array.length > 4) {
      final attributesObject = array.getObject(4);
      if (attributesObject is COSDictionary) {
        attributes = PDDeviceNAttributes(attributesObject);
      }
    }

    final conversionCache = _buildConversionCache(
      colorantNames,
      attributes,
      resources,
    );

    return PDDeviceN._(
      array,
      colorantNames,
      alternate,
      tintTransform,
      attributes,
      conversionCache,
    );
  }

  final COSArray _array;
  final List<String> _colorantNames;
  final PDColorSpace _alternateColorSpace;
  final PDFunction _tintTransform;
  final PDDeviceNAttributes? _attributes;
  final _DeviceNConversionCache? _conversionCache;
  late final PDColor _initialColor;
  final Map<String, List<double>> _rgbCache = <String, List<double>>{};
  final Map<String, List<double>> _attributesRgbCache =
      <String, List<double>>{};

  @override
  COSBase get cosObject => _array;

  @override
  String get name => COSName.deviceN.name;

  @override
  int get numberOfComponents => _colorantNames.length;

  @override
  List<double> getDefaultDecode(int bitsPerComponent) => List<double>.generate(
        numberOfComponents * 2,
        (index) => index.isEven ? 0.0 : 1.0,
        growable: false,
      );

  @override
  PDColor getInitialColor() => _initialColor;

  List<String> get colorantNames =>
      List<String>.from(_colorantNames, growable: false);

  PDColorSpace get alternateColorSpace => _alternateColorSpace;

  PDFunction get tintTransform => _tintTransform;

  PDDeviceNAttributes? get attributes => _attributes;

  @override
  List<double> toRGB(List<double> value) {
    final normalized = _normalizeInput(value);
    final cacheKey = _cacheKey(normalized);
    final rgb = _convertNormalizedWithKey(normalized, cacheKey);
    return List<double>.from(rgb, growable: false);
  }

  @override
  img.Image toRGBImage(PDRaster raster) {
    if (raster.componentsPerPixel != numberOfComponents) {
      throw ArgumentError(
        'DeviceN expects $numberOfComponents components per pixel but '
        'received ${raster.componentsPerPixel}.',
      );
    }

    final image = img.Image(width: raster.width, height: raster.height);
    final samples = List<double>.filled(numberOfComponents, 0.0);
    final normalized = List<double>.filled(numberOfComponents, 0.0);
    final imageCache = <String, List<int>>{};

    for (var y = 0; y < raster.height; ++y) {
      for (var x = 0; x < raster.width; ++x) {
        raster.getPixel(x, y, samples);
        _normalizeInto(samples, normalized);
        final cacheKey = _cacheKey(normalized);

        final cached = imageCache[cacheKey];
        if (cached != null) {
          image.setPixelRgba(x, y, cached[0], cached[1], cached[2], 255);
          continue;
        }

        final rgb = _convertNormalizedWithKey(normalized, cacheKey);
        final r = _channel(rgb[0]);
        final g = _channel(rgb[1]);
        final b = _channel(rgb[2]);

        imageCache[cacheKey] = <int>[r, g, b];
        image.setPixelRgba(x, y, r, g, b, 255);
      }
    }

    return image;
  }

  List<double> _convertNormalizedWithKey(
    List<double> normalized,
    String cacheKey,
  ) {
    final attributes = _toRGBWithAttributes(normalized, cacheKey: cacheKey);
    if (attributes != null) {
      return attributes;
    }
    return _toRGBWithTintTransform(normalized, cacheKey: cacheKey);
  }

  List<double>? _toRGBWithAttributes(
    List<double> normalized, {
    String? cacheKey,
  }) {
    final cache = _conversionCache;
    if (cache == null) {
      return null;
    }

    final key = cacheKey ?? _cacheKey(normalized);
    final cached = _attributesRgbCache[key];
    if (cached != null) {
      return List<double>.from(cached, growable: false);
    }

    final rgb = <double>[1.0, 1.0, 1.0];
    for (var index = 0; index < normalized.length; ++index) {
      final componentIndex = cache.colorantToComponent[index];
      final isProcessComponent =
          componentIndex >= 0 && cache.processColorSpace != null;
      final PDColorSpace? componentSpace = isProcessComponent
          ? cache.processColorSpace
          : cache.spotColorSpaces[index];

      if (componentSpace == null) {
        return null;
      }

      final componentValues = List<double>.filled(
        componentSpace.numberOfComponents,
        0.0,
        growable: false,
      );

      if (isProcessComponent) {
        componentValues[componentIndex] = normalized[index];
      } else {
        componentValues[0] = normalized[index];
      }

      final componentRgb = componentSpace.toRGB(componentValues);
      rgb[0] *= componentRgb[0];
      rgb[1] *= componentRgb[1];
      rgb[2] *= componentRgb[2];
    }

    final result = List<double>.from(rgb, growable: false);
    _attributesRgbCache[key] = result;
    return List<double>.from(result, growable: false);
  }

  List<double> _toRGBWithTintTransform(
    List<double> normalized, {
    String? cacheKey,
  }) {
    final key = cacheKey ?? _cacheKey(normalized);
    final cached = _rgbCache[key];
    if (cached != null) {
      return List<double>.from(cached, growable: false);
    }
    final converted = _tintTransform.eval(normalized);
    final rgb = _alternateColorSpace.toRGB(converted);
    final result = List<double>.from(rgb, growable: false);
    _rgbCache[key] = result;
    return List<double>.from(result, growable: false);
  }

  List<double> _normalizeInput(List<double> value) {
    final normalized =
        List<double>.filled(numberOfComponents, 0.0, growable: false);
    _normalizeInto(value, normalized);
    return normalized;
  }

  void _normalizeInto(List<double> value, List<double> target) {
    for (var index = 0; index < numberOfComponents; ++index) {
      final component = index < value.length ? value[index] : 0.0;
      target[index] = PDColorMath.clampUnit(component);
    }
  }

  String _cacheKey(List<double> components) {
    final buffer = StringBuffer();
    for (var i = 0; i < components.length; ++i) {
      if (i > 0) {
        buffer.write('#');
      }
      buffer.write((components[i] * 255).round());
    }
    return buffer.toString();
  }

  static List<String> _parseColorantNames(COSBase? base) {
    if (base is COSArray) {
      final names = <String>[];
      for (final element in base) {
        if (element is COSName) {
          names.add(element.name);
        }
      }
      if (names.isNotEmpty) {
        return names;
      }
    }
    throw StateError(
        'DeviceN colour space requires an array of colourant names');
  }

  static _DeviceNConversionCache? _buildConversionCache(
    List<String> colorantNames,
    PDDeviceNAttributes? attributes,
    PDResources? resources,
  ) {
    if (attributes == null) {
      return null;
    }

    final spotColorants = attributes.getColorants(resources: resources);
    final spotColorSpaces = List<PDSeparation?>.filled(
      colorantNames.length,
      null,
      growable: false,
    );

    final PDDeviceNProcess? process =
        attributes.getProcess(resources: resources);
    final PDColorSpace? processColorSpace =
        process?.getColorSpace(resources: resources);
    final List<String> processComponents =
        process?.getComponents() ?? const <String>[];

    final colorantToComponent = List<int>.filled(
      colorantNames.length,
      -1,
      growable: false,
    );

    if (processColorSpace != null && processComponents.isNotEmpty) {
      for (var index = 0; index < colorantNames.length; ++index) {
        colorantToComponent[index] =
            processComponents.indexOf(colorantNames[index]);
      }
    }

    for (var index = 0; index < colorantNames.length; ++index) {
      final name = colorantNames[index];
      final spot = spotColorants[name];
      if (spot != null) {
        spotColorSpaces[index] = spot;
        if (!attributes.isNChannel) {
          colorantToComponent[index] = -1;
        }
      }
    }

    if (processColorSpace == null && spotColorants.isEmpty) {
      return null;
    }

    return _DeviceNConversionCache(
      colorantToComponent: colorantToComponent,
      processColorSpace: processColorSpace,
      spotColorSpaces: spotColorSpaces,
    );
  }

  @override
  String toString() => 'DeviceN(${colorantNames.join(', ')})';

  int _channel(double component) {
    final clamped = component.clamp(0.0, 1.0);
    final scaled = (clamped * 255.0).round();
    if (scaled < 0) {
      return 0;
    }
    if (scaled > 255) {
      return 255;
    }
    return scaled;
  }
}

class _DeviceNConversionCache {
  const _DeviceNConversionCache({
    required this.colorantToComponent,
    required this.processColorSpace,
    required this.spotColorSpaces,
  });

  final List<int> colorantToComponent;
  final PDColorSpace? processColorSpace;
  final List<PDSeparation?> spotColorSpaces;
}
