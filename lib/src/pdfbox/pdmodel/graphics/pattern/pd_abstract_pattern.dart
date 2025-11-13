import '../../../cos/cos_base.dart';
import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_name.dart';
import '../../pd_resources.dart';
import '../shading/pd_shading.dart';

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
    final shadingDictionary = cosObject.getCOSDictionary(COSName.shading);
    if (shadingDictionary == null) {
      return null;
    }
    return PDShading.create(shadingDictionary, resources: resources);
  }
}

/// Placeholder for pattern types that do not yet have a dedicated wrapper.
class PDUnknownPattern extends PDAbstractPattern {
  PDUnknownPattern(COSDictionary dictionary, {PDResources? resources})
      : super(dictionary, resources: resources);
}
