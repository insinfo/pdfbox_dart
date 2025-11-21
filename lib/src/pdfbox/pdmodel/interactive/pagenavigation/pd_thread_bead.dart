import 'package:pdfbox_dart/src/pdfbox/cos/cos_dictionary.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_name.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/common/pd_rectangle.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/common/cos_objectable.dart';

class PDThreadBead implements COSObjectable {
  final COSDictionary _dictionary;

  PDThreadBead([COSDictionary? dictionary])
      : _dictionary = dictionary ?? COSDictionary() {
    if (dictionary == null) {
      _dictionary.setName(COSName.type, 'Bead');
    }
  }

  @override
  COSDictionary get cosObject => _dictionary;

  PDRectangle? get rectangle {
    final array = _dictionary.getCOSArray(COSName.r);
    if (array != null) {
      return PDRectangle.fromCOSArray(array);
    }
    return null;
  }

  set rectangle(PDRectangle? rect) {
    if (rect != null) {
      _dictionary.setItem(COSName.r, rect.toCOSArray());
    } else {
      _dictionary.removeItem(COSName.r);
    }
  }

  // TODO: Add other properties like Next, Prev, Thread, Page if needed
}
