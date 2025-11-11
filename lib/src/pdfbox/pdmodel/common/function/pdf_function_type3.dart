import '../../../cos/cos_base.dart';
import '../../../cos/cos_name.dart';
import '../pd_range.dart';
import 'pdf_function.dart';

class PDFunctionType3 extends PDFunction {
  PDFunctionType3(COSBase? function) : super(function);

  List<PDFunction>? _functions;
  List<double>? _boundsValues;

  @override
  int get functionType => 3;

  @override
  List<double> eval(List<double> input) {
    if (input.isEmpty) {
      return const <double>[];
    }
    var x = input[0];
    final domain = getDomainForInput(0);
    x = clipValue(x, domain.min, domain.max);

    final functions = _loadFunctions();
    PDFunction? selected;
    var mapped = x;

    if (functions.length == 1) {
      final encodeRange = _encodeForParameter(0);
      mapped = interpolate(
        x,
        domain.min,
        domain.max,
        encodeRange.min,
        encodeRange.max,
      );
      selected = functions.first;
    } else {
      final boundsValues = _loadBounds();
  final partitions = List<double>.filled(boundsValues.length + 2, 0.0);
      partitions[0] = domain.min;
      partitions[partitions.length - 1] = domain.max;
      for (var i = 0; i < boundsValues.length; ++i) {
        partitions[i + 1] = boundsValues[i];
      }
      for (var i = 0; i < partitions.length - 1; ++i) {
        final lower = partitions[i];
        final upper = partitions[i + 1];
        final isLast = i == partitions.length - 2;
        if (x >= lower && (x < upper || (isLast && x == upper))) {
          selected = functions[i];
          final encodeRange = _encodeForParameter(i);
          mapped = interpolate(x, lower, upper, encodeRange.min, encodeRange.max);
          break;
        }
      }
    }

    if (selected == null) {
      throw StateError('No partition matched value for type 3 function');
    }

    final result = selected.eval(<double>[mapped]);
    return clipToRange(result);
  }

  List<PDFunction> _loadFunctions() {
    if (_functions != null) {
      return _functions!;
    }
    final array = cosObject.getCOSArray(COSName.functions);
    if (array == null) {
      throw StateError('Type 3 function is missing Functions entry');
    }
    final functions = <PDFunction>[];
    for (final entry in array) {
      functions.add(PDFunction.create(entry));
    }
    _functions = functions;
    return functions;
  }

  List<double> _loadBounds() {
    if (_boundsValues != null) {
      return _boundsValues!;
    }
    final bounds = cosObject.getCOSArray(COSName.bounds);
    if (bounds == null) {
      _boundsValues = const <double>[];
      return _boundsValues!;
    }
    _boundsValues = bounds.toDoubleList();
    return _boundsValues!;
  }

  PDRange _encodeForParameter(int index) {
    final encode = cosObject.getCOSArray(COSName.encode);
    if (encode == null) {
      throw StateError('Type 3 function is missing Encode entry');
    }
    if (encode.length < (index + 1) * 2) {
      throw StateError('Encode array too short for parameter $index');
    }
    return PDRange.fromCOSArray(encode, index * 2);
  }
}
