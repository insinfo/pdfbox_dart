import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_name.dart';
import 'pd_acro_form.dart';
import 'pd_choice.dart';
import 'pd_non_terminal_field.dart';

/// A combo box consisting of a drop-down list.
/// May be accompanied by an editable text box in which non-predefined values may be entered.
class PDComboBox extends PDChoice {
  static const int FLAG_EDIT = 1 << 18;

  PDComboBox(
      PDAcroForm acroForm, COSDictionary dictionary, PDNonTerminalField? parent)
      : super(acroForm, dictionary, parent) {
    isCombo = true;
  }

  /// Determines if Edit is set.
  bool get isEdit => cosObject.getFlag(COSName.ff, FLAG_EDIT);

  /// Set the Edit bit.
  set isEdit(bool edit) => cosObject.setFlag(COSName.ff, FLAG_EDIT, edit);
}
