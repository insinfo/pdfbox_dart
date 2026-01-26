import 'dart:convert';
import 'package:pdfbox_dart/src/utils/xml/xml.dart';

import '../../cos/cos_array.dart';
import '../../cos/cos_base.dart';
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

  /// Convenience helper to read raw strings from the underlying COS dictionary.
  String? getString(COSName key) => _field.getString(key);

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
      return _decodeStreamText(value);
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

  /// This will set the rich text that is associated with this field.
  /// Returns the rich text XHTML stream.
  String? getRichText() {
    final rv = _field.getDictionaryObject(COSName.rv);
    if (rv == null) {
      return null;
    } else if (rv is COSString) {
      return rv.string;
    } else if (rv is COSStream) {
      return _decodeStreamText(rv);
 
    }
    return null;
  }

  /// This will set the rich text value.
  /// [rv] The rich text value for the stream.
  void setRichText(COSBase rv) {
    _field.setItem(COSName.rv, rv);
  }

  /// Constructor from XML Element.
  FDFField.fromXml(XmlElement fieldXML) : _field = COSDictionary() {
    setPartialFieldName(fieldXML.getAttribute('name'));
    List<FDFField> kids = [];
    for (var node in fieldXML.children) {
      if (node is XmlElement) {
        if (node.name.local == 'value') {
          setValue(_getNodeValue(node));
        } else if (node.name.local == 'value-richtext') {
           setRichText(COSString(_getNodeValue(node)));
        } else if (node.name.local == 'field') {
          kids.add(FDFField.fromXml(node));
        }
      }
    }
    if (kids.isNotEmpty) {
      setKids(kids);
    }
  }

  String _getNodeValue(XmlElement element) {
    return element.innerText;
  }
  
  /// This will write this element as an XML document.
  /// [output] The stream to write the xml to.
  /// Throws IOException if there is an error writing the XML.
  void writeXML(StringSink output) {
    output.write('<field name="${_escapeXML(getPartialFieldName() ?? '')}">\n');
    
    // getValue implementation in Dart might return different types based on dictionary content.
    // Assuming handling String and List<String> primarily.
    Object? value;
    try {
       value = getValue();
    } catch(e) {
       // ignore
    }

    if (value is String) {
      output.write('<value>${_escapeXML(value)}</value>\n');
    } else if (value is List<String>) {
      for (var item in value) {
        output.write('<value>${_escapeXML(item)}</value>\n');
      }
    } else if (value != null) {
      output.write('<value>${_escapeXML(value.toString())}</value>\n');
    }
    
    var rt = getRichText();
    if (rt != null) {
      output.write('<value-richtext>${_escapeXML(rt)}</value-richtext>\n');
    }
    
    var kids = getKids();
    if (kids != null) {
      for (var kid in kids) {
        kid.writeXML(output);
      }
    }
    
    output.write('</field>\n');
  }

  String _escapeXML(String input) {
    return input.replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  String? _decodeStreamText(COSStream stream) {
    try {
      final bytes = stream.decode() ?? stream.data;
      if (bytes == null || bytes.isEmpty) {
        return null;
      }
      try {
        return utf8.decode(bytes);
      } catch (_) {
        return latin1.decode(bytes);
      }
    } catch (_) {
      return null;
    }
  }
}

