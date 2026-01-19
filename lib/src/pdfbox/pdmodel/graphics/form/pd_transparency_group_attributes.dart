import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_name.dart';
import '../../common/cos_objectable.dart';
import '../../pd_resources.dart';
import '../color/pd_color_space.dart';

/// Transparency group attributes.
class PDTransparencyGroupAttributes implements COSObjectable {
  PDTransparencyGroupAttributes([COSDictionary? dictionary])
      : _dictionary = dictionary ?? COSDictionary() {
    if (dictionary == null) {
      _dictionary.setName(COSName.get('S'), COSName.get('Transparency').name);
    }
  }

  final COSDictionary _dictionary;
  PDColorSpace? _colorSpace;

  @override
  COSDictionary get cosObject => _dictionary;

  /// Returns the group color space or null if it isn't defined.
  PDColorSpace? getColorSpace({PDResources? resources}) {
    if (_colorSpace == null && _dictionary.containsKey(COSName.get('CS'))) {
      final cs = _dictionary.getDictionaryObject(COSName.get('CS'));
      if (cs != null) {
        _colorSpace = PDColorSpace.create(cs, resources: resources);
      }
    }
    return _colorSpace;
  }

  /// Returns true if this group is isolated.
  bool isIsolated() => _dictionary.getBoolean(COSName.get('I')) ?? false;

  /// Returns true if this group is a knockout.
  bool isKnockout() => _dictionary.getBoolean(COSName.get('K')) ?? false;
}
