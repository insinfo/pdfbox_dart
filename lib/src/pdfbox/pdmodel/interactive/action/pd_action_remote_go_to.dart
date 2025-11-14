import '../../../cos/cos_base.dart';
import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_name.dart';
import '../../../cos/cos_string.dart';
import '../../common/pd_destination.dart';
import '../../common/pd_file_specification.dart';
import 'pd_action.dart';

/// Represents a /GoToR action that jumps to a destination in an external PDF.
class PDActionRemoteGoTo extends PDAction {
  PDActionRemoteGoTo({COSDictionary? dictionary})
      : super(dictionary ?? COSDictionary()) {
    subtype = 'GoToR';
  }

  static PDActionRemoteGoTo? fromCOS(COSBase? base) {
    final dict = PDAction.dictionaryFrom(base);
    if (dict == null) {
      return null;
    }
    final subtype = dict.getNameAsString(COSName.s);
    if (subtype != null && subtype != 'GoToR') {
      return null;
    }
    return PDActionRemoteGoTo(dictionary: dict);
  }

  PDFileSpecification? get file =>
      PDFileSpecification.fromCOS(getDictionaryObject(COSName.f));

  set file(PDFileSpecification? value) =>
      setItem(COSName.f, value?.cosObject);

    String? get fileName => cosObject.getString(COSName.f);

    set fileName(String? value) => cosObject.setString(COSName.f, value);

  PDDestination? get destination =>
      PDDestination.fromCOS(getDictionaryObject(COSName.d));

  set destination(PDDestination? value) =>
      setItem(COSName.d, value?.cosObject);

  String? get destinationName {
    final base = getDictionaryObject(COSName.d);
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
      removeItem(COSName.d);
    } else {
      cosObject.setString(COSName.d, value);
    }
  }

  bool get newWindow => getBoolean(COSName.newWindow, false) ?? false;

  set newWindow(bool value) => setBoolean(COSName.newWindow, value);
}
