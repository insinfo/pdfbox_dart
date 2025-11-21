import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_name.dart';
import '../../../cos/cos_base.dart';

/// A marked-content reference dictionary denoting a marked-content sequence.
class PDMarkedContentReference implements COSObjectable {
  static const String TYPE = 'MCR';

  final COSDictionary _dictionary;

  PDMarkedContentReference([COSDictionary? dictionary])
      : _dictionary = dictionary ?? COSDictionary() {
    if (dictionary == null) {
      _dictionary[COSName.type] = COSName(TYPE);
    }
  }

  @override
  COSDictionary get cosObject => _dictionary;
}
