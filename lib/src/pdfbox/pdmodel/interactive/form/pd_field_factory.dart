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
  static const String _fieldTypeText = 'Tx';
  static const String _fieldTypeButton = 'Btn';
  static const String _fieldTypeChoice = 'Ch';
  static const String _fieldTypeSignature = 'Sig';

  static PDField? createField(
      PDAcroForm acroForm, COSDictionary field, PDNonTerminalField? parent) {
    
    // Check for non-terminal field (has Kids with at least one having a partial name 'T')
    if (field.containsKey(COSName.kids)) {
      final kids = field.getCOSArray(COSName.kids);
      if (kids != null && kids.isNotEmpty) {
        for (var i = 0; i < kids.length; i++) {
          final kid = kids.getObject(i);
          if (kid is COSDictionary && kid.getString(COSName.t) != null) {
             return PDNonTerminalField(acroForm, field, parent);
          }
        }
      }
    }

    final fieldType = _findFieldType(field);

    // Fallback? Java returns null if type not found.
    if (fieldType == null) {
      // If we didn't classify as NonTerminal above, handling here is tricky.
      // But maybe it really is just an invalid terminal field without type.
      return null;
    }

    switch (fieldType) {
      case _fieldTypeText:
        return PDTextField(acroForm, field, parent);
      case _fieldTypeButton:
        return _createButtonSubType(acroForm, field, parent);
      case _fieldTypeChoice:
        return _createChoiceSubType(acroForm, field, parent);
      case _fieldTypeSignature:
        return PDSignatureField(acroForm, field, parent);
      default:
        // TODO: Handle unknown types or fallback
        return null;
    }
  }

  static String? _findFieldType(COSDictionary dic) {
    return _findFieldTypeRecursive(dic, <COSDictionary>{});
  }

  static String? _findFieldTypeRecursive(
      COSDictionary dic, Set<COSDictionary> seen) {
    if (!seen.add(dic)) {
      return null;
    }
    final type = dic.getNameAsString(COSName.ft);
    if (type != null) {
      return type;
    }
    final parent = dic.getCOSDictionary(COSName.parent);
    // In Java: dic.getCOSDictionary(COSName.PARENT, COSName.P);
    // We should check both if Dart allows, or just Parent/P. 
    // Usually Parent is consistent.
    
    // Note: getCOSDictionary in Dart usually takes one key. 
    // We might need to check 'P' if 'Parent' is missing, but fields usually use 'Parent'.
    // Widgets might use 'P' but that points to Page. 
    // Field hierarchy uses 'Parent'.
    if (parent != null) {
      final result = _findFieldTypeRecursive(parent, seen);
      seen.remove(dic);
      return result;
    }
    seen.remove(dic);
    return null;
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

