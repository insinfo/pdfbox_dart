import '../../cos/cos_array.dart';
import '../../cos/cos_base.dart' show COSObjectable;
import '../../cos/cos_string.dart';

/// This represents an object that can be used in a Field's Opt entry to represent 
/// an available option and a default appearance string.
/// Ported from org.apache.pdfbox.pdmodel.fdf.FDFOptionElement
class FDFOptionElement implements COSObjectable {
  FDFOptionElement([COSArray? option]) 
      : _option = option ?? _createDefaultArray();

  static COSArray _createDefaultArray() {
    final array = COSArray();
    array.add(COSString(''));
    array.add(COSString(''));
    return array;
  }

  final COSArray _option;

  @override
  COSArray get cosObject => _option;

  /// Convert this standard java object to a COS array.
  /// Returns the cos array that matches this Java object.
  COSArray getCOSArray() => _option;

  /// This will get the string of one of the available options. A required element.
  /// Returns an available option.
  String get option {
    final obj = _option.getObject(0);
    return obj is COSString ? obj.string : '';
  }

  /// This will set the string for an available option.
  /// [opt] One of the available options.
  set option(String opt) {
    if (_option.isEmpty) {
      _option.add(COSString(opt));
    } else {
      _option[0] = COSString(opt);
    }
  }

  /// This will get the string of default appearance string. A required element.
  /// Returns a default appearance string.
  String get defaultAppearanceString {
    if (_option.length < 2) return '';
    final obj = _option.getObject(1);
    return obj is COSString ? obj.string : '';
  }

  /// This will set the default appearance string.
  /// [da] The default appearance string.
  set defaultAppearanceString(String da) {
    while (_option.length < 2) {
      _option.add(COSString(''));
    }
    _option[1] = COSString(da);
  }
}

