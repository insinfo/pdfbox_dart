import '../../cos/cos_dictionary.dart';
import '../../cos/cos_name.dart';
import '../../cos/cos_stream.dart';
import '../../cos/cos_number.dart';
import '../pd_resources.dart';
import '../common/pd_rectangle.dart';
import '../../util/matrix.dart';

import 'pd_simple_font.dart';
import '../../../fontbox/encoding/encoding.dart';
import 'encoding/dictionary_encoding.dart';

/// Represents a Type 3 font.
class PDType3Font extends PDSimpleFont {
  PDResources? _resources;
  PDRectangle? _fontBBox;
  Matrix? _fontMatrix;

  PDType3Font(COSDictionary dictionary)
      : super(dictionary, encoding: _readEncoding(dictionary)) {
    _readResources();
  }

  static Encoding _readEncoding(COSDictionary dictionary) {
    final encoding = dictionary.getDictionaryObject(COSName.encoding);
    if (encoding is COSDictionary) {
      return DictionaryEncoding(encoding);
    } else if (encoding is COSName) {
      return DictionaryEncoding.resolveEncoding(encoding) ??
          DictionaryEncoding.resolveEncoding(COSName.standardEncoding)!;
    }
    return DictionaryEncoding.resolveEncoding(COSName.standardEncoding)!;
  }

  void _readResources() {
    final resources = dictionary.getDictionaryObject(COSName.resources);
    if (resources is COSDictionary) {
      _resources = PDResources(resources);
    }
  }

  PDResources? get resources => _resources;

  PDRectangle? get fontBBox {
    if (_fontBBox == null) {
      final bbox = dictionary.getCOSArray(COSName.fontBBox);
      if (bbox != null) {
        _fontBBox = PDRectangle.fromCOSArray(bbox);
      }
    }
    return _fontBBox;
  }

  Matrix get fontMatrix {
    if (_fontMatrix == null) {
      final matrix = dictionary.getCOSArray(COSName.fontMatrix);
      if (matrix != null) {
        _fontMatrix = Matrix.fromCos(matrix);
      } else {
        _fontMatrix = Matrix();
      }
    }
    return _fontMatrix!;
  }

  COSStream? getCharStream(int code) {
    final name = codeToName(code);
    final charProcs = dictionary.getCOSDictionary(COSName.charProcs);
    if (charProcs != null) {
      return charProcs.getCOSStream(COSName(name));
    }
    return null;
  }

  @override
  double getWidthFromFont(int code) {
    final firstChar = dictionary.getInt(COSName.firstChar) ?? 0;
    final lastChar = dictionary.getInt(COSName.lastChar) ?? 0;
    final widths = dictionary.getCOSArray(COSName.widths);
    
    if (widths != null && code >= firstChar && code <= lastChar) {
      final index = code - firstChar;
      if (index < widths.length) {
        final w = widths.getObject(index);
        if (w is COSNumber) {
          return w.doubleValue;
        }
      }
    }
    return 0;
  }
}

