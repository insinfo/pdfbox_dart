import '../../cos/cos_array.dart';
import '../../cos/cos_float.dart';

class PDRange {
  PDRange([double min = 0, double max = 0])
      : _array = COSArray()
          ..add(COSFloat(min))
          ..add(COSFloat(max)),
        _offset = 0;

  PDRange.fromCOSArray(COSArray array, [int offset = 0])
      : _array = array,
        _offset = offset;

  final COSArray _array;
  final int _offset;

  double get min => _array.getDouble(_offset) ?? 0;

  set min(double value) {
    _ensureLength();
    _array[_offset] = COSFloat(value);
  }

  double get max => _array.getDouble(_offset + 1) ?? 0;

  set max(double value) {
    _ensureLength();
    _array[_offset + 1] = COSFloat(value);
  }

  COSArray get cosArray => _array;

  void _ensureLength() {
    while (_array.length <= _offset + 1) {
      _array.add(COSFloat(0));
    }
  }
}
