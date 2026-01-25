import '../../../cos/cos_array.dart';
import '../../../cos/cos_base.dart';
import '../../../cos/cos_null.dart';
import '../../graphics/color/pd_gamma.dart';

class PDFourColours implements COSObjectable {
  PDFourColours()
      : _array = COSArray(<COSBase>[
          COSNull.NULL,
          COSNull.NULL,
          COSNull.NULL,
          COSNull.NULL,
        ]);

  PDFourColours.fromCOSArray(COSArray array) : _array = array {
    for (var i = _array.length; i < 4; i++) {
      _array.addObject(COSNull.NULL);
    }
  }

  final COSArray _array;

  @override
  COSBase get cosObject => _array;

  PDGamma? get beforeColour => _getColourByIndex(0);

  set beforeColour(PDGamma? colour) => _setColourByIndex(0, colour);

  PDGamma? get afterColour => _getColourByIndex(1);

  set afterColour(PDGamma? colour) => _setColourByIndex(1, colour);

  PDGamma? get startColour => _getColourByIndex(2);

  set startColour(PDGamma? colour) => _setColourByIndex(2, colour);

  PDGamma? get endColour => _getColourByIndex(3);

  set endColour(PDGamma? colour) => _setColourByIndex(3, colour);

  PDGamma? _getColourByIndex(int index) {
    final item = _array.getObject(index);
    if (item is COSArray) {
      return PDGamma.fromCOSArray(item);
    }
    return null;
  }

  void _setColourByIndex(int index, PDGamma? colour) {
    final base = colour?.cosArray ?? COSNull.NULL;
    _array[index] = base;
  }
}

