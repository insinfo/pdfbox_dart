import '../../../cos/cos_base.dart';
import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_name.dart';
import '../../../cos/cos_number.dart';
import '../../../cos/cos_stream.dart';
import '../../../cos/cos_string.dart';
import 'pd_acro_form.dart';
import 'pd_non_terminal_field.dart';
import 'pd_terminal_field.dart';

/// Base class for fields which use "Variable Text".
abstract class PDVariableText extends PDTerminalField {
  static const int QUADDING_LEFT = 0;
  static const int QUADDING_CENTERED = 1;
  static const int QUADDING_RIGHT = 2;

  PDVariableText(
      PDAcroForm acroForm, COSDictionary dictionary, PDNonTerminalField? parent)
      : super(acroForm, dictionary, parent);

  /// Get the default appearance.
  String? getDefaultAppearance() {
    final base = getInheritableAttribute(COSName.defaultAppearance);
    if (base is COSString) {
      return base.string;
    }
    return null;
  }

  /// Set the default appearance.
  void setDefaultAppearance(String daValue) {
    cosObject.setString(COSName.defaultAppearance, daValue);
    // TODO: Update kids if needed (PDFBOX-5797)
  }

  /// Get the default style string.
  String? getDefaultStyleString() {
    return cosObject.getString(COSName.ds);
  }

  /// Set the default style string.
  void setDefaultStyleString(String? defaultStyleString) {
    if (defaultStyleString != null) {
      cosObject.setString(COSName.ds, defaultStyleString);
    } else {
      cosObject.removeItem(COSName.ds);
    }
  }

  /// Get the quadding (justification).
  int get q {
    final number = getInheritableAttribute(COSName.q);
    if (number is COSNumber) {
      return number.intValue;
    }
    return 0;
  }

  /// Set the quadding.
  set q(int value) {
    cosObject.setInt(COSName.q, value);
  }

  /// Get the rich text value.
  String? get richTextValue {
    return _getStringOrStream(getInheritableAttribute(COSName.rv));
  }

  /// Set the rich text value.
  set richTextValue(String? value) {
    if (value != null) {
      cosObject.setString(COSName.rv, value);
    } else {
      cosObject.removeItem(COSName.rv);
    }
  }

  String? _getStringOrStream(COSBase? base) {
    if (base is COSString) {
      return base.string;
    } else if (base is COSStream) {
      // TODO: Implement toTextString for COSStream
      return ''; 
    }
    return null;
  }
}
