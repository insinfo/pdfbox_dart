import 'dart:convert';

import '../../../cos/cos_base.dart';
import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_name.dart';
import '../../../cos/cos_stream.dart';
import '../../../cos/cos_string.dart';
import 'pd_action.dart';

class PDActionJavaScript extends PDAction {
  PDActionJavaScript({COSDictionary? dictionary})
      : super(dictionary ?? COSDictionary()) {
    subtype = 'JavaScript';
  }

  static PDActionJavaScript? fromCOS(COSBase? base) {
    final dict = PDAction.dictionaryFrom(base);
    if (dict == null) {
      return null;
    }
    final subtype = dict.getNameAsString(COSName.s);
    if (subtype != null && subtype != 'JavaScript') {
      return null;
    }
    return PDActionJavaScript(dictionary: dict);
  }

  String? get script {
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

  set script(String? value) {
    if (value == null) {
      cosObject.removeItem(COSName.js);
    } else {
      cosObject.setString(COSName.js, value);
    }
  }
}
