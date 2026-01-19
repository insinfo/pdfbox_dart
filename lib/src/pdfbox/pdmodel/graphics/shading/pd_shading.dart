import 'dart:math' as math;

import 'package:dart_graphics/dart_graphics.dart' show Affine;
import 'package:pdfbox_dart/src/pdfbox/pdmodel/graphics/color/pd_color_space.dart';

import '../../../cos/cos_base.dart';
import '../../../cos/cos_array.dart';
import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_float.dart';
import '../../../cos/cos_name.dart';
import '../../../cos/cos_stream.dart';

import '../../../util/matrix.dart';
import '../../common/function/pdf_function.dart';
import '../../common/pd_rectangle.dart';

part 'shaded_triangle.dart';
part 'pd_triangle_based_shading_type.dart';
part 'patch.dart';
part 'pd_mesh_based_shading_type.dart';
part 'pd_shading_type1.dart';
part 'pd_shading_type2.dart';
part 'pd_shading_type3.dart';
part 'pd_shading_type4.dart';
part 'pd_shading_type5.dart';
part 'pd_shading_type6.dart';
part 'pd_shading_type7.dart';

/// Base wrapper for shading resources.
class PDShading {
  PDShading(this._dictionary, {dynamic resources}) : _resources = resources;

  final COSDictionary _dictionary;
  final dynamic _resources;

  COSDictionary get cosObject => _dictionary;

  int get shadingType => _dictionary.getInt(COSName.shadingType) ?? 0;

  /// Optional background color used when Extend is false.
  COSArray? get background => _dictionary.getCOSArray(COSName.background);

  /// Optional bounding box restricting where the shading is painted.
  PDRectangle? get bbox {
    final COSBase? value = _dictionary.getDictionaryObject(COSName.bBox);
    if (value is COSArray) {
      return PDRectangle.fromCOSArray(value);
    }
    return null;
  }

  PDColorSpace? get colorSpace {
    final COSBase? value = _dictionary.getDictionaryObject(COSName.colorSpace);
    if (value == null) {
      return null;
    }
    return PDColorSpace.create(value, resources: _resources);
  }

  /// Creates a shading wrapper for the provided dictionary.
  static PDShading create(COSDictionary dictionary, {dynamic resources}) {
    final type = dictionary.getInt(COSName.shadingType) ?? 0;
    switch (type) {
      case 1:
        return PDShadingType1(dictionary, resources: resources);
      case 2:
        return PDShadingType2(dictionary, resources: resources);
      case 3:
        return PDShadingType3(dictionary, resources: resources);
      case 4:
        return PDShadingType4(dictionary, resources: resources);
      case 5:
        return PDShadingType5(dictionary, resources: resources);
      case 6:
        return PDShadingType6(dictionary, resources: resources);
      case 7:
        return PDShadingType7(dictionary, resources: resources);
      default:
        return PDShading(dictionary, resources: resources);
    }
  }
}
