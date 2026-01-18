import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_name.dart';
import '../../common/cos_objectable.dart';

/// Provides additional information about tagged/structured PDFs.
class PDMarkInfo implements COSObjectable {
  PDMarkInfo() : _dictionary = COSDictionary();

  PDMarkInfo.fromDictionary(this._dictionary);

  static final COSName _marked = COSName('Marked');
  static final COSName _userProperties = COSName('UserProperties');
  static final COSName _suspects = COSName('Suspects');

  final COSDictionary _dictionary;

  @override
  COSDictionary get cosObject => _dictionary;

  bool get isMarked => _dictionary.getBoolean(_marked, false) ?? false;

  set isMarked(bool value) => _dictionary.setBoolean(_marked, value);

  bool get usesUserProperties =>
      _dictionary.getBoolean(_userProperties, false) ?? false;

  set usesUserProperties(bool value) =>
      _dictionary.setBoolean(_userProperties, value);

  bool get isSuspect => _dictionary.getBoolean(_suspects, false) ?? false;

  set isSuspect(bool value) => _dictionary.setBoolean(_suspects, value);
}
