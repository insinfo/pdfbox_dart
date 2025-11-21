import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_name.dart';
import 'pd_acro_form.dart';
import 'pd_field.dart';
import 'pd_non_terminal_field.dart';
import 'pd_button.dart';
import 'pd_check_box.dart';
import 'pd_choice.dart';
import 'pd_combo_box.dart';
import 'pd_list_box.dart';
import 'pd_push_button.dart';
import 'pd_radio_button.dart';
import 'pd_signature_field.dart';
import 'pd_text_field.dart';

class PDFieldFactory {
  static PDField? createField(
      PDAcroForm acroForm, COSDictionary field, PDNonTerminalField? parent) {
    final fieldType = field.getNameAsString(COSName.ft);
    
    // If no FT entry, it might be a non-terminal field if it has Kids
    if (fieldType == null) {
      if (field.containsKey(COSName.kids)) {
        return PDNonTerminalField(acroForm, field, parent);
      }
      // Fallback or error? Java PDFBox sometimes treats as generic field or tries to inherit.
      // For now return null or generic field.
      return null; 
    }

    switch (fieldType) {
      case 'Tx':
        return PDTextField(acroForm, field, parent);
      case 'Btn':
        return _createButtonSubType(acroForm, field, parent);
      case 'Ch':
        return _createChoiceSubType(acroForm, field, parent);
      case 'Sig':
        return PDSignatureField(acroForm, field, parent);
      default:
        return null;
    }
  }

  static PDField _createChoiceSubType(
      PDAcroForm acroForm, COSDictionary field, PDNonTerminalField? parent) {
    final flags = field.getInt(COSName.ff, 0) ?? 0;
    if ((flags & PDChoice.FLAG_COMBO) != 0) {
      return PDComboBox(acroForm, field, parent);
    } else {
      return PDListBox(acroForm, field, parent);
    }
  }

  static PDField _createButtonSubType(
      PDAcroForm acroForm, COSDictionary field, PDNonTerminalField? parent) {
    final flags = field.getInt(COSName.ff, 0) ?? 0;
    // BJL: I have found that the radio flag bit is not always set
    // and that sometimes there is just a kids dictionary.
    // so, if there is a kids dictionary then it must be a radio button group.
    if ((flags & PDButton.FLAG_RADIO) != 0) {
      return PDRadioButton(acroForm, field, parent);
    } else if ((flags & PDButton.FLAG_PUSHBUTTON) != 0) {
      return PDPushButton(acroForm, field, parent);
    } else {
      return PDCheckBox(acroForm, field, parent);
    }
  }
}
