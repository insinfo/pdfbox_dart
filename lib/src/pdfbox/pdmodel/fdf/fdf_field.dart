import 'dart:convert';

import '../../cos/cos_array.dart';
import '../../cos/cos_base.dart' show COSObjectable;
import '../../cos/cos_dictionary.dart';
import '../../cos/cos_name.dart';
import '../../cos/cos_stream.dart';
import '../../cos/cos_string.dart';

/// This represents an FDF field that is part of the FDF document.
class FDFField implements COSObjectable {
  final COSDictionary _field;

  /// Default constructor.
  FDFField() : _field = COSDictionary();

  /// Constructor with an existing dictionary.
  FDFField.fromDictionary(this._field);

  @override
  COSDictionary get cosObject => _field;

  /// This will get the list of kids. This will return a list of FDFField objects.
  /// This will return null if the underlying list is null.
  List<FDFField>? getKids() {
    final kids = _field.getDictionaryObject(COSName.kids);
    if (kids is COSArray) {
      final actuals = <FDFField>[];
      for (var i = 0; i < kids.length; i++) {
        final obj = kids.getObject(i);
        if (obj is COSDictionary) {
          actuals.add(FDFField.fromDictionary(obj));
        }
      }
      return actuals;
    }
    return null;
  }

  /// This will set the list of kids.
  void setKids(List<FDFField>? kids) {
    if (kids == null) {
      _field.removeItem(COSName.kids);
    } else {
      final array = COSArray();
      for (final kid in kids) {
        array.addObject(kid.cosObject);
      }
      _field.setItem(COSName.kids, array);
    }
  }

  /// This will get the "T" entry in the field dictionary. A partial field name.
  /// Where the fully qualified field name is a concatenation of the parent's fully qualified
  /// field name and "." as a separator. For example:
  /// Address.State
  /// Address.City
  String? getPartialFieldName() {
    return _field.getString(COSName.t);
  }

  /// This will set the partial field name.
  void setPartialFieldName(String? partial) {
    _field.setString(COSName.t, partial);
  }

  /// This will get the value for the field. The return type will either be:
  /// - String: for Checkboxes, Radio Button, Textfields
  /// - List<String>: for a Choice Field
  Object? getValue() {
    final value = _field.getDictionaryObject(COSName.v);
    if (value is COSName) {
      return value.name;
    } else if (value is COSArray) {
      final list = <String>[];
      for (var i = 0; i < value.length; i++) {
        final obj = value.getObject(i);
        if (obj is COSString) {
          list.add(obj.string);
        }
      }
      return list;
    } else if (value is COSString) {
      return value.string;
    } else if (value is COSStream) {
      try {
        final bytes = value.decode();
        if (bytes != null) {
          return utf8.decode(bytes);
        }
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  /// This will set the value for the field.
  void setValue(Object? value) {
    if (value == null) {
      _field.removeItem(COSName.v);
    } else if (value is String) {
      _field.setString(COSName.v, value);
    } else if (value is List<String>) {
      final array = COSArray();
      for (final item in value) {
        array.addObject(COSString(item));
      }
      _field.setItem(COSName.v, array);
    }
  }

  /// This will get the Ff entry of the cos dictionary. If the entry is null then this
  /// method will return 0.
  int getFieldFlags() {
    return _field.getInt(COSName.ff) ?? 0;
  }

  /// This will set the Ff entry of the dictionary.
  void setFieldFlags(int flags) {
    _field.setInt(COSName.ff, flags);
  }

  /// This will get the field type (FT entry).
  String? getFieldType() {
    return _field.getNameAsString(COSName.ft);
  }

  /// This will set the field type.
  void setFieldType(String? type) {
    _field.setName(COSName.ft, type);
  }
}
