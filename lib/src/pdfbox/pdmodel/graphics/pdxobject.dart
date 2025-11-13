import '../../cos/cos_array.dart';
import '../../cos/cos_base.dart';
import '../../cos/cos_name.dart';
import '../../cos/cos_number.dart';
import '../../cos/cos_stream.dart';
import '../pd_document.dart';
import '../pd_stream.dart';
import 'color/pd_color_space.dart';

/// Base representation of an external object (XObject).
class PDXObject {
  PDXObject(PDStream stream, COSName subtype) : _stream = stream {
    _initialiseSubtype(subtype);
  }

  PDXObject.fromCOSStream(COSStream stream, COSName subtype)
      : _stream = PDStream(stream) {
    _initialiseSubtype(subtype);
  }

  PDXObject.forDocument(PDDocument _document, COSName subtype)
      : _stream = PDStream(COSStream()) {
    _initialiseSubtype(subtype);
  }

  final PDStream _stream;

  PDStream get stream => _stream;

  COSStream get cosObject => _stream.cosStream;

  void _initialiseSubtype(COSName subtype) {
    final dictionary = _stream.cosStream;
    dictionary.setName(COSName.type, COSName.xObject.name);
    dictionary.setName(COSName.subtype, subtype.name);
  }
}

/// Representation of an Image XObject.
class PDImageXObject extends PDXObject {
  PDImageXObject(PDStream stream, {dynamic resources})
      : _resources = resources,
        super(stream, COSName.image);

  PDImageXObject.fromCOSStream(COSStream stream, {dynamic resources})
      : _resources = resources,
        super.fromCOSStream(stream, COSName.image);

  dynamic _resources;

  /// Updates the resource context used to resolve color spaces or other
  /// dependencies.
  void setAssociatedResources(dynamic resources) {
    _resources = resources;
  }

  int get width => cosObject.getInt(COSName.width) ?? 0;

  int get height => cosObject.getInt(COSName.height) ?? 0;

  int get bitsPerComponent => cosObject.getInt(COSName.bitsPerComponent) ?? 8;

  bool get isStencil => cosObject.getBoolean(COSName.imageMask) ?? false;

  bool get interpolate => cosObject.getBoolean(COSName.interpolate) ?? false;

  List<double>? get decode {
    final COSArray? array = cosObject.getCOSArray(COSName.decode);
    if (array == null) {
      return null;
    }
    final values = <double>[];
    for (var index = 0; index < array.length; ++index) {
      final COSBase entry = array.getObject(index);
      if (entry is COSNumber) {
        values.add(entry.doubleValue);
      }
    }
    return values;
  }

  PDColorSpace? get colorSpace {
    final COSBase? value = cosObject.getDictionaryObject(COSName.colorSpace);
    if (value == null) {
      return null;
    }
    return PDColorSpace.create(value, resources: _resources);
  }

  PDStream? get softMask {
    final COSBase? value = cosObject.getDictionaryObject(COSName.sMask);
    if (value is COSStream) {
      return PDStream(value);
    }
    return null;
  }

  PDStream? get imageMaskStream {
    final COSBase? value = cosObject.getDictionaryObject(COSName.mask);
    if (value is COSStream) {
      return PDStream(value);
    }
    return null;
  }
}
