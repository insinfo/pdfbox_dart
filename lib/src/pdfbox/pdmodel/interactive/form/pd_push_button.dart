import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_name.dart';
import 'pd_acro_form.dart';
import 'pd_button.dart';
import 'pd_non_terminal_field.dart';

/// A pushbutton is a purely interactive control that responds immediately to user
/// input without retaining a permanent value.
class PDPushButton extends PDButton {
  PDPushButton(
      PDAcroForm acroForm, COSDictionary dictionary, PDNonTerminalField? parent)
      : super(acroForm, dictionary, parent) {
    cosObject.setFlag(COSName.ff, PDButton.FLAG_PUSHBUTTON, true);
  }

  @override
  List<String> getExportValues() {
    return [];
  }

  @override
  void setExportValues(List<String>? values) {
    if (values != null && values.isNotEmpty) {
      throw ArgumentError(
          "A PDPushButton shall not use the Opt entry in the field dictionary");
    }
  }

  @override
  String get value => "";

  @override
  String get defaultValue => "";

  @override
  Set<String> getOnValues() {
    return {};
  }
}

