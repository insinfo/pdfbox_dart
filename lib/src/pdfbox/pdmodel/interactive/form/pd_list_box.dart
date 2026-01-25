import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_name.dart';
import 'pd_acro_form.dart';
import 'pd_choice.dart';
import 'pd_non_terminal_field.dart';

/// A scrollable list box. Contains several text items, one or more of which shall be selected as the
/// field value.
class PDListBox extends PDChoice {
  PDListBox(
      PDAcroForm acroForm, COSDictionary dictionary, PDNonTerminalField? parent)
      : super(acroForm, dictionary, parent);

  /// This will get the top index "TI" value.
  int get topIndex => cosObject.getInt(COSName.ti, 0) ?? 0;

  /// This will set top index "TI" value.
  set topIndex(int? topIndex) {
    if (topIndex != null) {
      cosObject.setInt(COSName.ti, topIndex);
    } else {
      cosObject.removeItem(COSName.ti);
    }
  }
}

