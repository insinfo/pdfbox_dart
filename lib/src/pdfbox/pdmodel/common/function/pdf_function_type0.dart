import 'dart:math' as math;
import 'dart:typed_data';

import '../../../cos/cos_array.dart';
import '../../../cos/cos_base.dart';
import '../../../cos/cos_float.dart';
import '../../../cos/cos_name.dart';
import '../../../cos/cos_number.dart';
import '../../../cos/cos_object.dart';
import '../../../cos/cos_stream.dart';
import '../pd_range.dart';
import 'pdf_function.dart';

class PDFunctionType0 extends PDFunction {
  PDFunctionType0(COSBase? function) : super(function);

  COSArray? _encode;
  COSArray? _decode;
  COSArray? _size;
  List<List<int>>? _samples;

  @override
  int get functionType => 0;

  COSArray get size {
    _size ??= cosObject.getCOSArray(COSName.size);
    final result = _size;
    if (result == null) {
      throw StateError('Type 0 function is missing Size entry');
    }
    return result;
  }

  int get bitsPerSample {
    final value = cosObject.getInt(COSName.bitsPerSample);
    if (value == null) {
      throw StateError('Type 0 function is missing BitsPerSample entry');
    }
    return value;
  }

  int get order => cosObject.getInt(COSName.order) ?? 1;

  PDRange? getEncodeForParameter(int index) {
    final encodeValues = _encodeValues;
    if (encodeValues.length >= (index + 1) * 2) {
      return PDRange.fromCOSArray(encodeValues, index * 2);
    }
    return null;
  }

  PDRange? getDecodeForParameter(int index) {
    final decodeValues = _decodeValues;
    if (decodeValues.length >= (index + 1) * 2) {
      return PDRange.fromCOSArray(decodeValues, index * 2);
    }
    return null;
  }

  COSArray get _encodeValues {
    if (_encode != null) {
      return _encode!;
    }
    final existing = cosObject.getCOSArray(COSName.encode);
    if (existing != null) {
      _encode = existing;
      return existing;
    }
    final defaults = COSArray();
    final sizeArray = size;
    for (var i = 0; i < sizeArray.length; ++i) {
      defaults.add(COSFloat(0));
      defaults.add(COSFloat((_intAt(sizeArray, i) - 1).toDouble()));
    }
    _encode = defaults;
    return defaults;
  }

  COSArray get _decodeValues {
    if (_decode != null) {
      return _decode!;
    }
    final existing = cosObject.getCOSArray(COSName.decode);
    if (existing != null) {
      _decode = existing;
      return existing;
    }
  final ranges = cosObject.getCOSArray(COSName.range);
    if (ranges != null) {
      _decode = ranges;
      return ranges;
    }
    final defaults = COSArray();
    _decode = defaults;
    return defaults;
  }

  @override
  List<double> eval(List<double> input) {
    final sizeValues = _sizeValues();
    final bps = bitsPerSample;
    final maxSample = math.pow(2, bps).toDouble() - 1.0;
    final inputValues = List<double>.from(input);
    final outputs = numberOfOutputParameters;
    final inputPrev = List<int>.filled(inputValues.length, 0);
    final inputNext = List<int>.filled(inputValues.length, 0);

    for (var i = 0; i < inputValues.length; ++i) {
      final domain = getDomainForInput(i);
      final encodeRange = getEncodeForParameter(i);
      if (encodeRange == null) {
        throw StateError('Type 0 function missing Encode entry for input $i');
      }
      final min = domain.min;
      final max = domain.max;
      var value = clipValue(inputValues[i], min, max);
      value = interpolate(value, min, max, encodeRange.min, encodeRange.max);
  value = clipValue(value, 0.0, sizeValues[i].toDouble() - 1.0);
      inputPrev[i] = value.floor();
      inputNext[i] = value.ceil();
      inputValues[i] = value;
    }

    final interpolator = _RecursiveInterpolator(
      function: this,
      input: inputValues,
      inputPrev: inputPrev,
      inputNext: inputNext,
      sizeValues: sizeValues,
      numberOfOutputs: outputs,
    );
    final outputValues = interpolator.interpolate();

    for (var i = 0; i < outputs; ++i) {
      final range = getRangeForOutput(i);
      final decodeRange = getDecodeForParameter(i);
      if (decodeRange == null) {
        throw StateError('Type 0 function missing Decode entry for output $i');
      }
      final decoded = interpolate(
        outputValues[i],
  0.0,
        maxSample,
        decodeRange.min,
        decodeRange.max,
      );
      outputValues[i] = clipValue(decoded, range.min, range.max);
    }

    return outputValues;
  }

  List<int> _sizeValues() {
    final values = <int>[];
    for (var i = 0; i < size.length; ++i) {
      values.add(_intAt(size, i));
    }
    return values;
  }

