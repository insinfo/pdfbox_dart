import '../../../cos/cos_array.dart';
import '../../../cos/cos_base.dart';
import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_float.dart';
import '../../../cos/cos_name.dart';

/// Describes annotation border appearance (ISO 32000-1, Table 166).
class PDBorderStyleDictionary implements COSObjectable {
  PDBorderStyleDictionary(this._dictionary);

  static const String styleSolid = 'S';
  static const String styleDashed = 'D';
  static const String styleBeveled = 'B';
  static const String styleInset = 'I';
  static const String styleUnderline = 'U';

  final COSDictionary _dictionary;

  @override
  COSDictionary get cosObject => _dictionary;

  String? get style => _dictionary.getNameAsString(COSName.s);

  set style(String? value) {
    if (value == null) {
      _dictionary.removeItem(COSName.s);
    } else {
      _dictionary.setName(COSName.s, value);
    }
  }

  double get width => _dictionary.getFloat(COSName.w, 1.0) ?? 1.0;

  set width(double value) {
    if (value <= 0) {
      throw ArgumentError.value(value, 'value', 'Border width must be positive');
    }
    _dictionary.setFloat(COSName.w, value);
  }

  List<double>? get dashPattern {
    final array = _dictionary.getCOSArray(COSName.d);
    if (array == null || array.isEmpty) {
      return null;
    }
    final values = array.toDoubleList();
    return values.isEmpty ? null : List<double>.unmodifiable(values);
  }

  set dashPattern(List<double>? value) {
    if (value == null) {
      _dictionary.removeItem(COSName.d);
      return;
    }
    if (value.isEmpty) {
      throw ArgumentError.value(
        value,
        'value',
        'Dash pattern must contain at least one element',
      );
    }
    final array = COSArray();
    for (final component in value) {
      if (component < 0) {
        throw ArgumentError.value(
          component,
          'value',
          'Dash pattern components must be non-negative',
        );
      }
      array.add(COSFloat(component.toDouble()));
    }
    _dictionary.setItem(COSName.d, array);
  }
}
