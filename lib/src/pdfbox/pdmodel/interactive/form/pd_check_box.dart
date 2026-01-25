import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_name.dart';
import 'pd_acro_form.dart';
import 'pd_button.dart';
import 'pd_non_terminal_field.dart';

/// A check box toggles between two states, on and off.
class PDCheckBox extends PDButton {
  PDCheckBox(
      PDAcroForm acroForm, COSDictionary dictionary, PDNonTerminalField? parent)
      : super(acroForm, dictionary, parent);

  /// This will tell if this radio button is currently checked or not.
  bool get isChecked => value.compareTo(onValue) == 0;

  /// Checks the check box.
  void check() {
    setValue(onValue);
  }

  /// Unchecks the check box.
  void unCheck() {
    setValue('Off');
  }

  /// Get the value which sets the check box to the On state.
  String get onValue {
    final widgets = getWidgets();
    if (widgets.isNotEmpty) {
      final widget = widgets[0];
      final apDictionary = widget.appearance;
      if (apDictionary != null) {
        final normalAppearance = apDictionary.normalAppearance;
        if (normalAppearance != null && normalAppearance.isSubDictionary) {
          final subDictionary = normalAppearance.subDictionary;
          for (final entry in subDictionary.keys) {
            if (COSName.off != entry) {
              return entry.name;
            }
          }
        }
      }
    }
    return "";
  }
}

