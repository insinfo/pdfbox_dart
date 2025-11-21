import '../../../cos/cos_array.dart';
import '../../../cos/cos_base.dart';
import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_name.dart';

import '../../../cos/cos_document.dart';
import '../../pd_resources.dart';
import '../../resource_cache.dart';
import 'pd_field.dart';
import 'pd_field_factory.dart';
import 'pd_non_terminal_field.dart';

/// Contains the AcroForm dictionary.
class PDAcroForm implements COSObjectable {
  final COSDocument _document;
  final ResourceCache _resourceCache;
  final COSDictionary _dictionary;
  PDResources? _defaultResources;

  PDAcroForm(this._document, this._resourceCache, [COSDictionary? dictionary])
      : _dictionary = dictionary ?? COSDictionary();

  @override
  COSDictionary get cosObject => _dictionary;

  /// Returns the default resources for the AcroForm.
  PDResources? get defaultResources {
    if (_defaultResources != null) {
      return _defaultResources;
    }
    final dict = _dictionary.getCOSDictionary(COSName.dr);
    if (dict == null) {
      return null;
    }
    _defaultResources = PDResources(dict, _resourceCache);
    return _defaultResources;
  }

  set defaultResources(PDResources? resources) {
    _defaultResources = resources;
    if (resources == null) {
      _dictionary.removeItem(COSName.dr);
    } else {
      _dictionary[COSName.dr] = resources.cosObject;
    }
  }

  /// Returns true if the NeedAppearances flag is set.
  bool get needAppearances =>
      _dictionary.getBoolean(COSName.needAppearances, false) ?? false;

  set needAppearances(bool value) {
    _dictionary.setBoolean(COSName.needAppearances, value);
  }

  /// Returns the list of fields in this AcroForm.
  List<PDField> get fields {
    final fieldsArray = _dictionary.getDictionaryObject(COSName.fields);
    if (fieldsArray is! COSArray) {
      return [];
    }
    final result = <PDField>[];
    for (var i = 0; i < fieldsArray.length; i++) {
      final item = fieldsArray.getObject(i);
      if (item is COSDictionary) {
        final field = PDFieldFactory.createField(this, item, null);
        if (field != null) {
          result.add(field);
        }
      }
    }
    return result;
  }

  /// Sets the fields for this AcroForm.
  set fields(List<PDField> fields) {
    final array = COSArray();
    for (final field in fields) {
      array.add(field);
    }
    _dictionary[COSName.fields] = array;
  }

  /// Returns the document this AcroForm belongs to.
  COSDocument get document => _document;

  /// Returns the field with the given name, or null if it does not exist.
  PDField? getField(String fullyQualifiedName) {
    // TODO: Optimize this lookup
    for (final field in fieldTree) {
      if (field.fullyQualifiedName == fullyQualifiedName) {
        return field;
      }
    }
    return null;
  }

  /// Returns an iterable of all fields in the form, including children.
  Iterable<PDField> get fieldTree sync* {
    final rootFields = fields;
    for (final field in rootFields) {
      yield field;
      if (field is PDNonTerminalField) {
        yield* _getFieldTree(field);
      }
    }
  }

  Iterable<PDField> _getFieldTree(PDNonTerminalField parent) sync* {
    for (final child in parent.getChildren()) {
      yield child;
      if (child is PDNonTerminalField) {
        yield* _getFieldTree(child);
      }
    }
  }

  // TODO: Implement importFDF, flatten, etc.
}
