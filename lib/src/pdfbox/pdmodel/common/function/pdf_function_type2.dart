import 'dart:math' as math;

import '../../../cos/cos_array.dart';
import '../../../cos/cos_base.dart';
import '../../../cos/cos_float.dart';
import '../../../cos/cos_name.dart';
import '../../../cos/cos_number.dart';
import 'pdf_function.dart';

class PDFunctionType2 extends PDFunction {
  PDFunctionType2(COSBase? function) : super(function) {
    final dictionary = cosObject;

    final c0Array = dictionary.getCOSArray(COSName.c0);
    if (c0Array == null || c0Array.isEmpty) {
      _c0 = COSArray()..add(COSFloat(0));
    } else {
      _c0 = c0Array;
    }

    final c1Array = dictionary.getCOSArray(COSName.c1);
    if (c1Array == null || c1Array.isEmpty) {
      _c1 = COSArray()..add(COSFloat(1));
    } else {
      _c1 = c1Array;
    }

    _exponent = dictionary.getFloat(COSName.n) ?? 1.0;
  }

  late final COSArray _c0;
  late final COSArray _c1;
  late final double _exponent;

  @override
  int get functionType => 2;

  @override
  List<double> eval(List<double> input) {
    if (input.isEmpty) {
      return const <double>[];
    }
    final xToN = math.pow(input[0], _exponent).toDouble();
    final resultLength = math.min(_c0.length, _c1.length);
    final result = List<double>.filled(resultLength, 0.0);
    for (var i = 0; i < resultLength; i++) {
      final c0Value = (_c0[i] as COSNumber).doubleValue;
      final c1Value = (_c1[i] as COSNumber).doubleValue;
      result[i] = c0Value + xToN * (c1Value - c0Value);
    }
    return clipToRange(result);
  }

  COSArray get c0 => _c0;

  COSArray get c1 => _c1;

  double get n => _exponent;

  @override
  String toString() => 'FunctionType2{C0:$c0 C1:$c1 N:$n}';
}
