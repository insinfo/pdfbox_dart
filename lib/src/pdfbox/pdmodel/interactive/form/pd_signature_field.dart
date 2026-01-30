import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_name.dart';
import '../digitalsignature/pd_seed_value.dart';
import '../digitalsignature/pd_signature.dart';
import 'pd_acro_form.dart';
import 'pd_non_terminal_field.dart';
import 'pd_terminal_field.dart';

/// A signature field is a form field that contains a digital signature.
class PDSignatureField extends PDTerminalField {
  PDSignatureField(
      PDAcroForm acroForm, COSDictionary dictionary, PDNonTerminalField? parent)
      : super(acroForm, dictionary, parent) {
    cosObject.setItem(COSName.ft, COSName.sig);
  }

  /// Returns the signature contained in this field.
  PDSignature? get signature {
    final value = cosObject.getCOSDictionary(COSName.v);
    return value != null ? PDSignature(value) : null;
  }

  /// Sets the value of this field to be the given signature.
  set signature(PDSignature? value) {
    if (value != null) {
      setSignature(value);
    } else {
      cosObject.removeItem(COSName.v);
    }
  }

  /// Sets the value of this field to be the given signature.
  void setSignature(PDSignature value) {
    cosObject.setItem(COSName.v, value);
    updateFieldAppearances();
  }

  @override
  void setValue(String value) {
    throw UnsupportedError(
        "Signature fields don't support setting the value as String - use setSignature(PDSignature value) instead");
  }

  /// Returns the default value, if any.
  PDSignature? get defaultValue {
    final value = cosObject.getCOSDictionary(COSName.dv);
    return value != null ? PDSignature(value) : null;
  }

  /// Sets the default value of this field to be the given signature.
  void setDefaultValue(PDSignature value) {
    cosObject.setItem(COSName.dv, value);
  }

  /// Returns the seed value dictionary.
  PDSeedValue? get seedValue {
    final dict = cosObject.getCOSDictionary(COSName.sv);
    return dict != null ? PDSeedValue(dict) : null;
  }

  /// Sets the seed value dictionary.
  set seedValue(PDSeedValue? sv) {
    if (sv != null) {
      cosObject.setItem(COSName.sv, sv);
    } else {
      cosObject.removeItem(COSName.sv);
    }
  }
}