  List<List<int>> _getSamples() {
    if (_samples != null) {
      return _samples!;
    }
    final nIn = numberOfInputParameters;
    final nOut = numberOfOutputParameters;
    if (nIn == 0 || nOut == 0) {
      _samples = <List<int>>[];
      return _samples!;
    }
    final sizes = _sizeValues();
    var arraySize = 1;
    for (final value in sizes) {
      arraySize *= value;
    }
    final samples = List.generate(
      arraySize,
      (_) => List<int>.filled(nOut, 0),
    );
    final data = _readSampleData();
    final reader = _BitReader(data);
    final bps = bitsPerSample;
    for (var i = 0; i < arraySize; ++i) {
      for (var j = 0; j < nOut; ++j) {
        samples[i][j] = reader.read(bps);
      }
    }
    _samples = samples;
    return samples;
  }

  List<int> _sampleAt(int index) => _getSamples()[index];

  Uint8List _readSampleData() {
    final base = cosObject;
    if (base is COSStream) {
      final decoded = base.decode();
      if (decoded != null) {
        return decoded;
      }
      final encoded = base.encodedBytes();
      if (encoded != null) {
        return encoded;
      }
    }
    throw StateError('Unable to read sample data for type 0 function');
  }

  int _intAt(COSArray array, int index) {
    final base = array.getObject(index);
    final resolved = base is COSObject ? base.object : base;
    if (resolved is COSNumber) {
      return resolved.intValue;
    }
    throw StateError('Expected numeric value at index $index');
  }
}

class _RecursiveInterpolator {
  _RecursiveInterpolator({
    required this.function,
    required this.input,
    required this.inputPrev,
    required this.inputNext,
    required this.sizeValues,
    required this.numberOfOutputs,
  });

  final PDFunctionType0 function;
  final List<double> input;
  final List<int> inputPrev;
  final List<int> inputNext;
  final List<int> sizeValues;
  final int numberOfOutputs;

  List<double> interpolate() {
    return _interpolate(List<int>.filled(input.length, 0), 0);
  }

  List<double> _interpolate(List<int> coord, int step) {
  final result = List<double>.filled(numberOfOutputs, 0.0);
    if (step == input.length - 1) {
      if (inputPrev[step] == inputNext[step]) {
        coord[step] = inputPrev[step];
        final sample = function._sampleAt(_calcSampleIndex(coord));
        for (var i = 0; i < numberOfOutputs; ++i) {
          result[i] = sample[i].toDouble();
        }
        return result;
      }
      coord[step] = inputPrev[step];
      final sample1 = function._sampleAt(_calcSampleIndex(coord));
      coord[step] = inputNext[step];
      final sample2 = function._sampleAt(_calcSampleIndex(coord));
      for (var i = 0; i < numberOfOutputs; ++i) {
        result[i] = function.interpolate(
          input[step],
          inputPrev[step].toDouble(),
          inputNext[step].toDouble(),
          sample1[i].toDouble(),
          sample2[i].toDouble(),
        );
      }
      return result;
    }
    if (inputPrev[step] == inputNext[step]) {
      coord[step] = inputPrev[step];
      return _interpolate(coord, step + 1);
    }
    coord[step] = inputPrev[step];
    final sample1 = _interpolate(coord, step + 1);
    coord[step] = inputNext[step];
    final sample2 = _interpolate(coord, step + 1);
    for (var i = 0; i < numberOfOutputs; ++i) {
      result[i] = function.interpolate(
        input[step],
        inputPrev[step].toDouble(),
        inputNext[step].toDouble(),
        sample1[i],
        sample2[i],
      );
    }
    return result;
  }

  int _calcSampleIndex(List<int> coord) {
    final dimension = coord.length;
    var index = 0;
    var sizeProduct = 1;
    for (var i = dimension - 2; i >= 0; --i) {
      sizeProduct *= sizeValues[i];
    }
    for (var i = dimension - 1; i >= 0; --i) {
      index += sizeProduct * coord[i];
      if (i - 1 >= 0) {
        sizeProduct ~/= sizeValues[i - 1];
      }
    }
    return index;
  }
}

class _BitReader {
  _BitReader(this.data);

  final Uint8List data;
  var _byteIndex = 0;
  var _bitOffset = 0;

  int read(int bits) {
    if (bits <= 0) {
      return 0;
    }
    var value = 0;
    for (var i = 0; i < bits; ++i) {
      if (_byteIndex >= data.length) {
        return value;
      }
      value <<= 1;
      final current = data[_byteIndex];
      final bit = (current >> (7 - _bitOffset)) & 1;
      value |= bit;
      _bitOffset++;
      if (_bitOffset == 8) {
        _bitOffset = 0;
        _byteIndex++;
      }
    }
    return value;
  }
}
