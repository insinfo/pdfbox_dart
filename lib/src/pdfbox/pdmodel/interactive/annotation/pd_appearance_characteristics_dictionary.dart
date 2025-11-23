import 'package:pdfbox_dart/src/pdfbox/pdmodel/graphics/color/pd_color_space.dart';

import '../../../cos/cos_array.dart';
import '../../../cos/cos_base.dart';
import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_name.dart';
import '../../../cos/cos_stream.dart';
import '../../graphics/color/pd_color.dart';

import '../../graphics/color/pd_device_cmyk.dart';
import '../../graphics/color/pd_device_gray.dart';
import '../../graphics/color/pd_device_rgb.dart';
import '../../graphics/form/pd_form_xobject.dart';

/// This class represents an appearance characteristics dictionary.
class PDAppearanceCharacteristicsDictionary implements COSObjectable {
  final COSDictionary _dictionary;

  /// Constructor.
  PDAppearanceCharacteristicsDictionary(this._dictionary);

  /// returns the dictionary.
  @override
  COSDictionary get cosObject => _dictionary;

  /// This will retrieve the rotation of the annotation widget. It must be a multiple of 90. Default is 0
  int get rotation => _dictionary.getInt(COSName.r, 0)!;

  /// This will set the rotation.
  set rotation(int rotation) => _dictionary.setInt(COSName.r, rotation);

  /// This will retrieve the border color.
  PDColor? get borderColour => _getColor(COSName.bc);

  /// This will set the border color.
  set borderColour(PDColor? c) {
    if (c != null) {
      _dictionary.setItem(COSName.bc, c.cosObject);
    } else {
      _dictionary.removeItem(COSName.bc);
    }
  }

  /// This will retrieve the background color.
  PDColor? get background => _getColor(COSName.bg);

  /// This will set the background color.
  set background(PDColor? c) {
    if (c != null) {
      _dictionary.setItem(COSName.bg, c.cosObject);
    } else {
      _dictionary.removeItem(COSName.bg);
    }
  }

  /// This will retrieve the normal caption.
  String? get normalCaption => _dictionary.getString(COSName.ca);

  /// This will set the normal caption.
  set normalCaption(String? caption) {
    if (caption != null) {
      _dictionary.setString(COSName.ca, caption);
    } else {
      _dictionary.removeItem(COSName.ca);
    }
  }

  /// This will retrieve the rollover caption.
  String? get rolloverCaption => _dictionary.getString(COSName.rc);

  /// This will set the rollover caption.
  set rolloverCaption(String? caption) {
    if (caption != null) {
      _dictionary.setString(COSName.rc, caption);
    } else {
      _dictionary.removeItem(COSName.rc);
    }
  }

  /// This will retrieve the alternate caption.
  String? get alternateCaption => _dictionary.getString(COSName.ac);

  /// This will set the alternate caption.
  set alternateCaption(String? caption) {
    if (caption != null) {
      _dictionary.setString(COSName.ac, caption);
    } else {
      _dictionary.removeItem(COSName.ac);
    }
  }

  /// This will retrieve the normal icon.
  PDFormXObject? get normalIcon {
    COSStream? stream = _dictionary.getCOSStream(COSName.i);
    return stream != null ? PDFormXObject.fromCOSStream(stream) : null;
  }

  /// This will retrieve the rollover icon.
  PDFormXObject? get rolloverIcon {
    COSStream? stream = _dictionary.getCOSStream(COSName.ri);
    return stream != null ? PDFormXObject.fromCOSStream(stream) : null;
  }

  /// This will retrieve the alternate icon.
  PDFormXObject? get alternateIcon {
    COSStream? stream = _dictionary.getCOSStream(COSName.ix);
    return stream != null ? PDFormXObject.fromCOSStream(stream) : null;
  }

  /// This will retrieve the icon fit dictionary.
  COSDictionary? get iconFit => _dictionary.getCOSDictionary(COSName.ifKey);

  /// This will set the icon fit dictionary.
  set iconFit(COSDictionary? value) {
    if (value != null) {
      _dictionary.setItem(COSName.ifKey, value);
    } else {
      _dictionary.removeItem(COSName.ifKey);
    }
  }

  /// This will retrieve the text position.
  int get textPosition => _dictionary.getInt(COSName.tp, 0)!;

  /// This will set the text position.
  set textPosition(int value) => _dictionary.setInt(COSName.tp, value);

  PDColor? _getColor(COSName itemName) {
    COSArray? cs = _dictionary.getCOSArray(itemName);
    if (cs != null) {
      PDColorSpace colorSpace;
      switch (cs.length) {
        case 1:
          colorSpace = PDDeviceGray.instance;
          break;
        case 3:
          colorSpace = PDDeviceRGB.instance;
          break;
        case 4:
          colorSpace = PDDeviceCMYK.instance;
          break;
        default:
          return null;
      }
      return PDColor.fromCOSArray(cs, colorSpace);
    }
    return null;
  }
}

