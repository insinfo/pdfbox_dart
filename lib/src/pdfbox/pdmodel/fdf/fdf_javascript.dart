import '../../cos/cos_array.dart';
import '../../cos/cos_base.dart' show COSObjectable;
import '../../cos/cos_dictionary.dart';
import '../../cos/cos_name.dart';
import '../../cos/cos_stream.dart';
import '../../cos/cos_string.dart';

/// This represents an FDF JavaScript dictionary that is part of the FDF document.
/// Ported from org.apache.pdfbox.pdmodel.fdf.FDFJavaScript
class FDFJavaScript implements COSObjectable {
  FDFJavaScript([COSDictionary? dictionary])
      : _dictionary = dictionary ?? COSDictionary();

  final COSDictionary _dictionary;

  @override
  COSDictionary get cosObject => _dictionary;

  /// This will get the javascript that is executed before the import.
  /// Returns some javascript code or null.
  String? getBefore() {
    final base = _dictionary.getDictionaryObject(COSName.before);
    if (base is COSString) {
      return base.string;
    } else if (base is COSStream) {
      // Decode stream and convert to string
      try {
        final decoded = base.decode();
        if (decoded == null) return null;
        return String.fromCharCodes(decoded);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  /// This will set the javascript code that will get executed before the import.
  /// [before] A reference to some javascript code.
  void setBefore(String? before) {
    if (before == null) {
      _dictionary.removeItem(COSName.before);
    } else {
      _dictionary.setItem(COSName.before, COSString(before));
    }
  }

  /// This will get the javascript that is executed after the import.
  /// Returns some javascript code or null.
  String? getAfter() {
    final base = _dictionary.getDictionaryObject(COSName.after);
    if (base is COSString) {
      return base.string;
    } else if (base is COSStream) {
      // Decode stream and convert to string
      try {
        final decoded = base.decode();
        if (decoded == null) return null;
        return String.fromCharCodes(decoded);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  /// This will set the javascript code that will get executed after the import.
  /// [after] A reference to some javascript code.
  void setAfter(String? after) {
    if (after == null) {
      _dictionary.removeItem(COSName.after);
    } else {
      _dictionary.setItem(COSName.after, COSString(after));
    }
  }

  /// Returns the dictionary's "Doc" entry, that is, a map of key value pairs 
  /// to be added to the document's JavaScript name tree.
  /// Returns map of named "JavaScript" dictionaries or null.
  /// Note: PDActionJavaScript not yet ported, returns raw COSDictionary values.
  Map<String, COSDictionary>? getDoc() {
    final array = _dictionary.getCOSArray(COSName.doc);
    if (array == null) return null;

    final map = <String, COSDictionary>{};
    for (int i = 0; i + 1 < array.length; i += 2) {
      final name = array[i];
      if (name is COSName) {
        final base = array.getObject(i + 1);
        if (base is COSDictionary) {
          map[name.name] = base;
        }
      }
    }
    return map;
  }

  /// Sets the dictionary's "Doc" entry.
  /// [map] Map of named "JavaScript" dictionaries.
  void setDoc(Map<String, COSDictionary>? map) {
    if (map == null) {
      _dictionary.removeItem(COSName.doc);
    } else {
      final array = COSArray();
      map.forEach((key, value) {
        array.add(COSString(key));
        array.add(value);
      });
      _dictionary.setItem(COSName.doc, array);
    }
  }
}
