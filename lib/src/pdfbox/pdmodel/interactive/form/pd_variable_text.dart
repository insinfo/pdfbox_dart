import 'dart:convert';
import 'dart:typed_data';

import '../../../cos/cos_base.dart';
import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_name.dart';
import '../../../cos/cos_number.dart';
import '../../../cos/cos_stream.dart';
import '../../../cos/cos_string.dart';
import 'pd_acro_form.dart';
import 'pd_non_terminal_field.dart';
import 'pd_terminal_field.dart';

/// Base class for fields which use "Variable Text".
abstract class PDVariableText extends PDTerminalField {
  static const int QUADDING_LEFT = 0;
  static const int QUADDING_CENTERED = 1;
  static const int QUADDING_RIGHT = 2;

  PDVariableText(
      PDAcroForm acroForm, COSDictionary dictionary, PDNonTerminalField? parent)
      : super(acroForm, dictionary, parent);

  /// Get the default appearance.
  String? getDefaultAppearance() {
    final base = getInheritableAttribute(COSName.defaultAppearance);
    if (base is COSString) {
      return base.string;
    }
    return null;
  }

  /// Set the default appearance.
  void setDefaultAppearance(String daValue) {
    cosObject.setString(COSName.defaultAppearance, daValue);
    // PDFBOX-5797: If this field has widgets, their appearance might need update.
    // Since this is a terminal field, kids usually refers to widgets in this context if any.
    // We delegate to updateFieldAppearances() to refresh visual state if needed.
    updateFieldAppearances();    
  }

  /// Get the default style string.
  String? getDefaultStyleString() {
    return cosObject.getString(COSName.ds);
  }

  /// Set the default style string.
  void setDefaultStyleString(String? defaultStyleString) {
    if (defaultStyleString != null) {
      cosObject.setString(COSName.ds, defaultStyleString);
    } else {
      cosObject.removeItem(COSName.ds);
    }
  }

  /// Get the quadding (justification).
  int get q {
    final number = getInheritableAttribute(COSName.q);
    if (number is COSNumber) {
      return number.intValue;
    }
    return 0;
  }

  /// Set the quadding.
  set q(int value) {
    cosObject.setInt(COSName.q, value);
  }

  /// Get the rich text value.
  String? get richTextValue {
    return _getStringOrStream(getInheritableAttribute(COSName.rv));
  }

  /// Set the rich text value.
  set richTextValue(String? value) {
    if (value != null) {
      cosObject.setString(COSName.rv, value);
    } else {
      cosObject.removeItem(COSName.rv);
    }
  }

  String? _getStringOrStream(COSBase? base) {
    if (base is COSString) {
      return base.string;
    } else if (base is COSStream) {
      return _streamToText(base);
    }
    return null;
  }

  String _streamToText(COSStream stream) {
    final decoded = stream.decode();
    if (decoded != null && decoded.isNotEmpty) {
      return _decodeTextBytes(decoded);
    }
    final encoded = stream.encodedBytes();
    if (encoded != null && encoded.isNotEmpty) {
      return _decodeTextBytes(encoded);
    }
    return '';
  }

  String _decodeTextBytes(Uint8List bytes) {
    if (bytes.length >= 2) {
      final first = bytes[0];
      final second = bytes[1];
      if (first == 0xFE && second == 0xFF) {
        return _decodeUtf16(bytes.sublist(2), Endian.big);
      }
      if (first == 0xFF && second == 0xFE) {
        return _decodeUtf16(bytes.sublist(2), Endian.little);
      }
    }
    try {
      return utf8.decode(bytes, allowMalformed: true);
    } on FormatException {
      return latin1.decode(bytes, allowInvalid: true);
    }
  }

  String _decodeUtf16(Uint8List bytes, Endian endian) {
    final usableLength = bytes.length - (bytes.length % 2);
    if (usableLength == 0) {
      return '';
    }
    final dataView = ByteData.view(
      bytes.buffer,
      bytes.offsetInBytes,
      usableLength,
    );
    final codeUnits = List<int>.generate(usableLength ~/ 2, (index) {
      return dataView.getUint16(index * 2, endian);
    });
    return String.fromCharCodes(codeUnits);
  }
}

