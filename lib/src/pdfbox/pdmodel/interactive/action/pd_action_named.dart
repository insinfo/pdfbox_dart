import '../../../cos/cos_base.dart';
import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_name.dart';
import 'pd_action.dart';

/// Represents a /Named action (ISO 32000-1, Table 38).
class PDActionNamed extends PDAction {
  PDActionNamed({COSDictionary? dictionary})
      : super(dictionary ?? COSDictionary()) {
    subtype = 'Named';
  }

  static PDActionNamed? fromCOS(COSBase? base) {
    final dict = PDAction.dictionaryFrom(base);
    if (dict == null) {
      return null;
    }
    final subtype = dict.getNameAsString(COSName.s);
    if (subtype != null && subtype != 'Named') {
      return null;
    }
    return PDActionNamed(dictionary: dict);
  }

  /// Returns the named action identifier stored in the `/N` entry.
  String? get namedAction => cosObject.getString(COSName.n);

  set namedAction(String? value) {
    if (value == null) {
      cosObject.removeItem(COSName.n);
    } else {
      // Named actions are name objects; storing as COSName matches Java implementation.
      cosObject.setName(COSName.n, value);
    }
  }
}
