import 'dart:convert';
import 'dart:typed_data';

import 'package:pdfbox_dart/src/pdfbox/cos/cos_array.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_dictionary.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_float.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_integer.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_name.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_stream.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/common/function/pdf_function.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/common/function/pdf_function_type0.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/common/function/pdf_function_type3.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/common/function/pdf_function_type4.dart';
import 'package:test/test.dart';

void main() {
  group('PDFunctionType0', () {
    test('evaluates sampled function and clips input', () {
      final stream = COSStream()
        ..setInt(COSName.functionType, 0)
        ..setItem(COSName.domain, _floatArray([0.0, 1.0]))
        ..setItem(COSName.range, _floatArray([0.0, 1.0]))
        ..setItem(COSName.size, COSArray()..add(COSInteger(2)))
        ..setInt(COSName.bitsPerSample, 8)
        ..data = Uint8List.fromList(<int>[0, 255]);

      final function = PDFunction.create(stream);

      expect(function, isA<PDFunctionType0>());

      expect(function.eval(<double>[0.0])[0], closeTo(0.0, 1e-6));
      expect(function.eval(<double>[1.0])[0], closeTo(1.0, 1e-6));
      expect(function.eval(<double>[0.5])[0], closeTo(0.5, 1e-6));
      expect(function.eval(<double>[1.5])[0], closeTo(1.0, 1e-6));
      expect(function.eval(<double>[-0.25])[0], closeTo(0.0, 1e-6));
    });
  });

  group('PDFunctionType3', () {
    test('selects sub-functions based on bounds', () {
      final dictionary = COSDictionary()
        ..setInt(COSName.functionType, 3)
        ..setItem(COSName.domain, _floatArray([0.0, 1.0]))
        ..setItem(COSName.range, _floatArray([0.0, 1.0]))
        ..setItem(COSName.bounds, _floatArray([0.5]))
        ..setItem(COSName.encode, _floatArray([0.0, 1.0, 0.0, 1.0]));

      final functions = COSArray()
        ..addObject(_buildType2(const <double>[0.0], const <double>[1.0]))
        ..addObject(_buildType2(const <double>[1.0], const <double>[0.0]));
      dictionary.setItem(COSName.functions, functions);

      final function = PDFunction.create(dictionary);

      expect(function, isA<PDFunctionType3>());

  expect(function.eval(<double>[0.25])[0], closeTo(0.5, 1e-6));
      expect(function.eval(<double>[0.5])[0], closeTo(1.0, 1e-6));
      expect(function.eval(<double>[0.75])[0], closeTo(0.5, 1e-6));
    });
  });

  group('PDFunctionType4', () {
    test('evaluates simple PostScript procedure', () {
      final function = _createType4('{ add }');

      final output = function.eval(<double>[0.8, 0.1]);
      expect(output, hasLength(1));
      expect(output[0], closeTo(0.9, 1e-6));

      final clipped = function.eval(<double>[0.8, 0.3]);
      expect(clipped[0], closeTo(1.0, 1e-6));

      final inputClipped = function.eval(<double>[0.8, 1.2]);
      expect(inputClipped[0], closeTo(1.0, 1e-6));
    });

    test('respects stack order', () {
      final function = _createType4('{ pop }');

      final output = function.eval(<double>[-0.7, 0.0]);
      expect(output[0], closeTo(-0.7, 1e-6));
    });
  });
}

COSArray _floatArray(List<double> values) {
  final array = COSArray();
  for (final value in values) {
    array.add(COSFloat(value));
  }
  return array;
}

COSDictionary _buildType2(List<double> c0, List<double> c1) {
  final dictionary = COSDictionary()
    ..setInt(COSName.functionType, 2)
    ..setItem(COSName.domain, _floatArray([0.0, 1.0]))
    ..setItem(COSName.c0, _floatArray(c0))
    ..setItem(COSName.c1, _floatArray(c1))
    ..setFloat(COSName.n, 1.0);
  return dictionary;
}

PDFunctionType4 _createType4(String source) {
  final stream = COSStream()
    ..setInt(COSName.functionType, 4)
    ..setItem(COSName.domain, _floatArray([-1.0, 1.0, -1.0, 1.0]))
    ..setItem(COSName.range, _floatArray([-1.0, 1.0]));
  stream.data = latin1.encode(source);
  return PDFunction.create(stream) as PDFunctionType4;
}
