import '../../cos/cos_array.dart';
import '../../cos/cos_base.dart';
import '../../cos/cos_float.dart';
import '../../cos/cos_integer.dart';
import '../../cos/cos_number.dart';

/// A line dash pattern for stroking paths.
/// Instances are immutable after construction.
class PDLineDashPattern implements COSObjectable {
  /// Creates a new dash pattern with no dashes and a phase of zero.
  PDLineDashPattern() : this._(const <double>[], 0);

  /// Creates a new dash pattern from a COS dash array and phase.
  factory PDLineDashPattern.fromCOSArray(COSArray dashArray, int phase) {
    final values = _toFloatArray(dashArray);
    final normalized = _normalizePhase(values, phase);
    return PDLineDashPattern._(values, normalized);
  }

  /// Creates a new dash pattern from an iterable of dash lengths and phase.
  factory PDLineDashPattern.fromValues(
      Iterable<double> dashLengths, int phase) {
    final array = List<double>.from(dashLengths, growable: false);
    final normalized = _normalizePhase(array, phase);
    return PDLineDashPattern._(array, normalized);
  }

  PDLineDashPattern._(List<double> array, this._phase)
      : _array = List<double>.unmodifiable(array);

  final List<double> _array;
  final int _phase;

  @override
  COSBase get cosObject => toCOSArray();

  /// Converts this pattern to a COS representation `[dashArray, phase]`.
  COSArray toCOSArray() {
    final dashArray = COSArray();
    for (final value in _array) {
      dashArray.add(COSFloat(value));
    }
    final result = COSArray();
    result.add(dashArray);
    result.add(COSInteger(_phase));
    return result;
  }

  /// Returns the dash phase specifying where to start within the pattern.
  int get phase => _phase;

  /// Returns a defensive copy of the dash array.
  List<double> get dashArray => List<double>.from(_array, growable: false);

  static List<double> _toFloatArray(COSArray array) {
    final values = <double>[];
    for (final element in array) {
      if (element is COSNumber) {
        values.add(element.doubleValue);
      }
    }
    return values;
  }

  static int _normalizePhase(List<double> dashArray, int phase) {
    if (phase >= 0) {
      return phase;
    }
    final sum = dashArray.fold<double>(0, (value, element) => value + element);
    final sum2 = sum * 2;
    if (sum2 <= 0) {
      return 0;
    }
    final negativePhase = -phase.toDouble();
    final double increment;
    if (negativePhase < sum2) {
      increment = sum2;
    } else {
      final cycles = (negativePhase / sum2).floor() + 1;
      increment = cycles * sum2;
    }
    final adjusted = phase + increment.toInt();
    return adjusted >= 0 ? adjusted : 0;
  }

  @override
  String toString() => 'PDLineDashPattern{array=$_array, phase=$_phase}';
}
