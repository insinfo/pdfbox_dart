import '../../../cos/cos_base.dart';
import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_name.dart';
import '../../common/pd_dictionary_wrapper.dart';
import 'pd_user_attribute_object.dart';

class PDUserProperty extends PDDictionaryWrapper {
  PDUserProperty(this._userAttributeObject) : super();

  PDUserProperty.fromDictionary(
    COSDictionary dictionary,
    this._userAttributeObject,
  ) : super(dictionary);

  final PDUserAttributeObject _userAttributeObject;

  String? get name => cosObject.getNameAsString(COSName.n);

  set name(String? value) {
    _potentiallyNotifyChanged(name, value);
    cosObject.setName(COSName.n, value);
  }

  COSBase? get value => cosObject.getDictionaryObject(COSName.v);

  set value(COSBase? newValue) {
    _potentiallyNotifyChanged(value, newValue);
    cosObject.setItem(COSName.v, newValue);
  }

  String? get formattedValue => cosObject.getString(COSName.f);

  set formattedValue(String? newValue) {
    _potentiallyNotifyChanged(formattedValue, newValue);
    cosObject.setString(COSName.f, newValue);
  }

  bool get isHidden => cosObject.getBoolean(COSName.h, false) ?? false;

  set isHidden(bool value) {
    _potentiallyNotifyChanged(isHidden, value);
    cosObject.setBoolean(COSName.h, value);
  }

  void _potentiallyNotifyChanged(Object? oldEntry, Object? newEntry) {
    if (_isEntryChanged(oldEntry, newEntry)) {
      _userAttributeObject.userPropertyChanged(this);
    }
  }

  bool _isEntryChanged(Object? oldEntry, Object? newEntry) {
    if (oldEntry == null) {
      return newEntry != null;
    }
    return oldEntry != newEntry;
  }

  @override
  String toString() {
    return 'Name=$name, Value=$value, FormattedValue=$formattedValue, Hidden=$isHidden';
  }
}

