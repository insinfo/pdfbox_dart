import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_name.dart';
import 'pd_acro_form.dart';
import 'pd_non_terminal_field.dart';
import 'pd_variable_text.dart';

/// A text field in an interactive form.
class PDTextField extends PDVariableText {
  PDTextField(PDAcroForm acroForm, COSDictionary dictionary, PDNonTerminalField? parent)
      : super(acroForm, dictionary, parent);

  /// Returns the value of the text field.
  String get value {
    return cosObject.getString(COSName.v) ?? '';
  }

  /// Sets the value of the text field.
  @override
  void setValue(String value) {
    super.setValue(value);
  }
}

