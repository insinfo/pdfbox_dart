import 'dart:typed_data';

import '../../cos/cos_array.dart';
import '../../cos/cos_dictionary.dart';
import '../../cos/cos_float.dart';
import '../../cos/cos_name.dart';
import '../../cos/cos_stream.dart';

/// Lightweight wrapper around a font descriptor dictionary.
class PDFontDescriptor {
  PDFontDescriptor(this._dictionary);

  factory PDFontDescriptor.create(String fontName) {
    final dictionary = COSDictionary()
      ..setName(COSName.type, 'FontDescriptor')
      ..setName(COSName.fontName, fontName);
    return PDFontDescriptor(dictionary);
  }

  final COSDictionary _dictionary;

  String? get fontName => _dictionary.getNameAsString(COSName.fontName);

  COSDictionary get cosObject => _dictionary;

  set fontName(String? value) => _dictionary.setName(COSName.fontName, value);

  set fontFamily(String? value) => _dictionary.setString(COSName.fontFamily, value);

  set fontStretch(String? value) => _dictionary.setName(COSName.fontStretch, value);

  set fontWeight(int? value) => _dictionary.setInt(COSName.fontWeight, value);

  set flags(int value) => _dictionary.setInt(COSName.flags, value);

  set italicAngle(double value) => _dictionary.setFloat(COSName.italicAngle, value);

  set ascent(double value) => _dictionary.setFloat(COSName.ascent, value);

  set descent(double value) => _dictionary.setFloat(COSName.descent, value);

  set leading(double value) => _dictionary.setFloat(COSName.leading, value);

  set capHeight(double value) => _dictionary.setFloat(COSName.capHeight, value);

  set xHeight(double value) => _dictionary.setFloat(COSName.xHeight, value);

  set stemV(double value) => _dictionary.setFloat(COSName.stemV, value);

  set stemH(double value) => _dictionary.setFloat(COSName.stemH, value);

  set avgWidth(double value) => _dictionary.setFloat(COSName.avgWidth, value);

  set maxWidth(double value) => _dictionary.setFloat(COSName.maxWidth, value);

  set missingWidth(double value) => _dictionary.setFloat(COSName.missingWidth, value);

  set fontBBox(List<double> bbox) {
    final array = COSArray();
    for (final value in bbox) {
      array.add(COSFloat(value));
    }
    _dictionary[COSName.fontBBox] = array;
  }

  COSStream setFontFile2Data(Uint8List data) {
    final stream = COSStream()
      ..data = data
      ..setInt(COSName.length1, data.length);
    _dictionary[COSName.fontFile2] = stream;
    return stream;
  }

  COSStream setCIDSetData(Uint8List data) {
    final stream = COSStream()..data = data;
    _dictionary[COSName.cidSet] = stream;
    return stream;
  }

  COSStream? get fontFile2Stream {
    final raw = _dictionary.getDictionaryObject(COSName.fontFile2);
    return raw is COSStream ? raw : null;
  }
}
