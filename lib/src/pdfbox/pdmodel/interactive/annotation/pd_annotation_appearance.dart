import '../../../cos/cos_base.dart';
import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_name.dart';
import '../../../cos/cos_object.dart';
import '../../../cos/cos_stream.dart';

class PDAppearanceEntry {
  PDAppearanceEntry._(this._base);

  final COSBase _base;

  COSBase get base => _base;

  COSDictionary? get dictionary {
    final resolved = _resolve(_base);
    return resolved is COSDictionary ? resolved : null;
  }

  COSStream? get stream {
    final resolved = _resolve(_base);
    return resolved is COSStream ? resolved : null;
  }

  static COSBase _resolve(COSBase base) =>
      base is COSObject ? base.object : base;

  static PDAppearanceEntry? fromCOS(COSBase? base) {
    if (base == null) {
      return null;
    }
    return PDAppearanceEntry._(base);
  }
}

class PDAppearanceDictionary implements COSObjectable {
  PDAppearanceDictionary(this._dictionary);

  final COSDictionary _dictionary;

  @override
  COSDictionary get cosObject => _dictionary;

  PDAppearanceEntry? get normal =>
      PDAppearanceEntry.fromCOS(_dictionary.getDictionaryObject(COSName.n));

  PDAppearanceEntry? get rollover =>
      PDAppearanceEntry.fromCOS(_dictionary.getDictionaryObject(COSName.r));

  PDAppearanceEntry? get down =>
      PDAppearanceEntry.fromCOS(_dictionary.getDictionaryObject(COSName.d));
}
