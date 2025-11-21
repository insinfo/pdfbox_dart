import '../../../cos/cos_base.dart';
import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_name.dart';

import '../../../cos/cos_stream.dart';
import 'pd_appearance_stream.dart';

/// An entry in an appearance dictionary. May contain either a single appearance stream or an appearance subdictionary.
class PDAppearanceEntry implements COSObjectable {
  final COSBase _entry;

  PDAppearanceEntry(this._entry);

  @override
  COSBase get cosObject => _entry;

  /// Returns true if this entry is an appearance subdictionary.
  bool get isSubDictionary => !(_entry is COSStream);

  /// Returns true if this entry is an appearance stream.
  bool get isStream => _entry is COSStream;

  /// Returns the entry as an appearance stream.
  PDAppearanceStream get appearanceStream {
    if (!isStream) {
      throw StateError('This entry is not an appearance stream');
    }
    return PDAppearanceStream(_entry as COSStream);
  }

  /// Returns the entry as an appearance subdictionary.
  Map<COSName, PDAppearanceStream> get subDictionary {
    if (!isSubDictionary) {
      throw StateError('This entry is not an appearance subdictionary');
    }

    final dict = _entry as COSDictionary;
    final map = <COSName, PDAppearanceStream>{};

    for (final key in dict.keys) {
      final stream = dict.getCOSStream(key);
      if (stream != null) {
        map[key] = PDAppearanceStream(stream);
      }
    }
    return map;
  }
}

/// An appearance dictionary specifying how the annotation shall be presented visually on the page.
class PDAppearanceDictionary implements COSObjectable {
  final COSDictionary _dictionary;

  /// Constructor for embedding.
  PDAppearanceDictionary([COSDictionary? dictionary])
      : _dictionary = dictionary ?? COSDictionary() {
    if (dictionary == null) {
      _dictionary.setItem(COSName.n, COSDictionary());
    }
  }

  @override
  COSDictionary get cosObject => _dictionary;

  /// This will return a list of appearances. In the case where there is only one appearance the map will contain one
  /// entry whose key is the string "default".
  PDAppearanceEntry? get normalAppearance {
    final entry = _dictionary.getDictionaryObject(COSName.n);
    return entry != null ? PDAppearanceEntry(entry) : null;
  }

  /// This will set a list of appearances. If you would like to set the single appearance then you should use the key
  /// "default", and when the PDF is written back to the filesystem then there will only be one stream.
  set normalAppearance(PDAppearanceEntry? entry) {
    _dictionary.setItem(COSName.n, entry);
  }

  /// This will set the normal appearance when there is only one appearance to be shown.
  void setNormalAppearanceStream(PDAppearanceStream ap) {
    _dictionary.setItem(COSName.n, ap);
  }

  /// This will return a list of appearances. In the case where there is only one appearance the map will contain one
  /// entry whose key is the string "default". If there is no rollover appearance then the normal appearance will be
  /// returned. Which means that this method will never return null.
  PDAppearanceEntry? get rolloverAppearance {
    final entry = _dictionary.getDictionaryObject(COSName.r);
    return entry != null ? PDAppearanceEntry(entry) : normalAppearance;
  }

  /// This will set a list of appearances. If you would like to set the single appearance then you should use the key
  /// "default", and when the PDF is written back to the filesystem then there will only be one stream.
  set rolloverAppearance(PDAppearanceEntry? entry) {
    _dictionary.setItem(COSName.r, entry);
  }

  /// This will set the rollover appearance when there is rollover appearance to be shown.
  void setRolloverAppearanceStream(PDAppearanceStream ap) {
    _dictionary.setItem(COSName.r, ap);
  }

  /// This will return a list of appearances. In the case where there is only one appearance the map will contain one
  /// entry whose key is the string "default". If there is no rollover appearance then the normal appearance will be
  /// returned. Which means that this method will never return null.
  PDAppearanceEntry? get downAppearance {
    final entry = _dictionary.getDictionaryObject(COSName.d);
    return entry != null ? PDAppearanceEntry(entry) : normalAppearance;
  }

  /// This will set a list of appearances. If you would like to set the single appearance then you should use the key
  /// "default", and when the PDF is written back to the filesystem then there will only be one stream.
  set downAppearance(PDAppearanceEntry? entry) {
    _dictionary.setItem(COSName.d, entry);
  }

  /// This will set the down appearance when there is down appearance to be shown.
  void setDownAppearanceStream(PDAppearanceStream ap) {
    _dictionary.setItem(COSName.d, ap);
  }
}
