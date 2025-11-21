import '../../../cos/cos_array.dart';
import '../../../cos/cos_base.dart';
import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_integer.dart';
import '../../../cos/cos_name.dart';
import '../../../cos/cos_number.dart';
import '../../../cos/cos_string.dart';
import 'pd_acro_form.dart';
import 'pd_non_terminal_field.dart';
import 'pd_variable_text.dart';

/// A choice field contains several text items, one or more of which shall be selected as the field
/// value.
abstract class PDChoice extends PDVariableText {
  static const int FLAG_COMBO = 1 << 17;
  static const int FLAG_SORT = 1 << 19;
  static const int FLAG_MULTI_SELECT = 1 << 21;
  static const int FLAG_DO_NOT_SPELL_CHECK = 1 << 22;
  static const int FLAG_COMMIT_ON_SEL_CHANGE = 1 << 26;

  PDChoice(
      PDAcroForm acroForm, COSDictionary dictionary, PDNonTerminalField? parent)
      : super(acroForm, dictionary, parent) {
    cosObject.setItem(COSName.ft, COSName.ch);
  }

  /// This will get the option values "Opt".
  List<String> getOptions() {
    final values = cosObject.getDictionaryObject(COSName.opt);
    return _getPairableItems(values, 0);
  }

  /// This will set the display values - the 'Opt' key.
  void setOptions(List<String>? displayValues) {
    if (displayValues != null && displayValues.isNotEmpty) {
      if (isSort) {
        displayValues.sort();
      }
      cosObject.setItem(COSName.opt, COSArray.ofCOSStrings(displayValues));
    } else {
      cosObject.removeItem(COSName.opt);
    }
  }

  /// This will set the display and export values - the 'Opt' key.
  void setOptionsWithExportValues(
      List<String> exportValues, List<String> displayValues) {
    if (exportValues.isNotEmpty && displayValues.isNotEmpty) {
      if (exportValues.length != displayValues.length) {
        throw ArgumentError(
            "The number of entries for exportValue and displayValue shall be the same.");
      }

      // TODO: Implement sorting for pairs if isSort is true

      final options = COSArray();
      for (var i = 0; i < exportValues.length; i++) {
        final entry = COSArray();
        entry.add(COSString(exportValues[i]));
        entry.add(COSString(displayValues[i]));
        options.add(entry);
      }
      cosObject.setItem(COSName.opt, options);
    } else {
      cosObject.removeItem(COSName.opt);
    }
  }

  /// This will get the display values from the options.
  List<String> getOptionsDisplayValues() {
    final values = cosObject.getDictionaryObject(COSName.opt);
    return _getPairableItems(values, 1);
  }

  /// This will get the export values from the options.
  List<String> getOptionsExportValues() {
    return getOptions();
  }

  /// This will get the indices of the selected options - the 'I' key.
  List<int> getSelectedOptionsIndex() {
    final value = cosObject.getCOSArray(COSName.i);
    if (value != null) {
      final result = <int>[];
      for (final item in value) {
        if (item is COSNumber) {
          result.add(item.intValue);
        }
      }
      return result;
    }
    return [];
  }

  /// This will set the indices of the selected options - the 'I' key.
  void setSelectedOptionsIndex(List<int>? values) {
    if (values != null && values.isNotEmpty) {
      if (!isMultiSelect) {
        throw ArgumentError(
            "Setting the indices is not allowed for choice fields not allowing multiple selections.");
      }
      final array = COSArray();
      for (final val in values) {
        array.add(COSInteger(val));
      }
      cosObject.setItem(COSName.i, array);
    } else {
      cosObject.removeItem(COSName.i);
    }
  }

  bool get isSort => cosObject.getFlag(COSName.ff, FLAG_SORT);

  set isSort(bool sort) => cosObject.setFlag(COSName.ff, FLAG_SORT, sort);

  bool get isMultiSelect => cosObject.getFlag(COSName.ff, FLAG_MULTI_SELECT);

  set isMultiSelect(bool multiSelect) =>
      cosObject.setFlag(COSName.ff, FLAG_MULTI_SELECT, multiSelect);

  bool get isDoNotSpellCheck =>
      cosObject.getFlag(COSName.ff, FLAG_DO_NOT_SPELL_CHECK);

  set isDoNotSpellCheck(bool doNotSpellCheck) =>
      cosObject.setFlag(COSName.ff, FLAG_DO_NOT_SPELL_CHECK, doNotSpellCheck);

  bool get isCommitOnSelChange =>
      cosObject.getFlag(COSName.ff, FLAG_COMMIT_ON_SEL_CHANGE);

  set isCommitOnSelChange(bool commitOnSelChange) => cosObject.setFlag(
      COSName.ff, FLAG_COMMIT_ON_SEL_CHANGE, commitOnSelChange);

  bool get isCombo => cosObject.getFlag(COSName.ff, FLAG_COMBO);

  set isCombo(bool combo) => cosObject.setFlag(COSName.ff, FLAG_COMBO, combo);

  @override
  void setValue(String value) {
    cosObject.setString(COSName.v, value);
    // remove I key for single valued choice field
    setSelectedOptionsIndex(null);
    constructAppearances();
  }

  /// Sets the default value of this field.
  void setDefaultValue(String value) {
    cosObject.setString(COSName.dv, value);
  }

  /// Sets the entry "V" to the given values. Requires [isMultiSelect] to be true.
  void setValues(List<String>? values) {
    if (values != null && values.isNotEmpty) {
      if (!isMultiSelect) {
        throw ArgumentError(
            "The list box does not allow multiple selections.");
      }
      final options = getOptions();
      for (final val in values) {
        if (!options.contains(val)) {
          throw ArgumentError(
              "The values are not contained in the selectable options.");
        }
      }
      cosObject.setItem(COSName.v, COSArray.ofCOSStrings(values));
      _updateSelectedOptionsIndex(values, options);
    } else {
      cosObject.removeItem(COSName.v);
      cosObject.removeItem(COSName.i);
    }
    constructAppearances();
  }

  /// Returns the selected values, or an empty List.
  List<String> getValue() {
    return _getValueFor(COSName.v);
  }

  /// Returns the default values, or an empty List.
  List<String> getDefaultValueList() {
    return _getValueFor(COSName.dv);
  }

  List<String> _getValueFor(COSName name) {
    final value = cosObject.getDictionaryObject(name);
    if (value is COSString) {
      return [value.string];
    } else if (value is COSArray) {
      return value.toCOSNameStringList();
    }
    return [];
  }

  void _updateSelectedOptionsIndex(List<String> values, List<String> options) {
    final indices = <int>[];
    for (final value in values) {
      indices.add(options.indexOf(value));
    }
    indices.sort();
    setSelectedOptionsIndex(indices);
  }

  List<String> _getPairableItems(COSBase? items, int pairIdx) {
    if (items is COSArray) {
      final result = <String>[];
      for (final entry in items) {
        if (entry is COSString) {
          result.add(entry.string);
        } else if (entry is COSArray) {
          if (entry.length >= pairIdx + 1) {
            final item = entry.getObject(pairIdx);
            if (item is COSString) {
              result.add(item.string);
            }
          }
        }
      }
      return result;
    }
    return [];
  }
}
