import '../../../cos/cos_array.dart';
import '../../../cos/cos_base.dart';
import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_name.dart';
import '../../../cos/cos_object.dart';
import '../../../cos/cos_stream.dart';
import '../pd_range.dart';
import 'pdf_function_identity.dart';
import 'pdf_function_type0.dart';
import 'pdf_function_type2.dart';
import 'pdf_function_type3.dart';
import 'pdf_function_type4.dart';

abstract class PDFunction implements COSObjectable {
  PDFunction(COSBase? function) : _dictionary = _resolveDictionary(function);
  final COSDictionary _dictionary;
  COSArray? _domain;
  COSArray? _range;

  @override
  COSDictionary get cosObject => _dictionary;

  int get functionType;

  int get numberOfInputParameters {
    final domainValues = _domainValues;
    if (domainValues == null) {
      return 0;
    }
    return domainValues.length ~/ 2;
  }

  int get numberOfOutputParameters {
    final rangeValues = _rangeValues;
    if (rangeValues == null) {
      return 0;
    }
    return rangeValues.length ~/ 2;
  }

  PDRange getDomainForInput(int index) {
    final domainValues = _domainValues;
    if (domainValues == null || domainValues.length < (index + 1) * 2) {
      return PDRange();
    }
    return PDRange.fromCOSArray(domainValues, index * 2);
  }

  PDRange getRangeForOutput(int index) {
    final rangeValues = _rangeValues;
    if (rangeValues == null || rangeValues.length < (index + 1) * 2) {
      return PDRange();
    }
    return PDRange.fromCOSArray(rangeValues, index * 2);
  }

  List<double> eval(List<double> input);

  List<double> clipToRange(List<double> values) {
    final rangeValues = _rangeValues;
    if (rangeValues == null || rangeValues.isEmpty) {
      return values;
    }
    final clips = <double>[];
    for (var i = 0; i < values.length; i++) {
      final min = rangeValues.getDouble(i * 2);
      final max = rangeValues.getDouble(i * 2 + 1);
      final value = values[i];
      if (min == null || max == null) {
        clips.add(value);
      } else {
        clips.add(value.clamp(min, max));
      }
    }
    return clips;
  }

  double clipValue(double value, double min, double max) {
    if (value < min) {
      return min;
    }
    if (value > max) {
      return max;
    }
    return value;
  }

  double interpolate(
    double x,
    double xMin,
    double xMax,
    double yMin,
    double yMax,
  ) {
    if (xMax == xMin) {
      return yMin;
    }
    return yMin + ((x - xMin) * (yMax - yMin) / (xMax - xMin));
  }

  static PDFunction create(COSBase? function) {
    if (function == null) {
      throw StateError('Function definition is null');
    }
    if (function == COSName.identity) {
      return PDFunctionIdentity();
    }
    final resolved = _resolve(function);
    if (resolved is COSDictionary || resolved is COSStream) {
      final dictionary = resolved as COSDictionary;
      final type = dictionary.getInt(COSName.functionType);
      switch (type) {
        case 0:
          return PDFunctionType0(resolved);
        case 2:
          return PDFunctionType2(resolved);
        case 3:
          return PDFunctionType3(resolved);
        case 4:
          return PDFunctionType4(resolved);
        default:
          throw UnsupportedError('Unsupported function type: $type');
      }
    }
    throw StateError(
        'Unsupported function definition: ${resolved.runtimeType}');
  }

  static COSDictionary _resolveDictionary(COSBase? base) {
    if (base is COSStream) {
      base.setItem(COSName.type, COSName.function);
      return base;
    }
    if (base is COSDictionary) {
      return base;
    }
    if (base == null) {
      return COSDictionary();
    }
    final resolved = _resolve(base);
    if (resolved is COSDictionary) {
      return resolved;
    }
    if (resolved is COSStream) {
      resolved.setItem(COSName.type, COSName.function);
      return resolved;
    }
    throw StateError('Function must be a dictionary or stream');
  }

  static COSBase? _resolve(COSBase? value) {
    if (value is COSObject) {
      return value.object;
    }
    return value;
  }

  COSArray? get _domainValues {
    _domain ??= _dictionary.getCOSArray(COSName.domain);
    return _domain;
  }

  COSArray? get _rangeValues {
    _range ??= _dictionary.getCOSArray(COSName.range);
    return _range;
  }
}
