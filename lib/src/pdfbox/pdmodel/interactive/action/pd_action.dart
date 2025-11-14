import '../../../cos/cos_base.dart' show COSBase, COSObjectable;
import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_name.dart';
import '../../../cos/cos_object.dart';

/// Base class for PDF actions.
abstract class PDAction implements COSObjectable {
  PDAction(COSDictionary dictionary) : _dictionary = dictionary;

  final COSDictionary _dictionary;

  @override
  COSDictionary get cosObject => _dictionary;

  String? get subtype => _dictionary.getNameAsString(COSName.s);

  set subtype(String? value) => _dictionary.setName(COSName.s, value);

    COSBase? getDictionaryObject(COSName name) =>
      _dictionary.getDictionaryObject(name);

    COSDictionary? getCOSDictionary(COSName name) =>
      _dictionary.getCOSDictionary(name);

    void setItem(COSName name, COSObjectable? value) =>
      _dictionary.setItem(name, value);

    bool? getBoolean(COSName name, [bool? defaultValue]) =>
      _dictionary.getBoolean(name, defaultValue);

    void setBoolean(COSName name, bool value) =>
      _dictionary.setBoolean(name, value);

    void removeItem(COSName name) => _dictionary.removeItem(name);

  static COSDictionary? dictionaryFrom(COSBase? base) {
    if (base == null) {
      return null;
    }
    if (base is COSDictionary) {
      return base;
    }
    if (base is COSObject) {
      final target = base.object;
      return target is COSDictionary ? target : null;
    }
    return null;
  }
}
