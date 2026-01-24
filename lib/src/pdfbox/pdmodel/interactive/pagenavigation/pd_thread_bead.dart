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

  /// Returns the next bead in the thread.
  PDThreadBead? get nextBead {
    final dict = _dictionary.getCOSDictionary(COSName.n);
    return dict != null ? PDThreadBead(dict) : null;
  }

  /// Sets the next bead in the thread.
  set nextBead(PDThreadBead? bead) {
    if (bead != null) {
      _dictionary.setItem(COSName.n, bead.cosObject);
    } else {
      _dictionary.removeItem(COSName.n);
    }
  }

  /// Returns the previous bead in the thread.
  PDThreadBead? get previousBead {
    final dict = _dictionary.getCOSDictionary(COSName.v);
    return dict != null ? PDThreadBead(dict) : null;
  }

  /// Sets the previous bead in the thread.
  set previousBead(PDThreadBead? bead) {
    if (bead != null) {
      _dictionary.setItem(COSName.v, bead.cosObject);
    } else {
      _dictionary.removeItem(COSName.v);
    }
  }

  /// Returns the thread that this bead belongs to.
  COSDictionary? get thread {
    return _dictionary.getCOSDictionary(COSName.t);
  }

  /// Sets the thread that this bead belongs to.
  set thread(COSDictionary? threadDict) {
    if (threadDict != null) {
      _dictionary.setItem(COSName.t, threadDict);
    } else {
      _dictionary.removeItem(COSName.t);
    }
  }

  /// Returns the page dictionary that this bead is on.
  COSDictionary? get page {
    return _dictionary.getCOSDictionary(COSName.p);
  }

  /// Sets the page that this bead is on.
  set page(COSDictionary? pageDict) {
    if (pageDict != null) {
      _dictionary.setItem(COSName.p, pageDict);
    } else {
      _dictionary.removeItem(COSName.p);
    }
  }
}
