import '../../../cos/cos_array.dart';
import '../../../cos/cos_base.dart' show COSObjectable;
import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_name.dart';
import '../../../cos/cos_string.dart';

/// General build information about the software that created a signature.
class PDPropBuildDataDict implements COSObjectable {  // ignore: prefer-match-file-name
  PDPropBuildDataDict([COSDictionary? dictionary])
      : _dictionary = dictionary ?? COSDictionary() {
    _dictionary.isDirect = true; // Specification recommends direct objects.
  }

  final COSDictionary _dictionary;

  @override
  COSDictionary get cosObject => _dictionary;

  String? get name => _dictionary.getNameAsString(COSName.nameKey);

  void setName(String? value) {
    if (value == null) {
      _dictionary.removeItem(COSName.nameKey);
    } else {
      _dictionary.setName(COSName.nameKey, value);
    }
  }

  String? get date => _dictionary.getString(COSName.date);

  void setDate(String? value) => _dictionary.setString(COSName.date, value);

  static final COSName _rexKey = COSName.get('REx');

  String? get version => _dictionary.getString(_rexKey);

  void setVersion(String? value) => _dictionary.setString(_rexKey, value);

  int? get revision => _dictionary.getInt(COSName.r);

  void setRevision(int? value) => _dictionary.setInt(COSName.r, value);

  int? get minimumRevision => _dictionary.getInt(COSName.v);

  void setMinimumRevision(int? value) => _dictionary.setInt(COSName.v, value);

  bool get preRelease => _dictionary.getBoolean(COSName.preRelease, false) ?? false;

  void setPreRelease(bool value) => _dictionary.setBoolean(COSName.preRelease, value);

  String? get os {
    final array = _dictionary.getCOSArray(COSName.os);
    if (array != null && array.isNotEmpty) {
      final entry = array[0];
      if (entry is COSName) {
        return entry.name;
      }
      if (entry is COSString) {
        return entry.string;
      }
    }
    return _dictionary.getString(COSName.os);
  }

  void setOs(String? value) {
    if (value == null) {
      _dictionary.removeItem(COSName.os);
      return;
    }
    var array = _dictionary.getCOSArray(COSName.os);
    if (array == null) {
      array = COSArray()
        ..isDirect = true;
      _dictionary[COSName.os] = array;
    }
    final cosName = COSName.get(value);
    if (array.isEmpty) {
      array.addObject(cosName);
    } else {
      array[0] = cosName;
    }
  }

  String? getOS() => os;

  void setOS(String? value) => setOs(value);

  bool get nonEFontNoWarn =>
      _dictionary.getBoolean(COSName.nonEFontNoWarn, true) ?? true;

  void setNonEFontNoWarn(bool value) =>
      _dictionary.setBoolean(COSName.nonEFontNoWarn, value);

  bool get trustedMode =>
      _dictionary.getBoolean(COSName.trustedMode, false) ?? false;

  void setTrustedMode(bool value) =>
      _dictionary.setBoolean(COSName.trustedMode, value);

  COSDictionary toCOSDictionary() => _dictionary;
}