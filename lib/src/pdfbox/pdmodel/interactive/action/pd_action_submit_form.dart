import '../../../cos/cos_array.dart';
import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_name.dart';
import '../../common/pd_file_specification.dart';

import 'pd_action.dart';

/// This represents a Submit-Form action that can be executed in a PDF document.
class PDActionSubmitForm extends PDAction {
  /// This type of action this object represents.
  static const String subType = 'SubmitForm';

  /// Default constructor.
  PDActionSubmitForm() {
    setSubType(subType);
  }

  /// Constructor from an existing dictionary.
  PDActionSubmitForm.fromDictionary(COSDictionary a) : super.fromDictionary(a);

  /// This will get the file in which the destination is located.
  ///
  /// @return The F entry of the specific Submit-Form action dictionary.
  PDFileSpecification? getFile() {
    return PDFileSpecification.createFS(action.getDictionaryObject(COSName.f));
  }

  /// This will set the file in which the destination is located.
  ///
  /// @param fs The file specification.
  void setFile(PDFileSpecification? fs) {
    action.setItem(COSName.f, fs);
  }

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
