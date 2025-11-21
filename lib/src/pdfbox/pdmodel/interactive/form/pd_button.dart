import '../../../cos/cos_array.dart';
import '../../../cos/cos_dictionary.dart';

import '../../../cos/cos_name.dart';
import '../../../cos/cos_string.dart';
import 'pd_acro_form.dart';
import 'pd_non_terminal_field.dart';
import 'pd_terminal_field.dart';

/// A button field represents an interactive control on the screen
/// that the user can manipulate with the mouse.
abstract class PDButton extends PDTerminalField {
  static const int FLAG_RADIO = 1 << 15;
  static const int FLAG_PUSHBUTTON = 1 << 16;
  static const int FLAG_RADIOS_IN_UNISON = 1 << 25;

  PDButton(
      PDAcroForm acroForm, COSDictionary dictionary, PDNonTerminalField? parent)
      : super(acroForm, dictionary, parent) {
    cosObject.setItem(COSName.ft, COSName.btn);
  }

  /// Determines if push button bit is set.
  bool get isPushButton => cosObject.getFlag(COSName.ff, FLAG_PUSHBUTTON);

  /// Determines if radio button bit is set.
  bool get isRadioButton => cosObject.getFlag(COSName.ff, FLAG_RADIO);

  /// Returns the selected value.
  String get value {
    final val = getInheritableAttribute(COSName.v);
    if (val is COSName) {
      final stringValue = val.name;
      final exportValues = getExportValues();
      if (exportValues.isNotEmpty) {
        try {
          final idx = int.parse(stringValue);
          if (idx >= 0 && idx < exportValues.length) {
            return exportValues[idx];
          }
        } catch (_) {
          return stringValue;
        }
      }
      return stringValue;
    }
    return 'Off';
  }

  /// Set the selected option given its name.
  @override
  void setValue(String value) {
    checkValue(value);
    if (getExportValues().isNotEmpty) {
      updateByOption(value);
    } else {
      updateByValue(value);
    }
    // TODO: applyChange()
  }

  /// Set the selected option given its index.
  void setValueAtIndex(int index) {
    final exportValues = getExportValues();
    if (exportValues.isEmpty || index < 0 || index >= exportValues.length) {
      throw ArgumentError("index '$index' is not a valid index.");
    }
    updateByValue(index.toString());
    // TODO: applyChange()
  }

  /// Returns the default value.
  String get defaultValue {
    final val = getInheritableAttribute(COSName.dv);
    if (val is COSName) {
      return val.name;
    }
    return '';
  }

  /// Sets the default value.
  void setDefaultValue(String value) {
    checkValue(value);
    cosObject.setName(COSName.dv, value);
  }

  /// This will get the (optional) export values.
  List<String> getExportValues() {
    final value = getInheritableAttribute(COSName.opt);
    if (value is COSString) {
      return [value.string];
    } else if (value is COSArray) {
      return value.toCOSNameStringList();
    }
    return [];
  }

  /// This will set the export values.
  void setExportValues(List<String>? values) {
    if (values != null && values.isNotEmpty) {
      cosObject.setItem(COSName.opt, COSArray.ofCOSStrings(values));
    } else {
      cosObject.removeItem(COSName.opt);
    }
  }

  void checkValue(String value) {
    final onValues = getOnValues();
    if (value != 'Off' && !onValues.contains(value)) {
      throw ArgumentError("value '$value' is not a valid option.");
    }
  }

  Set<String> getOnValues() {
    final onValues = <String>{};
    final exportValues = getExportValues();
    if (exportValues.isNotEmpty) {
      onValues.addAll(exportValues);
      return onValues;
    }
    
    for (final widget in getWidgets()) {
      final appearance = widget.appearance;
      if (appearance != null) {
        final normal = appearance.normalAppearance;
        if (normal != null && normal.isSubDictionary) {
          final subDict = normal.subDictionary;
          for (final key in subDict.keys) {
            if (key.name != 'Off') {
              onValues.add(key.name);
            }
          }
        }
      }
    }
    return onValues;
  }

  void updateByValue(String value) {
    cosObject.setName(COSName.v, value);
    for (final widget in getWidgets()) {
      final appearance = widget.appearance;
      if (appearance != null) {
        final normal = appearance.normalAppearance;
        if (normal != null && normal.isSubDictionary) {
          final subDict = normal.subDictionary;
          if (subDict.containsKey(COSName.getPDFName(value))) {
            widget.appearanceState = value;
          } else {
            widget.appearanceState = 'Off';
          }
        } else {
           // If it's not a subdictionary, it might be a single stream (e.g. push button)
           // In that case, AS might not be relevant or handled differently.
           // For Checkbox/Radio, it's usually a subdictionary.
           widget.appearanceState = value;
        }
      } else {
        // No appearance dictionary, just set the state?
        // Or maybe we shouldn't touch it if we don't know valid states.
        // But for now, let's assume setting it is better than not.
        widget.appearanceState = value;
      }
    }
  }

  void updateByOption(String value) {
    final options = getExportValues();
    if (value == 'Off') {
      updateByValue(value);
    } else {
      final index = options.indexOf(value);
      if (index != -1) {
        updateByValue(index.toString());
      }
    }
  }
}
