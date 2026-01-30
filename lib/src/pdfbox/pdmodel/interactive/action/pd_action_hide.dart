import '../../../cos/cos_base.dart';
import '../../../cos/cos_boolean.dart';
import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_name.dart';

import 'pd_action.dart';

/// This represents a hide action that can be executed in a PDF document.
class PDActionHide extends PDAction {
  /// This type of action this object represents.
  static const String subType = 'Hide';

  /// Default constructor.
  PDActionHide() {
    setSubType(subType);
  }

  /// Constructor from an existing dictionary.
  PDActionHide.fromDictionary(COSDictionary a) : super(a);

  /// The annotation or annotations to be hidden or shown.
  ///
  /// @return The T entry of the specific hide action dictionary.
  COSBase? getT() {
    // Dictionary, String or Array
    return dictionary.getDictionaryObject(COSName.t);
  }

  /// Sets the annotation or annotations to be hidden or shown.
  ///
  /// @param t annotation or annotations
  void setT(COSBase? t) {
    dictionary.setItem(COSName.t, t);
  }

  /// A flag indicating whether to hide the annotation or show it.
  ///
  /// @return true if annotation is hidden
  bool getH() {
    return dictionary.getBoolean(COSName.h, true) ?? true;
  }

  /// Sets the hide flag.
  ///
  /// @param h hide flag
  void setH(bool h) {
    dictionary.setItem(COSName.h, COSBoolean.valueOf(h));
  }
}
