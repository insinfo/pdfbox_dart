import '../../../cos/cos_base.dart';
import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_name.dart';
import '../../../cos/cos_stream.dart';
import '../../pd_resources.dart';
import 'pd_tiling_pattern.dart';
import '../shading/pd_shading.dart';
import '../../../util/matrix.dart';

/// Base class for pattern resources stored in a page or XObject dictionary.
abstract class PDAbstractPattern implements COSObjectable {
  PDAbstractPattern(this._dictionary, {this.resources});

  final COSDictionary _dictionary;
  final PDResources? resources;

  @override
  COSDictionary get cosObject => _dictionary;

  /// Returns the pattern type integer stored in the dictionary.
  int get patternType => _dictionary.getInt(COSName.patternType) ?? 0;

  /// Factory method mirroring PDFBox behaviour for pattern dictionaries.
  static PDAbstractPattern create(
    COSDictionary dictionary, {
    PDResources? resources,
  }) {
    final type = dictionary.getInt(COSName.patternType) ?? 0;
    if (type == 1 && dictionary is COSStream) {
      return PDTilingPattern(dictionary, resources: resources);
    }
    if (type == 2) {
      return PDShadingPattern(dictionary, resources: resources);
    }
    return PDUnknownPattern(dictionary, resources: resources);
  }
}

/// Pattern type 2 – shading pattern wrapper.
class PDShadingPattern extends PDAbstractPattern {
  PDShadingPattern(COSDictionary dictionary, {PDResources? resources})
      : super(dictionary, resources: resources);

  PDShading? get shading {
    final raw = cosObject.getDictionaryObject(COSName.shading);
    if (raw is COSName) {
      return resources?.getShading(raw);
    }
    if (raw is COSDictionary) {
      return PDShading.create(raw, resources: resources);
    }
    return null;
  }

  Matrix get matrix {
    final array = cosObject.getCOSArray(COSName.matrix);
    if (array == null) {
      return Matrix();
    }
    return Matrix.fromCos(array);
  }
}

/// Placeholder for pattern types that do not yet have a dedicated wrapper.
class PDUnknownPattern extends PDAbstractPattern {
  PDUnknownPattern(COSDictionary dictionary, {PDResources? resources})
      : super(dictionary, resources: resources);
}

