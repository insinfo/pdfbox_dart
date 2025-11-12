import '../../cos/cos_array.dart';
import '../../cos/cos_base.dart' show COSBase, COSObjectable;
import '../../cos/cos_number.dart';
import '../font/pdfont.dart';

/// Represents the `/Font` entry inside an extended graphics state.
///
/// The font dictionary is not resolved yet; this class exposes the requested
/// font size and leaves actual font loading to higher layers once the font
/// subsystem is ported.
class PDFontSetting implements COSObjectable {
  PDFontSetting([COSArray? array]) : _array = array ?? COSArray();

  final COSArray _array;

  @override
  COSBase get cosObject => _array;

  /// Returns the raw COS font object, if any.
  COSBase? get rawFont => _array.length > 0 ? _array.getObject(0) : null;

  /// Returns the resolved font when already available.
  PDFont? get font => rawFont is PDFont ? rawFont as PDFont : null;

  /// Requested font size, defaults to 1.0 when not specified.
  double get fontSize {
    if (_array.length < 2) {
      return 1.0;
    }
    final value = _array.getObject(1);
    if (value is COSNumber) {
      return value.doubleValue;
    }
    return 1.0;
  }
}
