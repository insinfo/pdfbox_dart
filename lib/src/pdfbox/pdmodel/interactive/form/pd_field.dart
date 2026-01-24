import '../../../cos/cos_base.dart';
import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_name.dart';
import '../annotation/pd_annotation_widget.dart';
import 'pd_acro_form.dart';

import 'pd_non_terminal_field.dart';

/// Represents a field in an interactive form.
abstract class PDField implements COSObjectable {
  final PDAcroForm _acroForm;
  final COSDictionary _dictionary;
  final PDNonTerminalField? _parent;

  PDField(this._acroForm, this._dictionary, this._parent);

  @override
  COSDictionary get cosObject => _dictionary;

  /// Returns the AcroForm that this field is part of.
  PDAcroForm get acroForm => _acroForm;

  /// Returns the parent field, or null if this is a top-level field.
  PDNonTerminalField? get parent => _parent;

  /// Returns the partial name of the field.
  String get partialName => _dictionary.getString(COSName.t) ?? '';

  /// Sets the partial name of the field.
  set partialName(String name) => _dictionary.setString(COSName.t, name);

  /// Returns the fully qualified name of the field.
  String get fullyQualifiedName {
    final parent = this.parent;
    if (parent != null) {
      final parentName = parent.fullyQualifiedName;
      if (parentName.isNotEmpty) {
        final partial = partialName;
        if (partial.isNotEmpty) {
          return '$parentName.$partial';
        }
        return parentName;
      }
    }
    return partialName;
  }

  /// Returns the value of the field.
  COSBase? get cosValue => _dictionary.getDictionaryObject(COSName.v);

  /// Returns the inheritable attribute for the given key.
  COSBase? getInheritableAttribute(COSName key) {
    var current = _dictionary.getDictionaryObject(key);
    if (current != null) {
      return current;
    }
    return _parent?.getInheritableAttribute(key);
  }

  /// Sets the value of the field.
  void setValue(String value) {
    _dictionary.setString(COSName.v, value);
    updateFieldAppearances();
  }

  /// Updates the appearance of this field.
  /// This is strongly recommended when changing the value of the field.
  /// 
  /// If the AcroForm has the `needAppearances` flag set to true, this method
  /// will regenerate appearances. Subclasses (particularly terminal fields)
  /// should override [constructAppearances] to provide actual appearance generation.
  void updateFieldAppearances() {
    // Check if we should generate appearances
    if (acroForm.needAppearances == true) {
      // For terminal fields, constructAppearances will be called from setValue
      // For non-terminal fields, iterate through children
      // This base implementation doesn't do anything as it's abstract
    }
  }
  
  /// Constructs the appearance streams for this field.
  /// Override in subclasses to provide actual implementation.
  void constructAppearances() {
    // Base implementation does nothing.
    // Terminal fields override this to use AppearanceGeneratorHelper.
  }

  /// Returns the widget annotations associated with this field.
  List<PDAnnotationWidget> getWidgets();

  @override
  String toString() => '$runtimeType{name: $fullyQualifiedName}';
}
