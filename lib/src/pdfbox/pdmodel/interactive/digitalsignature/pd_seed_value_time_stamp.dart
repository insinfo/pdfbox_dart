import '../../../cos/cos_base.dart';
import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_name.dart';

/// Represents the timestamp configuration inside a signature seed value.
class PDSeedValueTimeStamp implements COSObjectable {
  PDSeedValueTimeStamp([COSDictionary? dictionary])
      : _dictionary = dictionary ?? _createDictionary() {
    if (dictionary != null) {
      _dictionary.isDirect = true;
    }
  }

  final COSDictionary _dictionary;

  @override
  COSDictionary get cosObject => _dictionary;

  String? get url => _dictionary.getString(COSName.url);

  void setUrl(String? value) => _dictionary.setString(COSName.url, value);

  bool get timestampRequired => (_dictionary.getInt(COSName.ft) ?? 0) != 0;

  void setTimestampRequired(bool value) =>
      _dictionary.setInt(COSName.ft, value ? 1 : 0);

  String? getURL() => url;

  void setURL(String? value) => setUrl(value);

  bool isTimestampRequired() => timestampRequired;

  static COSDictionary _createDictionary() {
    final dict = COSDictionary();
    dict.isDirect = true;
    return dict;
  }
}