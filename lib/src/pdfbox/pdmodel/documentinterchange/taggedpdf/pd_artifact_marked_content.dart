import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_name.dart';
import '../../common/pd_rectangle.dart';
import '../markedcontent/pd_marked_content.dart';

class PDArtifactMarkedContent extends PDMarkedContent {
  PDArtifactMarkedContent(COSDictionary properties)
      : super(COSName('Artifact'), properties);

  String? get type => properties?.getNameAsString(COSName.type);

  PDRectangle? get bbox {
    final array = properties?.getCOSArray(COSName.bBox);
    if (array == null) {
      return null;
    }
    return PDRectangle.fromCOSArray(array);
  }

  bool get isTopAttached => _isAttached('Top');

  bool get isBottomAttached => _isAttached('Bottom');

  bool get isLeftAttached => _isAttached('Left');

  bool get isRightAttached => _isAttached('Right');

  String? get subtype => properties?.getNameAsString(COSName.subtype);

  bool _isAttached(String edge) {
    final attached = properties?.getCOSArray(COSName.attached);
    if (attached == null) {
      return false;
    }
    for (final item in attached) {
      if (item is COSName && item.name == edge) {
        return true;
      }
    }
    return false;
  }
}

