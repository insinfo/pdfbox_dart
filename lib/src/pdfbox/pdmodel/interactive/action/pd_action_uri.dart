import 'dart:convert';

import '../../../cos/cos_base.dart';
import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_name.dart';
import '../../../cos/cos_stream.dart';
import '../../../cos/cos_string.dart';
import 'pd_action.dart';

/// Represents a /URI action that opens an external resource.
class PDActionURI extends PDAction {
  PDActionURI({COSDictionary? dictionary})
      : super(dictionary ?? COSDictionary()) {
    subtype = 'URI';
  }

  static PDActionURI? fromCOS(COSBase? base) {
    final dict = PDAction.dictionaryFrom(base);
    if (dict == null) {
      return null;
    }
    final subtype = dict.getNameAsString(COSName.s);
    if (subtype != null && subtype != 'URI') {
      return null;
    }
    return PDActionURI(dictionary: dict);
  }

  String? get uri => cosObject.getString(COSName.uri);

  set uri(String? value) => cosObject.setString(COSName.uri, value);

  /// Returns `true` when the `/IsMap` flag is set.
  bool get isMap => cosObject.getBoolean(COSName.isMap, false) ?? false;

  set isMap(bool value) => cosObject.setBoolean(COSName.isMap, value);

  /// Extracts the script associated with `/JS` if present, allowing some
  /// vendors to embed JavaScript alongside the URI action.
  String? get javascript {
    final base = cosObject.getDictionaryObject(COSName.js);
    if (base is COSString) {
      return base.string;
    }
    if (base is COSStream) {
      final bytes = base.decode() ?? base.encodedBytes(copy: true);
      if (bytes == null) {
        return null;
      }
      return const Latin1Codec(allowInvalid: true).decode(bytes);
    }
    return null;
  }

  set javascript(String? value) {
    if (value == null) {
      cosObject.removeItem(COSName.js);
    } else {
      cosObject.setString(COSName.js, value);
    }
  }
}
