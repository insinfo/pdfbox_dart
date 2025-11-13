import '../../../contentstream/pd_content_stream.dart';
import '../../../cos/cos_array.dart';
import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_float.dart';
import '../../../cos/cos_name.dart';
import '../../../cos/cos_stream.dart';
import '../../../../io/random_access_read.dart';
import '../../pd_document.dart';
import '../../pd_resources.dart';
import '../../pd_stream.dart';
import '../../common/pd_rectangle.dart';
import '../../graphics/pdxobject.dart';
import '../../resource_cache.dart';
import '../../../pdfparser/pdf_stream_parser.dart';
import '../../../util/matrix.dart';

/// Representation of a Form XObject.
class PDFormXObject extends PDXObject implements PDContentStream {
  PDFormXObject(PDStream stream) : super(stream, COSName.form);

  PDFormXObject.fromCOSStream(COSStream stream)
      : super.fromCOSStream(stream, COSName.form);

  PDFormXObject.forDocument(PDDocument document)
      : super.forDocument(document, COSName.form);

  PDStream get contentStream => stream;
  ResourceCache? _resourceCache;

  int get formType => cosObject.getInt(COSName.formType) ?? 1;

  set formType(int value) => cosObject.setInt(COSName.formType, value);

  PDResources? get resources {
    final COSDictionary? dictionary =
        cosObject.getCOSDictionary(COSName.resources);
    if (dictionary != null) {
      return PDResources(dictionary, _resourceCache);
    }
    if (cosObject.containsKey(COSName.resources)) {
      return PDResources(null, _resourceCache);
    }
    return null;
  }

  set resources(PDResources? value) {
    if (value == null) {
      cosObject.removeItem(COSName.resources);
    } else {
      cosObject[COSName.resources] = value.cosObject;
    }
  }

  @override
  RandomAccessRead getContentsForStreamParsing() =>
      contentStream.getContentsForStreamParsing();

  PDRectangle? get boundingBox {
    final array = cosObject.getCOSArray(COSName.bBox);
    if (array == null) {
      return null;
    }
    return PDRectangle.fromCOSArray(array);
  }

  set boundingBox(PDRectangle? rectangle) {
    if (rectangle == null) {
      cosObject.removeItem(COSName.bBox);
    } else {
      cosObject[COSName.bBox] = rectangle.toCOSArray();
    }
  }

  Matrix get matrix =>
      Matrix.create(cosObject.getDictionaryObject(COSName.matrix));

  set matrix(Matrix value) {
    final components = value.toList();
    final cosArray = COSArray()
      ..add(COSFloat(components[0]))
      ..add(COSFloat(components[1]))
      ..add(COSFloat(components[3]))
      ..add(COSFloat(components[4]))
      ..add(COSFloat(components[6]))
      ..add(COSFloat(components[7]));
    cosObject[COSName.matrix] = cosArray;
  }

  List<Object?> parseContentStreamTokens() {
    final parser = PDFStreamParser(this);
    return parser.parse();
  }

  ResourceCache? get resourceCache => _resourceCache;

  set resourceCache(ResourceCache? cache) {
    _resourceCache = cache;
  }
}
