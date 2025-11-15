import '../../../cos/cos_array.dart';
import '../../../cos/cos_base.dart';
import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_float.dart';
import '../../../cos/cos_name.dart';
import '../../../cos/cos_stream.dart';

/// Appearance characteristics dictionary (`/MK`).
class PDAppearanceCharacteristicsDictionary implements COSObjectable {
  PDAppearanceCharacteristicsDictionary(this._dictionary);

  final COSDictionary _dictionary;

  @override
  COSDictionary get cosObject => _dictionary;

  List<double>? get backgroundColor => _getColor(COSName.bg);

  set backgroundColor(List<double>? value) => _setColor(COSName.bg, value);

  List<double>? get borderColor => _getColor(COSName.bc);

  set borderColor(List<double>? value) => _setColor(COSName.bc, value);

  String? get normalCaption => _dictionary.getString(COSName.ca);

  set normalCaption(String? value) => _dictionary.setString(COSName.ca, value);

  String? get rolloverCaption => _dictionary.getString(COSName.rc);

  set rolloverCaption(String? value) => _dictionary.setString(COSName.rc, value);

  String? get alternateCaption => _dictionary.getString(COSName.ac);

  set alternateCaption(String? value) => _dictionary.setString(COSName.ac, value);

    COSStream? get normalIcon => _getStream(COSName.i);

    set normalIcon(COSStream? value) => _dictionary.setItem(COSName.i, value);

    COSStream? get rolloverIcon => _getStream(COSName.ri);

    set rolloverIcon(COSStream? value) => _dictionary.setItem(COSName.ri, value);

    COSStream? get alternateIcon => _getStream(COSName.ix);

    set alternateIcon(COSStream? value) => _dictionary.setItem(COSName.ix, value);

  COSDictionary? get iconFit => _dictionary.getCOSDictionary(COSName.ifKey);

  set iconFit(COSDictionary? value) =>
      _dictionary.setItem(COSName.ifKey, value);

  int get textPosition => _dictionary.getInt(COSName.tp, 0) ?? 0;

  set textPosition(int value) {
    if (value < 0 || value > 3) {
      throw ArgumentError.value(value, 'value', 'Text position must be 0..3');
    }
    _dictionary.setInt(COSName.tp, value);
  }

  List<double>? _getColor(COSName name) {
    final array = _dictionary.getCOSArray(name);
    if (array == null || array.isEmpty) {
      return null;
    }
    final values = array.toDoubleList();
    return values.isEmpty ? null : List<double>.unmodifiable(values);
  }

  void _setColor(COSName name, List<double>? value) {
    if (value == null) {
      _dictionary.removeItem(name);
      return;
    }
    if (value.isEmpty) {
      throw ArgumentError.value(
        value,
        'value',
        'Color components cannot be empty',
      );
    }
    final array = COSArray();
    for (final component in value) {
      array.add(COSFloat(component.toDouble()));
    }
    _dictionary.setItem(name, array);
  }

  COSStream? _getStream(COSName name) {
    final COSBase? base = _dictionary.getDictionaryObject(name);
    if (base is COSStream) {
      return base;
    }
    return null;
  }
}
