import '../../../cos/cos_base.dart';
import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_name.dart';
import '../color/pd_color_space.dart';

/// Base wrapper for shading resources.
class PDShading {
  PDShading(this._dictionary, {dynamic resources}) : _resources = resources;

  final COSDictionary _dictionary;
  final dynamic _resources;

  COSDictionary get cosObject => _dictionary;

  int get shadingType => _dictionary.getInt(COSName.shadingType) ?? 0;

  PDColorSpace? get colorSpace {
    final COSBase? value = _dictionary.getDictionaryObject(COSName.colorSpace);
    if (value == null) {
      return null;
    }
    return PDColorSpace.create(value, resources: _resources);
  }

  /// Creates a shading wrapper for the provided dictionary.
  static PDShading create(COSDictionary dictionary, {dynamic resources}) =>
      PDShading(dictionary, resources: resources);
}
