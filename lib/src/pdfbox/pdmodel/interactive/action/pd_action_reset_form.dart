import '../../../cos/cos_array.dart';
import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_name.dart';

import 'pd_action.dart';

/// This represents a ResetForm action that can be executed in a PDF document.
class PDActionResetForm extends PDAction {
  /// This type of action this object represents.
  static const String subType = 'ResetForm';

  /// Default constructor.
  PDActionResetForm() {
    setSubType(subType);
  }

  /// Constructor from an existing dictionary.
  PDActionResetForm.fromDictionary(COSDictionary a) : super.fromDictionary(a);

  /// An array identifying which fields to include in the submission or which 
  /// to exclude, depending on the setting of the Include/Exclude flag in 
  /// the Flags entry.
  ///
  /// @return the array of fields
  COSArray? getFields() {
    return action.getCOSArray(COSName.fields);
  }

  /// Sets the array of fields.
  ///
  /// @param array the array of fields
  void setFields(COSArray? array) {
    action.setItem(COSName.fields, array);
  }

  /// A set of flags specifying various characteristics of the action.
  ///
  /// @return the flags
  int getFlags() {
    return action.getInt(COSName.flags, 0) ?? 0;
  }

  /// Sets the flags.
  ///
  /// @param flags the flags
  void setFlags(int flags) {
    action.setInt(COSName.flags, flags);
  }
}
