import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_name.dart';
import 'pd_acro_form.dart';
import 'pd_button.dart';
import 'pd_non_terminal_field.dart';

/// Radio button fields contain a set of related buttons that can each be on or off.
class PDRadioButton extends PDButton {
  static const int FLAG_NO_TOGGLE_TO_OFF = 1 << 14;

  PDRadioButton(
      PDAcroForm acroForm, COSDictionary dictionary, PDNonTerminalField? parent)
      : super(acroForm, dictionary, parent) {
    cosObject.setFlag(COSName.ff, PDButton.FLAG_RADIO, true);
  }

  /// Sets the radios in unison flag.
  set radiosInUnison(bool radiosInUnison) {
    cosObject.setFlag(COSName.ff, PDButton.FLAG_RADIOS_IN_UNISON, radiosInUnison);
  }

  /// Returns true if the radios in unison flag is set.
  bool get isRadiosInUnison =>
      cosObject.getFlag(COSName.ff, PDButton.FLAG_RADIOS_IN_UNISON);

  /// Returns the selected index.
  int get selectedIndex {
    var idx = 0;
    for (final widget in getWidgets()) {
      if (COSName.off.name != widget.appearanceState) {
        return idx;
      }
      idx++;
    }
    return -1;
  }

  /// Returns the selected export values.
  List<String> getSelectedExportValues() {
    final exportValues = getExportValues();
    final selectedExportValues = <String>[];
    if (exportValues.isEmpty) {
      selectedExportValues.add(value);
      return selectedExportValues;
    } else {
      final fieldValue = value;
      var idx = 0;
      for (final onValue in getOnValues()) {
        if (onValue.compareTo(fieldValue) == 0) {
          selectedExportValues.add(exportValues[idx]);
        }
        idx++;
      }
      return selectedExportValues;
    }
  }
}

