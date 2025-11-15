import '../../cos/cos_dictionary.dart';
import '../../cos/cos_name.dart';
import '../../cos/cos_string.dart';

/// Wrapper for a PDF encryption dictionary (ISO 32000-1, Table 20).
class PDEncryption {
  PDEncryption(this._dictionary);

  final COSDictionary _dictionary;

  COSDictionary get cosObject => _dictionary;

  String? get filter => _dictionary.getNameAsString(COSName.filter);

  set filter(String? value) => _setName(COSName.filter, value);

  String? get subFilter => _dictionary.getNameAsString(COSName.subFilter);

  set subFilter(String? value) => _setName(COSName.subFilter, value);

  int? get version => _dictionary.getInt(COSName.v);

  set version(int? value) => _dictionary.setInt(COSName.v, value);

  int? get revision => _dictionary.getInt(COSName.r);

  set revision(int? value) => _dictionary.setInt(COSName.r, value);

  int? get length => _dictionary.getInt(COSName.length);

  set length(int? value) => _dictionary.setInt(COSName.length, value);

  int? get permissions => _dictionary.getInt(COSName.p);

  set permissions(int? value) => _dictionary.setInt(COSName.p, value);

  bool get encryptMetadata =>
      _dictionary.getBoolean(COSName.encryptMetadata, true) ?? true;

  set encryptMetadata(bool value) =>
      _dictionary.setBoolean(COSName.encryptMetadata, value);

  COSDictionary? get cfDictionary =>
      _dictionary.getCOSDictionary(COSName.cf);

  set cfDictionary(COSDictionary? value) =>
      _dictionary.setItem(COSName.cf, value);

  COSName? get streamFilter => _dictionary.getCOSName(COSName.stmf);

  set streamFilter(COSName? value) =>
      _dictionary.setItem(COSName.stmf, value);

  COSName? get stringFilter => _dictionary.getCOSName(COSName.strf);

  set stringFilter(COSName? value) =>
      _dictionary.setItem(COSName.strf, value);

  COSName? get embeddedFileFilter => _dictionary.getCOSName(COSName.eff);

  set embeddedFileFilter(COSName? value) =>
      _dictionary.setItem(COSName.eff, value);

  COSString? get ownerValue =>
      _dictionary.getDictionaryObject(COSName.o) as COSString?;

  set ownerValue(COSString? value) =>
      _dictionary.setItem(COSName.o, value);

  COSString? get userValue =>
      _dictionary.getDictionaryObject(COSName.u) as COSString?;

  set userValue(COSString? value) =>
      _dictionary.setItem(COSName.u, value);

  COSString? get ownerEncryption =>
      _dictionary.getDictionaryObject(COSName.oe) as COSString?;

  set ownerEncryption(COSString? value) =>
      _dictionary.setItem(COSName.oe, value);

  COSString? get userEncryption =>
      _dictionary.getDictionaryObject(COSName.ue) as COSString?;

  set userEncryption(COSString? value) =>
      _dictionary.setItem(COSName.ue, value);

  COSString? get perms =>
      _dictionary.getDictionaryObject(COSName.perms) as COSString?;

  set perms(COSString? value) => _dictionary.setItem(COSName.perms, value);

  void _setName(COSName key, String? value) {
    if (value == null) {
      _dictionary.removeItem(key);
    } else {
      _dictionary.setName(key, value);
    }
  }
}
