import '../../../cos/cos_array.dart';
import '../../../cos/cos_base.dart';
import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_name.dart';
import '../../../cos/cos_object.dart';

import '../../../cos/cos_document.dart';
import '../../../cos/cos_string.dart';
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

  /// Returns true if the XFA entry is present.
  bool get xfaIsDynamic {
    return _dictionary.containsKey(COSName.xfa);
  }

  /// Returns the list of fields in this AcroForm.
  List<PDField> get fields {
    final fieldsArray = _dictionary.getDictionaryObject(COSName.fields);
    if (fieldsArray is! COSArray) {
      return [];
    }
    final result = <PDField>[];
    for (var i = 0; i < fieldsArray.length; i++) {
      var item = fieldsArray.getObject(i);
      if (item is COSObject) {
        item = item.object;
      }
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
    // Optimized lookup: split name and traverse
    if (fullyQualifiedName.isEmpty) return null;

    final nameParts = fullyQualifiedName.split('.');
    var currentFields = fields;

    PDField? found;
    for (var i = 0; i < nameParts.length; i++) {
      final partialName = nameParts[i];
      found = null;
      for (final field in currentFields) {
        if (field.partialName == partialName) {
          found = field;
          break;
        }
      }

      if (found == null) return null;

      if (i < nameParts.length - 1) {
        if (found is PDNonTerminalField) {
          currentFields = found.getChildren();
        } else {
          return null; // Should be terminal but path goes deeper
        }
      }
    }
    return found;
  }

  /// Imports an FDF document into this AcroForm.
  void importFDF(COSDictionary fdf) {
    // Basic FDF import logic
    final fdfFields = fdf.getDictionaryObject(COSName.fields);
    if (fdfFields is COSArray) {
      for (var i = 0; i < fdfFields.length; i++) {
        final fdfField = fdfFields.getObject(i);
        if (fdfField is COSDictionary) {
          final partialFieldName = fdfField.getString(COSName.t);
          final value = fdfField.getDictionaryObject(COSName.v);
          if (partialFieldName != null && value != null) {
            final pdField = getField(partialFieldName);
            // partialFieldName from FDF is usually fully qualified?
            // PDFBox FDFField.getPartialFieldName actually returns full if it's top level FDF.
            // We assume partialFieldName here might be usable with getField (which takes fully qualified).

            if (pdField != null) {
              if (value is COSString) {
                pdField.setValue(value.string);
              } else if (value is COSName) {
                pdField.setValue(value.name);
              } else {
                // Handle other value types or extend setValue
                // pdField.setValue(value);
              }
              // In a full implementation, we'd handle APs, actions, etc.
            }
          }
        }
      }
    }
  }

  /// Flattens the form fields into the page content.
  void flatten({List<PDField>? fields, bool refreshAppearances = true}) {
    // If no fields provided, flatten all
    final fieldsToFlatten = fields ?? this.fields;

    if (refreshAppearances) {
      if (needAppearances) {
        if (needAppearances) {
          for (final field in fieldsToFlatten) {
            field
                .updateFieldAppearances(); // Assuming updateFieldAppearances() effectively constructs appearances
          }
        }
      }
    }

    for (final field in fieldsToFlatten) {
      for (final widget in field.getWidgets()) {
        final page = widget.page;
        if (page == null) continue;

        // Basic Flattening: Remove widget from page annotations
        // To properly flatten, we should draw appearance.
        // Without drawing, this just removes the field interaction.

        final annots = page.getCOSArray(COSName.annots);
        if (annots != null) {
          annots.remove(widget.cosObject);
          // If annots is empty, remove it?
          if (annots.isEmpty) {
            page.removeItem(COSName.annots);
          }
        }
      }
    }
    if (fields == null) {
      // Flattened all, remove /Fields
      _dictionary.removeItem(COSName.fields);
    } else {
      // Remove specific fields from /Fields array
      final rootFields = _dictionary.getCOSArray(COSName.fields);
      if (rootFields != null) {
        // Collect cosObjects of fields to remove for quick lookup
        final toRemove = <COSDictionary>{};
        for (final field in fieldsToFlatten) {
          toRemove.add(field.cosObject);
        }
        
        // Remove matching entries from root /Fields array
        // Note: This handles top-level fields. Nested fields are in Kids arrays.
        for (int i = rootFields.length - 1; i >= 0; i--) {
          final obj = rootFields.getObject(i);
          if (obj is COSDictionary && toRemove.contains(obj)) {
            rootFields.removeAt(i);
          }
        }
        
        // Also need to remove from parent's Kids arrays for nested fields
        for (final field in fieldsToFlatten) {
          final parent = field.parent;
          if (parent != null) {
            final kids = parent.cosObject.getCOSArray(COSName.kids);
            if (kids != null) {
              for (int i = kids.length - 1; i >= 0; i--) {
                final obj = kids.getObject(i);
                if (obj == field.cosObject) {
                  kids.removeAt(i);
                }
              }
            }
          }
        }
      }
    }
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
}

