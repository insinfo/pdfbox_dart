import '../../../cos/cos_base.dart';
import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_name.dart';
import '../../common/pd_file_specification.dart';
import 'pd_action.dart';

/// Represents a /Launch action used to open files or applications.
class PDActionLaunch extends PDAction {
  PDActionLaunch({COSDictionary? dictionary})
      : super(dictionary ?? COSDictionary()) {
    subtype = 'Launch';
  }

  static PDActionLaunch? fromCOS(COSBase? base) {
    final dict = PDAction.dictionaryFrom(base);
    if (dict == null) {
      return null;
    }
    final subtype = dict.getNameAsString(COSName.s);
    if (subtype != null && subtype != 'Launch') {
      return null;
    }
    return PDActionLaunch(dictionary: dict);
  }

  PDFileSpecification? get file =>
      PDFileSpecification.fromCOS(getDictionaryObject(COSName.f));

  set file(PDFileSpecification? value) =>
      setItem(COSName.f, value?.cosObject);

    /// Convenience accessor when `/F` is stored as a bare string.
    String? get fileName => cosObject.getString(COSName.f);

    set fileName(String? value) => cosObject.setString(COSName.f, value);

  bool get newWindow => getBoolean(COSName.newWindow, false) ?? false;

  set newWindow(bool value) => setBoolean(COSName.newWindow, value);

  COSDictionary? get windowsLaunchParams => getCOSDictionary(COSName.win);

  set windowsLaunchParams(COSDictionary? value) => setItem(COSName.win, value);
}
