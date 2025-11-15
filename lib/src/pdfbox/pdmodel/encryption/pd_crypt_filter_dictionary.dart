import '../../cos/cos_base.dart';
import '../../cos/cos_boolean.dart';
import '../../cos/cos_dictionary.dart';
import '../../cos/cos_name.dart';

/// Dart port of PDFBox's `PDCryptFilterDictionary` helper.
class PDCryptFilterDictionary implements COSObjectable {
  PDCryptFilterDictionary([COSDictionary? dictionary])
      : _dictionary = dictionary ?? COSDictionary();

  final COSDictionary _dictionary;

  @override
  @override
  COSDictionary get cosObject => _dictionary;

  set length(int value) => _dictionary.setInt(COSName.length, value);

  int get length => _dictionary.getInt(COSName.length, 40) ?? 40;

  void setCryptFilterMethod(COSName? method) {
    if (method == null) {
      _dictionary.removeItem(COSName.cfm);
    } else {
      _dictionary.setItem(COSName.cfm, method);
    }
  }

  COSName? get cryptFilterMethod => _dictionary.getCOSName(COSName.cfm);

  bool get encryptMetaData {
    final value = _dictionary.getDictionaryObject(COSName.encryptMetadata);
    if (value is COSBoolean) {
      return value.value;
    }
    return true;
  }

  set encryptMetaData(bool value) =>
      _dictionary.setBoolean(COSName.encryptMetadata, value);
}
