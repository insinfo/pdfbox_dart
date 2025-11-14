import '../../../cos/cos_base.dart';
import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_name.dart';
import '../../../cos/cos_string.dart';
import 'pd_action.dart';
import '../../common/pd_destination.dart';

/// Represents a /GoTo action referencing a destination within the document.
class PDActionGoTo extends PDAction {
  PDActionGoTo({COSDictionary? dictionary})
      : super(dictionary ?? COSDictionary()) {
    subtype = 'GoTo';
  }

  static PDActionGoTo? fromCOS(COSBase? base) {
    final dict = PDAction.dictionaryFrom(base);
    if (dict == null) {
      return null;
    }
    final subtype = dict.getNameAsString(COSName.s);
    if (subtype != null && subtype != 'GoTo') {
      return null;
    }
    return PDActionGoTo(dictionary: dict);
  }

  PDDestination? get destination =>
      PDDestination.fromCOS(cosObject.getDictionaryObject(COSName.d));

  set destination(PDDestination? value) =>
      cosObject.setItem(COSName.d, value?.cosObject);

  /// Convenience accessor for named destinations stored directly in `/D`.
  String? get destinationName {
    final base = cosObject.getDictionaryObject(COSName.d);
    if (base is COSName) {
      return base.name;
    }
    if (base is COSString) {
      return base.string;
    }
    return null;
  }

  set destinationName(String? value) {
    if (value == null) {
      cosObject.removeItem(COSName.d);
    } else {
      cosObject.setString(COSName.d, value);
    }
  }
}
