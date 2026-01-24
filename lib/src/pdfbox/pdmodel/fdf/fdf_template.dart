import '../../cos/cos_array.dart';
import '../../cos/cos_base.dart' show COSObjectable;
import '../../cos/cos_dictionary.dart';
import '../../cos/cos_name.dart';
import 'fdf_field.dart';
import 'fdf_named_page_reference.dart';

/// This represents an FDF template that is part of the FDF page.
class FDFTemplate implements COSObjectable {
  final COSDictionary _template;

  /// Default constructor.
  FDFTemplate() : _template = COSDictionary();

  /// Constructor with an existing dictionary.
  FDFTemplate.fromDictionary(this._template);

  @override
  COSDictionary get cosObject => _template;

  /// This is the template reference.
  FDFNamedPageReference? getTemplateReference() {
    final dict = _template.getDictionaryObject(COSName.tref);
    if (dict is COSDictionary) {
      return FDFNamedPageReference(dict);
    }
    return null;
  }

  /// This will set the template reference.
  void setTemplateReference(FDFNamedPageReference? tRef) {
    _template.setItem(COSName.tref, tRef);
  }

  /// This will get a list of fields that are part of this template.
  List<FDFField>? getFields() {
    final array = _template.getDictionaryObject(COSName.fields);
    if (array is COSArray) {
      final fields = <FDFField>[];
      for (var i = 0; i < array.length; i++) {
        final obj = array.getObject(i);
        if (obj is COSDictionary) {
          fields.add(FDFField.fromDictionary(obj));
        }
      }
      return fields;
    }
    return null;
  }

  /// This will set a list of fields for this template.
  void setFields(List<FDFField>? fields) {
    if (fields == null) {
      _template.removeItem(COSName.fields);
    } else {
      final array = COSArray();
      for (final field in fields) {
        array.addObject(field.cosObject);
      }
      _template.setItem(COSName.fields, array);
    }
  }

  /// A flag telling if the fields imported from the template may be renamed if there are conflicts.
  bool shouldRename() {
    return _template.getBoolean(COSName.rename, false) ?? false;
  }

  /// This will set if the fields can be renamed.
  void setRename(bool value) {
    _template.setBoolean(COSName.rename, value);
  }
}
