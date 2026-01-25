import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_name.dart';
import '../../../cos/cos_base.dart';

/// An object reference dictionary denoting a PDF object.
class PDObjectReference implements COSObjectable {
  static const String TYPE = 'OBJR';

  final COSDictionary _dictionary;

  PDObjectReference([COSDictionary? dictionary])
      : _dictionary = dictionary ?? COSDictionary() {
    if (dictionary == null) {
      _dictionary[COSName.type] = COSName(TYPE);
    }
  }

  @override
  COSDictionary get cosObject => _dictionary;
}

